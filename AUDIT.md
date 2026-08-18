# Audit de `safe`

Audit mené le 2026-08-18 sur `master` à partir du commit `f654a5b`.

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

