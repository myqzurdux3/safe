import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/main.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/storage/vault_transfer.dart';
import 'package:safe/util/clipboard.dart';

import '../support/session_fixture.dart';

/// Monte l'application entière: le retour arrière et le dépilement au
/// verrouillage passent tous deux par le `Navigator`, qu'un écran seul n'a pas.
Future<VaultSession> monter(WidgetTester tester, MemoryVaultStore store) async {
  final session = await makeUnlockedSession(store: store, keys: ['gmail']);
  await tester.pumpWidget(
    SafeApp(
      session: session,
      transfer: VaultTransfer(crypto: await testCrypto(), storage: store),
      clipboard: SecureClipboard(),
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

void main() {
  testWidgets('quitter une saisie en cours demande confirmation', (
    tester,
  ) async {
    final session = await monter(tester, MemoryVaultStore());

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('key')), 'banque');
    await tester.pumpAndSettle();

    // Retour arrière: la saisie ne doit pas partir sans un mot.
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Abandonner les modifications ?'), findsOneWidget);
    expect(find.byKey(const Key('key')), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-discard')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('key')), findsNothing);
    session.lock();
  });

  testWidgets('sans modification, le retour arrière ne demande rien', (
    tester,
  ) async {
    final session = await monter(tester, MemoryVaultStore());

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Abandonner les modifications ?'), findsNothing);
    expect(find.byKey(const Key('key')), findsNothing);
    session.lock();
  });

  testWidgets('le verrouillage ferme l\'écran malgré la saisie en cours', (
    tester,
  ) async {
    final session = await monter(tester, MemoryVaultStore());

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('value')), 'secret-en-clair');
    await tester.pumpAndSettle();

    session.lock();
    await tester.pumpAndSettle();

    // La confirmation ne doit surtout pas retenir l'écran: son contenu en clair
    // resterait affiché par-dessus l'écran de verrou.
    expect(find.text('Abandonner les modifications ?'), findsNothing);
    expect(find.byKey(const Key('value')), findsNothing);
    expect(find.text('secret-en-clair'), findsNothing);
  });
}
