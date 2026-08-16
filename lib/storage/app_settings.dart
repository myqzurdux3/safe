import 'dart:convert';
import 'dart:io';

/// Préférences de l'application.
///
/// Rien de secret ici, d'où un simple fichier JSON en clair à côté du coffre:
/// ces réglages ne disent rien du contenu du coffre. Tout ce qui touche aux
/// données reste chiffré dans `vault.safe`.
class AppSettings {
  const AppSettings({this.blockScreenshots = true});

  /// Bloquer les captures d'écran et vider la vignette du sélecteur
  /// d'applications (`FLAG_SECURE` sur Android).
  ///
  /// Actif par défaut: c'est le réglage sûr, et il compense le fait que passer
  /// en arrière-plan ne verrouille plus le coffre.
  final bool blockScreenshots;

  AppSettings copyWith({bool? blockScreenshots}) =>
      AppSettings(blockScreenshots: blockScreenshots ?? this.blockScreenshots);

  Map<String, Object?> toJson() => {'blockScreenshots': blockScreenshots};

  /// Toute valeur absente ou d'un type inattendu retombe sur le défaut, qui
  /// est le réglage le plus protecteur.
  factory AppSettings.fromJson(Map<String, Object?> json) {
    final value = json['blockScreenshots'];
    return AppSettings(blockScreenshots: value is bool ? value : true);
  }
}

/// Où vivent les réglages. Une interface, pour que les tests d'interface
/// n'aient pas à toucher au disque.
abstract class SettingsStore {
  Future<AppSettings> read();

  Future<void> write(AppSettings settings);
}

/// Réglages gardés en mémoire, pour les tests.
class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([this._settings = const AppSettings()]);

  AppSettings _settings;

  @override
  Future<AppSettings> read() async => _settings;

  @override
  Future<void> write(AppSettings settings) async => _settings = settings;
}

/// Les réglages sur le disque, dans le même dossier que le coffre.
class SettingsFile implements SettingsStore {
  const SettingsFile(this.directory);

  final Directory directory;

  File get file => File('${directory.path}/settings.json');

  /// Un fichier absent, illisible ou abîmé rend les valeurs par défaut: perdre
  /// ses préférences est acceptable, planter au démarrage ne l'est pas.
  @override
  Future<AppSettings> read() async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) {
        return const AppSettings();
      }
      return AppSettings.fromJson(decoded);
    } catch (_) {
      return const AppSettings();
    }
  }

  @override
  Future<void> write(AppSettings settings) async {
    await directory.create(recursive: true);
    await file.writeAsString(jsonEncode(settings.toJson()));
  }
}
