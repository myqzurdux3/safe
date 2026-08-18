# Audit de `safe`

Audit mené le 2026-08-18 sur `master`, à partir du commit `f654a5b`.

Les phases suivent la commande reçue: cartographie, recherche de défauts en
lecture seule, code mort, corrections, structure, documentation, hygiène. La
section qui compte est **« Ce qui n'a pas été fait, et pourquoi »**, à la fin.

## Phase 0 — Cartographie

### Ce que c'est

Gestionnaire de mots de passe hors ligne, écrit en Flutter/Dart, ciblant Android
et Linux. Un seul fichier chiffré (`vault.safe`), pas de serveur, pas de compte.

| | |
|---|---|
| Langage | Dart 3.12.2 / Flutter 3.44.6 (stable) |
| Natif | Kotlin (Android), C++/CMake généré (Linux) |
| Dépendances | `pub` — `pubspec.yaml` + `pubspec.lock` versionné |
| Point d'entrée | `lib/main.dart` (`main()`) |
| Natif Android | `android/app/src/main/kotlin/dev/safe/safe/MainActivity.kt` |
| Code applicatif | 3 092 lignes dans `lib/` |
| Tests | 2 292 lignes dans `test/` |

### Découpage

```
lib/crypto/    Argon2id + XChaCha20-Poly1305, format de fichier (en-têtes)
lib/model/     Vault, VaultEntry, VaultAttachment — sérialisation JSON
lib/state/     VaultSession — clé en session, verrouillage automatique
lib/storage/   fichier coffre, blobs, réglages, export/import
lib/ui/        écrans Flutter
lib/util/      presse-papier, générateur, canal FLAG_SECURE
tool/          generate_icons.py — génération des icônes
```

### Build, lancement, tests

| Commande | Rôle |
|---|---|
| `flutter pub get` | dépendances |
| `flutter test` | suite complète |
| `flutter analyze` | analyse statique (`flutter_lints` + 4 règles) |
| `flutter build apk --release` | Android |
| `flutter build linux --release` | bundle Linux |

### État réel mesuré

| Mesure | Valeur |
|---|---|
| `flutter test` | **159 tests, tous verts**, 32 s |
| `flutter analyze` | **No issues found!**, 6,4 s |
| Couverture de lignes | **79 %** (923 / 1168) |
| `flutter build linux --release` | OK, 15 s |
| `flutter build apk --release` | OK, 38 s, APK de 52,6 Mio |

Base verte: l'audit peut continuer.

Couverture par fichier, du moins couvert au plus couvert:

| Fichier | Couverture |
|---|---|
| `lib/ui/settings_screen.dart` | 37 % |
| `lib/ui/attachments_section.dart` | 51 % |
| `lib/util/clipboard.dart` | 56 % |
| `lib/storage/vault_file.dart` | 68 % |
| `lib/main.dart` | 69 % |
| `lib/util/screen_security.dart` | 80 % |
| `lib/ui/entries_screen.dart` | 84 % |
| `lib/ui/unlock_screen.dart` | 91 % |
| `lib/ui/entry_edit_screen.dart` | 92 % |
| `lib/state/vault_session.dart` | 93 % |
| `lib/crypto/vault_crypto.dart` | 97 % |
| `lib/model/vault.dart` | 99 % |
| autres | 100 % |

## Phase 1 — Défauts trouvés

Cinq relectures parallèles (sécurité, correction, interface, code mort, doc), puis
vérification par moi. Les trouvailles marquées **vérifiée** ont été reproduites
par un test-sonde exécuté puis supprimé; le reste vient de la lecture du code.

Aucune correction n'est appliquée dans cette phase.

### Bloquant

| Fichier:ligne | Description | Correction proposée | Confiance |
|---|---|---|---|
| `state/vault_session.dart:154-156` | `lock()` pendant un `save()` en vol **rouvre le coffre**. `save()` réaffecte `_vault` après son `await`, sans vérifier qu'un verrouillage a eu lieu. Sonde: après `lock()`, `isUnlocked=false`; à la fin du `save()`, `isUnlocked=true`, coffre déchiffré en mémoire et réaffiché par `VaultGate`, alors que `_key` est nulle. Déclencheurs réels: bouton « Verrouiller » ou expiration du délai pendant l'écriture d'une pièce jointe de 25 Mio. | Jeton de génération incrémenté par `lock()`; `save()`, `create()` et `changePassword()` abandonnent si le jeton a changé pendant leur `await`. | **certain, vérifiée** |
| `storage/vault_file.dart:39,55,65` + `state/vault_session.dart` | Toutes les écritures partagent le même `vault.safe.tmp`, et rien ne sérialise les `save()`. Deux écritures qui se chevauchent entrelacent leurs octets dans le même fichier, ou lèvent. Sonde: `Future.wait([write(a), write(b)])` → `PathNotFoundException: Cannot rename file to '…/vault.safe', path = '…/vault.safe.tmp'`. Atteignable: `_busy` d'`AttachmentsSection` et celui d'`EntryEditScreen` sont distincts. | Sérialiser les écritures dans `VaultSession` (chaînage de futures), et nommer le temporaire de façon unique, effacé en cas d'échec. | **certain, vérifiée** |

### Majeur

