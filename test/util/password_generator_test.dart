import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/util/password_generator.dart';

void main() {
  test('les caractères ambigus sont exclus de tous les jeux', () {
    for (final set in CharacterSet.values) {
      for (final ambigu in ['l', 'I', 'O', '0', '1']) {
        expect(
          set.alphabet.contains(ambigu),
          isFalse,
          reason: '$ambigu ne doit pas être dans ${set.name}',
        );
      }
    }
  });

  test('les alphabets sont exactement ceux du handoff', () {
    const lettres = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ';
    expect(CharacterSet.letters.alphabet, lettres);
    expect(
      CharacterSet.lettersDigits.alphabet,
      '$lettres'
      '23456789',
    );
    expect(
      CharacterSet.all.alphabet,
      '$lettres'
      '23456789'
      '!#\$%&*+-?@',
    );
  });

  test('les libellés sont ceux des pastilles', () {
    expect(CharacterSet.letters.label, 'Lettres');
    expect(CharacterSet.lettersDigits.label, '+ chiffres');
    expect(CharacterSet.all.label, '+ symboles');
  });

  test('les bornes vont de 8 à 48', () {
    expect(minPasswordLength, 8);
    expect(maxPasswordLength, 48);
    expect(generatePassword(length: 8).length, 8);
    expect(generatePassword(length: 48).length, 48);
    expect(() => generatePassword(length: 7), throwsArgumentError);
    expect(() => generatePassword(length: 49), throwsArgumentError);
  });

  test('chaque classe du jeu apparaît au moins une fois', () {
    for (var essai = 0; essai < 40; essai++) {
      final mot = generatePassword(length: 20);
      expect(mot.contains(RegExp('[a-z]')), isTrue);
      expect(mot.contains(RegExp('[A-Z]')), isTrue);
      expect(mot.contains(RegExp('[2-9]')), isTrue);
      expect(mot.contains(RegExp(r'[!#$%&*+\-?@]')), isTrue);
    }
  });

  test('le mot de passe ne tire que dans l\'alphabet de son jeu', () {
    final mot = generatePassword(length: 48, set: CharacterSet.letters);
    for (final caractere in mot.split('')) {
      expect(CharacterSet.letters.alphabet.contains(caractere), isTrue);
    }
  });

  test('deux tirages diffèrent', () {
    expect(generatePassword(), isNot(generatePassword()));
  });

  test('un générateur injecté rend un tirage reproductible', () {
    final a = generatePassword(length: 20, random: Random(7));
    final b = generatePassword(length: 20, random: Random(7));
    expect(a, b);
  });
}
