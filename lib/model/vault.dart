import 'dart:convert';
import 'dart:typed_data';

import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../storage/blob_store.dart';

/// Forme canonique d'une clef, pour la comparer et la chercher.
///
/// Deux problèmes se cumulent. La casse: on veut que « Gmail » et « gmail »
/// soient la même clef. Et l'écriture Unicode: « café » existe avec un é
/// précomposé (U+00E9) ou avec un e suivi d'un accent combinant
/// (U+0065 U+0301) — visuellement identiques, distincts octet pour octet, et un
/// clavier ou un collage produit l'un ou l'autre sans que l'utilisateur le
/// sache. Sans normalisation, la liste affichait deux entrées impossibles à
/// distinguer, et chercher l'une ne trouvait pas l'autre.
///
/// Uniquement pour comparer: la clef enregistrée reste celle que l'utilisateur a
/// tapée. Normaliser à l'écriture réécrirait les coffres existants, ce qui
/// demanderait une migration.
String canonicalKey(String key) => unorm.nfc(key).toLowerCase();

/// Lecture typée du JSON du coffre.
///
/// Le clair est authentifié, mais il n'a pas forcément été écrit par nous:
/// l'import accepte un fichier étranger avec son mot de passe. Des `as` nus
/// lèveraient alors un `TypeError` — qui n'est pas une `Exception`, et que le
/// contrat de [Vault.fromBytes] ne promet pas.
String _string(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String) {
    throw FormatException('Champ « $field » absent ou invalide');
  }
  return value;
}

int _int(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! int) {
    throw FormatException('Champ « $field » absent ou invalide');
  }
  return value;
}

/// Horodatage en millisecondes, borné.
///
/// `DateTime.fromMillisecondsSinceEpoch` lève sur les valeurs extrêmes, et
/// lèverait un `ArgumentError` plutôt qu'une `FormatException`.
DateTime _date(Map<String, dynamic> json, String field) {
  final millis = _int(json, field);
  if (millis.abs() > _maxTimestampMillis) {
    throw FormatException('Horodatage « $field » hors bornes: $millis');
  }
  return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}

/// Un siècle de part et d'autre de l'époque Unix: assez large pour tout coffre
/// réel, assez étroit pour écarter une valeur fabriquée.
const int _maxTimestampMillis = 100 * 365 * 24 * 3600 * 1000;

List<dynamic> _list(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) {
    return const [];
  }
  if (value is! List) {
    throw FormatException('Champ « $field » invalide');
  }
  return value;
}

Map<String, dynamic> _object(Object? raw) {
  if (raw is! Map<String, dynamic>) {
    throw const FormatException('Objet attendu');
  }
  return raw;
}

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
        name: _string(json, 'name'),
        mimeType: _string(json, 'mime'),
        size: _int(json, 'size'),
        created: _date(json, 'created'),
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
    key: _string(json, 'k'),
    value: _string(json, 'val'),
    created: _date(json, 'created'),
    updated: _date(json, 'updated'),
    // Champ absent des coffres écrits avant les pièces jointes: leur lecture
    // ne demande donc aucune migration.
    attachments: [
      for (final raw in _list(json, 'att'))
        VaultAttachment._fromJson(_object(raw)),
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
  /// Les entrées sont conservées triées et non modifiables.
  ///
  /// Le tri était documenté sans être établi: un fichier non trié se relisait
  /// non trié, et l'interface l'affichait dans le désordre jusqu'à la première
  /// modification.
  Vault(Iterable<VaultEntry> entries)
    : entries = List.unmodifiable(_sorted(entries));

  /// Le coffre vide, celui d'un coffre qui vient d'être créé.
  static final Vault empty = Vault(const []);

  static List<VaultEntry> _sorted(Iterable<VaultEntry> entries) =>
      [...entries]
        ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

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
    // Dédoublonnage par clef: rien n'imposait l'unicité à la relecture, et
    // `upsert` retirait ensuite *toutes* les entrées portant la clef pour n'en
    // réinsérer qu'une — les deux disparaissaient. La plus récemment modifiée
    // gagne.
    final parClef = <String, VaultEntry>{};
    for (final raw in rawEntries) {
      final entry = VaultEntry._fromJson(_object(raw));
      final existing = parClef[canonicalKey(entry.key)];
      if (existing == null || entry.updated.isAfter(existing.updated)) {
        parClef[canonicalKey(entry.key)] = entry;
      }
    }
    return Vault(parClef.values);
  }

  /// Version du clair sérialisé, indépendante de la version du fichier.
  static const int formatVersion = 1;

  /// Entrées triées par clef, casse ignorée. Non modifiable.
  final List<VaultEntry> entries;

  /// Sérialise en JSON UTF-8. C'est ce que la couche crypto chiffre.
  ///
  /// `JsonUtf8Encoder` écrit directement des octets. `jsonEncode` produisait
  /// d'abord une `String` contenant le coffre entier en clair — une copie que
  /// Dart ne permet pas d'effacer, et qui survivait donc au `fillRange` que la
  /// couche crypto applique consciencieusement au tampon qu'on lui rend.
  ///
  /// Le résultat est identique octet pour octet: un coffre déjà écrit se relit.
  Uint8List toBytes() {
    final encoded = JsonUtf8Encoder().convert({
      'v': formatVersion,
      'entries': [for (final entry in entries) entry._toJson()],
    });
    return encoded is Uint8List ? encoded : Uint8List.fromList(encoded);
  }

  /// Ajoute ou remplace une entrée, en conservant sa date de création.
  Vault upsert(VaultEntry entry) {
    final canonique = canonicalKey(entry.key);
    final existing = entries
        .where((e) => canonicalKey(e.key) == canonique)
        .firstOrNull;
    final merged = existing == null
        ? entry
        : VaultEntry(
            key: entry.key,
            value: entry.value,
            created: existing.created,
            updated: entry.updated,
            attachments: entry.attachments,
          );
    return Vault([
      ...entries.where((e) => canonicalKey(e.key) != canonique),
      merged,
    ]);
  }

  /// Retire l'entrée portant [key]; sans effet si elle n'existe pas.
  Vault remove(String key) {
    final canonique = canonicalKey(key);
    return Vault([...entries.where((e) => canonicalKey(e.key) != canonique)]);
  }

  /// Filtre les entrées dont la clef contient [query], casse ignorée.
  List<VaultEntry> search(String query) {
    final needle = canonicalKey(query.trim());
    if (needle.isEmpty) {
      return entries;
    }
    return [
      for (final entry in entries)
        if (canonicalKey(entry.key).contains(needle)) entry,
    ];
  }
}
