import 'package:flutter/material.dart';

import '../../model/entry_text.dart';
import '../theme/safe_theme.dart';

/// Un bloc titré: replié, il masque ses lignes; ouvert, il les montre.
///
/// **L'ouverture est le geste de révélation.** Il n'y a donc pas de second
/// bouton « voir » par ligne: une ligne visible est une ligne dont le bloc a
/// été ouvert exprès.
class BlockCard extends StatelessWidget {
  const BlockCard({
    required this.group,
    required this.firstLineIndex,
    required this.open,
    required this.onToggle,
    required this.onCopyLine,
    required this.onCopyBlock,
    super.key,
  });

  final EntryGroup group;

  /// Rang de la première ligne du bloc dans la fiche entière, commentaires
  /// compris. Les clefs de copie sont numérotées sur le document, pas sur le
  /// bloc: c'est ainsi qu'on désigne une ligne sans ambiguïté.
  final int firstLineIndex;

  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<String> onCopyLine;
  final VoidCallback onCopyBlock;

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Repliée, toute la carte ouvre le bloc. Ouverte, seul son en-tête le
      // referme: un doigt posé sur une valeur ne doit pas la remasquer.
      onTap: open ? null : onToggle,
      child: AnimatedContainer(
        duration: SafeMetrics.transition,
        padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
        decoration: BoxDecoration(
          color: tokens.cardSurface,
          borderRadius: BorderRadius.circular(SafeMetrics.cardRadius),
          border: Border.all(
            color: open ? tokens.accent : tokens.hairline,
            width: open ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(tokens),
            if (open)
              for (var offset = 0; offset < group.lines.length; offset++)
                _line(tokens, offset),
          ],
        ),
      ),
    );
  }

  Widget _header(SafeTokens tokens) {
    final lines = group.lines.length;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Row(
        children: [
          AnimatedRotation(
            duration: SafeMetrics.transition,
            turns: open ? 0 : -0.25,
            child: Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: open ? tokens.accentDark : tokens.tertiaryText,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              // Le titre s'affiche en majuscules; le texte enregistré, lui,
              // garde la casse tapée.
              (group.title ?? '').toUpperCase(),
              style: SafeText.blockTitle.copyWith(
                color: open ? tokens.accentDark : tokens.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (open)
            SafeCopyAction(label: 'copier le bloc', onTap: onCopyBlock)
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '$lines ligne${lines > 1 ? 's' : ''}',
                style: SafeText.counter.copyWith(color: tokens.tertiaryText),
              ),
            ),
        ],
      ),
    );
  }

  Widget _line(SafeTokens tokens, int offset) {
    final value = group.lines[offset];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            // Sans `maxLines`: une valeur longue se replie sur plusieurs lignes
            // plutôt que de se faire tronquer par des points de suspension, qui
            // en cacheraient la fin sans le dire.
            child: Text(
              value,
              style: SafeText.entryValue.copyWith(color: tokens.ink),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
          SafeCopyAction(
            key: Key('copy-line-${firstLineIndex + offset}'),
            label: 'copier',
            onTap: () => onCopyLine(value),
          ),
        ],
      ),
    );
  }
}

/// Un groupe sans titre: une note, pas un secret.
///
/// Affiché en clair sans aucun geste — c'est la règle du handoff, et elle vaut
/// aussi pour les entrées d'avant la refonte, dont la valeur d'une seule ligne
/// n'a pas de titre.
class CommentBlock extends StatelessWidget {
  const CommentBlock({required this.group, required this.onCopy, super.key});

  final EntryGroup group;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    return Container(
      // Pas de carte: un filet vertical suffit à le rattacher au fil du texte
      // sans lui donner le poids d'un bloc.
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: tokens.commentRule, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              group.lines.join('\n'),
              style: SafeText.comment.copyWith(color: tokens.commentText),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
          SafeCopyAction(label: 'copier', onTap: onCopy),
        ],
      ),
    );
  }
}

/// L'action textuelle « copier », partagée par les lignes et les commentaires.
class SafeCopyAction extends StatelessWidget {
  const SafeCopyAction({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        // La marge est la cible du doigt: le libellé fait onze pixels de haut,
        // la zone touchable en fait une trentaine.
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Text(
          label,
          style: SafeText.action.copyWith(color: tokens.accent),
        ),
      ),
    );
  }
}
