import 'package:flutter/material.dart';

import '../theme/safe_theme.dart';

/// Le bouton plein du handoff: pilule pleine largeur, 50 px, fond encre.
///
/// `onPressed` nul le rend inerte et grisé — c'est ce qui indique qu'une
/// saisie est en cours ou incomplète.
class SafePrimaryButton extends StatelessWidget {
  const SafePrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    return SizedBox(
      height: SafeMetrics.pillHeight,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: tokens.ink,
          foregroundColor: tokens.onInk,
          disabledBackgroundColor: tokens.controlBorder,
          disabledForegroundColor: tokens.hintText,
          // Le survol passe à l'accent: le seul retour visuel que le handoff
          // demande sur les boutons.
          overlayColor: tokens.accent,
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: safeSans,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
            height: 1,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Le bouton bordé: même forme, sans aplat. Sert aux actions de second rang,
/// « Pièce jointe » par exemple.
class SafeSecondaryButton extends StatelessWidget {
  const SafeSecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    return SizedBox(
      height: SafeMetrics.pillHeight,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.secondaryText,
          side: BorderSide(color: tokens.controlBorder),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: safeSans,
            fontWeight: FontWeight.w500,
            fontSize: 13.5,
            height: 1,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
