import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
    dir = await Directory.systemTemp.createTemp('safe_restore');
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
    await session.create(testPassword);
  });

  tearDown(() async => dir.delete(recursive: true));

  test('sans sauvegarde, il n\'y a rien à restaurer', () async {
    expect(await session.previousEntryCount(), isNull);
  });

  test('la sauvegarde annonce ce qu\'elle contient', () async {
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: 'gmail', value: 'p4ss')),
    );
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: 'banque', value: 's3cret')),
    );
    // La copie date d'avant la dernière sauvegarde: une seule entrée.
    expect(await session.previousEntryCount(), 1);
  });

  test('restaurer ramène l\'état précédent', () async {
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: 'gmail', value: 'p4ss')),
    );
    await session.save(session.vault!.remove('gmail'));
    expect(session.vault!.entries, isEmpty);

    await session.restorePrevious();

    expect(session.vault!.entries.single.key, 'gmail');
    // Et le coffre sur le disque suit: ce n'est pas qu'un état en mémoire.
    session.lock();
    await session.unlock(testPassword);
    expect(session.vault!.entries.single.key, 'gmail');
  });

  test('restaurer garde de quoi annuler', () async {
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: 'gmail', value: 'p4ss')),
    );
    await session.save(session.vault!.remove('gmail'));
    await session.restorePrevious();
    // La restauration a elle-même produit une copie: on peut revenir en arrière.
    expect(await session.previousEntryCount(), 0);
  });

  test('sur un coffre verrouillé, restaurer lève', () async {
    session.lock();
    await expectLater(session.restorePrevious(), throwsStateError);
  });

  test('une sauvegarde abîmée est signalée, pas appliquée', () async {
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: 'gmail', value: 'p4ss')),
    );
    await storage.backupFile.writeAsBytes(List.filled(200, 0));

    expect(await session.previousEntryCount(), isNull);
    await expectLater(session.restorePrevious(), throwsA(isA<Exception>()));
    // Le coffre courant est intact.
    expect(session.vault!.entries.single.key, 'gmail');
  });
}
