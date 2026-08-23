import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Demande confirmation avant de jeter une saisie en cours.
///
/// Partagée par les deux écrans qui modifient une entrée: le retour arrière est
/// le geste le plus facile à faire par erreur, et les deux doivent y répondre
/// du même mot. Rend `false` si la boîte est écartée sans choisir — l'inaction
/// garde la saisie.
Future<bool> confirmDiscard(BuildContext context) async {
  final t = L.of(context);
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t.discardTitle),
      content: Text(t.discardBody),
      actions: [
        TextButton(
          key: const Key('cancel-discard'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.discardKeepEditing),
        ),
        FilledButton(
          key: const Key('confirm-discard'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(t.discardConfirm),
        ),
      ],
    ),
  );
  return discard ?? false;
}
