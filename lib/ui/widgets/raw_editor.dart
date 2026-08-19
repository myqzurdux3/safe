import 'package:flutter/material.dart';

import '../theme/safe_theme.dart';

/// La zone de saisie du texte d'une fiche.
///
/// Partagée par la fiche et la nouvelle fiche: c'est le même champ, et surtout
/// les mêmes garanties. Les deux réglages qui coupent l'apprentissage du
/// clavier tiennent en deux lignes, et deux écrans qui les recopient finissent
/// toujours par en oublier un.
class SafeRawEditor extends StatelessWidget {
  const SafeRawEditor({
    required this.controller,
    required this.hintText,
    super.key,
  });

  final TextEditingController controller;

  /// Le placeholder; la nouvelle fiche le donne sur deux lignes, la fiche
  /// existante sur une seule — c'est la seule différence entre les deux.
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    return TextField(
      key: const Key('raw'),
      controller: controller,
      // `expands`: le champ occupe la place qu'on lui donne et défile en son
      // sein, au lieu de grandir jusqu'à pousser le pied hors de l'écran.
      expands: true,
      maxLines: null,
      minLines: null,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: TextInputType.multiline,
      // Le clavier n'a pas à apprendre ce qui est chiffré dans le coffre: sans
      // ces deux réglages, Android range les secrets tapés dans son
      // dictionnaire personnel et les propose ensuite dans une autre
      // application — hors du coffre, et hors de son cycle de vie.
      autocorrect: false,
      enableSuggestions: false,
      style: SafeText.rawEditor.copyWith(color: tokens.ink),
      cursorColor: tokens.accent,
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        hintText: hintText,
        hintStyle: SafeText.rawEditor.copyWith(color: tokens.hintText),
      ),
    );
  }
}
