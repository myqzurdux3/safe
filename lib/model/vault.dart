import 'dart:convert';
import 'dart:typed_data';

/// Une entrée du coffre: une clef, sa valeur secrète, et ses horodatages.
///
/// Immuable: modifier une entrée revient à en construire une nouvelle, ce qui
/// évite qu'une valeur déchiffrée traîne dans un objet partagé.
class VaultEntry {
  const VaultEntry({
    required this.key,
    required this.value,
    required this.created,
    required this.updated,
  });

  /// Construit une entrée horodatée à maintenant (UTC).
  factory VaultEntry.now({required String key, required String value}) {
    final now = DateTime.now().toUtc();
    return VaultEntry(key: key, value: value, created: now, updated: now);
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
  );

  final String key;
  final String value;
  final DateTime created;
  final DateTime updated;

  Map<String, dynamic> _toJson() => {
    'k': key,
    'val': value,
    'created': created.millisecondsSinceEpoch,
    'updated': updated.millisecondsSinceEpoch,
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
