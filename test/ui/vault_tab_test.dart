import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/ui/vault_tab.dart';

import '../support/session_fixture.dart';

/// L'onglet seul, sans l'accueil qui l'entoure: la navigation est rendue au
/// travers de [ouvertes], et rien n'est empilé.
Widget _onglet(VaultSession session, {List<VaultEntry>? ouvertes}) =>
    wrapScreen(
      Scaffold(
        body: VaultTab(
          session: session,
          onOpen: (entry) => ouvertes?.add(entry),
        ),
      ),
    );

void main() {
  testWidgets('les noms apparaissent, les valeurs restent masquées', (
    tester,
  ) async {
    final session = await makeUnlockedSession(keys: ['gmail', 'banque']);
    await tester.pumpWidget(_onglet(session));
    expect(find.text('gmail'), findsOneWidget);
    expect(find.text('banque'), findsOneWidget);
    expect(find.text('p4ss-gmail'), findsNothing);
    session.lock();
  });

  testWidgets('la recherche filtre la liste', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail', 'banque']);
    await tester.pumpWidget(_onglet(session));
    await tester.enterText(find.byKey(const Key('search')), 'gma');
    await tester.pumpAndSettle();
    expect(find.text('gmail'), findsOneWidget);
    expect(find.text('banque'), findsNothing);
    session.lock();
  });

  testWidgets('coffre vide: invite affichée', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_onglet(session));
    expect(find.textContaining('Aucune fiche'), findsOneWidget);
    session.lock();
  });

  testWidgets('recherche sans résultat: message dédié', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(_onglet(session));
    await tester.enterText(find.byKey(const Key('search')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucun résultat'), findsOneWidget);
    session.lock();
  });

  testWidgets('toucher une ligne demande l\'ouverture de sa fiche', (
    tester,
  ) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    final ouvertes = <VaultEntry>[];
    await tester.pumpWidget(_onglet(session, ouvertes: ouvertes));
    await tester.tap(find.byKey(const Key('entry-gmail')));
    await tester.pumpAndSettle();
    expect(ouvertes.single.key, 'gmail');
    session.lock();
  });

  testWidgets('une fiche multiligne ne laisse rien voir de son texte', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await session.save(
      session.vault!.upsert(
        VaultEntry.now(key: 'note', value: 'première\nseconde\ntroisième'),
      ),
    );
    await tester.pumpWidget(_onglet(session));
    await tester.pumpAndSettle();

    // La liste ne rognait la valeur qu'à la première ligne; elle n'en montre
    // désormais aucune. La seule exception est l'extrait d'une recherche, qui
    // dit pourquoi une fiche remonte — et il n'y a pas de recherche ici.
    expect(find.text('note'), findsOneWidget);
    expect(find.textContaining('première'), findsNothing);
    expect(find.textContaining('seconde'), findsNothing);
    session.lock();
  });

  testWidgets('la recherche dans le contenu montre la ligne trouvée', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await session.save(
      session.vault!.upsert(
        VaultEntry.now(key: 'comptes', value: 'wifi:\nmot-de-passe-du-salon'),
      ),
    );
    await tester.pumpWidget(_onglet(session));
    await tester.enterText(find.byKey(const Key('search')), 'salon');
    await tester.pumpAndSettle();

    expect(find.text('comptes'), findsOneWidget);
    expect(find.text('mot-de-passe-du-salon'), findsOneWidget);
    // Sans `onCopy`, l'onglet n'affiche aucune action de copie: le
    // presse-papier appartient à l'accueil, pas à la liste.
    expect(find.byKey(const Key('copy-hit-comptes')), findsNothing);
    session.lock();
  });
}
