import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/crypto/vault_crypto.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/storage/blob_store.dart';
import 'package:safe/storage/vault_file.dart';
import 'package:safe/util/clipboard.dart';

import '../support/session_fixture.dart';

void main() {
  late Directory dir;
  late VaultFile storage;
  late VaultSession session;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('safe_bak');
    storage = VaultFile(dir);
    session = VaultSession(
      crypto: await testCrypto(),
      storage: storage,
      blobs: BlobFileStore(Directory('${dir.path}/blobs')),
      clipboard: SecureClipboard(),
      autoLockDelay: const Duration(minutes: 10),
      kdfParams: testKdfParams,
    );
    addTearDown(session.dispose);
  });

  tearDown(() async => dir.delete(recursive: true));

  test('changer de mot de passe ne laisse pas l\'ancien ouvrir la sauvegarde',
      () async {
    await session.create(testPassword);
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: 'gmail', value: 'p4ss')),
    );
    expect(storage.backupFile.existsSync(), isTrue);

    await session.changePassword('nouveaumotdepasse');

    // Changer de mot de passe se fait souvent parce que l'ancien a fuité.
    // Une copie que l'ancien mot de passe ouvre encore annule l'opération.
    if (storage.backupFile.existsSync()) {
      final crypto = await testCrypto();
      final bak = await storage.backupFile.readAsBytes();
      expect(
        () => crypto.open(bak, testPassword),
        throwsA(isA<WrongPasswordException>()),
        reason: 'l\'ancien mot de passe ouvre encore vault.safe.bak',
      );
    }
  });

  test('une sauvegarde ordinaire garde bien la génération précédente',
      () async {
    await session.create(testPassword);
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: 'gmail', value: 'p4ss')),
    );
    final crypto = await testCrypto();
    final precedent = crypto.open(
      await storage.backupFile.readAsBytes(),
      testPassword,
    );
    expect(precedent.entries, isEmpty);
  });
}
