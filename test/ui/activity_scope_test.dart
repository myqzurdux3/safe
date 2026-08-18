import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  testWidgets('un écran empilé compte comme de l\'activité', (tester) async {
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
      ),
    );
    await tester.pumpAndSettle();

    // Repère: une tape sur l'écran de base compte, ça a toujours marché.
    session.touches = 0;
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(session.touches, greaterThan(0));

    // L'écran d'édition est maintenant empilé par-dessus. Une tape dedans doit
    // compter elle aussi: sinon le coffre se verrouille sous les doigts de qui
    // remplit un formulaire sans taper au clavier.
    expect(find.byKey(const Key('key')), findsOneWidget);
    final avant = session.touches;
    await tester.tap(find.byKey(const Key('key')));
    await tester.pumpAndSettle();
    expect(
      session.touches,
      greaterThan(avant),
      reason: 'les événements des routes empilées n\'atteignent pas le détecteur',
    );

    session.lock();
  });
}
