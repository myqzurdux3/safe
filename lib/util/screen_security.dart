import 'dart:io';

import 'package:flutter/services.dart';

/// Canal vers le code natif Android qui pose ou retire `FLAG_SECURE`.
const MethodChannel screenSecurityChannel = MethodChannel('dev.safe/screen');

/// Blocage des captures d'écran et de la vignette du sélecteur
/// d'applications.
///
/// Android uniquement: il n'existe pas d'équivalent sous Linux, où un
/// utilisateur capable de capturer l'écran est déjà devant la session
/// déverrouillée. L'appel y est simplement sans effet.
class ScreenSecurity {
  const ScreenSecurity();

  /// La plateforme sait-elle bloquer les captures d'écran ?
  ///
  /// Sert à distinguer « le système a refusé » — qu'il faut dire — de « il n'y
  /// a rien à bloquer ici », qui n'a pas à inquiéter un utilisateur Linux.
  bool get isSupported => Platform.isAndroid;

  /// Rend `true` si le natif a confirmé, `false` sinon.
  ///
  /// Le résultat compte: une protection silencieusement absente est pire
  /// qu'une erreur visible. L'appelant décide quoi en faire — sous Linux, où
  /// il n'y a rien à bloquer, un `false` est attendu et sans conséquence.
  Future<bool> setBlocked(bool blocked) async {
    try {
      await screenSecurityChannel.invokeMethod<void>('setBlocked', {
        'blocked': blocked,
      });
      return true;
    } on MissingPluginException {
      // Plateforme sans implémentation native.
      return false;
    } on PlatformException {
      // Le natif a refusé; l'écran de réglages doit le dire, pas planter.
      return false;
    }
  }
}
