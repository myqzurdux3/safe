import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/safe_theme.dart';

/// Les onglets pilule du handoff: un conteneur teinté, une pastille claire
/// posée sur l'onglet actif.
///
/// Le widget mesure au moins [SafeMetrics.touchTarget] de haut, la barre
/// visible restant à `height + 8`: l'écart est de la marge touchable, répartie
/// également au-dessus et au-dessous. Un onglet de 28 px reste un onglet de
/// 28 px à l'œil, mais le doigt en trouve 48. Les écrans qui posent cette barre
/// reprennent cette marge sur leurs propres écarts, pour que rien ne bouge.
class SafePillTabs extends StatelessWidget {
  const SafePillTabs({
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.height = SafeMetrics.tabHeight,
    super.key,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  /// Hauteur d'une pastille: 36 px pour les onglets d'un écran, 28 px pour la
  /// barre de mode d'une fiche, qui vit sous un titre et ne doit pas lui
  /// disputer la place.
  final double height;

  /// Hauteur de la barre visible: les pastilles plus les 4 px de marge du
  /// handoff, de part et d'autre.
  double get _barHeight => height + 8;

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    final outer = math.max(_barHeight, SafeMetrics.touchTarget);
    return SizedBox(
      height: outer,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: (outer - _barHeight) / 2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.tabContainer,
                borderRadius: BorderRadius.circular(
                  SafeMetrics.tabContainerRadius,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                for (var index = 0; index < labels.length; index++)
                  Expanded(child: _pill(tokens, index)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(SafeTokens tokens, int index) {
    final active = index == selected;
    return GestureDetector(
      // Opaque, et sur toute la hauteur touchable: sans cela le doigt tomberait
      // entre les lettres du libellé, ou dans la marge au-dessus de la barre.
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelected(index),
      child: Center(
        child: AnimatedContainer(
          duration: SafeMetrics.transition,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // La pastille inactive prend la couleur du conteneur plutôt que du
            // transparent: c'est la même chose à l'œil, et la couleur peut
            // s'animer d'un onglet à l'autre au lieu de sauter.
            color: active ? tokens.cardSurface : tokens.tabContainer,
            borderRadius: BorderRadius.circular(SafeMetrics.tabRadius),
            // La seule ombre de l'écran, et elle sert à dire lequel est actif.
            boxShadow: active
                ? [
                    BoxShadow(
                      color: tokens.tabShadow,
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: AnimatedDefaultTextStyle(
            duration: SafeMetrics.transition,
            style: TextStyle(
              fontFamily: safeSans,
              fontSize: 12.5,
              height: 1,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? tokens.ink : tokens.secondaryText,
            ),
            child: Text(labels[index]),
          ),
        ),
      ),
    );
  }
}
