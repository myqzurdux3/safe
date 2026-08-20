import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/ui/generator_tab.dart';
import 'package:safe/ui/home_screen.dart';
import 'package:safe/ui/theme/safe_theme.dart';
import 'package:safe/ui/widgets/pill_tabs.dart';
import 'package:safe/util/clipboard.dart';

import '../support/session_fixture.dart';

Widget _accueil(VaultSession session) => MaterialApp(
  theme: safeLightTheme(),
  home: HomeScreen(session: session, settings: MemorySettingsStore()),
);

/// Une session qui laisse voir combien d'auditeurs lui restent.
///
/// Le générateur de l'accueil s'abonne à la session pour vider son historique
/// au verrouillage. C'est le seul moyen, depuis l'extérieur, de constater
/// qu'il a bien été construit puis libéré: l'accueil le garde privé.
///
/// Compter, et pas seulement constater qu'il reste quelqu'un: l'onglet Coffre
/// s'abonne lui aussi, et `hasListeners` seul reste vrai même si le générateur
/// n'existe pas encore.
class _ObservedSession extends VaultSession {
  _ObservedSession({
    required super.crypto,
    required super.storage,
    required super.blobs,
    required super.clipboard,
    required super.kdfParams,
  });

  int watchers = 0;

  @override
  void addListener(VoidCallback listener) {
    watchers++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    watchers--;
    super.removeListener(listener);
  }

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

    // Deux auditeurs, et pas un: l'onglet Coffre en pose un, le générateur
    // l'autre. Le compte est ce qui distingue les deux — `hasListeners` seul
    // resterait vrai si le générateur n'était construit qu'à l'ouverture de
    // son onglet, et un abonnement pris paresseusement laisserait passer le
    // verrouillage qui le précède: la valeur déjà tirée survivrait au verrou.
    expect(
      session.watchers,
      2,
      reason:
          'le générateur doit être construit dès le montage, sans attendre '
          "qu'on ouvre son onglet",
    );

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

  testWidgets(
    'le cadenas de l\'en-tête verrouille, et emporte l\'historique du générateur',
    (tester) async {
      final session = await makeUnlockedSession(keys: ['gmail']);
      await tester.pumpWidget(_accueil(session));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Générateur'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('regenerate')));
      await tester.pumpAndSettle();

      // La session du générateur elle-même, et non ce que l'écran en montre:
      // ce qu'il faut voir vide, c'est la mémoire — une liste qui disparaît de
      // l'arbre prouve seulement que l'écran a changé.
      final generator = tester
          .widget<GeneratorTab>(find.byType(GeneratorTab))
          .generator;
      expect(session.isUnlocked, isTrue);
      expect(generator.value, isNotEmpty);
      expect(generator.history, isNotEmpty);

      await tester.tap(find.byKey(const Key('header-lock')));
      await tester.pumpAndSettle();

      expect(
        session.isUnlocked,
        isFalse,
        reason: 'le cadenas de l\'accueil doit fermer la session',
      );
      expect(
        generator.history,
        isEmpty,
        reason: 'les valeurs précédentes ont survécu au verrouillage',
      );
      expect(
        generator.value,
        isEmpty,
        reason: 'la valeur affichée a survécu au verrouillage',
      );
    },
  );

  testWidgets(
    'les deux commandes de l\'en-tête font un doigt chacune, sans se marcher dessus',
    (tester) async {
      final session = await makeUnlockedSession();
      await tester.pumpWidget(_accueil(session));
      await tester.pumpAndSettle();

      final cadenas = tester.getRect(find.byKey(const Key('header-lock')));
      final reglages = tester.getRect(find.byKey(const Key('settings')));

      const doigt = Size(SafeMetrics.touchTarget, SafeMetrics.touchTarget);
      expect(cadenas.size, doigt);
      expect(reglages.size, doigt);
      expect(cadenas.right, lessThanOrEqualTo(reglages.left));

      // L'en-tête ne pèse toujours qu'une seule cible tactile: la barre
      // d'onglets n'a pas reculé d'un pixel en lui ajoutant le cadenas.
      expect(
        tester.getTopLeft(find.byType(SafePillTabs)).dy,
        7.5 + SafeMetrics.touchTarget,
        reason: 'l\'en-tête a grandi et pousse tout l\'écran vers le bas',
      );

      // Les rectangles de mise en page ne prouvent pas le doigt: dans une Row,
      // deux enfants ne peuvent pas se recouvrir, et un dessin de 21 px logé
      // au centre d'une boîte de 48 laisserait les bords muets. On tape donc
      // aux quatre bords, et on regarde la session.
      for (final bord in <Offset>[
        cadenas.centerLeft + const Offset(1, 0),
        cadenas.centerRight - const Offset(1, 0),
        cadenas.topCenter + const Offset(0, 1),
        cadenas.bottomCenter - const Offset(0, 1),
      ]) {
        await session.unlock(testPassword);
        await tester.pumpAndSettle();
        expect(session.isUnlocked, isTrue);

        await tester.tapAt(bord);
        await tester.pumpAndSettle();
        expect(
          session.isUnlocked,
          isFalse,
          reason: 'le cadenas ne répond pas en $bord',
        );
      }

      // Et la cible voisine n'a pas été avalée: la commande des réglages
      // ouvre les réglages, elle ne verrouille pas.
      await session.unlock(testPassword);
      await tester.pumpAndSettle();
      await tester.tapAt(reglages.center);
      await tester.pumpAndSettle();
      expect(session.isUnlocked, isTrue);
      expect(find.text('Réglages'), findsOneWidget);
      session.lock();
    },
  );

  testWidgets('coffre vide: une invite, pas une liste blanche', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_accueil(session));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aucune'), findsOneWidget);
    session.lock();
  });
}
