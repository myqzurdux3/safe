# safe

Coffre chiffré, minimaliste, pour Android et Linux. Une fiche porte un nom et
un bloc de texte libre — plusieurs services, des codes, des notes; tout est
chiffré en bloc par un mot de passe maître, et rien ne quitte l'appareil.

## Ce qu'il fait

- Créer un coffre protégé par un mot de passe maître
- Ajouter, modifier, supprimer, rechercher des fiches
- Une fiche tient plusieurs services: son texte se découpe tout seul en blocs
  titrés et en notes, sans rien réécrire de ce qui a été tapé (voir plus bas)
- Les lignes d'un bloc titré restent masquées jusqu'à ce qu'on ouvre le bloc;
  une note sans titre s'affiche en clair, c'est une note, pas un secret
- Chercher dans les noms de fiches, les intertitres de blocs **et les lignes de
  valeur**, avec la ligne trouvée montrée en contexte
- Joindre des photos et des documents, chiffrés un par fichier, 25 Mio maximum
- Générer des valeurs aléatoires (8 à 48 caractères, 20 par défaut), lettres
  seules, avec chiffres, ou avec dix symboles `!#$%&*+-?@`; les caractères
  ambigus `l I O 0 1` sont exclus et chaque classe demandée est garantie
  présente. Les trois valeurs précédentes restent consultables en mémoire, et
  disparaissent au verrouillage
- Copier une ligne, ou un bloc entier d'un coup, depuis la fiche; le
  presse-papier est effacé 30 s plus tard
- Bloquer les captures d'écran et vider la vignette des applications récentes
  (Android). Actif par défaut, désactivable dans les réglages
- Verrouiller à la main, depuis le cadenas de l'en-tête de l'accueil ou depuis
  les réglages
- Verrouiller automatiquement après inactivité (30 s, 1, 2 ou 5 min; 2 min par
  défaut, choix conservé d'un lancement à l'autre).
  Le temps passé en arrière-plan compte comme de l'inactivité, mais changer
  d'application ne verrouille pas en soi. Frappes et gestes comptent comme une
  activité, sur tous les écrans. Le verrouillage ferme les écrans ouverts,
  referme les blocs, vide l'historique du générateur et efface une saisie en
  cours
- Exporter et importer le coffre chiffré, pour transférer entre appareils
- Restaurer l'état d'avant la dernière modification, depuis la copie conservée
  à côté du coffre

Pas de compte, pas de serveur, pas de synchronisation automatique, pas de
remplissage de formulaires.

## Comment s'écrit une fiche

Le texte d'une fiche est libre. Il se lit ainsi, ligne par ligne:

1. Une ligne de 44 caractères ou moins qui finit par `:` ouvre un **bloc**, et
   ce qui la précède devient son intertitre.
2. Les lignes suivantes appartiennent à ce bloc, et restent masquées tant qu'il
   n'est pas ouvert.
3. Une ligne vide ferme le bloc courant.
4. Une ligne qui n'appartient à aucun bloc est une **note**, affichée en clair.
5. L'ordre est celui du document: une note écrite entre deux blocs s'affiche
   entre ces deux blocs.

```
courrier:
personne@example.invalid
correcthorsebattery

pense-bête: cette boîte sert aussi de secours pour la banque

banque:
titulaire@example.invalid
```

Deux blocs, une note, dans cet ordre. Rien de tout cela n'est écrit sur le
disque: le coffre garde le texte tel qu'il a été tapé, la découpe est refaite à
l'affichage. Ajouter une ligne `nom:` au-dessus d'une valeur suffit donc à la
masquer, et la retirer suffit à la remontrer.

## Sécurité

