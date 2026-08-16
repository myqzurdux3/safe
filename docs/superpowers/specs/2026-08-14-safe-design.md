# safe — coffre clef/valeur chiffré (design)

Date: 2026-08-14
Statut: approuvé en brainstorming, à transformer en plan d'implémentation

## 1. But

Application minimaliste où l'utilisateur enregistre des paires clef/valeur
chiffrées par un mot de passe maître, et les déchiffre avec ce même mot de
passe. Un gestionnaire de mots de passe réduit à l'essentiel, fait maison,
sans compte, sans serveur, sans synchronisation automatique.

Plateformes visées: Android et Linux, un seul codebase Flutter
(Flutter 3.44.6 / Dart 3.12.2, déjà installés sur la machine).

### Hors périmètre (YAGNI)

Synchronisation cloud, comptes utilisateurs, partage entre utilisateurs,
remplissage automatique de formulaires, extension navigateur, TOTP,
multi-coffres, thèmes.

### Ajouté le 2026-08-14, après la première version

- Valeurs multilignes
- Pièces jointes (photos, documents), chiffrées une par fichier
- Générateur couvrant toute la ponctuation ASCII, avec au moins un
  caractère de chaque classe demandée

## 2. Propriétés de sécurité

Ce que le design garantit:

- Le fichier coffre volé (sauvegarde, appareil perdu, stockage partagé)
  reste inexploitable sans le mot de passe maître.
- Les **noms de clefs sont chiffrés eux aussi**, pas seulement les valeurs:
  le fichier ne révèle pas quels services l'utilisateur possède.
- Toute modification du fichier, y compris de son en-tête en clair, est
  détectée au déchiffrement (AEAD + en-tête utilisé comme données
  associées).
- Aucun secret n'est écrit en clair sur le disque, à aucun moment, y
  compris pendant la sauvegarde (fichier temporaire chiffré puis `rename`).
- Aucune récupération: mot de passe maître perdu = coffre perdu. C'est un
  choix, pas un manque; toute porte de secours serait une seconde cible.

Ce que le design ne garantit pas, explicitement:

- **Effacement mémoire des valeurs déchiffrées.** La clé vit dans une
  `SecureKey` libsodium (mémoire native verrouillée, effaçable), mais les
  valeurs déchiffrées deviennent des `String` Dart, immuables et non
  effaçables de façon déterministe avant le passage du ramasse-miettes.
  L'auto-lock réduit la fenêtre d'exposition sans la supprimer. Limite du
  langage, pas du design.
- **Appareil compromis.** Root, malware avec accès mémoire, keylogger
  système: hors modèle de menace. Rien dans une app en espace utilisateur
  n'y résiste.
- **Force du mot de passe maître.** Argon2id rend les attaques coûteuses,
  il ne sauve pas un mot de passe de 6 caractères.

## 3. Choix cryptographiques

Bibliothèque: `sodium` 4.0.4 (liaison FFI vers libsodium, code natif
audité), variante **sumo** — Argon2id (`crypto_pwhash`) n'existe que là.
Le paquet `sodium_libs` est déprécié depuis la 4.x, ses fonctions ayant
été absorbées par `sodium`, qui embarque désormais libsodium via les
*native assets* de Dart. Vérifié sur cette machine: `SodiumSumoInit.init()`
et une dérivation Argon2id à 128 Mio passent sous `flutter test`.

| Rôle | Primitive | Paramètres |
|---|---|---|
| Dérivation de clé | Argon2id (`crypto_pwhash`) | `opslimit=3`, `memlimit=128 Mio`, sel 16 o aléatoire |
| Chiffrement | XChaCha20-Poly1305 IETF (AEAD) | clé 32 o, nonce 24 o aléatoire par sauvegarde |
| Aléa | `randombytes_buf` de libsodium (crypto) pour sel/nonce; `Random.secure` pour le générateur de mots de passe | — |

Justification des paramètres Argon2id: le preset `moderate` de libsodium
(3 passes / 256 Mio) est écarté parce qu'une allocation de 256 Mio expose
l'app à une mise à mort par Android sur appareil bas de gamme. 128 Mio
conserve la résistance mémoire réelle qui manque à PBKDF2, pour une
dérivation de l'ordre de 0,5 à 1 s sur téléphone milieu de gamme.

Les paramètres sont stockés dans l'en-tête du fichier: un coffre créé
aujourd'hui reste lisible si les valeurs par défaut sont durcies plus tard.

Le nonce de 24 octets de XChaCha20 autorise un tirage purement aléatoire à
chaque sauvegarde sans risque pratique de collision — pas de compteur à
gérer, donc pas de bug de compteur possible.

## 3 bis. Pièces jointes

Une pièce jointe est un fichier quelconque rattaché à une entrée. Le
coffre ne contient que ses métadonnées — identifiant, nom, type, taille,
date — dans le champ optionnel `att` de l'entrée; les coffres écrits
avant cette version restent donc lisibles sans migration.

