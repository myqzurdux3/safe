import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/util/clipboard.dart';

import '../support/session_fixture.dart';

/// Une sauvegarde met plusieurs centaines de millisecondes sur un téléphone —
/// le temps d'un chiffrement et d'une écriture. Tout peut arriver pendant.
void main() {
  late GatedVaultStore store;
  late VaultSession session;

  setUp(() async {
    store = GatedVaultStore();
    session = VaultSession(
      crypto: await testCrypto(),
      storage: store,
      blobs: MemoryBlobStore(),
      clipboard: SecureClipboard(),
      autoLockDelay: const Duration(minutes: 10),
      kdfParams: testKdfParams,
    );
    addTearDown(session.dispose);
    await session.create(testPassword);
  });

  test(
    'un verrouillage pendant une sauvegarde ne rouvre pas le coffre',
    () async {
      final gate = Completer<void>();
      store.gate = gate;
      final pending = session.save(
        session.vault!.upsert(VaultEntry.now(key: 'gmail', value: 'p4ss')),
      );

      session.lock();
      expect(session.isUnlocked, isFalse);

      store.gate = null;
      gate.complete();
      await pending;

      // Le coffre doit rester fermé: sinon l'interface réaffiche tout le clair,
      // alors que la clé, elle, a bien été libérée.
      expect(session.isUnlocked, isFalse);
      expect(session.vault, isNull);
    },
  );

  test(
    'un verrouillage pendant la dérivation abandonne le changement',
    () async {
      // La dérivation Argon2id tourne hors de l'isolat d'interface et prend de
      // l'ordre d'une seconde: le coffre peut être verrouillé pendant. Rien
      // n'ayant encore été écrit, on abandonne franchement plutôt que de
      // ré-chiffrer le fichier pour une session déjà fermée.
      final pending = session.changePassword('nouveaumotdepasse');
      session.lock();

      await expectLater(pending, throwsStateError);
      expect(session.isUnlocked, isFalse);

      // L'ancien mot de passe ouvre toujours le coffre: rien n'a bougé.
      await session.unlock(testPassword);
      expect(session.isUnlocked, isTrue);
    },
  );

  test(
    'un verrouillage pendant l\'écriture du nouveau mot de passe ne rouvre pas',
    () async {
      // La dérivation est passée; l'écriture, elle, va au bout — le fichier
      // porte donc le nouveau mot de passe — mais la session reste fermée.
      final gate = Completer<void>();
      final pending = session.changePassword('nouveaumotdepasse');
      await Future<void>.delayed(Duration.zero);
      store.gate = gate;
      await Future<void>.delayed(Duration.zero);
      session.lock();
      store.gate = null;
      gate.complete();
      await pending.catchError((_) {});

      expect(session.isUnlocked, isFalse);
    },
  );

  test(
    'la sauvegarde interrompue par un verrouillage a bien atteint le disque',
    () async {
      final gate = Completer<void>();
      store.gate = gate;
      final pending = session.save(
        session.vault!.upsert(VaultEntry.now(key: 'gmail', value: 'p4ss')),
      );
      session.lock();
      store.gate = null;
      gate.complete();
      await pending;

      // Ce qui a été écrit reste écrit: on ne perd pas la sauvegarde, on refuse
      // seulement de rouvrir la session.
      await session.unlock(testPassword);
      expect(session.vault!.entries.single.key, 'gmail');
    },
  );
}
