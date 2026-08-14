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

  test('écriture puis lecture', () async {
    await store.put('abc', Uint8List.fromList([1, 2, 3]));
    expect(await store.get('abc'), [1, 2, 3]);
  });

  test('lecture d\'un blob absent lève FileSystemException', () async {
    expect(store.get('inconnu'), throwsA(isA<FileSystemException>()));
  });

  test('suppression puis relecture impossible', () async {
    await store.put('abc', Uint8List.fromList([1]));
    await store.delete('abc');
    expect(store.get('abc'), throwsA(isA<FileSystemException>()));
  });

  test('supprimer un blob absent ne lève pas', () async {
    await expectLater(store.delete('jamais-écrit'), completes);
  });

  test('ids liste les blobs présents', () async {
    await store.put('a', Uint8List.fromList([1]));
    await store.put('b', Uint8List.fromList([2]));
    expect(await store.ids(), {'a', 'b'});
  });

  test('ids sur un dossier absent rend un ensemble vide', () async {
    expect(await BlobFileStore(Directory('${dir.path}/vide')).ids(), isEmpty);
  });

  test('aucun .tmp ne subsiste après écriture', () async {
    await store.put('a', Uint8List.fromList([1]));
    expect(
      store.directory.listSync().where((e) => e.path.endsWith('.tmp')),
      isEmpty,
    );
  });
}
