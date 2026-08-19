import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/ui/home_screen.dart';
import 'package:safe/ui/theme/safe_theme.dart';

import '../support/session_fixture.dart';

Widget _accueil(VaultSession session) => MaterialApp(
  theme: safeLightTheme(),
  home: HomeScreen(session: session, settings: MemorySettingsStore()),
);

void main() {
  testWidgets('les deux onglets sont là, Coffre d\'abord', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(_accueil(session));
    await tester.pumpAndSettle();

    expect(find.text('Coffre'), findsOneWidget);
    expect(find.text('Générateur'), findsOneWidget);
    expect(find.text('gmail'), findsOneWidget);
    session.lock();
  });

  testWidgets('l\'onglet Générateur montre une valeur et ses réglages', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_accueil(session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Générateur'));
    await tester.pumpAndSettle();

    expect(find.text('Copier'), findsOneWidget);
    expect(find.text('Lettres'), findsOneWidget);
    expect(find.text('+ chiffres'), findsOneWidget);
    expect(find.text('+ symboles'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    session.lock();
  });

  testWidgets('« Nouvelle fiche » est visible sur les deux onglets', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_accueil(session));
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle fiche'), findsOneWidget);
    await tester.tap(find.text('Générateur'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle fiche'), findsOneWidget);
    session.lock();
  });

  testWidgets('la recherche trouve un intertitre de bloc', (tester) async {
    final session = await makeUnlockedSession();
    await session.save(
      session.vault!.upsert(
        VaultEntry.now(key: 'comptes', value: 'courrier:\nvaleur'),
      ),
    );
    await tester.pumpWidget(_accueil(session));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search')), 'courri');
    await tester.pumpAndSettle();

    expect(find.text('comptes'), findsOneWidget);
    expect(find.textContaining('courrier'), findsWidgets);
    session.lock();
  });

  testWidgets('coffre vide: une invite, pas une liste blanche', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_accueil(session));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aucune'), findsOneWidget);
    session.lock();
  });
}
