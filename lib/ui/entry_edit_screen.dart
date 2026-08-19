import 'package:flutter/material.dart';

import '../model/vault.dart';
import '../state/vault_session.dart';
import '../util/password_generator.dart';
import 'attachments_section.dart';
import 'widgets/confirm_discard.dart';

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

  /// La saisie diffère-t-elle de ce qui est enregistré ?
  ///
  /// Sert à ne pas jeter silencieusement une saisie en cours sur un retour
  /// arrière — c'est le geste le plus facile à faire par erreur.
  bool _dirty = false;

  /// Masquée par défaut sur une entrée existante; révélée en création, où il
  /// n'y a encore aucun secret à l'écran et où l'utilisateur va taper.
  late bool _obscure = widget.existing != null;

  bool get _isCreation => widget.existing == null;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    _keyController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  /// Au verrouillage, l'écran efface sa saisie et cesse de retenir le retour.
  ///
  /// Sans cela, la confirmation d'abandon bloquerait le dépilement déclenché
  /// par le verrouillage, et le contenu en clair resterait affiché par-dessus
  /// l'écran de verrou. Effacer les champs enlève aussi le clair de l'écran
  /// avant même que la route ne disparaisse.
  void _onSession() {
    if (!mounted || widget.session.isUnlocked) {
      return;
    }
    _keyController.clear();
    _valueController.clear();
    setState(() {
      _dirty = false;
      // Dit franchement ce qui vient de se passer: la saisie est perdue, et
      // elle ne peut pas être gardée — ce serait garder du clair à l'écran et
      // en mémoire pendant que le coffre est fermé.
      _error = 'Le coffre s\'est verrouillé: la saisie a été effacée';
    });
  }

  void _markDirty() {
    widget.session.touch();
    if (!_dirty) {
      setState(() => _dirty = true);
    }
  }

  Future<void> _save() async {
    if (_busy) {
      return;
    }
    // Le verrouillage se vérifie avant la saisie: c'est la vraie cause, et
    // signaler d'abord une clef vide — que le verrouillage vient justement
    // d'effacer — enverrait l'utilisateur sur une fausse piste.
    final vault = widget.session.vault;
    if (vault == null) {
      setState(
        () => _error = 'Le coffre s\'est verrouillé: rien n\'a été enregistré',
      );
      return;
    }
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'La clef ne peut pas être vide');
      return;
    }
    final collision = vault.entries.any(
      // Comparaison canonique: sans elle, « Gmail » et « gmail », ou deux
      // écritures Unicode de « café », créaient deux entrées que rien ne
      // distinguait à l'écran.
      (entry) =>
          canonicalKey(entry.key) == canonicalKey(key) &&
          canonicalKey(entry.key) != canonicalKey(widget.existing?.key ?? ''),
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
    final current = vault.entries
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
        attachments: current?.attachments ?? const [],
      ),
    );
    try {
      await widget.session.save(updated);
    } catch (_) {
      // Garde `mounted` comme le chemin de succès juste en dessous: l'écran
      // peut avoir été dépilé par un verrouillage pendant l'écriture.
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Enregistrement impossible: réessayez';
        });
      }
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
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        final navigator = Navigator.of(context);
        if (await confirmDiscard(context) && mounted) {
          navigator.pop();
        }
      },
      child: _body(theme),
    );
  }

  Widget _body(ThemeData theme) {
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
              onChanged: (_) => _markDirty(),
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
                // Les puces sont lues une par une par un lecteur d'écran.
                title: Semantics(
                  label: 'Valeur masquée',
                  child: const ExcludeSemantics(child: Text('••••••••')),
                ),
                // Sans le nombre de lignes: il renseignait gratuitement un
                // voisin sur la structure du secret.
                subtitle: Text(
                  'Révélez la valeur pour la modifier',
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
                onChanged: (_) => _markDirty(),
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
          // Bornes du générateur lui-même: un curseur plus large laisserait
          // passer une longueur que `generatePassword` refuse.
          min: minPasswordLength.toDouble(),
          max: maxPasswordLength.toDouble(),
          divisions: maxPasswordLength - minPasswordLength,
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
          onPressed: () => Navigator.of(
            context,
          ).pop(generatePassword(length: _length.round(), set: _set)),
          child: const Text('Utiliser'),
        ),
      ],
    ),
  );
}
