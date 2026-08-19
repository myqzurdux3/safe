# Refonte de l'interface de safe — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer l'interface de safe par celle du handoff de refonte: le contenu d'une entrée devient du texte libre dont l'affichage en blocs est dérivé à la lecture, le générateur devient un onglet de l'accueil, et le thème passe au clair.

**Architecture:** Un parseur pur (`entry_text.dart`) transforme le texte d'une entrée en groupes; rien de ce qu'il produit n'est persisté. Une couche de thème (`SafeTokens`) porte toutes les couleurs et mesures, qu'aucun écran ne réécrit en dur. Les écrans sont remplacés un par un, l'application restant compilable et la suite verte à chaque commit.

**Tech Stack:** Flutter 3.44.6 / Dart 3.12.2, Material 3, `flutter_test`. Aucune dépendance nouvelle: les polices sont des fichiers embarqués, pas un paquet.

**Spec:** `docs/superpowers/specs/2026-08-19-safe-refonte-design.md`

## Global Constraints

- **Ne jamais réécrire le texte de l'utilisateur.** Le parseur lit, il ne normalise pas, ne réordonne pas, ne complète pas. Le contenu écrit sur le disque est exactement ce qui a été tapé.
- **Rien de dérivé n'est persisté.** Blocs, lignes, compteurs et résultats de recherche sont recalculés à chaque affichage.
- **Aucun littéral de couleur dans un écran.** Tout passe par `SafeTokens`.
- **Les polices ne sont jamais chargées depuis le réseau.** Fichiers embarqués dans `assets/fonts/`, licences OFL incluses.
- **Le format du coffre ne change pas.** `VaultEntry.value` reste une `String`; aucune migration; export et import restent compatibles avec les sauvegardes déjà faites.
- **Le presse-papier passe par `SecureClipboard`**, jamais par `Clipboard.setData` directement: le marquage « sensible » et l'effacement différé sont déjà là.
- **Tests:** test rouge exécuté et constaté rouge avant toute implémentation. La suite entière (`flutter test`) doit être verte avant chaque commit.
- **Émulateur:** toute vérification sur appareil se fait sur `emulator-5554`, jamais sans `-s`. Le téléphone réel porte le coffre de l'utilisateur.
- **Interdits:** `flutter analyze` doit rendre « No issues found! » et `dart format` ne doit rien changer avant chaque commit.
- **Langue:** commentaires, messages d'interface et messages de commit en français, comme le reste du dépôt.

## Structure des fichiers

| Fichier | Responsabilité | Tâche |
| --- | --- | --- |
| `lib/model/entry_text.dart` | Parseur de texte libre en groupes, compteurs | 1 |
| `tool/fetch_fonts.sh` | Télécharge les polices statiques et leurs licences | 2 |
| `assets/fonts/*.ttf`, `assets/fonts/OFL-*.txt` | Polices embarquées | 2 |
| `lib/ui/theme/safe_theme.dart` | `SafeTokens` + `safeLightTheme()` | 2 |
| `lib/ui/safe_logo.dart` | Monogramme S | 3 |
| `lib/ui/widgets/primary_button.dart` | Bouton pilule primaire et secondaire | 4 |
| `lib/ui/unlock_screen.dart` | Déverrouillage restylé | 4 |
| `lib/util/password_generator.dart` | Jeux sans caractères ambigus, bornes 8–48 | 5 |
| `lib/state/generator_session.dart` | Longueur, jeu, valeur, historique en mémoire | 5 |
| `lib/ui/widgets/pill_tabs.dart` | Onglets pilule (accueil et fiche) | 6 |
| `lib/ui/widgets/safe_toast.dart` | Toast « Copié » | 6 |
| `lib/ui/widgets/syntax_tutorial.dart` | Carte de tuto de syntaxe | 6 |
| `lib/ui/widgets/block_card.dart` | Bloc replié/ouvert et commentaire | 6 |
| `lib/ui/entry_screen.dart` | La fiche: lecture / texte brut | 6 |
| `lib/ui/new_entry_screen.dart` | Nouvelle fiche | 7 |
| `lib/model/vault_search.dart` | Recherche noms + intertitres + valeurs | 8 |
| `lib/ui/home_screen.dart` | Accueil: en-tête, onglets, bouton de pied | 9 |
| `lib/ui/vault_tab.dart` | Recherche + liste | 9 |
| `lib/ui/generator_tab.dart` | Générateur plein écran | 9 |
| `lib/ui/settings_screen.dart` | Restylé, structure inchangée | 10 |

Supprimés en fin de parcours: `lib/ui/entry_edit_screen.dart` (tâche 7), `lib/ui/entries_screen.dart` (tâche 9).

---

### Task 1: Le parseur de texte libre

C'est la seule vraie nouveauté logique. Dart pur: aucun `import 'package:flutter'`, aucun état, aucun accès disque.

**Files:**
- Create: `lib/model/entry_text.dart`
- Test: `test/model/entry_text_test.dart`

**Interfaces:**
- Consumes: rien.
- Produces:
  - `class EntryGroup { const EntryGroup({this.title, required this.lines}); final String? title; final List<String> lines; bool get isComment; }`
  - `List<EntryGroup> parseEntryText(String raw)`
  - `int countBlocks(List<EntryGroup> groups)`
  - `int countLines(List<EntryGroup> groups)`
  - `String describeGroups(List<EntryGroup> groups)` → `"5 blocs · 7 lignes"`
  - `const int maxBlockTitleLength = 44;`

- [ ] **Step 1: Écrire le test rouge**

Créer `test/model/entry_text_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/entry_text.dart';

/// Même forme que le texte réel visé par la refonte: des blocs titrés, des
/// commentaires intercalés, l'ordre du document qui compte.
const reference = '''
courrier:
personne@example.invalid
correcthorsebattery

note libre entre deux blocs

banque:
titulaire@example.invalid
double authentification active

deuxieme note libre

wifi:
un-mot-de-passe-quelconque
''';

void main() {
  test('le texte de référence donne cinq groupes dans l\'ordre du document', () {
    final groups = parseEntryText(reference);
    expect(groups.length, 5);

    expect(groups[0].title, 'courrier');
    expect(groups[0].lines, [
      'personne@example.invalid',
      'correcthorsebattery',
    ]);

    expect(groups[1].isComment, isTrue);
    expect(groups[1].lines, ['note libre entre deux blocs']);

    expect(groups[2].title, 'banque');
    expect(groups[2].lines, [
      'titulaire@example.invalid',
      'double authentification active',
    ]);

    expect(groups[3].isComment, isTrue);
    expect(groups[3].lines, ['deuxieme note libre']);

    expect(groups[4].title, 'wifi');
    expect(groups[4].lines, ['un-mot-de-passe-quelconque']);
  });

  test('les compteurs comptent les groupes et les lignes de contenu', () {
    final groups = parseEntryText(reference);
    expect(countBlocks(groups), 5);
    expect(countLines(groups), 7);
    expect(describeGroups(groups), '5 blocs · 7 lignes');
  });

  test('un titre de 44 caractères ouvre un bloc, 45 non', () {
    final court = '${'a' * 43}:'; // 44 caractères avec le deux-points
    expect(court.length, 44);
    expect(parseEntryText('$court\nvaleur').single.title, 'a' * 43);

    final long = '${'a' * 44}:'; // 45 caractères
    expect(long.length, 45);
    final groups = parseEntryText('$long\nvaleur');
    expect(groups.single.isComment, isTrue);
    expect(groups.single.lines, [long, 'valeur']);
  });

  test('une ligne vide ferme le bloc courant', () {
    final groups = parseEntryText('bloc:\nun\n\napres');
    expect(groups.length, 2);
    expect(groups[0].title, 'bloc');
    expect(groups[0].lines, ['un']);
    expect(groups[1].isComment, isTrue);
    expect(groups[1].lines, ['apres']);
  });

  test('les lignes vides consécutives ne créent pas de groupe', () {
    expect(parseEntryText('\n\n\n'), isEmpty);
    expect(parseEntryText(''), isEmpty);
    expect(parseEntryText('   \n\t\n'), isEmpty);
  });

  test('un deux-points seul donne un bloc au titre vide, écarté s\'il est vide', () {
    // Le prototype de référence écarte un groupe dont le titre est vide et qui
    // n'a aucune ligne; il garde le même groupe dès qu'une ligne le suit.
    expect(parseEntryText(':'), isEmpty);
    final groups = parseEntryText(':\nvaleur');
    expect(groups.single.title, '');
    expect(groups.single.lines, ['valeur']);
  });

  test('chaque ligne est nettoyée de ses espaces et de son retour chariot', () {
    // Un texte collé depuis Windows arrive avec des \r en fin de ligne.
    final groups = parseEntryText('bloc:\r\n  valeur  \r\n');
    expect(groups.single.title, 'bloc');
    expect(groups.single.lines, ['valeur']);
  });

  test('un texte sans deux-points est un seul commentaire', () {
    final groups = parseEntryText('juste une note\net sa suite');
    expect(groups.single.isComment, isTrue);
    expect(groups.single.lines, ['juste une note', 'et sa suite']);
  });

  test('le singulier est respecté dans les compteurs', () {
    expect(describeGroups(parseEntryText('un:\nx')), '1 bloc · 1 ligne');
    expect(describeGroups(const []), '0 bloc · 0 ligne');
  });

  test('les groupes rendus ne sont pas modifiables', () {
    final groups = parseEntryText('bloc:\nvaleur');
    expect(() => groups.single.lines.add('injection'), throwsUnsupportedError);
  });
}
```

- [ ] **Step 2: Constater le rouge**

Run: `flutter test test/model/entry_text_test.dart`
Expected: échec de compilation, `Target of URI doesn't exist: 'package:safe/model/entry_text.dart'`.

- [ ] **Step 3: Écrire l'implémentation minimale**

Créer `lib/model/entry_text.dart`:

```dart
/// Lecture du texte libre d'une entrée.
///
/// Une entrée n'est plus « une valeur » mais un bloc de texte: plusieurs
/// services, des codes, des notes. Ce module en dérive une structure
/// d'affichage — des blocs titrés et des commentaires — qui n'est **jamais**
/// écrite sur le disque. Le texte de l'utilisateur reste tel qu'il l'a tapé:
/// ni réécrit, ni normalisé, ni réordonné.
library;

/// Longueur maximale d'une ligne pouvant faire office de titre.
///
/// Au-delà, une ligne finissant par « : » est une phrase, pas un intertitre —
/// une note comme « penser à changer ça avant juin: » ne doit pas ouvrir un
/// bloc.
const int maxBlockTitleLength = 44;

/// Un groupe de lignes: soit un bloc titré, soit un commentaire.
class EntryGroup {
  const EntryGroup({this.title, required this.lines});

  /// Titre du bloc, sans son deux-points. `null` pour un commentaire.
  final String? title;

  /// Lignes de contenu, titre exclu.
  final List<String> lines;

  /// Un groupe sans titre est une note, pas un secret.
  bool get isComment => title == null;
}

/// Découpe [raw] en groupes, dans l'ordre du document.
///
/// Règles, sur chaque ligne débarrassée de ses espaces de bord:
/// 1. Ligne vide: ferme le bloc courant.
/// 2. Ligne de [maxBlockTitleLength] caractères ou moins finissant par « : »:
///    ouvre un bloc titré.
/// 3. Toute autre ligne: rejoint le bloc courant, ou ouvre un commentaire.
/// 4. Les groupes sans titre utile et sans ligne sont écartés.
List<EntryGroup> parseEntryText(String raw) {
  final groups = <_Group>[];
  _Group? current;

  for (final line in raw.split('\n')) {
    // `trim` emporte aussi le retour chariot d'un texte collé depuis Windows.
    final trimmed = line.trim();

    if (trimmed.isEmpty) {
      current = null;
      continue;
    }

    if (trimmed.length <= maxBlockTitleLength && trimmed.endsWith(':')) {
      current = _Group(trimmed.substring(0, trimmed.length - 1));
      groups.add(current);
      continue;
    }

    if (current == null) {
      current = _Group(null);
      groups.add(current);
    }
    current.lines.add(trimmed);
  }

  return [
    for (final group in groups)
      // Un « : » seul ouvre un titre vide: sans ligne derrière, il ne porte
      // rien et n'a rien à afficher.
      if ((group.title?.isNotEmpty ?? false) || group.lines.isNotEmpty)
        EntryGroup(title: group.title, lines: List.unmodifiable(group.lines)),
  ];
}

/// Nombre de groupes, commentaires compris: c'est ce que compte l'en-tête.
int countBlocks(List<EntryGroup> groups) => groups.length;

/// Total des lignes de contenu, titres exclus.
int countLines(List<EntryGroup> groups) =>
    groups.fold(0, (total, group) => total + group.lines.length);

/// Le compteur affiché en en-tête de fiche: « 5 blocs · 7 lignes ».
String describeGroups(List<EntryGroup> groups) {
  final blocks = countBlocks(groups);
  final lines = countLines(groups);
  return '$blocks bloc${blocks > 1 ? 's' : ''} · '
      '$lines ligne${lines > 1 ? 's' : ''}';
}

/// Groupe en cours de construction; l'immuabilité arrive au rendu.
class _Group {
  _Group(this.title);

  final String? title;
  final List<String> lines = [];
}
```

