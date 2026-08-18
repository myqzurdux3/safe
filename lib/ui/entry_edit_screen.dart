import 'package:flutter/material.dart';

import '../model/vault.dart';
import '../state/vault_session.dart';
import '../util/password_generator.dart';
import 'attachments_section.dart';

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
  bool _busy = false;

  /// Masquée par défaut sur une entrée existante; révélée en création, où il
  /// n'y a encore aucun secret à l'écran et où l'utilisateur va taper.
  late bool _obscure = widget.existing != null;

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
      // Le coffre a pu se verrouiller pendant la saisie. Se taire ici donnerait
      // un bouton « Enregistrer » sans effet, et l'utilisateur croirait avoir
      // enregistré.
      setState(
        () => _error =
            'Le coffre s\'est verrouillé pendant la saisie. Déverrouillez-le, '
            'puis enregistrez de nouveau.',
      );
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
    // Les pièces jointes sont lues dans le coffre courant, pas dans l'entrée
    // reçue à l'ouverture: celles ajoutées pendant l'édition n'y figurent pas,
    // et reconstruire l'entrée sans elles les perdrait.
    final courant = vault.entries
        .where((entry) => entry.key == widget.existing?.key)
        .firstOrNull;
    // Une clef renommée est une nouvelle entrée: l'ancienne doit disparaître.
    if (!_isCreation && widget.existing!.key != key) {
      updated = updated.remove(widget.existing!.key);
    }
    updated = updated.upsert(
      VaultEntry.now(
        key: key,
        value: _valueController.text,
        attachments: courant?.attachments ?? const [],
      ),
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
              // La frappe est souvent la seule activité pendant une saisie
              // longue: sans cela, le coffre se verrouille sous les doigts.
              onChanged: (_) => widget.session.touch(),
              // Le clavier ne doit rien apprendre de ce qu'on tape ici: un nom
              // de clef est chiffré dans le coffre, il n'a pas à ressortir dans
              // les suggestions d'une autre application.
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Clef',
                helperText: 'Par exemple: gmail, banque, wifi maison',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Masquée, la valeur n'est pas un champ de saisie: un champ
            // `obscureText` est forcément sur une ligne, et une ligne unique
            // supprime silencieusement les retours à la ligne tapés ou collés.
            // Modifier suppose donc de révéler.
            if (_obscure)
              ListTile(
                key: const Key('value-masked'),
                contentPadding: EdgeInsets.zero,
                title: const Text('••••••••'),
                subtitle: Text(
                  _valueController.text.contains('\n')
                      ? 'Valeur sur ${_valueController.text.split('\n').length} '
                            'lignes — révélez-la pour la modifier'
                      : 'Révélez la valeur pour la modifier',
                  style: theme.textTheme.bodySmall,
                ),
                trailing: IconButton(
                  key: const Key('toggle-value'),
                  icon: const Icon(Icons.visibility),
                  tooltip: 'Afficher',
                  onPressed: () => setState(() => _obscure = false),
                ),
              )
            else
              TextField(
                key: const Key('value'),
                controller: _valueController,
                onChanged: (_) => widget.session.touch(),
                maxLines: null,
                minLines: 3,
                keyboardType: TextInputType.multiline,
                // Ce champ montre le secret en clair — c'est voulu, une valeur
                // multiligne doit être relisible. Mais il ne doit pas nourrir
                // le dictionnaire personnel du clavier: `obscureText`, qui
                // coupe cet apprentissage ailleurs, n'est pas utilisable ici.
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Valeur',
                  helperText: 'Les retours à la ligne sont conservés',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    key: const Key('hide-value'),
                    icon: const Icon(Icons.visibility_off),
                    tooltip: 'Masquer',
                    onPressed: () => setState(() => _obscure = true),
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
            const SizedBox(height: 24),
            AttachmentsSection(
              session: widget.session,
              entryKey: widget.existing?.key,
              onChanged: () => setState(() {}),
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
