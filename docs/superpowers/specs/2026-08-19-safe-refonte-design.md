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

Monogramme S géométrique, tracé unique de deux demi-cercles, dans un `viewBox` de 48 :

```
M34 14 A10 10 0 1 0 24 24 A10 10 0 1 1 14 34
```

Trait 7, extrémités arrondies, sans remplissage, couleur `#2f7d5b` (version foncée
`#183a2b`). Tailles : 34 px au déverrouillage, 17 px en en-tête d'accueil, jamais moins de
16 px. Logotype « safe » en Instrument Sans 600, `-0.03em`, `#183a2b`, à 9–12 px du signe.

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
