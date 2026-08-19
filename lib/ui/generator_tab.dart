import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/generator_session.dart';
import '../util/clipboard.dart';
import '../util/password_generator.dart';
import 'theme/safe_theme.dart';
import 'widgets/block_card.dart';
import 'widgets/primary_button.dart';
import 'widgets/safe_toast.dart';

/// L'onglet Générateur de l'accueil.
///
/// Le générateur n'appartient plus à un champ d'édition: c'est un outil à
/// part, dont on prend la valeur pour la coller où l'on veut — dans une fiche,
/// sur un site, dans un autre gestionnaire. L'écran ne sait rien du coffre.
///
/// Tout ce qu'il affiche vit dans [GeneratorSession], en mémoire seulement:
/// l'historique n'est jamais écrit sur le disque et disparaît au verrouillage.
/// C'est ce que la mention sous l'historique promet, et c'est le seul endroit
/// où l'application affiche un secret sans qu'on l'ait demandé.
class GeneratorTab extends StatefulWidget {
  const GeneratorTab({required this.generator, this.clipboard, super.key});

  /// L'état du générateur. Il appartient à l'accueil, qui le libère: cet
  /// onglet est démonté et remonté à chaque changement d'onglet, et une valeur
  /// perdue à chaque aller-retour n'aurait aucun sens.
  final GeneratorSession generator;

  /// Presse-papier auto-effaçant; celui par défaut suffit hors tests.
  final SecureClipboard? clipboard;

  @override
  State<GeneratorTab> createState() => _GeneratorTabState();
}

class _GeneratorTabState extends State<GeneratorTab> {
  /// Durée pendant laquelle le bouton dit « Copié ✓ ».
  static const Duration _retourDeCopie = Duration(milliseconds: 1600);

  /// Hauteur visible d'une pastille de jeu de caractères.
  static const double _hauteurPastille = 36;

  /// Marge touchable d'une pastille, de part et d'autre. Elle est reprise sur
  /// les écarts voisins pour que rien ne bouge à l'écran.
  static const double _margePastille =
      (SafeMetrics.touchTarget - _hauteurPastille) / 2;

  late final SecureClipboard _clipboard = widget.clipboard ?? SecureClipboard();

  Timer? _retour;
  bool _copie = false;

  @override
  void initState() {
    super.initState();
    widget.generator.addListener(_onGenerateur);
  }

  /// Au verrouillage, la session se vide.
  ///
  /// Le bouton, lui, compte son propre temps: sans cela il continuerait
  /// d'annoncer « Copié ✓ » jusqu'à une seconde et demie après la fermeture du
  /// coffre, au-dessus d'une valeur qui n'existe plus.
  void _onGenerateur() {
    if (mounted && _copie && widget.generator.value.isEmpty) {
      _retour?.cancel();
      setState(() => _copie = false);
    }
  }

  @override
  void dispose() {
    widget.generator.removeListener(_onGenerateur);
    // Sans cette annulation, la minuterie réveillerait un `setState` sur un
    // écran démonté — et, en test, laisserait une minuterie en attente.
    _retour?.cancel();
    if (widget.clipboard == null) {
      _clipboard.dispose();
    }
    super.dispose();
  }

  Future<void> _copier(String valeur) async {
    if (valeur.isEmpty) {
      // Après un verrouillage, la session est vidée: il n'y a rien à copier.
      return;
    }
    // L'état part avant la copie: celle-ci est un aller-retour vers la
    // plateforme, et attendre sa réponse retarderait le retour au doigt.
    setState(() => _copie = true);
    _retour?.cancel();
    _retour = Timer(_retourDeCopie, () {
      if (mounted) {
        setState(() => _copie = false);
      }
    });
    try {
      await _clipboard.copy(valeur);
    } on MissingPluginException {
      // Aucun presse-papier sous la main — un hôte de développement, pas un
      // téléphone. Rien à signaler: il n'y a rien à corriger côté utilisateur.
    } catch (_) {
      // Le bouton annonce déjà une copie faite: le démentir vaut mieux que le
      // laisser mentir pendant que l'erreur file en exception de zone.
      if (mounted) {
        showSafeToast(context, 'Copie impossible');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    return AnimatedBuilder(
      animation: widget.generator,
      builder: (context, _) => SingleChildScrollView(
        // Défilant, et non figé: la carte, le curseur, les pastilles et trois
        // lignes d'historique dépassent d'un écran court, et une valeur
        // générée coupée par le bas serait recopiée fausse.
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _carte(tokens),
            if (widget.generator.history.isNotEmpty) _historique(tokens),
          ],
        ),
      ),
    );
  }

