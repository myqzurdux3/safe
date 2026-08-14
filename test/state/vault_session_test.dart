import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/crypto/vault_crypto.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/storage/blob_store.dart';
import 'package:safe/storage/vault_file.dart';
import 'package:safe/util/clipboard.dart';
import 'package:sodium/sodium_sumo.dart';

/// Paramètres faibles: ces tests vérifient la machine à états, pas le KDF.
const testParams = KdfParams(opsLimit: 1, memLimit: 8 * 1024 * 1024);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VaultCrypto crypto;
  late Directory dir;

  setUpAll(() async {
    crypto = VaultCrypto(await SodiumSumoInit.init());
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('safe_session');
  });

  tearDown(() async => dir.delete(recursive: true));

  VaultSession makeSession({Duration? autoLock}) => VaultSession(
    crypto: crypto,
    storage: VaultFile(dir),
    blobs: BlobFileStore(Directory('${dir.path}/blobs')),
    clipboard: SecureClipboard(),
    autoLockDelay: autoLock ?? const Duration(minutes: 2),
    kdfParams: testParams,
  );

  test('coffre absent puis présent après création', () async {
    final session = makeSession();
    expect(await session.vaultExists(), isFalse);
    await session.create('motdepasse123');
    expect(await session.vaultExists(), isTrue);
    expect(session.isUnlocked, isTrue);
    expect(session.vault!.entries, isEmpty);
  });

  test('verrouillage puis déverrouillage', () async {
    final session = makeSession();
    await session.create('motdepasse123');
    session.lock();
    expect(session.isUnlocked, isFalse);
    expect(session.vault, isNull);
    await session.unlock('motdepasse123');
    expect(session.isUnlocked, isTrue);
  });

  test('mauvais mot de passe laisse la session verrouillée', () async {
    final session = makeSession();
    await session.create('motdepasse123');
    session.lock();
    await expectLater(
      session.unlock('faux'),
      throwsA(isA<WrongPasswordException>()),
    );
    expect(session.isUnlocked, isFalse);
  });

  test('les entrées survivent à un cycle verrou/déverrouillage', () async {
    final session = makeSession();
    await session.create('motdepasse123');
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: 'gmail', value: 'p4ss')),
    );
    session.lock();
    await session.unlock('motdepasse123');
    expect(session.vault!.entries.single.value, 'p4ss');
  });

  test('la minuterie verrouille après le délai', () async {
    final session = makeSession(autoLock: const Duration(milliseconds: 50));
    await session.create('motdepasse123');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(session.isUnlocked, isFalse);
  });

  test('touch repousse le verrouillage', () async {
    final session = makeSession(autoLock: const Duration(milliseconds: 120));
    await session.create('motdepasse123');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    session.touch();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(session.isUnlocked, isTrue);
  });

  test('arrière-plan verrouille immédiatement', () async {
    final session = makeSession();
    await session.create('motdepasse123');
    session.handleLifecycle(AppLifecycleState.paused);
    expect(session.isUnlocked, isFalse);
  });

  test('le retour au premier plan ne déverrouille pas', () async {
    final session = makeSession();
    await session.create('motdepasse123');
    session.handleLifecycle(AppLifecycleState.paused);
    session.handleLifecycle(AppLifecycleState.resumed);
    expect(session.isUnlocked, isFalse);
  });

  test('changement de mot de passe: ancien invalide, nouveau valide', () async {
    final session = makeSession();
    await session.create('motdepasse123');
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: 'a', value: 'v')),
    );
    await session.changePassword('nouveaumotdepasse');
    session.lock();
    await expectLater(
      session.unlock('motdepasse123'),
      throwsA(isA<WrongPasswordException>()),
    );
    await session.unlock('nouveaumotdepasse');
    expect(session.vault!.entries.single.value, 'v');
  });

  test('sauvegarder sans être déverrouillé est une erreur', () async {
    final session = makeSession();
    expect(() => session.save(const Vault([])), throwsStateError);
  });

  test('la session prévient ses auditeurs à chaque transition', () async {
    final session = makeSession();
    var notifications = 0;
    session.addListener(() => notifications++);
    await session.create('motdepasse123');
    session.lock();
    expect(notifications, greaterThanOrEqualTo(2));
  });
}
