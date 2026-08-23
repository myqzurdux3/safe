import 'package:flutter/material.dart';

/// Demande confirmation avant de jeter une saisie en cours.
///
/// Partagée par les deux écrans qui modifient une entrée: le retour arrière est
/// le geste le plus facile à faire par erreur, et les deux doivent y répondre
/// du même mot. Rend `false` si la boîte est écartée sans choisir — l'inaction
/// garde la saisie.
Future<bool> confirmDiscard(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Abandonner les modifications ?'),
      content: const Text('La saisie en cours ne sera pas enregistrée.'),
      actions: [
        TextButton(
          key: const Key('cancel-discard'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Continuer la saisie'),
        ),
        FilledButton(
          key: const Key('confirm-discard'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Abandonner'),
        ),
      ],
    ),
  );
  return discard ?? false;
}
