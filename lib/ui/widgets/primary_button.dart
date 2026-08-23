import 'package:flutter/material.dart';

import '../theme/safe_theme.dart';

/// Le bouton plein du handoff: pilule pleine largeur, 50 px, fond encre.
///
/// `onPressed` nul le rend inerte et grisé — c'est ce qui indique qu'une
/// saisie est en cours ou incomplète. `busy` sert un autre cas: une attente
/// dont le résultat n'est pas encore en cause, simplement pas encore là —
/// une dérivation Argon2id, plusieurs secondes sur un téléphone. Un bouton
/// grisé ne s'en distingue pas d'un bouton invalide, et pousse à retaper.
class SafePrimaryButton extends StatelessWidget {
  const SafePrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    super.key,
  });

  final String label;

  /// Pictogramme posé devant le libellé, ou nul — le cas courant.
  ///
  /// Il vient de MaterialIcons, livrée avec l'application: les deux polices
  /// embarquées n'ont pas de glyphe pour les signes qu'on serait tenté
  /// d'écrire dans le libellé (« ✓ », « ↻ »), et Android se rabattrait alors
  /// sur une autre fonte au milieu du texte, quand il en a une.
  final IconData? icon;

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    return SizedBox(
      height: SafeMetrics.pillHeight,
      width: double.infinity,
      child: FilledButton(
        // Occupé reste désactivé, quel que soit `onPressed`: un second appui
        // pendant la dérivation ne doit pas relancer une seconde fois.
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: tokens.ink,
          foregroundColor: tokens.onInk,
          // Occupé garde les couleurs actives: le bouton attend un résultat,
          // il n'est pas invalide. Le grisé (`controlBorder`/`hintText`)
          // reste réservé au cas `onPressed` nul sans attente en cours.
          disabledBackgroundColor: busy ? tokens.ink : tokens.controlBorder,
          disabledForegroundColor: busy ? tokens.onInk : tokens.hintText,
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
        child: busy
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tokens.onInk,
                ),
              )
            : icon == null
            ? Text(label)
            : Row(
                // Le bouton garde sa largeur — elle est imposée par le parent
                // — et l'icône, plus basse que la pilule, ne change pas sa
                // hauteur non plus.
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sans couleur écrite: le bouton pose la sienne, celle de
                  // son libellé, et l'icône suit l'état actif ou grisé.
                  Icon(icon, size: 15),
                  const SizedBox(width: 6),
                  Text(label),
                ],
              ),
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
