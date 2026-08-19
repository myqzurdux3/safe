import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/storage/app_settings.dart';
import 'package:safe/ui/entry_screen.dart';
import 'package:safe/ui/theme/safe_theme.dart';
import 'package:safe/util/clipboard.dart';

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

/// Un texte de même découpage que [_texte] — trois groupes, quatre lignes —
/// mais dont aucun bloc n'a le même nom ni le même contenu.
const _reordonne = '''
banque:
titulaire@example.invalid
un-autre-secret

autre note

serveur:
encore-un-secret
''';

/// Réglages qui se font attendre, comme un fichier sur le disque: le premier
/// affichage a lieu avant que la préférence ne soit connue.
class _LateSettingsStore implements SettingsStore {
  AppSettings _settings = const AppSettings();

  /// Ce qui est enregistré, lisible sans attendre: le test tourne sous une
  /// horloge simulée où `read` ne rendrait la main qu'après une image.
  AppSettings get stored => _settings;

  @override
  Future<AppSettings> read() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return _settings;
  }

  @override
  Future<void> write(AppSettings settings) async => _settings = settings;
}

/// Presse-papier espion: retient ce qui a été copié, sans toucher au système.
class _SpyClipboard extends SecureClipboard {
  final List<String> copies = [];

  @override
  Future<void> copy(String value) async => copies.add(value);
}

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

  testWidgets('modifier le texte referme tous les blocs', (tester) async {
    // Le nombre de groupes ne suffit pas à décider: à trois groupes constants,
    // un index d'ouverture désigne un autre bloc après un remaniement, et
    // l'écran révélerait un bloc que personne n'a ouvert.
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('COURRIER'));
    await tester.pumpAndSettle();
    expect(find.text('correcthorsebattery'), findsOneWidget);

    await tester.tap(find.text('Texte brut'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('raw')), _reordonne);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lecture'));
    await tester.pumpAndSettle();

    expect(find.text('BANQUE'), findsOneWidget);
    expect(find.text('titulaire@example.invalid'), findsNothing);
    expect(find.text('un-autre-secret'), findsNothing);
    expect(find.text('encore-un-secret'), findsNothing);
    session.lock();
  });

  testWidgets('la clef de copie porte le rang de la ligne dans la fiche', (
    tester,
  ) async {
    // Le commentaire compte: « wifi » est la quatrième ligne du document même
    // si elle est la première de son bloc.
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('WIFI'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('copy-line-3')), findsOneWidget);
    expect(find.byKey(const Key('copy-line-0')), findsNothing);
    expect(find.byKey(const Key('copy-line-1')), findsNothing);
    session.lock();
  });

  testWidgets('copier une ligne copie la ligne, espaces de bord compris', (
    tester,
  ) async {
    // L'affichage rogne les espaces de bord; le coffre, lui, les garde. Copier
    // la ligne rognée collerait un mot de passe faux, sans rien dire.
    final clipboard = _SpyClipboard();
    final session = await makeUnlockedSession();
    await session.save(
      session.vault!.upsert(
        VaultEntry.now(key: 'perso', value: 'courrier:\n  secret bordé  \n'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: EntryScreen(
          session: session,
          entry: session.vault!.entries.first,
          settings: MemorySettingsStore(),
          clipboard: clipboard,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('COURRIER'));
    await tester.pumpAndSettle();
    expect(find.text('secret bordé'), findsOneWidget);
    await tester.tap(find.byKey(const Key('copy-line-0')));
    await tester.pumpAndSettle();

    expect(clipboard.copies, ['  secret bordé  ']);
    session.lock();
  });

  testWidgets('copier le bloc copie les lignes brutes, sans le titre', (
    tester,
  ) async {
    final clipboard = _SpyClipboard();
    final session = await makeUnlockedSession();
    await session.save(
      session.vault!.upsert(
        VaultEntry.now(key: 'perso', value: 'courrier:\n a \n b \n'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: EntryScreen(
          session: session,
          entry: session.vault!.entries.first,
          settings: MemorySettingsStore(),
          clipboard: clipboard,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('COURRIER'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('copier le bloc'));
    await tester.pumpAndSettle();

    expect(clipboard.copies, [' a \n b ']);
    session.lock();
  });

  testWidgets('le tuto est là dès la première image', (tester) async {
    // Apparaître à la deuxième décale la mise en page sous les yeux, le temps
    // d'un aller-retour au disque.
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session, settings: _LateSettingsStore()));
    await tester.pump();

    expect(find.text('Compris'), findsOneWidget);
    // Laisse la lecture des réglages se terminer: elle ne change rien ici,
    // mais une minuterie en vol ferait échouer le test suivant.
    await tester.pump(const Duration(milliseconds: 50));
    session.lock();
  });

  testWidgets('le verrouillage efface aussi le nom de la fiche', (
    tester,
  ) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();
    expect(find.text('perso'), findsOneWidget);

    session.lock();
    await tester.pumpAndSettle();

    expect(find.text('perso'), findsNothing);
  });

  testWidgets('« Compris » donné avant la lecture des réglages tient', (
    tester,
  ) async {
    // Le tuto s'affiche avant que le disque n'ait répondu: la réponse, qui
    // arrive après, ne doit pas défaire le geste de l'utilisateur.
    final settings = _LateSettingsStore();
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session, settings: settings));
    await tester.pump();

    await tester.tap(find.text('Compris'));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Compris'), findsNothing);
    expect(settings.stored.syntaxTutorialDismissed, isTrue);
    // Et les autres réglages sont intacts: écrire par-dessus des valeurs par
    // défaut les aurait effacés.
    expect(settings.stored.blockScreenshots, isTrue);
    session.lock();
  });
}