  Widget _carte(SafeTokens tokens) => DecoratedBox(
    decoration: BoxDecoration(
      color: tokens.cardSurface,
      borderRadius: BorderRadius.circular(SafeMetrics.generatorCardRadius),
    ),
    child: Padding(
      // Vingt pixels partout, sauf en bas où la rangée de pastilles rend déjà
      // sa marge touchable: 14 + 6 = 20, et la carte se ferme où elle se
      // fermait.
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20 - _margePastille),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            // Une valeur courte ne doit pas faire remonter le bouton: la carte
            // garde sa hauteur d'une longueur à l'autre.
            constraints: const BoxConstraints(minHeight: 62),
            child: Text(
              widget.generator.value,
              style: SafeText.generatorValue.copyWith(color: tokens.ink),
              // Sans coupure de mot, la valeur déborderait par la droite: elle
              // n'a ni espace ni césure possible.
              softWrap: true,
            ),
          ),
          const SizedBox(height: 14),
          _boutons(tokens),
          const SizedBox(height: 16),
          _longueur(tokens),
          Slider(
            value: widget.generator.length.toDouble(),
            // Les bornes du générateur, et pas d'autres: une longueur hors de
            // ces bornes fait lever `generatePassword`, et l'écran tombait.
            min: minPasswordLength.toDouble(),
            max: maxPasswordLength.toDouble(),
            divisions: maxPasswordLength - minPasswordLength,
            onChanged: (valeur) => widget.generator.setLength(valeur.round()),
          ),
          const SizedBox(height: 10 - _margePastille),
          _pastilles(tokens),
        ],
      ),
    ),
  );

  Widget _boutons(SafeTokens tokens) => Row(
    children: [
      Expanded(
        // Le bouton plein partagé: il fait 50 px et non les 48 du handoff,
        // et le carré ci-contre s'aligne sur lui. Redéclarer un bouton de
        // 48 px ici ferait deux boutons pleins dans l'application, à deux
        // pixels près, pour rien.
        child: SafePrimaryButton(
          label: _copie ? 'Copié ✓' : 'Copier',
          onPressed: () => _copier(widget.generator.value),
        ),
      ),
      const SizedBox(width: 10),
      Semantics(
        button: true,
        label: 'Régénérer',
        child: GestureDetector(
          key: const Key('regenerate'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.generator.regenerate,
          child: Container(
            // Carré, de la hauteur du bouton d'à côté: les deux commandes
            // s'alignent, et le carré fait plus que la cible minimale.
            width: SafeMetrics.pillHeight,
            height: SafeMetrics.pillHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: tokens.controlBorder),
              borderRadius: BorderRadius.circular(SafeMetrics.pillHeight / 2),
            ),
            child: ExcludeSemantics(
              child: Text(
                '↻',
                style: TextStyle(
                  fontFamily: safeSans,
                  fontSize: 18,
                  height: 1,
                  color: tokens.accent,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _longueur(SafeTokens tokens) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        'LONGUEUR',
        style: SafeText.sectionLabel.copyWith(color: tokens.tertiaryText),
      ),
      Text(
        '${widget.generator.length}',
        // En chasse fixe: c'est un nombre qui change sous le doigt, et les
        // chiffres ne doivent pas danser d'une largeur à l'autre.
        style: SafeText.counter.copyWith(
          fontSize: 13,
          color: tokens.secondaryText,
        ),
      ),
    ],
  );

  Widget _pastilles(SafeTokens tokens) => Row(
    children: [
      for (final jeu in CharacterSet.values) ...[
        if (jeu != CharacterSet.values.first) const SizedBox(width: 7),
        Expanded(child: _pastille(tokens, jeu)),
      ],
    ],
  );

  Widget _pastille(SafeTokens tokens, CharacterSet jeu) {
    final active = widget.generator.set == jeu;
    return GestureDetector(
      // Opaque, et sur toute la hauteur touchable: sans cela le doigt tomberait
      // entre les lettres du libellé.
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.generator.setSet(jeu),
      child: SizedBox(
        height: SafeMetrics.touchTarget,
        child: Center(
          child: Container(
            height: _hauteurPastille,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? tokens.softAccentSurface : null,
              border: Border.all(
                color: active ? tokens.accent : tokens.controlBorder,
                width: active ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(_hauteurPastille / 2),
            ),
            child: Text(
              jeu.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: safeSans,
                fontSize: 11.5,
                height: 1,
                fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                color: active ? tokens.accentDark : tokens.secondaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _historique(SafeTokens tokens) {
    final valeurs = widget.generator.history;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GÉNÉRÉ AVANT',
            style: SafeText.sectionLabel.copyWith(color: tokens.tertiaryText),
          ),
          for (var rang = 0; rang < valeurs.length; rang++)
            Row(
              children: [
                Expanded(
                  child: Text(
                    valeurs[rang],
                    style: SafeText.entryValue.copyWith(
                      color: tokens.secondaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SafeCopyAction(
                  key: Key('copy-history-$rang'),
                  label: 'copier',
                  onTap: () => _copier(valeurs[rang]),
                  // La marge verticale est la cible tactile: 18,5 de part et
                  // d'autre d'un libellé de 11 px font exactement 48.
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 18.5,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            'Effacé au verrouillage. Jamais écrit sur le disque.',
            style: SafeText.meta.copyWith(color: tokens.hintText),
          ),
        ],
      ),
    );
  }
}
