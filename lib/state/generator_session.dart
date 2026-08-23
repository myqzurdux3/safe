import 'package:flutter/foundation.dart';

import '../util/password_generator.dart';
import 'vault_session.dart';

/// L'état du générateur de mots de passe.
///
/// Le générateur n'appartient plus à un champ d'édition: c'est un outil de
/// l'accueil, dont l'état vit le temps d'une session déverrouillée. Rien ici
/// n'est écrit sur le disque — c'est ce que l'écran promet à l'utilisateur, et
/// une valeur générée est un secret au même titre qu'une valeur du coffre.
class GeneratorSession extends ChangeNotifier {
  GeneratorSession(this._vault) {
    _vault.addListener(_onVault);
    _value = generatePassword(length: _length, set: _set);
  }

  /// Nombre de valeurs précédentes conservées, comme sur la maquette.
  static const int historyLength = 3;

  final VaultSession _vault;

  int _length = 20;
  CharacterSet _set = CharacterSet.all;
  String _value = '';
  final List<String> _history = [];

  int get length => _length;
  CharacterSet get set => _set;
  String get value => _value;

  /// Les valeurs précédentes, de la plus récente à la plus ancienne.
  List<String> get history => List.unmodifiable(_history);

  /// Tire une nouvelle valeur et pousse l'ancienne dans l'historique.
  void regenerate() {
    if (_value.isNotEmpty) {
      _history.insert(0, _value);
      if (_history.length > historyLength) {
        _history.removeRange(historyLength, _history.length);
      }
    }
    _value = generatePassword(length: _length, set: _set);
    notifyListeners();
  }

  /// Le curseur régénère à chaque cran: la maquette montre la valeur suivre.
  void setLength(int length) {
    _length = length.clamp(minPasswordLength, maxPasswordLength);
    _value = generatePassword(length: _length, set: _set);
    notifyListeners();
  }

  void setSet(CharacterSet set) {
    _set = set;
    _value = generatePassword(length: _length, set: _set);
    notifyListeners();
  }

  /// Efface tout: appelé au verrouillage, et rien ne survit.
  void clear() {
    _history.clear();
    _value = '';
    notifyListeners();
  }

  void _onVault() {
    if (!_vault.isUnlocked) {
      clear();
    }
  }

  @override
  void dispose() {
    _vault.removeListener(_onVault);
    super.dispose();
  }
}
