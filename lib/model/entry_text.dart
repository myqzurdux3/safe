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
  const EntryGroup({this.title, required this.lines, List<String>? rawLines})
    : _rawLines = rawLines;

  /// Titre du bloc, sans son deux-points. `null` pour un commentaire.
  final String? title;

  /// Lignes de contenu, titre exclu, espaces de bord rognés. C'est la version
  /// qui s'affiche: un mot de passe suivi d'espaces se lit mieux sans elles.
  final List<String> lines;

  final List<String>? _rawLines;

  /// Les mêmes lignes, telles qu'elles sont dans le coffre.
  ///
  /// C'est la version qui se **copie**: rogner un mot de passe qui se termine
  /// par une espace le collerait faux, en silence, et l'utilisateur en
  /// accuserait le site. Seul le retour chariot d'un texte venu de Windows est
  /// écarté: il termine la ligne, il n'en fait pas partie.
  ///
  /// Absent d'un groupe construit à la main, il retombe sur [lines]: ce champ
  /// s'ajoute au module sans rien changer à ce qui existait.
  List<String> get rawLines => _rawLines ?? lines;

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
    current.rawLines.add(
      line.endsWith('\r') ? line.substring(0, line.length - 1) : line,
    );
  }

  return [
    for (final group in groups)
      // Un « : » seul ouvre un titre vide: sans ligne derrière, il ne porte
      // rien et n'a rien à afficher.
      if ((group.title?.isNotEmpty ?? false) || group.lines.isNotEmpty)
        EntryGroup(
          title: group.title,
          lines: List.unmodifiable(group.lines),
          rawLines: List.unmodifiable(group.rawLines),
        ),
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

  /// Toujours remplie en même temps que [lines]: les deux se lisent par rang.
  final List<String> rawLines = [];
}
