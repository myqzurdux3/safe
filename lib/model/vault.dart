import 'dart:convert';
import 'dart:typed_data';

import '../storage/blob_store.dart';

/// Une pièce jointe: photo, document, n'importe quel fichier.
///
/// Seules ses métadonnées vivent dans le coffre; le contenu est chiffré à part,
/// dans `blobs/<id>.blob`. Le coffre reste donc petit, et une photo n'est
/// déchiffrée que si l'utilisateur l'ouvre.
class VaultAttachment {
  const VaultAttachment({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.created,
  });

  factory VaultAttachment._fromJson(Map<String, dynamic> json) =>
      VaultAttachment(
        // Relu d'un fichier qui peut venir d'un tiers: un identifiant est un
        // nom de fichier, il ne doit désigner qu'un blob.
        id: _checkedId(json['id']),
        name: json['name'] as String,
        mimeType: json['mime'] as String,
        size: json['size'] as int,
        created: DateTime.fromMillisecondsSinceEpoch(
          json['created'] as int,
          isUtc: true,
        ),
      );

  /// Identifiant du blob sur le disque; sans rapport avec le nom du fichier,
  /// qui est un secret comme le reste.
  final String id;
  final String name;
  final String mimeType;

  /// Taille du contenu en clair, en octets.
  final int size;
  final DateTime created;

  static String _checkedId(Object? raw) {
    try {
      return checkBlobId(raw as String);
    } catch (error) {
      throw FormatException('Identifiant de pièce jointe invalide: $error');
    }
  }

  bool get isImage => mimeType.startsWith('image/');

  Map<String, dynamic> _toJson() => {
    'id': id,
    'name': name,
    'mime': mimeType,
    'size': size,
    'created': created.millisecondsSinceEpoch,
  };
}

/// Une entrée du coffre: une clef, sa valeur secrète, ses pièces jointes et ses
/// horodatages.
///
/// Immuable: modifier une entrée revient à en construire une nouvelle, ce qui
/// évite qu'une valeur déchiffrée traîne dans un objet partagé.
class VaultEntry {
  const VaultEntry({
    required this.key,
    required this.value,
    required this.created,
    required this.updated,
    this.attachments = const [],
  });

  /// Construit une entrée horodatée à maintenant (UTC).
  factory VaultEntry.now({
    required String key,
    required String value,
    List<VaultAttachment> attachments = const [],
  }) {
    final now = DateTime.now().toUtc();
    return VaultEntry(
      key: key,
      value: value,
      created: now,
      updated: now,
      attachments: attachments,
    );
  }

  factory VaultEntry._fromJson(Map<String, dynamic> json) => VaultEntry(
    key: json['k'] as String,
    value: json['val'] as String,
    created: DateTime.fromMillisecondsSinceEpoch(
      json['created'] as int,
      isUtc: true,
    ),
    updated: DateTime.fromMillisecondsSinceEpoch(
      json['updated'] as int,
      isUtc: true,
    ),
    // Champ absent des coffres écrits avant les pièces jointes: leur lecture
    // ne demande donc aucune migration.
    attachments: [
      for (final raw in (json['att'] as List<dynamic>? ?? const []))
        VaultAttachment._fromJson(raw as Map<String, dynamic>),
    ],
  );

  final String key;
  final String value;
  final DateTime created;
  final DateTime updated;
  final List<VaultAttachment> attachments;

  Map<String, dynamic> _toJson() => {
    'k': key,
    'val': value,
    'created': created.millisecondsSinceEpoch,
    'updated': updated.millisecondsSinceEpoch,
    if (attachments.isNotEmpty)
      'att': [for (final attachment in attachments) attachment._toJson()],
  };
}

/// Le contenu déchiffré du coffre.
///
/// N'existe qu'en mémoire et seulement pendant que la session est
/// déverrouillée. La sérialisation produit le clair qui sera chiffré en bloc;
/// aucune méthode de cette classe ne touche au disque.
class Vault {
  const Vault(this.entries);

  /// Relit le clair produit par [toBytes].
  ///
  /// Lève une [FormatException] si les octets ne sont pas du JSON attendu ou
  /// si la version du format est inconnue.
  factory Vault.fromBytes(Uint8List bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Contenu de coffre illisible: $error');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Contenu de coffre illisible');
    }
    if (decoded['v'] != formatVersion) {
      throw FormatException('Version de coffre inconnue: ${decoded['v']}');
    }
    final rawEntries = decoded['entries'];
    if (rawEntries is! List) {
      throw const FormatException('Liste d\'entrées absente');
    }
    return Vault([
      for (final raw in rawEntries)
        VaultEntry._fromJson(raw as Map<String, dynamic>),
    ]);
  }

  /// Version du clair sérialisé, indépendante de la version du fichier.
  static const int formatVersion = 1;

  /// Entrées triées par clef, casse ignorée.
  final List<VaultEntry> entries;

  /// Sérialise en JSON UTF-8. C'est ce que la couche crypto chiffre.
  Uint8List toBytes() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'v': formatVersion,
        'entries': [for (final entry in entries) entry._toJson()],
      }),
    ),
  );

  /// Ajoute ou remplace une entrée, en conservant sa date de création.
  Vault upsert(VaultEntry entry) {
    final existing = entries.where((e) => e.key == entry.key).firstOrNull;
    final merged = existing == null
        ? entry
        : VaultEntry(
            key: entry.key,
            value: entry.value,
            created: existing.created,
            updated: entry.updated,
            attachments: entry.attachments,
          );
    final next = [
      ...entries.where((e) => e.key != entry.key),
      merged,
    ]..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return Vault(next);
  }

  /// Retire l'entrée portant [key]; sans effet si elle n'existe pas.
  Vault remove(String key) =>
      Vault([...entries.where((e) => e.key != key)]);

  /// Filtre les entrées dont la clef contient [query], casse ignorée.
  List<VaultEntry> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return entries;
    }
    return [
      for (final entry in entries)
        if (entry.key.toLowerCase().contains(needle)) entry,
    ];
  }
}
