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
- Aucun secret n'est écrit en clair sur le disque à la sauvegarde (fichier
  temporaire chiffré puis `rename`). **Seule exception, explicite**: exporter
  une pièce jointe individuellement l'écrit en clair sur le disque (§3 bis).
- Sur Android, le coffre et les pièces jointes sont exclus des sauvegardes
  automatiques du système (`allowBackup="false"` et
  `res/xml/backup_rules.xml`): sans ça, Auto Backup les envoyait par défaut
  vers Google Drive et vers le transfert d'appareil à appareil, un canal que
  rien ici ne prévoyait.
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
- **Signature de release.** `android/app/build.gradle.kts` lit
  `android/key.properties` s'il existe, et retombe sinon sur la clé de
  debug — publique, partagée par toutes les installations Flutter:
  n'importe qui peut alors fabriquer un APK substituable lors d'une mise à
  jour, et hériter du répertoire privé existant, coffre compris.
  L'infrastructure est prête (`key.properties`, `*.jks`, `*.keystore`
  exclus du dépôt), mais le basculement n'est pas fait: il impose une
  désinstallation, donc l'effacement du coffre.

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

La dérivation tourne dans un isolat séparé (`deriveKeyAsync`, dans
`vault_crypto.dart`), pas sur celui qui dessine l'écran: à 128 Mio et
3 passes, Argon2id prend de l'ordre d'une seconde, et l'exécuter sur
l'isolat d'interface gèle l'écran à chaque déverrouillage, création ou
changement de mot de passe — au pire moment si une écriture est en vol,
avec le risque qu'Android tue le processus pour non-réponse. Contrepartie
assumée: les 32 octets de la clé traversent un port de message, donc du
tas ordinaire, avant d'être recopiés dans la mémoire verrouillée d'une
`SecureKey`; le tampon de transit est remis à zéro juste après, mais sa
copie côté isolat, elle, ne l'est pas. `useIsolate: false` existe pour les
tests de widgets, qui tournent sous une horloge simulée où un isolat ne
rend jamais sa réponse.

Le fichier borne lui-même ce qu'il peut demander à la relecture: `opsLimit`
entre 1 et 8, `memLimit` entre 8 et 256 Mio (le double du défaut, pour
laisser de la marge à un futur durcissement). Argon2id tourne avec ces
paramètres **avant** que le tag AEAD ne soit vérifié: sans bornes, un fichier
hostile pourrait demander une allocation qui tue le processus à la simple
tentative d'ouverture.

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
  orphelin. Un import remplaçant tout le coffre en laisse aussi d'un coup:
  tous les blobs de l'ancien coffre deviennent orphelins sans être du
  déchet. Les effacer détruirait des pièces jointes que personne n'a
  demandé de supprimer: au déverrouillage suivant, ils sont donc mis en
  quarantaine dans `blobs/orphelins/`, pas effacés. Seuls les `*.blob.tmp`
  d'un `put` interrompu — incomplets, sans valeur possible — le sont.
- Un identifiant de pièce jointe relu dans le JSON du coffre est vérifié
  contre la forme `^[0-9a-f]{32}$`, à la lecture comme dans `BlobFileStore`.
  Le coffre est authentifié, mais pas forcément écrit par nous: un import
  accepte un fichier étranger avec son propre mot de passe, et un
  identifiant comme `../../victime` y ferait lire, écrire ou **effacer** un
  fichier hors de `blobs/`.
- La lecture d'une pièce jointe borne aussi la taille du blob lu sur le
  disque: le plafond de 25 Mio n'était vérifié qu'à l'écriture, si bien
  qu'un blob importé ou abîmé pouvait faire exploser la mémoire à
  l'ouverture.
- **L'export du coffre ne contient pas les pièces jointes**, qui vivent
  dans des fichiers séparés. L'interface le dit, et chaque pièce jointe
  peut être exportée individuellement. Une archive unique reste possible
  plus tard.
- Exporter une pièce jointe l'écrit en clair sur le disque: c'est le seul
  moment où un contenu quitte le coffre, et il est explicite.