| Élément | Choix |
|---|---|
| Dérivation de clé | Argon2id, 3 passes, 128 Mio, sel aléatoire de 16 octets |
| Chiffrement | XChaCha20-Poly1305 (AEAD), nonce de 24 octets tiré à chaque sauvegarde |
| Bibliothèque | libsodium, via `package:sodium` (FFI) |
| Portée du chiffrement | Le coffre entier: **les noms de fiches sont chiffrés eux aussi** |
| Pièces jointes | Un fichier chiffré par pièce (`blobs/<id>.blob`), nonce propre, identifiant aléatoire sans rapport avec le nom |
| Intégrité | L'en-tête en clair sert de données associées: le modifier invalide le tag |
| Écriture | Fichier temporaire, puis `rename` atomique, avec sauvegarde `.bak` — supprimée lors d'un changement de mot de passe, que l'ancien ouvrirait encore |
| Écritures concurrentes | Sérialisées: une sauvegarde ne peut pas écraser la modification d'une autre |
| Sauvegarde Android | Désactivée (`allowBackup="false"`): ni Google Drive, ni transfert d'appareil à appareil |
| Clavier | `autocorrect` et `enableSuggestions` coupés sur les champs de saisie: le dictionnaire du clavier n'apprend pas les secrets |
| Presse-papier | Marqué sensible (`EXTRA_IS_SENSITIVE`): pas d'aperçu système, pas d'entrée dans l'historique du clavier |
| Dérivation | Exécutée dans un isolat séparé: l'interface ne gèle pas, et Android ne tue pas l'app pour non-réponse |
| Droits des fichiers | Dossier du coffre en `0700` sous Linux: les autres comptes de la machine n'y accèdent pas |

**Le mot de passe maître ne peut pas être récupéré.** Il n'existe ni question
secrète, ni clef de secours, ni porte dérobée: perdre le mot de passe, c'est
perdre le contenu du coffre. Une copie exportée reste chiffrée et ne sert donc à
rien sans lui.

Deux limites assumées, décrites en détail dans le document de conception:
les valeurs déchiffrées vivent dans des `String` Dart, que le langage ne permet
pas d'effacer de façon déterministe; et un appareil déjà compromis (root,
enregistreur de frappe) échappe au modèle de menace.

## Lancer

```bash
flutter run -d linux     # Linux
flutter run -d <device>  # Android
```

Vérification:

```bash
flutter analyze
flutter test
```

Compilation:

```bash
flutter build linux --release
flutter build apk --release
```

libsodium est compilée à la première exécution par le *build hook* de
`package:sodium`; le premier `flutter test` ou `flutter build` est donc plus
lent que les suivants.

## Où vit le coffre

- Linux: `$XDG_DATA_HOME/safe/`, par défaut `~/.local/share/safe/`
- Android: dossier privé de l'application, inaccessible aux autres applications

Un seul dossier, cinq choses dedans:

| Fichier | Contenu | Chiffré |
|---|---|---|
| `vault.safe` | le coffre: noms de fiches, textes, métadonnées des pièces jointes | oui |
| `vault.safe.bak` | l'état précédant la dernière sauvegarde | oui |
| `blobs/<id>.blob` | le contenu d'une pièce jointe | oui |
| `blobs/orphelins/` | pièces jointes qu'aucune entrée ne référence plus | oui |
| `settings.json` | blocage des captures d'écran, délai de verrouillage | **non** — aucun secret |

Le dossier est créé en `0700`: sous Linux, aucun autre compte de la machine n'y
accède.

Sauvegarder revient à copier le dossier: le contenu reste chiffré, une copie sur
une clé USB ne l'expose pas.

## Configuration

`settings.json`, à côté du coffre, en clair. Deux réglages, tous deux modifiables
depuis l'écran Réglages:

| Clef | Valeurs | Défaut |
|---|---|---|
| `blockScreenshots` | `true` / `false` | `true` |
| `autoLockSeconds` | 30, 60, 120 ou 300 | 120 |

Une valeur absente, aberrante ou hors de cette liste retombe sur le réglage le
plus protecteur; un `autoLockSeconds` intermédiaire est ramené au choix
inférieur. Supprimer le fichier remet les défauts. Il ne contient aucun secret et
ne dit rien du contenu du coffre.

## Transférer un coffre entre appareils

Réglages → **Exporter le coffre** produit le fichier chiffré tel quel. Il peut
transiter par n'importe quel canal, y compris peu sûr: sans le mot de passe il
est inexploitable. Sur l'autre appareil, Réglages → **Importer un coffre**
demande le mot de passe du fichier et vérifie qu'il l'ouvre **avant** de
remplacer le coffre existant, dont une copie part en `.bak`.

**L'export ne contient pas les pièces jointes**: elles vivent dans des fichiers
séparés et s'exportent une par une depuis l'entrée concernée. Un export en
archive unique reste à faire.

Conséquence sur l'appareil qui reçoit l'import: ses pièces jointes locales ne
sont plus référencées par le coffre importé. Elles ne sont pas détruites — elles
partent dans `blobs/orphelins/`, où elles restent chiffrées et récupérables à la
main.

