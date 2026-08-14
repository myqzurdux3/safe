import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

import '../model/vault.dart';

/// Levée quand le déchiffrement échoue.
///
/// Un tag AEAD invalide ne dit pas *pourquoi* il est invalide: mauvais mot de
/// passe ou fichier altéré donnent la même erreur, et l'interface ne doit pas
/// prétendre distinguer les deux.
class WrongPasswordException implements Exception {
  const WrongPasswordException();

  @override
  String toString() => 'WrongPasswordException';
}

/// Paramètres de dérivation Argon2id, stockés dans l'en-tête du fichier pour
/// qu'un coffre ancien reste lisible après un durcissement des valeurs par
/// défaut.
class KdfParams {
  const KdfParams({required this.opsLimit, required this.memLimit});

  /// 3 passes sur 128 Mio: résistance mémoire réelle, sans l'allocation de
  /// 256 Mio du preset `moderate` de libsodium qui expose l'app à une mise à
  /// mort par Android sur appareil bas de gamme.
  static const KdfParams defaults = KdfParams(
    opsLimit: 3,
    memLimit: 128 * 1024 * 1024,
  );

  final int opsLimit;
  final int memLimit;
}

/// En-tête en clair du fichier coffre, également utilisé comme données
/// associées de l'AEAD: le modifier invalide le tag.
class VaultHeader {
  const VaultHeader({
    required this.version,
    required this.params,
    required this.salt,
    required this.nonce,
  });

  /// Relit l'en-tête des [bytes] d'un fichier coffre.
  ///
  /// Lève une [FormatException] si le fichier est trop court, si le magic ne
  /// correspond pas, ou si la version ou l'identifiant de KDF sont inconnus.
  factory VaultHeader.parse(Uint8List bytes) {
    if (bytes.length < length + 16) {
      throw const FormatException('Fichier coffre tronqué');
    }
    final magicBytes = bytes.sublist(0, magic.length);
    if (utf8.decode(magicBytes, allowMalformed: true) != magic) {
      throw const FormatException('Ce fichier n\'est pas un coffre safe');
    }
    final view = ByteData.sublistView(bytes, 0, length);
    final version = view.getUint8(8);
    if (version != formatVersion) {
      throw FormatException('Version de coffre inconnue: $version');
    }
    final kdfId = view.getUint8(9);
    if (kdfId != argon2idKdfId) {
      throw FormatException('Fonction de dérivation inconnue: $kdfId');
    }
    final opsLimit = view.getUint32(10, Endian.little);
    final memLimit = view.getUint64(14, Endian.little);
    // Les paramètres viennent d'un fichier qui peut être hostile: sans bornes,
    // un memLimit de plusieurs Tio ferait tomber l'app à la simple ouverture.
    if (opsLimit < minOpsLimit || opsLimit > maxOpsLimit) {
      throw FormatException('Paramètre opsLimit hors bornes: $opsLimit');
    }
    if (memLimit < minMemLimit || memLimit > maxMemLimit) {
      throw FormatException('Paramètre memLimit hors bornes: $memLimit');
    }
    return VaultHeader(
      version: version,
      params: KdfParams(opsLimit: opsLimit, memLimit: memLimit),
      salt: Uint8List.sublistView(bytes, 22, 38),
      nonce: Uint8List.sublistView(bytes, 38, length),
    );
  }

  static const String magic = 'SAFEVLT1';
  static const int formatVersion = 1;
  static const int argon2idKdfId = 1;
  static const int saltLength = 16;
  static const int nonceLength = 24;

  /// 8 magic + 1 version + 1 kdf + 4 opsLimit + 8 memLimit + 16 sel + 24 nonce.
  static const int length = 62;

  /// Bornes acceptées pour les paramètres lus dans un fichier.
  static const int minOpsLimit = 1;
  static const int maxOpsLimit = 32;
  static const int minMemLimit = 8 * 1024 * 1024;
  static const int maxMemLimit = 1024 * 1024 * 1024;

  final int version;
  final KdfParams params;
  final Uint8List salt;
  final Uint8List nonce;

