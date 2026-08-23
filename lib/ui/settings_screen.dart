import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../crypto/vault_crypto.dart';
import '../state/vault_session.dart';
import '../storage/app_settings.dart';
import '../storage/vault_transfer.dart';
import '../util/file_saver.dart';
import '../util/screen_security.dart';
import 'theme/safe_theme.dart';
import 'unlock_screen.dart';
import 'widgets/primary_button.dart';

/// Le paragraphe de glose de la refonte.
///
/// La même linéale de 13,5 px sur 1,6 que l'écran de déverrouillage, qui est
/// le seul autre endroit où l'application explique quelque chose en plusieurs
/// phrases. [SafeText] ne lui donne pas de nom; le reprendre au caractère près
/// vaut mieux qu'inventer une taille de plus.
const TextStyle _paragraph = TextStyle(
  fontFamily: safeSans,
  fontWeight: FontWeight.w400,
  fontSize: 13.5,
  height: 1.6,
);

/// La forme commune aux trois boîtes de cet écran.
///
/// Elles gardent leurs mots, leurs clefs et leur ordre — annuler à gauche,
/// valider à droite; seuls la carte du handoff, ses polices et ses deux
/// pilules remplacent l'habillage Material par défaut.
AlertDialog _safeDialog(
  BuildContext context, {
  required String title,
  required Widget content,
  required Widget cancel,
  required Widget confirm,
}) {
  final tokens = SafeTokens.of(context);
  return AlertDialog(
    backgroundColor: tokens.cardSurface,
    // Sans quoi Material repose un voile de teinte sur la carte blanche.
    surfaceTintColor: tokens.cardSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SafeMetrics.cardRadius),
    ),
    titleTextStyle: SafeText.wordmark.copyWith(color: tokens.ink),
    contentTextStyle: _paragraph.copyWith(color: tokens.secondaryText),
    title: Text(title),
    content: content,
    actionsPadding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
    actions: [
      // Les deux pilules côte à côte, à parts égales: `actions` est une
      // `OverflowBar`, qui ne sait pas partager sa largeur — la rangée le
      // fait à sa place, et les libellés sont courts.
      Row(
        children: [
          Expanded(child: cancel),
          const SizedBox(width: 10),
          Expanded(child: confirm),
        ],
      ),
    ],
  );
}

/// Les deux façons de sortir le coffre de l'appareil.
enum _Export { enregistrer, partager }

