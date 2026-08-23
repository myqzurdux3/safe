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

    // La ligne brute, pas la rognée: c'est elle que l'écran affichera pour
    // le surlignage, et probablement celle qu'il proposera de copier. Rogner
    // ici referait exactement l'erreur que `EntryGroup.rawLines` existe pour
    // éviter: un mot de passe qui se termine par une espace se collerait
    // faux, en silence. Chercher dans le brut plutôt que dans la version
    // rognée ne change aucun résultat: seuls des espaces de bord séparent
    // les deux, et `contains` les ignore de toute façon.
    final line = groups
        .expand((group) => group.rawLines)
        .where((line) => canonicalKey(line).contains(needle))
        .firstOrNull;
    if (line != null) {
      hits.add(SearchHit(entry: entry, matchedLine: line));
    }
  }
  return hits;
}
