import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/util/clipboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String?> ecrits;
  late Object? lectureRendue;
  late bool lectureLeve;

  setUp(() {
    ecrits = [];
    lectureRendue = <String, Object?>{'text': ''};
    lectureLeve = false;
    SecureClipboard.resetNativeProbe();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              final arguments = call.arguments as Map<Object?, Object?>;
              ecrits.add(arguments['text'] as String?);
              return null;
            case 'Clipboard.getData':
              if (lectureLeve) {
                throw PlatformException(code: 'refusé');
              }
              return lectureRendue;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('efface quand le presse-papier contient encore notre valeur', () async {
    final clipboard = SecureClipboard();
    await clipboard.copy('p4ss');
    lectureRendue = <String, Object?>{'text': 'p4ss'};
    await clipboard.clearNow();
    expect(ecrits, ['p4ss', '']);
    clipboard.dispose();
  });

  test('n\'efface pas ce que l\'utilisateur a copié entre-temps', () async {
    final clipboard = SecureClipboard();
    await clipboard.copy('p4ss');
    lectureRendue = <String, Object?>{'text': 'autre chose'};
    await clipboard.clearNow();
    expect(ecrits, ['p4ss']);
    clipboard.dispose();
  });

  test('efface quand même si la lecture est refusée', () async {
    // Depuis Android 10, lire le presse-papier échoue quand l'app n'a pas le
    // focus — exactement le cas nominal: on copie, on bascule vers le
    // navigateur, la minuterie se déclenche. Ne rien faire y laisserait le
    // secret indéfiniment.
    final clipboard = SecureClipboard();
    await clipboard.copy('p4ss');
    lectureRendue = null;
    await clipboard.clearNow();
    expect(ecrits, ['p4ss', '']);
    clipboard.dispose();
  });

  test('efface quand même si la lecture lève', () async {
    final clipboard = SecureClipboard();
    await clipboard.copy('p4ss');
    lectureLeve = true;
    await clipboard.clearNow();
    expect(ecrits, ['p4ss', '']);
    clipboard.dispose();
  });

  test('sans rien copié, n\'efface rien', () async {
    final clipboard = SecureClipboard();
    await clipboard.clearNow();
    expect(ecrits, isEmpty);
    clipboard.dispose();
  });
}