Le contenu vit dans `blobs/<id>.blob`, chiffré avec la clé de session et
son propre nonce. L'identifiant est tiré au hasard (16 octets), jamais
dérivé du nom du fichier: un nom de fichier est un secret au même titre
que le reste.

En-tête d'un blob, 33 octets, servant de données associées:

```
offset  taille  champ
0       8       magic "SAFEBLB1"
8       1       version = 1
9       24      nonce
33      n       ciphertext || tag (16 o)
```

Le magic distinct de celui du coffre empêche de confondre les deux
formats: présenter un blob à l'ouverture du coffre échoue proprement.

**Plafond: 25 Mio par pièce jointe.** Une pièce jointe est déchiffrée
d'un bloc en mémoire à l'ouverture; au-delà, l'app se ferait tuer par le
système sur un téléphone modeste.

Conséquences assumées:

- Le déverrouillage reste instantané quel que soit le volume joint:
  seules les métadonnées sont déchiffrées avec le coffre.
- Une écriture interrompue entre le blob et le coffre laisse un blob
  orphelin. Il est effacé au déverrouillage suivant.
- **L'export du coffre ne contient pas les pièces jointes**, qui vivent
  dans des fichiers séparés. L'interface le dit, et chaque pièce jointe
  peut être exportée individuellement. Une archive unique reste possible
  plus tard.
- Exporter une pièce jointe l'écrit en clair sur le disque: c'est le seul
  moment où un contenu quitte le coffre, et il est explicite.

## 4. Format de fichier

Fichier `vault.safe`, binaire, entiers en little-endian.

```
offset  taille  champ
0       8       magic "SAFEVLT1"
8       1       version = 1
9       1       kdf_id  = 1 (Argon2id)
10      4       opslimit (u32)
14      8       memlimit (u64, octets)
22      16      sel
38      24      nonce
62      n       ciphertext || tag (16 o)
```

Les 62 octets d'en-tête sont passés comme **données associées (AAD)** de
l'AEAD: altérer la version ou les paramètres KDF invalide le tag.

Clair chiffré: JSON UTF-8

```json
{"v":1,"entries":[{"k":"...","val":"...","created":0,"updated":0}]}
```

`created` / `updated` sont des timestamps Unix en millisecondes.

## 5. Emplacements et écriture

- Linux: `$XDG_DATA_HOME/safe/vault.safe`, défaut `~/.local/share/safe/`
- Android: répertoire privé de l'application (`path_provider`,
  `getApplicationDocumentsDirectory`). Jamais le stockage externe.

