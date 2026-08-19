import 'package:flutter_test/flutter_test.dart';
import 'package:safe/state/generator_session.dart';
import 'package:safe/util/password_generator.dart';

import '../support/session_fixture.dart';

void main() {
  test('les défauts sont 20 caractères et « + symboles »', () async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    expect(gen.length, 20);
    expect(gen.set, CharacterSet.all);
    expect(gen.value.length, 20);
    expect(gen.history, isEmpty);
    vault.lock();
  });

  test('régénérer pousse la valeur précédente dans l\'historique', () async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    final premiere = gen.value;
    gen.regenerate();
    expect(gen.history, [premiere]);
    expect(gen.value, isNot(premiere));
    vault.lock();
  });

  test('l\'historique ne garde que trois valeurs', () async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    for (var i = 0; i < 6; i++) {
      gen.regenerate();
    }
    expect(gen.history.length, 3);
    vault.lock();
  });

  test('changer la longueur régénère immédiatement', () async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    gen.setLength(32);
    expect(gen.length, 32);
    expect(gen.value.length, 32);
    vault.lock();
  });

  test('changer de jeu régénère avec le nouveau jeu', () async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    gen.setSet(CharacterSet.letters);
    expect(gen.set, CharacterSet.letters);
    expect(gen.value.contains(RegExp('[0-9]')), isFalse);
    vault.lock();
  });

  test('le verrouillage vide l\'historique et la valeur', () async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    gen.regenerate();
    gen.regenerate();
    expect(gen.history, isNotEmpty);

    vault.lock();
    await Future<void>.delayed(Duration.zero);

    expect(gen.history, isEmpty);
    expect(gen.value, isEmpty);
  });

  test('les auditeurs sont prévenus à chaque changement', () async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    var avis = 0;
    gen.addListener(() => avis++);
    gen.regenerate();
    gen.setLength(24);
    gen.setSet(CharacterSet.letters);
    expect(avis, 3);
    vault.lock();
  });

  test('l\'historique n\'est pas modifiable de l\'extérieur', () async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    gen.regenerate();
    expect(() => gen.history.add('injection'), throwsUnsupportedError);
    vault.lock();
  });
}
