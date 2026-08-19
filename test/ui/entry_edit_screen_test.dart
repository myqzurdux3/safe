import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/ui/entry_edit_screen.dart';

import '../support/session_fixture.dart';

void main() {
  testWidgets('entrée ajoutée: elle rejoint le coffre', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(wrapScreen(EntryEditScreen(session: session)));
    await tester.enterText(find.byKey(const Key('key')), 'gmail');
    await tester.enterText(find.byKey(const Key('value')), 'p4ss');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(session.vault!.entries.single.key, 'gmail');
    expect(session.vault!.entries.single.value, 'p4ss');
    session.lock();
  });

  testWidgets('clef vide refusée', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(wrapScreen(EntryEditScreen(session: session)));
    await tester.enterText(find.byKey(const Key('value')), 'p4ss');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('clef'), findsWidgets);
    expect(session.vault!.entries, isEmpty);
    session.lock();
  });

  testWidgets('clef déjà prise refusée en création', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(wrapScreen(EntryEditScreen(session: session)));
    await tester.enterText(find.byKey(const Key('key')), 'gmail');
    await tester.enterText(find.byKey(const Key('value')), 'x');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('existe déjà'), findsOneWidget);
    expect(session.vault!.entries.single.value, 'p4ss-gmail');
    session.lock();
  });

  testWidgets('modification: la même clef est acceptée', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    final existing = session.vault!.entries.single;
    await tester.pumpWidget(
      wrapScreen(EntryEditScreen(session: session, existing: existing)),
    );
    // Une entrée existante s'ouvre masquée: la valeur n'est modifiable
    // qu'une fois révélée.
    await tester.tap(find.byKey(const Key('toggle-value')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('value')), 'nouvelle');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(session.vault!.entries.single.value, 'nouvelle');
    session.lock();
  });

  testWidgets('le générateur remplit le champ valeur', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(wrapScreen(EntryEditScreen(session: session)));
    await tester.tap(find.byKey(const Key('generate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('generate-confirm')));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byKey(const Key('value')));
    expect(field.controller!.text.length, greaterThanOrEqualTo(12));
    session.lock();
  });

  testWidgets(
    'le curseur du générateur ne dépasse jamais ce que le générateur accepte',
    (tester) async {
      final session = await makeUnlockedSession();
      await tester.pumpWidget(wrapScreen(EntryEditScreen(session: session)));
      await tester.tap(find.byKey(const Key('generate')));
      await tester.pumpAndSettle();
      // Pousse le curseur à fond à droite: la borne affichée doit être celle
      // que `generatePassword` accepte réellement, pas un vestige de l'ancienne
      // borne à 128.
      await tester.drag(
        find.byKey(const Key('generate-length')),
        const Offset(1000, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('generate-confirm')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      session.lock();
    },
  );

  testWidgets('valeur vide acceptée', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(wrapScreen(EntryEditScreen(session: session)));
    await tester.enterText(find.byKey(const Key('key')), 'note');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(session.vault!.entries.single, isA<VaultEntry>());
    expect(session.vault!.entries.single.value, '');
    session.lock();
  });
}
