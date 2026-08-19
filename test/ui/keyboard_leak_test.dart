import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/ui/entry_screen.dart';
import 'package:safe/ui/new_entry_screen.dart';

import '../support/session_fixture.dart';

void main() {
  testWidgets('le champ du texte n\'alimente pas le clavier', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(
      wrapScreen(
        NewEntryScreen(session: session, settings: MemorySettingsStore()),
      ),
    );
    await tester.pumpAndSettle();

    // La carte de saisie est le champ qu'on tape sur une nouvelle fiche.
    final champ = tester.widget<TextField>(find.byKey(const Key('raw')));

    // Sans ces deux réglages, le clavier Android range les secrets tapés dans
    // son dictionnaire personnel et les propose ensuite ailleurs — hors du
    // coffre, et hors de son cycle de vie.
    expect(champ.autocorrect, isFalse);
    expect(champ.enableSuggestions, isFalse);
    session.lock();
  });

  testWidgets('le champ du nom non plus', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(
      wrapScreen(
        NewEntryScreen(session: session, settings: MemorySettingsStore()),
      ),
    );
    await tester.pumpAndSettle();

    final champ = tester.widget<TextField>(find.byKey(const Key('name')));
    expect(champ.autocorrect, isFalse);
    expect(champ.enableSuggestions, isFalse);
    session.lock();
  });

  testWidgets('le titre d\'une fiche existante non plus', (tester) async {
    final session = await makeUnlockedSession();
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: 'perso', value: 'note')),
    );
    await tester.pumpWidget(
      wrapScreen(
        EntryScreen(
          session: session,
          entry: session.vault!.entries.single,
          settings: MemorySettingsStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Le titre est modifiable depuis la refonte: c'est un nom de fiche, donc
    // chiffré dans le coffre, et le clavier n'a pas à l'apprendre.
    final champ = tester.widget<TextField>(find.byKey(const Key('name')));
    expect(champ.autocorrect, isFalse);
    expect(champ.enableSuggestions, isFalse);
    session.lock();
  });

  testWidgets('le texte brut d\'une fiche existante non plus', (tester) async {
    final session = await makeUnlockedSession();
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: 'perso', value: 'note')),
    );
    await tester.pumpWidget(
      wrapScreen(
        EntryScreen(
          session: session,
          entry: session.vault!.entries.single,
          settings: MemorySettingsStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Texte brut'));
    await tester.pumpAndSettle();

    final champ = tester.widget<TextField>(find.byKey(const Key('raw')));
    expect(champ.autocorrect, isFalse);
    expect(champ.enableSuggestions, isFalse);
    session.lock();
  });
}
