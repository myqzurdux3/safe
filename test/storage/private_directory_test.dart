import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/storage/blob_store.dart';
import 'package:safe/storage/private_directory.dart';
import 'package:safe/storage/vault_file.dart';

void main() {
  late Directory parent;

  setUp(() async {
    parent = await Directory.systemTemp.createTemp('safe_perms');
  });

  tearDown(() async => parent.delete(recursive: true));

  test('le dossier du coffre n\'est lisible que par son propriétaire', () async {
    final dir = Directory('${parent.path}/safe');
    await VaultFile(dir).write(Uint8List.fromList(List.filled(64, 1)));

    // Sous Linux, un umask ordinaire donne 0755: n'importe quel autre compte de
    // la machine pouvait alors lire le coffre et attaquer Argon2id hors ligne.
    expect(dir.statSync().modeString(), 'rwx------');
  });

  test('le dossier des pièces jointes aussi', () async {
    final dir = Directory('${parent.path}/blobs');
    await BlobFileStore(
      dir,
    ).put('0123456789abcdef0123456789abcdef', Uint8List.fromList([1]));
    expect(dir.statSync().modeString(), 'rwx------');
  });

  test('un dossier déjà en place n\'est pas retouché', () async {
    final dir = Directory('${parent.path}/deja');
    await dir.create(recursive: true);
    await createPrivateDirectory(dir);
    // Rien n'impose de corriger les droits d'un dossier existant: l'utilisateur
    // a peut-être ses raisons, et écraser son choix serait pire.
    expect(dir.existsSync(), isTrue);
  });
}