  /// Rend les octets de l'en-tête, tels qu'écrits en tête de fichier.
  Uint8List toBytes() {
    final bytes = Uint8List(length);
    bytes.setRange(0, magic.length, utf8.encode(magic));
    final view = ByteData.sublistView(bytes);
    view.setUint8(8, version);
    view.setUint8(9, argon2idKdfId);
    view.setUint32(10, params.opsLimit, Endian.little);
    view.setUint64(14, params.memLimit, Endian.little);
    bytes.setRange(22, 38, salt);
    bytes.setRange(38, length, nonce);
    return bytes;
  }
}

/// Chiffrement du coffre: Argon2id pour la dérivation, XChaCha20-Poly1305 pour
/// le contenu.
///
/// Ne touche jamais au disque: elle prend et rend des octets. C'est ce qui la
/// rend testable sans système de fichiers, et lisible d'un seul tenant.
class VaultCrypto {
  VaultCrypto(this._sodium);

  final SodiumSumo _sodium;

  Aead get _aead => _sodium.crypto.aeadXChaCha20Poly1305IETF;

  /// Tire un sel neuf pour une dérivation.
  Uint8List newSalt() => _sodium.randombytes.buf(VaultHeader.saltLength);

  /// Dérive la clé de chiffrement à partir du mot de passe maître.
  ///
  /// Opération volontairement coûteuse: c'est elle qui protège un fichier volé.
  SecureKey deriveKey(String password, Uint8List salt, KdfParams params) {
    final passwordBytes = Int8List.fromList(utf8.encode(password));
    try {
      return _sodium.crypto.pwhash(
        outLen: _aead.keyBytes,
        password: passwordBytes,
        salt: salt,
        opsLimit: params.opsLimit,
        memLimit: params.memLimit,
        alg: CryptoPwhashAlgorithm.argon2id13,
      );
    } finally {
      passwordBytes.fillRange(0, passwordBytes.length, 0);
    }
  }

  /// Chiffre [vault] avec une clé déjà dérivée, en réutilisant [salt] et
  /// [params] pour l'en-tête. Un nonce neuf est tiré à chaque appel.
  Uint8List seal(
    Vault vault,
    SecureKey key,
    Uint8List salt,
    KdfParams params,
  ) {
    final header = VaultHeader(
      version: VaultHeader.formatVersion,
      params: params,
      salt: salt,
      nonce: _sodium.randombytes.buf(_aead.nonceBytes),
    );
    final headerBytes = header.toBytes();
    final plaintext = vault.toBytes();
    try {
      final cipherText = _aead.encrypt(
        message: plaintext,
        nonce: header.nonce,
        key: key,
        additionalData: headerBytes,
      );
      return Uint8List(headerBytes.length + cipherText.length)
        ..setRange(0, headerBytes.length, headerBytes)
        ..setRange(headerBytes.length, headerBytes.length + cipherText.length,
            cipherText);
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  /// Dérive une clé sur un sel neuf, chiffre [vault], puis libère la clé.
  ///
  /// Utilisé à la création du coffre et au changement de mot de passe.
  Uint8List sealWithPassword(
    Vault vault,
    String password, {
    KdfParams params = KdfParams.defaults,
  }) {
    final salt = newSalt();
    final key = deriveKey(password, salt, params);
    try {
      return seal(vault, key, salt, params);
    } finally {
      key.dispose();
    }
  }

  /// Déchiffre un fichier coffre complet.
  ///
  /// Lève [FormatException] si le fichier n'est pas un coffre lisible, et
  /// [WrongPasswordException] si le tag AEAD ne passe pas.
  Vault open(Uint8List fileBytes, String password) {
    final header = VaultHeader.parse(fileBytes);
    final key = deriveKey(password, header.salt, header.params);
    try {
      return openWithKey(fileBytes, key);
    } finally {
      key.dispose();
    }
  }

  /// Déchiffre avec une clé déjà dérivée — évite de repayer Argon2id quand la
  /// session tient déjà la clé.
  Vault openWithKey(Uint8List fileBytes, SecureKey key) {
    final header = VaultHeader.parse(fileBytes);
    final cipherText = Uint8List.sublistView(fileBytes, VaultHeader.length);
    Uint8List plaintext;
    try {
      plaintext = _aead.decrypt(
        cipherText: cipherText,
        nonce: header.nonce,
        key: key,
        additionalData: Uint8List.sublistView(fileBytes, 0, VaultHeader.length),
      );
    } on SodiumException {
      throw const WrongPasswordException();
    }
    try {
      return Vault.fromBytes(plaintext);
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }
}
