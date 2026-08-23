import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../model/vault.dart';
import '../model/vault_search.dart';
import '../state/vault_session.dart';
import 'theme/safe_theme.dart';
import 'widgets/block_card.dart';

/// L'onglet Coffre de l'accueil: la recherche, puis la liste des fiches.
///
/// Aucune valeur ne s'affiche d'elle-même. La seule exception est l'extrait
/// qui explique *pourquoi* une fiche remonte d'une recherche: sans lui, une
/// recherche dans le contenu rend une liste de noms qui n'ont rien à voir avec
/// ce qu'on a tapé. C'est un choix assumé, documenté dans [searchVault].
class VaultTab extends StatefulWidget {
  const VaultTab({
    required this.session,
    required this.onOpen,
    this.onCopy,
    super.key,
  });

  final VaultSession session;

  /// Ouvre la fiche demandée. La navigation appartient à l'accueil: cet onglet
  /// n'empile aucune route.
  final ValueChanged<VaultEntry> onOpen;

  /// Copie l'extrait qui a fait remonter une fiche — la ligne **brute** du
  /// coffre. Confié à l'accueil, qui possède le presse-papier auto-effaçant;
  /// nul, l'action de copie ne s'affiche pas.
  final ValueChanged<String>? onCopy;

  @override
  State<VaultTab> createState() => _VaultTabState();
}

class _VaultTabState extends State<VaultTab> {
  /// Hauteur visible du champ de recherche.
  static const double _hauteurRecherche = SafeMetrics.searchHeight;

  /// Marge touchable du champ, de part et d'autre. Reprise sur l'écart qui
  /// suit, pour que la liste commence exactement où elle commençait.
  static const double _margeRecherche =
      (SafeMetrics.touchTarget - _hauteurRecherche) / 2;

  /// Diamètre de la puce de ligne.
  static const double _puce = 8;

  final TextEditingController _recherche = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    _recherche.dispose();
    super.dispose();
  }

  /// Une fiche enregistrée depuis un autre écran doit apparaître au retour.
  void _onSession() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    final t = L.of(context);
    final vault = widget.session.vault;
    final hits = vault == null
        ? const <SearchHit>[]
        : searchVault(vault, _query);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _champ(tokens, t),
        const SizedBox(height: 12 - _margeRecherche),
        Expanded(
          child: hits.isEmpty
              ? _vide(tokens, t)
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: hits.length,
                  itemBuilder: (context, index) =>
                      _ligne(tokens, t, hits[index]),
                ),
        ),
      ],
    );
  }

  Widget _champ(SafeTokens tokens, L t) => SizedBox(
    // Le champ se voit sur 44 px et se touche sur 48: les deux pixels de
    // marge, en haut et en bas, sont repris sur l'écart qui suit.
    height: SafeMetrics.touchTarget,
    child: Center(
      child: Container(
        height: _hauteurRecherche,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: tokens.barSurface,
          borderRadius: BorderRadius.circular(_hauteurRecherche / 2),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 15, color: tokens.tertiaryText),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const Key('search'),
                controller: _recherche,
                // On y tape des noms de fiches et des morceaux de leur
                // contenu, tous chiffrés dans le coffre: le clavier n'a pas à
                // les apprendre pour les proposer ailleurs.
                autocorrect: false,
                enableSuggestions: false,
                style: SafeText.listTitle.copyWith(color: tokens.ink),
                cursorColor: tokens.accent,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: t.searchHint,
                  hintStyle: SafeText.listTitle.copyWith(
                    color: tokens.hintText,
                  ),
                ),
                onChanged: (valeur) {
                  // Taper est souvent la seule activité d'une recherche
                  // longue: sans cela, le coffre se verrouille sous les doigts.
                  widget.session.touch();
                  setState(() => _query = valeur);
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _vide(SafeTokens tokens, L t) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        _query.trim().isEmpty ? t.vaultEmpty : t.searchEmpty,
        textAlign: TextAlign.center,
        style: SafeText.meta.copyWith(color: tokens.hintText),
      ),
    ),
  );

  Widget _ligne(SafeTokens tokens, L t, SearchHit hit) {
    final extrait = hit.matchedTitle ?? hit.matchedLine;
    return GestureDetector(
      key: Key('entry-${hit.entry.key}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onOpen(hit.entry),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.hairline)),
        ),
        child: Padding(
          // Quinze pixels en haut, et en bas seulement quand la ligne s'arrête
          // au nom: l'extrait apporte sa propre bande touchable, dont le
          // centrage rend le même air que ces quinze pixels.
          padding: EdgeInsets.only(top: 15, bottom: extrait == null ? 15 : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: _puce,
                    height: _puce,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // Toujours vide: la maquette montre une puce pleine « si
                      // épinglée », mais ne dit ni comment on épingle ni où
                      // l'état vivrait. Rien n'est inventé.
                      border: Border.all(
                        color: tokens.inactiveBullet,
                        width: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      hit.entry.key,
                      style: SafeText.listTitle.copyWith(color: tokens.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hit.entry.attachments.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Icon(
                      key: Key('has-attachments-${hit.entry.key}'),
                      Icons.attach_file,
                      size: 14,
                      color: tokens.tertiaryText,
                      semanticLabel: t.attachmentCount(
                        hit.entry.attachments.length,
                      ),
                    ),
                  ],
                ],
              ),
              if (extrait != null) _extrait(tokens, hit, extrait),
            ],
          ),
        ),
      ),
    );
  }

  Widget _extrait(SafeTokens tokens, SearchHit hit, String extrait) => SizedBox(
    // La bande fait une cible tactile de haut: c'est elle qui rend l'action de
    // copie touchable, et son centrage rend au nom l'air qu'il avait.
    height: SafeMetrics.touchTarget,
    child: Row(
      children: [
        const SizedBox(width: _puce + 11),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: tokens.searchHighlight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                extrait,
                style: SafeText.counter.copyWith(color: tokens.accentDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        // Seulement sur une ligne de valeur: un intertitre n'est qu'un nom,
        // il n'y a rien à coller. Et c'est la ligne **brute** qui part au
        // presse-papier — une valeur qui se termine par une espace se
        // collerait sinon amputée, en silence.
        if (widget.onCopy != null && hit.matchedLine != null)
          SafeCopyAction(
            key: Key('copy-hit-${hit.entry.key}'),
            label: 'copier',
            onTap: () => widget.onCopy!(hit.matchedLine!),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18.5),
          ),
      ],
    ),
  );
}
