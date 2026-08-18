import 'dart:math';
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

  group('tirage reproductible, via le générateur injecté', () {
    // Le paramètre `random` existe pour ça; aucun test ne l'utilisait, ce qui
    // rendait faux le commentaire qui l'annonçait comme réservé aux tests.
    test('même graine, même mot de passe', () {
      final a = generatePassword(length: 24, random: Random(1234));
      final b = generatePassword(length: 24, random: Random(1234));
      expect(a, b);
    });

    test('graines différentes, mots de passe différents', () {
      final a = generatePassword(length: 24, random: Random(1));
      final b = generatePassword(length: 24, random: Random(2));
      expect(a, isNot(b));
    });

    test('toutes les classes demandées sont présentes, sur 200 graines', () {
      // Le tirage garantit une occurrence par classe; une seule graine
      // malchanceuse ne prouverait rien.
      for (var graine = 0; graine < 200; graine++) {
        final mot = generatePassword(
          length: minPasswordLength,
          random: Random(graine),
        );
        expect(mot, matches(r'[a-z]'), reason: 'graine $graine');
        expect(mot, matches(r'[A-Z]'), reason: 'graine $graine');
        expect(mot, matches(r'[0-9]'), reason: 'graine $graine');
        expect(
          mot.split('').any((c) => !RegExp(r'[a-zA-Z0-9]').hasMatch(c)),
          isTrue,
          reason: 'aucun symbole, graine $graine',
        );
      }
    });

    test('le mélange ne laisse pas les classes à leur position d\'origine', () {
      // Sans le mélange de Fisher-Yates, les premiers caractères trahiraient
      // toujours l'ordre des classes: minuscule, majuscule, chiffre, symbole.
      var trouve = false;
      for (var graine = 0; graine < 50 && !trouve; graine++) {
        final mot = generatePassword(length: 20, random: Random(graine));
        if (!RegExp(r'^[a-z]').hasMatch(mot)) {
          trouve = true;
        }
      }
      expect(trouve, isTrue);
    });
  });
}
