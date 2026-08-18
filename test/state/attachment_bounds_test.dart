import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/state/vault_session.dart';

import '../support/session_fixture.dart';

void main() {
  test(
    'une pièce jointe démesurée sur le disque est refusée à la lecture',
    () async {
      final blobs = MemoryBlobStore();
      final session = await makeUnlockedSession(keys: ['gmail'], blobs: blobs);
      final attachment = await session.attach(
        entryKey: 'gmail',
        name: 'note.txt',
        mimeType: 'text/plain',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      // Le plafond n'était vérifié qu'à l'écriture: un blob importé ou abîmé
      // était déchiffré d'un bloc, quelle que soit sa taille.
      blobs.contents[attachment.id] = Uint8List(maxAttachmentBytes + 4096);

      await expectLater(
        session.readAttachment(attachment),
        throwsA(isA<AttachmentTooLargeException>()),
      );
      session.lock();
    },
  );

  test('une pièce jointe de taille normale se relit', () async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    final attachment = await session.attach(
      entryKey: 'gmail',
      name: 'note.txt',
      mimeType: 'text/plain',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    expect(await session.readAttachment(attachment), [1, 2, 3]);
    session.lock();
  });
}
