import 'dart:math';

/// Classes de caractères combinées par les jeux proposés.
class _CharacterClass {
  const _CharacterClass(this.characters);

  final String characters;

  /// Les minuscules sans « l », qui se confond avec « 1 » et « I ».
  static const lower = _CharacterClass('abcdefghijkmnopqrstuvwxyz');

  /// Les majuscules sans « I » ni « O ».
  static const upper = _CharacterClass('ABCDEFGHJKLMNPQRSTUVWXYZ');

  /// Les chiffres sans « 0 » ni « 1 ».
  static const digits = _CharacterClass('23456789');

  /// Une ponctuation restreinte, celle que le handoff retient.
  ///
  /// Le jeu complet passe de 94 à 67 caractères, soit 6,07 bits par position
  /// au lieu de 6,55 — un demi-bit de moins, 121 bits à vingt caractères. Ce
  /// qu'on gagne: des mots de passe que les formulaires acceptent, et qui se
  /// recopient à la main sans erreur.
  static const symbols = _CharacterClass(r'!#$%&*+-?@');
}

/// Jeux de caractères proposés par le générateur.
enum CharacterSet {
  letters('Lettres'),
  lettersDigits('+ chiffres'),
  all('+ symboles');

  const CharacterSet(this.label);

  final String label;

  /// Classes qui composent ce jeu; chacune est garantie présente dans un mot de
  /// passe assez long pour les contenir toutes.
  List<_CharacterClass> get _classes => switch (this) {
    CharacterSet.letters => const [
      _CharacterClass.lower,
      _CharacterClass.upper,
    ],
    CharacterSet.lettersDigits => const [
      _CharacterClass.lower,
      _CharacterClass.upper,
      _CharacterClass.digits,
    ],
    CharacterSet.all => const [
      _CharacterClass.lower,
      _CharacterClass.upper,
      _CharacterClass.digits,
      _CharacterClass.symbols,
    ],
  };

  /// Tous les caractères utilisables par ce jeu.
  String get alphabet => _classes.map((c) => c.characters).join();
}

/// Longueurs acceptées, bornes comprises. Le curseur du générateur va de l'une
/// à l'autre.
const int minPasswordLength = 8;
const int maxPasswordLength = 48;

/// Tire un mot de passe aléatoire.
///
/// Chaque classe du jeu choisi apparaît au moins une fois quand la longueur le
/// permet: un tirage uniforme finit sinon par produire un mot de passe sans
/// aucun symbole, que beaucoup de formulaires refusent.
///
/// Utilise [Random.secure] par défaut — le générateur du système, pas le
/// `Random` ordinaire de Dart, qui est prévisible. Le paramètre [random]
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
  final classes = set._classes;
  final alphabet = set.alphabet;

  final characters = <String>[
    // Un caractère par classe d'abord, le reste tiré dans tout l'alphabet.
    for (final characterClass in classes.take(length))
      characterClass.characters[source.nextInt(
        characterClass.characters.length,
      )],
  ];
  while (characters.length < length) {
    characters.add(alphabet[source.nextInt(alphabet.length)]);
  }

  // Mélange de Fisher-Yates: sans lui, les premières positions trahiraient
  // toujours la même classe.
  for (var i = characters.length - 1; i > 0; i--) {
    final j = source.nextInt(i + 1);
    final swap = characters[i];
    characters[i] = characters[j];
    characters[j] = swap;
  }
  return characters.join();
}
