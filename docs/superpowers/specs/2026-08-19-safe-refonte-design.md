# Refonte de l'interface de safe

Date : 2026-08-19
État : validé, prêt pour le plan d'implémentation

## D'où vient ce document

Un designer a livré une maquette (`Safe — Refonte.dc.html`) et un handoff écrit. Ces
fichiers ne sont **pas** versionnés : leur README cite en exemple du texte présenté comme
réel — adresses, mots de passe, une note sur une clef SSH — et ce dépôt est public. Les
valeurs de design qu'ils portent sont donc recopiées ici, qui devient la référence.

Le handoff supposait une application GTK4/libadwaita. La vraie pile est Flutter 3.44.6 /
Dart 3.12.2, visant Android et Linux. Les écarts que cela impose sont listés en fin de
document.

## Ce qui change

Trois choses, dont une seule est structurante.

1. **Le contenu d'une entrée devient du texte libre.** Une entrée n'est plus « une clef et
   un mot de passe masqué » mais un bloc de texte multiligne : plusieurs services, des
   codes, des notes. L'affichage — blocs, lignes copiables, commentaires — est **dérivé du
   texte à la lecture**, jamais stocké.
2. **Le générateur quitte l'écran d'édition** et devient un onglet de l'accueil, sans lien
   avec un champ.
3. **La direction visuelle** passe du sombre à un thème clair.

Le format du fichier coffre, le chiffrement, les pièces jointes, l'export et l'import ne
changent pas.

## Aucune migration

`VaultEntry` porte déjà `{key, value, created, updated, attachments}` où `value` est une
`String`. Le modèle demandé — `{nom, texte, pièces jointes}` — s'y superpose exactement.
Les coffres existants et les exports déjà faits se relisent sans conversion. La seule
addition est un champ de préférence, `syntaxTutorialDismissed`, dont l'absence vaut
`false` : les fichiers `settings.json` existants restent valides.

## Le parseur

Nouveau module `lib/model/entry_text.dart`, Dart pur : aucun état, aucune dépendance
Flutter, aucun accès disque. C'est la seule vraie nouveauté logique de la refonte, et la
première chose écrite.

```dart
class EntryGroup {
  const EntryGroup({this.title, required this.lines});
  final String? title;      // null == commentaire
  final List<String> lines;
  bool get isComment => title == null;
}

List<EntryGroup> parseEntryText(String raw);
```

Sur le texte découpé en lignes, chaque ligne étant `trim()`ée :

1. Ligne vide : **ferme** le bloc courant.
2. Ligne non vide de **44 caractères ou moins finissant par `:`** : ouvre un bloc dont le
   titre est la ligne sans son `:` final.
3. Toute autre ligne : rejoint le bloc courant ; s'il n'y en a pas, elle ouvre un groupe
   **sans titre**, qui est un commentaire.
4. Les groupes sans titre et sans ligne sont écartés.
5. **L'ordre du document est conservé.** Un commentaire écrit entre deux blocs s'affiche
   entre ces deux blocs. Les commentaires ne sont ni regroupés ni repoussés en fin de
   fiche.

Le texte de l'utilisateur n'est jamais réécrit, normalisé ni réordonné.

Compteurs affichés : **blocs** = nombre de groupes, commentaires compris ; **lignes** =
total des lignes de contenu, titres exclus.

### Cas de test de référence

```
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
```

Attendu : cinq groupes dans cet ordre — bloc `courrier` (2 lignes), commentaire (1),
bloc `banque` (2), commentaire (1), bloc `wifi` (1). En-tête : « 5 blocs · 7 lignes ».

Cas limites à couvrir : titre de 44 caractères (accepté) et de 45 (devient une ligne de
contenu) ; `:` seul ; lignes vides consécutives ; texte entièrement vide ; texte sans
aucun `:`.

## Masquage — écart volontaire au handoff

Le handoff affiche les commentaires **en clair, sans geste** : ce sont des notes, pas des
secrets. Les lignes d'un bloc titré restent masquées jusqu'à ouverture du bloc, et cette
ouverture *est* le geste de révélation — pas de second bouton « voir » par ligne.

Appliqué tel quel, cela expose le contenu existant : une entrée d'aujourd'hui vaut une
valeur d'une seule ligne, sans `titre:`, donc un commentaire, donc affichée en clair à
l'ouverture de la fiche, là où elle est masquée aujourd'hui.

Deux replis ont été proposés — traiter une fiche sans aucun `titre:` comme un bloc unique
masqué, ou migrer le texte une fois. **Le propriétaire du dépôt a choisi de suivre le
handoff à la lettre**, en connaissance de cette conséquence. Le tuto de syntaxe, affiché
par défaut, indique le geste : ajouter une ligne `nom:` au-dessus d'une valeur la remasque.

