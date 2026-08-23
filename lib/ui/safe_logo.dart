import 'package:flutter/material.dart';

import 'theme/safe_theme.dart';

/// Le logo de safe: le « fermoir », deux équerres qui s'emboîtent.
///
/// C'est la marque **C** de la planche `1a` du handoff, préférée au
/// monogramme S (marque B) qu'elle remplace. Deux équerres qui s'emboîtent
/// sans se toucher: verrouillé quand elles s'alignent, entrouvert quand elles
/// glissent. Le centre du carré reste vide — c'est ce qui la distingue du S,
/// dont les deux arcs se rejoignaient précisément là.
///
/// Dessinée plutôt qu'importée: le trait reste net à toutes les tailles et
/// prend les couleurs qu'on lui donne, ce qu'une image figée ne ferait pas.
///
/// Le tracé du handoff, dans un carré de 48:
///
///     M32 7 H16 A9 9 0 0 0 7 16 V26      (accent)
///     M16 41 H32 A9 9 0 0 0 41 32 V22    (encre)
class SafeLogo extends StatelessWidget {
  const SafeLogo({this.size = 34, this.color, this.secondColor, super.key});

  final double size;

  /// Trait de l'équerre du haut. Par défaut l'accent du thème.
  final Color? color;

  /// Trait de l'équerre du bas. Par défaut l'encre.
  ///
  /// Pour une version une-couleur — une barre système, un gabarit foncé —
  /// passer la même valeur aux deux.
  final Color? secondColor;

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: SafeLogoPainter(
          color ?? tokens.accent,
          secondColor ?? tokens.ink,
        ),
        isComplex: false,
      ),
    );
  }
}

/// Public pour que les tests puissent lire les couleurs effectivement peintes.
class SafeLogoPainter extends CustomPainter {
  const SafeLogoPainter(this.color, this.secondColor);

  final Color color;
  final Color secondColor;

  /// Côté du carré de référence du tracé.
  static const double _box = 48;

  /// Épaisseur du trait, exprimée dans ce même carré.
  static const double _stroke = 7;

  /// `M32 7 H16 A9 9 0 0 0 7 16 V26` — l'équerre du haut.
  static Path equerreHaute() => Path()
    ..moveTo(32, 7)
    ..lineTo(16, 7)
    // A9 9 0 0 0 7 16: petit arc, sweep 0, donc `clockwise: false`.
    ..arcToPoint(
      const Offset(7, 16),
      radius: const Radius.circular(9),
      clockwise: false,
    )
    ..lineTo(7, 26);

  /// `M16 41 H32 A9 9 0 0 0 41 32 V22` — celle du bas, par symétrie centrale.
  static Path equerreBasse() => Path()
    ..moveTo(16, 41)
    ..lineTo(32, 41)
    ..arcToPoint(
      const Offset(41, 32),
      radius: const Radius.circular(9),
      clockwise: false,
    )
    ..lineTo(41, 22);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _box;
    canvas.save();
    canvas.scale(scale);

    Paint trait(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = c
      ..isAntiAlias = true;

    canvas.drawPath(equerreHaute(), trait(color));
    canvas.drawPath(equerreBasse(), trait(secondColor));
    canvas.restore();
  }

  @override
  bool shouldRepaint(SafeLogoPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.secondColor != secondColor;
}