- [ ] **Step 4: Constater le vert**

Run: `flutter test test/model/entry_text_test.dart`
Expected: `+11: All tests passed!`

- [ ] **Step 5: Vérifier la suite entière et la forme**

Run: `flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
Expected: 285 + 11 tests verts, « No issues found! », aucun fichier reformaté.

- [ ] **Step 6: Commit**

```bash
git add lib/model/entry_text.dart test/model/entry_text_test.dart
git commit -m "feat: le texte d'une entrée se lit en blocs

Une entrée n'est plus une valeur mais un bloc de texte libre. Ce
parseur en dérive des blocs titrés et des commentaires, dans l'ordre
du document, sans jamais réécrire le texte ni persister ce qu'il
produit.

Deux détails viennent du prototype de référence et sont testés comme
tels: un titre s'arrête à 44 caractères, et un « : » seul sans ligne
derrière ne produit aucun groupe.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Polices embarquées et couche de thème

**Files:**
- Create: `tool/fetch_fonts.sh`, `assets/fonts/` (5 `.ttf` + 2 licences), `lib/ui/theme/safe_theme.dart`
- Modify: `pubspec.yaml`
- Test: `test/ui/theme/safe_theme_test.dart`

**Interfaces:**
- Consumes: rien.
- Produces:
  - `class SafeTokens extends ThemeExtension<SafeTokens>` avec les champs de couleur listés plus bas et `static SafeTokens of(BuildContext)`.
  - `ThemeData safeLightTheme()`
  - `const String safeSans = 'InstrumentSans';` et `const String safeMono = 'JetBrainsMono';`

- [ ] **Step 1: Écrire le script de récupération des polices**

Créer `tool/fetch_fonts.sh` (le rendre exécutable):

```bash
#!/usr/bin/env bash
# Télécharge les polices de l'interface et leurs licences.
#
# Elles sont embarquées dans le paquet, jamais chargées depuis le réseau: une
# application hors ligne ne doit appeler personne au démarrage. Ce script ne
# sert qu'à les régénérer; les fichiers obtenus sont versionnés.
#
#     bash tool/fetch_fonts.sh
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p assets/fonts

# L'API css2 rend du WOFF à un navigateur moderne et du TrueType à un client
# ancien. Flutter ne lit que le TrueType, d'où l'agent laissé tel quel.
css() {
  curl -sS --fail --max-time 60 -A "curl/7.68.0" \
    "https://fonts.googleapis.com/css2?family=$1"
}

fetch() {
  local url="$1" out="$2"
  echo "  $out"
  curl -sS --fail --max-time 60 -o "assets/fonts/$out" "$url"
}

mapfile -t sans < <(css "Instrument+Sans:wght@400;500;600" | grep -oE 'https://[^)]+\.ttf')
[ "${#sans[@]}" -eq 3 ] || { echo "Instrument Sans: 3 fichiers attendus, ${#sans[@]} reçus" >&2; exit 1; }
fetch "${sans[0]}" InstrumentSans-Regular.ttf
fetch "${sans[1]}" InstrumentSans-Medium.ttf
fetch "${sans[2]}" InstrumentSans-SemiBold.ttf

mapfile -t mono < <(css "JetBrains+Mono:wght@400;500" | grep -oE 'https://[^)]+\.ttf')
[ "${#mono[@]}" -eq 2 ] || { echo "JetBrains Mono: 2 fichiers attendus, ${#mono[@]} reçus" >&2; exit 1; }
fetch "${mono[0]}" JetBrainsMono-Regular.ttf
fetch "${mono[1]}" JetBrainsMono-Medium.ttf

# La licence SIL OFL exige que sa notice accompagne les fichiers.
curl -sS --fail --max-time 60 -o assets/fonts/OFL-InstrumentSans.txt \
  https://raw.githubusercontent.com/google/fonts/main/ofl/instrumentsans/OFL.txt
curl -sS --fail --max-time 60 -o assets/fonts/OFL-JetBrainsMono.txt \
  https://raw.githubusercontent.com/google/fonts/main/ofl/jetbrainsmono/OFL.txt

echo "Polices à jour dans assets/fonts/."
```

- [ ] **Step 2: Exécuter le script et vérifier ce qu'il a écrit**

Run: `bash tool/fetch_fonts.sh && ls -l assets/fonts/ && file assets/fonts/*.ttf`
Expected: 5 fichiers `TrueType Font data`, 2 licences non vides. Si un fichier fait moins de 10 ko, c'est une page d'erreur: arrêter et signaler.

- [ ] **Step 3: Déclarer les polices dans `pubspec.yaml`**

Sous `flutter:`, après le bloc `assets:` existant, ajouter:

```yaml
  fonts:
    # Interface. Embarquées plutôt que chargées depuis Google: l'application est
    # hors ligne et ne doit contacter personne au démarrage.
    - family: InstrumentSans
      fonts:
        - asset: assets/fonts/InstrumentSans-Regular.ttf
          weight: 400
        - asset: assets/fonts/InstrumentSans-Medium.ttf
          weight: 500
        - asset: assets/fonts/InstrumentSans-SemiBold.ttf
          weight: 600
    # Tout ce qui est une donnée stockée s'affiche en chasse fixe, jamais en
    # linéale: une valeur doit se relire caractère par caractère.
    - family: JetBrainsMono
      fonts:
        - asset: assets/fonts/JetBrainsMono-Regular.ttf
          weight: 400
        - asset: assets/fonts/JetBrainsMono-Medium.ttf
          weight: 500
```

Ajouter aussi les licences à la liste `assets:` existante pour qu'elles soient embarquées:

```yaml
    - assets/fonts/OFL-InstrumentSans.txt
    - assets/fonts/OFL-JetBrainsMono.txt
```

- [ ] **Step 4: Écrire le test rouge du thème**

Créer `test/ui/theme/safe_theme_test.dart`:

```dart
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
```

- [ ] **Step 5: Constater le rouge**

Run: `flutter test test/ui/theme/safe_theme_test.dart`
Expected: `Target of URI doesn't exist: 'package:safe/ui/theme/safe_theme.dart'`.

- [ ] **Step 6: Écrire `lib/ui/theme/safe_theme.dart`**

```dart
import 'package:flutter/material.dart';

/// Familles déclarées dans `pubspec.yaml`.
///
/// Règle du handoff: l'interface est en linéale, **tout ce qui est une donnée
/// stockée est en chasse fixe**. Une valeur doit pouvoir se relire caractère
/// par caractère, un « l » ne doit pas ressembler à un « 1 ».
const String safeSans = 'InstrumentSans';
const String safeMono = 'JetBrainsMono';

/// Les couleurs du handoff, nommées par rôle.
///
/// Elles vivent ici et nulle part ailleurs: aucun écran n'écrit de littéral
/// hexadécimal. Changer une teinte se fait donc à un seul endroit, et une
/// palette sombre pourra un jour se poser à côté sans toucher aux écrans.
@immutable
class SafeTokens extends ThemeExtension<SafeTokens> {
  const SafeTokens({
    required this.pageBackground,
    required this.barSurface,
    required this.tabContainer,
    required this.cardSurface,
    required this.secondaryCardSurface,
    required this.softAccentSurface,
    required this.ink,
    required this.accent,
    required this.accentDark,
    required this.onInk,
    required this.secondaryText,
    required this.tertiaryText,
    required this.hintText,
    required this.titlePlaceholder,
    required this.hairline,
    required this.controlBorder,
    required this.strongDivider,
    required this.inactiveBullet,
    required this.commentRule,
    required this.searchHighlight,
  });

  final Color pageBackground;
  final Color barSurface;
  final Color tabContainer;
  final Color cardSurface;
  final Color secondaryCardSurface;
  final Color softAccentSurface;
  final Color ink;
  final Color accent;
  final Color accentDark;
  final Color onInk;
  final Color secondaryText;
  final Color tertiaryText;
  final Color hintText;
  final Color titlePlaceholder;
  final Color hairline;
  final Color controlBorder;
  final Color strongDivider;
  final Color inactiveBullet;
  final Color commentRule;
  final Color searchHighlight;

  static const SafeTokens light = SafeTokens(
    pageBackground: Color(0xFFF4F2EE),
    barSurface: Color(0xFFEAE7E1),
    tabContainer: Color(0xFFE4E1DB),
    cardSurface: Color(0xFFFFFFFF),
    secondaryCardSurface: Color(0xFFEFECE6),
    softAccentSurface: Color(0xFFEAF4EE),
    ink: Color(0xFF183A2B),
    accent: Color(0xFF2F7D5B),
    accentDark: Color(0xFF1F6F52),
    onInk: Color(0xFFF4F2EE),
    secondaryText: Color(0xFF6B736E),
    tertiaryText: Color(0xFF8A918C),
    hintText: Color(0xFF7F8781),
    titlePlaceholder: Color(0xFFA8AEA8),
    hairline: Color(0x12000000),
    controlBorder: Color(0xFFCFD4CE),
    strongDivider: Color(0xFFDCDFDA),
    inactiveBullet: Color(0xFFC3C8C3),
    commentRule: Color(0xFFD3D7D1),
    searchHighlight: Color(0xFFDFF0E5),
  );

  /// Les tokens du thème courant. Lève si l'écran n'est pas sous
  /// [safeLightTheme] — ce qui est un défaut de câblage, pas un cas d'usage.
  static SafeTokens of(BuildContext context) =>
      Theme.of(context).extension<SafeTokens>()!;

  @override
  SafeTokens copyWith() => this;

  /// Les couleurs ne s'animent pas d'un thème à l'autre: il n'y en a qu'un.
  @override
  SafeTokens lerp(ThemeExtension<SafeTokens>? other, double t) =>
      other is SafeTokens ? other : this;
}

/// Rayons et hauteurs du handoff, en un seul endroit.
abstract final class SafeMetrics {
  /// Gouttière gauche et droite, constante sur tous les écrans.
  static const double gutter = 24;

  static const double pillRadius = 25;
  static const double pillHeight = 50;
  static const double cardRadius = 14;
  static const double generatorCardRadius = 18;
  static const double tabContainerRadius = 22;
  static const double tabRadius = 18;
  static const double tabHeight = 36;
  static const double searchHeight = 44;

  /// Cible tactile minimale. Material impose 48 dp sur Android là où le
  /// handoff demandait 44: plus grand ne casse rien, plus petit casse
  /// l'accessibilité.
  static const double touchTarget = 48;

  /// Durée des transitions: ouverture d'un bloc, changement d'onglet, toast.
  static const Duration transition = Duration(milliseconds: 140);
}

/// L'échelle typographique du handoff.
abstract final class SafeText {
  static const screenTitle = TextStyle(
    fontFamily: safeSans,
    fontWeight: FontWeight.w600,
    fontSize: 24,
    height: 1.2,
    letterSpacing: -0.72,
  );

  static const wordmark = TextStyle(
    fontFamily: safeSans,
    fontWeight: FontWeight.w600,
    fontSize: 19,
    height: 1,
    letterSpacing: -0.57,
  );

  static const listTitle = TextStyle(
    fontFamily: safeSans,
    fontWeight: FontWeight.w500,
    fontSize: 14.5,
    height: 1.3,
  );

  static const generatorValue = TextStyle(
    fontFamily: safeMono,
    fontWeight: FontWeight.w400,
    fontSize: 19,
    height: 1.55,
  );

  static const entryValue = TextStyle(
    fontFamily: safeMono,
    fontWeight: FontWeight.w400,
    fontSize: 12.5,
    height: 1.45,
  );

  static const blockTitle = TextStyle(
    fontFamily: safeSans,
    fontWeight: FontWeight.w600,
    fontSize: 11,
    height: 1.3,
    letterSpacing: 0.77,
  );

  static const sectionLabel = TextStyle(
    fontFamily: safeSans,
    fontWeight: FontWeight.w500,
    fontSize: 10.5,
    height: 1,
    letterSpacing: 0.63,
  );

  static const action = TextStyle(
    fontFamily: safeSans,
    fontWeight: FontWeight.w400,
    fontSize: 11,
    height: 1,
  );

  static const meta = TextStyle(
    fontFamily: safeSans,
    fontWeight: FontWeight.w400,
    fontSize: 11.5,
    height: 1.6,
  );

  static const comment = TextStyle(
    fontFamily: safeMono,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 1.6,
  );

  static const rawEditor = TextStyle(
    fontFamily: safeMono,
    fontWeight: FontWeight.w400,
    fontSize: 12.5,
    height: 1.75,
  );

  static const counter = TextStyle(
    fontFamily: safeMono,
    fontWeight: FontWeight.w400,
    fontSize: 11.5,
    height: 1,
  );
}

/// Le thème clair, seul thème de la refonte.
///
/// Le handoff donne vingt couleurs claires et quatre sombres, sur une planche
/// explicitement non validée: en déduire une palette sombre reviendrait à
/// inventer seize teintes que le designer n'a pas vues. Le thème sombre attend
/// donc une maquette, et `main.dart` force le mode clair.
ThemeData safeLightTheme() {
  const tokens = SafeTokens.light;
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: tokens.accent,
      primary: tokens.ink,
      onPrimary: tokens.onInk,
      surface: tokens.cardSurface,
      onSurface: tokens.ink,
    ),
  );
  return base.copyWith(
    extensions: const [tokens],
    scaffoldBackgroundColor: tokens.pageBackground,
    canvasColor: tokens.pageBackground,
    dividerColor: tokens.hairline,
    textTheme: base.textTheme.apply(
      fontFamily: safeSans,
      bodyColor: tokens.ink,
      displayColor: tokens.ink,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.pageBackground,
      foregroundColor: tokens.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: tokens.accent,
      thumbColor: tokens.accent,
      inactiveTrackColor: tokens.controlBorder,
      trackHeight: 4,
    ),
  );
}
```