Les valeurs révélées ne sont jamais écrites dans les journaux, et restent soumises au
réglage « bloquer les captures d'écran » existant.

## Recherche

Nouveau module `lib/model/vault_search.dart` :

```dart
class SearchHit {
  final VaultEntry entry;
  final String? matchedTitle;   // intertitre de bloc trouvé
  final String? matchedLine;    // ligne de contenu trouvée
}

List<SearchHit> searchVault(Vault vault, String query);
```

Chercher par nom de fiche seul devient inutile dès qu'une fiche regroupe plusieurs
services : « courrier » n'est alors le nom d'aucune fiche mais l'intertitre d'un bloc.
La recherche indexe donc **les noms de fiches, les intertitres de blocs et les lignes de
valeur**. Le résultat affiche la fiche avec la ligne trouvée en contexte, surlignée
(`#dff0e5` sur `#1f6f52`).

**Deuxième écart volontaire** : indexer les valeurs signifie qu'une ligne de valeur peut
apparaître surlignée dans la liste des résultats sans qu'aucun bloc ait été ouvert, ce qui
contourne la règle de masquage. Le propriétaire du dépôt l'a choisi en connaissance de
cause.

Comparaison casse et Unicode ignorées via `canonicalKey`, déjà en place. Tout est calculé
à chaque frappe et rien n'est indexé sur le disque.

## Générateur

`lib/state/generator_session.dart`, un `ChangeNotifier` qui écoute `VaultSession` : jeu de
caractères, longueur, valeur courante, et **historique des trois valeurs précédentes en
mémoire seulement**, vidé au verrouillage. Rien n'est écrit sur le disque — c'est ce que
l'écran promet.

`lib/util/password_generator.dart` change de bornes et de jeux :

```
lettres     abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ
+ chiffres  … + 23456789
+ symboles  … + !#$%&*+-?@
```

Les caractères ambigus (`l`, `I`, `O`, `0`, `1`) sont exclus. Longueur de 8 à **48**
(contre 128), défaut **20**, jeu par défaut **« + symboles »**. Chaque classe du jeu reste
garantie présente quand la longueur le permet, et le tirage reste `Random.secure()`.

Perte d'entropie assumée : le jeu complet passe de 94 à 67 caractères, soit 6,07 bits par
position au lieu de 6,55 — un demi-bit de moins. À 20 caractères, un mot de passe tiré
uniformément vaut encore 121 bits. Le gain est la compatibilité avec les formulaires qui refusent la
ponctuation exotique.

Le générateur disparaît de l'écran d'édition, où il n'avait pas de sens pour la majorité
des entrées.

## Écrans

| Fichier | Remplace | Contenu |
| --- | --- | --- |
| `lib/ui/unlock_screen.dart` | lui-même | Restylé |
| `lib/ui/home_screen.dart` | `entries_screen.dart` | En-tête, onglets, bouton de pied |
| `lib/ui/vault_tab.dart` | — | Recherche + liste |
| `lib/ui/generator_tab.dart` | — | Générateur plein écran |
| `lib/ui/entry_screen.dart` | `entry_edit_screen.dart` | Lecture / Texte brut |
| `lib/ui/new_entry_screen.dart` | mode création du même | Saisie initiale |
| `lib/ui/settings_screen.dart` | lui-même | Restylé, structure inchangée |

Widgets partagés dans `lib/ui/widgets/` : carte de bloc, commentaire, tuto de syntaxe,
onglets pilule, toast, bouton primaire, ligne de liste.

Fiche et nouvelle fiche sont deux fichiers : leurs structures diffèrent assez (la première
a une barre de mode et un panneau défilant, la seconde une carte de saisie et un
compteur) pour qu'un fichier unique à branches devienne illisible.

### Déverrouillage

Logo 34 px, 26 px d'espace, titre « Content de te revoir. » 600 30 px/1.15. Champ sans
boîte, filet bas `1.5px #183a2b`, valeur en mono 500 16 px `letter-spacing: .16em`, caret
`#2f7d5b`. Bouton œil à droite. Bouton primaire pleine largeur 50 px, rayon 25 px. Pied de
page rappelant le délai de verrouillage.

**Le sous-titre ne peut pas annoncer le nombre de fiches.** La maquette affiche « 14 fiches
attendent derrière ce mot de passe. » ; or l'en-tête du coffre fait 62 octets et ne
contient aucun compteur, tout le reste étant chiffré. Écrire ce nombre dans le
`settings.json` en clair le divulguerait à qui lit le disque. Le sous-titre sera donc sans
chiffre.

