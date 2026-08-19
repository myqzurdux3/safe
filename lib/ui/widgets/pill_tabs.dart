import 'package:flutter/material.dart';

import '../theme/safe_theme.dart';

/// Les onglets pilule du handoff: un conteneur teinté, une pastille claire
/// posée sur l'onglet actif.
///
/// La pastille inactive prend la couleur du conteneur plutôt que du
/// transparent: c'est la même chose à l'œil, et cela laisse la couleur
/// s'animer d'un onglet à l'autre au lieu de sauter.
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

  /// 36 px pour les onglets d'un écran, 28 px pour la barre de mode d'une
  /// fiche, qui vit sous un titre et ne doit pas lui disputer la place.
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.tabContainer,
        borderRadius: BorderRadius.circular(SafeMetrics.tabContainerRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (var index = 0; index < labels.length; index++)
              Expanded(child: _pill(tokens, index)),
          ],
        ),
      ),
    );
  }

  Widget _pill(SafeTokens tokens, int index) {
    final active = index == selected;
    return GestureDetector(
      // Opaque: la pastille inactive n'a pas d'aplat propre, et sans cela le
      // doigt tomberait entre les lettres du libellé.
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelected(index),
      child: AnimatedContainer(
        duration: SafeMetrics.transition,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
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
    );
  }
}
