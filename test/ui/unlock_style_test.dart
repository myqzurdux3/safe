import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/ui/unlock_screen.dart';

import '../support/session_fixture.dart';

/// L'invite d'un champ de mot de passe est un mot, pas un secret.
///
/// Le champ écrit ses caractères en `letter-spacing: .16em` — c'est la
/// maquette, et c'est ce qui rend une suite de points lisible. Mais Flutter
/// fusionne `hintStyle` PAR-DESSUS le style du champ: ce que `hintStyle`
/// n'écrase pas, l'invite en hérite. Sans remise à zéro explicite, « Mot de
/// passe maître » s'affiche « M o t  d e  p a s s e  m a î t r e ».
void main() {
  for (final cas in const [
    (creation: true, invite: 'Mot de passe maître'),
    (creation: true, invite: 'Confirmation'),
    (creation: false, invite: 'Mot de passe maître'),
  ]) {
    testWidgets('l\'invite « ${cas.invite} » n\'hérite pas de '
        'l\'espacement des caractères masqués'
        '${cas.creation ? '' : ' (déverrouillage)'}', (tester) async {
      final session = await makeTestSession();
      await tester.pumpWidget(
        wrapScreen(UnlockScreen(session: session, isCreation: cas.creation)),
      );
      await tester.pumpAndSettle();

      final invite = tester.widget<Text>(find.text(cas.invite));
      expect(
        invite.style?.letterSpacing ?? 0,
        0,
        reason:
            'l\'invite porte l\'espacement des points du champ; elle se lit '
            '« ${cas.invite.split('').join(' ')} »',
      );
    });
  }
}
