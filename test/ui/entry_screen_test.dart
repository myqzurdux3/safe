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
  _LateSettingsStore([this._settings = const AppSettings()]);

  AppSettings _settings;

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

/// Presse-papier qui échoue tout de suite, comme un canal natif qui refuse.
///
/// L'échec arrive avant la première image du toast « Copié »: c'est le cas
/// courant sur téléphone, où un aller-retour de `MethodChannel` dure moins
/// qu'une image.
class _FailingClipboard extends SecureClipboard {
  @override
  Future<void> copy(String value) async =>
      throw StateError('presse-papier indisponible');
}

/// Relève la position de tout ce qui est déjà à l'écran, parmi les repères
/// stables de la fiche.
Map<String, Rect> _reperes(WidgetTester tester) {
  final vus = <String, Rect>{};
  for (final libelle in const [
    'perso',
    'Coffre',
    'Lecture',
    'Texte brut',
    'Enregistrer',
    'COURRIER',
    'WIFI',
    'note libre',
    'Compris',
    'Syntaxe',
  ]) {
    final finder = find.text(libelle);
    if (finder.evaluate().length == 1) {
      vus[libelle] = tester.getRect(finder);
    }
  }
  return vus;
}

/// Monte la fiche sur un magasin de réglages qui se fait attendre et vérifie
/// que la réponse, quand elle arrive, ne déplace rien de ce qui était déjà là.
Future<void> _rienNeBougeALaLecture(
  WidgetTester tester, {
  required bool ecarte,
}) async {
  final session = await _sessionAvecTexte();
  await tester.pumpWidget(
    _ecran(
      session,
      settings: _LateSettingsStore(
        AppSettings(syntaxTutorialDismissed: ecarte),
      ),
    ),
  );
  await tester.pump();
  final avant = _reperes(tester);
  await tester.pump(const Duration(milliseconds: 50));
  final apres = _reperes(tester);

  expect(avant, isNotEmpty, reason: 'le premier rendu doit montrer la fiche');
  for (final repere in avant.entries) {
    expect(
      apres[repere.key],
      repere.value,
      reason: '« ${repere.key} » a bougé quand les réglages sont arrivés',
    );
  }
  session.lock();
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

  testWidgets('la lecture des réglages ne déplace rien: tuto à venir', (
    tester,
  ) async {
    await _rienNeBougeALaLecture(tester, ecarte: false);
  });

  testWidgets('la lecture des réglages ne déplace rien: tuto déjà écarté', (
    tester,
  ) async {
    // Le sens qui manquait: qui a déjà fait « Compris » ne doit pas voir la
    // carte apparaître puis disparaître à chaque ouverture de fiche.
    await _rienNeBougeALaLecture(tester, ecarte: true);
  });

  testWidgets('une fiche déjà comprise ne montre le tuto à aucune image', (
    tester,
  ) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(
      _ecran(
        session,
        settings: _LateSettingsStore(
          const AppSettings(syntaxTutorialDismissed: true),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Compris'), findsNothing);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Compris'), findsNothing);
    expect(find.text('Syntaxe'), findsOneWidget);
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

  testWidgets('écarter le tuto ne touche pas aux autres réglages', (
    tester,
  ) async {
    // Des valeurs franchement différentes des défauts: repartir de
    // `const AppSettings()` pour écrire la préférence rallumerait le blocage
    // des captures d'écran et rallongerait le délai de verrouillage.
    final settings = MemorySettingsStore(
      const AppSettings(
        blockScreenshots: false,
        autoLockDelay: Duration(seconds: 30),
      ),
    );
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session, settings: settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Compris'));
    await tester.pumpAndSettle();

    final ecrit = await settings.read();
    expect(ecrit.syntaxTutorialDismissed, isTrue);
    expect(ecrit.blockScreenshots, isFalse);
    expect(ecrit.autoLockDelay, const Duration(seconds: 30));
    session.lock();
  });

  testWidgets('une copie qui échoue le dit, sans lever', (tester) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: EntryScreen(
          session: session,
          entry: session.vault!.entries.first,
          settings: MemorySettingsStore(),
          clipboard: _FailingClipboard(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('COURRIER'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('copy-line-1')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Copie impossible'), findsOneWidget);
    expect(find.text('Copié'), findsNothing);
    await tester.pumpAndSettle();
    session.lock();
  });
}
