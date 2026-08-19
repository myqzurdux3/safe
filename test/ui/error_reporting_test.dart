import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/ui/attachments_section.dart';
import 'package:safe/ui/entry_screen.dart';

import '../support/session_fixture.dart';

/// Ce que l'utilisateur voit quand une opération échoue.
///
/// Le coffre verrouillé est le déclencheur le plus simple à provoquer, et le
/// plus fréquent en vrai: le délai d'inactivité expire pendant qu'une boîte de
/// confirmation est ouverte.
void main() {
  testWidgets('une suppression impossible est dite, pas passée sous silence', (
    tester,
  ) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(
      wrapScreen(
        EntryScreen(
          session: session,
          entry: session.vault!.entries.single,
          settings: MemorySettingsStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('delete-entry')));
    await tester.pumpAndSettle();

    // Le coffre se verrouille pendant que la confirmation est affichée.
    session.lock();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    // Sans `pumpAndSettle`: le toast compte son propre temps, et se laisser
    // porter jusqu'au repos le ferait disparaître avant d'être lu.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Suppression impossible'), findsOneWidget);
  });

  testWidgets('un export impossible est dit', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    final attachment = await session.attach(
      entryKey: 'gmail',
      name: 'note.txt',
      mimeType: 'text/plain',
      bytes: bytesOf('bonjour'),
    );
    await tester.pumpWidget(
      wrapScreen(
        Scaffold(
          body: AttachmentsSection(
            session: session,
            entryKey: 'gmail',
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    session.lock();
    await tester.tap(find.byKey(Key('export-${attachment.id}')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Export impossible'), findsOneWidget);
  });

  testWidgets('un détachement impossible est dit', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    final attachment = await session.attach(
      entryKey: 'gmail',
      name: 'note.txt',
      mimeType: 'text/plain',
      bytes: bytesOf('bonjour'),
    );
    await tester.pumpWidget(
      wrapScreen(
        Scaffold(
          body: AttachmentsSection(
            session: session,
            entryKey: 'gmail',
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('detach-${attachment.id}')));
    await tester.pumpAndSettle();
    session.lock();
    await tester.tap(find.byKey(const Key('confirm-detach')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Suppression impossible'), findsOneWidget);
  });
}

/// Petit raccourci, les octets d'une chaîne.
Uint8List bytesOf(String texte) => Uint8List.fromList(texte.codeUnits);
