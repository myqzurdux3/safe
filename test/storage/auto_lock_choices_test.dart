import 'package:flutter_test/flutter_test.dart';
import 'package:safe/storage/app_settings.dart';

void main() {
  test('un délai hors des choix proposés est ramené à un choix', () {
    // Sinon l'écran de réglages affichait « Après 45 s » avec « 2 min »
    // sélectionné dans la liste: deux vérités pour un seul réglage.
    expect(
      AppSettings.fromJson(const {'autoLockSeconds': 45}).autoLockDelay,
      const Duration(seconds: 30),
    );
    expect(
      AppSettings.fromJson(const {'autoLockSeconds': 119}).autoLockDelay,
      const Duration(minutes: 1),
    );
  });

  test('tout délai relu est l\'un des choix proposés', () {
    for (final seconds in [-10, 0, 1, 29, 30, 31, 60, 90, 120, 300, 86400]) {
      expect(
        autoLockChoices,
        contains(
          AppSettings.fromJson({'autoLockSeconds': seconds}).autoLockDelay,
        ),
        reason: 'pour $seconds s',
      );
    }
  });

  test('les bornes encadrent bien les choix', () {
    expect(autoLockChoices.first, minAutoLockDelay);
    expect(autoLockChoices.last, maxAutoLockDelay);
    expect(autoLockChoices, contains(defaultAutoLockDelay));
  });
}
