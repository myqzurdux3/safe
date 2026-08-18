import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/storage/vault_file.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('safe_concurrent');
  });

  tearDown(() async => dir.delete(recursive: true));

  test('deux écritures concurrentes ne se marchent pas dessus', () async {
    final file = VaultFile(dir);
    final a = Uint8List.fromList(List.filled(2 * 1024 * 1024, 0x41));
    final b = Uint8List.fromList(List.filled(2 * 1024 * 1024, 0x42));

    await Future.wait([file.write(a), file.write(b)]);

    // Le coffre doit être *l'un des deux*, entier: ni un mélange des deux, ni
    // un fichier tronqué. Un seul octet distinct suffit à le prouver ici.
    final relu = await file.read();
    expect(relu.length, a.length);
    expect(relu.toSet().length, 1, reason: 'contenu mélangé');
  });

  test('aucun fichier temporaire ne survit à une écriture', () async {
    final file = VaultFile(dir);
    await Future.wait([
      for (var i = 0; i < 4; i++)
        file.write(Uint8List.fromList(List.filled(512 * 1024, i))),
    ]);

    final restes = dir
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .where((name) => name.contains('.tmp'))
        .toList();
    expect(restes, isEmpty);
  });
}
