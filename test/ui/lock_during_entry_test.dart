import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/main.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/storage/vault_transfer.dart';
import 'package:safe/ui/entry_screen.dart';
import 'package:safe/ui/unlock_screen.dart';
import 'package:safe/util/clipboard.dart';

import '../support/session_fixture.dart';

/// Monte l'application entière et ouvre la fiche « perso » depuis la liste.
///
/// Un écran monté seul n'a pas de pile de routes: ni le dépilement au
/// verrouillage ni la garde de sortie ne s'y observent. C'est pourtant là que
/// vivait le défaut que ces tests protègent.
Future<VaultSession> ouvrirLaFiche(WidgetTester tester) async {
  final store = MemoryVaultStore();
  final session = await makeUnlockedSession(store: store);
  await session.save(
    session.vault!.upsert(
      VaultEntry.now(key: 'perso', value: 'courrier:\nsecret-en-clair\n'),
    ),
  );
  await tester.pumpWidget(
    SafeApp(
      session: session,
      transfer: VaultTransfer(crypto: await testCrypto(), storage: store),
      clipboard: SecureClipboard(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('perso'));
  await tester.pumpAndSettle();
  expect(find.byType(EntryScreen), findsOneWidget);
  return session;
}

void main() {
  testWidgets('la liste ouvre la nouvelle fiche', (tester) async {
    final session = await ouvrirLaFiche(tester);
    expect(find.text('perso'), findsOneWidget);
    expect(find.text('1 bloc · 1 ligne'), findsOneWidget);
    expect(find.text('COURRIER'), findsOneWidget);
    expect(find.text('secret-en-clair'), findsNothing);
    session.lock();
    await tester.pumpAndSettle();
  });

  testWidgets('le verrouillage ferme la fiche restée ouverte', (tester) async {
    final session = await ouvrirLaFiche(tester);

    session.lock();
    await tester.pumpAndSettle();

    // Sans dépilage, la fiche resterait au-dessus de l'écran de verrou et son
    // contenu en clair avec elle.
    expect(find.byType(EntryScreen), findsNothing);
    expect(find.byType(UnlockScreen), findsOneWidget);
  });

  testWidgets('le verrouillage ferme la fiche malgré la saisie en cours', (
    tester,
  ) async {
    final session = await ouvrirLaFiche(tester);
    await tester.tap(find.text('Texte brut'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('raw')), 'autre:\nsecret-tapé');
    await tester.pumpAndSettle();

    session.lock();
    await tester.pumpAndSettle();

    // La confirmation d'abandon ne doit surtout pas retenir l'écran: son
    // contenu en clair resterait affiché par-dessus l'écran de verrou.
    expect(find.text('Abandonner les modifications ?'), findsNothing);
    expect(find.byType(EntryScreen), findsNothing);
    expect(find.text('secret-tapé'), findsNothing);
    expect(find.byType(UnlockScreen), findsOneWidget);
  });

  testWidgets('quitter une saisie en cours demande confirmation', (
    tester,
  ) async {
    final session = await ouvrirLaFiche(tester);
    await tester.tap(find.text('Texte brut'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('raw')), 'courrier:\nmodifié');
    await tester.pumpAndSettle();

    // Le retour de la fiche est un contrôle propre à l'écran, pas la flèche
    // d'une `AppBar`: c'est lui qu'il faut presser.
    await tester.tap(find.text('Coffre'));
    await tester.pumpAndSettle();

    expect(find.text('Abandonner les modifications ?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-discard')));
    await tester.pumpAndSettle();
    expect(find.byType(EntryScreen), findsNothing);
    session.lock();
    await tester.pumpAndSettle();
  });

  testWidgets('sans modification, le retour arrière ne demande rien', (
    tester,
  ) async {
    final session = await ouvrirLaFiche(tester);

    await tester.tap(find.text('Coffre'));
    await tester.pumpAndSettle();

    expect(find.text('Abandonner les modifications ?'), findsNothing);
    expect(find.byType(EntryScreen), findsNothing);
    session.lock();
    await tester.pumpAndSettle();
  });

  testWidgets('la frappe dans la fiche repousse le verrouillage', (
    tester,
  ) async {
    final session = await makeUnlockedSession(
      autoLock: const Duration(milliseconds: 200),
    );
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: 'perso', value: 'note')),
    );
    await tester.pumpWidget(
      wrapScreen(
        EntryScreen(session: session, entry: session.vault!.entries.first),
      ),
    );
    // Une image pour laisser atterrir la lecture des réglages: la barre de
    // mode ne s'affiche pas avant, pour ne pas se déplacer ensuite.
    await tester.pump();
    await tester.tap(find.text('Texte brut'));
    // Une seule image ici encore: `pumpAndSettle` laisserait filer l'animation
    // d'onglet, donc le délai d'inactivité, avant même la première frappe.
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(find.byKey(const Key('raw')), 'note m');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(find.byKey(const Key('raw')), 'note modifiée');
    await tester.pump(const Duration(milliseconds: 150));

    expect(
      session.isUnlocked,
      isTrue,
      reason: 'la frappe doit réarmer la minuterie',
    );
    session.lock();
  });
}
