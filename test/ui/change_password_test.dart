import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/crypto/vault_crypto.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/storage/vault_store.dart';
import 'package:safe/ui/settings_screen.dart';
import 'package:safe/ui/unlock_screen.dart';
import 'package:safe/util/clipboard.dart';

import '../support/session_fixture.dart';

/// Coffre dont l'écriture échoue, comme un disque plein.
class _FailingStore implements VaultStore {
  final inner = MemoryVaultStore();
  bool enPanne = false;

  @override
  Future<bool> exists() => inner.exists();

  @override
  Future<Uint8List> read() => inner.read();

  @override
  Future<Uint8List?> readPrevious() => inner.readPrevious();

  @override
  Future<void> write(Uint8List bytes, {bool keepPrevious = true}) {
    if (enPanne) {
      throw const FileSystemException('disque plein');
    }
    return inner.write(bytes, keepPrevious: keepPrevious);
  }
}

Future<void> ouvrirDialogue(WidgetTester tester, VaultSession session) async {
  await tester.pumpWidget(
    wrapScreen(SettingsScreen(session: session, settings: null)),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('change-password')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('un mot de passe trop court est refusé sans rien ré-chiffrer', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await ouvrirDialogue(tester, session);

    await tester.enterText(find.byKey(const Key('new-password')), 'court');
    await tester.enterText(find.byKey(const Key('new-confirm')), 'court');
    await tester.tap(find.byKey(const Key('confirm-change')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('$minMasterPasswordLength caractères'),
      findsOneWidget,
    );
    // Le dialogue reste ouvert: rien n'a été fait.
    expect(find.byKey(const Key('confirm-change')), findsOneWidget);
    session.lock();
  });

  testWidgets('deux saisies différentes sont refusées', (tester) async {
    final session = await makeUnlockedSession();
    await ouvrirDialogue(tester, session);

    await tester.enterText(
      find.byKey(const Key('new-password')),
      'unmotdepasseassezlong',
    );
    await tester.enterText(
      find.byKey(const Key('new-confirm')),
      'unmotdepassedifferent',
    );
    await tester.tap(find.byKey(const Key('confirm-change')));
    await tester.pumpAndSettle();

    expect(find.textContaining('ne correspondent pas'), findsOneWidget);
    session.lock();
  });

  testWidgets('annuler ne change pas le mot de passe', (tester) async {
    final store = MemoryVaultStore();
    final session = await makeUnlockedSession(store: store);
    await ouvrirDialogue(tester, session);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    // L'ancien mot de passe ouvre toujours le coffre.
    session.lock();
    await session.unlock(testPassword);
    expect(session.isUnlocked, isTrue);
    session.lock();
  });

  testWidgets('un changement réussi le dit, et l\'ancien n\'ouvre plus', (
    tester,
  ) async {
    final store = MemoryVaultStore();
    final session = await makeUnlockedSession(store: store);
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: 'gmail', value: 'p4ss')),
    );
    await ouvrirDialogue(tester, session);

    await tester.enterText(
      find.byKey(const Key('new-password')),
      'nouveaumotdepasse',
    );
    await tester.enterText(
      find.byKey(const Key('new-confirm')),
      'nouveaumotdepasse',
    );
    await tester.tap(find.byKey(const Key('confirm-change')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mot de passe maître changé'), findsOneWidget);

    session.lock();
    await expectLater(
      session.unlock(testPassword),
      throwsA(isA<WrongPasswordException>()),
    );
    await session.unlock('nouveaumotdepasse');
    expect(session.vault!.entries.single.key, 'gmail');
    session.lock();
  });

  testWidgets('un changement qui échoue le dit au lieu de se taire', (
    tester,
  ) async {
    final store = _FailingStore();
    final session = VaultSession(
      crypto: await testCrypto(),
      storage: store,
      blobs: MemoryBlobStore(),
      clipboard: SecureClipboard(),
      autoLockDelay: const Duration(minutes: 10),
      kdfParams: testKdfParams,
    );
    addTearDown(session.dispose);
    await session.create(testPassword);
    store.enPanne = true;

    await ouvrirDialogue(tester, session);
    await tester.enterText(
      find.byKey(const Key('new-password')),
      'nouveaumotdepasse',
    );
    await tester.enterText(
      find.byKey(const Key('new-confirm')),
      'nouveaumotdepasse',
    );
    await tester.tap(find.byKey(const Key('confirm-change')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Changement impossible'), findsOneWidget);
    session.lock();
  });
}
