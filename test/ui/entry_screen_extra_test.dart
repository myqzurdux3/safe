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

Widget _fiche(VaultSession session) => wrapScreen(
  EntryScreen(
    session: session,
    entry: session.vault!.entries.single,
    settings: MemorySettingsStore(),
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
}
