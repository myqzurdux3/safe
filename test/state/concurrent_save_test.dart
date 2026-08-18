import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/util/clipboard.dart';

import '../support/session_fixture.dart';

/// Pièces jointes en mémoire dont l'écriture peut être suspendue: une pièce
/// jointe de 25 Mio met du temps à partir sur le disque, et l'utilisateur peut
/// enregistrer autre chose pendant ce temps.
class GatedBlobStore extends MemoryBlobStore {
  final gate = Completer<void>();

  @override
  Future<void> put(String id, Uint8List bytes) async {
    await gate.future;
    return super.put(id, bytes);
  }
}

void main() {
  test('une sauvegarde pendant l\'écriture d\'une pièce jointe n\'est pas perdue',
      () async {
    final blobs = GatedBlobStore();
    final session = VaultSession(
      crypto: await testCrypto(),
      storage: MemoryVaultStore(),
      blobs: blobs,
      clipboard: SecureClipboard(),
      autoLockDelay: const Duration(minutes: 10),
      kdfParams: testKdfParams,
    );
    addTearDown(session.dispose);
    await session.create(testPassword);
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: 'gmail', value: 'p4ss')),
    );

    // La pièce jointe part, et se bloque en cours d'écriture.
    final pending = session.attach(
      entryKey: 'gmail',
      name: 'photo.png',
      mimeType: 'image/png',
      bytes: Uint8List.fromList([1, 2, 3]),
    );

    // Pendant ce temps, l'utilisateur crée une autre entrée.
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: 'banque', value: 's3cret')),
    );

    blobs.gate.complete();
    await pending;

    final clefs = session.vault!.entries.map((e) => e.key).toList();
    expect(clefs, containsAll(['banque', 'gmail']));
    expect(
      session.vault!.entries.firstWhere((e) => e.key == 'gmail').attachments,
      hasLength(1),
    );
  });

  test('deux sauvegardes concurrentes s\'exécutent l\'une après l\'autre',
      () async {
    final store = GatedVaultStore();
    final session = VaultSession(
      crypto: await testCrypto(),
      storage: store,
      blobs: MemoryBlobStore(),
      clipboard: SecureClipboard(),
      autoLockDelay: const Duration(minutes: 10),
      kdfParams: testKdfParams,
    );
    addTearDown(session.dispose);
    await session.create(testPassword);

    final avant = store.writeOrder.length;
    final gate = Completer<void>();
    store.gate = gate;
    final premiere = session.save(
      session.vault!.upsert(VaultEntry.now(key: 'a', value: '1')),
    );
    final seconde = session.save(
      session.vault!.upsert(VaultEntry.now(key: 'b', value: '2')),
    );

    // La seconde ne doit pas être entrée dans le magasin tant que la première
    // n'en est pas sortie: deux écritures en vol se marchent dessus.
    await Future<void>.delayed(Duration.zero);
    expect(
      store.writeOrder.length - avant,
      1,
      reason: 'les deux écritures sont en vol en même temps',
    );

    store.gate = null;
    gate.complete();
    await Future.wait([premiere, seconde]);
  });
}
