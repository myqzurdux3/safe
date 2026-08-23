import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/l10n/app_localizations.dart';
import 'package:safe/storage/app_settings.dart';
import 'package:safe/ui/settings_screen.dart';
import 'package:safe/ui/theme/safe_theme.dart';

import '../support/session_fixture.dart';

void main() {
  testWidgets('le réglage de langue est là, sur « Système » par défaut', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(
      wrapScreen(
        SettingsScreen(session: session, settings: MemorySettingsStore()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('language')), findsOneWidget);
    expect(find.text('Système'), findsOneWidget);
    session.lock();
  });

  testWidgets('choisir English bascule l\'écran, sans le quitter', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    final langue = ValueNotifier(AppLanguage.system);
    final store = MemorySettingsStore();

    // L'application entière, pour que le changement de langue se propage:
    // c'est `MaterialApp` qui écoute le notifieur.
    await tester.pumpWidget(
      ValueListenableBuilder<AppLanguage>(
        valueListenable: langue,
        builder: (context, valeur, _) => MaterialApp(
          theme: safeLightTheme(),
          locale: valeur.locale ?? const Locale('fr'),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: SettingsScreen(
            session: session,
            settings: store,
            language: langue,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Réglages'), findsOneWidget);

    await tester.tap(find.byKey(const Key('language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    // L'écran lui-même a changé de langue: pas besoin de relancer.
    expect(langue.value, AppLanguage.english);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Réglages'), findsNothing);
    session.lock();
  });

  testWidgets('le choix est écrit dans les réglages', (tester) async {
    final session = await makeUnlockedSession();
    final store = MemorySettingsStore();
    final langue = ValueNotifier(AppLanguage.system);

    await tester.pumpWidget(
      wrapScreen(
        SettingsScreen(session: session, settings: store, language: langue),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    // Persisté: sinon la langue serait à rechoisir à chaque lancement.
    expect((await store.read()).language, AppLanguage.english);
    session.lock();
  });

  test('le code de langue relu du disque, et ce qu\'il devient', () {
    expect(AppLanguage.fromCode('en'), AppLanguage.english);
    expect(AppLanguage.fromCode('fr'), AppLanguage.french);
    expect(AppLanguage.fromCode('system'), AppLanguage.system);
    // Un code inconnu ou absent ne doit pas rendre l'application illisible.
    expect(AppLanguage.fromCode('klingon'), AppLanguage.system);
    expect(AppLanguage.fromCode(null), AppLanguage.system);
    expect(AppLanguage.fromCode(42), AppLanguage.system);
  });
}
