import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/ui/settings_screen.dart';

import '../support/session_fixture.dart';

void main() {
  testWidgets('la restauration annonce ce qu\'elle contient avant d\'agir', (
    tester,
  ) async {
    final store = MemoryVaultStore();
    final session = await makeUnlockedSession(store: store);
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: 'gmail', value: 'p4ss')),
    );
    await session.save(session.vault!.remove('gmail'));

    await tester.pumpWidget(
      wrapScreen(SettingsScreen(session: session, settings: null)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('restore-backup')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 entrée(s)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-restore')));
    await tester.pumpAndSettle();

    expect(session.vault!.entries.single.key, 'gmail');
    session.lock();
  });

  testWidgets('annuler ne change rien', (tester) async {
    final store = MemoryVaultStore();
    final session = await makeUnlockedSession(store: store);
    await session.save(
      session.vault!.upsert(VaultEntry.now(key: 'gmail', value: 'p4ss')),
    );
    await session.save(session.vault!.remove('gmail'));

    await tester.pumpWidget(
      wrapScreen(SettingsScreen(session: session, settings: null)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('restore-backup')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-restore')));
    await tester.pumpAndSettle();

    expect(session.vault!.entries, isEmpty);
    session.lock();
  });

  testWidgets('sans sauvegarde, le dit au lieu d\'ouvrir un dialogue', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(
      wrapScreen(SettingsScreen(session: session, settings: null)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('restore-backup')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aucune sauvegarde'), findsOneWidget);
    expect(find.byKey(const Key('confirm-restore')), findsNothing);
    session.lock();
  });
}
