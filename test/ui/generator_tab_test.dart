import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/state/generator_session.dart';
import 'package:safe/ui/generator_tab.dart';
import 'package:safe/ui/theme/safe_theme.dart';
import 'package:safe/util/clipboard.dart';
import 'package:safe/util/password_generator.dart';

import '../support/session_fixture.dart';

void main() {
  testWidgets('les deux commandes portent des icônes, pas des glyphes absents '
      'des polices embarquées', (tester) async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);
    final clipboard = SecureClipboard();
    addTearDown(clipboard.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: Scaffold(
          body: GeneratorTab(generator: gen, clipboard: clipboard),
        ),
      ),
    );

    // « ↻ » (U+21BB) et « ✓ » (U+2713) n'ont de glyphe dans AUCUNE des deux
    // polices embarquées — vérifié dans leur table `cmap`. Sur appareil,
    // Android se rabat sur une autre fonte, d'autres métriques et une autre
    // graisse au milieu du texte; sans repli, c'est un tofu. Les `Icons`
    // viennent de MaterialIcons, qui, elle, est livrée avec l'application.
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.text('↻'), findsNothing);

    await tester.tap(find.text('Copier'));
    await tester.pump();
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('Copié'), findsOneWidget);
    expect(find.textContaining('✓'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1700));
    vault.lock();
  });

  testWidgets('« Copier » devient « Copié » puis revient', (tester) async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);
    final clipboard = SecureClipboard();
    addTearDown(clipboard.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: Scaffold(
          body: GeneratorTab(generator: gen, clipboard: clipboard),
        ),
      ),
    );

    await tester.tap(find.text('Copier'));
    await tester.pump();
    expect(find.text('Copié'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1700));
    expect(find.text('Copier'), findsOneWidget);
    vault.lock();
  });

  testWidgets('régénérer remplit l\'historique, au plus trois', (tester) async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: Scaffold(body: GeneratorTab(generator: gen)),
      ),
    );

    expect(find.text('GÉNÉRÉ AVANT'), findsNothing);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const Key('regenerate')));
      await tester.pumpAndSettle();
    }
    expect(find.text('GÉNÉRÉ AVANT'), findsOneWidget);
    expect(
      find.text('Effacé au verrouillage. Jamais écrit sur le disque.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('copy-history-2')), findsOneWidget);
    expect(find.byKey(const Key('copy-history-3')), findsNothing);
    vault.lock();
  });

  testWidgets('la pastille active se voit', (tester) async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: Scaffold(body: GeneratorTab(generator: gen)),
      ),
    );

    // Défaut: « + symboles ».
    expect(gen.set.label, '+ symboles');
    await tester.tap(find.text('Lettres'));
    await tester.pumpAndSettle();
    expect(gen.set.label, 'Lettres');
    vault.lock();
  });

  testWidgets('le curseur régénère à la nouvelle longueur', (tester) async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: Scaffold(body: GeneratorTab(generator: gen)),
      ),
    );

    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(gen.value.length, gen.length);
    expect(gen.length, greaterThan(20));
    vault.lock();
  });

  testWidgets('le curseur poussé à fond ne fait pas tomber l\'écran', (
    tester,
  ) async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: Scaffold(body: GeneratorTab(generator: gen)),
      ),
    );

    // Un curseur plus large que ce que `generatePassword` accepte faisait
    // lever un `ArgumentError` non rattrapé, et l'écran tombait. Le curseur
    // doit donc être borné par les longueurs du générateur, des deux côtés.
    await tester.drag(find.byType(Slider), const Offset(4000, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(gen.length, maxPasswordLength);
    expect(gen.value.length, maxPasswordLength);

    await tester.drag(find.byType(Slider), const Offset(-4000, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(gen.length, minPasswordLength);
    expect(gen.value.length, minPasswordLength);
    vault.lock();
  });

  testWidgets('le verrouillage rend le bouton à « Copier »', (tester) async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);
    final clipboard = SecureClipboard();
    addTearDown(clipboard.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: Scaffold(
          body: GeneratorTab(generator: gen, clipboard: clipboard),
        ),
      ),
    );

    await tester.tap(find.text('Copier'));
    await tester.pump();
    expect(find.text('Copié'), findsOneWidget);

    // Le coffre se ferme dans la seconde et demie qui suit la copie: la
    // session est vidée, et le bouton ne doit pas continuer d'annoncer une
    // copie au-dessus d'une valeur qui n'existe plus.
    vault.lock();
    await tester.pump();
    expect(find.text('Copié'), findsNothing);
    expect(find.text('Copier'), findsOneWidget);
  });
}
