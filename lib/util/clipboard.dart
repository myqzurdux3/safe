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
    _timer = Timer(clearAfter, clearNow);
  }

  /// Efface immédiatement, si le presse-papier contient encore notre valeur.
  Future<void> clearNow() async {
    _timer?.cancel();
    _timer = null;
    final pending = _pending;
    _pending = null;
    if (pending == null) {
      return;
    }
    final current = await Clipboard.getData(Clipboard.kTextPlain);
    if (current?.text == pending) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }
}
