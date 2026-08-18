import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/storage/app_settings.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('safe_settings_robuste');
  });

  tearDown(() async => dir.delete(recursive: true));

  test('un délai écrit à la main en décimal est compris', () {
    // Un `settings.json` édité à la main, ou relu par un décodeur qui rend un
    // double, ne doit pas perdre silencieusement le réglage.
    expect(
      AppSettings.fromJson(const {'autoLockSeconds': 120.0}).autoLockDelay,
      const Duration(minutes: 2),
    );
  });

  test('l\'écriture ne laisse aucun fichier temporaire', () async {
    final store = SettingsFile(dir);
    await store.write(const AppSettings(blockScreenshots: false));
    final restes = dir
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .where((name) => name.contains('.tmp'))
        .toList();
    expect(restes, isEmpty);
  });

  test('deux écritures concurrentes laissent un fichier lisible', () async {
    final store = SettingsFile(dir);
    await Future.wait([
      store.write(const AppSettings(autoLockDelay: Duration(seconds: 30))),
      store.write(const AppSettings(autoLockDelay: Duration(minutes: 5))),
    ]);
    final relu = await store.read();
    expect(
      relu.autoLockDelay,
      anyOf(const Duration(seconds: 30), const Duration(minutes: 5)),
    );
  });
}