- [ ] **Step 7: Constater le vert**

Run: `flutter test test/ui/theme/safe_theme_test.dart`
Expected: `+5: All tests passed!`

- [ ] **Step 8: Brancher le thème dans `main.dart`**

Dans `lib/main.dart`, remplacer les blocs `theme:` et `darkTheme:` du `MaterialApp` par:

```dart
    theme: safeLightTheme(),
    // Clair uniquement: voir la note de safe_theme.dart et la section « ce qui
    // n'est pas fait » de la spec.
    themeMode: ThemeMode.light,
```

et ajouter l'import `import 'ui/theme/safe_theme.dart';`. Supprimer l'import de `ColorScheme.fromSeed` devenu inutile s'il y en avait un dédié.

- [ ] **Step 9: Vérifier la suite entière**

Run: `flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
Expected: tout vert. Certains tests d'écran comparent peut-être des couleurs de l'ancien thème: s'il y en a, les corriger dans ce commit en notant lesquels.

- [ ] **Step 10: Commit**

```bash
git add pubspec.yaml tool/fetch_fonts.sh assets/fonts lib/ui/theme/safe_theme.dart lib/main.dart test/ui/theme/safe_theme_test.dart
git commit -m "feat: les couleurs et les polices du handoff, en un seul endroit

Les vingt couleurs, l'échelle typographique et les mesures vivent dans
un ThemeExtension: aucun écran n'écrira de littéral hexadécimal, et
une palette sombre pourra se poser à côté sans les toucher.

Les polices sont embarquées, pas chargées depuis Google: une
application hors ligne ne doit contacter personne au démarrage. Le
script qui les récupère est versionné avec elles, licences OFL
comprises.

Le thème sombre existant disparaît. Le handoff donne vingt couleurs
claires contre quatre sombres, sur une planche non validée: en déduire
une palette complète reviendrait à inventer seize teintes.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Le monogramme S

**Files:**
- Modify: `lib/ui/safe_logo.dart`, `test/ui/safe_logo_test.dart`

**Interfaces:**
- Consumes: `SafeTokens` (tâche 2).
- Produces: `SafeLogo({double size, Color? color})` — la couleur par défaut est `SafeTokens.of(context).accent`.

L'icône de lancement (`tool/generate_icons.py`) garde le bouclier: la changer réécrirait les PNG de toutes les densités et modifierait l'identité de l'application installée sur le téléphone de l'utilisateur. C'est une décision à part, listée dans le rapport final.

- [ ] **Step 1: Écrire le test rouge**

Ajouter à `test/ui/safe_logo_test.dart`:

```dart
  testWidgets('le logo accepte une couleur explicite', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: const Scaffold(
          body: SafeLogo(size: 34, color: Color(0xFF183A2B)),
        ),
      ),
    );
    expect(tester.getSize(find.byType(SafeLogo)), const Size(34, 34));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sans couleur explicite, le logo prend l\'accent du thème', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: safeLightTheme(), home: const Scaffold(body: SafeLogo())),
    );
    final painter = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(SafeLogo),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter;
    expect(painter, isA<SafeLogoPainter>());
    expect((painter! as SafeLogoPainter).color, const Color(0xFF2F7D5B));
  });
```

Avec `import 'package:safe/ui/theme/safe_theme.dart';` en tête du fichier.

- [ ] **Step 2: Constater le rouge**

Run: `flutter test test/ui/safe_logo_test.dart`
Expected: échec — `SafeLogo` n'a pas de paramètre `color`, et `SafeLogoPainter` n'est pas exporté.

- [ ] **Step 3: Réécrire `lib/ui/safe_logo.dart`**

```dart
import 'package:flutter/material.dart';

import 'theme/safe_theme.dart';

/// Le logo de safe: un S géométrique d'un seul trait.
///
/// Deux demi-cercles enchaînés, dessinés plutôt qu'importés: le trait reste
/// net à toutes les tailles et prend la couleur qu'on lui donne, ce qu'une
/// image figée ne ferait pas.
///
/// Le tracé du handoff, dans un carré de 48:
///
///     M34 14 A10 10 0 1 0 24 24 A10 10 0 1 1 14 34
class SafeLogo extends StatelessWidget {
  const SafeLogo({this.size = 34, this.color, super.key});

  final double size;

  /// Par défaut l'accent du thème; `ink` pour la version foncée.
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: SafeLogoPainter(color ?? SafeTokens.of(context).accent),
      isComplex: false,
    ),
  );
}

/// Public pour que les tests puissent lire la couleur effectivement peinte.
class SafeLogoPainter extends CustomPainter {
  const SafeLogoPainter(this.color);

  final Color color;

  /// Côté du carré de référence du tracé.
  static const double _box = 48;

  /// Épaisseur du trait, exprimée dans ce même carré.
  static const double _stroke = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _box;
    canvas.save();
    canvas.scale(scale);

    final path = Path()
      ..moveTo(34, 14)
      // A10 10 0 1 0 24 24: grand arc, sens antihoraire.
      ..arcToPoint(
        const Offset(24, 24),
        radius: const Radius.circular(10),
        largeArc: true,
        clockwise: false,
      )
      // A10 10 0 1 1 14 34: grand arc, sens horaire.
      ..arcToPoint(
        const Offset(14, 34),
        radius: const Radius.circular(10),
        largeArc: true,
        clockwise: true,
      );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = color
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(SafeLogoPainter oldDelegate) => oldDelegate.color != color;
}
```

- [ ] **Step 4: Constater le vert**

Run: `flutter test test/ui/safe_logo_test.dart`
Expected: tous verts.

- [ ] **Step 5: Voir le logo pour de vrai**

Le trait doit former un S lisible, pas deux arcs disjoints. Run:

```bash
flutter run -d emulator-5554
```

Regarder l'écran de déverrouillage, comparer au tracé du handoff, puis quitter. Si le S est cassé, le défaut vient des drapeaux d'arc: les inverser un par un et retester.

- [ ] **Step 6: Vérifier la suite et commiter**

```bash
flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add lib/ui/safe_logo.dart test/ui/safe_logo_test.dart
git commit -m "feat: le logo devient le monogramme S

Deux demi-cercles d'un seul trait, dans le carré de 48 du handoff.
Toujours dessiné plutôt qu'importé: net à toutes les tailles, et il
prend la couleur qu'on lui donne — accent sur fond clair, encre pour
la version foncée.

L'icône de lancement garde le bouclier: la changer réécrirait les PNG
de toutes les densités et modifierait l'identité de l'application déjà
installée. Décision à part.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Le déverrouillage restylé

**Files:**
- Create: `lib/ui/widgets/primary_button.dart`
- Modify: `lib/ui/unlock_screen.dart`, `test/ui/unlock_screen_test.dart`
- Test: `test/ui/widgets/primary_button_test.dart`

**Interfaces:**
- Consumes: `SafeTokens`, `SafeMetrics`, `SafeText`, `SafeLogo`.
- Produces:
  - `SafePrimaryButton({required String label, required VoidCallback? onPressed, Key? key})` — pilule pleine, hauteur `SafeMetrics.pillHeight`, fond `ink`, texte `onInk`.
  - `SafeSecondaryButton({required String label, required VoidCallback? onPressed, Key? key})` — même forme, bordure `controlBorder`, texte `secondaryText`.

Lire `lib/ui/unlock_screen.dart` en entier avant de le modifier: la logique de déverrouillage, de création et de report d'erreur ne change pas, seule la présentation change. Conserver toutes les clefs de widget existantes pour que les tests actuels continuent de passer.

- [ ] **Step 1: Écrire le test rouge des boutons**

Créer `test/ui/widgets/primary_button_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/ui/theme/safe_theme.dart';
import 'package:safe/ui/widgets/primary_button.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: safeLightTheme(), home: Scaffold(body: child));

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
  Widget build(BuildContext context) =>
      MaterialApp(theme: safeLightTheme(), home: Scaffold(body: child));
}
```

- [ ] **Step 2: Constater le rouge**

Run: `flutter test test/ui/widgets/primary_button_test.dart`
Expected: `Target of URI doesn't exist: 'package:safe/ui/widgets/primary_button.dart'`.

- [ ] **Step 3: Écrire `lib/ui/widgets/primary_button.dart`**

```dart
import 'package:flutter/material.dart';

import '../theme/safe_theme.dart';

/// Le bouton plein du handoff: pilule pleine largeur, 50 px, fond encre.
///
/// `onPressed` nul le rend inerte et grisé — c'est ce qui indique qu'une
/// saisie est en cours ou incomplète.
class SafePrimaryButton extends StatelessWidget {
  const SafePrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    return SizedBox(
      height: SafeMetrics.pillHeight,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: tokens.ink,
          foregroundColor: tokens.onInk,
          disabledBackgroundColor: tokens.controlBorder,
          disabledForegroundColor: tokens.hintText,
          // Le survol passe à l'accent: le seul retour visuel que le handoff
          // demande sur les boutons.
          overlayColor: tokens.accent,
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: safeSans,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
            height: 1,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Le bouton bordé: même forme, sans aplat. Sert aux actions de second rang,
/// « Pièce jointe » par exemple.
class SafeSecondaryButton extends StatelessWidget {
  const SafeSecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    return SizedBox(
      height: SafeMetrics.pillHeight,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.secondaryText,
          side: BorderSide(color: tokens.controlBorder),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: safeSans,
            fontWeight: FontWeight.w500,
            fontSize: 13.5,
            height: 1,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
```

- [ ] **Step 4: Constater le vert**

Run: `flutter test test/ui/widgets/primary_button_test.dart`
Expected: 4 tests verts.

- [ ] **Step 5: Écrire le test rouge du déverrouillage restylé**

Ajouter à `test/ui/unlock_screen_test.dart`:

```dart
  testWidgets('le pied de page annonce le vrai délai de verrouillage', (
    tester,
  ) async {
    final session = await makeTestSession(autoLock: const Duration(minutes: 2));
    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: UnlockScreen(session: session, isCreation: false),
      ),
    );
    expect(find.textContaining('2 min'), findsOneWidget);
    expect(find.textContaining('5 min'), findsNothing);
  });

  testWidgets('le sous-titre n\'annonce aucun nombre de fiches', (tester) async {
    // Coffre fermé: le compte est chiffré, l'annoncer supposerait de l'écrire
    // en clair à côté.
    final session = await makeTestSession();
    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: UnlockScreen(session: session, isCreation: false),
      ),
    );
    expect(find.textContaining('fiches attendent'), findsNothing);
    expect(find.text('Content de te revoir.'), findsOneWidget);
  });

  testWidgets('le bouton de déverrouillage est le bouton pilule', (
    tester,
  ) async {
    final session = await makeTestSession();
    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: UnlockScreen(session: session, isCreation: false),
      ),
    );
    expect(find.byType(SafePrimaryButton), findsOneWidget);
    expect(find.text('Déverrouiller'), findsOneWidget);
  });
```