De même, le pied de page affichera le **vrai** délai de verrouillage automatique (30 s,
1, 2 ou 5 min selon le réglage) et non « 5 min » en dur.

### Accueil

En-tête : logo 17 px + logotype 19 px à gauche, commande réglages à droite. Onglets :
conteneur `#e4e1db` rayon 22 px, `padding: 4px`, deux pastilles de largeur égale,
hauteur 36 px, rayon 18 px ; active en `#fff` avec ombre `0 1px 2px rgba(0,0,0,.09)`.
Libellés « Coffre » et « Générateur ». Bouton « Nouvelle fiche » en pied, visible sur les
deux onglets.

Onglet Coffre : champ de recherche pilule `#eae7e1` hauteur 44 px, puis liste défilante.
Ligne : puce 8 px, nom 500 14.5 px, hairline bas, `padding: 15px 0`, troncature.

Onglet Générateur : carte blanche rayon 18 px, valeur en mono 400 19 px/1.55, hauteur
minimale 62 px ; « Copier » (48 px, devient « Copié » précédé d'une coche 1,6 s — voir
« Deux signes de la maquette n'existent pas dans les polices ») et régénérer 48 × 48 px ;
curseur de longueur 8–48 ; trois pastilles de jeu ; historique « GÉNÉRÉ AVANT » de trois
valeurs avec la mention « Effacé au verrouillage. Jamais écrit sur le disque. »

### La fiche

En-tête : retour + « Coffre », nom 600 24 px, méta « N blocs · N lignes » en mono
11.5 px. Barre de mode « Lecture » / « Texte brut », hauteur 28 px ; à droite un lien
« Syntaxe » visible seulement si le tuto est masqué.

Tuto de syntaxe : carte `#eaf4ee` rayon 14 px, trois lignes — `courrier:` ouvre un bloc,
une ligne vide le referme, un texte seul reste un commentaire à sa place — puis une action
« Compris » qui le masque définitivement (préférence persistée).

Mode Lecture, pour chaque groupe dans l'ordre du texte :

- **Bloc replié** : carte blanche rayon 14 px, chevron, titre en intertitre uppercase
  600 11 px, compteur « N lignes » à droite. Toute la carte est cliquable.
- **Bloc ouvert** : même carte bordée `1.5px #2f7d5b`, en-tête en `#1f6f52`, le compteur
  cède la place à « copier le bloc » (lignes jointes par `\n`, sans le titre). Puis une
  ligne par valeur : mono 12.5 px avec césure, action « copier », `padding: 11px 0`.
- **Commentaire** : pas de carte. Filet vertical 2 px `#d3d7d1`, texte mono 12 px/1.6
  `#5f6862`, action « copier » à droite.

Le panneau de contenu défile : un bloc long ne doit jamais être tronqué silencieusement.

Mode Texte brut : zone de saisie pleine largeur, fond `#fff`, bordure `1px #dcdfda`,
rayon 14 px, mono 12.5 px/1.75, correction orthographique désactivée. La lecture se
recompose **à chaque frappe**.

Pied : « Pièce jointe » (secondaire) et « Enregistrer » (primaire), 50 px, largeurs
égales. Toast de copie : pilule `#183a2b`, 84 px au-dessus du bas, visible 1,5 s.

### Nouvelle fiche

Retour + « Nouvelle fiche » ; champ de nom en placeholder `#a8aea8` 600 24 px avec filet
bas et caret `#2f7d5b`. Tuto affiché par défaut. Carte blanche de saisie occupant l'espace
restant, placeholder « Colle ou tape ici. / Tout est accepté. » ; en pied de carte, un
compteur « 0 bloc · 0 ligne » mis à jour en direct et une action « Coller ». Bouton
« Enregistrer » pleine largeur.

## Interactions

| Déclencheur | Effet |
| --- | --- |
| Clic sur un bloc replié | Ouvre le bloc et révèle ses valeurs ; plusieurs blocs peuvent être ouverts |
| Clic sur l'en-tête d'un bloc ouvert | Le referme et remasque ses valeurs |
| « copier » sur une ligne | Copie la ligne seule, toast « Copié » |
| « copier le bloc » | Copie les lignes du bloc jointes par `\n`, sans le titre |
| « copier » sur un commentaire | Copie le texte du commentaire |
| Onglet « Texte brut » | Affiche le texte source éditable ; chaque frappe recompose la lecture |
| « Compris » | Masque le tuto de façon persistante ; « Syntaxe » le rappelle |
| Curseur de longueur | Régénère immédiatement |
| Pastille de jeu | Régénère ; l'état actif est visible |
| Régénérer | Pousse la valeur précédente dans l'historique de session (max 3) |
| Verrouillage automatique | Referme tous les blocs, vide l'historique du générateur, remasque tout |

La copie passe par le presse-papier auto-effaçant existant, qui marque déjà le contenu
comme sensible et le vide après délai.

Transitions discrètes, 120–160 ms, sur l'ouverture des blocs, le changement d'onglet et le
toast. Aucune animation sur les valeurs.

## État

| État | Portée | Rôle |
| --- | --- | --- |
| `value` de l'entrée | Coffre chiffré | Seule source de vérité du contenu |
| blocs ouverts | Écran de fiche | Réinitialisé au verrouillage et au changement de fiche |
| `syntaxTutorialDismissed` | `settings.json` | Persisté ; une fois masqué, définitif |
| onglet d'accueil | Écran d'accueil | Coffre ou Générateur |
| longueur, jeu, valeur | `GeneratorSession` | Défauts 20 et « + symboles » |
| historique du générateur | `GeneratorSession` | Mémoire seule, vidé au verrouillage |
| requête de recherche | Onglet Coffre | Non persistée |

Aucune donnée dérivée — blocs, lignes, résultats de recherche — n'est persistée. Tout est
recalculé depuis le texte à chaque affichage.

## Design tokens

Portés par un `ThemeExtension` `SafeTokens` dans `lib/ui/theme/safe_theme.dart`. Aucun
littéral hexadécimal dans les écrans.

### Couleurs

| Rôle | Valeur |
| --- | --- |
| Fond application | `#f4f2ee` |
| Fond barre de titre / champs inertes | `#eae7e1` |
| Fond conteneur onglets | `#e4e1db` |
| Surface carte | `#ffffff` |
| Surface carte secondaire | `#efece6` |
| Surface accent douce | `#eaf4ee` |
| Encre principale / bouton primaire | `#183a2b` |
| Accent | `#2f7d5b` |
| Accent foncé sur fond doux | `#1f6f52` |
| Texte sur fond sombre | `#f4f2ee` |
| Texte secondaire | `#6b736e` |
| Texte tertiaire / libellés | `#8a918c` |
| Texte d'indice | `#7f8781` |
| Placeholder de champ titre | `#a8aea8` |
| Bordure hairline | `rgba(0,0,0,.06)`–`rgba(0,0,0,.07)` |
| Bordure de contrôle | `#cfd4ce` |
| Filet de séparation fort | `#dcdfda` |
| Puce inactive | `#c3c8c3`, trait 1.5 px |
| Filet de commentaire | `#d3d7d1` |
| Surlignage de recherche | `#dff0e5` sur `#1f6f52` |

### Typographie

Interface : **Instrument Sans** 400/500/600. Données stockées, valeurs, compteurs, texte
brut : **JetBrains Mono** 400/500. Règle : tout ce qui est une donnée stockée est en mono,
jamais en sans.

| Usage | Style |
| --- | --- |
| Titre d'écran | 600 24–25 px/1.2, `-0.03em`, `#183a2b` |
| Logotype d'accueil | 600 19–21 px/1, `-0.03em` |
| Valeur du générateur | 400 19 px/1.55 mono |
| Titre de ligne de liste | 500 14.5 px/1.3 |
| Valeur de ligne de fiche | 400 12.5 px/1.45 mono, césure autorisée |
| Intertitre de bloc | 600 11 px/1.3, `.07em`, majuscules |
| Libellé de section | 500 10.5 px/1, `.06em`, majuscules, `#8a918c` |
| Action textuelle | 400 10.5–11.5 px/1, `#2f7d5b` |
| Indice / méta | 400 11–11.5 px/1.6, `#7f8781` |
| Commentaire | 400 12 px/1.6 mono, `#5f6862` |
| Texte brut | 400 12.5 px/1.75 mono |

Les deux familles sont sous licence SIL OFL et **embarquées dans `assets/fonts/`** avec
leur fichier de licence. Elles ne sont jamais chargées depuis le réseau : une application
hors ligne ne doit appeler personne au démarrage.

### Formes et espacement

Rayons : boutons et champs pleine largeur 25 px (pilule, hauteur 50 px) ; petits contrôles
16–18 px (hauteur 32–36 px) ; cartes 14 px ; carte du générateur 16–18 px ; conteneur
d'onglets 22 px, pastilles 18 px.

Gouttières 24 px à gauche et à droite sur tous les écrans. Titre vers contenu 18–22 px ;
carte à carte 9–10 px ; ligne de fiche `padding: 11px 0` ; ligne de liste `padding: 15px 0`.

Hauteurs : bouton primaire 50 px ; bouton du générateur 44–48 px ; onglet 36 px ; pastille
de mode 32–36 px ; champ de recherche 44–46 px.

Ombres : uniquement sur la pastille d'onglet active (`0 1px 2px rgba(0,0,0,.09)`) et sur le
toast (`0 6px 18px rgba(0,0,0,.18)`). Aucune ombre de carte.

### Logo

Le **fermoir** — marque `C` de la planche `1a` du handoff. Deux équerres qui s'emboîtent
sans se toucher, dans un `viewBox` de 48 :

```
M32 7 H16 A9 9 0 0 0 7 16 V26      trait #2f7d5b
M16 41 H32 A9 9 0 0 0 41 32 V22    trait #183a2b
```

Trait 7, extrémités arrondies, sans remplissage. Le centre du carré reste **vide** : c'est
ce que le dessin dit — verrouillé quand les deux équerres s'alignent, entrouvert quand
elles glissent —, et c'est aussi ce qui le distingue à coup sûr du monogramme S.
Tailles : 34 px au déverrouillage, 17 px en en-tête d'accueil, jamais moins de 16 px.
Logotype « safe » en Instrument Sans 600, `-0.03em`, `#183a2b`, à 9–12 px du signe.

Pour une version une-couleur — barre système, gabarit foncé — les deux traits prennent
`#183a2b`.

**Décision du propriétaire, 2026-08-23 :** le monogramme S (marque `B`), retenu par le
handoff dans tous ses écrans validés et implémenté jusque-là, est remplacé par le fermoir.
Les autres écrans ne bougent pas ; seul le signe change. L'**icône de lancement** reste le
bouclier à serrure évidée de `tool/generate_icons.py` : l'application montre donc deux
marques différentes selon qu'on la lance ou qu'on l'ouvre.

## Écarts imposés par la plateforme

Le handoff visait GTK4/libadwaita ; la pile est Flutter.

- **Icônes** — pas d'icônes symboliques GNOME. Les icônes Material du SDK sont utilisées
  aux tailles indiquées, en remplacement des primitives géométriques du prototype.
- **Cibles tactiles** — le handoff demande 44 × 44 px, Material impose 48 dp sur Android.
  Les commandes iconographiques feront **48 dp sur Android** et 44 sur Linux : plus grand
  ne casse rien, plus petit casse l'accessibilité.
- **Fenêtre large sous Linux** — la maquette est une fenêtre étroite. Sous Linux, le
  contenu garde la même colonne étroite, centrée et bornée en largeur, plutôt que de
  s'étirer.

## Ce qui n'est pas fait, et pourquoi

- **Thème sombre.** L'application suit aujourd'hui le thème système et possède donc un
  thème sombre. Le handoff donne vingt couleurs claires et seulement quatre sombres, sur
  une planche explicitement non validée. En déduire une palette sombre complète
  reviendrait à inventer seize couleurs que le designer n'a pas vues. La refonte est donc
  **claire uniquement**, et le thème sombre attend une maquette.
- **Épinglage.** La maquette montre une puce pleine « si épinglée », mais ne spécifie ni le
  geste qui épingle, ni où l'état serait stocké. Aucune fonction d'épinglage n'existe dans
  l'application. Toutes les puces seront des cercles vides jusqu'à spécification.
- **Réglages redessinés.** L'écran de réglages est restylé aux tokens mais garde sa
  structure et ses fonctions : le designer le renvoie explicitement à un second temps.
- **Nombre de fiches au déverrouillage.** Impossible sans divulguer une métadonnée en
  clair. Voir la section Déverrouillage.
- **Deux signes de la maquette n'existent pas dans les polices.** La maquette écrit « ↻ »
  (U+21BB) sur le bouton régénérer et « Copié ✓ » (U+2713) sur le retour de copie. Ni
  Instrument Sans ni JetBrains Mono ne portent ces deux caractères — leurs tables `cmap`
  ont été lues, et ce sont les deux seuls trous : tous les autres signes non-ASCII de
  l'application y sont. La maquette est une page HTML, où les fontes du système les
  fournissent ; l'application, elle, n'embarque que ces deux familles. Android se
  rabattrait sur une autre fonte au milieu du texte, et un appareil sans repli afficherait
  un carré vide. L'application pose donc `Icons.refresh` et `Icons.check`, qui viennent de
  MaterialIcons, livrée avec elle. Le sens et la durée (1,6 s) ne changent pas ; seul le
  dessin du signe est celui de Material et non celui de la maquette.

## Ce qui ne bouge pas

Chiffrement, format de fichier, dérivation de clef, gestion des pièces jointes,
verrouillage automatique, blocage des captures d'écran, restauration de la sauvegarde
précédente, changement de mot de passe maître, et **export et import du coffre** — des
sauvegardes ont déjà été exportées dans ce format et doivent rester réimportables.

## Tests

Le parseur en premier, en test rouge d'abord, sur le texte de référence ci-dessus et ses
cas limites. Puis `vault_search`, puis `GeneratorSession`, puis un test d'interface par
écran. Les 285 tests existants restent verts ; ceux qui visent l'ancienne interface sont
réécrits, jamais supprimés.

Vérification sur l'émulateur Pixel 9a (`emulator-5554`) après chaque écran, captures à
l'appui. Le téléphone réel porte le coffre de l'utilisateur et ne sert qu'aux
installations `adb install -r`.

## État à la clôture

Écrit le 2026-08-23, sur la branche `refonte-interface`, 40 commits au-dessus de `master`.
Rien n'est fusionné : l'application installée sur le téléphone du propriétaire ne porte
aucune de ces modifications.

### Ce qui a été fait

Les onze tâches du plan, sauf la vérification sur appareil.

| Tâche | Résultat |
|---|---|
| 1 | `lib/model/entry_text.dart` — la découpe en blocs et en notes |
| 2 | Polices embarquées, jetons de couleur, de texte et d'espacement, `safeLightTheme()` |
| 3 | Le monogramme redessiné au trait |
| 4 | Déverrouillage restylé, sans compteur de fiches |
| 5 | Générateur : bornes 8–48, jeux sans caractères ambigus, état de session |
| 6 | La fiche : blocs masqués, notes en clair, mode texte brut, tuto de syntaxe |
| 7 | La nouvelle fiche, et le titre rendu modifiable (décision du propriétaire) |
| 8 | `lib/model/vault_search.dart` — noms, intertitres, lignes de valeur |
| 9 | L'accueil à deux onglets, l'ancienne liste supprimée |
| 10 | Réglages restylés aux jetons |
| 11 | Code mort, couverture, documentation, parcours sur l'émulateur |
| — | Le cadenas de verrouillage manuel dans l'en-tête (décision du propriétaire) |
| — | Le logo passé du monogramme S au fermoir (décision du propriétaire) |

### Ce qui a été vérifié, et comment

**430 tests verts**, répartis sur 68 fichiers ; `flutter analyze` et `dart format` propres.

Chaque tâche a été écrite par un agent et relue par un autre, sans lui montrer le rapport
du premier. Les relectures ont trouvé ce qu'une suite verte ne trouve pas : des assertions
vraies par construction, une cible tactile tombée à 24 px, un écran qui ne s'annonçait
plus, et la seule phrase disant que le mot de passe maître ne se récupère pas passée sous
le seuil de contraste AA. Chaque garde a été prouvée par **sabotage exécuté** — casser le
code, lancer la suite, citer la ligne rouge, restaurer.

Deux trouvailles hors plan méritent d'être nommées, parce qu'elles portent sur la sécurité
et non sur le dessin :

- **Deux fils du verrouillage automatique n'étaient gardés par rien** (`main.dart:87-88`
  et `153-155`). Débranchés, la suite restait verte. Or, sans le premier, le coffre se
  verrouille sous les doigts de qui remplit une fiche au clavier, et la saisie non
  enregistrée part avec lui ; sans le second, un coffre laissé en arrière-plan pendant
  qu'Android gèle le processus **revient ouvert**. `test/ui/app_wiring_test.dart` les tient
  désormais.
