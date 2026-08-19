import 'package:flutter/material.dart';

import 'theme/safe_theme.dart';

/// Le logo de safe: un S géométrique d'un seul trait.
///
/// Deux demi-cercles enchaînés, dessinés plutôt qu'importés: le trait reste
/// net à toutes les tailles et prend la couleur qu'on lui donne, ce qu'une
/// image figée ne ferait pas.
///
/// Le tracé du handoff, dans un carré de 48:
///
///     M34 14 A10 10 0 1 0 24 24 A10 10 0 1 1 14 34
class SafeLogo extends StatelessWidget {
  const SafeLogo({this.size = 34, this.color, super.key});

  final double size;

  /// Par défaut l'accent du thème; `ink` pour la version foncée.
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: SafeLogoPainter(color ?? SafeTokens.of(context).accent),
      isComplex: false,
    ),
  );
}

/// Public pour que les tests puissent lire la couleur effectivement peinte.
class SafeLogoPainter extends CustomPainter {
  const SafeLogoPainter(this.color);

  final Color color;

  /// Côté du carré de référence du tracé.
  static const double _box = 48;

  /// Épaisseur du trait, exprimée dans ce même carré.
  static const double _stroke = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _box;
    canvas.save();
    canvas.scale(scale);

    final path = Path()
      ..moveTo(34, 14)
      // A10 10 0 1 0 24 24: grand arc, sens antihoraire.
      ..arcToPoint(
        const Offset(24, 24),
        radius: const Radius.circular(10),
        largeArc: true,
        clockwise: false,
      )
      // A10 10 0 1 1 14 34: grand arc, sens horaire.
      ..arcToPoint(
        const Offset(14, 34),
        radius: const Radius.circular(10),
        largeArc: true,
        clockwise: true,
      );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = color
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(SafeLogoPainter oldDelegate) => oldDelegate.color != color;
}
