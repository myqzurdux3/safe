import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';

void main() {
  test('aller-retour JSON', () {
    final vault = Vault([
      VaultEntry(
        key: 'gmail',
        value: 'p4ss',
        created: DateTime.utc(2020),
        updated: DateTime.utc(2020),
      ),
    ]);
    final restored = Vault.fromBytes(vault.toBytes());
    expect(restored.entries.single.key, 'gmail');
    expect(restored.entries.single.value, 'p4ss');
    expect(restored.entries.single.created, DateTime.utc(2020));
  });

  test('clefs unicode et valeur vide survivent', () {
    final vault = Vault([VaultEntry.now(key: 'clé 🔐', value: '')]);
    final restored = Vault.fromBytes(vault.toBytes());
    expect(restored.entries.single.key, 'clé 🔐');
    expect(restored.entries.single.value, '');
  });

  test('upsert remplace une clef existante et trie', () {
    var vault = Vault.empty;
    vault = vault.upsert(VaultEntry.now(key: 'b', value: '1'));
    vault = vault.upsert(VaultEntry.now(key: 'a', value: '2'));
    vault = vault.upsert(VaultEntry.now(key: 'b', value: '3'));
    expect(vault.entries.map((e) => e.key), ['a', 'b']);
    expect(vault.entries.last.value, '3');
  });

  test('upsert conserve la date de création', () {
    final origine = VaultEntry(
      key: 'a',
      value: '1',
      created: DateTime.utc(2020),
      updated: DateTime.utc(2020),
    );
    final vault = Vault.empty
        .upsert(origine)
        .upsert(VaultEntry.now(key: 'a', value: '2'));
    expect(vault.entries.single.created, DateTime.utc(2020));
    expect(vault.entries.single.updated.isAfter(DateTime.utc(2020)), isTrue);
  });

  test('remove enlève la clef', () {
    final vault = Vault.empty
        .upsert(VaultEntry.now(key: 'a', value: '1'))
        .upsert(VaultEntry.now(key: 'b', value: '2'))
        .remove('a');
    expect(vault.entries.map((e) => e.key), ['b']);
  });

  test('version inconnue rejetée', () {
    final bytes = Uint8List.fromList(utf8.encode('{"v":99,"entries":[]}'));
    expect(() => Vault.fromBytes(bytes), throwsFormatException);
  });

  test('JSON illisible rejeté en FormatException', () {
    final bytes = Uint8List.fromList(utf8.encode('pas du json'));
    expect(() => Vault.fromBytes(bytes), throwsFormatException);
  });

  test('recherche insensible à la casse', () {
    final vault = Vault.empty.upsert(VaultEntry.now(key: 'Gmail', value: 'x'));
    expect(vault.search('gma').single.key, 'Gmail');
    expect(vault.search('  '), hasLength(1));
    expect(vault.search('zzz'), isEmpty);
  });
}
