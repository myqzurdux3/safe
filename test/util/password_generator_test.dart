import 'package:flutter_test/flutter_test.dart';
import 'package:safe/util/password_generator.dart';

void main() {
  test('longueur respectée', () {
    expect(generatePassword(length: 32).length, 32);
  });

  test('jeu de caractères respecté', () {
    expect(
      RegExp(
        r'^[A-Za-z]+$',
      ).hasMatch(generatePassword(length: 128, set: CharacterSet.letters)),
      isTrue,
    );
    expect(
      RegExp(r'^[A-Za-z0-9]+$').hasMatch(
        generatePassword(length: 128, set: CharacterSet.lettersDigits),
      ),
      isTrue,
    );
  });

  test('le jeu complet contient toute la ponctuation ASCII', () {
    const attendu = r'''!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~''';
    for (final symbole in attendu.split('')) {
      expect(
        CharacterSet.all.alphabet.contains(symbole),
        isTrue,
        reason: 'symbole absent du jeu: $symbole',
      );
    }
  });

  test('chaque classe demandée est présente, même sur un tirage court', () {
    // Répété: un tirage purement uniforme finirait par sortir un mot de passe
    // sans symbole, refusé par les formulaires qui en exigent un.
    for (var i = 0; i < 200; i++) {
      final pwd = generatePassword(length: 12);
      expect(RegExp(r'[a-z]').hasMatch(pwd), isTrue, reason: pwd);
      expect(RegExp(r'[A-Z]').hasMatch(pwd), isTrue, reason: pwd);
      expect(RegExp(r'[0-9]').hasMatch(pwd), isTrue, reason: pwd);
      expect(RegExp(r'''[!-/:-@\[-`{-~]''').hasMatch(pwd), isTrue, reason: pwd);
    }
  });

  test('lettres seules: majuscules et minuscules présentes', () {
    for (var i = 0; i < 50; i++) {
      final pwd = generatePassword(length: 8, set: CharacterSet.letters);
      expect(RegExp(r'[a-z]').hasMatch(pwd), isTrue, reason: pwd);
      expect(RegExp(r'[A-Z]').hasMatch(pwd), isTrue, reason: pwd);
    }
  });

  test('la garantie ne fige pas les positions', () {
    // Si les caractères garantis restaient en tête, les premières positions
    // seraient d'une classe fixe: entropie perdue et motif reconnaissable.
    final premiers = {
      for (var i = 0; i < 100; i++) generatePassword(length: 12)[0],
    };
    expect(premiers.length, greaterThan(3));
  });

  test('deux appels donnent des résultats différents', () {
    expect(generatePassword(), isNot(generatePassword()));
  });

  test('longueur hors bornes rejetée', () {
    expect(() => generatePassword(length: 3), throwsArgumentError);
    expect(() => generatePassword(length: 500), throwsArgumentError);
  });
}
