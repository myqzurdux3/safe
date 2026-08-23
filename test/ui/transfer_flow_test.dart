import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/storage/vault_transfer.dart';
import 'package:safe/ui/settings_screen.dart';

import '../support/crypto_fixture.dart';
import '../support/fake_file_selector.dart';
import '../support/session_fixture.dart';

void main() {
  late FakeFileSelector selector;
  late Directory scratch;

  setUp(() async {
    selector = FakeFileSelector();
    FileSelectorPlatform.instance = selector;
    scratch = await Directory.systemTemp.createTemp('safe_transfert');
  });

  tearDown(() async => scratch.delete(recursive: true));

  testWidgets('exporter écrit le coffre chiffré, et le dit', (tester) async {
    final store = MemoryVaultStore();
    final session = await makeUnlockedSession(store: store, keys: ['gmail']);
    final transfer = VaultTransfer(crypto: await testCrypto(), storage: store);
    final destination = '${scratch.path}/vault.safe';
    selector.saveTo = destination;

    await tester.pumpWidget(
      wrapScreen(
        SettingsScreen(session: session, settings: null, transfer: transfer),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('export')));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    final octets = File(destination).readAsBytesSync();
    // Le fichier exporté est le coffre tel quel: chiffré, et il ne contient
    // pas la clef en clair.
    expect(String.fromCharCodes(octets.take(8)), 'SAFEVLT1');
    expect(String.fromCharCodes(octets), isNot(contains('gmail')));
    expect(find.textContaining('Coffre exporté'), findsOneWidget);
    session.lock();
  });

  testWidgets('annuler l\'export n\'écrit rien', (tester) async {
    final store = MemoryVaultStore();
    final session = await makeUnlockedSession(store: store);
    final transfer = VaultTransfer(crypto: await testCrypto(), storage: store);
    selector.saveTo = null;

    await tester.pumpWidget(
      wrapScreen(
        SettingsScreen(session: session, settings: null, transfer: transfer),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export')));
    await tester.pumpAndSettle();

    expect(selector.saveCount, 1);
    expect(scratch.listSync(), isEmpty);
    session.lock();
  });

  testWidgets('importer un coffre étranger le vérifie, puis verrouille', (
    tester,
  ) async {
    // Un coffre venu d'ailleurs, avec son propre mot de passe.
    final crypto = await testCrypto();
    final etranger = crypto.sealWithPassword(
      Vault([VaultEntry.now(key: 'banque', value: 's3cret')]),
      'motdepasseetranger',
      params: testKdfParams,
    );
    selector.fileToOpen = XFile.fromData(etranger, name: 'autre.safe');

    final store = MemoryVaultStore();
    final session = await makeUnlockedSession(store: store, keys: ['gmail']);
    final transfer = VaultTransfer(crypto: crypto, storage: store);

    await tester.pumpWidget(
      wrapScreen(
        SettingsScreen(session: session, settings: null, transfer: transfer),
      ),
    );
    await tester.pumpAndSettle();

    // L'écran a gagné une ligne (« Langue ») et « Importer » tombe sous le
    // bord des 600 px de la surface de test: sans ce défilement, la tape
    // atterrit dans le vide et la boîte de mot de passe ne s'ouvre jamais.
    await tester.ensureVisible(find.byKey(const Key('import')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('import')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('import-password')),
      'motdepasseetranger',
    );
    await tester.tap(find.byKey(const Key('confirm-import')));
    await tester.pumpAndSettle();

    // Le coffre importé a son propre mot de passe: rester ouvert avec la clé
    // de l'ancien n'aurait aucun sens.
    expect(session.isUnlocked, isFalse);
    await session.unlock('motdepasseetranger');
    expect(session.vault!.entries.single.key, 'banque');
    session.lock();
  });

  testWidgets('un mauvais mot de passe laisse le coffre existant intact', (
    tester,
  ) async {
    final crypto = await testCrypto();
    final etranger = crypto.sealWithPassword(
      Vault([VaultEntry.now(key: 'banque', value: 's3cret')]),
      'motdepasseetranger',
      params: testKdfParams,
    );
    selector.fileToOpen = XFile.fromData(etranger, name: 'autre.safe');

    final store = MemoryVaultStore();
    final session = await makeUnlockedSession(store: store, keys: ['gmail']);
    final transfer = VaultTransfer(crypto: crypto, storage: store);

    await tester.pumpWidget(
      wrapScreen(
        SettingsScreen(session: session, settings: null, transfer: transfer),
      ),
    );
    await tester.pumpAndSettle();
    // L'écran a gagné une ligne (« Langue ») et « Importer » tombe sous le
    // bord des 600 px de la surface de test: sans ce défilement, la tape
    // atterrit dans le vide et la boîte de mot de passe ne s'ouvre jamais.
    await tester.ensureVisible(find.byKey(const Key('import')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('import')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('import-password')),
      'paslebonmotdepasse',
    );
    await tester.tap(find.byKey(const Key('confirm-import')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Import refusé'), findsOneWidget);
    // La vérification a lieu avant toute écriture.
    expect(session.isUnlocked, isTrue);
    expect(session.vault!.entries.single.key, 'gmail');
    session.lock();
  });

  testWidgets('un fichier qui n\'est pas un coffre est reconnu comme tel', (
    tester,
  ) async {
    selector.fileToOpen = XFile.fromData(
      Uint8List.fromList(List.filled(200, 0x41)),
      name: 'photo.jpg',
    );

    final store = MemoryVaultStore();
    final session = await makeUnlockedSession(store: store, keys: ['gmail']);
    final transfer = VaultTransfer(crypto: await testCrypto(), storage: store);

    await tester.pumpWidget(
      wrapScreen(
        SettingsScreen(session: session, settings: null, transfer: transfer),
      ),
    );
    await tester.pumpAndSettle();
    // L'écran a gagné une ligne (« Langue ») et « Importer » tombe sous le
    // bord des 600 px de la surface de test: sans ce défilement, la tape
    // atterrit dans le vide et la boîte de mot de passe ne s'ouvre jamais.
    await tester.ensureVisible(find.byKey(const Key('import')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('import')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('import-password')), 'peu');
    await tester.tap(find.byKey(const Key('confirm-import')));
    await tester.pumpAndSettle();

    // Message distinct du mot de passe incorrect: ce n'est pas la même erreur.
    expect(find.textContaining('n\'est pas un coffre safe'), findsOneWidget);
    expect(session.isUnlocked, isTrue);
    session.lock();
  });

  testWidgets('annuler la saisie du mot de passe n\'importe rien', (
    tester,
  ) async {
    final crypto = await testCrypto();
    selector.fileToOpen = XFile.fromData(
      crypto.sealWithPassword(Vault.empty, 'x', params: testKdfParams),
      name: 'autre.safe',
    );
    final store = MemoryVaultStore();
    final session = await makeUnlockedSession(store: store, keys: ['gmail']);

    await tester.pumpWidget(
      wrapScreen(
        SettingsScreen(
          session: session,
          settings: null,
          transfer: VaultTransfer(crypto: crypto, storage: store),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // L'écran a gagné une ligne (« Langue ») et « Importer » tombe sous le
    // bord des 600 px de la surface de test: sans ce défilement, la tape
    // atterrit dans le vide et la boîte de mot de passe ne s'ouvre jamais.
    await tester.ensureVisible(find.byKey(const Key('import')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('import')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(session.isUnlocked, isTrue);
    expect(session.vault!.entries.single.key, 'gmail');
    session.lock();
  });

  testWidgets('sans transfert disponible, les deux entrées sont inertes', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(
      wrapScreen(SettingsScreen(session: session, settings: null)),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<ListTile>(find.byKey(const Key('export'))).enabled,
      isFalse,
    );
    expect(
      tester.widget<ListTile>(find.byKey(const Key('import'))).enabled,
      isFalse,
    );
    session.lock();
  });
}
