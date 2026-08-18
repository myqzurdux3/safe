import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';

Uint8List clair(Object? json) =>
    Uint8List.fromList(utf8.encode(jsonEncode(json)));

void main() {
  group('Vault.fromBytes tient son contrat: FormatException, pas TypeError', () {
    test('une entrée qui n\'est pas un objet', () {
      expect(
        () => Vault.fromBytes(clair({'v': 1, 'entries': ['pas un objet']})),
        throwsFormatException,
      );
    });

    test('un champ obligatoire absent', () {
      expect(
        () => Vault.fromBytes(
          clair({
            'v': 1,
            'entries': [
              {'val': 'x', 'created': 0, 'updated': 0},
            ],
          }),
        ),
        throwsFormatException,
      );
    });

    test('un champ du mauvais type', () {
      expect(
        () => Vault.fromBytes(
          clair({
            'v': 1,
            'entries': [
              {'k': 'gmail', 'val': 42, 'created': 0, 'updated': 0},
            ],
          }),
        ),
        throwsFormatException,
      );
    });

    test('un horodatage aberrant', () {
      expect(
        () => Vault.fromBytes(
          clair({
            'v': 1,
            'entries': [
              {'k': 'gmail', 'val': 'x', 'created': 1 << 62, 'updated': 0},
            ],
          }),
        ),
        throwsFormatException,
      );
    });

    test('une liste de pièces jointes qui n\'en est pas une', () {
      expect(
        () => Vault.fromBytes(
          clair({
            'v': 1,
            'entries': [
              {
                'k': 'gmail',
                'val': 'x',
                'created': 0,
                'updated': 0,
                'att': 'non',
              },
            ],
          }),
        ),
        throwsFormatException,
      );
    });
  });

  test('les entrées relues sont triées, même si le fichier ne l\'était pas', () {
    final vault = Vault.fromBytes(
      clair({
        'v': 1,
        'entries': [
          {'k': 'zebre', 'val': 'z', 'created': 0, 'updated': 0},
          {'k': 'ananas', 'val': 'a', 'created': 0, 'updated': 0},
        ],
      }),
    );
    expect(vault.entries.map((e) => e.key), ['ananas', 'zebre']);
  });

  test('deux entrées de même clef: la plus récente gagne, sans tout perdre', () {
    final vault = Vault.fromBytes(
      clair({
        'v': 1,
        'entries': [
          {'k': 'gmail', 'val': 'ancien', 'created': 0, 'updated': 1000},
          {'k': 'gmail', 'val': 'récent', 'created': 0, 'updated': 2000},
        ],
      }),
    );
    // Avant, `upsert` retirait *toutes* les entrées portant la clef puis n'en
    // réinsérait qu'une: les deux disparaissaient.
    expect(vault.entries, hasLength(1));
    expect(vault.entries.single.value, 'récent');
  });

  test('la liste des entrées n\'est pas modifiable de l\'extérieur', () {
    final vault = Vault.empty;
    expect(
      () => vault.entries.add(VaultEntry.now(key: 'x', value: 'y')),
      throwsUnsupportedError,
    );
  });
}