- **Couverture globale 2248/2358 lignes, 95,34 %** (`lcov` étant absent de la machine, les
  enregistrements `DA:` ont été comptés à la main). Aucune ligne de déchiffrement, de
  sérialisation ni d'export n'est non couverte, vérifié ligne à ligne. Seul `lib/main.dart`
  est sous 80 % — 75 %, de l'amorçage non couvrable sous horloge simulée.

Le rendu a d'abord été regardé sur des PNG rendus hors écran (`RenderRepaintBoundary.toImage`
sous `runAsync`, vraies polices chargées par `FontLoader`, 411 × 891 à 2,625×) — une image
juste du dessin, mais pas une preuve du comportement de l'appareil. La section suivante dit
ce que l'appareil, lui, a montré.

### Ce qui a été vérifié sur un appareil

Sur l'**émulateur** Pixel 9a (`emulator-5554`, APK *debug*). **Le téléphone réel n'a jamais
été branché et rien n'y a été installé** : le Step 6 du plan reste entier.

Le point le plus important d'abord. **Une sauvegarde scellée par le code d'avant la
refonte se réimporte.** Elle a été fabriquée avec le `sealWithPassword` de `master`, puis
choisie dans le sélecteur de fichiers depuis Réglages → Importer. Résultat : `vault.safe`
passe à 607 octets, le coffre précédent part en `vault.safe.bak`, l'application se referme
— le coffre importé a un autre mot de passe — et les quatre fiches reviennent, accents et
tiret cadratin intacts, valeurs identiques à l'octet, dates de création conservées.

