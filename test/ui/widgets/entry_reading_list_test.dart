import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/entry_text.dart';
import 'package:safe/ui/widgets/entry_reading_list.dart';

import '../../support/session_fixture.dart';

/// Deux blocs, deux commentaires intercalés, un dernier bloc: la numérotation
/// des lignes doit traverser tout cela sans sauter ni se répéter.
const _texte = '''
courrier:
personne@example.invalid
correcthorsebattery

note libre entre deux blocs

banque:
titulaire@example.invalid
double authentification

deuxieme note

wifi:
  un-mot-de-passe-bordé  
''';

Future<List<String>> _monter(
  WidgetTester tester, {
  required Set<int> open,
}) async {
  final copies = <String>[];
  await tester.pumpWidget(
    wrapScreen(
      Scaffold(
        body: EntryReadingList(
          groups: parseEntryText(_texte),
          open: open,
          onToggle: (_) {},
          onCopy: copies.add,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return copies;
}

void main() {
  testWidgets('la numérotation des lignes court sur la fiche entière', (
    tester,
  ) async {
    await _monter(tester, open: {0, 2, 4});

    // courrier: 0 et 1 — le commentaire prend 2 — banque: 3 et 4 — le
    // deuxième commentaire prend 5 — wifi: 6.
    for (final index in [0, 1, 3, 4, 6]) {
      expect(
        find.byKey(Key('copy-line-$index')),
        findsOneWidget,
        reason: 'la ligne $index doit être copiable',
      );
    }
    // Les lignes d'un commentaire consomment leur rang sans porter de clef:
    // le commentaire se copie d'un bloc.
    expect(find.byKey(const Key('copy-line-2')), findsNothing);
    expect(find.byKey(const Key('copy-line-5')), findsNothing);
    expect(find.byKey(const Key('copy-line-7')), findsNothing);
  });

  testWidgets('un bloc fermé ne construit aucune de ses lignes', (
    tester,
  ) async {
    await _monter(tester, open: const {});

    expect(find.text('correcthorsebattery'), findsNothing);
    expect(find.byKey(const Key('copy-line-0')), findsNothing);
    // Les commentaires, eux, sont là sans geste.
    expect(find.text('note libre entre deux blocs'), findsOneWidget);
  });

  testWidgets('la dernière ligne se copie brute, espaces de bord compris', (
    tester,
  ) async {
    final copies = await _monter(tester, open: {4});

    await tester.tap(find.byKey(const Key('copy-line-6')));
    await tester.pumpAndSettle();

    expect(copies, ['  un-mot-de-passe-bordé  ']);
  });

  testWidgets('copier le bloc joint les lignes brutes, sans le titre', (
    tester,
  ) async {
    final copies = await _monter(tester, open: {0});

    await tester.tap(find.text('copier le bloc'));
    await tester.pumpAndSettle();

    expect(copies, ['personne@example.invalid\ncorrecthorsebattery']);
  });

  testWidgets('une fiche vide le dit au lieu de rester blanche', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapScreen(
        Scaffold(
          body: EntryReadingList(
            groups: parseEntryText(''),
            open: const {},
            onToggle: (_) {},
            onCopy: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Cette fiche est vide'), findsOneWidget);
  });
}
