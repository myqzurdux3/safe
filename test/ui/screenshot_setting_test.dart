import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/storage/app_settings.dart';
import 'package:safe/ui/settings_screen.dart';
import 'package:safe/util/screen_security.dart';

import '../support/session_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final appels = <bool>[];

  setUp(() {
    appels.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(screenSecurityChannel, (call) async {
      appels.add((call.arguments as Map)['blocked'] as bool);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(screenSecurityChannel, null);
  });

  testWidgets('l\'interrupteur est actif par défaut', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(
      wrapScreen(
        SettingsScreen(session: session, settings: MemorySettingsStore()),
      ),
    );
    await tester.pumpAndSettle();
    final bascule = tester.widget<SwitchListTile>(
      find.byKey(const Key('block-screenshots')),
    );
    expect(bascule.value, isTrue);
    session.lock();
  });

  testWidgets('désactiver prévient le natif et écrit le réglage', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    final store = MemorySettingsStore();
    await tester.pumpWidget(
      wrapScreen(SettingsScreen(session: session, settings: store)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('block-screenshots')));
    await tester.pumpAndSettle();

    expect(appels.last, isFalse);
    expect((await store.read()).blockScreenshots, isFalse);
    session.lock();
  });

  testWidgets('le réglage désactivé est relu à l\'ouverture de l\'écran', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    final store = MemorySettingsStore(
      const AppSettings(blockScreenshots: false),
    );
    await tester.pumpWidget(
      wrapScreen(SettingsScreen(session: session, settings: store)),
    );
    await tester.pumpAndSettle();
    final bascule = tester.widget<SwitchListTile>(
      find.byKey(const Key('block-screenshots')),
    );
    expect(bascule.value, isFalse);
    session.lock();
  });

  testWidgets('réactiver repasse à true', (tester) async {
    final session = await makeUnlockedSession();
    final store = MemorySettingsStore(
      const AppSettings(blockScreenshots: false),
    );
    await tester.pumpWidget(
      wrapScreen(SettingsScreen(session: session, settings: store)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('block-screenshots')));
    await tester.pumpAndSettle();

    expect(appels.last, isTrue);
    expect((await store.read()).blockScreenshots, isTrue);
    session.lock();
  });

  testWidgets('désactiver affiche ce que ça coûte', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(
      wrapScreen(
        SettingsScreen(session: session, settings: MemorySettingsStore()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('block-screenshots')));
    await tester.pumpAndSettle();
    // L'utilisateur doit savoir que la vignette des applications récentes
    // montrera le contenu du coffre.
    expect(find.textContaining('récentes'), findsWidgets);
    session.lock();
  });
}
