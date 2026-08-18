import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/storage/blob_store.dart';
import 'package:safe/storage/vault_file.dart';
import 'package:safe/util/clipboard.dart';

import '../support/session_fixture.dart';

void main() {
  late Directory dir;
  late Directory blobsDir;
  late VaultSession session;

  String id(int n) => n.toRadixString(16).padLeft(32, '0');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('safe_orphelins');
    blobsDir = Directory('${dir.path}/blobs');
    session = VaultSession(
      crypto: await testCrypto(),
      storage: VaultFile(dir),
      blobs: BlobFileStore(blobsDir),
      clipboard: SecureClipboard(),
      autoLockDelay: const Duration(minutes: 10),
      kdfParams: testKdfParams,
    );
    addTearDown(session.dispose);
  });

  tearDown(() async => dir.delete(recursive: true));

  test(
    'un blob qu\'aucune entrée ne référence est mis de côté, pas effacé',
    () async {
      await session.create(testPassword);
      session.lock();
      // Simule ce que laisse un import: un blob de l'ancien coffre, que le
      // nouveau ne référence pas. C'est le seul chemin de synchronisation entre
      // Linux et Android, et l'export ne contient pas les pièces jointes.
      await BlobFileStore(blobsDir).put(id(1), Uint8List.fromList([1, 2, 3]));

      await session.unlock(testPassword);

      expect(File('${blobsDir.path}/${id(1)}.blob').existsSync(), isFalse);
      expect(
        File('${blobsDir.path}/orphelins/${id(1)}.blob').existsSync(),
        isTrue,
        reason: 'le contenu a été détruit au lieu d\'être mis de côté',
      );
    },
  );

  test('un temporaire abandonné est bien effacé, lui', () async {
    await session.create(testPassword);
    session.lock();
    // Un `put` interrompu laisse ça: contenu incomplet, référencé par personne.
    await blobsDir.create(recursive: true);
    final temporaire = File('${blobsDir.path}/${id(2)}.blob.tmp');
    await temporaire.writeAsBytes([9]);

    await session.unlock(testPassword);

    expect(temporaire.existsSync(), isFalse);
  });

  test('un blob référencé n\'est pas touché', () async {
    await session.create(testPassword);
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: 'gmail', value: 'p4ss')),
    );
    final attachment = await session.attach(
      entryKey: 'gmail',
      name: 'note.txt',
      mimeType: 'text/plain',
      bytes: Uint8List.fromList([1]),
    );
    session.lock();
    await session.unlock(testPassword);

    expect(File('${blobsDir.path}/${attachment.id}.blob').existsSync(), isTrue);
  });
}
