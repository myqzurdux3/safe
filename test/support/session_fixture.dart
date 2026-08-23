import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/crypto/vault_crypto.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/storage/app_settings.dart';
import 'package:safe/storage/blob_store.dart';
import 'package:safe/storage/vault_store.dart';
import 'package:safe/ui/theme/safe_theme.dart';
import 'package:safe/util/clipboard.dart';
import 'package:sodium/sodium_sumo.dart';

/// Paramètres Argon2id volontairement faibles: les tests d'interface ne
/// mesurent pas la résistance du KDF, et les vrais paramètres rendraient chaque
/// `pumpWidget` inutilement lent.
const testKdfParams = KdfParams(opsLimit: 1, memLimit: 8 * 1024 * 1024);

/// Mot de passe utilisé par toutes les sessions de test.
const testPassword = 'motdepasse123';

/// Coffre en mémoire.
///
/// Les tests de widgets tournent sous une horloge simulée où les entrées/
/// sorties réelles ne se terminent jamais: le disque est remplacé ici, et
/// [VaultFile] garde ses propres tests, sur de vrais fichiers.
class MemoryVaultStore implements VaultStore {
  Uint8List? _bytes;
  Uint8List? _previous;

  @override
  Future<bool> exists() async => _bytes != null;

  @override
  Future<Uint8List> read() async {
    final bytes = _bytes;
    if (bytes == null) {
      throw StateError('Aucun coffre en mémoire');
    }
    return bytes;
  }

  @override
  Future<Uint8List?> readPrevious() async => _previous;

  @override
  Future<void> write(Uint8List bytes, {bool keepPrevious = true}) async {
    _previous = keepPrevious ? _bytes : null;
    _bytes = bytes;
  }
}

/// Coffre en mémoire dont l'écriture peut être suspendue.
///
/// Sert à observer ce qui arrive quand quelque chose se produit *pendant*
/// qu'une sauvegarde est en vol: verrouillage, seconde sauvegarde, arrêt.
class GatedVaultStore implements VaultStore {
  final inner = MemoryVaultStore();

  /// Écritures suspendues tant que ce jeton n'est pas complété.
  Completer<void>? gate;

  /// Ordre d'arrivée des écritures, pour vérifier la sérialisation.
  final List<int> writeOrder = [];
  int _next = 0;

  @override
  Future<bool> exists() => inner.exists();

  @override
  Future<Uint8List> read() => inner.read();

  @override
  Future<Uint8List?> readPrevious() => inner.readPrevious();

  @override
  Future<void> write(Uint8List bytes, {bool keepPrevious = true}) async {
    final me = _next++;
    writeOrder.add(me);
    final waiting = gate;
    if (waiting != null) {
      await waiting.future;
    }
    return inner.write(bytes, keepPrevious: keepPrevious);
  }
}

/// Pièces jointes en mémoire, même raison que [MemoryVaultStore].
class MemoryBlobStore implements BlobStore {
  final Map<String, Uint8List> contents = {};

  @override
  Future<void> put(String id, Uint8List bytes) async => contents[id] = bytes;

  @override
  Future<Uint8List> get(String id) async {
    final bytes = contents[id];
    if (bytes == null) {
      throw StateError('Pièce jointe absente: $id');
    }
    return bytes;
  }

  @override
  Future<void> delete(String id) async => contents.remove(id);

  /// Orphelins mis de côté, comme le fait le vrai magasin sur le disque.
  final Map<String, Uint8List> quarantined = {};

  @override
  Future<void> quarantine(String id) async {
    final bytes = contents.remove(id);
    if (bytes != null) {
      quarantined[id] = bytes;
    }
  }

  @override
  Future<int> sweepTemporaries() async => 0;

  @override
  Future<Set<String>> ids() async => contents.keys.toSet();
}

/// Réglages gardés en mémoire, même raison que [MemoryVaultStore].
class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([this._settings = const AppSettings()]);

  AppSettings _settings;

  @override
  Future<AppSettings> read() async => _settings;

  @override
  Future<void> write(AppSettings settings) async => _settings = settings;
}

VaultCrypto? _crypto;

/// Initialise libsodium une seule fois pour toute la suite.
/// `useIsolate: false`: les tests de widgets tournent sous une horloge simulée
/// où un isolat ne rend jamais sa réponse. Le chemin isolat a ses propres tests,
/// dans `test/crypto/derive_isolate_test.dart`.
Future<VaultCrypto> testCrypto() async =>
    _crypto ??= VaultCrypto(await SodiumSumoInit.init(), useIsolate: false);

/// Une session adossée à un coffre en mémoire.
///
/// La session est libérée en fin de test: sans cela, la minuterie d'auto-lock
/// resterait en attente et ferait échouer le test suivant.
Future<VaultSession> makeTestSession({
  MemoryVaultStore? store,
  MemoryBlobStore? blobs,
  Duration autoLock = const Duration(minutes: 10),
}) async {
  final session = VaultSession(
    crypto: await testCrypto(),
    storage: store ?? MemoryVaultStore(),
    blobs: blobs ?? MemoryBlobStore(),
    clipboard: SecureClipboard(),
    autoLockDelay: autoLock,
    kdfParams: testKdfParams,
  );
  addTearDown(session.dispose);
  return session;
}

/// Une session déjà déverrouillée, contenant [keys].
Future<VaultSession> makeUnlockedSession({
  List<String> keys = const [],
  MemoryVaultStore? store,
  MemoryBlobStore? blobs,
  Duration autoLock = const Duration(minutes: 10),
}) async {
  final session = await makeTestSession(
    store: store,
    blobs: blobs,
    autoLock: autoLock,
  );
  await session.create(testPassword);
  for (final key in keys) {
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: key, value: 'p4ss-$key')),
    );
  }
  return session;
}

/// Enveloppe un écran dans le minimum de matériel Flutter.
Widget wrapScreen(Widget child) =>
    MaterialApp(theme: safeLightTheme(), home: child);
