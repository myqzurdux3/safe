#!/usr/bin/env python3
"""Génère les icônes de safe: bouclier clair, serrure évidée, fond vert.

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

import os
from PIL import Image, ImageDraw

SS = 4  # facteur de supersampling

# Vert de l'application (graine du thème Material), décliné en dégradé.
BG_TOP = (47, 111, 78)
BG_BOTTOM = (20, 62, 44)
SHIELD = (242, 251, 245)

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(HERE, "android", "app", "src", "main", "res")

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


def quadratic(p0, p1, p2, steps=64):
    """Points d'une bézier quadratique — PIL ne sait pas tracer de courbes."""
    points = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        points.append(
            (
                u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
                u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1],
            )
        )
    return points


def shield_polygon(cx, cy, w, h):
    """Silhouette du bouclier: épaules droites, flancs qui filent vers la pointe."""
    left = cx - w / 2
    right = cx + w / 2
    top = cy - h / 2
    bottom = cy + h / 2
    shoulder = top + h * 0.40  # là où les flancs commencent à se resserrer
    corner = w * 0.30

    points = [(left + corner, top)]
    points += quadratic((left + corner, top), (left, top), (left, top + corner))
    points.append((left, shoulder))
    # Flanc gauche vers la pointe basse.
    points += quadratic(
        (left, shoulder), (left + w * 0.02, bottom - h * 0.22), (cx, bottom)
    )
    # Flanc droit, en remontant.
    points += quadratic(
        (cx, bottom), (right - w * 0.02, bottom - h * 0.22), (right, shoulder)
    )
    points.append((right, top + corner))
    points += quadratic((right, top + corner), (right, top), (right - corner, top))
    return points


def keyhole_polygon(cx, cy, w, h):
    """Tige de la serrure: un trapèze qui s'évase vers le bas."""
    top_half = w * 0.30
    bottom_half = w * 0.62
    return [
        (cx - top_half, cy),
        (cx + top_half, cy),
        (cx + bottom_half, cy + h),
        (cx - bottom_half, cy + h),
    ]


def draw_shield(size, coverage):
    """Bouclier seul, serrure évidée (alpha nul), sur fond transparent."""
    s = size * SS
    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    w = s * coverage
    h = w * 1.22
    cx, cy = s / 2, s / 2
    draw.polygon(shield_polygon(cx, cy, w, h), fill=SHIELD)

    # Serrure: disque + tige, percés dans le bouclier.
    hole = Image.new("L", (s, s), 0)
    hole_draw = ImageDraw.Draw(hole)
    r = w * 0.165
    hole_cy = cy - h * 0.07
    hole_draw.ellipse(
        [cx - r, hole_cy - r, cx + r, hole_cy + r], fill=255
    )
    hole_draw.polygon(
        keyhole_polygon(cx, hole_cy + r * 0.30, r * 1.30, h * 0.24), fill=255
    )
    alpha = layer.getchannel("A")
    alpha.paste(0, mask=hole)
    layer.putalpha(alpha)
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
    icon.alpha_composite(draw_shield(size, coverage=0.56))
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
        # Le bouclier reste dans la zone sûre centrale (66/108 du canevas).
        write(
            os.path.join(RES, folder, "ic_launcher_foreground.png"),
            draw_shield(size, coverage=0.40),
        )
    for size in (512, 256, 128, 64):
        write(
            os.path.join(HERE, "assets", "icon", f"safe_{size}.png"),
            full_icon(size),
        )


if __name__ == "__main__":
    main()
