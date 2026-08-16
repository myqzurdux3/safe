import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../state/vault_session.dart';
import '../storage/app_settings.dart';
import '../storage/vault_transfer.dart';
import '../util/screen_security.dart';
import 'unlock_screen.dart';

/// Délais d'inactivité proposés avant verrouillage automatique.
const List<Duration> autoLockChoices = [
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 2),
  Duration(minutes: 5),
];

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
        setState(() {
          _settings = loaded;
          // La session peut avoir été construite avant la lecture des
          // réglages: on la remet d'accord avec le fichier.
          widget.session.autoLockDelay = loaded.autoLockDelay;
        });
      }
    });
  }

  Future<void> _setAutoLockDelay(Duration value) async {
    final updated = _settings.copyWith(autoLockDelay: value);
    setState(() {
      _settings = updated;
      widget.session.autoLockDelay = value;
    });
    await widget.settings?.write(updated);
  }

  Future<void> _setBlockScreenshots(bool blocked) async {
    final updated = _settings.copyWith(blockScreenshots: blocked);
    setState(() => _settings = updated);
    await widget.screen.setBlocked(blocked);
    await widget.settings?.write(updated);
  }

  Future<void> _changePassword() async {
    final nouveau = await showDialog<String>(
      context: context,
      builder: (context) => const _ChangePasswordDialog(),
    );
    if (nouveau == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.session.changePassword(nouveau);
      _tell('Mot de passe maître changé');
    } catch (error) {
      _tell('Changement impossible: $error');
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
            files: [XFile.fromData(bytes, mimeType: 'application/octet-stream')],
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
    } catch (error) {
      _tell('Export impossible: $error');
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
    if (password == null) {
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
    } catch (error) {
      _tell('Import refusé: mot de passe incorrect ou fichier abîmé');
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

  String _label(Duration delay) => delay.inSeconds < 60
      ? '${delay.inSeconds} s'
      : '${delay.inMinutes} min';

  @override
  Widget build(BuildContext context) {
    final transferDisponible = widget.transfer != null;
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
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Verrouillage automatique'),
            subtitle: Text(
              'Après ${_label(widget.session.autoLockDelay)} sans activité',
            ),
            trailing: DropdownButton<Duration>(
              key: const Key('auto-lock'),
              value: autoLockChoices.contains(widget.session.autoLockDelay)
                  ? widget.session.autoLockDelay
                  : autoLockChoices[2],
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
            key: const Key('export'),
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Exporter le coffre'),
            subtitle: const Text(
              'Fichier chiffré: inutilisable sans le mot de passe. '
              'Les pièces jointes ne sont pas incluses',
            ),
            enabled: transferDisponible && !_busy,
            onTap: _export,
          ),
          ListTile(
            key: const Key('import'),
            leading: const Icon(Icons.download_outlined),
            title: const Text('Importer un coffre'),
            subtitle: const Text('Remplace le coffre actuel après vérification'),
            enabled: transferDisponible && !_busy,
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
      setState(
        () => _error =
            'Au moins $minMasterPasswordLength caractères',
      );
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
