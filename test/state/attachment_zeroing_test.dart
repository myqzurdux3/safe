import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/state/vault_session.dart';

import '../support/session_fixture.dart';

void main() {
  test('le tampon en clair d\'une pièce jointe est effacé après chiffrement',
      () async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    final clair = Uint8List.fromList([1, 2, 3, 4, 5]);

    await session.attach(
      entryKey: 'gmail',
      name: 'note.txt',
      mimeType: 'text/plain',
      bytes: clair,
    );

    // Le contenu vient d'un fichier choisi par l'utilisateur; une fois chiffré
    // et écrit, il n'a plus aucune raison de traîner sur le tas.
    expect(clair, everyElement(0));
    session.lock();
  });

  test('la pièce jointe reste lisible après cet effacement', () async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    final attachment = await session.attach(
      entryKey: 'gmail',
      name: 'note.txt',
      mimeType: 'text/plain',
      bytes: Uint8List.fromList([7, 8, 9]),
    );
    expect(await session.readAttachment(attachment), [7, 8, 9]);
    session.lock();
  });

  test('un fichier trop gros est refusé sans être effacé', () async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    final trop = Uint8List(maxAttachmentBytes + 1)..[0] = 42;
    await expectLater(
      session.attach(
        entryKey: 'gmail',
        name: 'gros.bin',
        mimeType: 'application/octet-stream',
        bytes: trop,
      ),
      throwsA(isA<AttachmentTooLargeException>()),
    );
    // Rien n'a été chiffré, donc rien à effacer: le tampon appartient encore à
    // l'appelant, qui peut vouloir en faire autre chose.
    expect(trop[0], 42);
    session.lock();
  });
}
