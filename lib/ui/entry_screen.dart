import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../model/entry_text.dart';
import '../model/vault.dart';
import '../state/vault_session.dart';
import '../storage/app_settings.dart';
import '../util/clipboard.dart';
import 'entry_counts.dart';
import 'theme/safe_theme.dart';
import 'widgets/attachments_sheet.dart';
import 'widgets/confirm_discard.dart';
import 'widgets/entry_reading_list.dart';
import 'widgets/pill_tabs.dart';
import 'widgets/primary_button.dart';
import 'widgets/raw_editor.dart';
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

  /// Index des blocs ouverts. Vidé au verrouillage et à toute modification du
  /// texte: un index désigne un rang, et un rang ne désigne plus le même bloc
  /// dès qu'on remanie le texte. Rouvrir après une frappe est un geste; révéler
  /// un bloc que personne n'a ouvert est un défaut.
  final Set<int> _open = {};

  /// Le texte tel qu'il est au coffre; ce qui s'en écarte est une saisie en
  /// cours, qu'un retour arrière ne doit pas jeter sans demander.
  late String _saved = widget.entry.value;

  /// Le nom affiché, et modifiable: renommer une fiche se fait ici, pas dans
  /// un écran à part. Copié de l'entrée pour pouvoir être effacé au
  /// verrouillage — le nom d'une fiche en dit déjà long.
  late final TextEditingController _nameController = TextEditingController(
    text: widget.entry.key,
  );

  /// La clef sous laquelle la fiche est **au coffre**, qui n'est plus celle
  /// reçue à l'ouverture dès qu'un renommage a été enregistré. Tout ce qui
  /// s'adresse au coffre — pièces jointes, retrait de l'ancienne entrée —
  /// passe par elle: rester sur `widget.entry.key` ferait chercher la fiche
  /// sous un nom qu'elle ne porte plus.
  late String _key = widget.entry.key;

  /// Le nom tel qu'il est au coffre, pendant du texte enregistré.
  late String _savedName = widget.entry.key;

  /// L'état du tuto, garde de sécurité comprise; voir
  /// [SyntaxTutorialPreference].
  late final SyntaxTutorialPreference _tutorial = SyntaxTutorialPreference(
    widget.settings,
  );

  int _mode = 0;
  bool _busy = false;

  bool get _dirty =>
      _controller.text != _saved || _nameController.text != _savedName;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    _controller.addListener(_onText);
    _nameController.addListener(_onName);
    _tutorial.addListener(_onTutorial);
    unawaited(_tutorial.load());
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    _controller.dispose();
    _nameController.dispose();
    if (widget.clipboard == null) {
      _clipboard.dispose();
    }
    _tutorial.removeListener(_onTutorial);
    _tutorial.dispose();
    super.dispose();
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
    _nameController.clear();
    setState(() {
      _saved = '';
      _savedName = '';
      _open.clear();
      _busy = false;
    });
  }

  void _onText() {
    widget.session.touch();
    // Sans condition: compter les groupes ne suffit pas. À nombre constant, un
    // texte réordonné ou renommé laisse les index en place, et ils désignent
    // alors d'autres blocs — l'écran révélait le contenu d'un bloc que
    // l'utilisateur n'avait jamais ouvert, et y restait.
    _open.clear();
    setState(() {});
  }

  /// Le nom ne commande aucun affichage dérivé: seule la garde de sortie s'en
  /// déduit, et elle n'est lue qu'à l'image suivante.
  void _onName() {
    widget.session.touch();
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
    showSafeToast(context, L.of(context).copied);
    try {
      await _clipboard.copy(value);
    } on MissingPluginException {
      // Aucun presse-papier sous la main — un hôte de développement, pas un
      // téléphone. Rien à signaler: il n'y a rien à corriger côté utilisateur.
    } catch (_) {
      // Le toast est déjà parti: le démentir vaut mieux que le laisser mentir
      // pendant que l'erreur file en exception de zone.
      if (mounted) {
        showSafeToast(context, L.of(context).copyFailed);
      }
    }
  }

  Future<void> _save() async {
    final vault = widget.session.vault;
    if (vault == null) {
      showSafeToast(context, L.of(context).vaultLocked);
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showSafeToast(context, L.of(context).entryNameEmpty);
      return;
    }
    // Comparaison canonique, avec exemption du nom d'origine: sans elle,
    // « Gmail » et « gmail » feraient deux fiches indiscernables à l'écran —
    // mais sans l'exemption, réenregistrer une fiche sans la renommer se
    // heurterait à elle-même.
    final collision = vault.entries.any(
      (entry) =>
          canonicalKey(entry.key) == canonicalKey(name) &&
          canonicalKey(entry.key) != canonicalKey(_key),
    );
    if (collision) {
      showSafeToast(context, L.of(context).entryNameTaken);
      return;
    }
    setState(() => _busy = true);
    final text = _controller.text;
    // Les pièces jointes sont relues dans le coffre courant, pas dans l'entrée
    // reçue à l'ouverture: celles ajoutées depuis cet écran n'y figurent pas,
    // et reconstruire l'entrée sans elles les perdrait.
    final current = vault.entries
        .where((entry) => entry.key == _key)
        .firstOrNull;
    var updated = vault;
    // Un nom canoniquement différent est une autre entrée: l'ancienne doit
    // partir, sans quoi le renommage laisserait un doublon derrière lui.
    if (canonicalKey(name) != canonicalKey(_key)) {
      updated = updated.remove(_key);
    }
    try {
      await widget.session.save(
        updated.upsert(
          VaultEntry(
            key: name,
            // Tel quel: ni `trim`, ni normalisation, ni réordonnancement. Les
            // espaces de bord sont du texte comme un autre.
            value: text,
            // Un renommage n'est pas une naissance.
            created: current?.created ?? widget.entry.created,
            updated: DateTime.now().toUtc(),
            attachments: current?.attachments ?? widget.entry.attachments,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showSafeToast(context, L.of(context).entrySaveFailed);
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _saved = text;
      _savedName = name;
      _key = name;
    });
    showSafeToast(context, L.of(context).entrySaved);
  }

  /// Supprime la fiche, après confirmation.
  ///
  /// La suppression vit ici, sur la fiche, et non dans la liste: la maquette
  /// de l'accueil ne montre aucune commande par ligne, et un geste
  /// irréversible n'a rien à faire sous le doigt qui fait défiler. Ici, on a
  /// devant les yeux ce qu'on efface.
  Future<void> _supprimer() async {
    widget.session.touch();
    final t = L.of(context);
    final navigator = Navigator.of(context);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.entryDeleteTitle),
        content: Text(t.entryDeleteBody(_key)),
        actions: [
          TextButton(
            key: const Key('cancel-delete'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.cancel),
          ),
          FilledButton(
            key: const Key('confirm-delete'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (!(confirme ?? false) || !mounted) {
      return;
    }
    try {
      // `deleteEntry`, et non `save(vault.remove(...))`: il efface aussi les
      // blobs des pièces jointes, qui resteraient sinon orphelins sur le
      // disque.
      await widget.session.deleteEntry(_key);
    } catch (_) {
      // Sans cela, la boîte se refermait, la fiche restait en place et rien ne
      // l'expliquait — l'erreur partant en erreur asynchrone non gérée.
      if (mounted) {
        showSafeToast(context, L.of(context).entryDeleteFailed);
      }
      return;
    }
    if (!mounted) {
      return;
    }
    // La fiche n'existe plus: rester dessus laisserait son texte à l'écran, et
    // un enregistrement la ferait revenir d'entre les morts.
    setState(() {
      _saved = _controller.text;
      _savedName = _nameController.text;
    });
    navigator.pop();
  }

  Future<void> _openAttachments() => showAttachmentsSheet(
    context: context,
    session: widget.session,
    entryKey: _key,
    onChanged: () {
      if (mounted) {
        setState(() {});
      }
    },
  );

  /// Le tuto a bougé: seule la mise en page en dépend.
  void _onTutorial() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    final t = L.of(context);
    final groups = parseEntryText(_controller.text);
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
                _header(tokens, t, groups),
                // La barre de mode attend les réglages: le lien « Syntaxe »
                // qu'elle porte à droite dépend d'eux, et son arrivée
                // rétrécirait les onglets sous les yeux.
                if (_tutorial.visible != null) ...[
                  // Six pixels de moins de part et d'autre de la barre de mode:
                  // c'est exactement la marge touchable qu'elle porte au-delà
                  // de sa hauteur visible. Rien ne bouge à l'écran.
                  const SizedBox(height: 8),
                  _modeBar(tokens, t),
                  if (_tutorial.visible!) ...[
                    const SizedBox(height: 6),
                    SyntaxTutorial(onDismiss: _tutorial.dismiss),
                    const SizedBox(height: 14),
                  ] else
                    // Seul l'écart qui touche la barre de mode se réduit: c'est
                    // là, et là seulement, qu'elle rend six pixels de marge.
                    const SizedBox(height: 8),
                ],
                Expanded(
                  child: switch ((_tutorial.visible, _mode)) {
                    (null, _) => const SizedBox.shrink(),
                    (_, 0) => EntryReadingList(
                      groups: groups,
                      open: _open,
                      onToggle: _toggle,
                      onCopy: _copy,
                    ),
                    _ => _raw(tokens, t),
                  },
                ),
                const SizedBox(height: 12),
                _footer(t),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(SafeTokens tokens, L t, List<EntryGroup> groups) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          _retour(tokens, t),
          const Spacer(),
          // À l'opposé du retour, et de la même hauteur que lui: les deux
          // cibles font 48 px, la rangée n'en gagne pas un seul, et rien ne
          // peut être touché par erreur en visant l'autre.
          GestureDetector(
            key: const Key('delete-entry'),
            behavior: HitTestBehavior.opaque,
            onTap: _supprimer,
            // Calé comme le retour d'en face, et non centré dans une boîte de
            // 48: le centrage posait le mot cinq pixels plus bas que
            // « Coffre », sur deux commandes qui se regardent d'un bord à
            // l'autre de la rangée. Onze pixels de texte entre ces deux
            // marges font toujours la cible de 48.
            child: Padding(
              padding: const EdgeInsets.only(top: 13.5, bottom: 23.5),
              child: Text(
                t.delete,
                style: SafeText.action.copyWith(color: tokens.secondaryText),
              ),
            ),
          ),
        ],
      ),
      TextField(
        key: const Key('name'),
        controller: _nameController,
        // Le clavier n'a pas à apprendre un nom de fiche: il est chiffré dans
        // le coffre, il n'a pas à ressortir ailleurs en suggestion.
        autocorrect: false,
        enableSuggestions: false,
        style: SafeText.screenTitle.copyWith(color: tokens.ink),
        cursorColor: tokens.accent,
        decoration: InputDecoration(
          isDense: true,
          // Aucune marge: le titre occupe exactement la place qu'il occupait
          // en `Text` — 29 px, mesurés identiques avec et sans le focus, le
          // filet ne coûtant rien. Le champ fait donc 29 px
          // et non 48: au-dessus, le retour est déjà une cible; en dessous, la
          // seule place libre est celle du compteur, qu'on ne peut pas rendre
          // touchable sans que taper « 3 blocs · 4 lignes » ouvre le clavier.
          // Une marge confortable, elle, pousserait de vingt pixels tout ce qui
          // suit sur un écran déjà validé à l'œil. Le titre reste large:
          // 29 px sur toute la largeur de l'écran, pas une lettre isolée.
          contentPadding: EdgeInsets.zero,
          // La maquette ne dessine pas de trait sous ce titre: au repos, le
          // champ doit être indiscernable du texte qu'il remplace. Le filet
          // n'apparaît qu'au focus — et le filet au repos, de la couleur du
          // fond, garde la géométrie exacte des deux états: rien ne saute au
          // moment où l'on touche le titre.
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: tokens.pageBackground, width: 1.5),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: tokens.strongDivider, width: 1.5),
          ),
        ),
      ),
      // Quatre et non six: les deux pixels manquants sont ceux que la marge
      // basse du retour a pris pour atteindre 48. Rendus ici, le compteur, la
      // barre de mode et tout ce qui suit retrouvent leur place exacte.
      const SizedBox(height: 4),
      Text(
        describeGroups(t, groups),
        style: SafeText.counter.copyWith(color: tokens.hintText),
      ),
    ],
  );

  /// Le retour au coffre.
  ///
  /// L'écart de 8 px qui suivait le retour est passé dans sa marge basse, et
  /// deux pixels de plus l'amènent à 48: la cible fait la taille d'un doigt,
  /// comme celle de la nouvelle fiche. La flèche ne bouge pas, et ces deux
  /// pixels sont repris sur l'écart sous le titre — seul le titre descend de
  /// deux pixels, tout le reste de l'écran reste exactement où il était.
  Widget _retour(SafeTokens tokens, L t) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => Navigator.of(context).maybePop(),
    child: Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_back, size: 18, color: tokens.secondaryText),
          const SizedBox(width: 6),
          Text(
            t.tabVault,
            style: SafeText.action.copyWith(color: tokens.secondaryText),
          ),
        ],
      ),
    ),
  );

  Widget _modeBar(SafeTokens tokens, L t) => Row(
    children: [
      Expanded(
        child: SafePillTabs(
          labels: [t.entryTabReading, t.entryTabRaw],
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
      if (_tutorial.visible == false)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _tutorial.recall(),
          child: SizedBox(
            // Aussi haute que la barre de mode d'à côté: le libellé reste à sa
            // place, centré, et la cible fait la taille d'un doigt.
            height: SafeMetrics.touchTarget,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Text(
                  t.syntaxLink,
                  style: SafeText.action.copyWith(color: tokens.accent),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _raw(SafeTokens tokens, L t) => DecoratedBox(
    decoration: BoxDecoration(
      color: tokens.cardSurface,
      borderRadius: BorderRadius.circular(SafeMetrics.cardRadius),
      border: Border.all(color: tokens.strongDivider),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: SafeRawEditor(
        fieldKey: const Key('raw'),
        controller: _controller,
        hintText: t.entryRawHint,
      ),
    ),
  );

  Widget _footer(L t) => Row(
    children: [
      Expanded(
        child: SafeSecondaryButton(
          label: t.attachmentAdd,
          onPressed: _openAttachments,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: SafePrimaryButton(label: t.save, onPressed: _save, busy: _busy),
      ),
    ],
  );
}
