import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sodium/sodium_sumo.dart';

import 'crypto/vault_crypto.dart';
import 'state/vault_session.dart';
import 'storage/app_settings.dart';
import 'storage/blob_store.dart';
import 'storage/private_directory.dart';
import 'storage/vault_file.dart';
import 'storage/vault_transfer.dart';
import 'ui/entries_screen.dart';
import 'ui/theme/safe_theme.dart';
import 'ui/unlock_screen.dart';
import 'util/clipboard.dart';
import 'util/screen_security.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sodium = await SodiumSumoInit.init();
  final crypto = VaultCrypto(sodium);
  final directory = await VaultFile.defaultDirectory();
  // Au démarrage et pas seulement à la première écriture: une installation
  // antérieure au resserrement des droits resterait sinon ouverte aux autres
  // comptes jusqu'à la prochaine sauvegarde.
  await createPrivateDirectory(directory);
  final storage = VaultFile(directory);
  final blobs = BlobFileStore(Directory('${directory.path}/blobs'));
  final clipboard = SecureClipboard();

  // Réglages lus avant de construire quoi que ce soit: le délai de
  // verrouillage doit être le bon dès la première seconde.
  final settings = SettingsFile(directory);
  final loaded = await settings.read();

  // Le natif démarre en mode bloqué; on ne le relâche que si l'utilisateur l'a
  // explicitement demandé.
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
        autoLockDelay: loaded.autoLockDelay,
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
    // Le détecteur d'activité est posé ici, et non dans `VaultGate`: `home:`
    // est *à l'intérieur* de la première route du `Navigator`, alors que les
    // écrans empilés — édition, réglages, dialogues, générateur, visionneuse —
    // en sont des frères dans l'`Overlay`. Un détecteur placé plus bas ne
    // voyait donc rien de ce qui s'y passait, et le coffre se verrouillait
    // sous les doigts. `builder` enveloppe le `Navigator` entier.
    builder: (context, child) => Focus(
      canRequestFocus: false,
      // Les frappes remontent jusqu'ici depuis le champ qui a le focus:
      // clavier matériel comme logiciel, toute frappe vaut activité.
      onKeyEvent: (_, _) {
        session.touch();
        return KeyEventResult.ignored;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => session.touch(),
        onPointerSignal: (_) => session.touch(),
        child: child ?? const SizedBox.shrink(),
      ),
    ),
    theme: safeLightTheme(),
    // Clair uniquement: voir la note de safe_theme.dart et la section « ce qui
    // n'est pas fait » de la spec.
    themeMode: ThemeMode.light,
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
/// C'est ici que passe le cycle de vie de l'application. Les signaux
/// d'activité, eux, sont captés plus haut, au-dessus du `Navigator`.
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
  late bool _etaitOuvert = widget.session.isUnlocked;

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
    final unlocked = widget.session.isUnlocked;
    final justLocked = _etaitOuvert && !unlocked;
    _etaitOuvert = unlocked;

    if (!unlocked) {
      // Un écran empilé (fiche, création, réglages) survivrait au verrouillage
      // et resterait affiché par-dessus l'écran de verrou: on le dépile. Après
      // la frame, pour que les écrans concernés aient d'abord pu réagir au
      // verrouillage — la fiche et la création effacent leur saisie à ce
      // moment-là, et c'est le clair à l'écran que ce délai fait disparaître,
      // pas un obstacle au dépilement: `popUntil` ne consulte pas `PopScope`.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final navigator = Navigator.maybeOf(context);
        if (navigator != null && navigator.canPop()) {
          navigator.popUntil((route) => route.isFirst);
        }
      });
    }

    if (justLocked) {
      // Relu seulement ici: cette valeur ne sert qu'à l'écran de verrou, et la
      // relire à chaque notification faisait un accès disque par sauvegarde,
      // plus une reconstruction complète de la liste par-dessus la sienne.
      //
      // Corps en bloc, pas en flèche: une lambda en flèche rend la valeur
      // assignée, donc un Future, ce que setState refuse.
      final exists = widget.session.vaultExists();
      setState(() {
        _vaultExists = exists;
      });
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.session.isUnlocked
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
        );
}
