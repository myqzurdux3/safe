import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/ui/entry_edit_screen.dart';

import '../support/session_fixture.dart';

void main() {
  testWidgets('le champ de la valeur n\'alimente pas le clavier', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(wrapScreen(EntryEditScreen(session: session)));
    await tester.pumpAndSettle();

    // Le champ est révélé par défaut à la création: c'est celui qu'on tape.
    final champ = tester.widget<TextField>(find.byKey(const Key('value')));

    // Sans ces deux réglages, le clavier Android range les secrets tapés dans
    // son dictionnaire personnel et les propose ensuite ailleurs — hors du
    // coffre, et hors de son cycle de vie.
    expect(champ.autocorrect, isFalse);
    expect(champ.enableSuggestions, isFalse);
    session.lock();
  });

  testWidgets('le champ de la clef non plus', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(wrapScreen(EntryEditScreen(session: session)));
    await tester.pumpAndSettle();

    final champ = tester.widget<TextField>(find.byKey(const Key('key')));
    expect(champ.autocorrect, isFalse);
    expect(champ.enableSuggestions, isFalse);
    session.lock();
  });
}
