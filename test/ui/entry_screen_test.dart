import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/storage/app_settings.dart';
import 'package:safe/ui/entry_screen.dart';
import 'package:safe/ui/theme/safe_theme.dart';

import '../support/session_fixture.dart';

const _texte = '''
courrier:
personne@example.invalid
correcthorsebattery

note libre

wifi:
un-mot-de-passe
''';

Future<VaultSession> _sessionAvecTexte() async {
  final session = await makeUnlockedSession();
  await session.save(
    session.vault!.upsert(VaultEntry.now(key: 'perso', value: _texte)),
  );
  return session;
}

Widget _ecran(VaultSession session, {SettingsStore? settings}) => MaterialApp(
  theme: safeLightTheme(),
  home: EntryScreen(
    session: session,
    entry: session.vault!.entries.first,
    settings: settings ?? MemorySettingsStore(),
  ),
);

void main() {
  testWidgets('l\'en-tête compte les blocs et les lignes', (tester) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    expect(find.text('perso'), findsOneWidget);
    expect(find.text('3 blocs · 4 lignes'), findsOneWidget);
    session.lock();
  });

  testWidgets('les blocs sont repliés et leurs valeurs masquées', (
    tester,
  ) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    expect(find.text('COURRIER'), findsOneWidget);
    expect(find.text('WIFI'), findsOneWidget);
    expect(find.text('correcthorsebattery'), findsNothing);
    expect(find.text('un-mot-de-passe'), findsNothing);
    session.lock();
  });

  testWidgets('un commentaire est visible sans geste', (tester) async {
    // Choix assumé du handoff: un groupe sans titre est une note, pas un
    // secret. Voir la section « masquage » de la spec.
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    expect(find.text('note libre'), findsOneWidget);
    session.lock();
  });

  testWidgets('ouvrir un bloc révèle ses lignes, le refermer les remasque', (
    tester,
  ) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('COURRIER'));
    await tester.pumpAndSettle();
    expect(find.text('personne@example.invalid'), findsOneWidget);
    expect(find.text('correcthorsebattery'), findsOneWidget);
    // L'autre bloc reste fermé.
    expect(find.text('un-mot-de-passe'), findsNothing);

    await tester.tap(find.text('COURRIER'));
    await tester.pumpAndSettle();
    expect(find.text('correcthorsebattery'), findsNothing);
    session.lock();
  });

  testWidgets('plusieurs blocs peuvent être ouverts en même temps', (
    tester,
  ) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('COURRIER'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WIFI'));
    await tester.pumpAndSettle();

    expect(find.text('correcthorsebattery'), findsOneWidget);
    expect(find.text('un-mot-de-passe'), findsOneWidget);
    session.lock();
  });

  testWidgets('le mode texte brut montre le texte source intact', (
    tester,
  ) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Texte brut'));
    await tester.pumpAndSettle();

    final champ = tester.widget<TextField>(find.byKey(const Key('raw')));
    expect(champ.controller!.text, _texte);
    session.lock();
  });

  testWidgets('taper dans le texte brut recompose la lecture en direct', (
    tester,
  ) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Texte brut'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('raw')), 'seul:\nx');
    await tester.pumpAndSettle();

    expect(find.text('1 bloc · 1 ligne'), findsOneWidget);

    await tester.tap(find.text('Lecture'));
    await tester.pumpAndSettle();
    expect(find.text('SEUL'), findsOneWidget);
    session.lock();
  });

  testWidgets('enregistrer écrit le texte tel quel, sans le réécrire', (
    tester,
  ) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Texte brut'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('raw')), '  espaces gardés  ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(session.vault!.entries.first.value, '  espaces gardés  ');
    session.lock();
  });

  testWidgets('le tuto s\'affiche puis s\'écarte définitivement', (
    tester,
  ) async {
    final settings = MemorySettingsStore();
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session, settings: settings));
    await tester.pumpAndSettle();

    expect(find.text('Compris'), findsOneWidget);
    await tester.tap(find.text('Compris'));
    await tester.pumpAndSettle();

    expect(find.text('Compris'), findsNothing);
    expect(find.text('Syntaxe'), findsOneWidget);
    expect((await settings.read()).syntaxTutorialDismissed, isTrue);
    session.lock();
  });

  testWidgets('« Syntaxe » rappelle le tuto écarté', (tester) async {
    final settings = MemorySettingsStore(
      const AppSettings(syntaxTutorialDismissed: true),
    );
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session, settings: settings));
    await tester.pumpAndSettle();

    expect(find.text('Compris'), findsNothing);
    await tester.tap(find.text('Syntaxe'));
    await tester.pumpAndSettle();
    expect(find.text('Compris'), findsOneWidget);
    session.lock();
  });

  testWidgets('copier une ligne affiche le toast', (tester) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('COURRIER'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('copy-line-1')));
    await tester.pump();

    expect(find.text('Copié'), findsOneWidget);
    session.lock();
  });

  testWidgets('le verrouillage referme les blocs et vide l\'écran', (
    tester,
  ) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('COURRIER'));
    await tester.pumpAndSettle();
    expect(find.text('correcthorsebattery'), findsOneWidget);

    session.lock();
    await tester.pumpAndSettle();

    expect(find.text('correcthorsebattery'), findsNothing);
  });
}
