import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../model/vault.dart';
import '../state/vault_session.dart';

/// Affiche une taille en octets de façon lisible.
///
/// Le séparateur décimal vient des traductions et non d'un `replaceAll`: il
/// s'écrit avec une virgule en français et un point en anglais, et coder l'un
/// des deux en dur donnait un « 1.5 ko » ou un « 1,5 kB » faux selon la
/// langue.
String formatBytes(L t, int bytes) {
  if (bytes < 1024) {
    return t.sizeBytes(bytes);
  }
  if (bytes < 1024 * 1024) {
    return t.sizeKilobytes(bytes / 1024);
  }
  return t.sizeMegabytes(bytes / (1024 * 1024));
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
            .where((entry) => canonicalKey(entry.key) == canonicalKey(key))
            .firstOrNull
            ?.attachments ??
        const [];
  }

  Future<void> _add() async {
    // Lu avant le premier `await`: après, le contexte a pu disparaître.
    final t = L.of(context);
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
    var attached = false;
    try {
      final bytes = Uint8List.fromList(await file.readAsBytes());
      await widget.session.attach(
        entryKey: key,
        // Le sélecteur ne garantit pas un nom: certaines implémentations
        // rendent un fichier en mémoire, sans chemin ni nom. Une pièce jointe
        // sans nom serait indistinguable des autres dans la liste.
        name: file.name.trim().isEmpty
            ? t.attachmentAdd.toLowerCase()
            : file.name,
        mimeType: file.mimeType ?? guessMimeType(file.name),
        bytes: bytes,
      );
      // Hors du `try` par un `attachee`: si le parent s'est démonté, son
      // `setState` lèverait, et le `catch` annoncerait un échec alors que la
      // pièce jointe est bien enregistrée.
      attached = true;
    } on AttachmentTooLargeException catch (error) {
      _tell(
        t.attachmentTooBig(
          formatBytes(t, error.size),
          formatBytes(t, maxAttachmentBytes),
        ),
      );
    } catch (_) {
      _tell(t.attachmentAddFailed);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
    if (attached && mounted) {
      widget.onChanged();
    }
  }

  Future<void> _open(VaultAttachment attachment) async {
    // Lu avant le premier `await`: après, le contexte a pu disparaître.
    final t = L.of(context);
    setState(() => _busy = true);
    try {
      final bytes = await widget.session.readAttachment(attachment);
      if (!mounted) {
        return;
      }
      try {
        if (attachment.isImage) {
          await showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: InteractiveViewer(
                      child: Image.memory(
                        bytes,
                        semanticLabel: attachment.name,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t.close),
                  ),
                ],
              ),
            ),
          );
        } else {
          await _exportBytes(attachment, bytes);
        }
      } finally {
        // Le clair ne survit pas à son usage: la visionneuse est fermée, ou le
        // fichier est écrit. `Image.memory` a déjà décodé de son côté, et ce
        // décodage-là n'est pas effaçable — mais le tampon source, lui, l'est.
        bytes.fillRange(0, bytes.length, 0);
      }
    } catch (_) {
      _tell(t.attachmentReadFailed);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _exportBytes(VaultAttachment attachment, Uint8List bytes) async {
    // Lu avant le premier `await`: après, le contexte a pu disparaître.
    final t = L.of(context);
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
      _tell(t.attachmentSavedPlain(location.path));
    }
  }

  /// Déchiffre puis sort une pièce jointe.
  ///
  /// Passe par `_busy` comme les autres: sans lui, deux appuis rapides
  /// ouvraient deux boîtes d'enregistrement, et un déchiffrement raté ne disait
  /// rien du tout.
  Future<void> _export(VaultAttachment attachment) async {
    // Lu avant le premier `await`: après, le contexte a pu disparaître.
    final t = L.of(context);
    setState(() => _busy = true);
    try {
      final bytes = await widget.session.readAttachment(attachment);
      try {
        await _exportBytes(attachment, bytes);
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
    } catch (_) {
      _tell(t.attachmentExportFailed);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _detach(VaultAttachment attachment) async {
    // Lu avant le premier `await`: après, le contexte a pu disparaître.
    final t = L.of(context);
    final key = widget.entryKey;
    if (key == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.attachmentDeleteTitle),
        content: Text(t.attachmentDeleteBody(attachment.name)),
        actions: [
          TextButton(
            key: const Key('cancel-detach'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.cancel),
          ),
          FilledButton(
            key: const Key('confirm-detach'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.delete),
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
      _tell(t.attachmentDeleteFailed);
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
    final t = L.of(context);
    final attachments = _attachments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(t.attachmentsTitle, style: theme.textTheme.titleMedium),
            const Spacer(),
            if (widget.entryKey != null)
              TextButton.icon(
                key: const Key('attach'),
                onPressed: _busy ? null : _add,
                icon: const Icon(Icons.attach_file),
                label: Text(t.add),
              ),
          ],
        ),
        if (widget.entryKey == null)
          Text(t.attachmentsSaveFirst, style: theme.textTheme.bodySmall)
        else if (attachments.isEmpty)
          Text(
            t.attachmentsEmpty(formatBytes(t, maxAttachmentBytes)),
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
              title: Text(
                attachment.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(formatBytes(t, attachment.size)),
              onTap: _busy ? null : () => _open(attachment),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: Key('export-${attachment.id}'),
                    icon: const Icon(Icons.save_alt),
                    tooltip: t.attachmentExportLabel(attachment.name),
                    onPressed: _busy ? null : () => _export(attachment),
                  ),
                  IconButton(
                    key: Key('detach-${attachment.id}'),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: t.attachmentDeleteLabel(attachment.name),
                    onPressed: _busy ? null : () => _detach(attachment),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
