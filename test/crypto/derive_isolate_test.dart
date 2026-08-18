import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/crypto/vault_crypto.dart';
import 'package:safe/model/vault.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  test('la dérivation hors isolat donne la même clé que sur place', () async {
    final sodium = await SodiumSumoInit.init();
    final crypto = VaultCrypto(sodium);
    final salt = crypto.newSalt();
    const params = KdfParams(opsLimit: 1, memLimit: 8 * 1024 * 1024);

    final surPlace = crypto.deriveKey('motdepasse123', salt, params);
    final horsIsolat = await crypto.deriveKeyAsync(
      'motdepasse123',
      salt,
      params,
    );
    try {
      expect(horsIsolat.extractBytes(), surPlace.extractBytes());
    } finally {
      surPlace.dispose();
      horsIsolat.dispose();
    }
  });

  test(
    'un coffre scellé sur place s\'ouvre avec la clé venue de l\'isolat',
    () async {
      final sodium = await SodiumSumoInit.init();
      final crypto = VaultCrypto(sodium);
      const params = KdfParams(opsLimit: 1, memLimit: 8 * 1024 * 1024);
      final octets = crypto.sealWithPassword(
        Vault([VaultEntry.now(key: 'gmail', value: 'p4ss')]),
        'motdepasse123',
        params: params,
      );

      final header = VaultHeader.parse(octets);
      final key = await crypto.deriveKeyAsync(
        'motdepasse123',
        header.salt,
        header.params,
      );
      try {
        expect(crypto.openWithKey(octets, key).entries.single.key, 'gmail');
      } finally {
        key.dispose();
      }
    },
  );

  test('quand l\'isolat est désactivé, la dérivation reste correcte', () async {
    final sodium = await SodiumSumoInit.init();
    final crypto = VaultCrypto(sodium, useIsolate: false);
    final salt = Uint8List(VaultHeader.saltLength);
    const params = KdfParams(opsLimit: 1, memLimit: 8 * 1024 * 1024);
    final a = await crypto.deriveKeyAsync('motdepasse123', salt, params);
    final b = crypto.deriveKey('motdepasse123', salt, params);
    try {
      expect(a.extractBytes(), b.extractBytes());
    } finally {
      a.dispose();
      b.dispose();
    }
  });
}
