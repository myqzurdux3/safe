import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/storage/blob_store.dart';

void main() {
  late Directory dir;
  late BlobFileStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('safe_blobs');
    store = BlobFileStore(Directory('${dir.path}/blobs'));
  });

  tearDown(() async => dir.delete(recursive: true));

  /// Les identifiants ont une forme imposée: 32 caractères hexadécimaux, ceux
  /// que tire `VaultCrypto.newBlobId`. Tout le reste est refusé, parce qu'un
  /// identifiant est un nom de fichier.
  String id(int n) => n.toRadixString(16).padLeft(32, '0');

  test('écriture puis lecture', () async {
    await store.put(id(1), Uint8List.fromList([1, 2, 3]));
    expect(await store.get(id(1)), [1, 2, 3]);
  });

  test('lecture d\'un blob absent lève FileSystemException', () async {
    expect(store.get(id(99)), throwsA(isA<FileSystemException>()));
  });

  test('suppression puis relecture impossible', () async {
    await store.put(id(1), Uint8List.fromList([1]));
    await store.delete(id(1));
    expect(store.get(id(1)), throwsA(isA<FileSystemException>()));
  });

  test('supprimer un blob absent ne lève pas', () async {
    await expectLater(store.delete(id(42)), completes);
  });

  test('ids liste les blobs présents', () async {
    await store.put(id(1), Uint8List.fromList([1]));
    await store.put(id(2), Uint8List.fromList([2]));
    expect(await store.ids(), {id(1), id(2)});
  });

  test('ids sur un dossier absent rend un ensemble vide', () async {
    expect(await BlobFileStore(Directory('${dir.path}/vide')).ids(), isEmpty);
  });

  test('aucun .tmp ne subsiste après écriture', () async {
    await store.put(id(1), Uint8List.fromList([1]));
    expect(
      store.directory.listSync().where((e) => e.path.endsWith('.tmp')),
      isEmpty,
    );
  });
}
