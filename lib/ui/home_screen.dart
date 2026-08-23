import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/vault.dart';
import '../state/generator_session.dart';
import '../state/vault_session.dart';
import '../storage/app_settings.dart';
import '../storage/vault_transfer.dart';
import '../util/clipboard.dart';
import 'entry_screen.dart';
import 'generator_tab.dart';
import 'new_entry_screen.dart';
import 'safe_logo.dart';
import 'settings_screen.dart';
import 'theme/safe_theme.dart';
import 'widgets/pill_tabs.dart';
import 'widgets/primary_button.dart';
import 'widgets/safe_toast.dart';
import 'vault_tab.dart';

/// L'accueil du coffre déverrouillé: le coffre et le générateur, côte à côte.
///
/// L'écran ne porte lui-même que l'en-tête, les onglets et le bouton de pied —
/// les deux derniers restent visibles quel que soit l'onglet. Il possède le
/// [GeneratorSession] et le libère: l'état du générateur doit survivre à un
/// aller-retour entre les onglets, mais pas à l'écran.
///
/// C'est aussi d'ici que part toute la navigation: la fiche, la création et
/// les réglages. Les onglets n'empilent aucune route.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.session,
    this.clipboard,
    this.transfer,
    this.settings,
    this.language,
    super.key,
  });

  final VaultSession session;

  /// Langue choisie, transmise aux réglages — le seul écran qui l'écrit.
  final ValueNotifier<AppLanguage>? language;

  /// Préférences de l'application, transmises aux écrans qui en dépendent.
  final SettingsStore? settings;

  /// Presse-papier auto-effaçant; celui par défaut suffit hors tests.
  final SecureClipboard? clipboard;

  /// Export/import; absent dans les tests d'interface, où aucun fichier réel
  /// n'est manipulé.
  final VaultTransfer? transfer;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Hauteur du contenu visible de l'en-tête: le logotype, plus haut que le
  /// logo de 17 px.
  static const double _hauteurEnTete = 19;

  /// Ce que les deux commandes de l'en-tête — le cadenas et les réglages —
  /// ajoutent de part et d'autre pour atteindre la cible tactile. Elles font
  /// la hauteur de la ligne à elles seules; l'écart au-dessus la déduit.
  static const double _margeEnTete =
      (SafeMetrics.touchTarget - _hauteurEnTete) / 2;

  late final SecureClipboard _clipboard = widget.clipboard ?? SecureClipboard();

  /// Construit tout de suite, et non à la première ouverture de l'onglet: il
  /// s'abonne au verrouillage pour vider son historique, et un abonnement pris
  /// paresseusement laisserait passer le verrouillage qui le précède.
  late final GeneratorSession _generator;

  int _onglet = 0;

  @override
  void initState() {
    super.initState();
    _generator = GeneratorSession(widget.session);
  }

  @override
  void dispose() {
    // Le générateur appartient à cet écran: personne d'autre ne le libérera,
    // et son auditeur sur la session survivrait à l'accueil.
    _generator.dispose();
    if (widget.clipboard == null) {
      _clipboard.dispose();
    }
    super.dispose();
  }

  Future<void> _copier(String valeur) async {
    widget.session.touch();
    // Le toast part avant la copie: celle-ci est un aller-retour vers la
    // plateforme, et attendre sa réponse retarderait le retour au doigt.
    showSafeToast(context, 'Copié');
    try {
      await _clipboard.copy(valeur);
    } on MissingPluginException {
      // Aucun presse-papier sous la main — un hôte de développement, pas un
      // téléphone. Rien à signaler à l'utilisateur.
    } catch (_) {
      if (mounted) {
        showSafeToast(context, 'Copie impossible');
      }
    }
  }

  Future<void> _ouvrirFiche(VaultEntry entry) async {
    widget.session.touch();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => EntryScreen(
          session: widget.session,
          entry: entry,
          settings: widget.settings,
          clipboard: widget.clipboard,
        ),
      ),
    );
  }

  Future<void> _ouvrirCreation() async {
    widget.session.touch();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            NewEntryScreen(session: widget.session, settings: widget.settings),
      ),
    );
  }

  Future<void> _ouvrirReglages() async {
    widget.session.touch();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsScreen(
          session: widget.session,
          transfer: widget.transfer,
          settings: widget.settings,
          language: widget.language,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.pageBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SafeMetrics.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Vingt-deux pixels visés au-dessus de l'en-tête, moins ce que
              // les commandes de l'en-tête ajoutent au-dessus du logotype.
              const SizedBox(height: 22 - _margeEnTete),
              _enTete(tokens),
              // Aucun écart écrit ici: l'en-tête et la barre d'onglets rendent
              // déjà, à eux deux, un peu plus que les seize pixels visés — et
              // ce reste n'est pas récupérable sans rogner une cible tactile.
              SafePillTabs(
                labels: const ['Coffre', 'Générateur'],
                selected: _onglet,
                onSelected: (index) {
                  widget.session.touch();
                  setState(() => _onglet = index);
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _onglet == 0
                    ? VaultTab(
                        session: widget.session,
                        onOpen: _ouvrirFiche,
                        onCopy: _copier,
                      )
                    : GeneratorTab(
                        generator: _generator,
                        clipboard: widget.clipboard,
                      ),
              ),
              Padding(
                // La gouttière est déjà posée par la colonne.
                padding: const EdgeInsets.fromLTRB(0, 14, 0, 22),
                child: SafePrimaryButton(
                  key: const Key('add'),
                  label: 'Nouvelle fiche',
                  onPressed: _ouvrirCreation,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _enTete(SafeTokens tokens) => Row(
    children: [
      const SafeLogo(size: 17),
      const SizedBox(width: 10),
      Text('safe', style: SafeText.wordmark.copyWith(color: tokens.ink)),
      const Spacer(),
      GestureDetector(
        key: const Key('header-lock'),
        // Le geste qu'on fait quand quelqu'un entre dans la pièce: il doit
        // tomber sous le pouce depuis l'accueil, sans passer par les réglages
        // — deux tapes et une lecture de liste arrivent trop tard. La commande
        // reste AUSSI dans les réglages, à côté du délai automatique.
        behavior: HitTestBehavior.opaque,
        onTap: widget.session.lock,
        child: SizedBox(
          width: SafeMetrics.touchTarget,
          height: SafeMetrics.touchTarget,
          child: Center(
            child: Semantics(
              button: true,
              label: 'Verrouiller',
              // Un pictogramme, pas un caractère: aucune des deux fontes
              // embarquées ne porte de cadenas, et un carré vide à la place du
              // verrou serait la pire des annonces. `Icons` vient de
              // MaterialIcons, livrée avec l'application.
              //
              // Vingt et un pixels comme le cercle voisin, mais en
              // `secondaryText` et non en `inactiveBullet`: le cercle des
              // réglages est un décor que le handoff dessine pâle, le cadenas
              // est un signe qu'il faut voir.
              child: Icon(
                Icons.lock_outline,
                size: 21,
                color: tokens.secondaryText,
              ),
            ),
          ),
        ),
      ),
      GestureDetector(
        key: const Key('settings'),
        // Opaque et de la taille d'un doigt: le signe du handoff ne fait que
        // 21 px. Le cadenas est son voisin immédiat, et les deux cibles se
        // touchent sans se recouvrir — la garde de l'accueil mesure les deux
        // rectangles.
        behavior: HitTestBehavior.opaque,
        onTap: _ouvrirReglages,
        child: SizedBox(
          width: SafeMetrics.touchTarget,
          height: SafeMetrics.touchTarget,
          child: Center(
            child: Semantics(
              button: true,
              label: 'Réglages',
              // Le handoff dessine ici un cercle vide et pâle. À l'écran il ne
              // dit rien: rien n'y indique qu'il ouvre les réglages, et à côté
              // d'un cadenas lisible il se lit comme une puce décorative. Une
              // roue dentée, à la taille et à l'encre du cadenas, pour que les
              // deux commandes de l'en-tête se lisent comme une paire.
              child: Icon(
                Icons.settings_outlined,
                size: 21,
                color: tokens.secondaryText,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
