import 'package:flutter/material.dart';

/// Le logo de safe, dessiné plutôt qu'importé.
///
/// Même géométrie que l'icône de lancement (`tool/generate_icons.py`): un
/// bouclier percé d'une serrure. Dessiné au trait, il reste net à toutes les
/// tailles et prend la couleur du thème, ce qu'une image figée ne ferait pas.
class SafeLogo extends StatelessWidget {
  const SafeLogo({this.size = 72, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _SafeLogoPainter(Theme.of(context).colorScheme.primary),
      isComplex: false,
    ),
  );
}

class _SafeLogoPainter extends CustomPainter {
  const _SafeLogoPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.86;
    final h = w * 1.22;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final left = cx - w / 2;
    final right = cx + w / 2;
    final top = cy - h / 2;
    final bottom = cy + h / 2;
    final shoulder = top + h * 0.40;
    final corner = w * 0.30;

    final shield = Path()
      ..moveTo(left + corner, top)
      ..quadraticBezierTo(left, top, left, top + corner)
      ..lineTo(left, shoulder)
      ..quadraticBezierTo(left + w * 0.02, bottom - h * 0.22, cx, bottom)
      ..quadraticBezierTo(right - w * 0.02, bottom - h * 0.22, right, shoulder)
      ..lineTo(right, top + corner)
      ..quadraticBezierTo(right, top, right - corner, top)
      ..close();

    // La serrure est un trou, pas un dessin par-dessus: le fond de l'écran la
    // traverse, comme sur l'icône.
    final radius = w * 0.165;
    final holeCy = cy - h * 0.07;
    final stemTop = holeCy + radius * 0.30;
    final stemHeight = h * 0.24;
    final keyhole = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, holeCy), radius: radius))
      ..addPolygon([
        Offset(cx - radius * 0.39, stemTop),
        Offset(cx + radius * 0.39, stemTop),
        Offset(cx + radius * 0.81, stemTop + stemHeight),
        Offset(cx - radius * 0.81, stemTop + stemHeight),
      ], true);

    canvas.drawPath(
      Path.combine(PathOperation.difference, shield, keyhole),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_SafeLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}
