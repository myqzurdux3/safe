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

/// Le délai retenu tant que rien n'a été choisi.
///
/// Il n'existe pas de constantes de bornes: [_clampDelay] ramène tout ce qui
/// est relu du disque à l'un des [autoLockChoices], si bien qu'un minimum et
/// un maximum déclarés à part n'auraient rien à valider. Il en a existé, sous
/// un commentaire qui affirmait le contraire.
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
    this.syntaxTutorialDismissed = false,
  });

  /// Bloquer les captures d'écran et vider la vignette du sélecteur
  /// d'applications (`FLAG_SECURE` sur Android).
  ///
  /// Actif par défaut: c'est le réglage sûr, et il compense le fait que passer
  /// en arrière-plan ne verrouille plus le coffre.
  final bool blockScreenshots;

  /// Inactivité tolérée avant verrouillage.
  final Duration autoLockDelay;

  /// Le tuto de syntaxe de la fiche a-t-il été écarté ?
  ///
  /// Une fois « Compris », il ne revient pas de lui-même: le lien « Syntaxe »
  /// le rappelle. Absent des fichiers écrits avant la refonte, d'où le défaut
  /// à `false` — aucune migration.
  final bool syntaxTutorialDismissed;

  AppSettings copyWith({
    bool? blockScreenshots,
    Duration? autoLockDelay,
    bool? syntaxTutorialDismissed,
  }) => AppSettings(
    blockScreenshots: blockScreenshots ?? this.blockScreenshots,
    autoLockDelay: autoLockDelay ?? this.autoLockDelay,
    syntaxTutorialDismissed:
        syntaxTutorialDismissed ?? this.syntaxTutorialDismissed,
  );

  Map<String, Object?> toJson() => {
    'blockScreenshots': blockScreenshots,
    'autoLockSeconds': autoLockDelay.inSeconds,
    'syntaxTutorialDismissed': syntaxTutorialDismissed,
  };

  /// Toute valeur absente ou d'un type inattendu retombe sur le défaut, qui
  /// est le réglage le plus protecteur.
  factory AppSettings.fromJson(Map<String, Object?> json) {
    final blocked = json['blockScreenshots'];
    final seconds = json['autoLockSeconds'];
    final tuto = json['syntaxTutorialDismissed'];
    return AppSettings(
      blockScreenshots: blocked is bool ? blocked : true,
      // Absent des fichiers écrits avant la refonte: le tuto s'affiche, ce qui
      // est justement ce dont a besoin quelqu'un qui découvre la syntaxe.
      syntaxTutorialDismissed: tuto is bool ? tuto : false,
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
