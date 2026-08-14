import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/storage/vault_file.dart';

void main() {
  late Directory dir;
  late VaultFile store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('safe_test');
    store = VaultFile(dir);
  });

  tearDown(() async => dir.delete(recursive: true));

  test('écriture puis lecture rend les mêmes octets', () async {
    await store.write(Uint8List.fromList([1, 2, 3]));
    expect(await store.read(), [1, 2, 3]);
  });

  test('exists reflète la présence du fichier', () async {
    expect(await store.exists(), isFalse);
    await store.write(Uint8List.fromList([1]));
    expect(await store.exists(), isTrue);
  });

  test('la sauvegarde précédente part en .bak', () async {
    await store.write(Uint8List.fromList([1]));
    await store.write(Uint8List.fromList([2]));
    expect(await store.file.readAsBytes(), [2]);
    expect(await store.backupFile.readAsBytes(), [1]);
  });

  test('aucun .tmp ne subsiste après écriture', () async {
    await store.write(Uint8List.fromList([1]));
    expect(dir.listSync().where((e) => e.path.endsWith('.tmp')), isEmpty);
  });

  test('le dossier est créé au besoin', () async {
    final nested = VaultFile(Directory('${dir.path}/a/b'));
    await nested.write(Uint8List.fromList([7]));
    expect(await nested.read(), [7]);
  });

  test('lecture sans fichier lève FileSystemException', () async {
    expect(store.read(), throwsA(isA<FileSystemException>()));
  });
}
