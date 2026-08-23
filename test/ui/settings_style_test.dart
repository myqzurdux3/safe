import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/ui/settings_screen.dart';
import 'package:safe/ui/theme/safe_theme.dart';

import '../support/session_fixture.dart';

/// La luminance relative de WCAG 2.x, qui n'est pas celle de `Color`.
double _luminance(Color c) {
  double canal(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
}

double _contraste(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  testWidgets('le sélecteur de délai garde une cible de doigt', (tester) async {
    // Un restylage a déjà rétréci ce contrôle à 24 px de haut: il est le seul
    // de l'écran qu'on ouvre sans le voir grandir, et rien ne l'avait signalé.
    final session = await makeUnlockedSession();
    await tester.pumpWidget(
      wrapScreen(
        SettingsScreen(session: session, settings: MemorySettingsStore()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('auto-lock'))).height,
      greaterThanOrEqualTo(SafeMetrics.touchTarget),
      reason: 'le sélecteur de délai est plus petit qu\'un doigt',
    );
    session.lock();
  });

  testWidgets('le titre de l\'écran s\'annonce comme titre de route', (
    tester,
  ) async {
    // Ce que l'AppBar posait toute seule et qu'un titre dessiné à la main perd:
    // sans `namesRoute`, la synthèse vocale n'annonce rien à l'ouverture, et
    // sans `header`, la navigation par en-têtes ne s'arrête plus dessus.
    final session = await makeUnlockedSession();
    final poignee = tester.ensureSemantics();
    await tester.pumpWidget(
      wrapScreen(
        SettingsScreen(session: session, settings: MemorySettingsStore()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('Réglages')),
      matchesSemantics(label: 'Réglages', isHeader: true, namesRoute: true),
    );
    poignee.dispose();
    session.lock();
  });

  testWidgets('l\'avertissement sur le mot de passe maître reste lisible', (
    tester,
  ) async {
    // C'est la seule phrase de l'application qui dit que le mot de passe maître
    // ne se récupère pas. Restylée, elle était devenue le texte le plus pâle de
    // la page, à 4,37:1 sur le fond crème — sous le seuil AA de 4,5.
    final session = await makeUnlockedSession();
    await tester.pumpWidget(
      wrapScreen(
        SettingsScreen(session: session, settings: MemorySettingsStore()),
      ),
    );
    await tester.pumpAndSettle();

    final avertissement = find.textContaining('ne peut pas être récupéré');
    await tester.scrollUntilVisible(avertissement, 200);
    final tokens = SafeTokens.of(tester.element(find.byType(SettingsScreen)));
    final couleur = tester.widget<Text>(avertissement.first).style?.color;
    expect(couleur, isNotNull);

    expect(
      _contraste(couleur!, tokens.pageBackground),
      greaterThanOrEqualTo(4.5),
      reason: 'l\'avertissement passe sous le contraste AA',
    );
    session.lock();
  });
}
