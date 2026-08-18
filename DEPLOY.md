# Rebuild et réinstallation

Tout part de la racine du dépôt. Aucune de ces commandes ne touche au coffre:
les données vivent hors du dépôt, et une mise à jour par-dessus les conserve.

## Avant de publier quoi que ce soit

```bash
dart format --output=none --set-exit-if-changed lib test   # ne doit rien signaler
flutter analyze     # doit finir par "No issues found!"
flutter test        # doit finir par "All tests passed!"
```

La vérification continue (`.github/workflows/ci.yml`) joue exactement ces trois
commandes, puis compile les deux cibles.

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

# Sans quotes autour du délimiteur, pour que $HOME soit substitué.
cat > ~/.local/share/applications/safe.desktop <<EOF
[Desktop Entry]
Type=Application
Name=safe
Comment=Coffre clef/valeur chiffré
Exec=$HOME/.local/bin/safe
Icon=safe
Terminal=false
Categories=Utility;Security;
Keywords=mot de passe;coffre;chiffrement;
EOF

update-desktop-database ~/.local/share/applications 2>/dev/null || true
```

`Exec=` doit être un chemin absolu: beaucoup de lanceurs ignorent `~` et
n'héritent pas du `PATH` du shell. C'est pourquoi ce bloc ne réutilise pas
`linux/packaging/safe.desktop`, qui contient `Exec=safe` — bon pour une
installation système où le binaire est dans le `PATH`, insuffisant ici.

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
| Linux | `~/.local/share/safe/` (`vault.safe`, `vault.safe.bak`, `blobs/`, `blobs/orphelins/`, `settings.json`) |
| Android | répertoire privé de l'app, illisible sans root |

`blobs/orphelins/` reçoit les pièces jointes qu'aucune entrée ne référence plus
— typiquement après un import, qui remplace le coffre entier. Elles restent
chiffrées; les effacer est sans risque une fois qu'on est sûr de ne plus en
vouloir.

Sauvegarde Linux: copier tout le dossier `~/.local/share/safe/`. Le coffre et
les pièces jointes sont chiffrés, une copie sur clé USB ou disque externe ne
les expose pas. Seul `settings.json` est en clair: il ne contient que des
préférences (blocage des captures d'écran, délai de verrouillage), aucun
secret. Le supprimer fait repartir sur les valeurs par défaut, qui sont les
plus protectrices.

Côté Android, ces fichiers ne sortent pas de l'appareil:

- `adb pull` échoue sur le répertoire privé: il n'est lisible que pour une
  application debuggable, ce qu'un build release n'est pas. C'est le
  comportement par défaut de Gradle en release, pas une option posée dans ce
  dépôt — donc à ne pas confondre avec une garantie que le dépôt contrôle.
- la sauvegarde automatique d'Android est **désactivée explicitement**
  (`android:allowBackup="false"` et des règles d'extraction vides dans
  `android/app/src/main/res/xml/backup_rules.xml`). Sans cela, Auto Backup
  couvrait le répertoire privé, et le coffre comme les pièces jointes partaient
  vers Google Drive et le transfert d'appareil à appareil.

La seule sauvegarde possible est donc Réglages → Exporter. **L'export ne
contient pas les pièces jointes**, à exporter une par une.

Pour vérifier soi-même, sur un appareil branché:

```bash
adb shell dumpsys package dev.safe.safe | grep -i 'flags\|allowBackup'
```

## En cas de problème

```bash
flutter clean && flutter pub get
```

Puis relancer la compilation. `flutter clean` supprime `build/`, jamais les
coffres.
