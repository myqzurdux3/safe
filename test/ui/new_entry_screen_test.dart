import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/ui/new_entry_screen.dart';
import 'package:safe/ui/theme/safe_theme.dart';

import '../support/session_fixture.dart';

Widget _ecran(VaultSession session) => MaterialApp(
  theme: safeLightTheme(),
  home: NewEntryScreen(session: session, settings: MemorySettingsStore()),
);

void main() {
  testWidgets('le compteur part de zéro et suit la frappe', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    expect(find.text('0 bloc · 0 ligne'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('raw')), 'a:\nun\ndeux');
    await tester.pumpAndSettle();
    expect(find.text('1 bloc · 2 lignes'), findsOneWidget);
    session.lock();
  });

  testWidgets('le tuto est affiché par défaut sur une nouvelle fiche', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    expect(find.text('Compris'), findsOneWidget);
    session.lock();
  });

  testWidgets('enregistrer crée l\'entrée avec le texte tel quel', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('name')), 'perso');
    await tester.enterText(find.byKey(const Key('raw')), 'a:\nun');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final entree = session.vault!.entries.single;
    expect(entree.key, 'perso');
    expect(entree.value, 'a:\nun');
    session.lock();
  });

  testWidgets('un nom vide empêche l\'enregistrement', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('raw')), 'a:\nun');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(session.vault!.entries, isEmpty);
    expect(find.textContaining('nom'), findsWidgets);
    session.lock();
  });

  testWidgets('un nom déjà pris est refusé', (tester) async {
    final session = await makeUnlockedSession(keys: ['perso']);
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('name')), 'PERSO');
    await tester.enterText(find.byKey(const Key('raw')), 'a:\nun');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(session.vault!.entries.length, 1);
    session.lock();
  });

  testWidgets('le verrouillage efface la saisie', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('raw')), 'secret:\nvaleur');
    await tester.pumpAndSettle();

    session.lock();
    await tester.pumpAndSettle();

    expect(find.text('secret:\nvaleur'), findsNothing);
    final champ = tester.widget<TextField>(find.byKey(const Key('raw')));
    expect(champ.controller!.text, isEmpty);
  });

  testWidgets('le texte part au coffre sans être réécrit', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    // Espaces de bord et lignes vides comprises: ni `trim`, ni normalisation.
    // Un mot de passe qui se termine par une espace se colle faux sans elle.
    const brut = '  courrier: \n mot de passe  \n\n\n';
    await tester.enterText(find.byKey(const Key('name')), 'perso');
    await tester.enterText(find.byKey(const Key('raw')), brut);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(session.vault!.entries.single.value, brut);
    session.lock();
  });

  testWidgets('« Coller » insère le presse-papier à la position du curseur', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': 'COLLÉ'} : null,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('raw')), 'ab');
    await tester.pumpAndSettle();

    final champ = tester.widget<TextField>(find.byKey(const Key('raw')));
    // Curseur entre les deux lettres: c'est là que le collage doit atterrir,
    // et non à la fin du texte.
    champ.controller!.selection = const TextSelection.collapsed(offset: 1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coller'));
    await tester.pumpAndSettle();

    expect(champ.controller!.text, 'aCOLLÉb');
    expect(champ.controller!.selection.baseOffset, 'aCOLLÉ'.length);
    session.lock();
  });
}
