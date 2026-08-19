#!/usr/bin/env bash
# Télécharge les polices de l'interface et leurs licences.
#
# Elles sont embarquées dans le paquet, jamais chargées depuis le réseau: une
# application hors ligne ne doit appeler personne au démarrage. Ce script ne
# sert qu'à les régénérer; les fichiers obtenus sont versionnés.
#
#     bash tool/fetch_fonts.sh
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p assets/fonts

# L'API css2 rend du WOFF à un navigateur moderne et du TrueType à un client
# ancien. Flutter ne lit que le TrueType, d'où l'agent laissé tel quel.
css() {
  curl -sS --fail --max-time 60 -A "curl/7.68.0" \
    "https://fonts.googleapis.com/css2?family=$1"
}

fetch() {
  local url="$1" out="$2"
  echo "  $out"
  curl -sS --fail --max-time 60 -o "assets/fonts/$out" "$url"
}

mapfile -t sans < <(css "Instrument+Sans:wght@400;500;600" | grep -oE 'https://[^)]+\.ttf')
[ "${#sans[@]}" -eq 3 ] || { echo "Instrument Sans: 3 fichiers attendus, ${#sans[@]} reçus" >&2; exit 1; }
fetch "${sans[0]}" InstrumentSans-Regular.ttf
fetch "${sans[1]}" InstrumentSans-Medium.ttf
fetch "${sans[2]}" InstrumentSans-SemiBold.ttf

mapfile -t mono < <(css "JetBrains+Mono:wght@400;500" | grep -oE 'https://[^)]+\.ttf')
[ "${#mono[@]}" -eq 2 ] || { echo "JetBrains Mono: 2 fichiers attendus, ${#mono[@]} reçus" >&2; exit 1; }
fetch "${mono[0]}" JetBrainsMono-Regular.ttf
fetch "${mono[1]}" JetBrainsMono-Medium.ttf

# La licence SIL OFL exige que sa notice accompagne les fichiers.
curl -sS --fail --max-time 60 -o assets/fonts/OFL-InstrumentSans.txt \
  https://raw.githubusercontent.com/google/fonts/main/ofl/instrumentsans/OFL.txt
curl -sS --fail --max-time 60 -o assets/fonts/OFL-JetBrainsMono.txt \
  https://raw.githubusercontent.com/google/fonts/main/ofl/jetbrainsmono/OFL.txt

echo "Polices à jour dans assets/fonts/."