Avec les imports `package:safe/ui/theme/safe_theme.dart` et `package:safe/ui/widgets/primary_button.dart`.

- [ ] **Step 6: Constater le rouge**

Run: `flutter test test/ui/unlock_screen_test.dart`
Expected: échec sur le titre « Content de te revoir. » et sur `SafePrimaryButton`.

- [ ] **Step 7: Restyler `lib/ui/unlock_screen.dart`**

Ne toucher qu'à `build` et aux méthodes de présentation. Conserver la logique, les clefs et les messages d'erreur existants. La structure visée, de haut en bas, gouttières de 40 px et contenu centré verticalement:

1. `SafeLogo(size: 34)`, puis 26 px.
2. Titre: `Text('Content de te revoir.')` en création `Text('Bienvenue.')`, style `SafeText.screenTitle.copyWith(fontSize: 30, height: 1.15)`, couleur `tokens.ink`.
3. Sous-titre, 400 13.5 px/1.6 en `tokens.secondaryText`, puis 32 px. En relecture: « Ton coffre est fermé. » En création: le texte d'avertissement existant sur l'irrécupérabilité du mot de passe maître, qui **ne doit pas disparaître**.
4. Champ: `TextField` sans bordure de boîte, `decoration: InputDecoration(border: InputBorder.none, enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: tokens.ink, width: 1.5)), focusedBorder: <idem>, suffixIcon: <œil>)`, `style: TextStyle(fontFamily: safeMono, fontWeight: FontWeight.w500, fontSize: 16, letterSpacing: 2.56)`, `cursorColor: tokens.accent`, `cursorWidth: 2`.
5. Bouton œil: `IconButton` de `SafeMetrics.touchTarget` de côté, icône `Icons.visibility_outlined` / `Icons.visibility_off_outlined`, 20 px, couleur `tokens.tertiaryText`.
6. `SafePrimaryButton(label: isCreation ? 'Créer le coffre' : 'Déverrouiller', ...)` — garder la même clef que le bouton actuel.
7. Pied: `Text('Verrouillage auto après ${_delaiLisible(widget.session.autoLockDelay)}.')` en `SafeText.meta` / `tokens.hintText`, marge basse 34 px.

Ajouter la fonction de mise en forme du délai, dans le même fichier:

```dart
/// « 30 s », « 1 min », « 2 min »… La maquette affichait « 5 min » en dur; le
/// délai est un réglage, et deux vérités pour un même réglage, on en a déjà
/// corrigé une.
String _delaiLisible(Duration delay) => delay.inMinutes >= 1
    ? '${delay.inMinutes} min'
    : '${delay.inSeconds} s';
```

Si `VaultSession` n'expose pas son délai en lecture, ajouter un getter `Duration get autoLockDelay => _autoLockDelay;` dans `lib/state/vault_session.dart`.

- [ ] **Step 8: Constater le vert**

Run: `flutter test test/ui/unlock_screen_test.dart test/ui/safe_logo_test.dart`
Expected: tous verts.

- [ ] **Step 9: Regarder l'écran**

```bash
flutter run -d emulator-5554
```

Vérifier: fond `#f4f2ee`, titre en Instrument Sans 600, valeur du champ en JetBrains Mono espacée, filet bas sous le champ, bouton pilule sombre. Si le texte s'affiche encore dans la police système, `pubspec.yaml` n'a pas été relu: arrêter et relancer.

- [ ] **Step 10: Vérifier la suite et commiter**

```bash
flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add lib/ui/widgets/primary_button.dart lib/ui/unlock_screen.dart lib/state/vault_session.dart test/ui/widgets/primary_button_test.dart test/ui/unlock_screen_test.dart
git commit -m "feat: le déverrouillage passe au thème clair

Logo, titre, champ à filet bas et bouton pilule, aux mesures du
handoff. La logique de déverrouillage et de création ne bouge pas.

Deux écarts à la maquette, tous deux motivés dans la spec: le
sous-titre n'annonce pas le nombre de fiches — coffre fermé, il est
chiffré, et l'écrire en clair à côté le divulguerait — et le pied de
page affiche le vrai délai de verrouillage plutôt que « 5 min » en
dur.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Le générateur, jeux et état de session

Cette tâche ne touche à aucun écran: elle prépare la logique que l'onglet Générateur (tâche 9) affichera.

**Files:**
- Modify: `lib/util/password_generator.dart`, `test/util/password_generator_test.dart`
- Create: `lib/state/generator_session.dart`, `test/state/generator_session_test.dart`

**Interfaces:**
- Consumes: `VaultSession` (pour l'écoute du verrouillage).
- Produces:
  - `enum CharacterSet { letters, lettersDigits, all }` avec `String get label` (« Lettres », « + chiffres », « + symboles ») et `String get alphabet`.
  - `const int minPasswordLength = 8; const int maxPasswordLength = 48;`
  - `String generatePassword({int length, CharacterSet set, Random? random})`
  - `class GeneratorSession extends ChangeNotifier` avec `int length`, `CharacterSet set`, `String value`, `List<String> get history`, `void regenerate()`, `void setLength(int)`, `void setSet(CharacterSet)`, `void clear()`.

- [ ] **Step 1: Écrire le test rouge des jeux**

Remplacer le contenu de `test/util/password_generator_test.dart` par ce qui suit — les tests existants sur la présence de chaque classe et sur le mélange restent valables, seuls les alphabets et les bornes changent:

```dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe/util/password_generator.dart';

void main() {
  test('les caractères ambigus sont exclus de tous les jeux', () {
    for (final set in CharacterSet.values) {
      for (final ambigu in ['l', 'I', 'O', '0', '1']) {
        expect(
          set.alphabet.contains(ambigu),
          isFalse,
          reason: '$ambigu ne doit pas être dans ${set.name}',
        );
      }
    }
  });

  test('les alphabets sont exactement ceux du handoff', () {
    const lettres = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ';
    expect(CharacterSet.letters.alphabet, lettres);
    expect(CharacterSet.lettersDigits.alphabet, '$lettres''23456789');
    expect(CharacterSet.all.alphabet, '$lettres''23456789''!#\$%&*+-?@');
  });

  test('les libellés sont ceux des pastilles', () {
    expect(CharacterSet.letters.label, 'Lettres');
    expect(CharacterSet.lettersDigits.label, '+ chiffres');
    expect(CharacterSet.all.label, '+ symboles');
  });

  test('les bornes vont de 8 à 48', () {
    expect(minPasswordLength, 8);
    expect(maxPasswordLength, 48);
    expect(generatePassword(length: 8).length, 8);
    expect(generatePassword(length: 48).length, 48);
    expect(() => generatePassword(length: 7), throwsArgumentError);
    expect(() => generatePassword(length: 49), throwsArgumentError);
  });

  test('chaque classe du jeu apparaît au moins une fois', () {
    for (var essai = 0; essai < 40; essai++) {
      final mot = generatePassword(length: 20);
      expect(mot.contains(RegExp('[a-z]')), isTrue);
      expect(mot.contains(RegExp('[A-Z]')), isTrue);
      expect(mot.contains(RegExp('[2-9]')), isTrue);
      expect(mot.contains(RegExp(r'[!#$%&*+\-?@]')), isTrue);
    }
  });

  test('le mot de passe ne tire que dans l\'alphabet de son jeu', () {
    final mot = generatePassword(length: 48, set: CharacterSet.letters);
    for (final caractere in mot.split('')) {
      expect(CharacterSet.letters.alphabet.contains(caractere), isTrue);
    }
  });

  test('deux tirages diffèrent', () {
    expect(generatePassword(), isNot(generatePassword()));
  });

  test('un générateur injecté rend un tirage reproductible', () {
    final a = generatePassword(length: 20, random: Random(7));
    final b = generatePassword(length: 20, random: Random(7));
    expect(a, b);
  });
}
```

- [ ] **Step 2: Constater le rouge**

Run: `flutter test test/util/password_generator_test.dart`
Expected: échec sur les alphabets, les libellés et la borne 48.

- [ ] **Step 3: Modifier `lib/util/password_generator.dart`**

Remplacer les constantes de classes de caractères et les libellés:

```dart
  /// Les minuscules sans « l », qui se confond avec « 1 » et « I ».
  static const lower = _CharacterClass('abcdefghijkmnopqrstuvwxyz');

  /// Les majuscules sans « I » ni « O ».
  static const upper = _CharacterClass('ABCDEFGHJKLMNPQRSTUVWXYZ');

  /// Les chiffres sans « 0 » ni « 1 ».
  static const digits = _CharacterClass('23456789');

  /// Une ponctuation restreinte, celle que le handoff retient.
  ///
  /// Le jeu complet passe de 94 à 67 caractères, soit 6,07 bits par position
  /// au lieu de 6,55 — un demi-bit de moins, 121 bits à vingt caractères. Ce
  /// qu'on gagne: des mots de passe que les formulaires acceptent, et qui se
  /// recopient à la main sans erreur.
  static const symbols = _CharacterClass(r'!#$%&*+-?@');
```

Renommer les libellés de l'énumération pour ceux des pastilles:

```dart
enum CharacterSet {
  letters('Lettres'),
  lettersDigits('+ chiffres'),
  all('+ symboles');
```

Et abaisser la borne haute:

```dart
/// Longueurs acceptées, bornes comprises. Le curseur du générateur va de l'une
/// à l'autre.
const int minPasswordLength = 8;
const int maxPasswordLength = 48;
```

- [ ] **Step 4: Constater le vert**

Run: `flutter test test/util/password_generator_test.dart`
Expected: 8 tests verts.

- [ ] **Step 5: Écrire le test rouge de l'état du générateur**

Créer `test/state/generator_session_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/state/generator_session.dart';
import 'package:safe/util/password_generator.dart';

import '../support/session_fixture.dart';

void main() {
  test('les défauts sont 20 caractères et « + symboles »', () async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    expect(gen.length, 20);
    expect(gen.set, CharacterSet.all);
    expect(gen.value.length, 20);
    expect(gen.history, isEmpty);
    vault.lock();
  });

  test('régénérer pousse la valeur précédente dans l\'historique', () async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    final premiere = gen.value;
    gen.regenerate();
    expect(gen.history, [premiere]);
    expect(gen.value, isNot(premiere));
    vault.lock();
  });

  test('l\'historique ne garde que trois valeurs', () async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    for (var i = 0; i < 6; i++) {
      gen.regenerate();
    }
    expect(gen.history.length, 3);
    vault.lock();
  });

  test('changer la longueur régénère immédiatement', () async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    gen.setLength(32);
    expect(gen.length, 32);
    expect(gen.value.length, 32);
    vault.lock();
  });

  test('changer de jeu régénère avec le nouveau jeu', () async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    gen.setSet(CharacterSet.letters);
    expect(gen.set, CharacterSet.letters);
    expect(gen.value.contains(RegExp('[0-9]')), isFalse);
    vault.lock();
  });

  test('le verrouillage vide l\'historique et la valeur', () async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    gen.regenerate();
    gen.regenerate();
    expect(gen.history, isNotEmpty);

    vault.lock();
    await Future<void>.delayed(Duration.zero);

    expect(gen.history, isEmpty);
    expect(gen.value, isEmpty);
  });

  test('les auditeurs sont prévenus à chaque changement', () async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    var avis = 0;
    gen.addListener(() => avis++);
    gen.regenerate();
    gen.setLength(24);
    gen.setSet(CharacterSet.letters);
    expect(avis, 3);
    vault.lock();
  });

  test('l\'historique n\'est pas modifiable de l\'extérieur', () async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    gen.regenerate();
    expect(() => gen.history.add('injection'), throwsUnsupportedError);
    vault.lock();
  });
}
```

- [ ] **Step 6: Constater le rouge**

Run: `flutter test test/state/generator_session_test.dart`
Expected: `Target of URI doesn't exist: 'package:safe/state/generator_session.dart'`.

- [ ] **Step 7: Écrire `lib/state/generator_session.dart`**

