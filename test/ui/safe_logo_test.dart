import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/ui/safe_logo.dart';
import 'package:safe/ui/theme/safe_theme.dart';
import 'package:safe/ui/unlock_screen.dart';

import '../support/session_fixture.dart';

void main() {
  testWidgets('le logo se dessine à la taille demandée', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: const Scaffold(body: Center(child: SafeLogo(size: 64))),
      ),
    );
    expect(tester.getSize(find.byType(SafeLogo)), const Size(64, 64));
  });

  testWidgets('le logo prend la couleur du thème', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: const Scaffold(body: SafeLogo()),
      ),
    );
    // Aucune exception de peinture, et le widget est bien monté.
    expect(find.byType(SafeLogo), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('l\'écran de verrou affiche le logo', (tester) async {
    final session = await makeTestSession();
    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: UnlockScreen(session: session, isCreation: true),
      ),
    );
    expect(find.byType(SafeLogo), findsOneWidget);
  });

  testWidgets('le logo accepte une couleur explicite', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: const Scaffold(
          body: SafeLogo(size: 34, color: Color(0xFF183A2B)),
        ),
      ),
    );
    expect(tester.getSize(find.byType(SafeLogo)), const Size(34, 34));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sans couleur explicite, le logo prend l\'accent du thème', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: const Scaffold(body: SafeLogo()),
      ),
    );
    final painter = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(SafeLogo),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter;
    expect(painter, isA<SafeLogoPainter>());
    expect((painter! as SafeLogoPainter).color, const Color(0xFF2F7D5B));
  });
}