- Le tampon d'une pièce jointe est remis à zéro dès qu'elle est chiffrée
  (`VaultSession.attach`), sauf si le fichier est refusé d'entrée pour sa
  taille — rien n'a alors été lu. L'interface l'efface aussi après usage
  (lecture, export); seul le décodage interne de `Image.memory` pour
  l'aperçu y échappe, le tampon source, lui, non.

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
{"v":1,"entries":[{"k":"...","val":"...","created":0,"updated":0,"att":[{"id":"...","name":"...","mime":"...","size":0,"created":0}]}]}
```

`created` / `updated` sont des timestamps Unix en millisecondes. `att` est
optionnel: absent des coffres écrits avant les pièces jointes, qui restent
donc lisibles sans migration; c'est la liste de leurs métadonnées (§3 bis).

`Vault.fromBytes` valide chaque champ et lève une vraie `FormatException`
(elle levait un `TypeError`, qui n'est pas une `Exception` et qu'aucun
appelant ne capturait) — le contenu authentifié n'est pas forcément écrit par
nous: l'import accepte un fichier étranger avec son propre mot de passe. Les
horodatages sont bornés à un siècle autour de l'époque Unix, pour écarter une
valeur fabriquée plutôt que de lever un `ArgumentError` obscur. La relecture
trie par clef et dédoublonne par clef, la plus récemment modifiée gagnant:
rien n'imposait l'unicité à l'écriture, et `upsert` retirait ensuite *toutes*
les entrées d'une clef dupliquée pour n'en réinsérer qu'une — les deux
disparaissaient. `entries` est `List.unmodifiable`, ce qui interdit un
constructeur `const` pour `Vault`; le coffre vide vit donc dans `Vault.empty`,
pas dans un littéral `const Vault([])`.

Cette comparaison de clefs passe par `canonicalKey` (NFC puis minuscules),
pas une simple casse ignorée: « café » existe avec un é précomposé
(U+00E9) ou avec un e suivi d'un accent combinant (U+0065 U+0301) —
visuellement identiques, distincts octet pour octet, et un clavier ou un
collage produit l'une ou l'autre écriture sans que l'utilisateur le sache.
Sans normalisation, la liste affichait deux entrées indistinguables, et
chercher l'une ne trouvait pas l'autre. `canonicalKey` sert à la recherche,
à l'unicité (`upsert`, `remove`), au dédoublonnage à la relecture ci-dessus
et à la garde de collision de l'écran d'édition — jamais à l'ordre
d'affichage, qui reste un simple `toLowerCase()`: au plus une entrée par
clef canonique survit avant le tri, donc l'écart ne s'y voit pas. La clef
enregistrée reste celle que l'utilisateur a tapée: seule la comparaison est
normalisée, pour ne pas imposer de migration aux coffres existants.
Dépendance `unorm_dart`, en Dart pur — le SDK ne fournit aucune fonction de
normalisation Unicode.

`Vault.toBytes` sérialise avec `JsonUtf8Encoder`, qui écrit directement des
octets, plutôt qu'avec `jsonEncode`: celui-ci produit d'abord une `String`
contenant le coffre entier en clair, une copie que Dart ne permet pas
d'effacer et qui survivait donc au `fillRange` que la couche crypto
applique consciencieusement au tampon qu'on lui rend. Le résultat est
identique octet pour octet: un coffre déjà écrit se relit sans changement.

## 5. Emplacements et écriture

- Linux: `$XDG_DATA_HOME/safe/vault.safe`, défaut `~/.local/share/safe/`.
  Lève un `StateError` si ni l'une ni l'autre variable n'est définie, plutôt
  que d'écrire dans le chemin littéral `null/.local/share/safe`, relatif au
  répertoire courant et donc n'importe où.
- Android: répertoire privé de l'application (`path_provider`,
  `getApplicationDocumentsDirectory`). Jamais le stockage externe.

Sous Linux, le dossier est créé en `0700` (`createPrivateDirectory`, dans
`private_directory.dart`): un umask ordinaire lui aurait donné `0755`, donc
`~/.local/share/safe/` lisible par tout autre compte de la machine, qui
pouvait copier le coffre et attaquer Argon2id hors ligne. Sans droit de
traversée sur le dossier, le mode des fichiers qu'il contient n'a plus
d'importance. L'appel passe par `chmod`, `dart:io` n'exposant pas l'appel
système directement; il échoue en silence, et un dossier déjà en place
n'est jamais retouché — l'utilisateur a pu en choisir les droits lui-même.
Rien à faire sous Android, déjà cloisonné par le système.

Séquence de sauvegarde, à chaque modification (le coffre est un blob
unique, il n'y a pas de mise à jour partielle):

1. sérialiser et chiffrer en mémoire
2. écrire `vault.safe.tmp`
3. `fsync`
4. copier l'ancien `vault.safe` vers `vault.safe.bak` s'il existe
5. `rename` de `vault.safe.tmp` sur `vault.safe` (atomique)

Une interruption à n'importe quelle étape laisse soit l'ancien coffre
intact, soit le nouveau complet, jamais un fichier à moitié écrit.

Limite de cette atomicité: le `rename` couvre un arrêt du processus, pas
une coupure d'alimentation brutale de la machine — `dart:io` n'expose
aucun moyen de forcer l'écriture de l'entrée de répertoire elle-même. Le
repli, dans ce cas comme dans les autres, est la restauration de la
sauvegarde décrite plus bas.

Quatre garanties supplémentaires, ajoutées après un audit:

- **Numéro de génération.** Une écriture dure; un verrouillage pendant
  qu'elle est en vol libère déjà la clé. Sans un jeton de génération relevé
  avant chaque `await` et vérifié après, la suite de l'opération réaffectait
  le coffre déchiffré en mémoire une fois l'écriture terminée: le coffre
  paraissait rouvert alors que la clé avait disparu. L'écriture, elle, va
  toujours jusqu'au bout — ce qui est sur le disque reste correct même si la
  session ne l'adopte plus.
- **File d'écriture et temporaire par écriture.** Deux sauvegardes en vol en
  même temps se marchaient dessus: chacune partait d'une photo du coffre
  prise avant son attente, et la dernière écrivait par-dessus les
  modifications de l'autre; `VaultFile` partageait en plus un seul
  `vault.safe.tmp` entre écritures concurrentes. Désormais chaque écriture a
  son propre temporaire (effacé si elle échoue), et `attach`,
  `removeAttachment`, `deleteEntry` calculent leur nouveau coffre à
  l'intérieur de la file, sur l'état courant — pas sur une copie prise avant
  d'attendre. Le chiffrement, lui, se fait immédiatement à l'appel de
  `save`: seule l'écriture passe par la file, pour qu'une sauvegarde
  demandée coffre ouvert atteigne le disque même si le verrouillage survient
  avant que la file ne se libère.
- **`.bak` supprimée au changement de mot de passe.** `VaultStore.write`
  prend un paramètre `keepPrevious`; le changement de mot de passe l'appelle
  à `false` et efface aussi `vault.safe.bak` s'il existe. Sans ça, l'ancien
  mot de passe ouvrait encore la copie de sauvegarde après le changement.
- **Restauration de la sauvegarde.** `vault.safe.bak` existait sans jamais
  être relue, et aucun écran ne la mentionnait. `VaultStore.readPrevious`
  la relit; `VaultSession.previousEntryCount` et `restorePrevious`
  l'exposent à l'écran Réglages. Le dialogue annonce le nombre d'entrées de
  la copie face au coffre actuel — une restauration à l'aveugle sur un
  coffre-fort n'est pas une offre honnête —, et l'opération est elle-même
  annulable: elle passe par la file d'écriture habituelle, qui refait donc
  une copie de l'état qu'elle abandonne. Aucun mot de passe à saisir: la
  garantie précédente efface la copie dès un changement de mot de passe,
  donc celle qui existe s'ouvre forcément avec la clé de la session en
  cours. Vérifiée avant toute écriture.

## 6. Architecture

Un fichier par responsabilité. La crypto ignore le disque; le stockage
ignore la crypto; l'interface ne voit que la session.

| Fichier | Rôle | Dépend de |
|---|---|---|
| `lib/crypto/vault_crypto.dart` | dérivation Argon2id, seal/open XChaCha20-Poly1305, en-têtes coffre et blob. Fonctions pures, aucune IO | sodium |
| `lib/model/vault.dart` | entrées, pièces jointes, (dé)sérialisation JSON, `canonicalKey` | storage/blob_store.dart, unorm_dart |
| `lib/storage/vault_store.dart` | interface d'écriture du coffre; `VaultFile` en est l'implémentation réelle, une version en mémoire sert aux tests | — |
| `lib/storage/vault_file.dart` | chemins par plateforme, lecture, écriture atomique, `.bak` | dart:io, path_provider, storage/private_directory.dart |
| `lib/storage/private_directory.dart` | crée le dossier du coffre, fermé (`0700`) aux autres comptes sous Linux | dart:io |
| `lib/storage/blob_store.dart` | pièces jointes sur le disque, une par identifiant; validation d'identifiant, quarantaine des orphelins | dart:io |
| `lib/storage/vault_transfer.dart` | export et import du fichier chiffré tel quel | crypto, storage/vault_store.dart |
| `lib/storage/app_settings.dart` | réglages en clair (`settings.json`): délai d'auto-lock, blocage des captures; seule source de vérité des choix de délai | dart:io |
| `lib/state/vault_session.dart` | état verrouillé/déverrouillé, `SecureKey` de session, minuterie d'auto-lock, file d'écriture, cycle de vie | crypto, storage/vault_store.dart, storage/blob_store.dart, model, sodium |
| `lib/ui/unlock_screen.dart` | création du coffre et déverrouillage | state |
| `lib/ui/entries_screen.dart` | liste, recherche, copie | state |
| `lib/ui/entry_edit_screen.dart` | ajout et modification, générateur | state, util, ui/attachments_section.dart |
| `lib/ui/attachments_section.dart` | section « Pièces jointes » de l'écran d'édition: ajout, lecture, export, suppression | state |
| `lib/ui/settings_screen.dart` | changement de mot de passe, délai d'auto-lock, blocage des captures, export, import | state, storage |
| `lib/ui/safe_logo.dart` | logo dessiné au trait (pas une image figée), utilisé sur l'écran de verrou | — |
| `lib/util/clipboard.dart` | copie avec effacement différé | — |
| `lib/util/password_generator.dart` | génération aléatoire | — |
| `lib/util/screen_security.dart` | canal vers `FLAG_SECURE` côté Android | flutter/services |
| `lib/main.dart` | initialisation de sodium, lecture des réglages, détecteur d'activité, thème, routage | tout |

`SecureKey` n'a pas de fichier propre: c'est un type de `package:sodium`,
détenu et libéré par `vault_session.dart`, pas une enveloppe maison.

## 7. Interface

Quatre écrans, plus un panneau de réglages.

**Création** (aucun fichier présent): mot de passe + confirmation, minimum
12 caractères — vérifié à la validation, pas de jauge de force affichée
pendant la saisie —, aucune règle de composition arbitraire. Avertissement
explicite sur l'absence de récupération.

**Verrou**: champ mot de passe, indicateur d'activité pendant la
dérivation. Message d'erreur unique « mot de passe incorrect » — l'échec
du tag AEAD ne distingue pas un mauvais mot de passe d'un fichier
corrompu, et distinguer les deux dans l'interface fuiterait de
l'information. Le détail technique va dans les logs de debug uniquement.

**Liste**: barre de recherche, entrées triées par clef, valeurs masquées
par défaut. Par entrée: révéler (bouton bascule, pas un appui maintenu),
copier, modifier, supprimer (avec confirmation). Bouton flottant pour
ajouter.

**Édition**: clef, valeur masquée avec bouton de révélation, bouton
« générer » (longueur 12–64, jeux lettres / chiffres / symboles).

**Réglages**: changer le mot de passe maître (nouveau sel, ré-chiffrement
complet), délai d'auto-lock (30 s, 1, 2 ou 5 min; défaut 2 min),
restauration de la sauvegarde précédente (§5), export, import.

Les champs clef, valeur et recherche désactivent `autocorrect` et
`enableSuggestions`: un clavier Android apprend sinon ce qui y est tapé, y
compris dans un dictionnaire personnel partagé entre applications. Les
champs de mot de passe maître n'ont pas eu besoin de ce traitement:
`obscureText` le leur assurait déjà.

La copie d'une valeur efface le presse-papier 30 s plus tard, ou plus tôt
si le coffre se verrouille entre-temps. L'effacement a lieu même si la
relecture du presse-papier échoue: depuis Android 10, `Clipboard.getData`
rend `null` quand l'app n'a pas le focus — le cas nominal ici, l'utilisateur
ayant basculé vers l'app où il colle la valeur —, si bien qu'un échec de
lecture comptait auparavant à tort comme « autre chose est là, ne pas
effacer » et l'effacement n'avait jamais lieu.

Sur Android, la copie passe par un canal natif (`dev.safe/clipboard`,
`MainActivity.kt`) plutôt que par `Clipboard.setData` de Flutter, qui ne
pose pas `EXTRA_IS_SENSITIVE`: sans cet indicateur, Android 13 et suivants
affichent le secret dans l'aperçu système du presse-papier, et les
claviers le rangent dans leur propre historique — un magasin hors de
portée de l'application, que l'effacement à 30 s ne touche pas. Le canal
pose l'extra à la copie, et efface via `clearPrimaryClip` (Android 9 et
suivants) sans relire le contenu au préalable. Repli sur le chemin Flutter
quand le canal n'existe pas (Linux); le résultat de la première tentative
est mémorisé, pour ne pas le retenter à chaque copie.

## 8. Verrouillage

Deux déclencheurs:

- minuterie d'inactivité, réinitialisée par toute interaction utilisateur —
  **frappes comprises**. Sur un clavier logiciel, saisir un caractère rare
  (parenthèse, symbole) demande de changer de page: la frappe est alors la
  seule activité, et l'ignorer verrouille le coffre sous les doigts de
  l'utilisateur.
- `AppLifecycleState.detached` uniquement: le processus s'arrête.

Le détecteur de ces interactions vit dans `builder:` de `MaterialApp`, pas
dans `VaultGate`: `home:` est à l'intérieur de la première route du
`Navigator`, alors que les écrans empilés — édition, réglages, générateur,
visionneuse de pièce jointe — en sont des frères dans l'`Overlay`. Un
détecteur posé plus bas ne voyait donc rien de ce qui s'y passait, et le
coffre se verrouillait sous les doigts de l'utilisateur en train de remplir
un formulaire.

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
compensée par `FLAG_SECURE`, qui vide la vignette du sélecteur d'applications
et interdit les captures d'écran.

`FLAG_SECURE` est réglable par l'utilisateur (ajouté le 2026-08-16), parce
qu'il empêche aussi les usages légitimes: capture d'écran pour un support
technique, partage d'écran, enregistrement d'une démonstration. Quatre
garde-fous autour de ce choix:

- actif par défaut, et un fichier de réglages absent ou abîmé retombe sur
  « actif »;
- l'activité Android le pose dès `onCreate`, avant que Flutter ait lu les
  réglages: le démarrage n'a pas de fenêtre non protégée, et Flutter ne fait
  que le relâcher ensuite si l'utilisateur l'a demandé;
- l'interface dit ce que la désactivation coûte, vignette des applications
  récentes comprise;
- `ScreenSecurity.setBlocked` rend un booléen plutôt que de supposer que
  l'appel a réussi, et `isSupported` distingue « rien à bloquer sous Linux »
  d'un refus réel du système sous Android: sans ça, l'interrupteur affichait
  « bloqué » après un refus du natif, sans que rien ne le vérifie.

Le réglage vit dans `settings.json`, en clair à côté du coffre: il ne dit rien
du contenu, et le chiffrer imposerait de déverrouiller le coffre avant de
pouvoir protéger l'écran. L'écriture passe par un temporaire puis un
`rename`, comme le coffre: `writeAsString` tronque avant d'écrire, et une
coupure en cours laissait un JSON partiel — donc un retour silencieux aux
valeurs par défaut à la lecture suivante.

Le délai de verrouillage y est conservé aussi (ajouté le 2026-08-16), en
secondes et lu comme `num` plutôt que `int`: un fichier édité à la main peut
contenir `120.0`, que certains décodeurs JSON rendent en `double`. Comme le
fichier est en clair et modifiable, la valeur relue est ensuite ramenée au
plus proche des choix proposés par l'interface — 30 s, 1, 2 ou 5 min, vers
le bas entre deux choix pour rester le plus protecteur: éditer
`settings.json` à la main ne permet pas de garder le coffre ouvert des
heures. Une valeur absente, d'un type inattendu ou hors bornes retombe sur
2 min. Cette liste de choix vit dans `lib/storage/app_settings.dart` et fait
seule foi — dropdown des réglages et bornes de validation confondus: deux
sources donnaient auparavant deux vérités pour un même réglage, le sous-titre
affichant par exemple « 45 s » avec « 2 min » sélectionné dans la liste.

Sous Linux, il n'existe pas d'équivalent: l'appel natif est absent et le canal
retombe silencieusement. Quelqu'un capable de capturer l'écran y est déjà
devant la session déverrouillée. Reste hors couverture: un
téléphone déverrouillé physiquement pris en main dans la fenêtre du délai.

Au verrouillage, les écrans empilés (édition, réglages) sont dépilés. Sans
cela, un formulaire ouvert resterait affiché par-dessus l'écran de verrou,
adossé à un coffre fermé: la saisie continuerait, et l'enregistrement
échouerait en silence.

L'écran d'édition demande confirmation avant d'abandonner une saisie non
enregistrée (retour arrière compris) — mais pas au verrouillage: il efface
alors ses champs et lève sa propre garde de sortie, sinon cette confirmation
retiendrait le dépilement et le clair resterait affiché par-dessus l'écran de
verrou. Pour la même raison, le dépilement déclenché par `VaultGate` est
différé après la frame: les écrans concernés doivent d'abord avoir pu réagir
au verrouillage.

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
- dérivation en isolat: même clé qu'une dérivation sur place, y compris
  `useIsolate: false` (§3)

Stockage:
- écriture atomique: le fichier cible n'est jamais partiel
- `.bak` créé après une sauvegarde réussie
- fichier tronqué ou magic invalide: erreur propre, pas d'exception brute
- anti-fuite: aucune valeur en clair présente dans les octets du fichier
- dossier du coffre et des pièces jointes lisibles du seul propriétaire
  sous Linux, sans retoucher un dossier déjà en place (§5)

Modèle:
- aller-retour JSON, clefs unicode, valeur vide
- deux écritures Unicode d'une même clef reconnues comme une seule:
  recherche, `upsert`, dédoublonnage à la relecture — sans réécrire la
  clef enregistrée (§4)

Session:
- expiration de la minuterie efface la clé
- le passage en arrière-plan seul ne verrouille pas; le retour au premier
  plan après le délai d'inactivité verrouille (§8)
- `detached` verrouille immédiatement
- le tampon d'une pièce jointe est effacé après chiffrement, sauf si le
  fichier est refusé pour sa taille (§3 bis)
- restauration de la sauvegarde: annonce ce qu'elle contient, refusée
  coffre verrouillé ou sans sauvegarde, sauvegarde abîmée signalée sans
  être appliquée (§5)

Widgets:
- mauvais mot de passe affiche l'erreur
- entrée ajoutée apparaît dans la liste
- la recherche filtre la liste
- le générateur respecte longueur et jeu de caractères demandés
- copie: passe par le canal natif sensible quand il existe, retombe sur
  Flutter sinon (§7)
- Réglages: le dialogue de restauration annonce le nombre d'entrées avant
  d'agir, et annuler ne change rien (§5)

## 11. À vérifier au début du plan

- `flutter doctor`: présence et état du SDK Android
- dépendances de build Linux: GTK, et le compilateur C nécessaire au *build
  hook* de `sodium`, qui compile lui-même libsodium (voir §3) — pas
  `sodium_libs`, qui n'intervient nulle part ici
- comportement réel de la dérivation Argon2id à 128 Mio sur l'appareil
  Android cible (ajuster `memlimit` si mise à mort par le système)
