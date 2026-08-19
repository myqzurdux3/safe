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

/// Le retour de la nouvelle fiche est un contrôle propre à l'écran, pas la
/// flèche d'une `AppBar`: `pageBack` ne le trouverait pas.
Future<void> retourner(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('quitter une saisie en cours demande confirmation', (
    tester,
  ) async {
    final session = await monter(tester, MemoryVaultStore());

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name')), 'banque');
    await tester.pumpAndSettle();

    // Retour arrière: la saisie ne doit pas partir sans un mot.
    await retourner(tester);

    expect(find.text('Abandonner les modifications ?'), findsOneWidget);
    expect(find.byKey(const Key('name')), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-discard')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('name')), findsNothing);
    session.lock();
  });

  testWidgets('sans modification, le retour arrière ne demande rien', (
    tester,
  ) async {
    final session = await monter(tester, MemoryVaultStore());

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await retourner(tester);

    expect(find.text('Abandonner les modifications ?'), findsNothing);
    expect(find.byKey(const Key('name')), findsNothing);
    session.lock();
  });

  testWidgets('le verrouillage ferme l\'écran malgré la saisie en cours', (
    tester,
  ) async {
    final session = await monter(tester, MemoryVaultStore());

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('raw')), 'secret-en-clair');
    await tester.pumpAndSettle();

    session.lock();
    await tester.pumpAndSettle();

    // La confirmation ne doit surtout pas retenir l'écran: son contenu en clair
    // resterait affiché par-dessus l'écran de verrou.
    expect(find.text('Abandonner les modifications ?'), findsNothing);
    expect(find.byKey(const Key('raw')), findsNothing);
    expect(find.text('secret-en-clair'), findsNothing);
  });

  testWidgets('enregistrer sort de l\'écran sans rien demander', (
    tester,
  ) async {
    final session = await monter(tester, MemoryVaultStore());

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name')), 'banque');
    await tester.enterText(find.byKey(const Key('raw')), 'courrier:\nsecret');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // La garde de sortie ne doit pas se déclencher sur un enregistrement: la
    // saisie n'est plus « en cours », elle est au coffre.
    expect(find.text('Abandonner les modifications ?'), findsNothing);
    expect(find.byKey(const Key('name')), findsNothing);
    expect(session.vault!.entries.map((e) => e.key), contains('banque'));
    session.lock();
  });
}
