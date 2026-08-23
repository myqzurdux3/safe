import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/storage/app_settings.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('safe_settings');
  });

  tearDown(() async => dir.delete(recursive: true));

  test('par défaut: les captures d\'écran sont bloquées', () {
    expect(const AppSettings().blockScreenshots, isTrue);
  });

  test('aller-retour JSON', () {
    const settings = AppSettings(blockScreenshots: false);
    expect(AppSettings.fromJson(settings.toJson()).blockScreenshots, isFalse);
  });

  test('fichier absent: valeurs par défaut, pas d\'erreur', () async {
    final store = SettingsFile(dir);
    expect((await store.read()).blockScreenshots, isTrue);
  });

  test('écriture puis relecture', () async {
    final store = SettingsFile(dir);
    await store.write(const AppSettings(blockScreenshots: false));
    expect((await store.read()).blockScreenshots, isFalse);
  });

  test(
    'fichier illisible: valeurs par défaut plutôt qu\'un plantage',
    () async {
      final store = SettingsFile(dir);
      await File('${dir.path}/settings.json').writeAsString('{ pas du json');
      // Sûr par défaut: un fichier abîmé ne doit pas désactiver la protection.
      expect((await store.read()).blockScreenshots, isTrue);
    },
  );

  test('clef inconnue ignorée, clef manquante = défaut', () async {
    final store = SettingsFile(dir);
    await File('${dir.path}/settings.json').writeAsString('{"inconnu":1}');
    expect((await store.read()).blockScreenshots, isTrue);
  });

  test('le fichier de réglages ne contient aucun secret', () async {
    final store = SettingsFile(dir);
    await store.write(const AppSettings(blockScreenshots: false));
    final contenu = await File('${dir.path}/settings.json').readAsString();
    expect(contenu.contains('motdepasse'), isFalse);
    expect(contenu, contains('blockScreenshots'));
  });

  test('le tuto de syntaxe est affiché par défaut', () {
    expect(const AppSettings().syntaxTutorialDismissed, isFalse);
  });

  test('un settings.json écrit avant la refonte reste lisible', () {
    // Champ absent: aucune migration, le tuto s'affiche.
    final settings = AppSettings.fromJson({
      'blockScreenshots': true,
      'autoLockSeconds': 120,
    });
    expect(settings.syntaxTutorialDismissed, isFalse);
  });

  test('la préférence de tuto fait l\'aller-retour par le JSON', () {
    final settings = const AppSettings().copyWith(
      syntaxTutorialDismissed: true,
    );
    expect(
      AppSettings.fromJson(settings.toJson()).syntaxTutorialDismissed,
      isTrue,
    );
  });

  test('une valeur de tuto d\'un type inattendu retombe sur le défaut', () {
    expect(
      AppSettings.fromJson({
        'syntaxTutorialDismissed': 'oui',
      }).syntaxTutorialDismissed,
      isFalse,
    );
  });
}
