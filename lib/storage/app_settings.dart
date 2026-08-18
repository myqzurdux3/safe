import 'dart:convert';
import 'dart:io';

import 'private_directory.dart';

/// Délais d'inactivité proposés avant verrouillage automatique.
///
/// Seule liste qui fasse foi: c'est elle que l'écran de réglages affiche, et
/// c'est à elle que tout délai relu du disque est ramené. Deux sources
/// donnaient auparavant deux vérités pour un même réglage — le sous-titre
/// affichait « Après 45 s » avec « 2 min » sélectionné dans la liste.
const List<Duration> autoLockChoices = [
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 2),
  Duration(minutes: 5),
];

/// Bornes du délai, déduites des choix.
///
/// Elles valident ce qui est relu du disque: un fichier modifié à la main ne
/// doit pas pouvoir garder le coffre ouvert indéfiniment.
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
      // `num` et non `int`: un fichier édité à la main peut contenir `120.0`,
      // et certains décodeurs rendent un `double` pour un entier.
      autoLockDelay: seconds is num
          ? _clampDelay(Duration(seconds: seconds.round()))
          : defaultAutoLockDelay,
    );
  }

  /// Ramène un délai relu du disque à l'un des [autoLockChoices].
  ///
  /// Vers le bas: entre deux choix, on retient le plus court, celui qui
  /// protège le plus.
  static Duration _clampDelay(Duration value) {
    var chosen = autoLockChoices.first;
    for (final choice in autoLockChoices) {
      if (value >= choice) {
        chosen = choice;
      }
    }
    return chosen;
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
  SettingsFile(this.directory);

  static int _writes = 0;

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
    } on FormatException {
      return const AppSettings();
    } on FileSystemException {
      return const AppSettings();
    }
  }

  /// Écrit par un temporaire puis un `rename`.
  ///
  /// `writeAsString` tronque avant d'écrire: une coupure laissait un JSON
  /// partiel, donc un retour silencieux aux valeurs par défaut. Le temporaire
  /// est nommé par un compteur, pour que deux écritures rapprochées — deux
  /// bascules d'affilée dans les réglages — ne le partagent pas.
  @override
  Future<void> write(AppSettings settings) async {
    await createPrivateDirectory(directory);
    final temp = File('${file.path}.${_writes++}.tmp');
    try {
      await temp.writeAsString(jsonEncode(settings.toJson()), flush: true);
      await temp.rename(file.path);
    } catch (_) {
      if (await temp.exists()) {
        await temp.delete();
      }
      rethrow;
    }
  }
}
