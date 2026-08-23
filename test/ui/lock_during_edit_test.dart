import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/storage/app_settings.dart';
import 'package:safe/main.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/storage/vault_transfer.dart';
import 'package:safe/ui/vault_tab.dart';
import 'package:safe/ui/new_entry_screen.dart';
import 'package:safe/ui/unlock_screen.dart';
import 'package:safe/util/clipboard.dart';

import '../support/session_fixture.dart';

void main() {
  testWidgets('taper au clavier repousse le verrouillage automatique', (
    tester,
  ) async {
    // Sur un clavier logiciel, saisir des caractères rares demande de changer
    // de page: la frappe est la seule activité, et elle doit compter.
    final session = await makeUnlockedSession(
      autoLock: const Duration(milliseconds: 200),
    );
    await tester.pumpWidget(
      wrapScreen(
        NewEntryScreen(session: session, settings: MemorySettingsStore()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(find.byKey(const Key('name')), 'banque (');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(find.byKey(const Key('name')), 'banque (pro)');
    await tester.pump(const Duration(milliseconds: 150));

    expect(
      session.isUnlocked,
      isTrue,
      reason: 'la frappe doit réarmer la minuterie',
    );
    session.lock();
  });

  testWidgets(
    'enregistrer sur un coffre verrouillé le dit au lieu de se taire',
    (tester) async {
      final session = await makeUnlockedSession();
      await tester.pumpWidget(
        wrapScreen(
          NewEntryScreen(session: session, settings: MemorySettingsStore()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('name')), 'banque (pro)');
      await tester.enterText(find.byKey(const Key('raw')), 'secret');

      session.lock();
      await tester.pump();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('verrouillé'), findsOneWidget);
    },
  );

  testWidgets('le verrouillage ferme l\'écran de création resté ouvert', (
    tester,
  ) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(
      SafeApp(
        session: session,
        transfer: VaultTransfer(
          crypto: await testCrypto(),
          storage: MemoryVaultStore(),
        ),
        clipboard: SecureClipboard(),
        // Sans cela l'application suit la plateforme, que
        // `flutter_test` fixe à en_US: tout s'afficherait en anglais.
        language: ValueNotifier(AppLanguage.french),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add')));
    await tester.pumpAndSettle();
    expect(find.byType(NewEntryScreen), findsOneWidget);

    session.lock();
    await tester.pumpAndSettle();

    // Sans dépilage, l'écran resterait au-dessus de l'écran de verrou et
    // l'utilisateur taperait dans un formulaire mort.
    expect(find.byType(NewEntryScreen), findsNothing);
    expect(find.byType(UnlockScreen), findsOneWidget);
  });

  testWidgets('la recherche compte comme une activité', (tester) async {
    final session = await makeUnlockedSession(
      keys: ['gmail'],
      autoLock: const Duration(milliseconds: 200),
    );
    await tester.pumpWidget(
      wrapScreen(
        Scaffold(
          body: VaultTab(session: session, onOpen: (_) {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(find.byKey(const Key('search')), 'gm');
    await tester.pump(const Duration(milliseconds: 150));
    expect(session.isUnlocked, isTrue);
    session.lock();
  });

  test('sauvegarder après verrouillage lève, sans écrire à moitié', () async {
    final store = MemoryVaultStore();
    final session = await makeUnlockedSession(store: store);
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: 'banque (pro)', value: 'v')),
    );
    final avant = await store.read();
    session.lock();
    expect(() => session.save(Vault.empty), throwsStateError);
    expect(await store.read(), avant);
  });
}
