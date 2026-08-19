import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/storage/app_settings.dart';
import 'package:safe/ui/widgets/syntax_tutorial.dart';

import '../../support/session_fixture.dart';

/// Des réglages franchement différents des défauts: si quelque chose repartait
/// de `const AppSettings()`, le blocage des captures se rallumerait et le délai
/// de verrouillage passerait de 30 secondes à plusieurs minutes.
const _reglages = AppSettings(
  blockScreenshots: false,
  autoLockDelay: Duration(seconds: 30),
);

/// Un magasin dont la lecture ne rend la main que sur demande.
class _LateSettingsStore implements SettingsStore {
  _LateSettingsStore(this._settings);

  AppSettings _settings;
  final _gate = Completer<void>();

  void repondre() => _gate.complete();

  @override
  Future<AppSettings> read() async {
    await _gate.future;
    return _settings;
  }

  @override
  Future<void> write(AppSettings settings) async => _settings = settings;

  AppSettings get ecrit => _settings;
}

void main() {
  test('sans réglages lus, l\'état part inconnu', () {
    final pref = SyntaxTutorialPreference(MemorySettingsStore());
    addTearDown(pref.dispose);
    expect(pref.visible, isNull);
  });

  test('la lecture décide de l\'affichage', () async {
    final vu = SyntaxTutorialPreference(
      MemorySettingsStore(const AppSettings(syntaxTutorialDismissed: true)),
    );
    addTearDown(vu.dispose);
    await vu.load();
    expect(vu.visible, isFalse);

    final neuf = SyntaxTutorialPreference(MemorySettingsStore());
    addTearDown(neuf.dispose);
    await neuf.load();
    expect(neuf.visible, isTrue);
  });

  test('écarter le tuto ne touche pas aux autres réglages', () async {
    final settings = MemorySettingsStore(_reglages);
    final pref = SyntaxTutorialPreference(settings);
    addTearDown(pref.dispose);
    await pref.load();

    await pref.dismiss();

    final ecrit = await settings.read();
    expect(ecrit.syntaxTutorialDismissed, isTrue);
    expect(ecrit.blockScreenshots, isFalse);
    expect(ecrit.autoLockDelay, const Duration(seconds: 30));
  });

  test('écarter le tuto sans avoir lu les réglages n\'écrit rien', () async {
    // Le cas que la garde protège, et que l'interface seule n'atteint pas: le
    // tuto n'y est affichable qu'une fois la lecture rendue. Écrire ici
    // repartirait de `const AppSettings()` et effacerait les deux réglages de
    // sécurité au profit d'une ligne de tuto.
    final settings = _LateSettingsStore(_reglages);
    final pref = SyntaxTutorialPreference(settings);
    addTearDown(pref.dispose);
    unawaited(pref.load());

    await pref.dismiss();

    expect(pref.visible, isFalse);
    expect(settings.ecrit.syntaxTutorialDismissed, isFalse);
    expect(settings.ecrit.blockScreenshots, isFalse);
    expect(settings.ecrit.autoLockDelay, const Duration(seconds: 30));
    settings.repondre();
  });

  test('« Syntaxe » rappelle le tuto sans rien persister', () async {
    final settings = MemorySettingsStore(
      const AppSettings(syntaxTutorialDismissed: true),
    );
    final pref = SyntaxTutorialPreference(settings);
    addTearDown(pref.dispose);
    await pref.load();
    expect(pref.visible, isFalse);

    pref.recall();

    expect(pref.visible, isTrue);
    // Le rappel est le temps d'un écran: la préférence reste « écarté ».
    expect((await settings.read()).syntaxTutorialDismissed, isTrue);
  });

  test('une lecture qui atterrit après la libération ne prévient personne', () {
    final settings = _LateSettingsStore(_reglages);
    final pref = SyntaxTutorialPreference(settings);
    var avis = 0;
    pref.addListener(() => avis++);
    unawaited(pref.load());
    pref.dispose();

    // Sans la garde, `notifyListeners` sur un objet libéré lève.
    settings.repondre();
    expect(avis, 0);
  });
}
