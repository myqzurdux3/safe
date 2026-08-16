import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/util/screen_security.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final appels = <MethodCall>[];

  setUp(() {
    appels.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(screenSecurityChannel, (call) async {
      appels.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(screenSecurityChannel, null);
  });

  test('activer envoie blockScreenshots(true)', () async {
    await const ScreenSecurity().setBlocked(true);
    expect(appels.single.method, 'setBlocked');
    expect(appels.single.arguments, {'blocked': true});
  });

  test('désactiver envoie blockScreenshots(false)', () async {
    await const ScreenSecurity().setBlocked(false);
    expect(appels.single.arguments, {'blocked': false});
  });

  test('une plateforme sans implémentation ne fait pas planter l\'app',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(screenSecurityChannel, (call) async {
      throw MissingPluginException('non implémenté');
    });
    // Linux n'a pas d'équivalent de FLAG_SECURE: l'appel doit être sans effet,
    // pas une exception qui remonte dans l'interface.
    await expectLater(const ScreenSecurity().setBlocked(true), completes);
  });
}
