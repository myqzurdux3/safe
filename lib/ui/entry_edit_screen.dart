import 'package:flutter/material.dart';

import '../model/vault.dart';
import '../state/vault_session.dart';
import '../util/password_generator.dart';

/// Ajout ou modification d'une entrée.
///
/// [existing] nul signifie création. En modification, la clef d'origine reste
/// autorisée; c'est la seule différence de validation entre les deux modes.
class EntryEditScreen extends StatefulWidget {
  const EntryEditScreen({required this.session, this.existing, super.key});

  final VaultSession session;
  final VaultEntry? existing;

  @override
  State<EntryEditScreen> createState() => _EntryEditScreenState();
}

class _EntryEditScreenState extends State<EntryEditScreen> {
  late final TextEditingController _keyController = TextEditingController(
    text: widget.existing?.key ?? '',
  );
  late final TextEditingController _valueController = TextEditingController(
    text: widget.existing?.value ?? '',
  );

  String? _error;
  bool _obscure = true;
  bool _busy = false;

  bool get _isCreation => widget.existing == null;

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) {
      return;
    }
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'La clef ne peut pas être vide');
      return;
    }
    final vault = widget.session.vault;
    if (vault == null) {
      return;
    }
    final collision = vault.entries.any(
      (entry) => entry.key == key && entry.key != widget.existing?.key,
    );
    if (collision) {
      setState(() => _error = 'Cette clef existe déjà');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    var updated = vault;
    // Une clef renommée est une nouvelle entrée: l'ancienne doit disparaître.
    if (!_isCreation && widget.existing!.key != key) {
      updated = updated.remove(widget.existing!.key);
    }
    updated = updated.upsert(
      VaultEntry.now(key: key, value: _valueController.text),
    );
    try {
      await widget.session.save(updated);
    } catch (error) {
      setState(() {
        _busy = false;
        _error = 'Enregistrement impossible: $error';
      });
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _generate() async {
    final generated = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => const _GeneratorSheet(),
    );
    if (generated != null) {
      setState(() => _valueController.text = generated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreation ? 'Nouvelle entrée' : 'Modifier l\'entrée'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('key'),
              controller: _keyController,
              autofocus: _isCreation,
              decoration: const InputDecoration(
                labelText: 'Clef',
                helperText: 'Par exemple: gmail, banque, wifi maison',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('value'),
              controller: _valueController,
              obscureText: _obscure,
              maxLines: 1,
              decoration: InputDecoration(
                labelText: 'Valeur',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  tooltip: _obscure ? 'Afficher' : 'Masquer',
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('generate'),
              onPressed: _generate,
              icon: const Icon(Icons.casino_outlined),
              label: const Text('Générer une valeur'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('save'),
              onPressed: _busy ? null : _save,
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Feuille de génération: longueur et jeu de caractères.
class _GeneratorSheet extends StatefulWidget {
  const _GeneratorSheet();

  @override
  State<_GeneratorSheet> createState() => _GeneratorSheetState();
}

class _GeneratorSheetState extends State<_GeneratorSheet> {
  double _length = 20;
  CharacterSet _set = CharacterSet.all;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 16,
      right: 16,
      top: 16,
      bottom: MediaQuery.of(context).viewInsets.bottom + 16,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Longueur: ${_length.round()}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Slider(
          key: const Key('generate-length'),
          value: _length,
          min: 12,
          max: 64,
          divisions: 52,
          label: '${_length.round()}',
          onChanged: (value) => setState(() => _length = value),
        ),
        const SizedBox(height: 8),
        SegmentedButton<CharacterSet>(
          segments: [
            for (final set in CharacterSet.values)
              ButtonSegment(value: set, label: Text(set.label)),
          ],
          selected: {_set},
          onSelectionChanged: (selection) =>
              setState(() => _set = selection.first),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('generate-confirm'),
          onPressed: () => Navigator.of(context).pop(
            generatePassword(length: _length.round(), set: _set),
          ),
          child: const Text('Utiliser'),
        ),
      ],
    ),
  );
}
