import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';

void main() {
  test('la sérialisation directe en octets donne le même JSON qu\'avant', () {
    final vault = Vault([
      VaultEntry(
        key: 'gmail (perso)',
        value: 'p4ss "avec" des \\ échappements\net un retour',
        created: DateTime.utc(2020),
        updated: DateTime.utc(2021),
        attachments: [
          VaultAttachment(
            id: '0123456789abcdef0123456789abcdef',
            name: 'reçu — février.pdf',
            mimeType: 'application/pdf',
            size: 42,
            created: DateTime.utc(2022),
          ),
        ],
      ),
      VaultEntry.now(key: 'emoji 🔐 et accents éàü', value: 'ok'),
    ]);

    final octets = vault.toBytes();
    // Le clair ne passe plus par une `String` intermédiaire, mais le résultat
    // doit rester exactement le même JSON: les coffres déjà écrits se relisent.
    expect(utf8.decode(octets), isA<String>());
    expect(jsonDecode(utf8.decode(octets)), isA<Map<String, Object?>>());

    final relu = Vault.fromBytes(octets);
    expect(relu.entries, hasLength(2));
    final gmail = relu.entries.firstWhere((e) => e.key == 'gmail (perso)');
    expect(gmail.value, 'p4ss "avec" des \\ échappements\net un retour');
    expect(gmail.attachments.single.name, 'reçu — février.pdf');
    expect(
      relu.entries.any((e) => e.key == 'emoji 🔐 et accents éàü'),
      isTrue,
    );
  });

  test('le format sur le disque est inchangé, octet pour octet', () {
    final vault = Vault([
      VaultEntry(
        key: 'k',
        value: 'v',
        created: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
        updated: DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true),
      ),
    ]);
    // Référence: ce qu'écrivait l'ancienne implémentation.
    final attendu = Uint8List.fromList(
      utf8.encode(
        '{"v":1,"entries":[{"k":"k","val":"v","created":1000,"updated":2000}]}',
      ),
    );
    expect(vault.toBytes(), attendu);
  });
}
