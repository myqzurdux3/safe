import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/storage/app_settings.dart';
import 'package:safe/main.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/storage/vault_transfer.dart';
import 'package:safe/util/clipboard.dart';

import '../support/session_fixture.dart';

/// Session qui compte les signaux d'activité reçus.
class _CountingSession extends VaultSession {
  _CountingSession({
    required super.crypto,
    required super.storage,
    required super.blobs,
    required super.clipboard,
    super.kdfParams,
  }) : super(autoLockDelay: const Duration(minutes: 10));

  int touches = 0;

  @override
  void touch() {
    touches++;
    super.touch();
  }
}

/// Les deux câblages de `main.dart` que rien ne gardait.
///
/// `SafeApp.build` et `_VaultGateState.didChangeAppLifecycleState` sont des
/// lignes de branchement: elles ne calculent rien, elles relient un événement
/// de la plateforme à une méthode de la session. La couverture les donnait à
/// zéro — la session, elle, est testée de près. Un branchement débranché ne
/// faisait donc tomber personne, alors que les deux tiennent le verrouillage
/// automatique.
void main() {
  testWidgets('une frappe au clavier compte comme une activité', (
    tester,
  ) async {
    final store = MemoryVaultStore();
    final session = _CountingSession(
      crypto: await testCrypto(),
      storage: store,
      blobs: MemoryBlobStore(),
      clipboard: SecureClipboard(),
      kdfParams: testKdfParams,
    );
    addTearDown(session.dispose);
    await session.create(testPassword);

    await tester.pumpWidget(
      SafeApp(
        session: session,
        transfer: VaultTransfer(crypto: await testCrypto(), storage: store),
        clipboard: SecureClipboard(),
        // Sans cela l'application suit la plateforme, que
        // `flutter_test` fixe à en_US: tout s'afficherait en anglais.
        language: ValueNotifier(AppLanguage.french),
      ),
    );
    await tester.pumpAndSettle();

    // Il faut un champ au focus: une frappe part du nœud focalisé et remonte.
    await tester.tap(find.byKey(const Key('search')));
    await tester.pumpAndSettle();

    // La tape vient de compter; on repart de zéro pour n'observer que la
    // frappe.
    session.touches = 0;
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pump();

    expect(
      session.touches,
      greaterThan(0),
      reason:
          'remplir une fiche au clavier sans toucher l\'écran laisserait le '
          'verrouillage automatique tomber sous les doigts, et la saisie non '
          'enregistrée avec lui',
    );

    session.lock();
  });

  testWidgets('le retour au premier plan après le délai verrouille le coffre', (
    tester,
  ) async {
    final store = MemoryVaultStore();
    final session = await makeUnlockedSession(
      store: store,
      autoLock: const Duration(milliseconds: 200),
    );

    await tester.pumpWidget(
      SafeApp(
        session: session,
        transfer: VaultTransfer(crypto: await testCrypto(), storage: store),
        clipboard: SecureClipboard(),
        // Sans cela l'application suit la plateforme, que
        // `flutter_test` fixe à en_US: tout s'afficherait en anglais.
        language: ValueNotifier(AppLanguage.french),
      ),
    );
    await tester.pumpAndSettle();
    expect(session.isUnlocked, isTrue);

    // La chaîne complète: le framework refuse les sauts d'état.
    for (final etat in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(etat);
    }

    // Temps RÉEL: la minuterie de verrouillage vit sous l'horloge simulée du
    // test et ne se déclenchera pas toute seule ici. Ce qui verrouille, c'est
    // donc bien le recalcul d'inactivité au retour — celui qui rattrape un
    // processus gelé par Android — et rien d'autre.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    expect(
      session.isUnlocked,
      isTrue,
      reason: 'la minuterie simulée ne doit pas avoir verrouillé d\'elle-même',
    );

    for (final etat in const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(etat);
    }
    await tester.pump();

    expect(
      session.isUnlocked,
      isFalse,
      reason:
          'sans ce câblage, un coffre laissé en arrière-plan pendant que le '
          'processus est gelé revient ouvert',
    );
  });
}