Cette réimportation avait d'ailleurs une preuve statique : `git diff master..HEAD` sur
`lib/crypto/`, `lib/model/vault.dart`, `lib/storage/vault_file.dart`,
`lib/storage/vault_transfer.dart` et `lib/storage/blob_store.dart` **ne rend rien**. Pas un
octet du format, du scellement, de l'écriture disque ni de l'export n'a bougé.

Constaté aussi, pour la première fois :

- **`Icons.refresh` et `Icons.check` s'affichent** — « ✓ Copié » et le bouton rond de
  régénération. L'écart de police décrit plus haut est levé.
- **Le cadenas de l'en-tête rend à 21 px et verrouille** depuis l'accueil.
- **Le blocage des captures d'écran fonctionne** : la toute première capture est revenue
  entièrement **noire**. Il a fallu poser `blockScreenshots: false` dans le `settings.json`
  de l'émulateur pour voir quoi que ce soit.
- **Le presse-papier est bien marqué sensible** : l'aperçu système d'Android affiche des
  points à la place de la valeur copiée.
- **`settings.json` est relu du disque** : le pied de page annonce le vrai délai.
- **`VaultFile.defaultDirectory()` résout correctement** sur Android —
  `/data/data/dev.safe.safe/app_flutter/safe`. C'était un trou de couverture ; il est
  constaté en marche, pas comblé par un test.