/// Réglages: mot de passe maître, délai de verrouillage, export et import.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.session,
    required this.settings,
    this.transfer,
    this.screen = const ScreenSecurity(),
    this.saver = const FileSaver(),
    this.language,
    super.key,
  });

  final VaultSession session;

  /// Préférences persistées, relues à l'ouverture de l'écran. Absent dans les
  /// tests d'interface qui ne touchent pas à ce réglage: la bascule fonctionne
  /// alors sans rien écrire.
  final SettingsStore? settings;

  /// Absent quand l'export/import n'est pas disponible (tests d'interface).
  final VaultTransfer? transfer;

  final ScreenSecurity screen;

  /// La langue choisie. Cet écran est le seul à l'écrire; la lui passer, c'est
  /// ce qui fait basculer l'application entière sans la relancer. Absente dans
  /// les tests qui ne touchent pas à ce réglage.
  final ValueNotifier<AppLanguage>? language;

  /// Écriture d'un fichier dans un dossier choisi. Là où il se déclare
  /// compétent — Android —, l'export laisse le choix entre enregistrer et
  /// partager; ailleurs il garde son sélecteur d'enregistrement habituel.
  final FileSaver saver;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Les libellés de l'écran.
  ///
  /// Un raccourci et non un champ: la langue peut changer sous cet écran même
  /// — c'est lui qui la règle —, et un libellé figé au premier montage
  /// laisserait la moitié de la page dans l'ancienne langue. Les méthodes
  /// asynchrones le lisent avant leur premier `await`.
  L get t => L.of(context);

  bool _busy = false;
  AppSettings _settings = const AppSettings();

  @override
  void initState() {
    super.initState();
    widget.settings?.read().then((loaded) {
      if (mounted) {
        // La session peut avoir été construite avant la lecture des réglages:
        // on la remet d'accord avec le fichier. Hors du `setState`, ce setter
        // prévenant ses propres écouteurs.
        widget.session.autoLockDelay = loaded.autoLockDelay;
        setState(() => _settings = loaded);
      }
    });
  }

  Future<void> _setAutoLockDelay(Duration value) async {
    final previous = _settings;
    final updated = _settings.copyWith(autoLockDelay: value);
    // Hors du `setState`: ce setter prévient ses écouteurs, et un effet de bord
    // n'a pas sa place dans un rappel censé n'être que local.
    widget.session.autoLockDelay = value;
    setState(() => _settings = updated);
    if (!await _persist(updated)) {
      widget.session.autoLockDelay = previous.autoLockDelay;
      setState(() => _settings = previous);
    }
  }

  Future<void> _setBlockScreenshots(bool blocked) async {
    final previous = _settings;
    final updated = _settings.copyWith(blockScreenshots: blocked);
    setState(() => _settings = updated);

    final applied = await widget.screen.setBlocked(blocked);
    if (blocked && widget.screen.isSupported && !applied) {
      // Afficher « bloqué » alors que rien ne l'est serait pire que l'aveu:
      // l'utilisateur ferait confiance à une protection absente.
      if (mounted) {
        setState(() => _settings = previous);
        _tell(t.settingsBlockRefused);
      }
      return;
    }
    if (!await _persist(updated)) {
      await widget.screen.setBlocked(previous.blockScreenshots);
      if (mounted) {
        setState(() => _settings = previous);
      }
    }
  }

  /// Écrit les réglages; rend `false` et prévient l'utilisateur si l'écriture
  /// échoue, pour que l'interface n'affiche pas un choix qui sera perdu au
  /// prochain lancement.
  Future<bool> _persist(AppSettings settings) async {
    try {
      await widget.settings?.write(settings);
      return true;
    } catch (_) {
      _tell(t.settingsNotSaved);
      return false;
    }
  }

  Future<void> _changePassword() async {
    final newPassword = await showDialog<String>(
      context: context,
      builder: (context) => const _ChangePasswordDialog(),
    );
    if (newPassword == null || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.session.changePassword(newPassword);
      _tell(t.settingsPasswordChanged);
    } catch (_) {
      _tell(t.settingsChangeFailed);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Propose de revenir à la copie conservée à côté du coffre.
  ///
  /// Annonce d'abord ce qu'elle contient: une restauration à l'aveugle sur un
  /// coffre-fort n'est pas une offre honnête.
  Future<void> _restore() async {
    setState(() => _busy = true);
    final int? entryCount;
    try {
      entryCount = await widget.session.previousEntryCount();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
    if (!mounted) {
      return;
    }
    // Recopié dans un local pour que Dart le promeuve en `int`: un `final`
    // affecté dans un `try` ne l'est pas par le seul test de nullité.
    final backupCount = entryCount;
    if (backupCount == null) {
      _tell(t.settingsNoBackup);
      return;
    }
    final currentCount = widget.session.vault?.entries.length ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _safeDialog(
        context,
        title: t.settingsRestoreTitle,
        content: Text(t.settingsRestoreBody(backupCount, currentCount)),
        cancel: SafeSecondaryButton(
          key: const Key('cancel-restore'),
          label: t.cancel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        confirm: SafePrimaryButton(
          key: const Key('confirm-restore'),
          label: t.settingsRestore,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (!(confirmed ?? false) || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.session.restorePrevious();
      _tell(t.settingsRestored);
    } catch (_) {
      _tell(t.settingsRestoreFailed);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _export() async {
    final transfer = widget.transfer;
    if (transfer == null) {
      return;
    }
    // Le choix est demandé AVANT de déchiffrer quoi que ce soit: renoncer à la
    // feuille ne doit pas laisser les octets du coffre traîner en mémoire.
    var partager = Platform.isAndroid || Platform.isIOS;
    if (widget.saver.isSupported) {
      final choix = await _commentExporter();
      if (choix == null) {
        return;
      }
      partager = choix == _Export.partager;
    }
    if (!mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await transfer.exportBytes();
      if (widget.saver.isSupported && !partager) {
        final nom = await widget.saver.save(
          suggestedName: 'vault.safe',
          bytes: bytes,
        );
        // `null` = l'utilisateur a renoncé. Annoncer un export qui n'a pas eu
        // lieu ferait croire à une sauvegarde qui n'existe pas.
        if (nom != null) {
          _tell(t.settingsExported(nom));
        }
      } else if (partager) {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(bytes, mimeType: 'application/octet-stream'),
            ],
            fileNameOverrides: const ['vault.safe'],
          ),
        );
      } else {
        final location = await getSaveLocation(suggestedName: 'vault.safe');
        if (location != null) {
          await File(location.path).writeAsBytes(bytes);
          _tell(t.settingsExported(location.path));
        }
      }
    } catch (_) {
      _tell(t.settingsExportFailed);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Demande s'il faut enregistrer le fichier ou le passer à une application.
  Future<_Export?> _commentExporter() {
    final tokens = SafeTokens.of(context);
    return showModalBottomSheet<_Export>(
      context: context,
      backgroundColor: tokens.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t.settingsExport,
                  style: SafeText.listTitle.copyWith(color: tokens.ink),
                ),
              ),
            ),
            ListTile(
              key: const Key('export-save'),
              leading: Icon(Icons.save_alt, color: tokens.secondaryText),
              title: Text(t.settingsExportSave),
              subtitle: Text(t.settingsExportSaveSubtitle),
              onTap: () => Navigator.of(sheet).pop(_Export.enregistrer),
            ),
            ListTile(
              key: const Key('export-share'),
              leading: Icon(Icons.ios_share, color: tokens.secondaryText),
              title: Text(t.settingsExportShare),
              subtitle: Text(t.settingsExportShareSubtitle),
              onTap: () => Navigator.of(sheet).pop(_Export.partager),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _import() async {
    final transfer = widget.transfer;
    if (transfer == null) {
      return;
    }
    final file = await openFile();
    if (file == null) {
      return;
    }
    final bytes = Uint8List.fromList(await file.readAsBytes());
    if (!mounted) {
      return;
    }
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _ImportPasswordDialog(),
    );
    if (password == null || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await transfer.importBytes(bytes, password);
      // Le coffre importé a son propre mot de passe: on verrouille pour forcer
      // un déverrouillage avec celui-là, plutôt que de garder une clé qui
      // n'ouvre plus rien.
      widget.session.lock();
      _tell(t.settingsImported);
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on FormatException {
      _tell(t.settingsImportNotAVault);
    } on WrongPasswordException {
      // Message volontairement vague: un tag AEAD invalide ne dit pas si c'est
      // le mot de passe ou le fichier qui cloche.
      _tell(t.settingsImportWrongPassword);
    } catch (_) {
      // Tout le reste — disque plein, permission refusée — mérite un autre
      // message: sinon l'utilisateur ressaisit indéfiniment un mot de passe
      // pourtant juste.
      _tell(t.settingsImportFailed);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Le message d'échec, en bas de l'écran.
  ///
  /// Reste un `SnackBar` et non la pilule de [showSafeToast]: celle-ci tient
  /// 1,5 s et une ligne, quand ces messages-ci sont des phrases entières qu'il
  /// faut avoir le temps de lire. Seuls sa couleur, sa forme et sa police
  /// rejoignent la pilule.
  void _tell(String message) {
    if (mounted) {
      final tokens = SafeTokens.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: tokens.ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SafeMetrics.cardRadius),
          ),
          content: Text(
            message,
            style: SafeText.action.copyWith(
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: tokens.onInk,
            ),
          ),
        ),
      );
    }
  }

  /// Change la langue de l'application, et l'écrit.
  ///
  /// Le notifieur d'abord: c'est lui qui redessine tout de suite, y compris
  /// cet écran-ci. L'écriture ensuite — si le fichier résiste, la langue reste
  /// celle qu'on vient de choisir pour cette session, et la panne est dite.
  Future<void> _setLanguage(AppLanguage choix) async {
    widget.session.touch();
    widget.language?.value = choix;
    setState(() => _settings = _settings.copyWith(language: choix));
    await _persist(_settings);
  }

  String _label(L t, Duration delay) =>
      delay.inSeconds < 60 ? '${delay.inSeconds} s' : '${delay.inMinutes} min';

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    final transferAvailable = widget.transfer != null;
    return Scaffold(
      backgroundColor: tokens.pageBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SafeMetrics.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _enTete(tokens),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 28),
                  children: [
                    // Une seule carte, dans l'ordre exact d'avant: les filets
                    // qui séparaient les lignes sont devenus les filets
                    // intérieurs de la carte, et le dernier — celui qui
                    // séparait la liste de la note — est devenu son bord bas.
                    _carte(tokens, transferAvailable),
                    _note(tokens),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Le retour et le titre, calés comme sur la fiche.
  ///
  /// La flèche seule, sans le mot qui l'accompagne ailleurs: nommer la
  /// destination serait ajouter un libellé à un écran dont le brief gèle les
  /// mots. Elle reste annoncée « Retour » à la synthèse vocale, ce que la
  /// flèche de l'`AppBar` faisait avant elle.
  Widget _enTete(SafeTokens tokens) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: Semantics(
          button: true,
          label: t.back,
          // Dix-huit pixels de flèche entre ces marges font la cible de 48 en
          // hauteur; les trente pixels de droite la font en largeur.
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 20, right: 30),
            child: Icon(
              Icons.arrow_back,
              size: 18,
              color: tokens.secondaryText,
            ),
          ),
        ),
      ),
      // `header` et `namesRoute`: l'`AppBar` les posait toute seule. Sans le
      // second, la synthèse vocale n'annonce rien quand l'écran s'ouvre; sans
      // le premier, la navigation par en-têtes ne s'arrête plus sur le titre.
      Semantics(
        header: true,
        namesRoute: true,
        child: Text(
          t.settingsTitle,
          style: SafeText.screenTitle.copyWith(color: tokens.ink),
        ),
      ),
      const SizedBox(height: 16),
    ],
  );

  /// Les six réglages, dans une seule carte blanche.
  ///
  /// `Material` et non un simple `DecoratedBox`: une carte posée au-dessus du
  /// matériau de l'écran masquerait l'onde des lignes qu'on touche, que ce
  /// matériau-là peint sous ses enfants.
  Widget _carte(SafeTokens tokens, bool transferAvailable) => Material(
    color: tokens.cardSurface,
    borderRadius: BorderRadius.circular(SafeMetrics.cardRadius),
    clipBehavior: Clip.antiAlias,
    child: ListTileTheme(
      // Les styles des lignes sont posés ici et non ligne par ligne: écrits
      // sur chaque `ListTile`, ils prendraient le pas sur la couleur d'inactif
      // que Material applique à « Exporter » et « Importer » quand le
      // transfert est absent, et les deux lignes mortes paraîtraient vives.
      data: ListTileThemeData(
        iconColor: tokens.secondaryText,
        titleTextStyle: SafeText.listTitle.copyWith(color: tokens.ink),
        subtitleTextStyle: SafeText.meta.copyWith(color: tokens.secondaryText),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 14,
        minLeadingWidth: 20,
        horizontalTitleGap: 14,
      ),
      child: Column(
        children: [
          ListTile(
            key: const Key('change-password'),
            leading: const Icon(Icons.key_outlined, size: 18),
            title: Text(t.settingsChangePassword),
            subtitle: Text(t.settingsChangePasswordSubtitle),
            enabled: !_busy,
            onTap: _changePassword,
          ),
          _filet(tokens),
          ListTile(
            // Le verrouillage manuel est ici ET dans l'en-tête de l'accueil,
            // décision du propriétaire: le cadenas de l'accueil est le geste
            // pressé, celui-ci est le pendant du délai automatique, juste
            // au-dessous, où on le cherche quand on règle les deux ensemble.
            // Ne pas le retirer d'ici sous prétexte que l'accueil en a un.
            key: const Key('lock'),
            leading: const Icon(Icons.lock_outline, size: 18),
            title: Text(t.settingsLockNow),
            subtitle: Text(t.settingsLockNowSubtitle),
            enabled: !_busy,
            onTap: widget.session.lock,
          ),
          _filet(tokens),
          ListTile(
            leading: const Icon(Icons.timer_outlined, size: 18),
            title: Text(t.settingsAutoLock),
            // Les deux affichages tirent du même champ: sinon le sous-titre
            // annonçait un délai que la liste ne montrait pas.
            subtitle: Text(
              t.settingsAutoLockSubtitle(_label(t, _settings.autoLockDelay)),
            ),
            trailing: DropdownButton<Duration>(
              key: const Key('auto-lock'),
              value: _settings.autoLockDelay,
              // Le handoff ne dessine pas de boîte de contrôle: le trait de
              // Material sous la valeur n'a rien à faire dans une carte.
              underline: const SizedBox.shrink(),
              // Pas de `isDense`: il ramène la cible à 24 px, la moitié d'un
              // doigt, et c'est le seul contrôle de l'écran qu'on ouvre sans
              // le voir grandir.
              borderRadius: BorderRadius.circular(SafeMetrics.cardRadius),
              dropdownColor: tokens.cardSurface,
              icon: Icon(
                Icons.expand_more,
                size: 18,
                color: tokens.secondaryText,
              ),
              style: SafeText.listTitle.copyWith(color: tokens.secondaryText),
              items: [
                for (final choice in autoLockChoices)
                  DropdownMenuItem(
                    value: choice,
                    child: Text(_label(t, choice)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  _setAutoLockDelay(value);
                }
              },
            ),
          ),
          _filet(tokens),
          ListTile(
            leading: const Icon(Icons.translate, size: 18),
            title: Text(t.settingsLanguage),
            // Le sous-titre décrit ce que fait le réglage, pas ce qu'il
            // pourrait faire: une fois une langue choisie, « suit la langue de
            // l'appareil » est exactement ce qu'il ne fait plus.
            subtitle: Text(
              _settings.language == AppLanguage.system
                  ? t.settingsLanguageSubtitle
                  : t.settingsLanguageForced,
            ),
            trailing: DropdownButton<AppLanguage>(
              key: const Key('language'),
              value: _settings.language,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(SafeMetrics.cardRadius),
              dropdownColor: tokens.cardSurface,
              icon: Icon(
                Icons.expand_more,
                size: 18,
                color: tokens.secondaryText,
              ),
              style: SafeText.listTitle.copyWith(color: tokens.secondaryText),
              items: [
                for (final choix in AppLanguage.values)
                  DropdownMenuItem(
                    value: choix,
                    // Le nom d'une langue s'écrit dans cette langue: un
                    // « English » traduit en « Anglais » ne se reconnaît pas
                    // quand on ne lit pas la langue affichée. « Système » n'a
                    // pas de nom propre et se traduit, lui.
                    child: Text(choix.endonym ?? t.settingsLanguageSystem),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  _setLanguage(value);
                }
              },
            ),
          ),
          _filet(tokens),
          SwitchListTile(
            key: const Key('block-screenshots'),
            secondary: const Icon(Icons.screenshot_monitor_outlined, size: 18),
            value: _settings.blockScreenshots,
            onChanged: _busy ? null : _setBlockScreenshots,
            activeThumbColor: tokens.onInk,
            activeTrackColor: tokens.accent,
            title: Text(t.settingsBlockScreenshots),
            subtitle: Text(
              _settings.blockScreenshots
                  ? t.settingsBlockScreenshotsOn
                  : t.settingsBlockScreenshotsOff,
            ),
          ),
          _filet(tokens),
          ListTile(
            key: const Key('restore-backup'),
            leading: const Icon(Icons.restore_outlined, size: 18),
            title: Text(t.settingsRestore),
            subtitle: Text(t.settingsRestoreSubtitle),
            enabled: !_busy,
            onTap: _restore,
          ),
          _filet(tokens),
          ListTile(
            key: const Key('export'),
            leading: const Icon(Icons.upload_file_outlined, size: 18),
            title: Text(t.settingsExport),
            subtitle: Text(t.settingsExportSubtitle),
            enabled: transferAvailable && !_busy,
            onTap: _export,
          ),
          ListTile(
            key: const Key('import'),
            leading: const Icon(Icons.download_outlined, size: 18),
            title: Text(t.settingsImport),
            subtitle: Text(t.settingsImportSubtitle),
            enabled: transferAvailable && !_busy,
            onTap: _import,
          ),
        ],
      ),
    ),
  );

  /// Le filet qui séparait deux lignes, à la couleur du handoff.
  Widget _filet(SafeTokens tokens) =>
      Divider(height: 1, thickness: 1, color: tokens.hairline);

  /// L'avertissement de pied de page, mot pour mot.
  Widget _note(SafeTokens tokens) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 20, 2, 0),
    child: Text(
      t.settingsNote,
      // En encre, et non en texte secondaire: sur le fond crème ce gris tombe
      // à 4,37:1, sous le seuil AA. C'est la seule phrase de l'application qui
      // dit que le mot de passe maître ne se récupère pas — elle ne peut pas
      // être le texte le plus pâle de la page.
      style: _paragraph.copyWith(color: tokens.ink),
    ),
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  L get t => L.of(context);

  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (_password.text.length < minMasterPasswordLength) {
      setState(
        () => _error = t.settingsPasswordTooShort(minMasterPasswordLength),
      );
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = t.unlockMismatch);
      return;
    }
    Navigator.of(context).pop(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    return _safeDialog(
      context,
      title: t.settingsNewPasswordTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _champ(
            tokens,
            key: const Key('new-password'),
            controller: _password,
            label: t.settingsNewPasswordHint,
            autofocus: true,
          ),
          _champ(
            tokens,
            key: const Key('new-confirm'),
            controller: _confirm,
            label: t.settingsConfirmHint,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                // La couleur d'erreur reste celle du schéma: le handoff n'en
                // donne pas, et en choisir une serait inventer une teinte.
                style: SafeText.meta.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
      cancel: SafeSecondaryButton(
        label: t.cancel,
        onPressed: () => Navigator.of(context).pop(),
      ),
      confirm: SafePrimaryButton(
        key: const Key('confirm-change'),
        label: t.settingsChange,
        onPressed: _submit,
      ),
    );
  }
}

