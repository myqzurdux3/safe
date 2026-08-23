import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/storage/vault_transfer.dart';
import 'package:safe/ui/settings_screen.dart';
import 'package:safe/util/file_saver.dart';

import '../support/session_fixture.dart';

/// Un enregistreur de fichiers qui note ce qu'on lui demande.
class _FauxEnregistreur implements FileSaver {
  _FauxEnregistreur({this.isSupported = true, this.rendu = 'vault.safe'});

  @override
  final bool isSupported;

  /// Ce que le sélecteur système est censé répondre; `null` = renoncé.
  final String? rendu;

  int appels = 0;
  String? nomDemande;
  Uint8List? octetsRecus;

  @override
  Future<String?> save({
    required String suggestedName,
    required Uint8List bytes,
  }) async {
    appels++;
    nomDemande = suggestedName;
    octetsRecus = bytes;
    return rendu;
  }
}

void main() {
  Future<VaultTransfer> transfertDe(store) async =>
      VaultTransfer(crypto: await testCrypto(), storage: store);

  testWidgets('là où le système sait enregistrer, l\'export laisse le choix', (
    tester,
  ) async {
    final store = MemoryVaultStore();
    final session = await makeUnlockedSession(store: store);
    final saver = _FauxEnregistreur();

    await tester.pumpWidget(
      wrapScreen(
        SettingsScreen(
          session: session,
          settings: null,
          transfer: await transfertDe(store),
          saver: saver,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export')));
    await tester.pumpAndSettle();

    // Partager n'est pas enregistrer: le partage passe le fichier à une autre
    // application, qui décide de ce qu'elle en fait. Une sauvegarde doit
    // pouvoir atterrir dans un dossier choisi, sans intermédiaire.
    expect(find.byKey(const Key('export-save')), findsOneWidget);
    expect(find.byKey(const Key('export-share')), findsOneWidget);
    session.lock();
  });

  testWidgets('« Enregistrer » passe les octets du coffre, pas autre chose', (
    tester,
  ) async {
    final store = MemoryVaultStore();
    final session = await makeUnlockedSession(store: store, keys: ['gmail']);
    final saver = _FauxEnregistreur();

    await tester.pumpWidget(
      wrapScreen(
        SettingsScreen(
          session: session,
          settings: null,
          transfer: await transfertDe(store),
          saver: saver,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-save')));
    await tester.pumpAndSettle();

    expect(saver.appels, 1);
    expect(saver.nomDemande, 'vault.safe');

    // Le coffre tel quel: l'en-tête du format, et pas la clef en clair.
    final octets = saver.octetsRecus!;
    expect(String.fromCharCodes(octets.take(8)), 'SAFEVLT1');
    expect(String.fromCharCodes(octets), isNot(contains('gmail')));
    expect(find.textContaining('Coffre exporté'), findsOneWidget);
    session.lock();
  });

  testWidgets('renoncer au sélecteur ne fait pas dire que c\'est exporté', (
    tester,
  ) async {
    final store = MemoryVaultStore();
    final session = await makeUnlockedSession(store: store);
    final saver = _FauxEnregistreur(rendu: null);

    await tester.pumpWidget(
      wrapScreen(
        SettingsScreen(
          session: session,
          settings: null,
          transfer: await transfertDe(store),
          saver: saver,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-save')));
    await tester.pumpAndSettle();

    expect(saver.appels, 1);
    // Annoncer un export qui n'a pas eu lieu ferait croire à une sauvegarde
    // qui n'existe pas — la pire des fausses nouvelles pour un coffre.
    expect(find.textContaining('Coffre exporté'), findsNothing);
    session.lock();
  });

  testWidgets('là où le système ne sait pas, aucune feuille ne s\'ouvre', (
    tester,
  ) async {
    final store = MemoryVaultStore();
    final session = await makeUnlockedSession(store: store);
    final saver = _FauxEnregistreur(isSupported: false);

    await tester.pumpWidget(
      wrapScreen(
        SettingsScreen(
          session: session,
          settings: null,
          transfer: await transfertDe(store),
          saver: saver,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export')));
    await tester.pumpAndSettle();

    // Sous Linux le sélecteur d'enregistrement s'ouvre directement: une feuille
    // à deux entrées dont l'une est « Partager » n'aurait rien à y faire.
    expect(find.byKey(const Key('export-save')), findsNothing);
    expect(find.byKey(const Key('export-share')), findsNothing);
    expect(saver.appels, 0);
    session.lock();
  });
}
