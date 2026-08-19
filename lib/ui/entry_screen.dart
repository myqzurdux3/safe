import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/entry_text.dart';
import '../model/vault.dart';
import '../state/vault_session.dart';
import '../storage/app_settings.dart';
import '../util/clipboard.dart';
import 'attachments_section.dart';
import 'theme/safe_theme.dart';
import 'widgets/block_card.dart';
import 'widgets/pill_tabs.dart';
import 'widgets/primary_button.dart';
import 'widgets/safe_toast.dart';
import 'widgets/syntax_tutorial.dart';

/// La fiche: le texte d'une entrée, lu en blocs ou repris tel quel.
///
/// Le contrôleur de texte est la seule source de vérité de l'écran. Les blocs,
/// les compteurs et l'état d'ouverture s'en déduisent à chaque affichage et ne
/// sont jamais écrits: ce qui part au coffre est le texte, exactement tel que
/// l'utilisateur l'a tapé.
class EntryScreen extends StatefulWidget {
  const EntryScreen({
    required this.session,
    required this.entry,
    this.settings,
    this.clipboard,
    super.key,
  });

  final VaultSession session;
  final VaultEntry entry;

  /// Préférences; nul signifie « ne rien persister », comme ailleurs.
  final SettingsStore? settings;

  /// Presse-papier auto-effaçant; celui par défaut suffit hors tests.
  final SecureClipboard? clipboard;

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.entry.value,
  );
  late final SecureClipboard _clipboard = widget.clipboard ?? SecureClipboard();

  /// Index des blocs ouverts. Vidé au verrouillage, et dès que le découpage
  /// change sous les doigts: un index ne désignerait plus le même bloc.
  final Set<int> _open = {};

  /// Nombre de groupes du dernier découpage, seule mémoire gardée d'une frappe
  /// à l'autre — elle ne sert qu'à savoir quand [_open] devient caduc.
  late int _groupCount = countBlocks(parseEntryText(widget.entry.value));

  /// Le texte tel qu'il est au coffre; ce qui s'en écarte est une saisie en
  /// cours, qu'un retour arrière ne doit pas jeter sans demander.
  late String _saved = widget.entry.value;

  AppSettings? _preferences;
  bool _showTutorial = false;
  int _mode = 0;
  bool _busy = false;

  bool get _dirty => _controller.text != _saved;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    _controller.addListener(_onText);
    unawaited(_loadPreferences());
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    _controller.dispose();
    if (widget.clipboard == null) {
      _clipboard.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final loaded = await widget.settings?.read() ?? const AppSettings();
    if (mounted) {
      setState(() {
        _preferences = loaded;
        _showTutorial = !loaded.syntaxTutorialDismissed;
      });
    }
  }

  /// Au verrouillage, l'écran se vide et cesse de retenir le retour.
  ///
  /// Sans cela, la confirmation d'abandon bloquerait le dépilement déclenché
  /// par le verrouillage, et le clair resterait affiché par-dessus l'écran de
  /// verrou. Effacer le contrôleur enlève le clair de l'écran avant même que
  /// la route ne disparaisse; vider [_open] évite qu'un bloc rouvert plus tard
  /// le soit déjà.
  void _onSession() {
    if (!mounted || widget.session.isUnlocked) {
      return;
    }
    _controller.clear();
    setState(() {
      _saved = '';
      _open.clear();
      _busy = false;
    });
  }

  void _onText() {
    widget.session.touch();
    final count = countBlocks(parseEntryText(_controller.text));
    if (count != _groupCount) {
      _groupCount = count;
      _open.clear();
    }
    setState(() {});
  }

  void _toggle(int index) {
    widget.session.touch();
    setState(() {
      if (!_open.remove(index)) {
        _open.add(index);
      }
    });
  }

  Future<void> _copy(String value) async {
    widget.session.touch();
    // Le toast part avant la copie: celle-ci est un aller-retour vers la
    // plateforme, et attendre sa réponse retarderait le retour au doigt.
    showSafeToast(context, 'Copié');
    try {
      await _clipboard.copy(value);
    } on MissingPluginException {
      // Aucun presse-papier sous la main — un hôte de développement, pas un
      // téléphone. Rien à signaler: il n'y a rien à corriger côté utilisateur.
    }
  }

  Future<void> _dismissTutorial() async {
    setState(() => _showTutorial = false);
    final preferences = _preferences;
    if (preferences == null) {
      return;
    }
    final updated = preferences.copyWith(syntaxTutorialDismissed: true);
    _preferences = updated;
    // Une préférence d'affichage: si l'écriture échoue, le tuto reviendra au
    // prochain lancement, ce qui ne mérite pas d'interrompre la lecture.
    try {
      await widget.settings?.write(updated);
    } catch (_) {
      // Sans effet visible ici, et déjà appliqué à l'écran.
    }
  }

  Future<void> _save() async {
    final vault = widget.session.vault;
    if (vault == null) {
      showSafeToast(context, 'Coffre verrouillé');
      return;
    }
    setState(() => _busy = true);
    final text = _controller.text;
    // Les pièces jointes sont relues dans le coffre courant, pas dans l'entrée
    // reçue à l'ouverture: celles ajoutées depuis cet écran n'y figurent pas,
    // et reconstruire l'entrée sans elles les perdrait.
    final current = vault.entries
        .where((entry) => entry.key == widget.entry.key)
        .firstOrNull;
    try {
      await widget.session.save(
        vault.upsert(
          VaultEntry(
            key: widget.entry.key,
            // Tel quel: ni `trim`, ni normalisation, ni réordonnancement. Les
            // espaces de bord sont du texte comme un autre.
            value: text,
            created: widget.entry.created,
            updated: DateTime.now().toUtc(),
            attachments: current?.attachments ?? widget.entry.attachments,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showSafeToast(context, 'Enregistrement impossible');
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _saved = text;
    });
    showSafeToast(context, 'Enregistré');
  }

  Future<void> _openAttachments() async {
    widget.session.touch();
    await showModalBottomSheet<void>(
      context: context,
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
              session: widget.session,
              entryKey: widget.entry.key,
              onChanged: () {
                setSheetState(() {});
                if (mounted) {
                  setState(() {});
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Demande confirmation avant de jeter une saisie en cours.
  Future<bool> _confirmDiscard() async {
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

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    final groups = parseEntryText(_controller.text);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        final navigator = Navigator.of(context);
        if (await _confirmDiscard() && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: tokens.pageBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SafeMetrics.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(tokens, groups),
                const SizedBox(height: 14),
                _modeBar(tokens),
                if (_showTutorial) ...[
                  const SizedBox(height: 12),
                  SyntaxTutorial(onDismiss: _dismissTutorial),
                ],
                const SizedBox(height: 14),
                Expanded(
                  child: _mode == 0 ? _reading(tokens, groups) : _raw(tokens),
                ),
                const SizedBox(height: 12),
                _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(SafeTokens tokens, List<EntryGroup> groups) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back, size: 18, color: tokens.secondaryText),
              const SizedBox(width: 6),
              Text(
                'Coffre',
                style: SafeText.action.copyWith(color: tokens.secondaryText),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        widget.entry.key,
        style: SafeText.screenTitle.copyWith(color: tokens.ink),
      ),
      const SizedBox(height: 6),
      Text(
        describeGroups(groups),
        style: SafeText.counter.copyWith(color: tokens.hintText),
      ),
    ],
  );

  Widget _modeBar(SafeTokens tokens) => Row(
    children: [
      Expanded(
        child: SafePillTabs(
          labels: const ['Lecture', 'Texte brut'],
          selected: _mode,
          height: 28,
          onSelected: (index) {
            widget.session.touch();
            setState(() => _mode = index);
          },
        ),
      ),
      // Le rappel n'a de sens que quand le tuto est rangé: sinon il pointerait
      // sur ce qui est déjà sous les yeux.
      if (_preferences != null && !_showTutorial)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _showTutorial = true),
          child: Padding(
            padding: const EdgeInsets.only(left: 14, top: 10, bottom: 10),
            child: Text(
              'Syntaxe',
              style: SafeText.action.copyWith(color: tokens.accent),
            ),
          ),
        ),
    ],
  );

  Widget _reading(SafeTokens tokens, List<EntryGroup> groups) {
    if (groups.isEmpty) {
      return Center(
        child: Text(
          'Cette fiche est vide.\nPassez en « Texte brut » pour la remplir.',
          textAlign: TextAlign.center,
          style: SafeText.meta.copyWith(color: tokens.hintText),
        ),
      );
    }
    final children = <Widget>[];
    var line = 0;
    for (var index = 0; index < groups.length; index++) {
      final group = groups[index];
      final first = line;
      line += group.lines.length;
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 9));
      }
      children.add(
        group.isComment
            ? CommentBlock(
                group: group,
                onCopy: () => _copy(group.lines.join('\n')),
              )
            : BlockCard(
                group: group,
                firstLineIndex: first,
                open: _open.contains(index),
                onToggle: () => _toggle(index),
                onCopyLine: _copy,
                onCopyBlock: () => _copy(group.lines.join('\n')),
              ),
      );
    }
    // Une liste défilante, pas une colonne figée: un bloc long doit pouvoir
    // sortir de l'écran par le bas plutôt que d'être coupé sans le dire.
    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: children,
    );
  }

  Widget _raw(SafeTokens tokens) => DecoratedBox(
    decoration: BoxDecoration(
      color: tokens.cardSurface,
      borderRadius: BorderRadius.circular(SafeMetrics.cardRadius),
      border: Border.all(color: tokens.strongDivider),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: TextField(
        key: const Key('raw'),
        controller: _controller,
        // `expands`: le champ occupe la carte et défile en son sein, au lieu de
        // la faire grandir jusqu'à pousser le pied de page hors de l'écran.
        expands: true,
        maxLines: null,
        minLines: null,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        // Le clavier n'a pas à apprendre ce qui est chiffré dans le coffre.
        autocorrect: false,
        enableSuggestions: false,
        style: SafeText.rawEditor.copyWith(color: tokens.ink),
        cursorColor: tokens.accent,
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: 'Colle ou tape ici. Tout est accepté.',
          hintStyle: SafeText.rawEditor.copyWith(color: tokens.hintText),
        ),
      ),
    ),
  );

  Widget _footer() => Row(
    children: [
      Expanded(
        child: SafeSecondaryButton(
          label: 'Pièce jointe',
          onPressed: _openAttachments,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: SafePrimaryButton(
          label: 'Enregistrer',
          onPressed: _save,
          busy: _busy,
        ),
      ),
    ],
  );
}
