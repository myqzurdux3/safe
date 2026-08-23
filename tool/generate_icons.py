#!/usr/bin/env python3
"""Génère les icônes de safe: le fermoir, sur fond vert.

C'est la même marque que celle dessinée à l'écran par `lib/ui/safe_logo.dart`
— deux équerres qui s'emboîtent sans se toucher, marque `C` de la planche `1a`
du handoff. Le lanceur et l'application montrent donc le même signe.

Le tracé est celui du handoff, dans un carré de 48:

    M32 7 H16 A9 9 0 0 0 7 16 V26      l'équerre du haut
    M16 41 H32 A9 9 0 0 0 41 32 V22    celle du bas

Sur le fond vert sombre du lanceur, les deux traits prennent la déclinaison
claire du handoff (`#7ee0a8` et `#eef2ef`) et non celle du fond clair: un
`#183a2b` sur `#255C42` serait un trait invisible.

Le dessin est vectoriel-par-calcul puis rendu en supersampling x4, ce qui donne
des bords nets à toutes les tailles sans dépendre d'un rasteriseur SVG.

    python3 tool/generate_icons.py

Écrit:
  android/app/src/main/res/mipmap-*/ic_launcher.png          (icône héritée)
  android/app/src/main/res/mipmap-*/ic_launcher_round.png    (variante ronde)
  android/app/src/main/res/mipmap-*/ic_launcher_foreground.png (icône adaptative)
  assets/icon/safe_512.png                                   (Linux, magasins)
"""

from __future__ import annotations

import math
import os
from PIL import Image, ImageDraw

SS = 4  # facteur de supersampling

# Vert de l'application (graine du thème Material), décliné en dégradé.
BG_TOP = (47, 111, 78)
BG_BOTTOM = (20, 62, 44)

# La déclinaison claire du fermoir, celle que le handoff pose sur fond sombre.
MARK_TOP = (126, 224, 168)  # #7ee0a8
MARK_BOTTOM = (238, 242, 239)  # #eef2ef

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(HERE, "android", "app", "src", "main", "res")

# Le carré de référence du tracé, et l'épaisseur du trait dedans.
BOX = 48.0
STROKE = 7.0

# Le signe déborde du tracé de la moitié du trait, de chaque côté: il va donc
# de 7 - 3.5 = 3.5 à 41 + 3.5 = 44.5, soit 41 unités de large.
SPAN = 41.0

LEGACY_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# L'icône adaptative fait 108 dp; seuls les 66 dp centraux sont toujours
# visibles, le reste peut être rogné par le masque du lanceur.
ADAPTIVE_SIZES = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}


def arc(cx, cy, r, start_deg, end_deg, steps=48):
    """Points d'un arc de cercle — PIL ne sait pas tracer de courbes.

    Les angles sont en degrés, dans le repère de l'image (y vers le bas), et
    l'arc va de `start_deg` à `end_deg` dans le sens du signe de la différence.
    """
    points = []
    for i in range(steps + 1):
        t = i / steps
        a = math.radians(start_deg + (end_deg - start_deg) * t)
        points.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return points


def upper_bracket():
    """`M32 7 H16 A9 9 0 0 0 7 16 V26`, en coordonnées du carré de 48."""
    # L'arc va du haut (270°) à la gauche (180°) du cercle centré en (16, 16).
    return [(32.0, 7.0)] + arc(16.0, 16.0, 9.0, 270.0, 180.0) + [(7.0, 26.0)]


def lower_bracket():
    """`M16 41 H32 A9 9 0 0 0 41 32 V22` — la même, tournée d'un demi-tour."""
    return [(16.0, 41.0)] + arc(32.0, 32.0, 9.0, 90.0, 0.0) + [(41.0, 22.0)]


def stroke(draw, points, color, width):
    """Trace une polyligne à bouts et jointures ronds.

    PIL n'a ni `stroke-linecap` ni `stroke-linejoin`: `draw.line(width=...)`
    pose un rectangle par segment et, avec `joint="curve"`, une ellipse par
    sommet — ce qui laisse des coutures visibles EN TRAVERS du trait, une par
    point d'échantillonnage de l'arc. Une brosse tamponnée le long du chemin
    n'a pas ce défaut: le disque est à la fois le bout, la jointure et le
    corps du trait.
    """
    r = width / 2
    step = 0.4  # en pixels du canevas supersamplé
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        n = max(int(math.hypot(x1 - x0, y1 - y0) / step), 1)
        for i in range(n + 1):
            t = i / n
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t
            draw.ellipse([x - r, y - r, x + r, y + r], fill=color)


def draw_mark(size, coverage):
    """Le fermoir seul, sur fond transparent.

    `coverage` est la part du canevas qu'occupe le signe, bord de trait
    compris — pas le tracé nu.
    """
    s = size * SS
    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    scale = coverage * s / SPAN

    def place(points):
        # Le centre du carré de 48 tombe sur le centre du canevas.
        return [(s / 2 + (x - BOX / 2) * scale, s / 2 + (y - BOX / 2) * scale) for x, y in points]

    stroke(draw, place(upper_bracket()), MARK_TOP, STROKE * scale)
    stroke(draw, place(lower_bracket()), MARK_BOTTOM, STROKE * scale)
    return layer.resize((size, size), Image.LANCZOS)


def gradient_background(size, radius_ratio=0.22, circular=False):
    s = size * SS
    gradient = Image.new("RGB", (s, s))
    draw = ImageDraw.Draw(gradient)
    for y in range(s):
        t = y / max(s - 1, 1)
        draw.line(
            [(0, y), (s, y)],
            fill=tuple(
                round(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3)
            ),
        )
    mask = Image.new("L", (s, s), 0)
    mask_draw = ImageDraw.Draw(mask)
    if circular:
        mask_draw.ellipse([0, 0, s - 1, s - 1], fill=255)
    else:
        mask_draw.rounded_rectangle(
            [0, 0, s - 1, s - 1], radius=s * radius_ratio, fill=255
        )
    background = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    background.paste(gradient, mask=mask)
    return background.resize((size, size), Image.LANCZOS)


def full_icon(size, circular=False):
    icon = gradient_background(size, circular=circular)
    icon.alpha_composite(draw_mark(size, coverage=0.56))
    return icon


def write(path, image):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)
    print(f"écrit {os.path.relpath(path, HERE)} ({image.width}px)")


def main():
    for folder, size in LEGACY_SIZES.items():
        write(os.path.join(RES, folder, "ic_launcher.png"), full_icon(size))
        write(
            os.path.join(RES, folder, "ic_launcher_round.png"),
            full_icon(size, circular=True),
        )
    for folder, size in ADAPTIVE_SIZES.items():
        # Le signe reste dans la zone sûre centrale (66/108 du canevas).
        write(
            os.path.join(RES, folder, "ic_launcher_foreground.png"),
            draw_mark(size, coverage=0.44),
        )
    for size in (512, 256, 128, 64):
        write(
            os.path.join(HERE, "assets", "icon", f"safe_{size}.png"),
            full_icon(size),
        )


if __name__ == "__main__":
    main()