| Fichier:ligne | Description | Correction proposée | Confiance |
|---|---|---|---|
| `main.dart:159-170` | Le détecteur d'activité (`Focus` + `Listener`) enveloppe `VaultGate`, qui est le `home:` du `MaterialApp` — donc **à l'intérieur** de la première route. Les écrans empilés (édition, réglages, dialogues, générateur, visionneuse) sont des frères dans l'`Overlay`: **aucun de leurs événements ne compte comme activité**. Sonde: tape sur l'écran de base → `touch()` appelé; tape sur l'écran d'édition empilé → `touch()` appelé **0 fois**. C'est la cause de fond du verrouillage sous les doigts déjà rencontré. | Remonter le détecteur au-dessus du `Navigator` via `MaterialApp(builder:)`. | **certain, vérifiée** |
| `state/vault_session.dart:187,205` et `:163-170` | Perte de mise à jour: `attach()` capture `_vault` **avant** `await _blobs.put(...)`, puis sauvegarde cette photo périmée. Sonde: une entrée créée pendant l'écriture du blob disparaît. Même schéma dans `changePassword()`. | Relire `_vault` après l'`await`, ou appliquer la modification via une fonction de transformation exécutée après le verrou d'écriture. | **certain, vérifiée** |
| `storage/blob_store.dart:28,31,42` + `model/vault.dart:20` | Traversée de chemin: l'identifiant de pièce jointe vient du JSON du coffre sans validation. Sonde: `delete('../victime')` efface un fichier hors du dossier `blobs/`, `put('../ecrit')` en écrit un. Atteignable par `importBytes`, où le fichier et le mot de passe viennent d'un tiers. | Refuser tout identifiant ne correspondant pas à `^[0-9a-f]{32}$`, à la relecture JSON **et** dans `BlobFileStore`. | **certain, vérifiée** |
| `ui/entry_edit_screen.dart:175-192` | Le champ de la valeur secrète est révélé sans `obscureText` (choix assumé pour le multiligne) mais **aussi sans `autocorrect: false` ni `enableSuggestions: false`**, qui valent `true` par défaut. Le clavier Android apprend donc les secrets tapés: dictionnaire personnel et barre de suggestions, hors du coffre et hors de son cycle de vie. | Ajouter `autocorrect: false, enableSuggestions: false`. | certain |
| `android/app/src/main/AndroidManifest.xml:2-6` | Ni `android:allowBackup="false"` ni `android:dataExtractionRules`. Auto Backup est actif par défaut et couvre le répertoire privé: `vault.safe`, `vault.safe.bak` et **toutes les pièces jointes** partent vers Google Drive et le transfert d'appareil à appareil. `DEPLOY.md` promet l'inverse. | `android:allowBackup="false"` + règles d'extraction vides. | certain |
| `storage/vault_file.dart:62-64` | `vault.safe.bak` conserve la génération précédente et n'est jamais effacé. Après `changePassword`, il reste déchiffrable avec **l'ancien** mot de passe — ce qui annule l'objet du changement. Après `deleteEntry`, il contient encore l'entrée supprimée. Et il n'est **jamais relu**: aucun chemin de restauration n'existe. | Effacer le `.bak` après un `rename` réussi, impérativement après `changePassword`; ou assumer le rôle de sauvegarde et le rendre restaurable et ré-chiffré. | certain |
| `util/clipboard.dart:28-40` | Depuis Android 10, `Clipboard.getData` rend `null` quand l'app n'a pas le focus. `clearNow()` compare alors `null` à la valeur attendue, conclut « ce n'est plus la nôtre » et **n'efface rien**, silencieusement. Or c'est le cas nominal: on copie, puis on bascule vers le navigateur. | Effacer sans condition quand la lecture échoue, ou passer par un canal natif. | probable |
| `util/clipboard.dart:20-25` | `Clipboard.setData` ne pose pas `EXTRA_IS_SENSITIVE`: sur Android 13+ le secret s'affiche dans l'aperçu système, et Gboard le range dans son propre historique, que `clearNow()` ne touche pas. | Canal natif posant `ClipDescription.EXTRA_IS_SENSITIVE`. | certain (absence) / probable (impact) |
| `ui/attachments_section.dart:82-86` | `setState(() => _busy = true)` juste après `await openFile()`, **sans garde `mounted`**. Le sélecteur de fichiers natif peut rester ouvert des minutes: le verrouillage dépile l'écran d'édition, et le retour du sélecteur fait un `setState` sur un `State` détruit. `settings_screen.dart:145` garde bien `mounted` au même endroit — l'incohérence confirme l'oubli. | `if (!mounted) return;` avant le `setState`. | certain |
| `ui/entries_screen.dart:124-129` | Suppression d'entrée sans `try`/`catch`: un `StateError` (coffre verrouillé) ou une erreur disque laisse l'utilisateur devant une entrée qui n'a pas bougé, sans message, l'erreur partant en `unhandled Future error`. | `try`/`catch` + `SnackBar`, sous garde `mounted`. | certain |
| `ui/attachments_section.dart:263-268` | Bouton « Exporter en clair »: ni `try`/`catch`, ni `mounted`, et il lit `_busy` sans jamais le lever. Un déchiffrement raté est totalement silencieux, et deux appuis rapides lancent deux exports. | Méthode dédiée avec `_busy`, `try`/`catch` et garde `mounted`. | certain |
| `ui/attachments_section.dart:191-200` | `removeAttachment` sans `try`/`catch`, et `widget.onChanged()` (un `setState` du parent) appelé **avant** la garde `mounted` de la ligne 197. | Envelopper, et déplacer `onChanged()` sous la garde. | certain |
| `ui/settings_screen.dart:67-81` | Les deux réglages basculent visuellement **avant** l'appel natif et l'écriture disque, aucun des deux n'étant vérifié. `ScreenSecurity.setBlocked` avale déjà ses erreurs: l'utilisateur peut croire les captures d'écran bloquées alors qu'elles ne le sont pas. Pour un coffre-fort, une protection silencieusement absente est pire qu'une erreur visible. | Faire remonter un booléen de succès, n'appliquer l'état visuel qu'après, `try`/`catch` sur l'écriture avec retour à l'état précédent. | certain |
| `util/screen_security.dart:20-25` | Deux `catch` vides. Un échec de pose de `FLAG_SECURE` est indiscernable d'un succès. | Rendre `Future<bool>`. | certain |
| `state/vault_session.dart:101-107,163-170` | `create()` et `changePassword()` ne libèrent pas la `SecureKey` si `seal` ou `write` lève. `unlock()` le fait correctement. Le finaliseur natif de `sodium` finit par la zéroïser, mais à un moment indéterminé. | `catch (_) { key.dispose(); rethrow; }` comme dans `unlock`. | certain |
| `state/vault_session.dart:103,116,167` | Argon2id (3 passes, 128 Mio) tourne **sur l'isolat d'interface**, en appel synchrone. Sur téléphone modeste: gel complet de l'écran pendant la dérivation, risque d'ANR. | Déporter la dérivation dans un isolat. | probable (évident, non mesuré) |
| `state/vault_session.dart:130,278-295` | `purgeOrphanBlobs()` au déverrouillage efface **tous** les blobs que le coffre courant ne référence pas. Après un import (le seul chemin de synchronisation Linux ↔ Android), les pièces jointes locales sont donc détruites définitivement et sans avertissement. | Déplacer vers `blobs/orphelins/` plutôt qu'effacer, ou n'effacer qu'après un délai de grâce. | certain |
| `model/vault.dart:149,81-98,18-28` | `Vault.fromBytes` documente `FormatException` mais lève `TypeError` sur un JSON structurellement valide et mal typé (entrée non-objet, champ absent, mauvais type). Sonde: `_TypeError`, `isFormat=false`. Rattrapé par les `catch` non typés de l'interface, donc pas de plantage — mais le message affiché devient faux. | Validation champ par champ levant `FormatException`. | **certain, vérifiée** |

