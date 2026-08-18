import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/util/clipboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> natif;
  late List<String?> flutterEcrits;
  late bool natifDisponible;

  setUp(() {
    natif = [];
    flutterEcrits = [];
    natifDisponible = true;
    SecureClipboard.resetNativeProbe();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(sensitiveClipboardChannel, (call) async {
      if (!natifDisponible) {
        throw MissingPluginException('pas d\'implémentation');
      }
      natif.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final arguments = call.arguments as Map<Object?, Object?>;
        flutterEcrits.add(arguments['text'] as String?);
      }
      if (call.method == 'Clipboard.getData') {
        return <String, Object?>{'text': ''};
      }
      return null;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(sensitiveClipboardChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('la copie passe par le canal natif quand il existe', () async {
    final clipboard = SecureClipboard();
    await clipboard.copy('p4ss');

    // Le canal natif marque le presse-papier « sensible »: sans ça, Android 13+
    // affiche le secret dans son aperçu et Gboard le range dans son propre
    // historique, que notre effacement ne touche pas.
    expect(natif.single.method, 'copySensitive');
    expect((natif.single.arguments as Map)['text'], 'p4ss');
    // Et pas deux fois: la copie ne doit pas repasser par Flutter derrière.
    expect(flutterEcrits, isEmpty);
    clipboard.dispose();
  });

  test('sans canal natif, on retombe sur Flutter', () async {
    natifDisponible = false;
    final clipboard = SecureClipboard();
    await clipboard.copy('p4ss');

    // Linux n'a pas d'équivalent: la copie doit marcher quand même.
    expect(flutterEcrits, ['p4ss']);
    clipboard.dispose();
  });

  test('l\'effacement passe aussi par le natif quand il existe', () async {
    final clipboard = SecureClipboard();
    await clipboard.copy('p4ss');
    natif.clear();
    await clipboard.clearNow();
    expect(natif.single.method, 'clear');
    clipboard.dispose();
  });
}
