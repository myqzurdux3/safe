import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sodium/sodium_sumo.dart';

import 'crypto/vault_crypto.dart';
import 'state/vault_session.dart';
import 'storage/app_settings.dart';
import 'storage/blob_store.dart';
import 'storage/vault_file.dart';
import 'storage/vault_transfer.dart';
import 'ui/entries_screen.dart';
import 'ui/unlock_screen.dart';
import 'util/clipboard.dart';
import 'util/screen_security.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sodium = await SodiumSumoInit.init();
  final crypto = VaultCrypto(sodium);
  final directory = await VaultFile.defaultDirectory();
  final storage = VaultFile(directory);
  final blobs = BlobFileStore(Directory('${directory.path}/blobs'));
  final clipboard = SecureClipboard();

  // Le natif démarre en mode bloqué; on ne le relâche que si l'utilisateur l'a
  // explicitement demandé, une fois les réglages lus.
  final settings = SettingsFile(directory);
  final loaded = await settings.read();
  if (!loaded.blockScreenshots) {
    await const ScreenSecurity().setBlocked(false);
  }

  runApp(
    SafeApp(
      session: VaultSession(
        crypto: crypto,
        storage: storage,
        blobs: blobs,
        clipboard: clipboard,
      ),
      transfer: VaultTransfer(crypto: crypto, storage: storage),
      clipboard: clipboard,
      settings: settings,
    ),
  );
}

class SafeApp extends StatelessWidget {
  const SafeApp({
    required this.session,
    required this.transfer,
    required this.clipboard,
    this.settings,
    super.key,
  });

  final VaultSession session;
  final VaultTransfer transfer;
  final SecureClipboard clipboard;
  final SettingsStore? settings;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'safe',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6F4E)),
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2F6F4E),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: VaultGate(
      session: session,
      transfer: transfer,
      clipboard: clipboard,
      settings: settings,
    ),
  );
}

/// Aiguillage entre l'écran de verrou et la liste, et point d'ancrage du
/// verrouillage automatique.
///
/// C'est ici que passent les deux signaux qui repoussent ou déclenchent le
/// verrouillage: les événements pointeur (activité) et le cycle de vie de
/// l'application (départ en arrière-plan).
class VaultGate extends StatefulWidget {
  const VaultGate({
    required this.session,
    required this.transfer,
    required this.clipboard,
    this.settings,
    super.key,
  });

  final VaultSession session;
  final VaultTransfer transfer;
  final SecureClipboard clipboard;
  final SettingsStore? settings;

  @override
  State<VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends State<VaultGate> with WidgetsBindingObserver {
  late Future<bool> _vaultExists;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.session.addListener(_onSessionChanged);
    _vaultExists = widget.session.vaultExists();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.session.handleLifecycle(state);
  }

  void _onSessionChanged() {
    if (!mounted) {
      return;
    }
    // Un écran empilé (édition, réglages) survivrait au verrouillage et
    // resterait affiché par-dessus l'écran de verrou: on le dépile.
    if (!widget.session.isUnlocked) {
      final navigator = Navigator.maybeOf(context);
      if (navigator != null && navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }
    }
    // Corps en bloc, pas en flèche: une lambda en flèche rend la valeur
    // assignée, donc un Future, ce que setState refuse.
    final exists = widget.session.vaultExists();
    setState(() {
      _vaultExists = exists;
    });
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    // Les frappes remontent jusqu'ici depuis le champ qui a le focus: clavier
    // matériel comme logiciel, toute frappe vaut activité.
    onKeyEvent: (_, _) {
      widget.session.touch();
      return KeyEventResult.ignored;
    },
    child: Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => widget.session.touch(),
      onPointerSignal: (_) => widget.session.touch(),
      child: widget.session.isUnlocked
        ? EntriesScreen(
            session: widget.session,
            clipboard: widget.clipboard,
            transfer: widget.transfer,
            settings: widget.settings,
          )
        : FutureBuilder<bool>(
            future: _vaultExists,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return UnlockScreen(
                session: widget.session,
                isCreation: !snapshot.data!,
                );
              },
            ),
    ),
  );
}
