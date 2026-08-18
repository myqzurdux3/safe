import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/ui/attachments_section.dart';

import '../support/fake_file_selector.dart';
import '../support/session_fixture.dart';

void main() {
  late FakeFileSelector selector;
  late Directory scratch;

  setUp(() async {
    selector = FakeFileSelector();
    FileSelectorPlatform.instance = selector;
    scratch = await Directory.systemTemp.createTemp('safe_pj');
  });

  tearDown(() async => scratch.delete(recursive: true));

  Future<Widget> section(
    VaultSession session, {
    VoidCallback? onChanged,
  }) async => wrapScreen(
    Scaffold(
      body: AttachmentsSection(
        session: session,
        entryKey: 'gmail',
        onChanged: onChanged ?? () {},
      ),
    ),
  );

  testWidgets('ajouter une pièce jointe la chiffre et l\'annonce', (
    tester,
  ) async {
    final blobs = MemoryBlobStore();
    final session = await makeUnlockedSession(keys: ['gmail'], blobs: blobs);
    // `XFile.fromData` et non un vrai fichier: une lecture disque ne se
    // termine jamais sous l'horloge simulée des tests de widgets.
    selector.fileToOpen = XFile.fromData(
      Uint8List.fromList([1, 2, 3, 4]),
      name: 'facture.pdf',
      path: 'facture.pdf',
    );

    var notifie = 0;
    await tester.pumpWidget(await section(session, onChanged: () => notifie++));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(blobs.contents, hasLength(1));
    // Le blob ne contient pas le clair: il est scellé.
    expect(blobs.contents.values.single, isNot([1, 2, 3, 4]));
    expect(notifie, 1);
    expect(find.text('facture.pdf'), findsOneWidget);
    session.lock();
  });

  testWidgets('annuler le sélecteur ne joint rien', (tester) async {
    final blobs = MemoryBlobStore();
    final session = await makeUnlockedSession(keys: ['gmail'], blobs: blobs);
    selector.fileToOpen = null;

    await tester.pumpWidget(await section(session));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(selector.openCount, 1);
    expect(blobs.contents, isEmpty);
    session.lock();
  });

  testWidgets('un fichier trop gros est refusé, avec sa taille', (
    tester,
  ) async {
    final blobs = MemoryBlobStore();
    final session = await makeUnlockedSession(keys: ['gmail'], blobs: blobs);
    selector.fileToOpen = XFile.fromData(
      Uint8List(maxAttachmentBytes + 1024),
      name: 'enorme.bin',
    );

    await tester.pumpWidget(await section(session));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(
      find.text('Fichier trop gros (25,0 Mo); maximum 25,0 Mo'),
      findsOneWidget,
    );
    expect(blobs.contents, isEmpty);
    session.lock();
  });

  testWidgets('exporter en clair écrit le contenu déchiffré', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    final attachment = await session.attach(
      entryKey: 'gmail',
      name: 'note.txt',
      mimeType: 'text/plain',
      bytes: Uint8List.fromList([7, 8, 9]),
    );
    final destination = '${scratch.path}/sortie.txt';
    selector.saveTo = destination;

    await tester.pumpWidget(await section(session));
    await tester.pumpAndSettle();
    // `runAsync`: l'export écrit vraiment sur le disque, ce que l'horloge
    // simulée ne laisse pas aboutir.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(Key('export-${attachment.id}')));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(File(destination).readAsBytesSync(), [7, 8, 9]);
    expect(find.textContaining('Enregistré en clair'), findsOneWidget);
    session.lock();
  });

  testWidgets('annuler l\'enregistrement n\'écrit aucun fichier', (
    tester,
  ) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    final attachment = await session.attach(
      entryKey: 'gmail',
      name: 'note.txt',
      mimeType: 'text/plain',
      bytes: Uint8List.fromList([7, 8, 9]),
    );
    selector.saveTo = null;

    await tester.pumpWidget(await section(session));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('export-${attachment.id}')));
    await tester.pumpAndSettle();

    expect(selector.saveCount, 1);
    expect(scratch.listSync(), isEmpty);
    session.lock();
  });

  testWidgets('détacher efface le blob et prévient le parent', (tester) async {
    final blobs = MemoryBlobStore();
    final session = await makeUnlockedSession(keys: ['gmail'], blobs: blobs);
    final attachment = await session.attach(
      entryKey: 'gmail',
      name: 'note.txt',
      mimeType: 'text/plain',
      bytes: Uint8List.fromList([7, 8, 9]),
    );
    var notifie = 0;
    await tester.pumpWidget(await section(session, onChanged: () => notifie++));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('detach-${attachment.id}')));
    await tester.pumpAndSettle();
    expect(find.textContaining('note.txt'), findsWidgets);
    await tester.tap(find.byKey(const Key('confirm-detach')));
    await tester.pumpAndSettle();

    // Effacé pour de bon: c'est une demande explicite, pas une déduction.
    expect(blobs.contents, isEmpty);
    expect(blobs.quarantined, isEmpty);
    expect(notifie, 1);
    session.lock();
  });

  testWidgets('annuler le détachement garde la pièce jointe', (tester) async {
    final blobs = MemoryBlobStore();
    final session = await makeUnlockedSession(keys: ['gmail'], blobs: blobs);
    final attachment = await session.attach(
      entryKey: 'gmail',
      name: 'note.txt',
      mimeType: 'text/plain',
      bytes: Uint8List.fromList([7, 8, 9]),
    );
    await tester.pumpWidget(await section(session));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('detach-${attachment.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-detach')));
    await tester.pumpAndSettle();

    expect(blobs.contents, hasLength(1));
    session.lock();
  });

  testWidgets('sans entrée enregistrée, la section invite à enregistrer', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(
      wrapScreen(
        Scaffold(
          body: AttachmentsSection(
            session: session,
            entryKey: null,
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Enregistrez l\'entrée'), findsOneWidget);
    session.lock();
  });

  testWidgets('un fichier sans nom reçoit un nom de repli', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    // Certaines implémentations du sélecteur rendent un fichier en mémoire,
    // sans chemin ni nom. Sans repli, la pièce jointe s'affichait sans rien.
    selector.fileToOpen = XFile.fromData(Uint8List.fromList([1, 2]));

    await tester.pumpWidget(await section(session));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(session.vault!.entries.single.attachments.single.name, isNotEmpty);
    expect(find.text('pièce jointe'), findsOneWidget);
    session.lock();
  });

  /// Le plus petit PNG valide: 1x1, transparent. Flutter doit pouvoir le
  /// décoder pour que la visionneuse s'affiche.
  final pngMinimal = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  testWidgets('ouvrir une image l\'affiche dans une visionneuse', (
    tester,
  ) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    final attachment = await session.attach(
      entryKey: 'gmail',
      name: 'photo.png',
      mimeType: 'image/png',
      bytes: Uint8List.fromList(pngMinimal),
    );
    expect(attachment.isImage, isTrue);

    await tester.pumpWidget(await section(session));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.byKey(Key('attachment-${attachment.id}')));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Fermer'), findsOneWidget);

    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    session.lock();
  });

  testWidgets('ouvrir un fichier non-image propose de l\'enregistrer', (
    tester,
  ) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    final attachment = await session.attach(
      entryKey: 'gmail',
      name: 'facture.pdf',
      mimeType: 'application/pdf',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    final destination = '${scratch.path}/facture.pdf';
    selector.saveTo = destination;

    await tester.pumpWidget(await section(session));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.byKey(Key('attachment-${attachment.id}')));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // Pas d'aperçu possible: on retombe sur l'export, qui est le seul usage.
    expect(find.byType(Image), findsNothing);
    expect(File(destination).readAsBytesSync(), [1, 2, 3]);
    session.lock();
  });
}
