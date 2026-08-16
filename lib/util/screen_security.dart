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

  Future<void> setBlocked(bool blocked) async {
    try {
      await screenSecurityChannel.invokeMethod<void>('setBlocked', {
        'blocked': blocked,
      });
    } on MissingPluginException {
      // Plateforme sans implémentation native: rien à faire, et surtout pas
      // remonter une erreur dans les réglages.
    } on PlatformException {
      // Idem: un échec côté natif ne doit pas casser l'écran de réglages.
    }
  }
}
