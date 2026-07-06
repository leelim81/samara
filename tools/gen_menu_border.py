#!/usr/bin/env python3
"""Generate a CRISP jade frame for the collection/squad unit thumbnails.

The in-battle border (assets/terra/ui/unit_player_border.png) carries a wide
soft glow so tiles pop against the field. On the dark menu cards that halo
reads as a faint SECOND frame around the portrait. This authors a tight,
single-line jade frame with almost no bloom so the portrait sits in one clean
border. Run from the project root:

    python3 tools/gen_menu_border.py
"""
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TERRA = os.path.join(ROOT, "assets", "terra", "ui")
SS = 4

ALLY_CYAN = (70, 211, 168)
ALLY_CYAN_HI = (150, 240, 212)


def menu_border(px=98, radius=16):
    s = (px * SS, px * SS)
    r = radius * SS
    inset = 2 * SS
    stroke = round(2.5 * SS)

    box = [inset, inset, s[0] - 1 - inset, s[1] - 1 - inset]

    img = Image.new("RGBA", s, (0, 0, 0, 0))

    # A hair of bloom kept TIGHT (single short blur) so it never reads as a
    # separate outer ring the way the battle border's wide halo does.
    glow = Image.new("RGBA", s, (0, 0, 0, 0))
    ImageDraw.Draw(glow).rounded_rectangle(box, radius=r, outline=ALLY_CYAN + (200,),
                                           width=stroke + SS)
    glow = glow.filter(ImageFilter.GaussianBlur(SS * 0.9))
    img = Image.alpha_composite(img, glow)

    d = ImageDraw.Draw(img)
    # crisp jade edge
    d.rounded_rectangle(box, radius=r, outline=ALLY_CYAN + (255,), width=stroke)
    # thin glassy inner highlight just inside the edge
    d.rounded_rectangle([box[0] + stroke, box[1] + stroke, box[2] - stroke, box[3] - stroke],
                        radius=max(1, r - stroke), outline=ALLY_CYAN_HI + (150,), width=max(1, SS // 2))

    img = img.resize((px, px), Image.LANCZOS)
    out = os.path.join(TERRA, "unit_player_border_menu.png")
    img.save(out)
    print("wrote", out)


if __name__ == "__main__":
    menu_border()