### Mineur

| Fichier:ligne | Description | Correction proposée | Confiance |
|---|---|---|---|
| `storage/blob_store.dart:33,50-59` | Un `put()` interrompu laisse un `<id>.blob.tmp` que `ids()` ne liste pas: `purgeOrphanBlobs()` ne l'efface donc jamais. Sonde: `IDS={aa11}` alors que `bb22.blob.tmp` est sur le disque. Jusqu'à 25 Mio perdus par occurrence. | Balayer aussi les `*.blob.tmp` à la purge. | **certain, vérifiée** |
| `storage/blob_store.dart:57` | `replaceAll('.blob', '')` retire **toutes** les occurrences. Inoffensif tant que les identifiants sont hexadécimaux, mais c'est une hypothèse implicite. | `substring`. | certain |
| `storage/blob_store.dart:55` | `listSync()` dans une méthode `async`: entrées/sorties bloquantes sur l'isolat d'interface, juste après une dérivation déjà coûteuse. | `directory.list()`. | certain |
| `storage/vault_file.dart:26` | `HOME` et `XDG_DATA_HOME` absents produisent le chemin littéral `null/.local/share/safe`, relatif au répertoire courant. | Lever une erreur explicite. | certain |
| `storage/vault_file.dart:65` | Pas de `fsync` du répertoire après le `rename`: sur coupure d'alimentation, l'atomicité annoncée n'est pas garantie. `dart:io` ne l'expose pas. | Documenter la limite plutôt que de la nier. | à vérifier |
| `storage/app_settings.dart:99-107` | `catch (_)` avale tout, y compris les erreurs de programmation. Un `settings.json` abîmé réinitialise les réglages sans un mot. | Restreindre aux exceptions attendues. | certain |
| `storage/app_settings.dart:113` | Écriture non atomique (`writeAsString` tronque puis écrit) et non sérialisée: deux bascules rapprochées lancent deux écritures concurrentes. | Motif temporaire + `rename`. | certain |
| `storage/app_settings.dart:51` | `seconds is int`: un `120.0` écrit à la main perd le réglage sans avertissement. | `is num` + `round()`. | certain |
| `model/vault.dart:170-190` | Rien n'impose l'unicité des clefs à la relecture. Un coffre contenant deux fois `gmail` perd les deux à l'`upsert` suivant. La garde d'unicité vit dans l'interface, sensible à la casse, alors que le tri ne l'est pas. | Dédupliquer dans `fromBytes`, décider et documenter la sensibilité à la casse. | probable |
| `model/vault.dart:122,157` | L'invariant « triées par clef » documenté n'est établi ni par le constructeur ni par `fromBytes`; `entries` est une liste modifiable exposée telle quelle dans une classe dite immuable. | Trier à la relecture, exposer `List.unmodifiable`. | certain |
| `model/vault.dart:184,194,200` | `toLowerCase()` sans normalisation Unicode: `café` précomposé et décomposé sont deux clefs distinctes, visuellement identiques. | Normaliser en NFC à la saisie. | à vérifier |
| `util/clipboard.dart:24` + `state/vault_session.dart:142` | `Timer(clearAfter, clearNow)` et `unawaited(...)` laissent une exception de plateforme sans destinataire: erreur de zone au lieu d'un échec local. | `catchError` explicite. | probable |
| `state/vault_session.dart:221-227` | `readAttachment` déchiffre sans borne, alors que les 25 Mio ne sont vérifiés qu'à l'écriture. Un blob importé ou corrompu fait exploser la mémoire à l'ouverture. | Vérifier la taille du fichier avant lecture. | à vérifier |
| `state/vault_session.dart:288` | `purgeOrphanBlobs` prend un instantané des identifiants: un `attach()` en cours juste après le déverrouillage peut voir son blob effacé avant que le coffre ne le référence. | Purger avant `_adopt`. | à vérifier |
| `crypto/vault_crypto.dart:98-100` | Un fichier hostile peut imposer 1 Gio × 32 passes d'Argon2id **avant** toute vérification d'authenticité: mise à mort du processus à la simple tentative d'ouverture. | Plafonner à ce que l'app encaisse vraiment (256 Mio / 8 passes). | certain |
| `crypto/vault_crypto.dart:191` et `model/vault.dart:160` | Le zéroïsage est partiel: `utf8.encode` et `jsonEncode` laissent deux copies non effaçables du clair complet sur le tas; seule la troisième est remise à zéro. | Sérialiser vers un tampon d'octets, ou documenter honnêtement la limite. | certain |
| `crypto/vault_crypto.dart:259-294` | Les pièces jointes en clair ne sont jamais zéroïsées, contrairement au coffre. | Aligner, ou documenter. | certain |
| `storage/vault_file.dart`, `blob_store.dart`, `app_settings.dart` | Aucune restriction de permissions: sous Linux les fichiers sont créés en `0644`, lisibles par tout autre compte de la machine, qui peut alors attaquer Argon2id hors ligne. | `0700` sur le dossier, `0600` sur les fichiers. | certain |
| `main.dart:152-155` | `vaultExists()` (accès disque) relancé à **chaque** `notifyListeners()`, avec double reconstruction d'`EntriesScreen`. | Ne recalculer que sur la transition vers l'état verrouillé. | certain |
| `main.dart:39-45` | La `VaultSession` n'est jamais `dispose()`ée; sous Linux, minuterie et clé ne sont libérées à aucun arrêt propre. | Libérer sur fermeture de fenêtre. | certain |
| `ui/entry_edit_screen.dart:99-105` | `setState` dans le `catch` sans garde `mounted`, alors que le chemin de succès juste en dessous en a une. | `if (!mounted) return;`. | certain |
| `ui/entry_edit_screen.dart` (build) | Aucun `PopScope`: le retour arrière jette une saisie en cours sans un mot. | `PopScope` + confirmation. | certain |
| `ui/entry_edit_screen.dart:55-66` | Le message « Le coffre s'est verrouillé pendant la saisie » est inatteignable: `main.dart:147` dépile l'écran avant que le bouton n'existe encore. Le code et l'intention se contredisent. | Trancher: ne pas dépiler l'écran d'édition, ou retirer la branche. | probable |
| `ui/entry_edit_screen.dart:237-286` | La feuille du générateur n'appelle jamais `touch()`: régler le curseur trente secondes verrouille le coffre. Aggravé par le défaut de `main.dart:159`. | `touch()` dans les `onChanged`. | certain |
| `ui/settings_screen.dart:91,155` | `setState` après `showDialog` sans garde `mounted`. | `if (!mounted) return;`. | probable |
| `ui/settings_screen.dart:166-170` | `catch` fourre-tout: un disque plein est rapporté comme un mot de passe incorrect, et l'utilisateur ressaisit indéfiniment un mot de passe juste. | Distinguer `WrongPasswordException` du reste. | certain |
| `ui/settings_screen.dart:208-215` | Un délai de 45 s (accepté par les bornes) s'affiche « Après 45 s » avec « 2 min » sélectionné dans la liste. | Dériver les deux du même champ. | certain |
| `ui/settings_screen.dart:55-64` | Le setter `autoLockDelay` — qui notifie les écouteurs — est appelé **dans** le callback de `setState`. | Sortir l'effet de bord du callback. | certain |
| `ui/entries_screen.dart:156-179` | Aucune garde contre le double appui sur « Ajouter » et « Réglages »: deux routes identiques empilées. | Garde de navigation. | probable |
| Messages d'erreur interpolant `$error` (6 endroits) | Exposent des chemins de système de fichiers dans des `SnackBar`. Aucun secret, mais surface inutile. | Message stable côté utilisateur. | certain |

