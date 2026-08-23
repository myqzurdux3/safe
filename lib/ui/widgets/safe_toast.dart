import 'package:flutter/material.dart';

import '../theme/safe_theme.dart';

/// Durée totale d'un toast, fondus compris.
const Duration _toastDuration = Duration(milliseconds: 1500);

/// Distance au bord bas, au-dessus du pied de page.
const double _toastBottom = 84;

/// Le toast affiché en ce moment, par `Overlay`.
///
/// Il n'y en a jamais deux à la fois: deux copies rapprochées empilaient deux
/// pilules l'une sur l'autre, illisibles toutes les deux. Rattaché à son
/// `Overlay` et non gardé dans une variable de bibliothèque: une pilule d'un
/// écran mort suivrait sinon l'application entière, et son retrait viserait un
/// `Overlay` qui n'existe plus.
final Expando<OverlayEntry> _visible = Expando<OverlayEntry>('toast affiché');

/// Retire [entry] si c'est bien elle qui est sur [overlay].
///
/// La garde d'identité compte: une pilule remplacée peut avoir laissé une
/// demande de retrait en vol, qui retirerait sinon la pilule suivante.
void _hide(OverlayState overlay, OverlayEntry entry) {
  if (!identical(_visible[overlay], entry)) {
    return;
  }
  _visible[overlay] = null;
  // Sans condition. Une `OverlayEntry` n'est `mounted` qu'à partir de la
  // première image qui suit son insertion: sauter le retrait avant celle-ci
  // laissait la pilule dans l'`Overlay` pour toujours, et `dispose`, qui exige
  // un retrait préalable, levait par-dessus. `remove` sait déjà quoi faire d'un
  // `Overlay` démonté, et la garde d'identité ci-dessus assure qu'on ne passe
  // ici qu'une fois.
  entry.remove();
  entry.dispose();
}

/// Le toast de copie: pilule encre, 84 px au-dessus du bas, 1,5 s.
///
/// Passe par l'`Overlay` plutôt que par un `SnackBar`: la maquette veut une
/// pilule centrée et flottante, pas la barre pleine largeur de Material.
void showSafeToast(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) {
    return;
  }
  // Les tokens se lisent ici, sous l'écran appelant: l'`Overlay` est au-dessus
  // du `Theme` de la route et ne les verrait pas.
  final tokens = SafeTokens.of(context);
  final previous = _visible[overlay];
  if (previous != null) {
    _hide(overlay, previous);
  }
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _SafeToast(
      message: message,
      tokens: tokens,
      onFinished: () => _hide(overlay, entry),
    ),
  );
  overlay.insert(entry);
  _visible[overlay] = entry;
}

/// La pilule elle-même, qui compte son propre temps.
///
/// Sa durée de vie est portée par un `AnimationController` et non par un
/// `Timer`: le contrôleur meurt avec le widget, là où une minuterie survivrait
/// à l'écran — et, dans les tests, à la fin du test.
class _SafeToast extends StatefulWidget {
  const _SafeToast({
    required this.message,
    required this.tokens,
    required this.onFinished,
  });

  final String message;
  final SafeTokens tokens;
  final VoidCallback onFinished;

  @override
  State<_SafeToast> createState() => _SafeToastState();
}

class _SafeToastState extends State<_SafeToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _toastDuration)
        ..addStatusListener(_onStatus)
        ..forward();

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 68),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
  ]).animate(_controller);

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    // Après l'image en cours: retirer l'entrée d'ici disposerait le contrôleur
    // au milieu de sa propre notification.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onFinished());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    return Positioned(
      left: 0,
      right: 0,
      bottom: _toastBottom,
      // Le toast ne prend jamais le doigt: il flotte au-dessus du pied de page,
      // dont les boutons doivent rester atteignables pendant qu'il s'affiche.
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _opacity,
          child: Center(
            child: Material(
              type: MaterialType.transparency,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.ink,
                  borderRadius: BorderRadius.circular(SafeMetrics.pillRadius),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.toastShadow,
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  child: Text(
                    widget.message,
                    style: SafeText.action.copyWith(
                      color: tokens.onInk,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
