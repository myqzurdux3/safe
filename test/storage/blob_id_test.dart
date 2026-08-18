import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/storage/blob_store.dart';

void main() {
  group('BlobFileStore refuse un identifiant qui sort du dossier', () {
    late Directory racine;
    late BlobFileStore store;

    setUp(() async {
      racine = await Directory.systemTemp.createTemp('safe_blob_id');
      store = BlobFileStore(Directory('${racine.path}/blobs'));
    });

    tearDown(() async => racine.delete(recursive: true));

    test('delete ne remonte pas d\'un cran', () async {
      final victime = File('${racine.path}/victime.blob')
        ..writeAsBytesSync([9]);
      await expectLater(
        store.delete('../victime'),
        throwsA(isA<ArgumentError>()),
      );
      expect(victime.existsSync(), isTrue);
    });

    test('put n\'écrit pas hors du dossier', () async {
      await expectLater(
        store.put('../ecrit', Uint8List.fromList([1])),
        throwsA(isA<ArgumentError>()),
      );
      expect(File('${racine.path}/ecrit.blob').existsSync(), isFalse);
    });

    test('get refuse un chemin absolu', () {
      // `get` lève sans même construire de future: le chemin est refusé avant
      // toute entrée/sortie.
      expect(() => store.get('/etc/passwd'), throwsArgumentError);
    });

    test('un identifiant normal passe', () async {
      const id = '0123456789abcdef0123456789abcdef';
      await store.put(id, Uint8List.fromList([7]));
      expect(await store.get(id), [7]);
    });
  });

  test(
    'un coffre dont un identifiant de pièce jointe est trafiqué est refusé',
    () {
      final bytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'v': 1,
            'entries': [
              {
                'k': 'gmail',
                'val': 'p4ss',
                'created': 0,
                'updated': 0,
                'att': [
                  {
                    'id': '../../../../etc/passwd',
                    'name': 'x',
                    'mime': 'text/plain',
                    'size': 1,
                    'created': 0,
                  },
                ],
              },
            ],
          }),
        ),
      );
      // Le contenu du coffre est authentifié, mais il peut venir d'un tiers:
      // l'import accepte un fichier étranger avec son mot de passe.
      expect(() => Vault.fromBytes(bytes), throwsFormatException);
    },
  );
}