/// Le champ masqué des deux boîtes, dessiné comme celui du déverrouillage.
///
/// Chasse fixe et lettres espacées: c'est un mot de passe qu'on relit
/// caractère par caractère, et le filet remplace la boîte de Material — le
/// handoff ne dessine pas de boîte.
Widget _champ(
  SafeTokens tokens, {
  required Key key,
  required TextEditingController controller,
  required String label,
  bool autofocus = false,
}) => TextField(
  key: key,
  controller: controller,
  obscureText: true,
  autofocus: autofocus,
  style: TextStyle(
    fontFamily: safeMono,
    fontWeight: FontWeight.w500,
    fontSize: 16,
    letterSpacing: 2.56,
    color: tokens.ink,
  ),
  cursorColor: tokens.accent,
  cursorWidth: 2,
  decoration: InputDecoration(
    labelText: label,
    labelStyle: _paragraph.copyWith(color: tokens.hintText),
    floatingLabelStyle: SafeText.meta.copyWith(color: tokens.tertiaryText),
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: tokens.controlBorder, width: 1.5),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: tokens.ink, width: 1.5),
    ),
  ),
);

class _ImportPasswordDialog extends StatefulWidget {
  const _ImportPasswordDialog();

  @override
  State<_ImportPasswordDialog> createState() => _ImportPasswordDialogState();
}

class _ImportPasswordDialogState extends State<_ImportPasswordDialog> {
  L get t => L.of(context);

  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _safeDialog(
    context,
    title: t.settingsImportPasswordTitle,
    content: _champ(
      SafeTokens.of(context),
      key: const Key('import-password'),
      controller: _password,
      label: t.settingsImportPasswordHint,
      autofocus: true,
    ),
    cancel: SafeSecondaryButton(
      label: 'Annuler',
      onPressed: () => Navigator.of(context).pop(),
    ),
    confirm: SafePrimaryButton(
      key: const Key('confirm-import'),
      label: 'Importer',
      onPressed: () => Navigator.of(context).pop(_password.text),
    ),
  );
}
