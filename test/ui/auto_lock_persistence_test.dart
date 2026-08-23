import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/storage/app_settings.dart';
import 'package:safe/ui/settings_screen.dart';

import '../support/session_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('changer le délai l\'écrit dans les réglages', (tester) async {
    final session = await makeUnlockedSession();
    final store = MemorySettingsStore();
    await tester.pumpWidget(
      wrapScreen(SettingsScreen(session: session, settings: store)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('auto-lock')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 s').last);
    await tester.pumpAndSettle();

    expect(session.autoLockDelay, const Duration(seconds: 30));
    expect((await store.read()).autoLockDelay, const Duration(seconds: 30));
    session.lock();
  });

  testWidgets('le délai enregistré est appliqué à l\'ouverture de l\'écran', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    final store = MemorySettingsStore(
      const AppSettings(autoLockDelay: Duration(minutes: 5)),
    );
    await tester.pumpWidget(
      wrapScreen(SettingsScreen(session: session, settings: store)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('5 min'), findsWidgets);
    session.lock();
  });

  testWidgets('« Verrouiller maintenant » ferme la session', (tester) async {
    // Transposé de l'ancienne liste, qui portait un cadenas dans sa barre.
    // Le verrouillage manuel vit désormais à DEUX endroits, par décision du
    // propriétaire: ici, à côté du délai automatique dont il est le pendant,
    // et dans l'en-tête de l'accueil, où il se prend en une tape — c'est le
    // geste qu'on fait quand quelqu'un entre dans la pièce. Les deux chemins
    // ont leur garde; celle de l'accueil est dans home_screen_test.
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(
      wrapScreen(
        SettingsScreen(session: session, settings: MemorySettingsStore()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('lock')));
    await tester.pumpAndSettle();
    expect(session.isUnlocked, isFalse);
  });
}
