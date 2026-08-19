import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../crypto/vault_crypto.dart';
import '../state/vault_session.dart';
import '../storage/app_settings.dart';
import '../storage/vault_transfer.dart';
import '../util/screen_security.dart';
import 'unlock_screen.dart';

/// Réglages: mot de passe maître, délai de verrouillage, export et import.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.session,
    required this.settings,
    this.transfer,
    this.screen = const ScreenSecurity(),
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

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
        _tell('Blocage refusé par le système: les captures restent possibles');
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
      _tell('Réglage non enregistré: le fichier n\'a pas pu être écrit');
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
      _tell('Mot de passe maître changé');
    } catch (_) {
      _tell('Changement impossible: le coffre n\'a pas pu être ré-chiffré');
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
    if (entryCount == null) {
      _tell('Aucune sauvegarde exploitable à côté du coffre');
      return;
    }
    final currentCount = widget.session.vault?.entries.length ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurer la sauvegarde ?'),
        content: Text(
          'La sauvegarde contient $entryCount entrée(s); le coffre actuel en a '
          '$currentCount.\n\nLe coffre actuel devient à son tour la sauvegarde: '
          'cette opération est donc annulable en la refaisant.\n\nLes pièces '
          'jointes ne sont pas concernées; celles qui ne seraient plus '
          'référencées partent dans le dossier des orphelins.',
        ),
        actions: [
          TextButton(
            key: const Key('cancel-restore'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const Key('confirm-restore'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.session.restorePrevious();
      _tell('Sauvegarde restaurée');
    } catch (_) {
      _tell('Restauration impossible: la sauvegarde n\'a pas pu être lue');
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
    setState(() => _busy = true);
    try {
      final bytes = await transfer.exportBytes();
      if (Platform.isAndroid || Platform.isIOS) {
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
          _tell('Coffre exporté vers ${location.path}');
        }
      }
    } catch (_) {
      _tell('Export impossible: le fichier n\'a pas pu être écrit');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
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
      _tell('Coffre importé — déverrouillez-le avec son mot de passe');
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on FormatException {
      _tell('Ce fichier n\'est pas un coffre safe');
    } on WrongPasswordException {
      // Message volontairement vague: un tag AEAD invalide ne dit pas si c'est
      // le mot de passe ou le fichier qui cloche.
      _tell('Import refusé: mot de passe incorrect ou fichier abîmé');
    } catch (_) {
      // Tout le reste — disque plein, permission refusée — mérite un autre
      // message: sinon l'utilisateur ressaisit indéfiniment un mot de passe
      // pourtant juste.
      _tell('Import impossible: le coffre n\'a pas pu être remplacé');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _tell(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _label(Duration delay) =>
      delay.inSeconds < 60 ? '${delay.inSeconds} s' : '${delay.inMinutes} min';

  @override
  Widget build(BuildContext context) {
    final transferAvailable = widget.transfer != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        children: [
          ListTile(
            key: const Key('change-password'),
            leading: const Icon(Icons.key_outlined),
            title: const Text('Changer le mot de passe maître'),
            subtitle: const Text('Le coffre est entièrement ré-chiffré'),
            enabled: !_busy,
            onTap: _changePassword,
          ),
          const Divider(height: 1),
          ListTile(
            // Le verrouillage manuel a suivi les réglages quand l'accueil a
            // été redessiné: la maquette validée ne pose qu'une commande dans
            // son en-tête, et lui en ajouter une seconde reviendrait à
            // dessiner à la place du designer. Il vit donc ici, à côté du
            // délai automatique dont il est le pendant immédiat — et non plus
            // à un doigt de la liste, mais toujours à portée.
            key: const Key('lock'),
            leading: const Icon(Icons.lock_outline),
            title: const Text('Verrouiller maintenant'),
            subtitle: const Text(
              'Referme le coffre et efface la clef de la mémoire',
            ),
            enabled: !_busy,
            onTap: widget.session.lock,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Verrouillage automatique'),
            // Les deux affichages tirent du même champ: sinon le sous-titre
            // annonçait un délai que la liste ne montrait pas.
            subtitle: Text(
              'Après ${_label(_settings.autoLockDelay)} sans activité',
            ),
            trailing: DropdownButton<Duration>(
              key: const Key('auto-lock'),
              value: _settings.autoLockDelay,
              items: [
                for (final choice in autoLockChoices)
                  DropdownMenuItem(value: choice, child: Text(_label(choice))),
              ],
              onChanged: (value) {
                if (value != null) {
                  _setAutoLockDelay(value);
                }
              },
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            key: const Key('block-screenshots'),
            secondary: const Icon(Icons.screenshot_monitor_outlined),
            value: _settings.blockScreenshots,
            onChanged: _busy ? null : _setBlockScreenshots,
            title: const Text('Bloquer les captures d\'écran'),
            subtitle: Text(
              _settings.blockScreenshots
                  ? 'Captures d\'écran refusées, et vignette vide dans les '
                        'applications récentes'
                  : 'Captures d\'écran autorisées: le contenu du coffre '
                        'apparaîtra aussi dans les applications récentes',
            ),
          ),
          const Divider(height: 1),
          ListTile(
            key: const Key('restore-backup'),
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Restaurer la sauvegarde précédente'),
            subtitle: const Text(
              'Revient à l\'état d\'avant la dernière modification',
            ),
            enabled: !_busy,
            onTap: _restore,
          ),
          const Divider(height: 1),
          ListTile(
            key: const Key('export'),
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Exporter le coffre'),
            subtitle: const Text(
              'Fichier chiffré: inutilisable sans le mot de passe. '
              'Les pièces jointes ne sont pas incluses',
            ),
            enabled: transferAvailable && !_busy,
            onTap: _export,
          ),
          ListTile(
            key: const Key('import'),
            leading: const Icon(Icons.download_outlined),
            title: const Text('Importer un coffre'),
            subtitle: const Text(
              'Remplace le coffre actuel après vérification',
            ),
            enabled: transferAvailable && !_busy,
            onTap: _import,
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Le mot de passe maître ne peut pas être récupéré. Gardez une '
              'copie exportée du coffre en lieu sûr: elle reste chiffrée.\n\n'
              'L\'export ne contient que les clefs et les valeurs. Les pièces '
              'jointes vivent dans des fichiers séparés: exportez-les une par '
              'une depuis l\'entrée concernée.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
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
      setState(() => _error = 'Au moins $minMasterPasswordLength caractères');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas');
      return;
    }
    Navigator.of(context).pop(_password.text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nouveau mot de passe maître'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('new-password'),
          controller: _password,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
        ),
        TextField(
          key: const Key('new-confirm'),
          controller: _confirm,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Confirmation'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Annuler'),
      ),
      FilledButton(
        key: const Key('confirm-change'),
        onPressed: _submit,
        child: const Text('Changer'),
      ),
    ],
  );
}

class _ImportPasswordDialog extends StatefulWidget {
  const _ImportPasswordDialog();

  @override
  State<_ImportPasswordDialog> createState() => _ImportPasswordDialogState();
}

class _ImportPasswordDialogState extends State<_ImportPasswordDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Mot de passe du coffre importé'),
    content: TextField(
      key: const Key('import-password'),
      controller: _password,
      obscureText: true,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Mot de passe'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Annuler'),
      ),
      FilledButton(
        key: const Key('confirm-import'),
        onPressed: () => Navigator.of(context).pop(_password.text),
        child: const Text('Importer'),
      ),
    ],
  );
}
