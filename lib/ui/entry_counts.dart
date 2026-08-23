import '../l10n/app_localizations.dart';
import '../model/entry_text.dart';

/// Le compteur affiché en en-tête de fiche: « 5 blocs · 7 lignes ».
///
/// Il vivait dans `entry_text.dart`, qui est du Dart pur — aucun état, aucune
/// dépendance Flutter, aucun accès disque. Un compteur traduit y aurait
/// introduit les deux: la dépendance aux traductions, et donc à Flutter. Il
/// vit donc ici, du côté qui a déjà un `BuildContext`.
String describeGroups(L t, List<EntryGroup> groups) =>
    '${t.entryBlockCount(countBlocks(groups))} · '
    '${t.entryLineCount(countLines(groups))}';