```dart
import 'package:flutter/foundation.dart';

import '../util/password_generator.dart';
import 'vault_session.dart';

/// L'état du générateur de mots de passe.
///
/// Le générateur n'appartient plus à un champ d'édition: c'est un outil de
/// l'accueil, dont l'état vit le temps d'une session déverrouillée. Rien ici
/// n'est écrit sur le disque — c'est ce que l'écran promet à l'utilisateur, et
/// une valeur générée est un secret au même titre qu'une valeur du coffre.
class GeneratorSession extends ChangeNotifier {
  GeneratorSession(this._vault) {
    _vault.addListener(_onVault);
    _value = generatePassword(length: _length, set: _set);
  }

  /// Nombre de valeurs précédentes conservées, comme sur la maquette.
  static const int historyLength = 3;

  final VaultSession _vault;

  int _length = 20;
  CharacterSet _set = CharacterSet.all;
  String _value = '';
  final List<String> _history = [];

  int get length => _length;
  CharacterSet get set => _set;
  String get value => _value;

  /// Les valeurs précédentes, de la plus récente à la plus ancienne.
  List<String> get history => List.unmodifiable(_history);

  /// Tire une nouvelle valeur et pousse l'ancienne dans l'historique.
  void regenerate() {
    if (_value.isNotEmpty) {
      _history.insert(0, _value);
      if (_history.length > historyLength) {
        _history.removeRange(historyLength, _history.length);
      }
    }
    _value = generatePassword(length: _length, set: _set);
    notifyListeners();
  }

  /// Le curseur régénère à chaque cran: la maquette montre la valeur suivre.
  void setLength(int length) {
    _length = length.clamp(minPasswordLength, maxPasswordLength);
    _value = generatePassword(length: _length, set: _set);
    notifyListeners();
  }

  void setSet(CharacterSet set) {
    _set = set;
    _value = generatePassword(length: _length, set: _set);
    notifyListeners();
  }

  /// Efface tout: appelé au verrouillage, et rien ne survit.
  void clear() {
    _history.clear();
    _value = '';
    notifyListeners();
  }

  void _onVault() {
    if (!_vault.isUnlocked) {
      clear();
    }
  }

  @override
  void dispose() {
    _vault.removeListener(_onVault);
    super.dispose();
  }
}
```

- [ ] **Step 8: Constater le vert**

Run: `flutter test test/state/generator_session_test.dart`
Expected: 8 tests verts.

- [ ] **Step 9: Vérifier la suite entière**

Run: `flutter test`
Expected: `entry_edit_screen_test.dart` échoue peut-être si un test attend l'ancien libellé « Lettres et chiffres ». Le corriger, ou le laisser tel quel si l'écran d'édition disparaît en tâche 7 — dans ce cas, adapter le libellé attendu sans toucher à l'écran.

- [ ] **Step 10: Commit**

```bash
git add lib/util/password_generator.dart lib/state/generator_session.dart test/util/password_generator_test.dart test/state/generator_session_test.dart
git commit -m "feat: le générateur perd les caractères ambigus et gagne un état

Les jeux excluent l, I, O, 0 et 1, et la ponctuation se restreint à
dix caractères: le jeu complet passe de 94 à 67, soit un demi-bit de
moins par position — 121 bits à vingt caractères. Ce qu'on gagne: des
mots de passe que les formulaires acceptent et qu'on recopie sans
erreur.

GeneratorSession porte longueur, jeu, valeur et les trois valeurs
précédentes. L'historique vit en mémoire et se vide au verrouillage:
rien n'est écrit sur le disque, comme l'écran le promettra.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: La fiche

La plus grosse tâche. À faire d'un bloc parce que les quatre widgets créés n'ont de sens que dans cet écran et se testent à travers lui.

**Files:**
- Create: `lib/ui/widgets/pill_tabs.dart`, `lib/ui/widgets/safe_toast.dart`, `lib/ui/widgets/syntax_tutorial.dart`, `lib/ui/widgets/block_card.dart`, `lib/ui/entry_screen.dart`
- Modify: `lib/storage/app_settings.dart`, `lib/ui/entries_screen.dart` (câblage temporaire vers le nouvel écran)
- Test: `test/ui/entry_screen_test.dart`, `test/storage/app_settings_test.dart`

**Interfaces:**
- Consumes: `parseEntryText`, `describeGroups`, `EntryGroup` (tâche 1); `SafeTokens`, `SafeText`, `SafeMetrics` (tâche 2); `SafePrimaryButton`, `SafeSecondaryButton` (tâche 4).
- Produces:
  - `SafePillTabs({required List<String> labels, required int selected, required ValueChanged<int> onSelected, double height, Key? key})`
  - `showSafeToast(BuildContext context, String message)` — pilule encre, 84 px au-dessus du bas, 1,5 s.
  - `SyntaxTutorial({required VoidCallback onDismiss, Key? key})`
  - `BlockCard({required EntryGroup group, required bool open, required VoidCallback onToggle, required ValueChanged<String> onCopyLine, required VoidCallback onCopyBlock, Key? key})`
  - `CommentBlock({required EntryGroup group, required VoidCallback onCopy, Key? key})`
  - `EntryScreen({required VaultSession session, required VaultEntry entry, SecureClipboard? clipboard, Key? key})`
  - `AppSettings.syntaxTutorialDismissed` (bool, défaut `false`)

- [ ] **Step 1: Écrire le test rouge de la préférence de tuto**

Ajouter à `test/storage/app_settings_test.dart`:

```dart
  test('le tuto de syntaxe est affiché par défaut', () {
    expect(const AppSettings().syntaxTutorialDismissed, isFalse);
  });

  test('un settings.json écrit avant la refonte reste lisible', () {
    // Champ absent: aucune migration, le tuto s'affiche.
    final settings = AppSettings.fromJson({
      'blockScreenshots': true,
      'autoLockSeconds': 120,
    });
    expect(settings.syntaxTutorialDismissed, isFalse);
  });

  test('la préférence de tuto fait l\'aller-retour par le JSON', () {
    final settings = const AppSettings().copyWith(
      syntaxTutorialDismissed: true,
    );
    expect(AppSettings.fromJson(settings.toJson()).syntaxTutorialDismissed,
        isTrue);
  });

  test('une valeur de tuto d\'un type inattendu retombe sur le défaut', () {
    expect(
      AppSettings.fromJson({'syntaxTutorialDismissed': 'oui'})
          .syntaxTutorialDismissed,
      isFalse,
    );
  });
```

- [ ] **Step 2: Constater le rouge, puis ajouter le champ**

Run: `flutter test test/storage/app_settings_test.dart` — échec, le champ n'existe pas.

Dans `lib/storage/app_settings.dart`, ajouter au constructeur, au champ, à `copyWith`, à `toJson` et à `fromJson`:

```dart
  /// Le tuto de syntaxe de la fiche a-t-il été écarté ?
  ///
  /// Une fois « Compris », il ne revient pas de lui-même: le lien « Syntaxe »
  /// le rappelle. Absent des fichiers écrits avant la refonte, d'où le défaut
  /// à `false` — aucune migration.
  final bool syntaxTutorialDismissed;
```

dans `fromJson`:

```dart
    final tuto = json['syntaxTutorialDismissed'];
    // …
      syntaxTutorialDismissed: tuto is bool ? tuto : false,
```

Run: `flutter test test/storage/app_settings_test.dart` — vert.

- [ ] **Step 3: Écrire le test rouge de la fiche**

Créer `test/ui/entry_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/storage/app_settings.dart';
import 'package:safe/ui/entry_screen.dart';
import 'package:safe/ui/theme/safe_theme.dart';

import '../support/session_fixture.dart';

const _texte = '''
courrier:
personne@example.invalid
correcthorsebattery

note libre

wifi:
un-mot-de-passe
''';

Future<VaultSession> _sessionAvecTexte() async {
  final session = await makeUnlockedSession();
  await session.save(
    session.vault!.upsert(VaultEntry.now(key: 'perso', value: _texte)),
  );
  return session;
}

Widget _ecran(VaultSession session, {SettingsStore? settings}) => MaterialApp(
  theme: safeLightTheme(),
  home: EntryScreen(
    session: session,
    entry: session.vault!.entries.first,
    settings: settings ?? MemorySettingsStore(),
  ),
);

void main() {
  testWidgets('l\'en-tête compte les blocs et les lignes', (tester) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    expect(find.text('perso'), findsOneWidget);
    expect(find.text('3 blocs · 4 lignes'), findsOneWidget);
    session.lock();
  });

  testWidgets('les blocs sont repliés et leurs valeurs masquées', (
    tester,
  ) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    expect(find.text('COURRIER'), findsOneWidget);
    expect(find.text('WIFI'), findsOneWidget);
    expect(find.text('correcthorsebattery'), findsNothing);
    expect(find.text('un-mot-de-passe'), findsNothing);
    session.lock();
  });

  testWidgets('un commentaire est visible sans geste', (tester) async {
    // Choix assumé du handoff: un groupe sans titre est une note, pas un
    // secret. Voir la section « masquage » de la spec.
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    expect(find.text('note libre'), findsOneWidget);
    session.lock();
  });

  testWidgets('ouvrir un bloc révèle ses lignes, le refermer les remasque', (
    tester,
  ) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('COURRIER'));
    await tester.pumpAndSettle();
    expect(find.text('personne@example.invalid'), findsOneWidget);
    expect(find.text('correcthorsebattery'), findsOneWidget);
    // L'autre bloc reste fermé.
    expect(find.text('un-mot-de-passe'), findsNothing);

    await tester.tap(find.text('COURRIER'));
    await tester.pumpAndSettle();
    expect(find.text('correcthorsebattery'), findsNothing);
    session.lock();
  });

  testWidgets('plusieurs blocs peuvent être ouverts en même temps', (
    tester,
  ) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('COURRIER'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WIFI'));
    await tester.pumpAndSettle();

    expect(find.text('correcthorsebattery'), findsOneWidget);
    expect(find.text('un-mot-de-passe'), findsOneWidget);
    session.lock();
  });

  testWidgets('le mode texte brut montre le texte source intact', (
    tester,
  ) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Texte brut'));
    await tester.pumpAndSettle();

    final champ = tester.widget<TextField>(find.byKey(const Key('raw')));
    expect(champ.controller!.text, _texte);
    session.lock();
  });

  testWidgets('taper dans le texte brut recompose la lecture en direct', (
    tester,
  ) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Texte brut'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('raw')), 'seul:\nx');
    await tester.pumpAndSettle();

    expect(find.text('1 bloc · 1 ligne'), findsOneWidget);

    await tester.tap(find.text('Lecture'));
    await tester.pumpAndSettle();
    expect(find.text('SEUL'), findsOneWidget);
    session.lock();
  });

  testWidgets('enregistrer écrit le texte tel quel, sans le réécrire', (
    tester,
  ) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Texte brut'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('raw')), '  espaces gardés  ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(session.vault!.entries.first.value, '  espaces gardés  ');
    session.lock();
  });

  testWidgets('le tuto s\'affiche puis s\'écarte définitivement', (
    tester,
  ) async {
    final settings = MemorySettingsStore();
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session, settings: settings));
    await tester.pumpAndSettle();

    expect(find.text('Compris'), findsOneWidget);
    await tester.tap(find.text('Compris'));
    await tester.pumpAndSettle();

    expect(find.text('Compris'), findsNothing);
    expect(find.text('Syntaxe'), findsOneWidget);
    expect((await settings.read()).syntaxTutorialDismissed, isTrue);
    session.lock();
  });

  testWidgets('« Syntaxe » rappelle le tuto écarté', (tester) async {
    final settings = MemorySettingsStore(
      const AppSettings(syntaxTutorialDismissed: true),
    );
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session, settings: settings));
    await tester.pumpAndSettle();

    expect(find.text('Compris'), findsNothing);
    await tester.tap(find.text('Syntaxe'));
    await tester.pumpAndSettle();
    expect(find.text('Compris'), findsOneWidget);
    session.lock();
  });

  testWidgets('copier une ligne affiche le toast', (tester) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('COURRIER'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('copy-line-1')));
    await tester.pump();

    expect(find.text('Copié'), findsOneWidget);
    session.lock();
  });

  testWidgets('le verrouillage referme les blocs et vide l\'écran', (
    tester,
  ) async {
    final session = await _sessionAvecTexte();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('COURRIER'));
    await tester.pumpAndSettle();
    expect(find.text('correcthorsebattery'), findsOneWidget);

    session.lock();
    await tester.pumpAndSettle();

    expect(find.text('correcthorsebattery'), findsNothing);
  });
}
```

- [ ] **Step 4: Constater le rouge**

Run: `flutter test test/ui/entry_screen_test.dart`
Expected: `Target of URI doesn't exist: 'package:safe/ui/entry_screen.dart'`.

- [ ] **Step 5: Écrire les quatre widgets**

`lib/ui/widgets/pill_tabs.dart` — conteneur `tabContainer`, rayon `SafeMetrics.tabContainerRadius`, `padding: EdgeInsets.all(4)`, pastilles `Expanded` de hauteur `height` (36 par défaut, 28 pour la barre de mode de la fiche), rayon `SafeMetrics.tabRadius`. Active: fond `cardSurface`, texte `ink` 600 12.5 px, `BoxShadow(color: Color(0x17000000), blurRadius: 2, offset: Offset(0, 1))`. Inactive: fond transparent, texte `secondaryText` 500. Transition `SafeMetrics.transition`.