### Cosmétique

| Fichier:ligne | Description | Confiance |
|---|---|---|
| `ui/entries_screen.dart:237`, `entry_edit_screen.dart:160` | `Text('••••••••')` est lu puce par puce par un lecteur d'écran. | certain |
| `ui/entries_screen.dart:244-272` | Les trois boutons par ligne ont des info-bulles génériques: un lecteur d'écran ne dit pas de quelle entrée il s'agit. | certain |
| `ui/entries_screen.dart:224`, `attachments_section.dart:253` | Pas de `maxLines`/`overflow`: une clef longue fait enfler la tuile. | certain |
| `ui/entry_edit_screen.dart:161-163` | En mode masqué, le sous-titre divulgue le nombre de lignes du secret. | certain |
| `ui/attachments_section.dart:243-278` | Liste de pièces jointes non paresseuse dans un `Column`. | certain |
| `state/vault_session.dart:262` | `deleteEntry` réécrit tout le coffre même quand la clef n'existe pas. | certain |
| `android/app/build.gradle.kts:18` | `// TODO: Specify your own unique Application ID` alors qu'il **est** personnalisé. | certain |

### Vérifié sans trouvaille

Dit explicitement, pour que l'absence de ligne dans le tableau ne se lise pas comme un oubli:

- **Nonces**: neufs à chaque appel, 24 octets de CSPRNG, aucune réutilisation possible, y compris entre coffre et blobs qui partagent la clé.
- **Données associées AEAD**: l'en-tête **complet** est authentifié dans les quatre sens (`seal`, `sealBytes`, `openWithKey`, `openBytes`). Aucun champ d'en-tête n'est modifiable sans invalider le tag.
- **Bornes de parsing**: `VaultHeader.parse` et `BlobHeader.parse` vérifient la longueur avant tout accès; aucun dépassement, aucune allocation dérivée d'un entier non validé.
- **Générateur de mots de passe**: `Random.secure()`, pas de biais modulo (le SDK fait du rejection sampling), Fisher-Yates correct, ~131 bits pour le défaut de 20 caractères.
- **Secrets dans l'historique Git**: 18 commits parcourus avec `git log -p --all` et une recherche par motifs; aucune fuite, aucun keystore, aucun `.env`.
- **Dépendances**: `flutter pub outdated` → « all up-to-date » pour les dépendances directes. Aucune dépendance vulnérable connue.
- **Permissions Android**: aucune dans le manifeste principal; `INTERNET` n'existe que dans la variante debug.
- **Chemin de stockage**: répertoire privé de l'application, jamais le stockage externe.
- **`dispose()` d'interface**: tous les contrôleurs et le `FocusNode` sont libérés.
- **`use_build_context_synchronously`**: tous les usages de `context` après un `await` sont gardés. Le défaut est ailleurs, sur les `setState`.
- **Aucun `TODO`/`FIXME`/`HACK`** dans `lib/`, aucun `print`.
- **Réfuté**: le coffre n'est **pas** réécrit à chaque frappe. `onChanged` ne fait qu'un `touch()`; seule la validation explicite sauvegarde.

