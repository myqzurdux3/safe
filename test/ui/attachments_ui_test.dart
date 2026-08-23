import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/ui/entry_screen.dart';
import 'package:safe/ui/new_entry_screen.dart';
import 'package:safe/ui/vault_tab.dart';

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

  Widget fiche(VaultSession session) => wrapScreen(
    EntryScreen(
      session: session,
      entry: session.vault!.entries.single,
      settings: MemorySettingsStore(),
    ),
  );

  /// Les pièces jointes de la fiche vivent dans une feuille modale.
  Future<void> ouvrirLesPiecesJointes(WidgetTester tester) async {
    await tester.tap(find.text('Pièce jointe'));
    await tester.pumpAndSettle();
  }

  testWidgets('en lecture, la valeur n\'est pas modifiable; en texte brut, '
      'elle est multiligne', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(fiche(session));
    await tester.pumpAndSettle();
    // La fiche s'ouvre en lecture: il n'y a pas de champ du tout, donc rien
    // qu'un geste malheureux puisse écraser.
    expect(find.byKey(const Key('raw')), findsNothing);

    await tester.tap(find.text('Texte brut'));
    await tester.pumpAndSettle();
    final champ = tester.widget<TextField>(find.byKey(const Key('raw')));
    expect(champ.maxLines, isNull);
    expect(champ.controller!.text, 'p4ss-gmail');
    session.lock();
  });

  testWidgets('en création, le texte est directement saisissable', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(
      wrapScreen(
        NewEntryScreen(session: session, settings: MemorySettingsStore()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('raw')), findsOneWidget);
    session.lock();
  });

  testWidgets('une valeur multiligne est enregistrée telle quelle', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(
      wrapScreen(
        NewEntryScreen(session: session, settings: MemorySettingsStore()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name')), 'note');
    await tester.enterText(
      find.byKey(const Key('raw')),
      'ligne 1\nligne 2\nligne 3',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(session.vault!.entries.single.value, 'ligne 1\nligne 2\nligne 3');
    session.lock();
  });

  testWidgets('la fiche garde les lignes d\'un texte multiligne', (
    tester,
  ) async {
    // La liste n'aperçoit plus rien: c'est la fiche qui porte le texte, et
    // elle le porte entier. L'aperçu rogné à la première ligne n'a plus lieu
    // d'être, mais les lignes suivantes, elles, ne doivent pas se perdre.
    final session = await makeUnlockedSession();
    await session.save(
      session.vault!.upsert(
        VaultEntry.now(key: 'note', value: 'première\nseconde\ntroisième'),
      ),
    );
    await tester.pumpWidget(fiche(session));
    await tester.pumpAndSettle();
    expect(find.textContaining('première'), findsOneWidget);
    expect(find.textContaining('seconde'), findsOneWidget);
    expect(find.textContaining('troisième'), findsOneWidget);
    session.lock();
  });

  testWidgets('les pièces jointes apparaissent dans la fiche', (tester) async {
    final session = await sessionAvecPieceJointe();
    await tester.pumpWidget(fiche(session));
    await tester.pumpAndSettle();
    await ouvrirLesPiecesJointes(tester);
    expect(find.text('photo.jpg'), findsOneWidget);
    expect(find.textContaining('2,0 ko'), findsOneWidget);
    session.lock();
  });

  testWidgets('supprimer une pièce jointe la retire du coffre et du disque', (
    tester,
  ) async {
    final blobs = MemoryBlobStore();
    final session = await sessionAvecPieceJointe(blobs: blobs);
    final attachment = session.vault!.entries.single.attachments.single;
    await tester.pumpWidget(fiche(session));
    await tester.pumpAndSettle();
    await ouvrirLesPiecesJointes(tester);
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
    await tester.pumpWidget(fiche(session));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Texte brut'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('raw')), 'nouvelle valeur');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(session.vault!.entries.single.value, 'nouvelle valeur');
    expect(session.vault!.entries.single.attachments, hasLength(1));
    session.lock();
  });

  testWidgets('renommer une entrée conserve ses pièces jointes', (
    tester,
  ) async {
    final session = await sessionAvecPieceJointe();
    final avant = session.vault!.entries.single;
    await tester.pumpWidget(fiche(session));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name')), 'papiers');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final apres = session.vault!.entries.single;
    expect(apres.key, 'papiers');
    expect(apres.attachments, hasLength(1));
    // La date de création suit la fiche: un renommage n'est pas une naissance.
    expect(apres.created, avant.created);
    session.lock();
  });

  testWidgets('la liste signale les entrées qui ont des pièces jointes', (
    tester,
  ) async {
    final session = await sessionAvecPieceJointe();
    await tester.pumpWidget(
      wrapScreen(
        Scaffold(
          body: VaultTab(session: session, onOpen: (_) {}),
        ),
      ),
    );
    expect(find.byKey(const Key('has-attachments-passeport')), findsOneWidget);
    session.lock();
  });

  testWidgets('supprimer une entrée efface aussi ses pièces jointes', (
    tester,
  ) async {
    final blobs = MemoryBlobStore();
    final session = await sessionAvecPieceJointe(blobs: blobs);
    await tester.pumpWidget(fiche(session));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(session.vault!.entries, isEmpty);
    expect(blobs.contents, isEmpty);
    session.lock();
  });
}