## Logo

L'icône est générée, pas dessinée à la main dans un binaire opaque:

```bash
python3 tool/generate_icons.py
```

Le script produit les mipmaps Android (héritées, rondes, adaptatives) et les
PNG `assets/icon/`. Modifier les couleurs ou la géométrie se fait dans
`tool/generate_icons.py`, puis on relance la commande. Le même bouclier est
redessiné à l'écran par `lib/ui/safe_logo.dart`, en vectoriel, pour suivre la
couleur du thème.

Sous Linux, l'icône de fenêtre est chargée par le lanceur natif depuis les
ressources empaquetées. Pour une installation système, `linux/packaging/safe.desktop`
attend l'icône dans le thème `hicolor`:

```bash
install -Dm644 assets/icon/safe_256.png ~/.local/share/icons/hicolor/256x256/apps/safe.png
install -Dm644 linux/packaging/safe.desktop ~/.local/share/applications/safe.desktop
```

Le fichier versionné contient `Exec=safe`, qui suppose le binaire dans le
`PATH`. Beaucoup de lanceurs n'héritent pas du `PATH` du shell: pour une
installation dans `~/.local`, [DEPLOY.md](DEPLOY.md) donne la variante à chemin
absolu, à préférer.

## Structure

```
lib/
  crypto/vault_crypto.dart   Argon2id, XChaCha20-Poly1305, format de fichier
  model/vault.dart           Fiches et sérialisation JSON
  model/entry_text.dart      Découpe du texte libre en blocs et en notes
  model/vault_search.dart    Recherche: noms, intertitres, lignes de valeur
  storage/vault_store.dart   Interface de stockage
  storage/vault_file.dart    Fichier sur disque, écriture atomique
  storage/vault_transfer.dart Export et import vérifié
  storage/blob_store.dart    Pièces jointes chiffrées sur disque
  storage/app_settings.dart  Préférences en clair, bornées à la relecture
  state/vault_session.dart   Verrouillé / déverrouillé, auto-lock
  state/generator_session.dart  Longueur, jeu, historique en mémoire
  ui/                        Verrou, accueil à deux onglets, fiche, réglages
  ui/theme/safe_theme.dart   Jetons de couleur, de texte et d'espacement
  ui/widgets/                Blocs, pilules, bouton, toast, tuto de syntaxe
  ui/safe_logo.dart          Logo vectoriel, dessiné au trait
  util/                      Générateur, presse-papier auto-effacé
tool/generate_icons.py       Génération des icônes Android et Linux
docs/superpowers/
  specs/2026-08-14-safe-design.md          Conception et modèle de menace
  specs/2026-08-19-safe-refonte-design.md  Refonte de l'interface
  plans/2026-08-14-safe.md                 Plan d'implémentation
  plans/2026-08-19-safe-refonte.md         Plan de la refonte
```

## Compiler et installer

Voir [DEPLOY.md](DEPLOY.md): rebuild et réinstallation sur Android et Linux,
emplacement des données, sauvegarde.

Prérequis: Flutter 3.44 ou plus récent, GTK 3 pour la cible Linux, et
`python3` avec Pillow pour régénérer les icônes.

## Signaler une faille

Pas d'issue publique: voir [SECURITY.md](.github/SECURITY.md), qui décrit le
canal privé et ce qui est hors du modèle de menace.

## Contribuer

Voir [CONTRIBUTING.md](CONTRIBUTING.md). En bref: un test qui échoue d'abord,
`dart format`, `flutter analyze` et `flutter test` verts avant de proposer quoi
que ce soit.

## Licence

[MIT](LICENSE).

Le code hérité du gabarit `flutter create` — dossiers `android/` et `linux/`,
hors les fichiers listés dans la structure ci-dessus — vient du projet Flutter et
reste sous sa licence BSD à trois clauses.

## Avertissement

Projet personnel, écrit et audité mais **jamais audité par un tiers**. Le
chiffrement repose sur libsodium, ce qui est solide; l'assemblage autour, lui,
n'a pas été relu par quelqu'un d'autre que son auteur et un outil. Les limites
connues sont listées dans [AUDIT.md](AUDIT.md). Ne confiez pas à ce logiciel des
secrets dont la perte serait grave sans en garder une copie ailleurs.
