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

  test('un appel abouti est rapporté comme tel', () async {
    expect(await const ScreenSecurity().setBlocked(true), isTrue);
  });

  test('une plateforme sans implémentation rapporte un échec', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(screenSecurityChannel, (call) async {
      throw MissingPluginException('non implémenté');
    });
    // Sans retour, l'interface affiche « captures bloquées » alors qu'elles ne
    // le sont pas: pour un coffre-fort, une protection silencieusement absente
    // est pire qu'une erreur visible.
    expect(await const ScreenSecurity().setBlocked(true), isFalse);
  });

  test('un échec côté natif rapporte un échec', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(screenSecurityChannel, (call) async {
      throw PlatformException(code: 'erreur');
    });
    expect(await const ScreenSecurity().setBlocked(true), isFalse);
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
