import 'package:flutter/material.dart';

import '../theme/safe_theme.dart';

/// Les trois règles de la syntaxe, dans l'ordre où on les rencontre.
const List<(String, String)> _rules = [
  ('courrier:', 'ouvre un bloc'),
  ('(ligne vide)', 'le referme'),
  ('texte seul', 'reste un commentaire, à sa place'),
];

/// Le tuto de syntaxe de la fiche.
///
/// Affiché par défaut, écarté une fois pour toutes par « Compris ». Il porte
/// aussi le geste qui remasque une entrée d'avant la refonte — une valeur d'une
/// seule ligne est un commentaire, donc en clair, jusqu'à ce qu'on lui ajoute
/// une ligne « nom: ».
class SyntaxTutorial extends StatelessWidget {
  const SyntaxTutorial({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.softAccentSurface,
        borderRadius: BorderRadius.circular(SafeMetrics.cardRadius),
      ),
      child: Stack(
        children: [
          // « Compris » fait onze pixels de haut: viser la lettre serait viser
          // un cheveu. La bande basse de la carte — vide sous la troisième
          // règle — écarte le tuto elle aussi, sans que rien ne se déplace à
          // l'écran. Elle est **derrière** le contenu: le libellé reste la
          // cible qu'on désigne, la bande ne fait que rattraper les doigts
          // qui tombent à côté.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: SafeMetrics.touchTarget,
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
              ),
            ),
          ),
          _content(tokens),
        ],
      ),
    );
  }

  Widget _content(SafeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (example, gloss) in _rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // L'exemple est du texte tapé par l'utilisateur: mono,
                  // comme partout où une donnée se relit caractère par
                  // caractère.
                  Text(
                    example,
                    style: const TextStyle(
                      fontFamily: safeMono,
                      fontSize: 11.5,
                      height: 1.4,
                    ).copyWith(color: tokens.accentDark),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      gloss,
                      style: const TextStyle(
                        fontFamily: safeSans,
                        fontSize: 11.5,
                        height: 1.4,
                      ).copyWith(color: tokens.softAccentText),
                    ),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: Padding(
                // Le libellé est aligné à droite: cette marge gauche élargit
                // la cible sans déplacer la lettre d'un pixel.
                padding: const EdgeInsets.only(top: 8, left: 12, bottom: 2),
                child: Text(
                  'Compris',
                  style: SafeText.action.copyWith(
                    fontWeight: FontWeight.w500,
                    color: tokens.accentDark,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
