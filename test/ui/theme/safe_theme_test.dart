import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/ui/theme/safe_theme.dart';

void main() {
  test('le thème clair porte les tokens du handoff', () {
    final tokens = safeLightTheme().extension<SafeTokens>();
    expect(tokens, isNotNull);
    expect(tokens!.pageBackground, const Color(0xFFF4F2EE));
    expect(tokens.cardSurface, const Color(0xFFFFFFFF));
    expect(tokens.ink, const Color(0xFF183A2B));
    expect(tokens.accent, const Color(0xFF2F7D5B));
    expect(tokens.accentDark, const Color(0xFF1F6F52));
    expect(tokens.softAccentSurface, const Color(0xFFEAF4EE));
    expect(tokens.secondaryText, const Color(0xFF6B736E));
    expect(tokens.tertiaryText, const Color(0xFF8A918C));
    expect(tokens.hintText, const Color(0xFF7F8781));
    expect(tokens.controlBorder, const Color(0xFFCFD4CE));
    expect(tokens.searchHighlight, const Color(0xFFDFF0E5));
  });

  test('les deux familles de police sont celles déclarées au pubspec', () {
    expect(safeSans, 'InstrumentSans');
    expect(safeMono, 'JetBrainsMono');
    expect(safeLightTheme().textTheme.bodyMedium!.fontFamily, safeSans);
  });

  test('le fond de page est celui du thème, pas le blanc de Material', () {
    expect(safeLightTheme().scaffoldBackgroundColor, const Color(0xFFF4F2EE));
  });

  testWidgets('les tokens se lisent depuis le contexte', (tester) async {
    late SafeTokens seen;
    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: Builder(
          builder: (context) {
            seen = SafeTokens.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(seen.accent, const Color(0xFF2F7D5B));
  });

  test('lerp rend un objet du même type', () {
    final tokens = safeLightTheme().extension<SafeTokens>()!;
    expect(tokens.lerp(tokens, 0.5), isA<SafeTokens>());
  });
}