- **Une fiche d'avant la refonte s'affiche en clair**, comme une note rattachée par un
  filet — la conséquence de l'écart de masquage, vue sur l'écran et non plus déduite.

**Ce qui reste sans regard :** le téléphone réel ; une fiche à trois blocs écrite à la
main ; le mode texte brut ; la recherche tapée au clavier ; les pièces jointes.

Rappels pour le jour du téléphone réel : toujours `adb -s <numéro de série>`, jamais sans —
le nom du modèle ne distingue plus le téléphone de l'émulateur. Jamais d'`adb uninstall`,
jamais d'`adb install` sans `-r` : le coffre et les pièces jointes seraient effacés. Jamais
de compilation *debug* dessus — `run-as` rendrait le coffre lisible.

### Ce que le regard a trouvé

Trois choses qu'aucune suite verte n'avait signalées.

1. **Les invites des champs de mot de passe portaient l'espacement des points.** « Mot de
   passe maître » s'affichait « M o t  d e  p a s s e  m a î t r e ». Le champ écrit ses
   caractères en `letter-spacing: .16em` — c'est la maquette — mais Flutter fusionne
   `hintStyle` par-dessus le style du champ, et ce que `hintStyle` n'écrase pas est hérité.
   **Corrigé**, avec trois gardes qui lisent le style *rendu* de l'invite.