## Phase 2 — Code mort et dépendances

Commit: `0a72516`.

### Supprimé, preuve à l'appui

| Élément | Preuve de non-usage |
|---|---|
| dépendance `cupertino_icons` | `grep -rni cupertino lib test` → aucune ligne. Reste du template `flutter create`. |
| `SafeLogo.color` | `grep -rn 'SafeLogo(' lib test` → 3 appels, aucun ne passe `color`; la branche de repli était la seule vivante. |
| `MemorySettingsStore` déplacée de `lib/` vers `test/support/` | Aucune référence dans `lib/`, 7 dans `test/ui/`. Elle était livrée dans le binaire. Rejoint `MemoryVaultStore` et `MemoryBlobStore`, qui vivaient déjà là. |
| `VaultHeader.nonceLength` | Aucune référence hors de sa déclaration. **Pas supprimée**: `length` est maintenant calculée à partir d'elle, ce qui empêche la taille de l'en-tête de dériver de la disposition réelle des champs. |
| ~40 lignes de commentaires du template dans `pubspec.yaml` et `analysis_options.yaml` | Boilerplate `flutter create` jamais édité (commit `19da785`). |
| `TODO` sur l'`applicationId` dans `build.gradle.kts` | Faux depuis longtemps: l'identifiant **est** personnalisé (commit `19da785`). |
| `safe.iml`, `android/safe_android.iml`, `coverage/lcov.info` | Fichiers d'éditeur et artefact de build, cessent d'être suivis (commits `19da785`, `44f54ad`). |

### Mort en apparence, gardé sciemment

La règle « pas de modification sans gain mesurable » vaut aussi pour les
suppressions. Ces éléments ne sont référencés que par les tests, ou pas du tout,
et sont restés:

| Élément | Pourquoi |
|---|---|
| `VaultCrypto.sealWithPassword` | 16 usages, tous dans les tests. Supprimer imposerait de réécrire ces 16 tests pour un gain nul. |
| `SettingsScreen.screen`, `SecureClipboard.clearAfter`, `generatePassword(random:)` | Points d'injection. En supprimer un ne fait rien gagner et coûte en testabilité — `SettingsScreen.screen` a d'ailleurs servi ensuite, pour tester un blocage d'écran refusé (`eee4757`). |
| branches `Platform.isIOS` | Inatteignables (pas de dossier `ios/`), mais inoffensives; les retirer serait du bruit dans l'historique. |
| `assets/icon/safe_64.png`, `safe_128.png`, `safe_512.png` | Non déclarés dans `pubspec.yaml`, mais régénérés par `tool/generate_icons.py` à chaque exécution: les supprimer ne tient pas. |
| `VaultAttachment.created` | Jamais affiché, mais sérialisé dans le JSON: le retirer changerait le format des coffres existants. |

