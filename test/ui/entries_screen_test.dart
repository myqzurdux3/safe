import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/ui/entries_screen.dart';

import '../support/session_fixture.dart';

void main() {
  testWidgets('les clefs apparaissent, les valeurs restent masquées', (
    tester,
  ) async {
    final session = await makeUnlockedSession(keys: ['gmail', 'banque']);
    await tester.pumpWidget(wrapScreen(EntriesScreen(session: session)));
    expect(find.text('gmail'), findsOneWidget);
    expect(find.text('banque'), findsOneWidget);
    expect(find.text('p4ss-gmail'), findsNothing);
    session.lock();
  });

  testWidgets('la recherche filtre la liste', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail', 'banque']);
    await tester.pumpWidget(wrapScreen(EntriesScreen(session: session)));
    await tester.enterText(find.byKey(const Key('search')), 'gma');
    await tester.pumpAndSettle();
    expect(find.text('gmail'), findsOneWidget);
    expect(find.text('banque'), findsNothing);
    session.lock();
  });

  testWidgets('coffre vide: invite affichée', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(wrapScreen(EntriesScreen(session: session)));
    expect(find.textContaining('Aucune entrée'), findsOneWidget);
    session.lock();
  });

  testWidgets('recherche sans résultat: message dédié', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(wrapScreen(EntriesScreen(session: session)));
    await tester.enterText(find.byKey(const Key('search')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucun résultat'), findsOneWidget);
    session.lock();
  });

  testWidgets('révéler affiche la valeur', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(wrapScreen(EntriesScreen(session: session)));
    await tester.tap(find.byKey(const Key('reveal-gmail')));
    await tester.pumpAndSettle();
    expect(find.text('p4ss-gmail'), findsOneWidget);
    session.lock();
  });

  testWidgets('suppression demande confirmation puis retire l\'entrée', (
    tester,
  ) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(wrapScreen(EntriesScreen(session: session)));
    await tester.tap(find.byKey(const Key('delete-gmail')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Supprimer'), findsWidgets);
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(session.vault!.entries, isEmpty);
    expect(find.text('gmail'), findsNothing);
    session.lock();
  });

  testWidgets('annuler la suppression conserve l\'entrée', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(wrapScreen(EntriesScreen(session: session)));
    await tester.tap(find.byKey(const Key('delete-gmail')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-delete')));
    await tester.pumpAndSettle();
    expect(session.vault!.entries.single.key, 'gmail');
    session.lock();
  });

  testWidgets('le bouton verrouiller ferme la session', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(wrapScreen(EntriesScreen(session: session)));
    await tester.tap(find.byKey(const Key('lock')));
    await tester.pumpAndSettle();
    expect(session.isUnlocked, isFalse);
    session.lock();
  });
}
