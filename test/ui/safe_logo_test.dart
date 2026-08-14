import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/ui/safe_logo.dart';
import 'package:safe/ui/unlock_screen.dart';

import '../support/session_fixture.dart';

void main() {
  testWidgets('le logo se dessine à la taille demandée', (tester) async {
    await tester.pumpWidget(
      wrapScreen(const Scaffold(body: Center(child: SafeLogo(size: 64)))),
    );
    expect(tester.getSize(find.byType(SafeLogo)), const Size(64, 64));
  });

  testWidgets('le logo prend la couleur du thème', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6F4E)),
        ),
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
      wrapScreen(UnlockScreen(session: session, isCreation: true)),
    );
    expect(find.byType(SafeLogo), findsOneWidget);
  });
}