`lib/ui/widgets/safe_toast.dart` — une fonction, pas un widget d'écran:

```dart
/// Le toast de copie: pilule encre, 84 px au-dessus du bas, 1,5 s.
///
/// Passe par l'`Overlay` plutôt que par un `SnackBar`: la maquette veut une
/// pilule centrée et flottante, pas la barre pleine largeur de Material.
void showSafeToast(BuildContext context, String message) { … }
```

`lib/ui/widgets/syntax_tutorial.dart` — carte `softAccentSurface`, rayon `SafeMetrics.cardRadius`, `padding: EdgeInsets.fromLTRB(16, 13, 16, 12)`, trois lignes de `exemple` en `safeMono` 11.5 px `accentDark` + glose en `safeSans` 11.5 px `Color(0xFF2C4438)`:

- `courrier:` → « ouvre un bloc »
- `(ligne vide)` → « le referme »
- `texte seul` → « reste un commentaire, à sa place »

puis l'action « Compris » 500 11 px `accentDark`.

`lib/ui/widgets/block_card.dart` — `BlockCard` et `CommentBlock`, aux mesures de la spec. Points à ne pas rater:

- La carte entière est cliquable quand elle est repliée; une fois ouverte, seul l'en-tête referme.
- Ouvert: bordure `1.5px accent`, en-tête en `accentDark`, chevron `⌄`, et le compteur cède la place à l'action « copier le bloc ».
- Chaque ligne porte une clef `Key('copy-line-$index')` où l'index est celui de la ligne **dans la fiche entière**, pas dans le bloc: les tests s'en servent pour viser une ligne précise.
- « copier le bloc » joint les lignes par `'\n'`, **sans le titre**.
- La valeur est en `SafeText.entryValue`, avec `softWrap: true` et coupure autorisée en milieu de mot (`TextOverflow.visible` et un `Wrap` ou `Text` sans `maxLines`).

- [ ] **Step 6: Écrire `lib/ui/entry_screen.dart`**

Points structurants:

- Un seul `TextEditingController` porte le texte; **c'est la source de vérité de l'écran**. La lecture est `parseEntryText(_controller.text)`, recalculée à chaque `build`. Aucun état dérivé n'est stocké.
- `_open` est un `Set<int>` d'index de groupes, vidé au verrouillage et à chaque fois que le nombre de groupes change sous les doigts.
- L'écran écoute `session` comme le fait `entry_edit_screen.dart` aujourd'hui: au verrouillage il efface le contrôleur, vide `_open` et cesse de retenir le retour. **Reprendre ce comportement à l'identique**, il corrige un défaut connu.
- Le tuto lit `settings.read()` au montage et écrit `settings.write()` sur « Compris ».
- `Enregistrer` appelle `session.save(vault.upsert(VaultEntry(key: entry.key, value: _controller.text, created: entry.created, updated: DateTime.now().toUtc(), attachments: entry.attachments)))` — le texte passe **tel quel**, sans `trim`.
- Le panneau de lecture est un `ListView`, pas une `Column` dans un `SingleChildScrollView` fixe: un bloc long ne doit jamais être tronqué.
- Pied: `Row` de deux boutons de largeurs égales, gap 10 — `SafeSecondaryButton('Pièce jointe')` qui ouvre `AttachmentsSection` existante, et `SafePrimaryButton('Enregistrer')`.

- [ ] **Step 7: Constater le vert**

Run: `flutter test test/ui/entry_screen_test.dart`
Expected: 12 tests verts. Chaque échec restant est un écart au handoff: le corriger dans l'écran, pas dans le test.

- [ ] **Step 8: Câbler l'ancienne liste vers la nouvelle fiche**

Dans `lib/ui/entries_screen.dart`, remplacer la navigation vers `EntryEditScreen(existing: entry)` par `EntryScreen(session: …, entry: entry, settings: …)`. **Laisser** la navigation de création pointer vers `EntryEditScreen` jusqu'à la tâche 7: l'application doit rester utilisable à chaque commit.

- [ ] **Step 9: Vérifier la suite et l'écran**

```bash
flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
flutter run -d emulator-5554
```

Sur l'émulateur: créer une entrée dont le texte contient deux blocs et un commentaire, vérifier les compteurs, l'ouverture, la copie, le toast et le mode texte brut.

- [ ] **Step 10: Commit**

```bash
git add lib/ui/widgets lib/ui/entry_screen.dart lib/storage/app_settings.dart lib/ui/entries_screen.dart test/ui/entry_screen_test.dart test/storage/app_settings_test.dart
git commit -m "feat: la fiche se lit en blocs

Le texte d'une entrée s'affiche en blocs repliés, commentaires
intercalés à leur place, et un mode texte brut qui recompose la
lecture à chaque frappe. Le texte enregistré est exactement celui qui
a été tapé: ni trim, ni réécriture.

Les lignes d'un bloc titré restent masquées jusqu'à son ouverture,
qui est le geste de révélation. Les commentaires s'affichent en clair:
c'est la règle du handoff, et elle vaut aussi pour les entrées
existantes, dont la valeur d'une ligne sans « titre: » devient un
commentaire. Conséquence connue, assumée, documentée dans la spec.

Le tuto de syntaxe s'écarte définitivement une fois compris; la
préférence rejoint settings.json, absente des fichiers antérieurs donc
sans migration.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: La nouvelle fiche

**Files:**
- Create: `lib/ui/new_entry_screen.dart`, `test/ui/new_entry_screen_test.dart`
- Modify: `lib/ui/entries_screen.dart`
- Delete: `lib/ui/entry_edit_screen.dart`, `test/ui/entry_edit_screen_test.dart`

**Interfaces:**
- Consumes: tout ce qu'a produit la tâche 6.
- Produces: `NewEntryScreen({required VaultSession session, SettingsStore? settings, Key? key})`.

Avant de supprimer `entry_edit_screen.dart`, lire `test/ui/entry_edit_screen_test.dart`, `test/ui/unsaved_changes_test.dart`, `test/ui/lock_during_edit_test.dart` et `test/ui/keyboard_leak_test.dart`: ils couvrent des défauts déjà corrigés (saisie perdue au verrouillage, garde de sortie, fuite du clavier). **Chacun doit être réécrit contre `NewEntryScreen` ou `EntryScreen`, aucun ne doit être supprimé.**

- [ ] **Step 1: Écrire le test rouge**

Créer `test/ui/new_entry_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/ui/new_entry_screen.dart';
import 'package:safe/ui/theme/safe_theme.dart';

import '../support/session_fixture.dart';

Widget _ecran(VaultSession session) => MaterialApp(
  theme: safeLightTheme(),
  home: NewEntryScreen(session: session, settings: MemorySettingsStore()),
);

void main() {
  testWidgets('le compteur part de zéro et suit la frappe', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    expect(find.text('0 bloc · 0 ligne'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('raw')), 'a:\nun\ndeux');
    await tester.pumpAndSettle();
    expect(find.text('1 bloc · 2 lignes'), findsOneWidget);
    session.lock();
  });

  testWidgets('le tuto est affiché par défaut sur une nouvelle fiche', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    expect(find.text('Compris'), findsOneWidget);
    session.lock();
  });

  testWidgets('enregistrer crée l\'entrée avec le texte tel quel', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('name')), 'perso');
    await tester.enterText(find.byKey(const Key('raw')), 'a:\nun');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final entree = session.vault!.entries.single;
    expect(entree.key, 'perso');
    expect(entree.value, 'a:\nun');
    session.lock();
  });

  testWidgets('un nom vide empêche l\'enregistrement', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('raw')), 'a:\nun');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(session.vault!.entries, isEmpty);
    expect(find.textContaining('nom'), findsWidgets);
    session.lock();
  });

  testWidgets('un nom déjà pris est refusé', (tester) async {
    final session = await makeUnlockedSession(keys: ['perso']);
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('name')), 'PERSO');
    await tester.enterText(find.byKey(const Key('raw')), 'a:\nun');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(session.vault!.entries.length, 1);
    session.lock();
  });

  testWidgets('le verrouillage efface la saisie', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_ecran(session));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('raw')), 'secret:\nvaleur');
    await tester.pumpAndSettle();

    session.lock();
    await tester.pumpAndSettle();

    expect(find.text('secret:\nvaleur'), findsNothing);
    final champ = tester.widget<TextField>(find.byKey(const Key('raw')));
    expect(champ.controller!.text, isEmpty);
  });
}
```

- [ ] **Step 2: Constater le rouge**

Run: `flutter test test/ui/new_entry_screen_test.dart`
Expected: `Target of URI doesn't exist`.

- [ ] **Step 3: Écrire `lib/ui/new_entry_screen.dart`**

Structure de haut en bas: retour + « Nouvelle fiche »; champ de nom (`Key('name')`) en placeholder `titlePlaceholder` 600 24 px, filet bas `1.5px strongDivider`, caret `accent`; `SyntaxTutorial` affiché par défaut; carte blanche rayon 14 occupant l'espace restant, contenant un `TextField` (`Key('raw')`) multiligne en `SafeText.rawEditor` avec le placeholder « Colle ou tape ici.\nTout est accepté. »; en pied de carte un hairline puis `describeGroups(parseEntryText(...))` en `SafeText.counter` `hintText` à gauche et l'action « Coller » `accent` à droite; enfin `SafePrimaryButton('Enregistrer')`.

Validation, reprise telle quelle de `entry_edit_screen.dart`: nom non vide, nom pas déjà pris (`canonicalKey`), message d'erreur affiché sous le champ. Écoute du verrouillage identique: effacer les deux contrôleurs, lever la garde de sortie, afficher « Le coffre s'est verrouillé: la saisie a été effacée ».

L'action « Coller » lit le presse-papier système et insère à la position du curseur.

- [ ] **Step 4: Constater le vert**

Run: `flutter test test/ui/new_entry_screen_test.dart`
Expected: 6 tests verts.

- [ ] **Step 5: Réécrire les tests qui visaient l'ancien écran**

Pour chacun de `test/ui/entry_edit_screen_test.dart`, `test/ui/unsaved_changes_test.dart`, `test/ui/lock_during_edit_test.dart`, `test/ui/keyboard_leak_test.dart`: remplacer `EntryEditScreen` par `NewEntryScreen` (cas de création) ou `EntryScreen` (cas de modification), en gardant **exactement la même assertion**. Renommer `entry_edit_screen_test.dart` en `entry_screen_extra_test.dart` si son contenu couvre la modification.

Run: `flutter test test/ui/`
Expected: tout vert. Un test qui ne peut pas être transposé signale une fonction perdue: l'ajouter au nouvel écran plutôt que supprimer le test.

- [ ] **Step 6: Basculer la création et supprimer l'ancien écran**

Dans `lib/ui/entries_screen.dart`, faire pointer la création vers `NewEntryScreen`. Puis:

```bash
git rm lib/ui/entry_edit_screen.dart
grep -rn "entry_edit_screen\|EntryEditScreen" lib test
```

Expected: aucun résultat.

- [ ] **Step 7: Vérifier la suite et commiter**

```bash
flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add -- lib/ui/new_entry_screen.dart lib/ui/entries_screen.dart test/ui
git commit -m "feat: la nouvelle fiche est un bloc de texte

Nom, tuto de syntaxe, carte de saisie et compteur qui suit la frappe.
Le générateur ne s'y trouve plus: il devient un outil de l'accueil, où
il a un sens pour toutes les entrées et pas seulement pour celles qui
tiennent en un mot de passe.

L'ancien écran d'édition disparaît. Ses tests ne sont pas supprimés
mais transposés: ils couvrent des défauts déjà corrigés — saisie
effacée au verrouillage, garde de sortie, fuite du clavier — qu'il ne
faut pas réintroduire.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: La recherche dans le contenu

**Files:**
- Create: `lib/model/vault_search.dart`, `test/model/vault_search_test.dart`

**Interfaces:**
- Consumes: `parseEntryText` (tâche 1), `canonicalKey` et `Vault` (existants).
- Produces:
  - `class SearchHit { const SearchHit({required this.entry, this.matchedTitle, this.matchedLine}); final VaultEntry entry; final String? matchedTitle; final String? matchedLine; }`
  - `List<SearchHit> searchVault(Vault vault, String query)`

- [ ] **Step 1: Écrire le test rouge**

Créer `test/model/vault_search_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/vault.dart';
import 'package:safe/model/vault_search.dart';

