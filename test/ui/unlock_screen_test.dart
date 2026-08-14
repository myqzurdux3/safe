import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/ui/unlock_screen.dart';

import '../support/session_fixture.dart';

void main() {
  testWidgets('création: la confirmation doit correspondre', (tester) async {
    final session = await makeTestSession();
    await tester.pumpWidget(
      wrapScreen(UnlockScreen(session: session, isCreation: true)),
    );
    await tester.enterText(find.byKey(const Key('password')), testPassword);
    await tester.enterText(find.byKey(const Key('confirm')), 'autre chose');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
    expect(session.isUnlocked, isFalse);
  });

  testWidgets('création: mot de passe trop court refusé', (tester) async {
    final session = await makeTestSession();
    await tester.pumpWidget(
      wrapScreen(UnlockScreen(session: session, isCreation: true)),
    );
    await tester.enterText(find.byKey(const Key('password')), 'court');
    await tester.enterText(find.byKey(const Key('confirm')), 'court');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('12 caractères'), findsOneWidget);
    expect(session.isUnlocked, isFalse);
  });

  testWidgets('création: l\'avertissement sur la perte est affiché', (
    tester,
  ) async {
    final session = await makeTestSession();
    await tester.pumpWidget(
      wrapScreen(UnlockScreen(session: session, isCreation: true)),
    );
    expect(find.textContaining('aucun moyen de récupérer'), findsOneWidget);
  });

  testWidgets('création: un mot de passe valide ouvre le coffre', (
    tester,
  ) async {
    final session = await makeTestSession();
    await tester.pumpWidget(
      wrapScreen(UnlockScreen(session: session, isCreation: true)),
    );
    await tester.enterText(find.byKey(const Key('password')), testPassword);
    await tester.enterText(find.byKey(const Key('confirm')), testPassword);
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(session.isUnlocked, isTrue);
    // Verrouiller avant la fin du test: une session ouverte laisse la minuterie
    // d'auto-lock en attente, ce que le harnais de test refuse.
    session.lock();
  });

  testWidgets('déverrouillage: mauvais mot de passe, erreur générique', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    session.lock();
    await tester.pumpWidget(
      wrapScreen(UnlockScreen(session: session, isCreation: false)),
    );
    expect(find.byKey(const Key('confirm')), findsNothing);
    await tester.enterText(find.byKey(const Key('password')), 'faux');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(find.text('Mot de passe incorrect'), findsOneWidget);
    expect(session.isUnlocked, isFalse);
  });

  testWidgets('déverrouillage: le bon mot de passe ouvre le coffre', (
    tester,
  ) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    session.lock();
    await tester.pumpWidget(
      wrapScreen(UnlockScreen(session: session, isCreation: false)),
    );
    await tester.enterText(find.byKey(const Key('password')), testPassword);
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(session.isUnlocked, isTrue);
    expect(session.vault!.entries.single.key, 'gmail');
    session.lock();
  });
}
