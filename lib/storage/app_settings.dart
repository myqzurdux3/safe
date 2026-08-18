import 'dart:convert';
import 'dart:io';

/// Bornes du délai de verrouillage automatique.
///
/// Elles servent à valider ce qui est relu du disque: un fichier modifié à la
/// main ne doit pas pouvoir garder le coffre ouvert indéfiniment.
const Duration minAutoLockDelay = Duration(seconds: 30);
const Duration maxAutoLockDelay = Duration(minutes: 5);
const Duration defaultAutoLockDelay = Duration(minutes: 2);

/// Préférences de l'application.
///
/// Rien de secret ici, d'où un simple fichier JSON en clair à côté du coffre:
/// ces réglages ne disent rien du contenu du coffre. Tout ce qui touche aux
/// données reste chiffré dans `vault.safe`.
class AppSettings {
  const AppSettings({
    this.blockScreenshots = true,
    this.autoLockDelay = defaultAutoLockDelay,
  });

  /// Bloquer les captures d'écran et vider la vignette du sélecteur
  /// d'applications (`FLAG_SECURE` sur Android).
  ///
  /// Actif par défaut: c'est le réglage sûr, et il compense le fait que passer
  /// en arrière-plan ne verrouille plus le coffre.
  final bool blockScreenshots;

  /// Inactivité tolérée avant verrouillage.
  final Duration autoLockDelay;

  AppSettings copyWith({bool? blockScreenshots, Duration? autoLockDelay}) =>
      AppSettings(
        blockScreenshots: blockScreenshots ?? this.blockScreenshots,
        autoLockDelay: autoLockDelay ?? this.autoLockDelay,
      );

  Map<String, Object?> toJson() => {
    'blockScreenshots': blockScreenshots,
    'autoLockSeconds': autoLockDelay.inSeconds,
  };

  /// Toute valeur absente ou d'un type inattendu retombe sur le défaut, qui
  /// est le réglage le plus protecteur.
  factory AppSettings.fromJson(Map<String, Object?> json) {
    final blocked = json['blockScreenshots'];
    final seconds = json['autoLockSeconds'];
    return AppSettings(
      blockScreenshots: blocked is bool ? blocked : true,
      autoLockDelay: seconds is int
          ? _clampDelay(Duration(seconds: seconds))
          : defaultAutoLockDelay,
    );
  }

  /// Ramène un délai relu du disque entre les bornes autorisées.
  static Duration _clampDelay(Duration value) {
    if (value < minAutoLockDelay) {
      return minAutoLockDelay;
    }
    return value > maxAutoLockDelay ? maxAutoLockDelay : value;
  }
}

/// Où vivent les réglages. Une interface, pour que les tests d'interface
/// n'aient pas à toucher au disque.
abstract class SettingsStore {
  Future<AppSettings> read();

  Future<void> write(AppSettings settings);
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