Séquence de sauvegarde, à chaque modification (le coffre est un blob
unique, il n'y a pas de mise à jour partielle):

1. sérialiser et chiffrer en mémoire
2. écrire `vault.safe.tmp`
3. `fsync`
4. copier l'ancien `vault.safe` vers `vault.safe.bak` s'il existe
5. `rename` de `vault.safe.tmp` sur `vault.safe` (atomique)

Une interruption à n'importe quelle étape laisse soit l'ancien coffre
intact, soit le nouveau complet, jamais un fichier à moitié écrit.

## 6. Architecture

Un fichier par responsabilité. La crypto ignore le disque; le stockage
ignore la crypto; l'interface ne voit que la session.

| Fichier | Rôle | Dépend de |
|---|---|---|
| `lib/crypto/vault_crypto.dart` | dérivation Argon2id, seal/open XChaCha20-Poly1305. Fonctions pures, aucune IO | sodium_libs |
| `lib/crypto/secure_key.dart` | enveloppe `SecureKey`, cycle de vie et effacement | sodium_libs |
| `lib/storage/vault_file.dart` | chemins par plateforme, lecture, écriture atomique, `.bak` | dart:io, path_provider |
| `lib/model/vault.dart` | entrées, (dé)sérialisation JSON | — |
| `lib/state/vault_session.dart` | état verrouillé/déverrouillé, minuterie d'auto-lock, cycle de vie | crypto, storage, model |
| `lib/ui/unlock_screen.dart` | création du coffre et déverrouillage | state |
| `lib/ui/entries_screen.dart` | liste, recherche, copie | state |
| `lib/ui/entry_edit_screen.dart` | ajout et modification, générateur | state, util |
| `lib/ui/settings_screen.dart` | changement de mot de passe, délai d'auto-lock, export, import | state, storage |
| `lib/util/clipboard.dart` | copie avec effacement différé | — |
| `lib/util/password_generator.dart` | génération aléatoire | — |
| `lib/main.dart` | initialisation de sodium, thème, routage | tout |

## 7. Interface

Quatre écrans, plus un panneau de réglages.

**Création** (aucun fichier présent): mot de passe + confirmation, minimum
12 caractères, indicateur de longueur, aucune règle de composition
arbitraire. Avertissement explicite sur l'absence de récupération.

**Verrou**: champ mot de passe, indicateur d'activité pendant la
dérivation. Message d'erreur unique « mot de passe incorrect » — l'échec
du tag AEAD ne distingue pas un mauvais mot de passe d'un fichier
corrompu, et distinguer les deux dans l'interface fuiterait de
l'information. Le détail technique va dans les logs de debug uniquement.

**Liste**: barre de recherche, entrées triées par clef, valeurs masquées
par défaut. Par entrée: révéler (appui maintenu), copier, modifier,
supprimer (avec confirmation). Bouton flottant pour ajouter.

**Édition**: clef, valeur masquée avec bouton de révélation, bouton
« générer » (longueur 12–64, jeux lettres / chiffres / symboles).

**Réglages**: changer le mot de passe maître (nouveau sel, ré-chiffrement
complet), délai d'auto-lock (30 s, 1, 2 ou 5 min; défaut 2 min), export,
import.

La copie d'une valeur efface le presse-papier 30 s plus tard, ou plus tôt
si le coffre se verrouille entre-temps.

## 8. Verrouillage

Deux déclencheurs:

- minuterie d'inactivité, réinitialisée par toute interaction utilisateur —
  **frappes comprises**. Sur un clavier logiciel, saisir un caractère rare
  (parenthèse, symbole) demande de changer de page: la frappe est alors la
  seule activité, et l'ignorer verrouille le coffre sous les doigts de
  l'utilisateur.
- `AppLifecycleState.detached` uniquement: le processus s'arrête.

**Le passage en arrière-plan ne verrouille plus** (changé le 2026-08-16).
Consulter une autre app puis revenir ne doit pas coûter une saisie du mot de
passe maître. Le temps passé en arrière-plan compte comme de l'inactivité: le
délai reste seul juge.

Android peut geler le processus, donc la minuterie Dart n'est pas fiable en
arrière-plan. Au retour au premier plan, l'inactivité réelle est recalculée à
partir de deux horloges, en retenant l'écart le plus grand: un `Stopwatch`
monotone, insensible à un changement d'heure système mais arrêté pendant la
veille profonde, et l'horloge murale, qui couvre la veille mais peut reculer.
Retenir le maximum verrouille toujours au plus tôt.

Contrepartie assumée: un coffre déverrouillé survit en arrière-plan. Elle est
compensée par `FLAG_SECURE` (déjà en place), qui vide la vignette du sélecteur
d'applications et interdit les captures d'écran. Reste hors couverture: un
téléphone déverrouillé physiquement pris en main dans la fenêtre du délai.

Au verrouillage, les écrans empilés (édition, réglages) sont dépilés. Sans
cela, un formulaire ouvert resterait affiché par-dessus l'écran de verrou,
adossé à un coffre fermé: la saisie continuerait, et l'enregistrement
échouerait en silence.

Verrouiller signifie: libérer la `SecureKey`, vider les entrées en
mémoire, revenir à l'écran de verrou, et effacer le presse-papier s'il
contient encore une valeur copiée depuis l'app.

Sur Android, `FLAG_SECURE` est activé: pas de capture d'écran, pas de
vignette dans la liste des applications récentes.

## 9. Export et import

L'export copie le fichier chiffré tel quel (feuille de partage Android,
dialogue de sauvegarde Linux). Il est inutile sans le mot de passe, donc
transférable par n'importe quel canal.

L'import: valider magic et version, **demander le mot de passe du fichier
importé et vérifier que le déchiffrement réussit avant de remplacer quoi
que ce soit**, conserver l'ancien coffre en `.bak`, puis remplacer.

C'est le chemin de synchronisation Linux ↔ Android: manuel, assumé, sans
serveur.

## 10. Tests

Développement piloté par les tests. Vérification: `flutter analyze` et
`flutter test`.

Crypto:
- aller-retour seal/open avec le bon mot de passe
- mauvais mot de passe rejeté
- en-tête falsifié (opslimit modifié) rejeté
- deux sauvegardes successives produisent des nonces différents

Stockage:
- écriture atomique: le fichier cible n'est jamais partiel
- `.bak` créé après une sauvegarde réussie
- fichier tronqué ou magic invalide: erreur propre, pas d'exception brute
- anti-fuite: aucune valeur en clair présente dans les octets du fichier

Modèle:
- aller-retour JSON, clefs unicode, valeur vide

Session:
- expiration de la minuterie efface la clé
- passage en arrière-plan verrouille

Widgets:
- mauvais mot de passe affiche l'erreur
- entrée ajoutée apparaît dans la liste
- la recherche filtre la liste
- le générateur respecte longueur et jeu de caractères demandés

## 11. À vérifier au début du plan

- `flutter doctor`: présence et état du SDK Android
- dépendances de build Linux: GTK, et `libsodium` fournie par
  `sodium_libs` ou par le système
- comportement réel de la dérivation Argon2id à 128 Mio sur l'appareil
  Android cible (ajuster `memlimit` si mise à mort par le système)