Vault _coffre() => Vault([
  VaultEntry.now(
    key: 'comptes perso',
    value: 'courrier:\nmoi@example.invalid\nmotdepasse\n\nnote\n\nwifi:\nabcdef',
  ),
  VaultEntry.now(key: 'banque', value: 'identifiant:\n12345678'),
]);

void main() {
  test('une requête vide rend toutes les fiches, sans surlignage', () {
    final hits = searchVault(_coffre(), '');
    expect(hits.length, 2);
    expect(hits.every((h) => h.matchedTitle == null), isTrue);
    expect(hits.every((h) => h.matchedLine == null), isTrue);
  });

  test('le nom de fiche est trouvé', () {
    final hits = searchVault(_coffre(), 'banque');
    expect(hits.single.entry.key, 'banque');
    expect(hits.single.matchedTitle, isNull);
  });

  test('un intertitre de bloc est trouvé, et rendu pour le surlignage', () {
    // « courrier » n'est le nom d'aucune fiche: c'est tout l'intérêt.
    final hits = searchVault(_coffre(), 'courri');
    expect(hits.single.entry.key, 'comptes perso');
    expect(hits.single.matchedTitle, 'courrier');
  });

  test('une ligne de valeur est trouvée', () {
    final hits = searchVault(_coffre(), '12345');
    expect(hits.single.entry.key, 'banque');
    expect(hits.single.matchedLine, '12345678');
  });

  test('le nom l\'emporte sur l\'intertitre, l\'intertitre sur la valeur', () {
    final hits = searchVault(_coffre(), 'wifi');
    expect(hits.single.matchedTitle, 'wifi');
    expect(hits.single.matchedLine, isNull);
  });

  test('une fiche n\'apparaît qu\'une fois même si elle correspond partout', () {
    final coffre = Vault([
      VaultEntry.now(key: 'test', value: 'test:\ntest\ntest'),
    ]);
    expect(searchVault(coffre, 'test').length, 1);
  });

  test('la casse et les accents composés sont ignorés', () {
    final coffre = Vault([
      VaultEntry.now(key: 'divers', value: 'Caf\u00e9:\nvaleur'),
    ]);
    // Le même mot écrit avec un accent combinant.
    expect(searchVault(coffre, 'cafe\u0301').single.matchedTitle, 'Caf\u00e9');
    expect(searchVault(coffre, 'CAF\u00c9').single.matchedTitle, 'Caf\u00e9');
  });

  test('une requête sans correspondance ne rend rien', () {
    expect(searchVault(_coffre(), 'zzz'), isEmpty);
  });

  test('l\'ordre du coffre est conservé', () {
    final hits = searchVault(_coffre(), 'e');
    expect(hits.map((h) => h.entry.key).toList(), ['banque', 'comptes perso']);
  });
}
```

- [ ] **Step 2: Constater le rouge**

Run: `flutter test test/model/vault_search_test.dart`
Expected: `Target of URI doesn't exist: 'package:safe/model/vault_search.dart'`.

- [ ] **Step 3: Écrire `lib/model/vault_search.dart`**

```dart
import 'entry_text.dart';
import 'vault.dart';

/// Une fiche trouvée, et ce qui l'a fait trouver.
///
/// [matchedTitle] et [matchedLine] servent au surlignage: montrer *pourquoi*
/// une fiche remonte, sans quoi une recherche sur le contenu rend une liste de
/// noms qui n'ont rien à voir avec ce qu'on a tapé.
class SearchHit {
  const SearchHit({required this.entry, this.matchedTitle, this.matchedLine});

  final VaultEntry entry;
  final String? matchedTitle;
  final String? matchedLine;
}

/// Cherche [query] dans les noms de fiches, les intertitres de blocs et les
/// lignes de valeur.
///
/// Chercher par nom seul ne suffit plus: une fiche « comptes perso » peut
/// contenir un bloc « courrier », et « courrier » n'est alors le nom de rien.
///
/// Indexer les lignes de valeur est un choix assumé du propriétaire du dépôt:
/// une valeur peut apparaître surlignée dans les résultats sans qu'un bloc ait
/// été ouvert, ce qui contourne la règle de masquage. Voir la spec.
///
/// Rien n'est indexé sur le disque: tout est recalculé à chaque frappe.
List<SearchHit> searchVault(Vault vault, String query) {
  final needle = canonicalKey(query.trim());
  if (needle.isEmpty) {
    return [for (final entry in vault.entries) SearchHit(entry: entry)];
  }

  final hits = <SearchHit>[];
  for (final entry in vault.entries) {
    if (canonicalKey(entry.key).contains(needle)) {
      hits.add(SearchHit(entry: entry));
      continue;
    }

    final groups = parseEntryText(entry.value);

    // Le titre d'abord: il dit de quoi il s'agit, la valeur ne dit rien.
    final title = groups
        .map((group) => group.title)
        .firstWhere(
          (title) => title != null && canonicalKey(title).contains(needle),
          orElse: () => null,
        );
    if (title != null) {
      hits.add(SearchHit(entry: entry, matchedTitle: title));
      continue;
    }

    final line = groups
        .expand((group) => group.lines)
        .where((line) => canonicalKey(line).contains(needle))
        .firstOrNull;
    if (line != null) {
      hits.add(SearchHit(entry: entry, matchedLine: line));
    }
  }
  return hits;
}
```

- [ ] **Step 4: Constater le vert**

Run: `flutter test test/model/vault_search_test.dart`
Expected: 9 tests verts.

- [ ] **Step 5: Vérifier la suite et commiter**

```bash
flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add lib/model/vault_search.dart test/model/vault_search_test.dart
git commit -m "feat: la recherche voit l'intérieur des fiches

Le nouveau modèle rend la recherche par nom presque inutile: un
service est désormais un bloc à l'intérieur d'une fiche, et son nom
n'est le nom de rien. La recherche indexe donc les noms de fiches, les
intertitres de blocs et les lignes de valeur, et rend ce qui a
provoqué la correspondance pour que l'écran puisse le surligner.

Indexer les valeurs contourne la règle de masquage: une valeur peut
apparaître dans les résultats sans qu'un bloc ait été ouvert. Choix
assumé par le propriétaire du dépôt, motivé dans la spec.

Rien n'est indexé sur le disque.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: L'accueil à deux onglets

**Files:**
- Create: `lib/ui/home_screen.dart`, `lib/ui/vault_tab.dart`, `lib/ui/generator_tab.dart`
- Modify: `lib/main.dart`
- Delete: `lib/ui/entries_screen.dart`
- Test: `test/ui/home_screen_test.dart`, `test/ui/generator_tab_test.dart`; réécrire `test/ui/entries_screen_test.dart` en `test/ui/vault_tab_test.dart`

**Interfaces:**
- Consumes: `SafePillTabs`, `SafePrimaryButton`, `searchVault`, `GeneratorSession`, `EntryScreen`, `NewEntryScreen`, `SafeLogo`.
- Produces: `HomeScreen({required VaultSession session, SecureClipboard? clipboard, VaultTransfer? transfer, SettingsStore? settings, Key? key})`.

`HomeScreen` remplace `EntriesScreen` dans `VaultGate` — mêmes paramètres, pour que `main.dart` ne change qu'au nom de la classe. Il possède le `GeneratorSession` et le libère dans son `dispose`.

- [ ] **Step 1: Écrire le test rouge de l'accueil**

Créer `test/ui/home_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/state/vault_session.dart';
import 'package:safe/ui/home_screen.dart';
import 'package:safe/ui/theme/safe_theme.dart';

import '../support/session_fixture.dart';

Widget _accueil(VaultSession session) => MaterialApp(
  theme: safeLightTheme(),
  home: HomeScreen(session: session, settings: MemorySettingsStore()),
);

void main() {
  testWidgets('les deux onglets sont là, Coffre d\'abord', (tester) async {
    final session = await makeUnlockedSession(keys: ['gmail']);
    await tester.pumpWidget(_accueil(session));
    await tester.pumpAndSettle();

    expect(find.text('Coffre'), findsOneWidget);
    expect(find.text('Générateur'), findsOneWidget);
    expect(find.text('gmail'), findsOneWidget);
    session.lock();
  });

  testWidgets('l\'onglet Générateur montre une valeur et ses réglages', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_accueil(session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Générateur'));
    await tester.pumpAndSettle();

    expect(find.text('Copier'), findsOneWidget);
    expect(find.text('Lettres'), findsOneWidget);
    expect(find.text('+ chiffres'), findsOneWidget);
    expect(find.text('+ symboles'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    session.lock();
  });

  testWidgets('« Nouvelle fiche » est visible sur les deux onglets', (
    tester,
  ) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_accueil(session));
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle fiche'), findsOneWidget);
    await tester.tap(find.text('Générateur'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle fiche'), findsOneWidget);
    session.lock();
  });

  testWidgets('la recherche trouve un intertitre de bloc', (tester) async {
    final session = await makeUnlockedSession();
    await session.save(
      session.vault!.upsert(
        VaultEntry.now(key: 'comptes', value: 'courrier:\nvaleur'),
      ),
    );
    await tester.pumpWidget(_accueil(session));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search')), 'courri');
    await tester.pumpAndSettle();

    expect(find.text('comptes'), findsOneWidget);
    expect(find.textContaining('courrier'), findsWidgets);
    session.lock();
  });

  testWidgets('coffre vide: une invite, pas une liste blanche', (tester) async {
    final session = await makeUnlockedSession();
    await tester.pumpWidget(_accueil(session));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aucune'), findsOneWidget);
    session.lock();
  });
}
```

avec `import 'package:safe/model/vault.dart';`.

Créer `test/ui/generator_tab_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/state/generator_session.dart';
import 'package:safe/ui/generator_tab.dart';
import 'package:safe/ui/theme/safe_theme.dart';
import 'package:safe/util/clipboard.dart';

import '../support/session_fixture.dart';

void main() {
  testWidgets('« Copier » devient « Copié ✓ » puis revient', (tester) async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);
    final clipboard = SecureClipboard();
    addTearDown(clipboard.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: Scaffold(
          body: GeneratorTab(generator: gen, clipboard: clipboard),
        ),
      ),
    );

    await tester.tap(find.text('Copier'));
    await tester.pump();
    expect(find.text('Copié ✓'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1700));
    expect(find.text('Copier'), findsOneWidget);
    vault.lock();
  });

  testWidgets('régénérer remplit l\'historique, au plus trois', (tester) async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: Scaffold(body: GeneratorTab(generator: gen)),
      ),
    );

    expect(find.text('GÉNÉRÉ AVANT'), findsNothing);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const Key('regenerate')));
      await tester.pumpAndSettle();
    }
    expect(find.text('GÉNÉRÉ AVANT'), findsOneWidget);
    expect(find.text('Effacé au verrouillage. Jamais écrit sur le disque.'),
        findsOneWidget);
    expect(find.byKey(const Key('copy-history-2')), findsOneWidget);
    expect(find.byKey(const Key('copy-history-3')), findsNothing);
    vault.lock();
  });

  testWidgets('la pastille active se voit', (tester) async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: Scaffold(body: GeneratorTab(generator: gen)),
      ),
    );

    // Défaut: « + symboles ».
    expect(gen.set.label, '+ symboles');
    await tester.tap(find.text('Lettres'));
    await tester.pumpAndSettle();
    expect(gen.set.label, 'Lettres');
    vault.lock();
  });

  testWidgets('le curseur régénère à la nouvelle longueur', (tester) async {
    final vault = await makeUnlockedSession();
    final gen = GeneratorSession(vault);
    addTearDown(gen.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: safeLightTheme(),
        home: Scaffold(body: GeneratorTab(generator: gen)),
      ),
    );

    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(gen.value.length, gen.length);
    expect(gen.length, greaterThan(20));
    vault.lock();
  });
}
```

- [ ] **Step 2: Constater le rouge**

Run: `flutter test test/ui/home_screen_test.dart test/ui/generator_tab_test.dart`
Expected: URI introuvables.

- [ ] **Step 3: Écrire `lib/ui/generator_tab.dart`**

`GeneratorTab({required GeneratorSession generator, SecureClipboard? clipboard, Key? key})`, `AnimatedBuilder` sur `generator`. De haut en bas: carte blanche rayon 18, `padding: 20`; valeur en `SafeText.generatorValue`, `constraints: BoxConstraints(minHeight: 62)`; ligne de boutons — `Expanded(SafePrimaryButton(label: _copie ? 'Copié ✓' : 'Copier'))` de hauteur 48 et bouton `Key('regenerate')` de 48 × 48 bordé `controlBorder` avec `↻` en `accent`; libellé « LONGUEUR » + valeur mono 13 alignée à droite; `Slider(min: minPasswordLength.toDouble(), max: maxPasswordLength.toDouble(), divisions: maxPasswordLength - minPasswordLength)`; trois pastilles de hauteur 36 en `Row` avec `gap 7`, active bordée `1.5 accent` sur `softAccentSurface` en `accentDark` 500, inactive bordée `1 controlBorder` en `secondaryText` 400; puis, si `generator.history` n'est pas vide, le bloc « GÉNÉRÉ AVANT » avec au plus trois lignes `Key('copy-history-$i')` et la mention.

Le retour « Copié ✓ » dure 1,6 s, géré par un `Timer` annulé dans `dispose`.

- [ ] **Step 4: Écrire `lib/ui/vault_tab.dart`**

`VaultTab({required VaultSession session, required ValueChanged<VaultEntry> onOpen, Key? key})`. Champ de recherche `Key('search')` en pilule `barSurface` hauteur 44 avec l'icône `Icons.search` 15 px `tertiaryText`. Puis `ListView` des `SearchHit`. Chaque ligne: puce de 8 px en cercle vide `1.5 inactiveBullet` (l'épinglage n'existe pas, voir le rapport), nom en `SafeText.listTitle` `ink` tronqué, hairline bas, `padding: EdgeInsets.symmetric(vertical: 15)`. Quand le hit porte un `matchedTitle` ou un `matchedLine`, une seconde ligne l'affiche en `SafeText.counter` sur fond `searchHighlight` en `accentDark`, avec une action « copier ».

Vides: coffre vide → « Aucune fiche pour l'instant. »; recherche sans résultat → « Aucun résultat. »

- [ ] **Step 5: Écrire `lib/ui/home_screen.dart`**

En-tête: `SafeLogo(size: 17)` + « safe » en `SafeText.wordmark`, et à droite un `IconButton` de `SafeMetrics.touchTarget` vers `SettingsScreen`. Puis `SafePillTabs(labels: ['Coffre', 'Générateur'], …)`. Puis le corps, `Expanded`. Puis le bouton « Nouvelle fiche » dans un `padding: EdgeInsets.fromLTRB(24, 14, 24, 22)`.

`HomeScreen` crée le `GeneratorSession` dans `initState` et le libère dans `dispose`. La navigation vers `EntryScreen` et `NewEntryScreen` part d'ici.

- [ ] **Step 6: Constater le vert**

Run: `flutter test test/ui/home_screen_test.dart test/ui/generator_tab_test.dart`
Expected: 9 tests verts.

- [ ] **Step 7: Basculer `main.dart` et retirer l'ancienne liste**

Dans `lib/main.dart`, remplacer `EntriesScreen(...)` par `HomeScreen(...)` — mêmes arguments. Puis transposer `test/ui/entries_screen_test.dart` vers `test/ui/vault_tab_test.dart` en gardant chaque assertion qui a encore un sens (les tests « révéler affiche la valeur » et « supprimer » visent des gestes qui ont déménagé dans la fiche: les déplacer vers `entry_screen_test.dart` plutôt que les jeter). Puis:

```bash
git rm lib/ui/entries_screen.dart test/ui/entries_screen_test.dart
grep -rn "entries_screen\|EntriesScreen" lib test
```

Expected: aucun résultat.

- [ ] **Step 8: Vérifier la suite et l'application entière**

```bash
flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
flutter run -d emulator-5554
```

Parcourir: déverrouillage, liste, ouverture d'une fiche, copie, retour, onglet générateur, régénération, historique, copie, nouvelle fiche, enregistrement, recherche par intertitre.

- [ ] **Step 9: Commit**

```bash
git add -- lib/ui/home_screen.dart lib/ui/vault_tab.dart lib/ui/generator_tab.dart lib/main.dart test/ui
git commit -m "feat: l'accueil a deux onglets, et le générateur est l'un d'eux

