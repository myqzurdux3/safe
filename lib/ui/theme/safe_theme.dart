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
    required this.commentText,
    required this.softAccentText,
    required this.tabShadow,
    required this.toastShadow,
    required this.searchHighlight,
  });

  final Color pageBackground;
  final Color barSurface;
  final Color tabContainer;
  final Color cardSurface;
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

  /// Texte d'un commentaire: plus doux que l'encre, un commentaire n'est pas
  /// une valeur.
  final Color commentText;

  /// Texte de glose sur la surface accent douce, celle du tuto de syntaxe.
  final Color softAccentText;

  /// Les deux seules ombres du handoff: la pastille d'onglet active et le
  /// toast. Elles sont ici parce qu'une ombre est une couleur.
  final Color tabShadow;
  final Color toastShadow;

  final Color searchHighlight;

  static const SafeTokens light = SafeTokens(
    pageBackground: Color(0xFFF4F2EE),
    barSurface: Color(0xFFEAE7E1),
    tabContainer: Color(0xFFE4E1DB),
    cardSurface: Color(0xFFFFFFFF),
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
    commentText: Color(0xFF5F6862),
    softAccentText: Color(0xFF2C4438),
    tabShadow: Color(0x17000000),
    toastShadow: Color(0x2E000000),
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
