import 'package:flutter/material.dart';

import '../../storage/app_settings.dart';
import '../theme/safe_theme.dart';

/// L'état du tuto de syntaxe, partagé par les deux écrans qui le portent.
///
/// Il vit ici et non dans chaque écran parce qu'il porte une garde de sécurité:
/// **on n'écrit jamais par-dessus des réglages qu'on n'a pas lus**. Repartir des
/// valeurs par défaut pour ranger une ligne de tuto effacerait le blocage des
/// captures d'écran et le délai de verrouillage automatique. Recopiée dans deux
/// écrans, cette garde finit par n'être vérifiée que dans un seul.
class SyntaxTutorialPreference extends ChangeNotifier {
  SyntaxTutorialPreference(this._store);

  /// Nul signifie « ne rien persister », comme partout ailleurs.
  final SettingsStore? _store;

  AppSettings? _settings;
  bool? _visible;
  bool _disposed = false;

  /// Le tuto est-il à l'écran ? `null` tant que les réglages sont inconnus.
  ///
  /// Les écrans s'en servent pour ne rien poser dont la place dépende d'eux:
  /// parier sur une réponse puis se corriger ferait sauter la mise en page —
  /// le tuto qui apparaît chez le nouveau venu, ou la carte qui clignote chez
  /// celui qui a déjà fait « Compris ».
  bool? get visible => _visible;

  Future<void> load() async {
    final loaded = await _store?.read() ?? const AppSettings();
    if (_disposed) {
      return;
    }
    _settings = loaded;
    _visible = !loaded.syntaxTutorialDismissed;
    notifyListeners();
  }

  /// Rappelle le tuto écarté; rien n'est persisté, l'oubli est volontaire.
  void recall() {
    _visible = true;
    notifyListeners();
  }

  /// Écarte le tuto pour de bon.
  Future<void> dismiss() async {
    final current = _settings;
    _visible = false;
    notifyListeners();
    final store = _store;
    // La garde: sans réglages lus, on n'écrit pas.
    if (store == null || current == null) {
      return;
    }
    // Une préférence d'affichage: si l'écriture échoue, le tuto reviendra au
    // prochain lancement, ce qui ne mérite pas d'interrompre la lecture.
    try {
      final updated = current.copyWith(syntaxTutorialDismissed: true);
      _settings = updated;
      await store.write(updated);
    } catch (_) {
      // Sans effet visible ici, et déjà appliqué à l'écran.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Les trois règles de la syntaxe, dans l'ordre où on les rencontre.
const List<(String, String)> _rules = [
  ('courrier:', 'ouvre un bloc'),
  ('(ligne vide)', 'le referme'),
  ('texte seul', 'reste un commentaire, à sa place'),
];

/// Le tuto de syntaxe de la fiche.
///
/// Affiché par défaut, écarté une fois pour toutes par « Compris ». Il porte
/// aussi le geste qui remasque une entrée d'avant la refonte — une valeur d'une
/// seule ligne est un commentaire, donc en clair, jusqu'à ce qu'on lui ajoute
/// une ligne « nom: ».
class SyntaxTutorial extends StatelessWidget {
  const SyntaxTutorial({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.softAccentSurface,
        borderRadius: BorderRadius.circular(SafeMetrics.cardRadius),
      ),
      child: Stack(
        children: [
          // « Compris » fait onze pixels de haut: viser la lettre serait viser
          // un cheveu. La bande basse de la carte — vide sous la troisième
          // règle — écarte le tuto elle aussi, sans que rien ne se déplace à
          // l'écran. Elle est **derrière** le contenu: le libellé reste la
          // cible qu'on désigne, la bande ne fait que rattraper les doigts
          // qui tombent à côté.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: SafeMetrics.touchTarget,
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
              ),
            ),
          ),
          _content(tokens),
        ],
      ),
    );
  }

  Widget _content(SafeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (example, gloss) in _rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // L'exemple est du texte tapé par l'utilisateur: mono,
                  // comme partout où une donnée se relit caractère par
                  // caractère.
                  Text(
                    example,
                    style: const TextStyle(
                      fontFamily: safeMono,
                      fontSize: 11.5,
                      height: 1.4,
                    ).copyWith(color: tokens.accentDark),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      gloss,
                      style: const TextStyle(
                        fontFamily: safeSans,
                        fontSize: 11.5,
                        height: 1.4,
                      ).copyWith(color: tokens.softAccentText),
                    ),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: Padding(
                // Le libellé est aligné à droite: cette marge gauche élargit
                // la cible sans déplacer la lettre d'un pixel.
                padding: const EdgeInsets.only(top: 8, left: 12, bottom: 2),
                child: Text(
                  'Compris',
                  style: SafeText.action.copyWith(
                    fontWeight: FontWeight.w500,
                    color: tokens.accentDark,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
