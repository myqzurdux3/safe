import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/ui/home_screen.dart';
import 'package:safe/ui/theme/safe_theme.dart';
import 'package:safe/util/clipboard.dart';

import '../support/session_fixture.dart';

Widget _accueil(VaultSession session) => MaterialApp(
  theme: safeLightTheme(),
  home: HomeScreen(session: session, settings: MemorySettingsStore()),
);

/// Une session qui laisse voir s'il lui reste des auditeurs.
///
/// Le générateur de l'accueil s'abonne à la session pour vider son historique
/// au verrouillage. C'est le seul moyen, depuis l'extérieur, de constater
/// qu'il a bien été libéré: l'accueil le garde privé.
class _ObservedSession extends VaultSession {
  _ObservedSession({
    required super.crypto,
    required super.storage,
    required super.blobs,
    required super.clipboard,
    required super.kdfParams,
  });

  bool get stillWatched => hasListeners;
}

Future<_ObservedSession> _sessionObservee() async {
  final session = _ObservedSession(
    crypto: await testCrypto(),
    storage: MemoryVaultStore(),
    blobs: MemoryBlobStore(),
    clipboard: SecureClipboard(),
    kdfParams: testKdfParams,
  );
  addTearDown(session.dispose);
  await session.create(testPassword);
  return session;
}

void main() {
  testWidgets('les deux onglets sont là, Coffre d\'abord', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(_accueil(session));
    await tester.pumpAndSettle();

    expect(find.text('Coffre'), findsOneWidget);
    expect(find.text('Générateur'), findsOneWidget);
    expect(find.text('gmail'), findsOneWidget);
    session.lock();
  });

  testWidgets('l\'onglet Générateur montre une valeur et ses réglages', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_accueil(session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Générateur'));
    await tester.pumpAndSettle();

    expect(find.text('Copier'), findsOneWidget);
    expect(find.text('Lettres'), findsOneWidget);
    expect(find.text('+ chiffres'), findsOneWidget);
    expect(find.text('+ symboles'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    session.lock();
  });

  testWidgets('« Nouvelle fiche » est visible sur les deux onglets', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_accueil(session));
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle fiche'), findsOneWidget);
    await tester.tap(find.text('Générateur'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle fiche'), findsOneWidget);
    session.lock();
  });

  testWidgets('la recherche trouve un intertitre de bloc', (tester) async {
    final session = await makeUnlockedSession();
    await session.save(
      session.vault!.upsert(
        VaultEntry.now(key: 'comptes', value: 'courrier:\nvaleur'),
      ),
    );
    await tester.pumpWidget(_accueil(session));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search')), 'courri');
    await tester.pumpAndSettle();

    expect(find.text('comptes'), findsOneWidget);
    expect(find.textContaining('courrier'), findsWidgets);
    session.lock();
  });

  testWidgets('quitter l\'accueil libère le générateur', (tester) async {
    final session = await _sessionObservee();
    await tester.pumpWidget(_accueil(session));
    await tester.pumpAndSettle();

    // Il écoute: le générateur est construit dès le montage, sans attendre
    // qu'on ouvre son onglet.
    expect(session.stillWatched, isTrue);

    // Remplacer l'arbre démonte l'accueil, comme un retour à l'écran de
    // déverrouillage.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    // Le générateur appartient à l'accueil: personne d'autre ne le libérera,
    // et son auditeur survivrait à l'écran pour toute la durée de la session.
    expect(
      session.stillWatched,
      isFalse,
      reason: 'le générateur écoute encore la session après l\'accueil',
    );
    session.lock();
  });

  testWidgets('coffre vide: une invite, pas une liste blanche', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_accueil(session));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aucune'), findsOneWidget);
    session.lock();
  });
}
