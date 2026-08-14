import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/ui/entries_screen.dart';
import 'package:safe/ui/entry_edit_screen.dart';

import '../support/session_fixture.dart';

void main() {
  Future<VaultSession> sessionAvecPieceJointe({
    String name = 'photo.jpg',
    String mime = 'image/jpeg',
    MemoryBlobStore? blobs,
  }) async {
    final session = await makeUnlockedSession(
      keys: ['passeport'],
      blobs: blobs,
    );
    await session.attach(
      entryKey: 'passeport',
      name: name,
      mimeType: mime,
      bytes: Uint8List.fromList(List.filled(2048, 7)),
    );
    return session;
  }

  testWidgets('masquée, la valeur n\'est pas modifiable; révélée, elle est '
      'multiligne', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    final entry = session.vault!.entries.single;
    await tester.pumpWidget(
      wrapScreen(EntryEditScreen(session: session, existing: entry)),
    );
    // Un champ masqué serait forcément sur une ligne, donc destructeur pour
    // une valeur multiligne: masquée, la valeur n'est pas un champ du tout.
    expect(find.byKey(const Key('value')), findsNothing);
    expect(find.byKey(const Key('value-masked')), findsOneWidget);

    await tester.tap(find.byKey(const Key('toggle-value')));
    await tester.pumpAndSettle();
    final champ = tester.widget<TextField>(find.byKey(const Key('value')));
    expect(champ.maxLines, isNull);
    expect(champ.controller!.text, 'p4ss-gmail');
    session.lock();
  });

  testWidgets('en création, la valeur est directement saisissable', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(wrapScreen(EntryEditScreen(session: session)));
    expect(find.byKey(const Key('value')), findsOneWidget);
    session.lock();
  });

  testWidgets('une valeur multiligne est enregistrée telle quelle', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(wrapScreen(EntryEditScreen(session: session)));
    await tester.enterText(find.byKey(const Key('key')), 'note');
    await tester.enterText(
      find.byKey(const Key('value')),
      'ligne 1\nligne 2\nligne 3',
    );
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(session.vault!.entries.single.value, 'ligne 1\nligne 2\nligne 3');
    session.lock();
  });

  testWidgets('la liste ne montre que la première ligne', (tester) async {
    final session = await makeUnlockedSession();
    await session.save(
      session.vault!.upsert(
        VaultEntry.now(key: 'note', value: 'première\nseconde\ntroisième'),
      ),
    );
    await tester.pumpWidget(wrapScreen(EntriesScreen(session: session)));
    await tester.tap(find.byKey(const Key('reveal-note')));
    await tester.pumpAndSettle();
    expect(find.textContaining('première'), findsOneWidget);
    expect(find.textContaining('seconde'), findsNothing);
    expect(find.textContaining('+2 lignes'), findsOneWidget);
    session.lock();
  });

  testWidgets('les pièces jointes apparaissent dans l\'écran d\'édition', (
    tester,
  ) async {
    final session = await sessionAvecPieceJointe();
    final entry = session.vault!.entries.single;
    await tester.pumpWidget(
      wrapScreen(EntryEditScreen(session: session, existing: entry)),
    );
    expect(find.text('photo.jpg'), findsOneWidget);
    expect(find.textContaining('2,0 ko'), findsOneWidget);
    session.lock();
  });

  testWidgets('supprimer une pièce jointe la retire du coffre et du disque', (
    tester,
  ) async {
    final blobs = MemoryBlobStore();
    final session = await sessionAvecPieceJointe(blobs: blobs);
    final entry = session.vault!.entries.single;
    final attachment = entry.attachments.single;
    await tester.pumpWidget(
      wrapScreen(EntryEditScreen(session: session, existing: entry)),
    );
    await tester.tap(find.byKey(Key('detach-${attachment.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-detach')));
    await tester.pumpAndSettle();
    expect(session.vault!.entries.single.attachments, isEmpty);
    expect(blobs.contents, isEmpty);
    session.lock();
  });

  testWidgets('modifier une entrée conserve ses pièces jointes', (
    tester,
  ) async {
    final session = await sessionAvecPieceJointe();
    final entry = session.vault!.entries.single;
    await tester.pumpWidget(
      wrapScreen(EntryEditScreen(session: session, existing: entry)),
    );
    await tester.tap(find.byKey(const Key('toggle-value')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('value')), 'nouvelle valeur');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(session.vault!.entries.single.value, 'nouvelle valeur');
    expect(session.vault!.entries.single.attachments, hasLength(1));
    session.lock();
  });

  testWidgets('renommer une entrée conserve ses pièces jointes', (
    tester,
  ) async {
    final session = await sessionAvecPieceJointe();
    final entry = session.vault!.entries.single;
    await tester.pumpWidget(
      wrapScreen(EntryEditScreen(session: session, existing: entry)),
    );
    await tester.enterText(find.byKey(const Key('key')), 'papiers');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(session.vault!.entries.single.key, 'papiers');
    expect(session.vault!.entries.single.attachments, hasLength(1));
    session.lock();
  });

  testWidgets('la liste signale les entrées qui ont des pièces jointes', (
    tester,
  ) async {
    final session = await sessionAvecPieceJointe();
    await tester.pumpWidget(wrapScreen(EntriesScreen(session: session)));
    expect(find.byKey(const Key('has-attachments-passeport')), findsOneWidget);
    session.lock();
  });

  testWidgets('supprimer une entrée efface aussi ses pièces jointes', (
    tester,
  ) async {
    final blobs = MemoryBlobStore();
    final session = await sessionAvecPieceJointe(blobs: blobs);
    await tester.pumpWidget(wrapScreen(EntriesScreen(session: session)));
    await tester.tap(find.byKey(const Key('delete-passeport')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(session.vault!.entries, isEmpty);
    expect(blobs.contents, isEmpty);
    session.lock();
  });
}
