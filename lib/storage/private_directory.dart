import 'dart:io';

/// Crée [directory] et, sous Linux, la ferme aux autres comptes.
///
/// Un umask ordinaire donne `0755` au dossier créé: `~/.local/share/safe/` était
/// donc lisible par tout autre utilisateur de la machine, qui pouvait copier le
/// coffre et attaquer Argon2id hors ligne, tranquillement. `0700` sur le dossier
/// suffit — sans droit de traversée, le mode des fichiers qu'il contient n'a plus
/// d'importance.
///
/// Sous Android le répertoire privé de l'application est déjà cloisonné par le
/// système; il n'y a rien à faire, et `chmod` n'y est pas garanti.
///
/// Un dossier déjà en place est resserré lui aussi, s'il est ouvert au groupe ou
/// à tout le monde: `0755` sur un dossier de coffre n'est jamais un choix
/// délibéré, c'est l'umask par défaut. Les installations faites avant ce
/// correctif sont donc réparées au premier démarrage, au lieu de rester ouvertes
/// indéfiniment.
///
/// Un échec est silencieux — refuser de démarrer parce qu'un `chmod` n'a pas
/// abouti serait disproportionné — mais alors les droits restent ceux du
/// système.
Future<void> createPrivateDirectory(Directory directory) async {
  final existait = await directory.exists();
  if (!existait) {
    await directory.create(recursive: true);
  }
  if (!Platform.isLinux) {
    return;
  }
  if (existait && !_ouvertAuxAutres(directory)) {
    return;
  }
  try {
    await Process.run('chmod', ['700', directory.path]);
  } on ProcessException {
    // `chmod` absent d'un système réduit: rien de mieux à faire depuis Dart,
    // qui n'expose pas l'appel système.
  }
}

/// Le dossier accorde-t-il le moindre droit au groupe ou aux autres ?
bool _ouvertAuxAutres(Directory directory) {
  try {
    // `modeString` rend par exemple `rwxr-xr-x`: les six derniers caractères
    // sont les droits du groupe puis des autres.
    return directory
        .statSync()
        .modeString()
        .substring(3)
        .contains(RegExp(r'[rwx]'));
  } on FileSystemException {
    return false;
  }
}
