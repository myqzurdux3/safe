import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/entry_text.dart';
import '../model/vault.dart';
import '../state/vault_session.dart';
import '../storage/app_settings.dart';
import 'theme/safe_theme.dart';
import 'widgets/confirm_discard.dart';
import 'widgets/primary_button.dart';
import 'widgets/raw_editor.dart';
import 'widgets/syntax_tutorial.dart';

/// La création d'une fiche: un nom, puis un bloc de texte libre.
///
/// L'écran n'a qu'une source de vérité, les deux contrôleurs de texte. Le
/// compteur de blocs et de lignes s'en déduit à chaque affichage; ce qui part
/// au coffre est le texte, exactement tel que l'utilisateur l'a tapé.
///
/// Le générateur de mots de passe ne s'y trouve plus: il devient un outil de
/// l'accueil, où il vaut pour toutes les fiches et pas seulement pour celles
/// qui tiennent en un mot de passe.
class NewEntryScreen extends StatefulWidget {
  const NewEntryScreen({required this.session, this.settings, super.key});

  final VaultSession session;

  /// Préférences; nul signifie « ne rien persister », comme ailleurs.
  final SettingsStore? settings;

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rawController = TextEditingController();

  /// Réglages lus au montage; `null` tant qu'ils ne le sont pas.
  AppSettings? _preferences;

  /// Le tuto est-il à l'écran ? `null` tant que les réglages sont inconnus.
  ///
  /// Tant qu'ils le sont, l'écran ne montre que ce dont la place ne dépend pas
  /// d'eux: son en-tête et son pied. Parier sur une réponse puis se corriger
  /// ferait sauter la carte de saisie d'un côté ou de l'autre.
  bool? _showTutorial;

  /// Message affiché sous le champ de nom: refus de validation, verrouillage,
  /// échec d'écriture.
  String? _error;

  bool _busy = false;

  /// Quelque chose a-t-il été tapé ? Sert à ne pas jeter silencieusement une
  /// saisie en cours sur un retour arrière — le geste le plus facile à faire
  /// par erreur.
  ///
  /// Déduit du texte, jamais mémorisé: un drapeau levé par les auditeurs des
  /// contrôleurs se lèverait aussi quand le champ prend le focus ou que le
  /// curseur bouge, et la confirmation d'abandon surgirait sur un écran où
  /// personne n'a rien écrit.
  bool get _dirty =>
      _nameController.text.isNotEmpty || _rawController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    _nameController.addListener(_onText);
    _rawController.addListener(_onText);
    unawaited(_loadPreferences());
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    _nameController.dispose();
    _rawController.dispose();
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

  /// Au verrouillage, l'écran efface sa saisie et cesse de retenir le retour.
  ///
  /// Sans cela, la confirmation d'abandon bloquerait le dépilement déclenché
  /// par le verrouillage, et le clair resterait affiché par-dessus l'écran de
  /// verrou. Effacer les contrôleurs enlève le clair de l'écran avant même que
  /// la route ne disparaisse.
  void _onSession() {
    if (!mounted || widget.session.isUnlocked) {
      return;
    }
    // Avant le `setState`: vider un contrôleur réveille ses auditeurs, qui
    // remarqueraient la saisie comme « en cours ».
    _nameController.clear();
    _rawController.clear();
    setState(() {
      _busy = false;
      // Dit franchement ce qui vient de se passer: la saisie est perdue, et
      // elle ne peut pas être gardée — ce serait garder du clair à l'écran et
      // en mémoire pendant que le coffre est fermé.
      _error = 'Le coffre s\'est verrouillé: la saisie a été effacée';
    });
  }

  /// Une frappe dans l'un ou l'autre champ.
  ///
  /// La frappe est souvent la seule activité pendant une saisie longue: sans
  /// [VaultSession.touch], le coffre se verrouille sous les doigts. Le
  /// `setState` sert au compteur de blocs et de lignes, qui se relit du texte à
  /// chaque affichage, et à la garde de sortie, qui s'en déduit aussi.
  void _onText() {
    widget.session.touch();
    setState(() {});
  }

  Future<void> _dismissTutorial() async {
    final current = _preferences;
    setState(() => _showTutorial = false);
    final store = widget.settings;
    // On n'écrit jamais par-dessus des réglages qu'on n'a pas lus: repartir des
    // valeurs par défaut effacerait le blocage des captures d'écran et le délai
    // de verrouillage au profit d'une ligne de tuto.
    if (store == null || current == null) {
      return;
    }
    // Une préférence d'affichage: si l'écriture échoue, le tuto reviendra au
    // prochain lancement, ce qui ne mérite pas d'interrompre la saisie.
    try {
      final updated = current.copyWith(syntaxTutorialDismissed: true);
      _preferences = updated;
      await store.write(updated);
    } catch (_) {
      // Sans effet visible ici, et déjà appliqué à l'écran.
    }
  }

