import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/crypto/vault_crypto.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/storage/vault_file.dart';
import 'package:safe/storage/vault_transfer.dart';
import 'package:sodium/sodium_sumo.dart';

const testParams = KdfParams(opsLimit: 1, memLimit: 8 * 1024 * 1024);

void main() {
  late VaultCrypto crypto;
  late Directory dir;
  late VaultFile storage;
  late VaultTransfer transfer;

  setUpAll(() async {
    crypto = VaultCrypto(await SodiumSumoInit.init());
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('safe_transfer');
    storage = VaultFile(dir);
    transfer = VaultTransfer(crypto: crypto, storage: storage);
    await storage.write(
      crypto.sealWithPassword(
        Vault.empty.upsert(VaultEntry.now(key: 'local', value: 'original')),
        'hunter2',
        params: testParams,
      ),
    );
  });

  tearDown(() async => dir.delete(recursive: true));

  Uint8List coffreEtranger() => crypto.sealWithPassword(
    Vault.empty.upsert(VaultEntry.now(key: 'venu', value: 'importé')),
    'autre',
    params: testParams,
  );

  test('export rend exactement les octets du fichier', () async {
    expect(await transfer.exportBytes(), await storage.read());
  });

  test('import avec mauvais mot de passe ne touche pas au coffre', () async {
    await expectLater(
      transfer.importBytes(coffreEtranger(), 'faux'),
      throwsA(isA<WrongPasswordException>()),
    );
    expect(
      crypto.open(await storage.read(), 'hunter2').entries.single.value,
      'original',
    );
  });

  test('fichier étranger sans magic rejeté, coffre intact', () async {
    await expectLater(
      transfer.importBytes(Uint8List.fromList([9, 9, 9]), 'hunter2'),
      throwsFormatException,
    );
    expect(
      crypto.open(await storage.read(), 'hunter2').entries.single.value,
      'original',
    );
  });

  test('import valide remplace le coffre et garde un .bak', () async {
    await transfer.importBytes(coffreEtranger(), 'autre');
    expect(
      crypto.open(await storage.read(), 'autre').entries.single.value,
      'importé',
    );
    expect(await storage.backupFile.exists(), isTrue);
    expect(
      crypto.open(await storage.backupFile.readAsBytes(), 'hunter2')
          .entries
          .single
          .value,
      'original',
    );
  });
}
