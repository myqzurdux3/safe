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

  test('le jeu complet contient au moins un symbole sur un long tirage', () {
    // 128 caractères tirés dans un alphabet dont un quart est symbolique:
    // l'absence de symbole est improbable au point d'être négligeable.
    expect(
      RegExp(r'[^A-Za-z0-9]').hasMatch(generatePassword(length: 128)),
      isTrue,
    );
  });

  test('deux appels donnent des résultats différents', () {
    expect(generatePassword(), isNot(generatePassword()));
  });

  test('longueur hors bornes rejetée', () {
    expect(() => generatePassword(length: 3), throwsArgumentError);
    expect(() => generatePassword(length: 500), throwsArgumentError);
  });
}
