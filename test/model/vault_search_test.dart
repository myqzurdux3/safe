import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/model/vault_search.dart';

Vault _coffre() => Vault([
  VaultEntry.now(
    key: 'comptes perso',
    value:
        'courrier:\nmoi@example.invalid\nmotdepasse\n\nnote\n\nwifi:\nabcdef',
  ),
  VaultEntry.now(key: 'banque', value: 'identifiant:\n12345678'),
]);

void main() {
  test('une requête vide rend toutes les fiches, sans surlignage', () {
    final hits = searchVault(_coffre(), '');
    expect(hits.length, 2);
    expect(hits.every((h) => h.matchedTitle == null), isTrue);
    expect(hits.every((h) => h.matchedLine == null), isTrue);
  });

  test('le nom de fiche est trouvé', () {
    final hits = searchVault(_coffre(), 'banque');
    expect(hits.single.entry.key, 'banque');
    expect(hits.single.matchedTitle, isNull);
  });

  test('un intertitre de bloc est trouvé, et rendu pour le surlignage', () {
    // « courrier » n'est le nom d'aucune fiche: c'est tout l'intérêt.
    final hits = searchVault(_coffre(), 'courri');
    expect(hits.single.entry.key, 'comptes perso');
    expect(hits.single.matchedTitle, 'courrier');
  });

  test('une ligne de valeur est trouvée', () {
    final hits = searchVault(_coffre(), '12345');
    expect(hits.single.entry.key, 'banque');
    expect(hits.single.matchedLine, '12345678');
  });

  test('le nom l\'emporte sur l\'intertitre, l\'intertitre sur la valeur', () {
    final hits = searchVault(_coffre(), 'wifi');
    expect(hits.single.matchedTitle, 'wifi');
    expect(hits.single.matchedLine, isNull);
  });

  test('le nom l\'emporte vraiment: une fiche dont le nom et un intertitre '
      'correspondent tous deux à la même requête', () {
    // Sans collision réelle entre les deux catégories, ce test passerait
    // même si la priorité était inversée: le nom seul suffirait.
    final coffre = Vault([
      VaultEntry.now(key: 'wifi maison', value: 'wifi:\nabcdef'),
    ]);
    final hits = searchVault(coffre, 'wifi');
    expect(hits.single.entry.key, 'wifi maison');
    expect(hits.single.matchedTitle, isNull);
    expect(hits.single.matchedLine, isNull);
  });

  test('l\'intertitre l\'emporte vraiment: un intertitre et une ligne de '
      'valeur correspondent tous deux à la même requête, sans le nom', () {
    final coffre = Vault([
      VaultEntry.now(key: 'divers', value: 'secret:\nsecret'),
    ]);
    final hits = searchVault(coffre, 'secret');
    expect(hits.single.matchedTitle, 'secret');
    expect(hits.single.matchedLine, isNull);
  });

  test(
    'une fiche n\'apparaît qu\'une fois même si elle correspond partout',
    () {
      final coffre = Vault([
        VaultEntry.now(key: 'test', value: 'test:\ntest\ntest'),
      ]);
      expect(searchVault(coffre, 'test').length, 1);
    },
  );

  test('l\'unicité vaut aussi sans le nom: plusieurs intertitres et plusieurs '
      'lignes de valeur correspondent, la fiche ne compte qu\'une fois', () {
    // Le test précédent court-circuite par le nom ('test' contient
    // 'test'): il ne passe jamais par la branche titre/valeur. Celui-ci
    // l'exerce vraiment, avec deux intertitres et deux lignes matchant.
    final coffre = Vault([
      VaultEntry.now(
        key: 'divers',
        value:
            'test:\nligne1\n\ntest2:\nligne2\n\n'
            'note:\ntestvalue\n\nautre:\ntestautre',
      ),
    ]);
    expect(searchVault(coffre, 'test').length, 1);
  });

  test('la casse et les accents composés sont ignorés', () {
    final coffre = Vault([
      VaultEntry.now(key: 'divers', value: 'Caf\u00e9:\nvaleur'),
    ]);
    // Le même mot écrit avec un accent combinant.
    expect(searchVault(coffre, 'cafe\u0301').single.matchedTitle, 'Caf\u00e9');
    expect(searchVault(coffre, 'CAF\u00c9').single.matchedTitle, 'Caf\u00e9');
  });

  test('une requête sans correspondance ne rend rien', () {
    expect(searchVault(_coffre(), 'zzz'), isEmpty);
  });

  test('l\'ordre du coffre est conservé', () {
    final hits = searchVault(_coffre(), 'e');
    expect(hits.map((h) => h.entry.key).toList(), ['banque', 'comptes perso']);
  });
}
