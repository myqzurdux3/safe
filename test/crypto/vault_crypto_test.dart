import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/crypto/vault_crypto.dart';
import 'package:safe/model/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../support/crypto_fixture.dart';

/// Paramètres volontairement faibles: les tests vérifient la mécanique, pas la
/// résistance au cassage. Les vrais paramètres sont dans [KdfParams.defaults].
const testParams = KdfParams(opsLimit: 1, memLimit: 8 * 1024 * 1024);

void main() {
  late VaultCrypto crypto;

  setUpAll(() async {
    crypto = VaultCrypto(await SodiumSumoInit.init());
  });

  Vault vaultAvec(String key, String value) =>
      Vault.empty.upsert(VaultEntry.now(key: key, value: value));

  test('aller-retour avec le bon mot de passe', () {
    final bytes = crypto.sealWithPassword(
      vaultAvec('a', 'secret'),
      'hunter2',
      params: testParams,
    );
    expect(crypto.open(bytes, 'hunter2').entries.single.value, 'secret');
  });

  test('mauvais mot de passe rejeté', () {
    final bytes = crypto.sealWithPassword(
      Vault.empty,
      'hunter2',
      params: testParams,
    );
    expect(
      () => crypto.open(bytes, 'hunter3'),
      throwsA(isA<WrongPasswordException>()),
    );
  });

  test('en-tête falsifié dans les bornes rejeté par le tag', () {
    final bytes = crypto.sealWithPassword(
      Vault.empty,
      'hunter2',
      params: testParams,
    );
    bytes[10] = testParams.opsLimit + 1; // opsLimit encore valide, mais changé
    expect(
      () => crypto.open(bytes, 'hunter2'),
      throwsA(isA<WrongPasswordException>()),
    );
  });

  test('sel falsifié rejeté', () {
    final bytes = crypto.sealWithPassword(
      Vault.empty,
      'hunter2',
      params: testParams,
    );
    bytes[22] = bytes[22] ^ 0x01;
    expect(
      () => crypto.open(bytes, 'hunter2'),
      throwsA(isA<WrongPasswordException>()),
    );
  });

  test('paramètres KDF hors bornes rejetés sans tenter la dérivation', () {
    final bytes = crypto.sealWithPassword(
      Vault.empty,
      'hunter2',
      params: testParams,
    );
    final opsNul = Uint8List.fromList(bytes)..[10] = 0;
    expect(() => crypto.open(opsNul, 'hunter2'), throwsFormatException);

    // memLimit ramené à 2^56 octets: sans borne, la dérivation tenterait
    // d'allouer 64 Pio à l'ouverture d'un fichier reçu de l'extérieur.
    final memEnorme = Uint8List.fromList(bytes)..[20] = 0x01;
    expect(() => crypto.open(memEnorme, 'hunter2'), throwsFormatException);
  });

  test('ciphertext falsifié rejeté', () {
    final bytes = crypto.sealWithPassword(
      vaultAvec('a', 'secret'),
      'hunter2',
      params: testParams,
    );
    bytes[bytes.length - 1] = bytes[bytes.length - 1] ^ 0x01;
    expect(
      () => crypto.open(bytes, 'hunter2'),
      throwsA(isA<WrongPasswordException>()),
    );
  });

  test('magic invalide rejeté', () {
    final bytes = crypto.sealWithPassword(
      Vault.empty,
      'hunter2',
      params: testParams,
    );
    bytes[0] = 0x00;
    expect(() => crypto.open(bytes, 'hunter2'), throwsFormatException);
  });

  test('fichier tronqué rejeté', () {
    final bytes = crypto.sealWithPassword(
      Vault.empty,
      'hunter2',
      params: testParams,
    );
    expect(
      () => crypto.open(bytes.sublist(0, 40), 'hunter2'),
      throwsFormatException,
    );
  });

  test('nonce différent à chaque scellement', () {
    final a = crypto.sealWithPassword(
      Vault.empty,
      'hunter2',
      params: testParams,
    );
    final b = crypto.sealWithPassword(
      Vault.empty,
      'hunter2',
      params: testParams,
    );
    expect(a.sublist(38, 62), isNot(b.sublist(38, 62)));
    expect(a.sublist(22, 38), isNot(b.sublist(22, 38)));
  });

  test('les paramètres KDF voyagent dans l\'en-tête', () {
    final bytes = crypto.sealWithPassword(
      Vault.empty,
      'hunter2',
      params: testParams,
    );
    final header = VaultHeader.parse(bytes);
    expect(header.params.opsLimit, testParams.opsLimit);
    expect(header.params.memLimit, testParams.memLimit);
    expect(header.version, 1);
  });

  test('la valeur en clair n\'apparaît pas dans le fichier', () {
    final bytes = crypto.sealWithPassword(
      vaultAvec('gmail', 'TRESOR'),
      'hunter2',
      params: testParams,
    );
    final brut = String.fromCharCodes(bytes);
    expect(brut.contains('TRESOR'), isFalse);
    expect(brut.contains('gmail'), isFalse);
  });

  test('mot de passe unicode utilisable', () {
    final bytes = crypto.sealWithPassword(
      vaultAvec('a', 'v'),
      'mot de passe 🔐 accentué',
      params: testParams,
    );
    expect(
      crypto.open(bytes, 'mot de passe 🔐 accentué').entries.single.value,
      'v',
    );
  });

  test('resceller avec une clé existante conserve sel et paramètres', () {
    final bytes = crypto.sealWithPassword(
      vaultAvec('a', 'v1'),
      'hunter2',
      params: testParams,
    );
    final header = VaultHeader.parse(bytes);
    final key = crypto.deriveKey('hunter2', header.salt, header.params);
    try {
      final resealed = crypto.seal(
        vaultAvec('a', 'v2'),
        key,
        header.salt,
        header.params,
      );
      expect(resealed.sublist(22, 38), header.salt);
      expect(crypto.open(resealed, 'hunter2').entries.single.value, 'v2');
    } finally {
      key.dispose();
    }
  });
}
