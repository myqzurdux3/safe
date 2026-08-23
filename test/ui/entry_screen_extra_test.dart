import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/ui/entry_screen.dart';
import 'package:safe/ui/new_entry_screen.dart';

import '../support/session_fixture.dart';

/// Ce que couvrait l'ancien écran d'édition, transposé.
///
/// La création est passée à [NewEntryScreen], la modification à [EntryScreen].
/// Les assertions n'ont pas changé: ce sont des défauts déjà corrigés, qu'il ne
/// faut pas réintroduire en changeant d'écran.
Widget _creation(VaultSession session) => wrapScreen(
  NewEntryScreen(session: session, settings: MemorySettingsStore()),
);

/// La fiche d'une entrée choisie par son nom, quand le coffre en porte
/// plusieurs.
Widget _ficheDe(VaultSession session, String key) => wrapScreen(
  EntryScreen(
    session: session,
    entry: session.vault!.entries.firstWhere((e) => e.key == key),
    settings: MemorySettingsStore(),
  ),
);

Widget _fiche(VaultSession session) => wrapScreen(
  EntryScreen(
    session: session,
    entry: session.vault!.entries.single,
    settings: MemorySettingsStore(),
  ),
);

/// La fiche empilée au-dessus d'un écran repère.
///
/// Le repère tient lieu de liste: c'est le seul moyen de constater qu'on en
/// revient. Une fiche montée seule ne permet pas de distinguer « revenu à la
/// liste » de « resté sur une fiche qui n'existe plus ».
Widget _ficheAuDessusDeLaListe(VaultSession session) => wrapScreen(
  Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EntryScreen(
                session: session,
                entry: session.vault!.entries.single,
                settings: MemorySettingsStore(),
              ),
            ),
          ),
          child: const Text('la liste'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('entrée ajoutée: elle rejoint le coffre', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_creation(session));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name')), 'gmail');
    await tester.enterText(find.byKey(const Key('raw')), 'p4ss');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(session.vault!.entries.single.key, 'gmail');
    expect(session.vault!.entries.single.value, 'p4ss');
    session.lock();
  });

  testWidgets('nom vide refusé', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_creation(session));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('raw')), 'p4ss');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('nom'), findsWidgets);
    expect(session.vault!.entries, isEmpty);
    session.lock();
  });

  testWidgets('nom déjà pris refusé en création', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(_creation(session));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name')), 'gmail');
    await tester.enterText(find.byKey(const Key('raw')), 'x');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('existe déjà'), findsOneWidget);
    expect(session.vault!.entries.single.value, 'p4ss-gmail');
    session.lock();
  });

  testWidgets('modification: la fiche garde son nom sans se dédoubler', (
    tester,
  ) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(_fiche(session));
    await tester.pumpAndSettle();
    // La fiche s'ouvre en lecture: le texte se modifie en « Texte brut ».
    await tester.tap(find.text('Texte brut'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('raw')), 'nouvelle');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    // `single`: le nom n'a pas changé, la fiche ne doit pas s'être dédoublée —
    // ce qui arriverait si la validation ne s'exemptait pas de sa propre clef.
    expect(session.vault!.entries.single.key, 'gmail');
    expect(session.vault!.entries.single.value, 'nouvelle');
    session.lock();
  });

  testWidgets('texte vide accepté', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_creation(session));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name')), 'note');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(session.vault!.entries.single, isA<VaultEntry>());
    expect(session.vault!.entries.single.value, '');
    session.lock();
  });

  testWidgets('renommer vers un nom vide est refusé', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(_fiche(session));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name')), '   ');
    await tester.tap(find.text('Enregistrer'));
    // Une seule image: `pumpAndSettle` laisserait filer le toast jusqu'au bout
    // de son fondu, et il n'y aurait plus rien à trouver.
    await tester.pump();

    // La fiche garde son nom: une fiche sans nom serait introuvable dans la
    // liste, qui n'affiche que les noms.
    expect(session.vault!.entries.single.key, 'gmail');
    expect(find.text('Le nom ne peut pas être vide'), findsOneWidget);
    session.lock();
  });

  testWidgets('renommer vers le nom d\'une autre fiche est refusé, et '
      'l\'autre fiche est intacte', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail', 'banque']);
    await tester.pumpWidget(_ficheDe(session, 'gmail'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Texte brut'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('raw')), 'contenu de gmail');
    await tester.enterText(find.byKey(const Key('name')), 'banque');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    // Le coffre d'abord, le message ensuite: sans cette garde,
    // l'enregistrement retirerait « gmail » puis écraserait « banque » avec le
    // contenu de « gmail ». Une fiche entière disparaîtrait sans un mot, et
    // c'est cela qu'il faut voir tomber en premier.
    expect(session.vault!.entries, hasLength(2));
    final banque = session.vault!.entries.firstWhere((e) => e.key == 'banque');
    expect(banque.value, 'p4ss-banque');
    final gmail = session.vault!.entries.firstWhere((e) => e.key == 'gmail');
    expect(gmail.value, 'p4ss-gmail');
    expect(find.text('Ce nom existe déjà'), findsOneWidget);
    session.lock();
  });

  testWidgets('renommer deux fois de suite ne laisse qu\'une entrée', (
    tester,
  ) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(_fiche(session));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('name')), 'courriel');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name')), 'messagerie');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // Le second renommage doit retirer « courriel », pas « gmail »: l'écran
    // suit le nom sous lequel la fiche est au coffre, pas celui qu'il a reçu à
    // l'ouverture. Sinon « courriel » reste derrière, en doublon.
    expect(session.vault!.entries, hasLength(1));
    expect(session.vault!.entries.single.key, 'messagerie');
    expect(session.vault!.entries.single.value, 'p4ss-gmail');
    session.lock();
  });

  testWidgets('suppression demande confirmation, retire la fiche et rend la '
      'liste', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(_ficheAuDessusDeLaListe(session));
    await tester.pumpAndSettle();
    await tester.tap(find.text('la liste'));
    await tester.pumpAndSettle();

    // La suppression a quitté la liste avec elle: elle vit sur la fiche, où
    // l'on voit ce qu'on efface.
    await tester.tap(find.byKey(const Key('delete-entry')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Supprimer'), findsWidgets);
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(session.vault!.entries, isEmpty);

    // Le nom ne doit plus être nulle part à l'écran: l'assertion perdue à la
    // transposition, et la seule qui distinguait une fiche effacée d'une fiche
    // effacée mais toujours affichée.
    expect(find.text('gmail'), findsNothing);

    // Et l'on est bien redescendu à la liste. Rester sur la fiche d'une entrée
    // supprimée laisserait « Enregistrer » la ressusciter.
    expect(find.text('la liste'), findsOneWidget);
    expect(find.byKey(const Key('delete-entry')), findsNothing);
    session.lock();
  });

  testWidgets('annuler la suppression conserve la fiche', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(_fiche(session));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('delete-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-delete')));
    await tester.pumpAndSettle();
    expect(session.vault!.entries.single.key, 'gmail');
    session.lock();
  });

  testWidgets('supprimer une fiche renommée vise son nom au coffre', (
    tester,
  ) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(_fiche(session));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('name')), 'courriel');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // Viser `widget.entry.key` chercherait « gmail », qui n'existe plus: la
    // fiche resterait au coffre, sans que rien ne le dise.
    await tester.tap(find.byKey(const Key('delete-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(session.vault!.entries, isEmpty);
    session.lock();
  });
}