2. **Les réglages parlaient encore de « clefs » et de « valeurs ».** Vocabulaire d'avant la
   refonte, resté parce que le contrat de la tâche 10 gelait les libellés. **Corrigé.**
3. **La commande des réglages est un cercle vide pâle** et ne dit rien de ce qu'elle
   ouvre — d'autant moins depuis que le cadenas, lisible, est son voisin immédiat : elle se
   lit comme une puce décorative. Ce document n'écrit que « commande réglages à droite » ;
   le cercle vient du handoff. **Non corrigé — décision du propriétaire :** y poser
   `Icons.settings` comme le cadenas porte `Icons.lock_outline`, encrer le cercle, ou
   laisser tel quel.

### Écarts assumés

Ceux qui touchent le dessin ou le contenu sont décrits plus haut dans ce document. Résumé,
avec ce que chacun coûte :

| Écart | Conséquence |
|---|---|
| Les notes sans titre s'affichent en clair | Une entrée d'avant la refonte, d'une seule ligne, est aujourd'hui masquée et ne le sera plus. Ajouter une ligne `nom:` au-dessus la remasque, et le tuto le dit |
| La recherche indexe les valeurs | Une ligne de valeur peut apparaître surlignée dans les résultats sans qu'aucun bloc ait été ouvert |
| `Icons.refresh` / `Icons.check` au lieu de « ↻ » et « ✓ » | Le dessin est celui de Material, pas celui de la maquette |
| L'`AppBar` des réglages remplacée par l'en-tête maison | Une `AppBar` ne sait poser ni la gouttière de 24 ni `screenTitle`, tous deux exigés par le plan. Le retour fait toujours `Navigator.maybePop()` et s'annonce « Retour » |
| Le cadenas de l'en-tête est plus sombre que le cercle des réglages voisin | 4,37:1 contre 1,35:1. Le cercle est un décor que le handoff dessine pâle ; un cadenas aussi pâle serait invisible. **Jamais vu à l'œil** |
| Pas de compteur de fiches au déverrouillage | Impossible sans divulguer une métadonnée en clair |
| `CommentBlock` rattache la note par un filet vertical, sans l'encadrer | Le handoff nomme une « surface carte secondaire » ; elle a été supprimée comme jeton mort. La remettre, c'est `block_card.dart:177` |
| `SafeText.sectionLabel` inutilisé | Inventer « SÉCURITÉ » et « SAUVEGARDE » aurait ajouté des mots à un écran dont le brief gèle les libellés |

