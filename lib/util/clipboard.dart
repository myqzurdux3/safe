import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Canal vers le presse-papier natif d'Android.
///
/// `Clipboard.setData` de Flutter ne marque pas le contenu comme sensible.
/// Conséquence sur Android 13 et suivants: le secret s'affiche dans l'aperçu du
/// presse-papier système, et les claviers le rangent dans leur propre historique
/// — un magasin distinct que notre effacement ne touche pas. Ce canal pose
/// `ClipDescription.EXTRA_IS_SENSITIVE`, seule façon de demander aux deux de
/// s'abstenir.
const MethodChannel sensitiveClipboardChannel = MethodChannel(
  'dev.safe/clipboard',
);

/// Presse-papier qui s'efface tout seul.
///
/// Une valeur copiée reste lisible par toute application tant qu'elle est dans
/// le presse-papier: on la retire après un délai court, et seulement si c'est
/// toujours la nôtre — sinon on effacerait ce que l'utilisateur a copié
/// entre-temps.
class SecureClipboard {
  SecureClipboard({this.clearAfter = const Duration(seconds: 30)});

  final Duration clearAfter;

  Timer? _timer;
  String? _pending;

  /// Le canal natif répond-il ? `null` tant qu'on n'a pas essayé.
  ///
  /// Mémorisé pour ne pas relancer un appel voué à l'échec à chaque copie sous
  /// Linux, où il n'existe pas.
  static bool? _natifDisponible;

  /// Copie [value] et programme son effacement.
  Future<void> copy(String value) async {
    if (await _viaNatif('copySensitive', {'text': value})) {
      _armer(value);
      return;
    }
    await Clipboard.setData(ClipboardData(text: value));
    _armer(value);
  }

  void _armer(String value) {
    _pending = value;
    _timer?.cancel();
    // `clearNow` rend un `Future`: passé tel quel à `Timer`, une erreur de
    // plateforme n'aurait aucun destinataire et remonterait en erreur de zone.
    _timer = Timer(clearAfter, () => unawaited(clearNow().catchError((_) {})));
  }

  /// Efface immédiatement, sauf si le presse-papier contient visiblement autre
  /// chose que notre valeur.
  ///
  /// La lecture du presse-papier échoue quand l'application n'a pas le focus —
  /// c'est la règle sur Android depuis la version 10, et c'est le cas nominal
  /// ici: on copie, on bascule vers le navigateur, la minuterie se déclenche.
  /// En cas de doute on efface donc: écraser une copie faite entre-temps est
  /// désagréable, laisser un mot de passe dans le presse-papier ne l'est pas.
  Future<void> clearNow() async {
    _timer?.cancel();
    _timer = null;
    final pending = _pending;
    _pending = null;
    if (pending == null) {
      return;
    }
    if (await _viaNatif('clear', const {})) {
      return;
    }
    ClipboardData? current;
    try {
      current = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (_) {
      current = null;
    }
    if (current == null || current.text == pending) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  }

  /// Tente [method] sur le canal natif; rend `false` s'il n'existe pas ou
  /// refuse, à charge pour l'appelant de se rabattre sur Flutter.
  Future<bool> _viaNatif(String method, Map<String, Object?> arguments) async {
    if (_natifDisponible == false) {
      return false;
    }
    try {
      await sensitiveClipboardChannel.invokeMethod<void>(method, arguments);
      _natifDisponible = true;
      return true;
    } on MissingPluginException {
      _natifDisponible = false;
      return false;
    } on PlatformException {
      // Le natif existe mais a refusé: on ne le déclare pas absent pour
      // autant, et on laisse le chemin Flutter faire ce qu'il peut.
      return false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }

  /// Oublie ce qu'on sait du canal natif. Réservé aux tests, qui le simulent
  /// tantôt présent, tantôt absent.
  @visibleForTesting
  static void resetNativeProbe() => _natifDisponible = null;
}