Le générateur quitte l'écran d'édition, où il ne servait qu'aux
entrées tenant en un mot de passe, et devient un outil autonome: on
génère, on copie, on colle où on veut. Son historique de session tient
trois valeurs, en mémoire, vidées au verrouillage.

La liste utilise la recherche dans le contenu et montre l'intertitre
qui a fait remonter une fiche.

Les puces de la liste restent des cercles vides: la maquette montre
une puce pleine « si épinglée », mais ne dit ni comment on épingle ni
où l'état vivrait. Rien n'est inventé.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 10: Les réglages restylés

**Files:**
- Modify: `lib/ui/settings_screen.dart`

**Interfaces:**
- Consumes: `SafeTokens`, `SafeText`, `SafeMetrics`, `SafePrimaryButton`, `SafeSecondaryButton`.
- Produces: rien de nouveau.

**Ne rien changer à la structure ni aux fonctions.** Changer le mot de passe maître, le verrouillage automatique, le blocage des captures, la restauration de la sauvegarde précédente, l'export et l'import restent exactement où ils sont et font exactement ce qu'ils font. Seuls changent les couleurs, les polices et les formes. Les tests existants (`settings_failure_test.dart`, `screenshot_setting_test.dart`, `auto_lock_persistence_test.dart`, `restore_backup_test.dart`, `change_password_test.dart`, `transfer_flow_test.dart`) doivent passer **sans modification**; s'ils échouent, c'est que la structure a bougé.

- [ ] **Step 1: Constater le point de départ**

Run: `flutter test test/ui/settings_failure_test.dart test/ui/screenshot_setting_test.dart test/ui/auto_lock_persistence_test.dart test/ui/restore_backup_test.dart test/ui/change_password_test.dart test/ui/transfer_flow_test.dart`
Expected: tous verts. Noter le compte exact: c'est le contrat à ne pas casser.

- [ ] **Step 2: Restyler**

Remplacer les couleurs et les styles par les tokens: fond `pageBackground`, cartes `cardSurface` rayon `SafeMetrics.cardRadius`, titres en `SafeText.screenTitle`, libellés de section en `SafeText.sectionLabel` `tertiaryText`, textes secondaires en `secondaryText`, boutons par `SafePrimaryButton` / `SafeSecondaryButton`, séparateurs en `hairline`, gouttières `SafeMetrics.gutter`. Les avertissements (irrécupérabilité du mot de passe maître, effet de la restauration) gardent leur texte mot pour mot.

- [ ] **Step 3: Constater que rien n'a bougé**

Run: la même commande qu'au Step 1.
Expected: le même compte, tous verts, aucun test modifié.

- [ ] **Step 4: Regarder l'écran**

```bash
flutter run -d emulator-5554
```

Ouvrir les réglages: plus aucun aplat sombre, la même identité que les autres écrans. Vérifier que le sélecteur de délai et la bascule des captures répondent toujours.

- [ ] **Step 5: Vérifier la suite et commiter**

```bash
flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add lib/ui/settings_screen.dart
git commit -m "style: les réglages rejoignent le thème clair

Couleurs, polices et formes seulement. La structure, les libellés et
les avertissements ne bougent pas — le designer renvoie explicitement
le redessin des réglages à un second temps, et leurs tests passent
sans avoir été touchés, ce qui le prouve.

Sans ce commit l'application porterait deux identités: quatre écrans
clairs et un écran resté sombre.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 11: Finition, vérification sur appareil, rapport

**Files:**
- Modify: `README.md`, `AUDIT.md` ou nouveau `docs/superpowers/specs/2026-08-19-safe-refonte-design.md` (section de clôture)
- Test: la suite entière

- [ ] **Step 1: Chasser ce qui n'est plus appelé**

```bash
grep -rn "EntryEditScreen\|EntriesScreen\|CharacterSet.lettersDigits" lib test
flutter analyze
dart run dart_code_metrics:metrics check-unused-code lib 2>/dev/null || echo "outil absent, revue manuelle"
```

Toute fonction devenue morte est supprimée dans ce commit, avec la preuve de sa non-utilisation dans le message.

- [ ] **Step 2: Mesurer la couverture**

```bash
flutter test --coverage
lcov --summary coverage/lcov.info
```

Noter le pourcentage global et celui de chaque nouveau fichier. Tout fichier de `lib/` sous 80 % reçoit un test avant la clôture, ou une ligne dans « ce qui n'a pas été fait » expliquant pourquoi il n'en reçoit pas.

- [ ] **Step 3: Vérifier sur l'émulateur, preuves à l'appui**

```bash
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am start -n dev.safe.safe/.MainActivity
adb -s emulator-5554 logcat -d -s flutter:E
```

Parcours à exécuter et à consigner: création d'un coffre, création d'une fiche à trois blocs, ouverture et fermeture d'un bloc, copie d'une ligne et copie d'un bloc, mode texte brut avec recomposition en direct, « Compris » puis « Syntaxe », recherche par intertitre puis par valeur, générateur — longueur, jeux, historique, copie —, verrouillage automatique et vérification que l'historique du générateur est vide et les blocs refermés, enfin export puis import d'un coffre pour prouver que la compatibilité tient.

- [ ] **Step 4: Vérifier qu'un coffre d'avant la refonte s'ouvre**

Le point le plus important. Prendre un export fait avec l'ancienne version, l'importer dans la nouvelle sur l'émulateur, et vérifier que chaque entrée est là et lisible. Si l'utilisateur a une sauvegarde à portée, la lui demander plutôt que d'en fabriquer une.

Consigner le résultat mot pour mot, y compris que les valeurs d'une ligne s'affichent désormais en clair comme des commentaires — c'est la conséquence attendue du choix (c).

- [ ] **Step 5: Mettre à jour la documentation**

`README.md`: la description d'une entrée passe de « clef et valeur » à « nom et bloc de texte », la section du générateur change d'écran, et la syntaxe des blocs est expliquée en cinq lignes. **Exécuter chaque commande citée** avant de la laisser dans le fichier.

Ajouter en fin de spec une section « État à la clôture » listant: ce qui a été fait, ce qui a été vérifié sur appareil et comment, ce qui n'a pas été fait — thème sombre, épinglage, réglages redessinés, icône de lancement inchangée — et ce que l'utilisateur doit vérifier lui-même.

- [ ] **Step 6: Installer sur le téléphone réel, seulement après accord**

**Ne pas exécuter sans demander.** Le Pixel 9a porte le coffre réel de l'utilisateur.

```bash
flutter build apk --release
adb -s 5A101JEBF39259 install -r build/app/outputs/flutter-apk/app-release.apk
```

`-r` obligatoire: sans lui, ou avec `adb uninstall`, le coffre et les pièces jointes sont effacés. Vérifier `firstInstallTime` inchangé après l'installation.

- [ ] **Step 7: Commit de clôture**

```bash
flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add README.md docs/superpowers/specs/2026-08-19-safe-refonte-design.md
git commit -m "docs: état de la refonte à la clôture

Ce qui a été fait, ce qui a été vérifié sur l'émulateur et comment, ce
qui ne l'a pas été et pourquoi: thème sombre faute de palette validée,
épinglage faute de geste spécifié, réglages non redessinés par choix,
icône de lancement inchangée.

Le README ne parle plus de clef et de valeur: une entrée est un nom et
un bloc de texte. Chaque commande citée a été exécutée avant d'être
laissée dans le fichier.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Auto-relecture du plan

**Couverture de la spec.** Parseur → tâche 1. Tokens, polices, thème clair → tâche 2. Logo → tâche 3. Déverrouillage, sous-titre sans compteur, vrai délai → tâche 4. Générateur, jeux, bornes, historique → tâches 5 et 9. Masquage et blocs, tuto, texte brut, toast, préférence persistée → tâche 6. Nouvelle fiche → tâche 7. Recherche → tâches 8 et 9. Accueil, onglets, liste → tâche 9. Réglages → tâche 10. Écarts plateforme, « ce qui n'est pas fait », compatibilité des exports → tâche 11.

**Points laissés volontairement ouverts,** à trancher pendant l'exécution et à consigner:

- Les pièces jointes dans la fiche: le handoff ne montre qu'un bouton « Pièce jointe ». La tâche 6 réutilise `AttachmentsSection` telle quelle; si son apparence jure trop, la restyler dans la tâche 10 plutôt que d'improviser en tâche 6.
- Le geste de suppression d'une fiche n'apparaît sur aucune maquette validée. Il existe aujourd'hui dans la liste. La tâche 9 doit le conserver quelque part — sinon une fiche devient indestructible — et le signaler comme non spécifié.

**Cohérence des noms.** `parseEntryText`, `describeGroups`, `EntryGroup.isComment`, `SafeTokens.of`, `SafeMetrics.pillHeight`, `SafeText.entryValue`, `SafePrimaryButton`, `SafePillTabs`, `showSafeToast`, `BlockCard`, `CommentBlock`, `GeneratorSession.regenerate`, `searchVault`, `SearchHit.matchedTitle` — mêmes orthographes de bout en bout, des interfaces aux tests.
