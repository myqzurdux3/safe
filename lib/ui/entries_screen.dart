import 'package:flutter/material.dart';

import '../model/vault.dart';
import '../state/vault_session.dart';
import '../storage/app_settings.dart';
import '../storage/vault_transfer.dart';
import '../util/clipboard.dart';
import 'entry_edit_screen.dart';
import 'settings_screen.dart';

/// Liste des entrées du coffre déverrouillé.
///
/// Les valeurs restent masquées tant que l'utilisateur ne les révèle pas
/// explicitement, entrée par entrée: un coffre ouvert sur un écran partagé ne
/// doit pas tout afficher d'un coup.
class EntriesScreen extends StatefulWidget {
  const EntriesScreen({
    required this.session,
    this.clipboard,
    this.transfer,
    this.settings,
    super.key,
  });

  final VaultSession session;

  /// Préférences de l'application, transmises à l'écran de réglages.
  final SettingsStore? settings;

  /// Presse-papier auto-effaçant; celui par défaut suffit hors tests.
  final SecureClipboard? clipboard;

  /// Export/import; absent dans les tests d'interface, où aucun fichier réel
  /// n'est manipulé.
  final VaultTransfer? transfer;

  @override
  State<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends State<EntriesScreen> {
  final _searchController = TextEditingController();
  late final SecureClipboard _clipboard = widget.clipboard ?? SecureClipboard();

  final Set<String> _revealed = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    _searchController.dispose();
    if (widget.clipboard == null) {
      _clipboard.dispose();
    }
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) {
      // Une entrée révélée ne doit pas le rester après un verrouillage.
      if (!widget.session.isUnlocked) {
        _revealed.clear();
      }
      setState(() {});
    }
  }

  Future<void> _copy(VaultEntry entry) async {
    widget.session.touch();
    await _clipboard.copy(entry.value);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Valeur copiée — le presse-papier sera effacé dans '
          '${_clipboard.clearAfter.inSeconds} s',
        ),
      ),
    );
  }

  Future<void> _openEditor({VaultEntry? existing}) async {
    widget.session.touch();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            EntryEditScreen(session: widget.session, existing: existing),
      ),
    );
  }

  Future<void> _confirmDelete(VaultEntry entry) async {
    widget.session.touch();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette entrée ?'),
        content: Text(
          'La clef « ${entry.key} » et sa valeur seront définitivement '
          'retirées du coffre.',
        ),
        actions: [
          TextButton(
            key: const Key('cancel-delete'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const Key('confirm-delete'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      _revealed.remove(entry.key);
      // deleteEntry, pas save(vault.remove(...)): il efface aussi les blobs des
      // pièces jointes, qui resteraient sinon orphelins sur le disque.
      await widget.session.deleteEntry(entry.key);
    }
  }

  /// Aperçu d'une valeur révélée: la première ligne seulement.
  ///
  /// Une valeur multiligne écraserait la liste, et les lignes suivantes n'ont
  /// pas à s'afficher tant que l'utilisateur n'a pas ouvert l'entrée.
  String _preview(String value) {
    final lines = value.split('\n');
    if (lines.length == 1) {
      return value;
    }
    return '${lines.first}  (+${lines.length - 1} lignes)';
  }

  @override
  Widget build(BuildContext context) {
    final vault = widget.session.vault;
    final entries = vault?.search(_query) ?? const <VaultEntry>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('safe'),
        actions: [
          IconButton(
            key: const Key('settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Réglages',
            onPressed: () {
              widget.session.touch();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => SettingsScreen(
                    session: widget.session,
                    transfer: widget.transfer,
                    settings: widget.settings,
                  ),
                ),
              );
            },
          ),
          IconButton(
            key: const Key('lock'),
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Verrouiller',
            onPressed: widget.session.lock,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add'),
        onPressed: _openEditor,
        tooltip: 'Ajouter une entrée',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const Key('search'),
              controller: _searchController,
              // On y tape des noms de clefs, qui sont chiffrés dans le coffre:
              // le clavier n'a pas à les apprendre.
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                hintText: 'Rechercher une clef',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                widget.session.touch();
                setState(() => _query = value);
              },
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _query.trim().isEmpty
                            ? 'Aucune entrée pour l\'instant.\nAppuyez sur + '
                                  'pour en ajouter une.'
                            : 'Aucun résultat pour « $_query ».',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final revealed = _revealed.contains(entry.key);
                      return ListTile(
                        title: Row(
                          children: [
                            Flexible(child: Text(entry.key)),
                            if (entry.attachments.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Icon(
                                key: Key('has-attachments-${entry.key}'),
                                Icons.attach_file,
                                size: 16,
                                semanticLabel:
                                    '${entry.attachments.length} pièce(s) jointe(s)',
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          revealed ? _preview(entry.value) : '••••••••',
                        ),
                        onTap: () => _openEditor(existing: entry),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: Key('reveal-${entry.key}'),
                              icon: Icon(
                                revealed
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              tooltip: revealed ? 'Masquer' : 'Révéler',
                              onPressed: () {
                                widget.session.touch();
                                setState(() {
                                  revealed
                                      ? _revealed.remove(entry.key)
                                      : _revealed.add(entry.key);
                                });
                              },
                            ),
                            IconButton(
                              key: Key('copy-${entry.key}'),
                              icon: const Icon(Icons.copy_outlined),
                              tooltip: 'Copier',
                              onPressed: () => _copy(entry),
                            ),
                            IconButton(
                              key: Key('delete-${entry.key}'),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Supprimer',
                              onPressed: () => _confirmDelete(entry),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
