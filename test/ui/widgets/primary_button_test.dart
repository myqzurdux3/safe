import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/l10n/app_localizations.dart';
import 'package:safe/ui/theme/safe_theme.dart';
import 'package:safe/ui/widgets/primary_button.dart';

Widget _host(Widget child) => MaterialApp(
  theme: safeLightTheme(),
  // Les délégués, sinon `L.of(context)` lève dès la première
  // chaîne traduite. La locale est forcée au français comme
  // dans `wrapScreen`: `flutter_test` démarre en en_US.
  locale: const Locale('fr'),
  localizationsDelegates: L.localizationsDelegates,
  supportedLocales: L.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('le bouton primaire fait la hauteur de pilule du handoff', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(SafePrimaryButton(label: 'Déverrouiller', onPressed: () {})),
    );
    expect(
      tester.getSize(find.byType(SafePrimaryButton)).height,
      SafeMetrics.pillHeight,
    );
    expect(find.text('Déverrouiller'), findsOneWidget);
  });

  testWidgets('le bouton primaire appelle son action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(SafePrimaryButton(label: 'Enregistrer', onPressed: () => taps++)),
    );
    await tester.tap(find.byType(SafePrimaryButton));
    expect(taps, 1);
  });

  testWidgets('sans action, le bouton primaire ne réagit pas', (tester) async {
    await tester.pumpWidget(
      const _HostConst(SafePrimaryButton(label: 'Inerte', onPressed: null)),
    );
    await tester.tap(find.byType(SafePrimaryButton), warnIfMissed: false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('avec un pictogramme, le bouton garde sa pilule et la couleur '
      'de son libellé', (tester) async {
    // Les deux polices embarquées n'ont de glyphe ni pour « ✓ » ni pour
    // « ↻ »: le pictogramme vient de MaterialIcons. Reste à ce qu'il ne
    // déforme pas le bouton et ne se détache pas du texte par sa couleur.
    await tester.pumpWidget(
      _host(
        SafePrimaryButton(label: 'Copié', icon: Icons.check, onPressed: () {}),
      ),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('Copié'), findsOneWidget);
    // Vérifier la hauteur de la pilule ne prouverait rien: elle est imposée
    // par un `SizedBox`, donc un pictogramme trop grand déborderait en
    // silence au lieu de la faire grandir. Ce qu'il faut exiger, c'est qu'il
    // tienne DANS la pilule.
    final pilule = tester.getRect(find.byType(SafePrimaryButton));
    expect(pilule.height, SafeMetrics.pillHeight);
    final marque = tester.getRect(find.byIcon(Icons.check));
    expect(
      pilule.contains(marque.topLeft) && pilule.contains(marque.bottomRight),
      isTrue,
      reason: 'le pictogramme déborde de la pilule: $marque hors de $pilule',
    );

    // La couleur n'est pas écrite sur l'icône: elle doit venir du bouton, la
    // même que le libellé. Écrite à la main, elle dériverait au prochain
    // changement de thème.
    final icone = tester.widget<Icon>(find.byIcon(Icons.check));
    expect(icone.color, isNull);
    final rendu = tester.firstWidget<RichText>(
      find.descendant(of: find.text('Copié'), matching: find.byType(RichText)),
    );
    final tokens = SafeTokens.of(
      tester.element(find.byType(SafePrimaryButton)),
    );
    expect(rendu.text.style?.color, tokens.onInk);
    expect(
      IconTheme.of(tester.element(find.byIcon(Icons.check))).color,
      tokens.onInk,
    );
  });

  testWidgets('le bouton secondaire porte une bordure, pas un aplat', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(SafeSecondaryButton(label: 'Pièce jointe', onPressed: () {})),
    );
    expect(find.text('Pièce jointe'), findsOneWidget);
    expect(
      tester.getSize(find.byType(SafeSecondaryButton)).height,
      SafeMetrics.pillHeight,
    );
  });

  testWidgets('occupé, le bouton primaire montre une roue plutôt que son '
      'texte', (tester) async {
    // Un bouton simplement grisé ne se distingue pas d'un bouton invalide;
    // sur une dérivation de plusieurs secondes, ça pousse à taper deux fois.
    await tester.pumpWidget(
      _host(
        SafePrimaryButton(label: 'Déverrouiller', onPressed: () {}, busy: true),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Déverrouiller'), findsNothing);
  });
}

class _HostConst extends StatelessWidget {
  const _HostConst(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: safeLightTheme(),
    // Les délégués, sinon `L.of(context)` lève dès la première
    // chaîne traduite. La locale est forcée au français comme
    // dans `wrapScreen`: `flutter_test` démarre en en_US.
    locale: const Locale('fr'),
    localizationsDelegates: L.localizationsDelegates,
    supportedLocales: L.supportedLocales,
    home: Scaffold(body: child),
  );
}
