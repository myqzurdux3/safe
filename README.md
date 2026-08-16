# safe

Coffre clef/valeur chiffré, minimaliste, pour Android et Linux. L'utilisateur
enregistre des paires clef/valeur; tout est chiffré en bloc par un mot de passe
maître, et rien ne quitte l'appareil.

## Ce qu'il fait

- Créer un coffre protégé par un mot de passe maître
- Ajouter, modifier, supprimer, rechercher des entrées
- Valeurs sur plusieurs lignes (notes, clefs SSH, adresses)
- Joindre des photos et des documents, chiffrés un par fichier, 25 Mio maximum
- Générer des valeurs aléatoires (12 à 64 caractères), toute la ponctuation
  ASCII, avec au moins un caractère de chaque classe demandée
- Copier une valeur; le presse-papier est effacé 30 s plus tard
- Verrouiller automatiquement après inactivité (30 s à 5 min, 2 min par défaut).
  Le temps passé en arrière-plan compte comme de l'inactivité, mais changer
  d'application ne verrouille pas en soi. La frappe compte comme une activité,
  et le verrouillage ferme les écrans ouverts
- Exporter et importer le coffre chiffré, pour transférer entre appareils

Pas de compte, pas de serveur, pas de synchronisation automatique, pas de
remplissage de formulaires.

## Sécurité

| Élément | Choix |
|---|---|
| Dérivation de clé | Argon2id, 3 passes, 128 Mio, sel aléatoire de 16 octets |
| Chiffrement | XChaCha20-Poly1305 (AEAD), nonce de 24 octets tiré à chaque sauvegarde |
| Bibliothèque | libsodium, via `package:sodium` (FFI) |
| Portée du chiffrement | Le coffre entier: **les noms de clefs sont chiffrés eux aussi** |
| Pièces jointes | Un fichier chiffré par pièce (`blobs/<id>.blob`), nonce propre, identifiant aléatoire sans rapport avec le nom |
| Intégrité | L'en-tête en clair sert de données associées: le modifier invalide le tag |
| Écriture | Fichier temporaire, puis `rename` atomique, avec sauvegarde `.bak` |

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

- Linux: `$XDG_DATA_HOME/safe/vault.safe`, par défaut `~/.local/share/safe/`
- Android: dossier privé de l'application, inaccessible aux autres applications

À côté du coffre, `vault.safe.bak` conserve l'état précédant la dernière
sauvegarde, et `blobs/` contient les pièces jointes chiffrées.

## Transférer un coffre entre appareils

Réglages → **Exporter le coffre** produit le fichier chiffré tel quel. Il peut
transiter par n'importe quel canal, y compris peu sûr: sans le mot de passe il
est inexploitable. Sur l'autre appareil, Réglages → **Importer un coffre**
demande le mot de passe du fichier et vérifie qu'il l'ouvre **avant** de
remplacer le coffre existant, dont une copie part en `.bak`.

**L'export ne contient pas les pièces jointes**: elles vivent dans des fichiers
séparés et s'exportent une par une depuis l'entrée concernée. Un export en
archive unique reste à faire.

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

## Structure

```
lib/
  crypto/vault_crypto.dart   Argon2id, XChaCha20-Poly1305, format de fichier
  model/vault.dart           Entrées et sérialisation JSON
  storage/vault_store.dart   Interface de stockage
  storage/vault_file.dart    Fichier sur disque, écriture atomique
  storage/vault_transfer.dart Export et import vérifié
  storage/blob_store.dart    Pièces jointes chiffrées sur disque
  state/vault_session.dart   Verrouillé / déverrouillé, auto-lock
  ui/                        Verrou, liste, édition, réglages
  ui/safe_logo.dart          Logo vectoriel, dessiné au trait
  util/                      Générateur, presse-papier auto-effacé
tool/generate_icons.py       Génération des icônes Android et Linux
docs/superpowers/
  specs/2026-08-14-safe-design.md   Conception et modèle de menace
  plans/2026-08-14-safe.md          Plan d'implémentation
```