### Dépendances

`flutter pub outdated`: « all up-to-date » pour les dépendances directes. Huit
paquets transitifs sont en retard, tous épinglés par les contraintes du SDK
Flutter, aucun à surface de sécurité. Aucune dépendance utilisée sans être
déclarée. `pubspec.lock` versionné et cohérent.

## Phase 3 — Corrections

Un commit par correctif, test rouge d'abord. Quand la correction a précédé le
test (un seul lot, celui des échecs silencieux d'interface), le test a été
vérifié rouge à rebours, en remisant `lib/` avec `git stash` — c'est dit dans le
message de commit concerné.

| Gravité | Défaut corrigé | Commit |
|---|---|---|
| **bloquant** | `lock()` pendant un `save()` en vol rouvrait le coffre: contenu déchiffré réaffiché, clé déjà libérée | `2dbf692` |
| **bloquant** | Écritures concurrentes sur un `vault.safe.tmp` partagé, et sans ordre: coffre illisible, ou `PathNotFoundException`, ou modification perdue | `edec57a` |
| majeur | L'activité sur les écrans empilés ne comptait pas: verrouillage sous les doigts | `dcb53c3` |
| majeur | Traversée de chemin par l'identifiant d'une pièce jointe relu d'un coffre importé | `0fe0828` |
| majeur | Le clavier Android apprenait les secrets tapés; Auto Backup emportait coffre et pièces jointes | `424cb55` |
| majeur | L'ancien mot de passe ouvrait encore `vault.safe.bak` après un changement | `bcf563f` |
| majeur | Presse-papier jamais effacé quand l'app n'a pas le focus — le cas nominal | `aae7bcc` |
| majeur | Les réglages affichaient des protections sans vérifier qu'elles avaient été obtenues | `eee4757` |
| majeur | Sept échecs silencieux dans l'interface | `245f8fe` |
| majeur | Le nettoyage automatique détruisait les pièces jointes après un import | `020ee40` |
| majeur | `Vault.fromBytes` levait `TypeError`; tri et immuabilité documentés mais non tenus; clefs en doublon perdues toutes les deux | `f6c7d73` |
| majeur | Bornes Argon2id d'un fichier hostile trop larges; lecture d'une pièce jointe non bornée | `d17f612` |
| mineur | Réglages écrits non atomiquement; `HOME` absent donnait le chemin littéral `null/...` | `c90f3f0` |
| mineur | Une saisie en cours partait sans confirmation | `1dc2108` |
| mineur | Deux vérités pour le délai de verrouillage; un accès disque par sauvegarde | `6301c5c` |

Le correctif clavier et manifeste (`424cb55`) porte le message générique d'un
hook de sauvegarde automatique qui a committé pendant une coupure de connexion.
L'historique n'a pas été réécrit pour le renommer, la consigne étant de demander
d'abord.

## Phases 4 à 6 — Structure, documentation, hygiène

### Formatage et lint

`dart format` n'avait jamais été passé: 29 des 60 fichiers étaient mis en forme à
la main (`4d97fa9`). La commande de vérification
`dart format --output=none --set-exit-if-changed lib test` sort maintenant sans
rien signaler, et fait partie de la vérification continue.

`analysis_options.yaml` gardait 22 lignes de commentaires du template; les quatre
règles ajoutées au jeu `flutter_lints` sont conservées et leur raison est dite.

### Documentation

`README.md`: l'emplacement des données ne mentionnait ni `settings.json` ni
`blobs/orphelins/`; il n'y avait aucune section Configuration, aucune mention des
prérequis, ni contribution ni licence. La contradiction entre `Exec=safe`
(fichier versionné) et le chemin absolu de `DEPLOY.md` est maintenant expliquée
au lieu d'être laissée au lecteur.

`DEPLOY.md` (`defd316`): deux affirmations fausses corrigées, et le bloc
d'installation Linux **exécuté** dans un faux `HOME` jetable pour vérifier qu'il
marche — `$HOME` remplace un `/home/user/...` codé en dur, ce qui imposait aussi
de corriger le heredoc, protégé par des quotes et donc sans substitution.

`docs/superpowers/specs/`: mis à jour (voir le commit `docs:` correspondant).
`docs/superpowers/plans/`: plan d'exécution historique, ni réécrit ni supprimé,
mais coiffé d'un encadré qui dit qu'il est terminé et que ses signatures d'API
n'ont plus cours.

### Hygiène du dépôt

Commits `19da785` et `44f54ad`.

| Élément | Avant | Après |
|---|---|---|
| `.gitignore` | 6 lignes; `coverage/`, `*.iml`, `.vscode/`, `*.log` absents | complet et commenté |
| Fichiers d'éditeur suivis | `safe.iml`, `android/safe_android.iml` | plus suivis |
| Artefact de build suivi | `coverage/lcov.info` | plus suivi |
| CI | aucune | `.github/workflows/ci.yml`: format, analyse, tests, puis compilation réelle des deux cibles |
| `CONTRIBUTING.md` | absent | présent |
| `pubspec.yaml` | `description: "A new Flutter project."` | description réelle, boilerplate retiré |
| Licence | absente | **toujours absente, volontairement** — voir « À toi de décider » |

### Cloner depuis zéro

Fait réellement, dans un répertoire propre, en ne suivant que le `README.md`:

```
git clone <dépôt> && cd <dépôt>
flutter pub get
dart format --output=none --set-exit-if-changed lib test   → 0 changed
flutter analyze                                            → No issues found!
flutter test                                               → 218 tests, All tests passed!
flutter build linux --release                               → ✓ Built .../bundle/safe
```

Aucun fichier manquant, aucune étape non documentée.

## Rapport final

### État initial contre état final

| Mesure | Avant (`f654a5b`) | Après | Vérifié par |
|---|---|---|---|
| Tests | 159 | **218** | `flutter test` |
| Couverture de lignes | 79,0 % (923/1168) | **81,7 %** (1080/1322) | `flutter test --coverage` |
| `flutter analyze` | No issues found! | No issues found! | idem |
| `dart format` | 29 fichiers non conformes | **0** | `--set-exit-if-changed` |
| Lignes dans `lib/` | 3 092 | 3 670 | `wc -l` |
| Lignes dans `test/` | 2 292 | 3 696 | `wc -l` |
| Dépendances directes | 6 | **5** | `pubspec.yaml` |
| Fichiers suivis | 101 | 121 | `git ls-files` |
| Build Linux | OK | OK | `flutter build linux --release` |
| Build APK release | OK, 52,6 Mio | OK | `flutter build apk --release` |
| CI | aucune | format + analyse + tests + 2 builds | `.github/workflows/ci.yml` |

Le nombre de lignes de `lib/` augmente de 19 %: ce sont des gardes, des
validations et les commentaires qui disent pourquoi elles existent. Aucun
correctif n'a été fait par réécriture.

### Ce qui n'a pas été fait, et pourquoi

C'est la section importante. Rien ici n'est « propre »; ce sont des choix.

**1. Argon2id tourne toujours sur l'isolat d'interface.** `deriveKey` est un
appel synchrone depuis `create`, `unlock` et `changePassword`, avec 3 passes sur
128 Mio. Sur un téléphone modeste: gel de l'écran pendant la dérivation, et
risque d'ANR Android. *Pas corrigé* parce que la parade — déporter dans un
isolat — se heurte à `SecureKey`, qui n'est pas transférable entre isolats: il
faudrait faire transiter les octets de la clé par un port de message, donc les
sortir de la mémoire verrouillée que `sodium` protège par `mlock`. Ce serait
échanger une gêne visible contre une régression de sécurité invisible. La bonne
forme est de déplacer tout `VaultCrypto` dans l'isolat, ce qui est une
refonte, pas un correctif d'audit. **Non mesuré**: je n'ai pas d'appareil bas de
gamme sous la main, seul un Pixel 9a.

**2. Le zéroïsage de la mémoire reste largement symbolique.** `seal` efface
consciencieusement son tampon de clair, mais `Vault.toBytes` a déjà produit deux
copies non effaçables du coffre entier: la `String` du `jsonEncode` et le tampon
d'`utf8.encode`. Idem pour le mot de passe, qui vit dans une `String` avant
d'être encodé. *Pas corrigé* parce que le faire vraiment demande de sérialiser en
JSON directement vers un tampon d'octets, sans passer par une `String` — donc un
encodeur maison. Le README annonce déjà cette limite; elle est réelle et plus
large que ce qu'il laisse croire.

**3. Les pièces jointes en clair ne sont pas zéroïsées.** `sealBytes` et
`openBytes` laissent le contenu déchiffré sur le tas, contrairement au coffre.
*Pas corrigé* pour la même raison de fond, et parce qu'un tampon de 25 Mio
traverse plusieurs couches (`file_selector`, `share_plus`, `Image.memory`) dont
aucune ne promet de ne pas le copier.

**4. Aucune restriction de permissions sur les fichiers créés.** Sous Linux,
`~/.local/share/safe/vault.safe` naît en `0644`: lisible par tout autre compte de
la machine, qui peut alors attaquer Argon2id hors ligne. *Pas corrigé* parce que
`dart:io` n'expose pas `chmod`: il faudrait un `Process.run('chmod')` — une
dépendance à un binaire externe sur un chemin critique — ou du code natif. Sous
Android le répertoire privé protège déjà. **À faire, mais pas à l'aveugle.**

**5. `vault.safe.bak` n'est toujours jamais relue.** Le changement de mot de
passe ne la laisse plus derrière lui (`bcf563f`), mais aucun chemin de
restauration n'existe et aucun écran ne la mentionne: c'est un filet dont seul
qui lit le code sait qu'il existe. *Pas corrigé* parce que le trancher est un
choix de produit — exposer une restauration, ou supprimer le mécanisme et gagner
la moitié des entrées/sorties de chaque sauvegarde (la copie double le volume
écrit). Ce n'est pas à un audit de décider.

**6. Pas de `fsync` du répertoire après le `rename`.** Le contenu du temporaire
est bien vidé sur le disque, l'entrée de répertoire non. Sur coupure
d'alimentation, selon le système de fichiers, le coffre peut réapparaître en
version ancienne. *Pas corrigé*: `dart:io` n'expose pas de `fsync` de
répertoire. L'atomicité annoncée vaut contre un arrêt du processus, pas contre
une coupure de courant — c'est désormais dit plutôt que sous-entendu.

**7. `Clipboard.setData` ne pose pas `EXTRA_IS_SENSITIVE`.** Sur Android 13+, le
secret copié s'affiche dans l'aperçu du presse-papier système, et Gboard le range
dans son propre historique — un magasin distinct que `clearNow` ne touche pas.
L'effacement à 30 s ne protège donc pas contre le vecteur le plus probable.
*Pas corrigé*: il faut un canal natif dédié, du même genre que celui de
`FLAG_SECURE`. **C'est la plus grosse faille restante côté Android.**

**8. L'APK release est signé avec la clé de debug.** Clé publique, partagée par
toutes les installations Flutter: n'importe qui peut fabriquer un APK
substituable à celui-ci lors d'une mise à jour, et hériter du répertoire privé
existant. *Pas corrigé* parce que changer de clé impose une désinstallation, donc
la perte du coffre si l'on n'exporte pas d'abord — et parce que le `key.properties`
correspondant ne peut venir que de toi. Le `TODO` du `build.gradle.kts` porte
maintenant cette conséquence, qu'il taisait.

**9. Normalisation Unicode.** `toLowerCase()` sans normalisation NFC: `café`
précomposé et `café` décomposé sont deux clefs distinctes, visuellement
identiques dans la liste, et chercher l'une ne trouve pas l'autre. *Pas corrigé*
parce que normaliser à la saisie change des clefs existantes: il faut décider
d'une migration, pas d'un patch.

**10. Nommage mixte français/anglais** des identifiants (`nouveau`, `courant`,
`transferDisponible` côtoient `_busy`, `_error`). *Pas corrigé*: c'est de la
préférence, la règle de cet audit étant qu'une modification doit se justifier par
un gain mesurable. Renommer produirait un gros diff sans un seul bug évité.

**11. Le générateur n'a pas de test déterministe.** Le paramètre
`generatePassword(random:)` existe pour ça, mais aucun test ne l'utilise: les
tests actuels sont statistiques. Le commentaire qui disait « n'existe que pour
les tests » était donc faux. *Pas corrigé* — c'est un test à écrire, pas un
défaut de production.

**12. Rien n'a été vérifié sur l'appareil** dans cette session. Les correctifs
Android — `allowBackup`, clavier, presse-papier hors focus — sont vérifiés par
le manifeste fusionné de l'APK et par des tests, pas par une manipulation sur
le Pixel. `FLAG_SECURE` l'avait été lors d'une session précédente.

**13. Le mot de passe maître ne m'a jamais été communiqué**, et je ne l'ai pas
demandé. Aucun test n'a donc été fait sur ton vrai coffre.

### Risques restants, par priorité

| Priorité | Risque | Où |
|---|---|---|
| 1 | Historique du presse-papier de Gboard: le secret survit à l'effacement | `lib/util/clipboard.dart` |
| 2 | Signature avec la clé de debug: substitution d'APK possible | `android/app/build.gradle.kts` |
| 3 | Gel de l'interface et risque d'ANR pendant Argon2id | `lib/state/vault_session.dart` |
| 4 | Fichiers `0644` sous Linux, lisibles par les autres comptes | `lib/storage/*.dart` |
| 5 | Clair non effaçable en mémoire (`String` Dart) | conception, documenté |
| 6 | Pas de restauration depuis `vault.safe.bak` | produit |
| 7 | Doublons Unicode invisibles dans les clefs | `lib/model/vault.dart` |
| 8 | Couverture faible sur `settings_screen` (41 %) et `attachments_section` (58 %) | tests |

### À toi de décider

1. **La licence.** Aucune n'est déclarée, ce qui vaut « tous droits réservés ».
   Le `README.md` le dit franchement plutôt que de combler d'office: le choix
   t'appartient. Si le dépôt reste privé et personnel, ne rien faire est une
   réponse valable.
2. **`vault.safe.bak`**: filet exposé à l'utilisateur, ou mécanisme supprimé ?
   En l'état il ne sert qu'à qui lit le code.
3. **La clé de release Android.** À faire un jour, avec un export du coffre
   avant, et en sachant que l'export ne contient pas les pièces jointes.
4. **Le message du commit `424cb55`**, écrit par un hook de sauvegarde
   automatique pendant une coupure. Je peux l'amender si tu veux un historique
   lisible — je ne touche pas à l'historique sans ton accord.
5. **Vérifier sur le téléphone** ce que je n'ai pu vérifier que par le manifeste
   et les tests: qu'une capture d'écran est bien refusée, que l'interrupteur des
   réglages la rétablit, et qu'après une mise à jour ton coffre est intact.
6. **`blobs/orphelins/`**: regarde s'il contient quelque chose après ta première
   mise à jour. S'il est vide, tant mieux; s'il ne l'est pas, ce sont des pièces
   jointes que l'ancien code aurait détruites.
