import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/crypto/vault_crypto.dart';
import 'package:sodium/sodium_sumo.dart';

const testParams = KdfParams(opsLimit: 1, memLimit: 8 * 1024 * 1024);

void main() {
  late VaultCrypto crypto;
  late SecureKey key;
  late SecureKey autreKey;

  setUpAll(() async {
    crypto = VaultCrypto(await SodiumSumoInit.init());
    key = crypto.deriveKey('hunter2', crypto.newSalt(), testParams);
    autreKey = crypto.deriveKey('autre', crypto.newSalt(), testParams);
  });

  tearDownAll(() {
    key.dispose();
    autreKey.dispose();
  });

  Uint8List contenu() => Uint8List.fromList([for (var i = 0; i < 5000; i++) i % 251]);

  test('aller-retour d\'un fichier joint', () {
    final scelle = crypto.sealBytes(contenu(), key);
    expect(crypto.openBytes(scelle, key), contenu());
  });

  test('une autre clé ne l\'ouvre pas', () {
    final scelle = crypto.sealBytes(contenu(), key);
    expect(
      () => crypto.openBytes(scelle, autreKey),
      throwsA(isA<WrongPasswordException>()),
    );
  });

  test('contenu falsifié rejeté', () {
    final scelle = crypto.sealBytes(contenu(), key);
    scelle[scelle.length - 1] = scelle[scelle.length - 1] ^ 0x01;
    expect(
      () => crypto.openBytes(scelle, key),
      throwsA(isA<WrongPasswordException>()),
    );
  });

  test('en-tête falsifié rejeté', () {
    final scelle = crypto.sealBytes(contenu(), key);
    scelle[8] = scelle[8] ^ 0x01; // version
    expect(() => crypto.openBytes(scelle, key), throwsFormatException);
  });

  test('un blob n\'est pas un coffre et réciproquement', () {
    final blob = crypto.sealBytes(contenu(), key);
    expect(() => crypto.openWithKey(blob, key), throwsFormatException);
  });

  test('nonce différent à chaque scellement', () {
    final a = crypto.sealBytes(contenu(), key);
    final b = crypto.sealBytes(contenu(), key);
    expect(a.sublist(9, 33), isNot(b.sublist(9, 33)));
  });

  test('le contenu en clair n\'apparaît pas dans le blob', () {
    final clair = Uint8List.fromList('SECRET-DOCUMENT'.codeUnits);
    final scelle = crypto.sealBytes(clair, key);
    expect(String.fromCharCodes(scelle).contains('SECRET-DOCUMENT'), isFalse);
  });

  test('blob tronqué rejeté', () {
    final scelle = crypto.sealBytes(contenu(), key);
    expect(
      () => crypto.openBytes(scelle.sublist(0, 20), key),
      throwsFormatException,
    );
  });

  test('contenu vide accepté', () {
    final scelle = crypto.sealBytes(Uint8List(0), key);
    expect(crypto.openBytes(scelle, key), isEmpty);
  });
}
