import 'dart:async';

import 'package:flutter/services.dart';

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

  /// Copie [value] et programme son effacement.
  Future<void> copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    _pending = value;
    _timer?.cancel();
    // `clearNow` rend un `Future`: passée telle quelle à `Timer`, une erreur de
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

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }
}
