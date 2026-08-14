import 'dart:math';

/// Jeux de caractères proposés par le générateur.
enum CharacterSet {
  letters('Lettres'),
  lettersDigits('Lettres et chiffres'),
  all('Tout');

  const CharacterSet(this.label);

  final String label;

  String get alphabet => switch (this) {
    CharacterSet.letters => _letters,
    CharacterSet.lettersDigits => '$_letters$_digits',
    CharacterSet.all => '$_letters$_digits$_symbols',
  };

  static const String _letters =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _digits = '0123456789';
  static const String _symbols = '!@#\$%^&*()-_=+[]{};:,.?/';
}

/// Longueurs acceptées, bornes comprises.
const int minPasswordLength = 8;
const int maxPasswordLength = 128;

/// Tire un mot de passe aléatoire.
///
/// Utilise [Random.secure] par défaut — le générateur du système, pas le
/// `Random` par défaut de Dart, qui est prévisible. Le paramètre [random]
/// n'existe que pour les tests.
String generatePassword({
  int length = 20,
  CharacterSet set = CharacterSet.all,
  Random? random,
}) {
  if (length < minPasswordLength || length > maxPasswordLength) {
    throw ArgumentError.value(
      length,
      'length',
      'Longueur attendue entre $minPasswordLength et $maxPasswordLength',
    );
  }
  final source = random ?? Random.secure();
  final alphabet = set.alphabet;
  return String.fromCharCodes([
    for (var i = 0; i < length; i++)
      alphabet.codeUnitAt(source.nextInt(alphabet.length)),
  ]);
}
