import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../model/vault.dart';
import '../state/vault_session.dart';

/// Affiche une taille en octets de façon lisible.
String formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes o';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1).replaceAll('.', ',')} ko';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} Mo';
}

/// Devine le type d'un fichier à partir de son extension.
///
/// Le sélecteur de fichiers ne renseigne pas toujours le type; il ne sert ici
/// qu'à choisir entre un aperçu image et un export.
String guessMimeType(String fileName) {
  final extension = fileName.toLowerCase().split('.').last;
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'pdf' => 'application/pdf',
    'txt' || 'md' => 'text/plain',
    _ => 'application/octet-stream',
  };
}

/// Section « Pièces jointes » de l'écran d'édition.
///
/// Une pièce jointe ne peut être ajoutée qu'à une entrée déjà enregistrée: son
/// blob est référencé par la clef de l'entrée, qui doit donc exister.
class AttachmentsSection extends StatefulWidget {
  const AttachmentsSection({
    required this.session,
    required this.entryKey,
    required this.onChanged,
    super.key,
  });

  final VaultSession session;

  /// Nul en création: l'entrée n'existe pas encore.
  final String? entryKey;
  final VoidCallback onChanged;

  @override
  State<AttachmentsSection> createState() => _AttachmentsSectionState();
}

class _AttachmentsSectionState extends State<AttachmentsSection> {
  bool _busy = false;

  List<VaultAttachment> get _attachments {
    final key = widget.entryKey;
    if (key == null) {
      return const [];
    }
    return widget.session.vault?.entries
            .where((entry) => entry.key == key)
            .firstOrNull
            ?.attachments ??
        const [];
  }

  Future<void> _add() async {
    final key = widget.entryKey;
    if (key == null) {
      return;
    }
    final file = await openFile();
    if (file == null) {
      return;
    }
    // Le sélecteur natif peut rester ouvert plusieurs minutes: le verrouillage
    // automatique a pu dépiler cet écran entre-temps.
    if (!mounted) {
      return;
    }
    setState(() => _busy = true);
    var attachee = false;
    try {
      final bytes = Uint8List.fromList(await file.readAsBytes());
      await widget.session.attach(
        entryKey: key,
        name: file.name,
        mimeType: file.mimeType ?? guessMimeType(file.name),
        bytes: bytes,
      );
      // Hors du `try` par un `attachee`: si le parent s'est démonté, son
      // `setState` lèverait, et le `catch` annoncerait un échec alors que la
      // pièce jointe est bien enregistrée.
      attachee = true;
    } on AttachmentTooLargeException catch (error) {
      _tell(
        'Fichier trop gros (${formatBytes(error.size)}); maximum '
        '${formatBytes(maxAttachmentBytes)}',
      );
    } catch (_) {
      _tell('Impossible de joindre ce fichier');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
    if (attachee && mounted) {
      widget.onChanged();
    }
  }

  Future<void> _open(VaultAttachment attachment) async {
    setState(() => _busy = true);
    try {
      final bytes = await widget.session.readAttachment(attachment);
      if (!mounted) {
        return;
      }
      if (attachment.isImage) {
        await showDialog<void>(
          context: context,
          builder: (context) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: InteractiveViewer(child: Image.memory(bytes))),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fermer'),
                ),
              ],
            ),
          ),
        );
      } else {
        await _exportBytes(attachment, bytes);
      }
    } catch (_) {
      _tell('Lecture impossible: pièce jointe absente ou coffre verrouillé');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _exportBytes(
    VaultAttachment attachment,
    Uint8List bytes,
  ) async {
    // Sortir une pièce jointe la rend lisible en clair sur le disque: c'est le
    // seul moment où le contenu quitte le coffre, et c'est un choix explicite.
    if (Platform.isAndroid || Platform.isIOS) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: attachment.mimeType)],
          fileNameOverrides: [attachment.name],
        ),
      );
      return;
    }
    final location = await getSaveLocation(suggestedName: attachment.name);
    if (location != null) {
      await File(location.path).writeAsBytes(bytes);
      _tell('Enregistré en clair dans ${location.path}');
    }
  }

  /// Déchiffre puis sort une pièce jointe.
  ///
  /// Passe par `_busy` comme les autres: sans lui, deux appuis rapides
  /// ouvraient deux boîtes d'enregistrement, et un déchiffrement raté ne disait
  /// rien du tout.
  Future<void> _export(VaultAttachment attachment) async {
    setState(() => _busy = true);
    try {
      await _exportBytes(
        attachment,
        await widget.session.readAttachment(attachment),
      );
    } catch (_) {
      _tell('Export impossible: pièce jointe absente ou coffre verrouillé');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _detach(VaultAttachment attachment) async {
    final key = widget.entryKey;
    if (key == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette pièce jointe ?'),
        content: Text('« ${attachment.name} » sera effacée définitivement.'),
        actions: [
          TextButton(
            key: const Key('cancel-detach'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const Key('confirm-detach'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) {
      return;
    }
    try {
      await widget.session.removeAttachment(
        entryKey: key,
        attachment: attachment,
      );
    } catch (_) {
      _tell('Suppression impossible: le coffre s\'est peut-être verrouillé');
      return;
    }
    if (mounted) {
      widget.onChanged();
      setState(() {});
    }
  }

  void _tell(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attachments = _attachments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Pièces jointes', style: theme.textTheme.titleMedium),
            const Spacer(),
            if (widget.entryKey != null)
              TextButton.icon(
                key: const Key('attach'),
                onPressed: _busy ? null : _add,
                icon: const Icon(Icons.attach_file),
                label: const Text('Ajouter'),
              ),
          ],
        ),
        if (widget.entryKey == null)
          Text(
            'Enregistrez l\'entrée pour pouvoir y joindre des photos ou des '
            'documents.',
            style: theme.textTheme.bodySmall,
          )
        else if (attachments.isEmpty)
          Text(
            'Aucune pièce jointe. Maximum '
            '${formatBytes(maxAttachmentBytes)} par fichier.',
            style: theme.textTheme.bodySmall,
          )
        else
          for (final attachment in attachments)
            ListTile(
              key: Key('attachment-${attachment.id}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                attachment.isImage
                    ? Icons.image_outlined
                    : Icons.description_outlined,
              ),
              title: Text(attachment.name),
              subtitle: Text(formatBytes(attachment.size)),
              onTap: _busy ? null : () => _open(attachment),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: Key('export-${attachment.id}'),
                    icon: const Icon(Icons.save_alt),
                    tooltip: 'Exporter en clair',
                    onPressed: _busy ? null : () => _export(attachment),
                  ),
                  IconButton(
                    key: Key('detach-${attachment.id}'),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Supprimer',
                    onPressed: _busy ? null : () => _detach(attachment),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
