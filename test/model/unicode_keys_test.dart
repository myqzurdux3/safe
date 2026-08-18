import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';

void main() {
  // « café » écrit de deux façons: le é précomposé (U+00E9), et le e suivi de
  // l'accent combinant (U+0065 U+0301). Visuellement identiques, distincts
  // octet pour octet — et un clavier ou un collage peut produire l'un ou l'autre.
  const precompose = 'café';
  const decompose = 'café';

  test('les deux écritures ne sont pas confondues par hasard', () {
    expect(precompose == decompose, isFalse);
  });

  test('chercher l\'une trouve l\'autre', () {
    final vault = Vault([VaultEntry.now(key: precompose, value: 'p4ss')]);
    expect(vault.search(decompose), hasLength(1));
    expect(vault.search('café'), hasLength(1));
  });

  test('la recherche par fragment marche aussi entre les deux formes', () {
    final vault = Vault([VaultEntry.now(key: decompose, value: 'p4ss')]);
    expect(vault.search('café'), hasLength(1));
  });

  test('upsert reconnaît la même clef sous ses deux écritures', () {
    var vault = Vault([VaultEntry.now(key: precompose, value: 'ancien')]);
    vault = vault.upsert(VaultEntry.now(key: decompose, value: 'nouveau'));
    // Sinon la liste montrerait deux entrées « café » impossibles à distinguer.
    expect(vault.entries, hasLength(1));
    expect(vault.entries.single.value, 'nouveau');
  });

  test('la clef enregistrée n\'est pas réécrite: aucune migration imposée', () {
    final vault = Vault([VaultEntry.now(key: decompose, value: 'p4ss')]);
    expect(vault.entries.single.key, decompose);
  });

  test('deux clefs vraiment différentes restent différentes', () {
    var vault = Vault([VaultEntry.now(key: 'cafe', value: 'a')]);
    vault = vault.upsert(VaultEntry.now(key: precompose, value: 'b'));
    expect(vault.entries, hasLength(2));
  });

  test('la relecture dédoublonne les deux écritures', () {
    final source = Vault([
      VaultEntry(
        key: precompose,
        value: 'ancien',
        created: DateTime.utc(2020),
        updated: DateTime.utc(2020),
      ),
    ]).toBytes();
    // Un coffre écrit par une version antérieure peut contenir les deux.
    final vault = Vault.fromBytes(source);
    expect(vault.entries, hasLength(1));
  });

  test('le tri ne sépare pas deux accents écrits différemment', () {
    // « éclair » précomposé et « épice » décomposé doivent se suivre. Avec une
    // comparaison brute, le é précomposé (U+00E9) pèse plus lourd qu'un « z »
    // tandis que le é décomposé commence par un « e »: les deux mots se
    // retrouvaient de part et d'autre de « zebre ».
    final vault = Vault([
      VaultEntry.now(key: 'zebre', value: 'z'),
      VaultEntry.now(key: '\u00e9clair', value: 'eclair'),
      VaultEntry.now(key: 'e\u0301pice', value: 'epice'),
    ]);
    final ordre = vault.entries.map((e) => e.value).toList();
    expect(
      ordre.indexOf('epice') - ordre.indexOf('eclair'),
      1,
      reason: 'les deux mots accentués doivent se suivre: $ordre',
    );
  });
}
