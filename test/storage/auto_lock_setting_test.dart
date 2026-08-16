import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/storage/app_settings.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('safe_autolock_setting');
  });

  tearDown(() async => dir.delete(recursive: true));

  test('défaut: 2 minutes', () {
    expect(const AppSettings().autoLockDelay, const Duration(minutes: 2));
  });

  test('aller-retour JSON', () {
    const settings = AppSettings(autoLockDelay: Duration(seconds: 30));
    expect(
      AppSettings.fromJson(settings.toJson()).autoLockDelay,
      const Duration(seconds: 30),
    );
  });

  test('écriture puis relecture sur disque', () async {
    final store = SettingsFile(dir);
    await store.write(const AppSettings(autoLockDelay: Duration(minutes: 5)));
    expect((await store.read()).autoLockDelay, const Duration(minutes: 5));
  });

  test('les deux réglages cohabitent dans le même fichier', () async {
    final store = SettingsFile(dir);
    await store.write(
      const AppSettings(
        blockScreenshots: false,
        autoLockDelay: Duration(seconds: 30),
      ),
    );
    final relu = await store.read();
    expect(relu.blockScreenshots, isFalse);
    expect(relu.autoLockDelay, const Duration(seconds: 30));
  });

  test('valeur absente: défaut', () {
    expect(
      AppSettings.fromJson(const {}).autoLockDelay,
      const Duration(minutes: 2),
    );
  });

  test('valeur d\'un type inattendu: défaut', () {
    expect(
      AppSettings.fromJson(const {'autoLockSeconds': 'beaucoup'}).autoLockDelay,
      const Duration(minutes: 2),
    );
  });

  test('un délai trafiqué trop long est ramené au maximum', () {
    // Un fichier de réglages modifié à la main ne doit pas pouvoir garder le
    // coffre ouvert des heures.
    expect(
      AppSettings.fromJson(const {'autoLockSeconds': 86400}).autoLockDelay,
      maxAutoLockDelay,
    );
  });

  test('zéro ou négatif est ramené au minimum', () {
    expect(
      AppSettings.fromJson(const {'autoLockSeconds': 0}).autoLockDelay,
      minAutoLockDelay,
    );
    expect(
      AppSettings.fromJson(const {'autoLockSeconds': -5}).autoLockDelay,
      minAutoLockDelay,
    );
  });

  test('le fichier abîmé rend les deux défauts', () async {
    final store = SettingsFile(dir);
    await File('${dir.path}/settings.json').writeAsString('pas du json');
    final relu = await store.read();
    expect(relu.blockScreenshots, isTrue);
    expect(relu.autoLockDelay, const Duration(minutes: 2));
  });
}