### Une perte d'ergonomie consentie

**Copier une valeur depuis la liste demandait une tape ; il en faut trois** (ouvrir la
fiche, ouvrir le bloc, copier). Le propriétaire du dépôt l'a décidé en connaissance de
cause : le nouveau modèle de contenu est fait pour des fiches à plusieurs valeurs, où une
commande unique par ligne devrait deviner laquelle copier — et une copie silencieusement
fausse est la pire panne d'un gestionnaire de mots de passe. Ce n'est pas un oubli.

### Décisions encore en attente

- **`Vault.search`** (`vault.dart:301`) est mort dans `lib/` — `VaultTab` passe par
  `searchVault` — mais retenu par `vault_test` et `unicode_keys_test`.
- **`VaultCrypto.sealWithPassword`** (`vault_crypto.dart:326`) est dans le même cas, avec
  20 sites de test. **Il touche au chiffrement** : c'est le seul chemin de scellement par
  mot de passe, celui qui fabrique les octets qu'un export doit rester capable de rouvrir.
  Ne rien y toucher avant le parcours d'import réel.
- **`minAutoLockDelay` / `maxAutoLockDelay`** (`app_settings.dart:23-24`) : leur commentaire
  affirme qu'elles valident ce qui est relu du disque, ce qui est devenu faux —
  `_clampDelay` ramène tout à `autoLockChoices`. Soit supprimer les constantes et la garde,
  soit corriger le commentaire.

### Ce qui reste faible

- **Le style des cinq écrans refaits n'est presque pas gardé.** Un sabotage de jeton ne fait
  tomber personne. Il existe deux fichiers de ce genre — `test/ui/settings_style_test.dart`
  et `test/ui/unlock_style_test.dart` — et chacun est né d'un défaut déjà constaté, pas
  d'une couverture systématique.
- **Trois trous de couverture qui comptent** : `home_screen._copier` (copier une ligne
  depuis un résultat de recherche, avec son repli `MissingPluginException` et ses deux
  toasts) ; le bouton **Annuler** de `confirm_discard.dart`, jamais pressé — s'il renvoyait
  `true`, une saisie serait perdue en croyant la garder ; `VaultFile.defaultDirectory()`,
  où se tromper de dossier revient à ouvrir le mauvais coffre.
- **Le focus directionnel ignore les commandes des en-têtes** — cadenas, réglages, flèche
  de retour. Ce sont des `GestureDetector` : pas de `Focus`, pas d'infobulle, pas de retour
  d'encre au toucher. Défaut préexistant, non aggravé, non corrigé.
- **Titres sans `header` ni `namesRoute`** dans `entry_screen.dart` et
  `new_entry_screen.dart` — le défaut exact corrigé dans les réglages. Préexistant.
- **Mineurs différés**, relevés en relecture et jugés sans conséquence : la liste rendue par
  `parseEntryText` est croissable ; `length` compte des unités UTF-16 et non des graphèmes ;
  deux titres consécutifs sans ligne entre eux gardent un groupe vide ; le pied de page
  ancré au clavier n'est figé par aucun test durable ; le test « chaque classe présente »
  pour le jeu « Lettres » a une marge de détection faible ; un test de recherche promet plus
  qu'il ne prouve ; quatre cibles tactiles entre 29 et 46 px dans la fiche.

### Ce que le propriétaire doit vérifier lui-même

Trancher le cercle des réglages, et les trois symboles morts ci-dessus. Puis, sur le
téléphone : l'installation se fait `adb install -r` sur une compilation **release**, et
`firstInstallTime` doit être inchangé après. Y refaire l'import d'une sauvegarde réelle
avant de se fier à celui de l'émulateur : c'est le même code, mais ce n'est pas le même
coffre.
