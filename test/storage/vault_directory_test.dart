import 'package:flutter_test/flutter_test.dart';
import 'package:safe/storage/vault_file.dart';

void main() {
  test('un environnement sans HOME ni XDG_DATA_HOME est refusé clairement', () {
    // L'interpolation d'un `null` donnait le chemin littéral
    // `null/.local/share/safe`, relatif au répertoire courant: le coffre
    // atterrissait n'importe où, sans que rien ne le signale.
    expect(
      () => VaultFile.linuxDirectory(const {}),
      throwsA(isA<StateError>()),
    );
  });

  test('XDG_DATA_HOME est respecté', () {
    expect(
      VaultFile.linuxDirectory(const {'XDG_DATA_HOME': '/data'}).path,
      '/data/safe',
    );
  });

  test('sans XDG_DATA_HOME, on retombe sur HOME', () {
    expect(
      VaultFile.linuxDirectory(const {'HOME': '/home/moi'}).path,
      '/home/moi/.local/share/safe',
    );
  });

  test('un XDG_DATA_HOME vide est ignoré', () {
    expect(
      VaultFile.linuxDirectory(const {
        'XDG_DATA_HOME': '',
        'HOME': '/home/moi',
      }).path,
      '/home/moi/.local/share/safe',
    );
  });
}
