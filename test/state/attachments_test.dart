import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/crypto/vault_crypto.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';

import '../support/session_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Uint8List contenu([int taille = 2048]) =>
      Uint8List.fromList([for (var i = 0; i < taille; i++) i % 251]);

  Future<VaultAttachment> joindre(
    VaultSession session, {
    String entryKey = 'passeport',
    String name = 'photo.jpg',
    String mimeType = 'image/jpeg',
    Uint8List? bytes,
  }) => session.attach(
    entryKey: entryKey,
    name: name,
    mimeType: mimeType,
    bytes: bytes ?? contenu(),
  );

  test(
    'joindre un fichier: métadonnées dans le coffre, contenu dehors',
    () async {
      final blobs = MemoryBlobStore();
      final session = await makeUnlockedSession(
        keys: ['passeport'],
        blobs: blobs,
      );
      final attachment = await joindre(session);

      expect(attachment.name, 'photo.jpg');
      expect(attachment.size, 2048);
      expect(
        session.vault!.entries.single.attachments.single.id,
        attachment.id,
      );
      expect(blobs.contents.keys, [attachment.id]);
      // Le blob est chiffré: son en-tête est celui d'une pièce jointe, et le
      // contenu en clair ne s'y trouve pas.
      final blob = blobs.contents[attachment.id]!;
      expect(String.fromCharCodes(blob.sublist(0, 8)), 'SAFEBLB1');
      expect(blob.length, greaterThan(2048));
      session.lock();
    },
  );

  test('relire une pièce jointe rend le contenu d\'origine', () async {
    final session = await makeUnlockedSession(keys: ['passeport']);
    final attachment = await joindre(session, bytes: contenu(5000));
    expect(await session.readAttachment(attachment), contenu(5000));
    session.lock();
  });

  test('les pièces jointes survivent au verrouillage', () async {
    final store = MemoryVaultStore();
    final blobs = MemoryBlobStore();
    final session = await makeUnlockedSession(
      keys: ['passeport'],
      store: store,
      blobs: blobs,
    );
    final attachment = await joindre(session);
    session.lock();
    await session.unlock(testPassword);
    expect(session.vault!.entries.single.attachments.single.name, 'photo.jpg');
    expect(await session.readAttachment(attachment), contenu());
    session.lock();
  });

  test('un fichier trop gros est refusé et rien n\'est écrit', () async {
    final blobs = MemoryBlobStore();
    final session = await makeUnlockedSession(
      keys: ['passeport'],
      blobs: blobs,
    );
    await expectLater(
      joindre(session, bytes: Uint8List(maxAttachmentBytes + 1)),
      throwsA(isA<AttachmentTooLargeException>()),
    );
    expect(blobs.contents, isEmpty);
    expect(session.vault!.entries.single.attachments, isEmpty);
    session.lock();
  });

  test('joindre à une clef inconnue est une erreur', () async {
    final session = await makeUnlockedSession(keys: ['passeport']);
    await expectLater(
      joindre(session, entryKey: 'inexistante'),
      throwsStateError,
    );
    session.lock();
  });

  test('supprimer une pièce jointe efface son blob', () async {
    final blobs = MemoryBlobStore();
    final session = await makeUnlockedSession(
      keys: ['passeport'],
      blobs: blobs,
    );
    final attachment = await joindre(session);
    await session.removeAttachment(
      entryKey: 'passeport',
      attachment: attachment,
    );
    expect(session.vault!.entries.single.attachments, isEmpty);
    expect(blobs.contents, isEmpty);
    session.lock();
  });

  test('supprimer une entrée efface ses pièces jointes', () async {
    final blobs = MemoryBlobStore();
    final session = await makeUnlockedSession(
      keys: ['passeport'],
      blobs: blobs,
    );
    await joindre(session);
    await joindre(session, name: 'scan.pdf', mimeType: 'application/pdf');
    await session.deleteEntry('passeport');
    expect(session.vault!.entries, isEmpty);
    expect(blobs.contents, isEmpty);
    session.lock();
  });

  test('deux pièces jointes ont des identifiants distincts', () async {
    final session = await makeUnlockedSession(keys: ['passeport']);
    final a = await joindre(session);
    final b = await joindre(session, name: 'autre.jpg');
    expect(a.id, isNot(b.id));
    expect(session.vault!.entries.single.attachments, hasLength(2));
    session.lock();
  });

  test('les blobs orphelins sont effacés au déverrouillage', () async {
    final store = MemoryVaultStore();
    final blobs = MemoryBlobStore();
    final session = await makeUnlockedSession(
      keys: ['passeport'],
      store: store,
      blobs: blobs,
    );
    final attachment = await joindre(session);
    // Un blob qu'aucune entrée ne référence: reste d'une écriture interrompue.
    await blobs.put('orphelin', Uint8List.fromList([1, 2, 3]));
    session.lock();
    await session.unlock(testPassword);
    expect(blobs.contents.keys, [attachment.id]);
    session.lock();
  });

  test('une pièce jointe abîmée est signalée, pas rendue en clair', () async {
    final blobs = MemoryBlobStore();
    final session = await makeUnlockedSession(
      keys: ['passeport'],
      blobs: blobs,
    );
    final attachment = await joindre(session);
    final blob = blobs.contents[attachment.id]!;
    blob[blob.length - 1] = blob[blob.length - 1] ^ 0x01;
    await expectLater(
      session.readAttachment(attachment),
      throwsA(isA<WrongPasswordException>()),
    );
    session.lock();
  });
}
