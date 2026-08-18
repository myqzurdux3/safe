import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/crypto/vault_crypto.dart';

void main() {
  /// Un en-tête de coffre valide, sauf les paramètres de dérivation.
  Uint8List entete({required int opsLimit, required int memLimit}) {
    final header = VaultHeader(
      version: VaultHeader.formatVersion,
      params: KdfParams(opsLimit: opsLimit, memLimit: memLimit),
      salt: Uint8List(VaultHeader.saltLength),
      nonce: Uint8List(VaultHeader.nonceLength),
    );
    return Uint8List(VaultHeader.length + 16)
      ..setRange(0, VaultHeader.length, header.toBytes());
  }

  test('les paramètres par défaut passent', () {
    final params = KdfParams.defaults;
    expect(
      () => VaultHeader.parse(
        entete(opsLimit: params.opsLimit, memLimit: params.memLimit),
      ),
      returnsNormally,
    );
  });

  test('un memLimit démesuré est refusé avant toute dérivation', () {
    // Argon2id tourne avec les paramètres du fichier *avant* que le tag AEAD
    // ne soit vérifié: un fichier hostile ne doit pas pouvoir demander une
    // allocation qui tue le processus à la simple tentative d'ouverture.
    expect(
      () => VaultHeader.parse(entete(opsLimit: 3, memLimit: 512 * 1024 * 1024)),
      throwsFormatException,
    );
  });

  test('un opsLimit démesuré est refusé', () {
    expect(
      () => VaultHeader.parse(
        entete(opsLimit: 24, memLimit: KdfParams.defaults.memLimit),
      ),
      throwsFormatException,
    );
  });
}
