import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/ui/safe_logo.dart';
import 'package:safe/ui/theme/safe_theme.dart';
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
      wrapScreen(UnlockScreen(session: session, isCreation: true)),
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

  // ---------------------------------------------------------------------
  // Le fermoir (planche 1a, marque « C » du handoff).
  //
  // Deux équerres qui s'emboîtent SANS SE TOUCHER: la première occupe le
  // haut-gauche, la seconde le bas-droite, et le centre reste vide. C'est
  // exactement ce qui distingue cette marque du monogramme S, dont le tracé
  // passe par le centre du carré — le point (24, 24) y est même la jonction
  // de ses deux arcs. Un test qui ne regarderait que la taille ou la couleur
  // laisserait passer le retour au S.

  /// Peint le logo seul dans [cote] pixels et rend les octets RGBA.
  Future<ui.Image> peindre(SafeLogoPainter peintre, double cote) async {
    final recorder = ui.PictureRecorder();
    peintre.paint(Canvas(recorder), Size(cote, cote));
    return recorder.endRecording().toImage(cote.toInt(), cote.toInt());
  }

  testWidgets('le fermoir laisse le centre vide, ce que le S ne fait pas', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const accent = Color(0xFF2F7D5B);
      const encre = Color(0xFF183A2B);
      final image = await peindre(const SafeLogoPainter(accent, encre), 96);
      final octets = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

      int alphaEn(int x, int y) => octets!.getUint8((y * 96 + x) * 4 + 3);
      int rougeEn(int x, int y) => octets!.getUint8((y * 96 + x) * 4);
      int vertEn(int x, int y) => octets!.getUint8((y * 96 + x) * 4 + 1);

      // Le centre du carré: rien. Le S y passait.
      expect(
        alphaEn(48, 48),
        0,
        reason:
            'le centre est peint: les deux équerres se touchent, ou ce '
            'n\'est pas le fermoir',
      );

      // Le montant vertical de la première équerre: x=7, y entre 16 et 26
      // dans le carré de 48, soit x=14, y=42 à 96 px.
      expect(
        alphaEn(14, 42),
        greaterThan(200),
        reason: 'la première équerre ne passe pas par son montant gauche',
      );

      // Celui de la seconde: x=41, y entre 22 et 32.
      expect(
        alphaEn(82, 54),
        greaterThan(200),
        reason: 'la seconde équerre ne passe pas par son montant droit',
      );

      // Et les deux ne portent PAS la même encre: la première est l'accent,
      // plus clair et plus vert que la seconde.
      expect(
        vertEn(14, 42),
        greaterThan(vertEn(82, 54)),
        reason:
            'les deux équerres sont de la même couleur; le handoff en '
            'demande deux',
      );
      expect(rougeEn(14, 42), greaterThan(rougeEn(82, 54)));
    });
  });

  testWidgets('les deux équerres occupent des coins opposés', (tester) async {
    await tester.runAsync(() async {
      final image = await peindre(
        const SafeLogoPainter(Color(0xFF2F7D5B), Color(0xFF183A2B)),
        96,
      );
      final octets = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      int alphaEn(int x, int y) => octets!.getUint8((y * 96 + x) * 4 + 3);

      // Le coin bas-gauche et le coin haut-droit restent nus: le fermoir est
      // une diagonale, pas un cadre.
      expect(alphaEn(14, 82), 0, reason: 'le coin bas-gauche est peint');
      expect(alphaEn(82, 14), 0, reason: 'le coin haut-droit est peint');
    });
  });

  testWidgets('la seconde couleur suit l\'encre du thème par défaut', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: const Scaffold(body: SafeLogo()),
      ),
    );
    final peintre =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(SafeLogo),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as SafeLogoPainter;
    expect(peintre.color, const Color(0xFF2F7D5B));
    expect(peintre.secondColor, const Color(0xFF183A2B));
  });
}
