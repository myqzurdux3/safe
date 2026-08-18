import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';

void main() {
  // Forme imposée aux identifiants: 32 caractères hexadécimaux.
  const idA = '0123456789abcdef0123456789abcdef';
  const idB = 'fedcba9876543210fedcba9876543210';
  VaultAttachment attachment({String id = idA}) => VaultAttachment(
    id: id,
    name: 'photo.jpg',
    mimeType: 'image/jpeg',
    size: 1234,
    created: DateTime.utc(2020),
  );

  test('les pièces jointes survivent à l\'aller-retour JSON', () {
    final vault = Vault.empty.upsert(
      VaultEntry.now(
        key: 'passeport',
        value: 'numéro',
        attachments: [attachment()],
      ),
    );
    final restored = Vault.fromBytes(vault.toBytes());
    final restauree = restored.entries.single.attachments.single;
    expect(restauree.id, idA);
    expect(restauree.name, 'photo.jpg');
    expect(restauree.mimeType, 'image/jpeg');
    expect(restauree.size, 1234);
    expect(restauree.created, DateTime.utc(2020));
  });

  test('une entrée sans pièce jointe reste lisible', () {
    final vault = Vault.empty.upsert(VaultEntry.now(key: 'a', value: 'v'));
    expect(Vault.fromBytes(vault.toBytes()).entries.single.attachments, isEmpty);
  });

  test('un coffre écrit avant les pièces jointes reste lisible', () {
    // Le champ est optionnel: pas de migration pour les coffres existants.
    const ancien =
        '{"v":1,"entries":[{"k":"a","val":"v","created":0,"updated":0}]}';
    final vault = Vault.fromBytes(
      Uint8List.fromList(utf8.encode(ancien)),
    );
    expect(vault.entries.single.attachments, isEmpty);
  });

  test('upsert conserve les pièces jointes fournies', () {
    var vault = Vault.empty.upsert(
      VaultEntry.now(key: 'a', value: 'v', attachments: [attachment()]),
    );
    vault = vault.upsert(
      VaultEntry.now(
        key: 'a',
        value: 'v2',
        attachments: [attachment(), attachment(id: idB)],
      ),
    );
    expect(vault.entries.single.attachments, hasLength(2));
    expect(vault.entries.single.value, 'v2');
  });

  test('valeur multiligne conservée telle quelle', () {
    final vault = Vault.empty.upsert(
      VaultEntry.now(key: 'note', value: 'ligne 1\nligne 2\n\nligne 4'),
    );
    expect(
      Vault.fromBytes(vault.toBytes()).entries.single.value,
      'ligne 1\nligne 2\n\nligne 4',
    );
  });
}
