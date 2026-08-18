import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/storage/app_settings.dart';
import 'package:safe/ui/settings_screen.dart';
import 'package:safe/util/screen_security.dart';

import '../support/session_fixture.dart';

/// Un blocage d'écran qui échoue, sur une plateforme qui sait pourtant le
/// faire — le cas où il faut le dire à l'utilisateur.
class _EcranRefusant implements ScreenSecurity {
  @override
  bool get isSupported => true;

  @override
  Future<bool> setBlocked(bool blocked) async => false;
}

/// Réglages dont l'écriture échoue: disque plein, permissions.
class _ReglagesEnPanne implements SettingsStore {
  @override
  Future<AppSettings> read() async => const AppSettings();

  @override
  Future<void> write(AppSettings settings) async {
    throw const FileSystemException('disque plein');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'un blocage refusé par le système est dit, pas affiché comme acquis',
    (tester) async {
      final session = await makeUnlockedSession();
      await tester.pumpWidget(
        wrapScreen(
          SettingsScreen(
            session: session,
            settings: MemorySettingsStore(
              const AppSettings(blockScreenshots: false),
            ),
            screen: _EcranRefusant(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('block-screenshots')));
      await tester.pumpAndSettle();

      // L'interrupteur ne doit pas rester sur « bloqué » alors que rien ne l'est.
      final bascule = tester.widget<SwitchListTile>(
        find.byKey(const Key('block-screenshots')),
      );
      expect(bascule.value, isFalse);
      expect(find.textContaining('refusé'), findsOneWidget);
      session.lock();
    },
  );

  testWidgets(
    'un réglage qui ne s\'écrit pas ne s\'affiche pas comme enregistré',
    (tester) async {
      final session = await makeUnlockedSession();
      await tester.pumpWidget(
        wrapScreen(
          SettingsScreen(session: session, settings: _ReglagesEnPanne()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('auto-lock')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 s').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('non enregistré'), findsOneWidget);
      session.lock();
    },
  );
}
