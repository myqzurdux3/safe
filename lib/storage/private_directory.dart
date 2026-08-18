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
/// Un dossier déjà en place n'est pas retouché: l'utilisateur a peut-être choisi
/// ses droits, et les écraser serait plus surprenant qu'utile. Un échec est
/// silencieux — refuser de démarrer parce qu'un `chmod` n'a pas abouti serait
/// disproportionné — mais alors les droits restent ceux du système.
Future<void> createPrivateDirectory(Directory directory) async {
  if (await directory.exists()) {
    return;
  }
  await directory.create(recursive: true);
  if (!Platform.isLinux) {
    return;
  }
  try {
    await Process.run('chmod', ['700', directory.path]);
  } on ProcessException {
    // `chmod` absent d'un système réduit: rien de mieux à faire depuis Dart,
    // qui n'expose pas l'appel système.
  }
}
