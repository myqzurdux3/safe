import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/ui/theme/safe_theme.dart';
import 'package:safe/ui/widgets/primary_button.dart';

Widget _host(Widget child) => MaterialApp(
  theme: safeLightTheme(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('le bouton primaire fait la hauteur de pilule du handoff', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(SafePrimaryButton(label: 'Déverrouiller', onPressed: () {})),
    );
    expect(
      tester.getSize(find.byType(SafePrimaryButton)).height,
      SafeMetrics.pillHeight,
    );
    expect(find.text('Déverrouiller'), findsOneWidget);
  });

  testWidgets('le bouton primaire appelle son action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(SafePrimaryButton(label: 'Enregistrer', onPressed: () => taps++)),
    );
    await tester.tap(find.byType(SafePrimaryButton));
    expect(taps, 1);
  });

  testWidgets('sans action, le bouton primaire ne réagit pas', (tester) async {
    await tester.pumpWidget(
      const _HostConst(SafePrimaryButton(label: 'Inerte', onPressed: null)),
    );
    await tester.tap(find.byType(SafePrimaryButton), warnIfMissed: false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le bouton secondaire porte une bordure, pas un aplat', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(SafeSecondaryButton(label: 'Pièce jointe', onPressed: () {})),
    );
    expect(find.text('Pièce jointe'), findsOneWidget);
    expect(
      tester.getSize(find.byType(SafeSecondaryButton)).height,
      SafeMetrics.pillHeight,
    );
  });
}

class _HostConst extends StatelessWidget {
  const _HostConst(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: safeLightTheme(),
    home: Scaffold(body: child),
  );
}
