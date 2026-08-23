import 'dart:io';

import 'package:flutter/services.dart';

/// Canal vers le code natif Android qui ouvre le sélecteur d'enregistrement.
const MethodChannel fileSaverChannel = MethodChannel('dev.safe/save');

/// Écrire un fichier dans un dossier choisi par l'utilisateur.
///
/// Sur Android, partager n'est pas enregistrer: le partage passe le fichier à
/// une autre application, qui décide de ce qu'elle en fait — et rien ne
/// garantit qu'une seule des cibles proposées sache simplement le poser sur
/// l'appareil. Une sauvegarde de coffre doit pouvoir atterrir dans un dossier
/// choisi, sans intermédiaire.
///
/// `file_selector` ne sait pas le faire sur Android: son implémentation
/// (`file_selector_android`) n'expose que l'ouverture d'un fichier et le choix
/// d'un dossier, pas `getSaveLocation`. D'où ce canal, qui déclenche
/// `ACTION_CREATE_DOCUMENT` — le geste standard du système. Aucun paquet tiers
/// n'est ajouté pour cela.
///
/// Sous Linux, `getSaveLocation` fait déjà le travail: [isSupported] y répond
/// `false` et l'appelant garde son chemin habituel.
class FileSaver {
  const FileSaver();

  /// La plateforme a-t-elle besoin de ce canal ?
  bool get isSupported => Platform.isAndroid;

  /// Ouvre le sélecteur et écrit [bytes] à l'endroit retenu.
  ///
  /// Rend le nom du fichier écrit, ou `null` si l'utilisateur a renoncé —
  /// distinction qui compte: annoncer un export qui n'a pas eu lieu ferait
  /// croire à une sauvegarde qui n'existe pas. Lève une [PlatformException] si
  /// l'écriture échoue, pour que l'appelant le dise au lieu de se taire.
  Future<String?> save({
    required String suggestedName,
    required Uint8List bytes,
  }) => fileSaverChannel.invokeMethod<String>('createDocument', {
    'name': suggestedName,
    'bytes': bytes,
  });
}
