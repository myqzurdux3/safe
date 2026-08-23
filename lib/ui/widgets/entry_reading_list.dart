import 'package:flutter/material.dart';

import '../../model/entry_text.dart';
import '../theme/safe_theme.dart';
import 'block_card.dart';

/// Le panneau de lecture d'une fiche: ses groupes, dans l'ordre du document.
///
/// Il porte la numérotation des lignes, qui court sur la **fiche entière**,
/// commentaires compris: c'est elle qui permet de désigner une ligne sans
/// ambiguïté, et c'est la seule règle non triviale de l'écran.
class EntryReadingList extends StatelessWidget {
  const EntryReadingList({
    required this.groups,
    required this.open,
    required this.onToggle,
    required this.onCopy,
    super.key,
  });

  final List<EntryGroup> groups;

  /// Index des groupes ouverts, dans la numérotation de [groups].
  final Set<int> open;

  final ValueChanged<int> onToggle;

  /// Reçoit le texte à copier, déjà prêt: les lignes brutes du coffre, pas
  /// celles, rognées, qui s'affichent.
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    if (groups.isEmpty) {
      return Center(
        child: Text(
          'Cette fiche est vide.\nPassez en « Texte brut » pour la remplir.',
          textAlign: TextAlign.center,
          style: SafeText.meta.copyWith(color: tokens.hintText),
        ),
      );
    }
    final children = <Widget>[];
    var line = 0;
    for (var index = 0; index < groups.length; index++) {
      final group = groups[index];
      final first = line;
      line += group.lines.length;
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 9));
      }
      children.add(
        group.isComment
            ? CommentBlock(
                group: group,
                onCopy: () => onCopy(group.rawLines.join('\n')),
              )
            : BlockCard(
                group: group,
                firstLineIndex: first,
                open: open.contains(index),
                onToggle: () => onToggle(index),
                onCopyLine: onCopy,
                onCopyBlock: () => onCopy(group.rawLines.join('\n')),
              ),
      );
    }
    // Une liste défilante, pas une colonne figée: un bloc long doit pouvoir
    // sortir de l'écran par le bas plutôt que d'être coupé sans le dire.
    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: children,
    );
  }
}
