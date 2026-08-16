# Rebuild et réinstallation

Tout part de la racine du dépôt. Aucune de ces commandes ne touche au coffre:
les données vivent hors du dépôt, et une mise à jour par-dessus les conserve.

## Avant de publier quoi que ce soit

```bash
flutter test        # doit finir par "All tests passed!"
flutter analyze     # doit finir par "No issues found!"
```

## Android

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

`-r` = mise à jour par-dessus. **Le coffre est conservé.** Ne jamais utiliser
`adb uninstall` ni `adb install` sans `-r`: désinstaller efface le répertoire
privé de l'app, donc le coffre et les pièces jointes, sans confirmation.

Vérifier que c'est bien la nouvelle version:

```bash
adb devices                                          # téléphone visible ?
adb shell dumpsys package dev.safe.safe | grep lastUpdateTime
```

L'APK est signé avec la clé de debug. Conséquence: une future signature avec
une vraie clé de release sera refusée en mise à jour et **imposera une
désinstallation, donc la perte du coffre**. Exporter le coffre avant ce
changement (Réglages → Exporter).

## Linux

```bash
flutter build linux --release
```

Le résultat est un dossier autonome, pas un seul fichier: `safe` a besoin des
dossiers `lib/` et `data/` posés à côté de lui.

Lancer sans installer:

```bash
./build/linux/x64/release/bundle/safe
```

Installer pour l'utilisateur courant (aucun `sudo`):

```bash
rm -rf ~/.local/lib/safe
mkdir -p ~/.local/lib/safe ~/.local/bin ~/.local/share/applications ~/.local/share/icons/hicolor/256x256/apps
cp -r build/linux/x64/release/bundle/. ~/.local/lib/safe/
ln -sf ~/.local/lib/safe/safe ~/.local/bin/safe
cp assets/icon/safe_256.png ~/.local/share/icons/hicolor/256x256/apps/safe.png

cat > ~/.local/share/applications/safe.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=safe
Comment=Coffre clef/valeur chiffré
Exec=/home/user/.local/bin/safe
Icon=safe
Terminal=false
Categories=Utility;Security;
EOF

update-desktop-database ~/.local/share/applications 2>/dev/null || true
```

`Exec=` doit être un chemin absolu: beaucoup de lanceurs ignorent `~` et
n'héritent pas du `PATH` du shell.

Ensuite: `safe` en ligne de commande, ou l'entrée « safe » du menu.

Mettre à jour plus tard = rejouer le bloc ci-dessus. Le `rm -rf` ne vise que
le dossier du programme, jamais les données.

Désinstaller:

```bash
rm -rf ~/.local/lib/safe ~/.local/bin/safe \
       ~/.local/share/applications/safe.desktop \
       ~/.local/share/icons/hicolor/256x256/apps/safe.png
```

## Où vivent les données

| Plateforme | Coffre |
|---|---|
| Linux | `~/.local/share/safe/` (`vault.safe`, `vault.safe.bak`, `blobs/`) |
| Android | répertoire privé de l'app, illisible sans root |

Sauvegarde Linux: copier tout le dossier `~/.local/share/safe/`. Le contenu
est chiffré, une copie sur clé USB ou disque externe ne l'expose pas.

Android n'offre aucun accès à ces fichiers (`adb pull` échoue, l'app n'est pas
debuggable — c'est voulu). La seule sauvegarde possible est Réglages →
Exporter. **L'export ne contient pas les pièces jointes**, à exporter une par
une.

## En cas de problème

```bash
flutter clean && flutter pub get
```

Puis relancer la compilation. `flutter clean` supprime `build/`, jamais les
coffres.