  /// Insère le presse-papier système à la position du curseur.
  Future<void> _paste() async {
    widget.session.touch();
    final ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } on MissingPluginException {
      // Aucun presse-papier sous la main — un hôte de développement, pas un
      // téléphone. Rien à signaler: il n'y a rien à corriger côté utilisateur.
      return;
    }
    final pasted = data?.text;
    if (pasted == null || pasted.isEmpty || !mounted) {
      return;
    }
    final value = _rawController.value;
    // Un champ jamais touché n'a pas de sélection valide: on colle à la fin.
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    _rawController.value = TextEditingValue(
      text: value.text.replaceRange(selection.start, selection.end, pasted),
      // Le curseur suit ce qui vient d'être collé: la frappe reprend là où
      // l'utilisateur s'attend à la trouver.
      selection: TextSelection.collapsed(
        offset: selection.start + pasted.length,
      ),
    );
  }

  Future<void> _save() async {
    if (_busy) {
      return;
    }
    // Le verrouillage se vérifie avant la saisie: c'est la vraie cause, et
    // signaler d'abord un nom vide — que le verrouillage vient justement
    // d'effacer — enverrait l'utilisateur sur une fausse piste.
    final vault = widget.session.vault;
    if (vault == null) {
      setState(
        () => _error = 'Le coffre s\'est verrouillé: rien n\'a été enregistré',
      );
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Le nom ne peut pas être vide');
      return;
    }
    // Comparaison canonique: sans elle, « Gmail » et « gmail », ou deux
    // écritures Unicode de « café », créaient deux fiches que rien ne
    // distinguait à l'écran.
    final collision = vault.entries.any(
      (entry) => canonicalKey(entry.key) == canonicalKey(name),
    );
    if (collision) {
      setState(() => _error = 'Ce nom existe déjà');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.save(
        vault.upsert(
          VaultEntry.now(
            key: name,
            // Tel quel: ni `trim`, ni normalisation, ni réordonnancement. Les
            // espaces de bord sont du texte comme un autre.
            value: _rawController.text,
          ),
        ),
      );
    } catch (_) {
      // Garde `mounted` comme le chemin de succès: l'écran peut avoir été
      // dépilé par un verrouillage pendant l'écriture.
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

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
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
      child: Scaffold(
        backgroundColor: tokens.pageBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SafeMetrics.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(tokens),
                // Le tuto attend les réglages: apparaître à la deuxième image
                // ferait sauter la carte de saisie sous les yeux.
                if (_showTutorial != null) ...[
                  if (_showTutorial!) ...[
                    const SizedBox(height: 16),
                    SyntaxTutorial(onDismiss: _dismissTutorial),
                  ],
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: _showTutorial == null
                      ? const SizedBox.shrink()
                      : _card(tokens),
                ),
                const SizedBox(height: 12),
                SafePrimaryButton(
                  label: 'Enregistrer',
                  onPressed: _save,
                  busy: _busy,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(SafeTokens tokens) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: Padding(
          // L'écart qui séparait le retour du nom est passé dans sa marge:
          // 11 + 18 de flèche + 19 font une cible de 48 px pile, sans qu'aucun
          // pixel ne soit pris au champ de nom juste en dessous, qui est une
          // cible lui aussi.
          padding: const EdgeInsets.only(top: 11, bottom: 19),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back, size: 18, color: tokens.secondaryText),
              const SizedBox(width: 6),
              Text(
                'Nouvelle fiche',
                style: SafeText.action.copyWith(color: tokens.secondaryText),
              ),
            ],
          ),
        ),
      ),
      TextField(
        key: const Key('name'),
        controller: _nameController,
        // L'écran s'ouvre sur le nom: c'est la première chose à taper, et rien
        // d'autre ne peut être enregistré sans lui.
        autofocus: true,
        // Un nom de fiche est chiffré dans le coffre: il n'a pas à ressortir
        // dans les suggestions d'une autre application.
        autocorrect: false,
        enableSuggestions: false,
        style: SafeText.screenTitle.copyWith(color: tokens.ink),
        cursorColor: tokens.accent,
        decoration: InputDecoration(
          isDense: true,
          // Assez de marge verticale pour que le champ fasse une cible de
          // doigt: le texte ne bouge pas, seule la zone touchable grandit.
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          hintText: 'Nom de la fiche',
          hintStyle: SafeText.screenTitle.copyWith(
            color: tokens.titlePlaceholder,
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: tokens.strongDivider, width: 1.5),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: tokens.strongDivider, width: 1.5),
          ),
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _error!,
            style: SafeText.meta.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
    ],
  );

  /// La carte de saisie: le texte, puis son compteur et l'action « Coller ».
  Widget _card(SafeTokens tokens) => DecoratedBox(
    decoration: BoxDecoration(
      color: tokens.cardSurface,
      borderRadius: BorderRadius.circular(SafeMetrics.cardRadius),
      border: Border.all(color: tokens.strongDivider),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SafeRawEditor(
              controller: _rawController,
              hintText: 'Colle ou tape ici.\nTout est accepté.',
            ),
          ),
          Divider(height: 1, thickness: 1, color: tokens.hairline),
          _cardFooter(tokens),
        ],
      ),
    ),
  );

  Widget _cardFooter(SafeTokens tokens) => SizedBox(
    // La hauteur d'un doigt: c'est elle qui fait la cible de « Coller », dont
    // le libellé ne fait que onze pixels de haut.
    height: SafeMetrics.touchTarget,
    child: Row(
      children: [
        Text(
          describeGroups(parseEntryText(_rawController.text)),
          style: SafeText.counter.copyWith(color: tokens.hintText),
        ),
        const Spacer(),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _paste,
          child: SizedBox(
            height: SafeMetrics.touchTarget,
            child: Center(
              child: Padding(
                // Le libellé est collé au bord droit de la carte: cette marge
                // gauche élargit la cible sans déplacer la lettre d'un pixel.
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  'Coller',
                  style: SafeText.action.copyWith(color: tokens.accent),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
