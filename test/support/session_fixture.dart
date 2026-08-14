import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/crypto/vault_crypto.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/storage/vault_store.dart';
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
  Future<void> write(Uint8List bytes) async => _bytes = bytes;
}

VaultCrypto? _crypto;

/// Initialise libsodium une seule fois pour toute la suite.
Future<VaultCrypto> testCrypto() async =>
    _crypto ??= VaultCrypto(await SodiumSumoInit.init());

/// Une session adossée à un coffre en mémoire.
///
/// La session est libérée en fin de test: sans cela, la minuterie d'auto-lock
/// resterait en attente et ferait échouer le test suivant.
Future<VaultSession> makeTestSession({
  MemoryVaultStore? store,
  Duration autoLock = const Duration(minutes: 10),
}) async {
  final session = VaultSession(
    crypto: await testCrypto(),
    storage: store ?? MemoryVaultStore(),
    clipboard: SecureClipboard(),
    autoLockDelay: autoLock,
    kdfParams: testKdfParams,
  );
  addTearDown(session.dispose);
  return session;
}

/// Une session déjà déverrouillée, contenant [keys].
Future<VaultSession> makeUnlockedSession({List<String> keys = const []}) async {
  final session = await makeTestSession();
  await session.create(testPassword);
  for (final key in keys) {
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: key, value: 'p4ss-$key')),
    );
  }
  return session;
}

/// Enveloppe un écran dans le minimum de matériel Flutter.
Widget wrapScreen(Widget child) => MaterialApp(home: child);
