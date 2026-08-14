import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/storage/blob_store.dart';
import 'package:safe/storage/vault_file.dart';
import 'package:safe/ui/entries_screen.dart';
import 'package:safe/ui/entry_edit_screen.dart';
import 'package:safe/util/clipboard.dart';

import '../support/session_fixture.dart';

/// Clefs que l'utilisateur a le droit d'écrire. Les parenthèses, y compris
/// déséquilibrées, n'ont aucun statut particulier: rien dans le coffre ne les
/// interprète.
const clefs = [
  'banque (pro)',
  'banque (pro',
  'compte )',
  'wifi (maison) (invités)',
  'a(b)c',
  '(',
  ')',
  '()',
  'clef "guillemets"',
  r'chemin\dossier',
  'clef {accolades} [crochets]',
  'clef\ttabulation',
  'clef  espaces   multiples',
  'émoji 🔐 et accents éàü',
];

/// Clefs volontairement normalisées à la saisie: seuls les espaces de bordure
/// sautent, parce qu'ils sont invisibles et créeraient deux clefs d'apparence
/// identique.
const clefsRognees = {
  ' espace en tête': 'espace en tête',
  'espace en fin ': 'espace en fin',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('modèle: toutes ces clefs survivent au JSON', () {
    var vault = const Vault([]);
    for (final clef in clefs) {
      vault = vault.upsert(VaultEntry.now(key: clef, value: 'v-$clef'));
    }
    final restored = Vault.fromBytes(vault.toBytes());
    expect(restored.entries.length, vault.entries.length);
    for (final entry in vault.entries) {
      expect(
        restored.entries.where((e) => e.key == entry.key).length,
        1,
        reason: 'clef perdue: ${entry.key}',
      );
    }
  });

  test('coffre sur disque: écriture puis relecture de toutes ces clefs',
      () async {
    final dir = await Directory.systemTemp.createTemp('safe_chars');
    addTearDown(() => dir.delete(recursive: true));
    final session = VaultSession(
      crypto: await testCrypto(),
      storage: VaultFile(dir),
      blobs: BlobFileStore(Directory('${dir.path}/blobs')),
      clipboard: SecureClipboard(),
      kdfParams: testKdfParams,
    );
    addTearDown(session.dispose);

    await session.create(testPassword);
    var vault = session.vault!;
    for (final clef in clefs) {
      vault = vault.upsert(VaultEntry.now(key: clef, value: 'v-$clef'));
    }
    await session.save(vault);
    session.lock();
    await session.unlock(testPassword);

    for (final clef in clefs) {
      final trouvee = session.vault!.entries.where((e) => e.key == clef);
      expect(trouvee.length, 1, reason: 'clef perdue sur disque: $clef');
      expect(trouvee.single.value, 'v-$clef');
    }
    session.lock();
  });

  testWidgets('interface: saisie puis relecture de chaque clef', (tester) async {
    for (final clef in clefs) {
      final session = await makeUnlockedSession();
      await tester.pumpWidget(wrapScreen(EntryEditScreen(session: session)));
      await tester.enterText(find.byKey(const Key('key')), clef);
      await tester.enterText(find.byKey(const Key('value')), 'secret');
      await tester.tap(find.byKey(const Key('save')));
      await tester.pumpAndSettle();
      expect(
        session.vault!.entries.length,
        1,
        reason: 'entrée non créée pour: "$clef"',
      );
      expect(
        session.vault!.entries.single.key,
        clef,
        reason: 'clef altérée à la saisie: "$clef"',
      );
      session.lock();
    }
  });

  testWidgets('interface: les espaces de bordure sont rognés, le reste intact', (
    tester,
  ) async {
    for (final entree in clefsRognees.entries) {
      final session = await makeUnlockedSession();
      await tester.pumpWidget(wrapScreen(EntryEditScreen(session: session)));
      await tester.enterText(find.byKey(const Key('key')), entree.key);
      await tester.tap(find.byKey(const Key('save')));
      await tester.pumpAndSettle();
      expect(session.vault!.entries.single.key, entree.value);
      session.lock();
    }
  });

  testWidgets('interface: recherche par fragment contenant des parenthèses', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    var vault = session.vault!;
    for (final clef in clefs) {
      vault = vault.upsert(VaultEntry.now(key: clef, value: 'v'));
    }
    await session.save(vault);
    await tester.pumpWidget(wrapScreen(EntriesScreen(session: session)));

    for (final fragment in ['(pro)', '(', ')', '()', '(maison)']) {
      await tester.enterText(find.byKey(const Key('search')), fragment);
      await tester.pumpAndSettle();
      final attendu = clefs.where((c) => c.contains(fragment)).length;
      expect(
        find.byType(ListTile),
        findsNWidgets(attendu),
        reason: 'recherche "$fragment": $attendu résultats attendus',
      );
    }
    session.lock();
  });
}
