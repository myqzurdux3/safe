import 'package:flutter/material.dart';

import '../../state/vault_session.dart';
import '../attachments_section.dart';
import '../theme/safe_theme.dart';

/// Ouvre les pièces jointes d'une entrée dans une feuille modale.
///
/// La tuyauterie est ici et non dans l'écran: la feuille se redessine elle-même
/// quand une pièce jointe arrive ou part, et l'écran hôte doit se redessiner
/// **aussi** — sa liste porte le même contenu. Un appelant qui recopierait ce
/// couplage en oublierait une moitié; la fiche est le seul aujourd'hui, l'écran
/// d'accueil est attendu.
///
/// [entryKey] désigne forcément une entrée déjà enregistrée: un blob est
/// référencé par la clef de son entrée, qui doit donc exister. C'est pourquoi la
/// nouvelle fiche n'ouvre pas cette feuille.
///
/// [onChanged] est appelé pendant que la feuille est ouverte: l'appelant reste
/// responsable de vérifier qu'il est toujours monté — un verrouillage peut
/// avoir dépilé son écran sous la feuille.
Future<void> showAttachmentsSheet({
  required BuildContext context,
  required VaultSession session,
  required String entryKey,
  required VoidCallback onChanged,
}) {
  session.touch();
  return showModalBottomSheet<void>(
    context: context,
    // Le clavier peut s'ouvrir par-dessus (renommer une pièce jointe): sans
    // cela, la feuille resterait sous lui.
    isScrollControlled: true,
    builder: (sheet) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.only(
          left: SafeMetrics.gutter,
          right: SafeMetrics.gutter,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: AttachmentsSection(
            session: session,
            entryKey: entryKey,
            onChanged: () {
              setSheetState(() {});
              onChanged();
            },
          ),
        ),
      ),
    ),
  );
}
