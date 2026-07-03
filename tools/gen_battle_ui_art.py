#!/usr/bin/env python3
"""Generate the Terra-Battle-parity battle-UI texture set (Hybrid: dark field + gold HUD).

Repaints existing textures IN PLACE at their exact current dimensions (so the
code-pinned geometry and portrait-clip masks stay valid) and authors a few new
ones. Run from the project root:

    python3 tools/gen_battle_ui_art.py

Backs up every file it overwrites to /tmp/ui_backup/ first. Everything is drawn
at 4x supersample and downscaled with LANCZOS for crisp edges. No external deps
beyond Pillow (numpy used only if present, for the vignette).
"""
import os
import shutil

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TERRA = os.path.join(ROOT, "assets", "terra", "ui")
BACKUP = "/tmp/ui_backup"
SS = 4  # supersample factor

os.makedirs(BACKUP, exist_ok=True)

# ---- palette (RGBA 0-255) --------------------------------------------------
ALLY_CYAN      = (70, 211, 168)
ALLY_CYAN_HI   = (150, 240, 212)
ENEMY_RED      = (226, 85, 58)
ENEMY_RED_HI   = (255, 168, 148)
BOSS_GOLD      = (255, 168, 72)
BOSS_GOLD_HI   = (255, 224, 150)
TILE_TOP       = (42, 50, 60)
TILE_BOT       = (26, 32, 41)
TILE_RIM       = (140, 158, 170, 95)
HP_TOP         = (104, 200, 150)
HP_BOT         = (52, 148, 108)
HP_ENEMY_TOP   = (238, 122, 88)
HP_ENEMY_BOT   = (176, 58, 38)
HP_TRACK       = (15, 21, 28)
HP_TRACK_RIM   = (44, 56, 70)
GOLD_TOP       = (255, 226, 134)
GOLD_BOT       = (222, 170, 70)
GAUGE_TRACK    = (60, 70, 84)
GAUGE_TRACK_RIM= (92, 106, 122)
GRID_LINE      = (208, 222, 230, 28)
GRID_FRAME     = (90, 200, 168, 75)
PLATE_DARK     = (11, 14, 20, 235)
PLATE_RIM      = (206, 118, 92, 170)  # warm vermilion rim: countdown = enemy signal


def _save(img, name, size):
    """Downscale to target size and write, backing up any existing file."""
    path = os.path.join(TERRA, name)
    if os.path.exists(path):
        shutil.copy2(path, os.path.join(BACKUP, name))
    img = img.resize(size, Image.LANCZOS)
    img.save(path)
    print("  wrote %-30s %s" % (name, size))


def _vgrad(size, top, bot):
    """Vertical gradient RGBA image at supersample size."""
    w, h = size
    g = Image.new("RGBA", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,))
    return g.resize((w, h))


def _rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


# --- tiles ------------------------------------------------------------------
def tile(name, px, radius):
    s = (px * SS, px * SS)
    r = radius * SS
    grad = _vgrad(s, TILE_TOP, TILE_BOT)
    grad.putalpha(_rounded_mask(s, r))
    d = ImageDraw.Draw(grad)
    # subtle inner rim-light just inside the rounded edge
    d.rounded_rectangle([SS, SS, s[0] - 1 - SS, s[1] - 1 - SS], radius=max(1, r - SS),
                        outline=TILE_RIM, width=SS)
    # gentle top sheen
    sheen = Image.new("RGBA", s, (0, 0, 0, 0))
    ImageDraw.Draw(sheen).rounded_rectangle([0, 0, s[0] - 1, int(s[1] * 0.42)], radius=r,
                                            fill=(255, 255, 255, 16))
    sheen.putalpha(Image.composite(sheen.split()[3], Image.new("L", s, 0), _rounded_mask(s, r)))
    grad = Image.alpha_composite(grad, sheen)
    _save(grad, name, (px, px))


# --- luminous glow rim (visible on the parchment field, not a hard border) ---
def border(name, px, radius, color, hi):
    s = (px * SS, px * SS)
    r = radius * SS
    rim = round(2.0 * SS)               # ~2px bright edge (reads as glow, not a slab)
    inset = SS
    # a wide bright ring, blurred, then layered for a strong luminous halo that
    # stands out against the cream battlefield
    ring = Image.new("RGBA", s, (0, 0, 0, 0))
    ImageDraw.Draw(ring).rounded_rectangle([inset, inset, s[0] - 1 - inset, s[1] - 1 - inset],
                                           radius=r, outline=color + (255,), width=rim + SS * 3)
    glow = ring.filter(ImageFilter.GaussianBlur(SS * 2.4))
    img = Image.new("RGBA", s, (0, 0, 0, 0))
    img = Image.alpha_composite(img, glow)
    img = Image.alpha_composite(img, glow)      # double pass = brighter, visible glow
    d = ImageDraw.Draw(img)
    # bright luminous rim
    d.rounded_rectangle([inset, inset, s[0] - 1 - inset, s[1] - 1 - inset],
                        radius=r, outline=color + (255,), width=rim)
    # glassy inner highlight
    d.rounded_rectangle([inset + rim, inset + rim, s[0] - 1 - inset - rim, s[1] - 1 - inset - rim],
                        radius=max(1, r - rim), outline=hi + (170,), width=max(1, SS // 2))
    _save(img, name, (px, px))


# --- horizontal rounded bar (nine-patch friendly) ---------------------------
def bar(name, px, top, bot, rim=None):
    w, h = px
    s = (w * SS, h * SS)
    r = (h * SS) // 2 - SS
    grad = _vgrad(s, top, bot)
    grad.putalpha(_rounded_mask(s, r))
    if rim:
        ImageDraw.Draw(grad).rounded_rectangle([0, 0, s[0] - 1, s[1] - 1], radius=r,
                                               outline=rim + (255,), width=SS)
    # top sheen line
    ImageDraw.Draw(grad).line([(r, SS), (s[0] - r, SS)], fill=(255, 255, 255, 70), width=SS)
    _save(grad, name, px)


# --- grid -------------------------------------------------------------------
def grid(name):
    W, H, cols, rows, t = 602, 802, 6, 8, 100
    s = (W * SS, H * SS)
    img = Image.new("RGBA", s, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    lw = max(1, SS)
    for i in range(cols + 1):
        x = (1 + i * t) * SS
        d.line([(x, SS), (x, (H - 1) * SS)], fill=GRID_LINE, width=lw)
    for j in range(rows + 1):
        y = (1 + j * t) * SS
        d.line([(SS, y), ((W - 1) * SS, y)], fill=GRID_LINE, width=lw)
    # brighter outer frame
    d.rounded_rectangle([SS, SS, (W - 1) * SS, (H - 1) * SS], radius=3 * SS,
                        outline=GRID_FRAME, width=max(1, round(1.5 * SS)))
    _save(img, name, (W, H))


# --- vignette ---------------------------------------------------------------
def vignette(name):
    W, H = 720, 960
    try:
        import numpy as np
        yy, xx = np.mgrid[0:H, 0:W]
        cx, cy = W / 2, H / 2
        d = np.sqrt(((xx - cx) / cx) ** 2 + ((yy - cy) / cy) ** 2)
        a = np.clip((d - 0.55) / 0.75, 0, 1) ** 1.6 * 120
        out = np.zeros((H, W, 4), dtype=np.uint8)
        out[..., 3] = a.astype(np.uint8)
        Image.fromarray(out, "RGBA").save(os.path.join(TERRA, name))
        print("  wrote %-30s %s" % (name, (W, H)))
    except Exception:
        m = Image.new("L", (W, H), 0)
        dd = ImageDraw.Draw(m)
        dd.ellipse([-W * 0.25, -H * 0.25, W * 1.25, H * 1.25], fill=255)
        m = m.filter(ImageFilter.GaussianBlur(120)).point(lambda v: 120 - int(v * 120 / 255))
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        img.putalpha(m)
        img.save(os.path.join(TERRA, name))
        print("  wrote %-30s %s (fallback)" % (name, (W, H)))


# --- countdown plate (dark rounded badge) -----------------------------------
def countdown_plate(name, px=44):
    s = (px * SS, px * SS)
    r = 12 * SS
    img = Image.new("RGBA", s, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([SS, SS, s[0] - 1 - SS, s[1] - 1 - SS], radius=r, fill=PLATE_DARK)
    d.rounded_rectangle([SS, SS, s[0] - 1 - SS, s[1] - 1 - SS], radius=r, outline=PLATE_RIM, width=SS)
    _save(img, name, (px, px))


# --- vendored weapon glyphs (game-icons.net, CC BY 3.0) ----------------------
def vendored_weapons():
    """Three base weapon glyphs are processed game-icons.net art
    (broadsword/wizard-staff by Lorc, pistol by John Colburn, CC BY 3.0 —
    see tools/gameicons/). The spear is drawn by spear_glyph() below in the
    same style, mirroring the original TB icon's diagonal leaf-head spear
    (no game-icons spear reads as a plain spear at HUD size). Copy the
    processed 128px PNGs into the game so a full regen never clobbers them."""
    src_dir = os.path.join(ROOT, "tools", "gameicons")
    for name in ("sword", "gun", "staff"):
        src = os.path.join(src_dir, "%s.png" % name)
        img = Image.open(src).convert("RGBA")
        _save(img, "%s.png" % name, img.size)
    spear_glyph()


def spear_glyph(px=128):
    """Diagonal spear like the original TB glyph — long shaft, leaf-shaped
    head, binding collar — drawn at the new icon family's weight. Written to
    tools/gameicons/spear.png (canonical source) and installed like the rest."""
    s = (px * SS, px * SS)
    img = Image.new("RGBA", s, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    W = (255, 255, 255, 255)
    u = SS

    # Axis runs bottom-left grip -> top-right head, like TB's original
    d.line([(22 * u, 106 * u), (84 * u, 44 * u)], fill=W, width=8 * u)
    # Butt cap
    d.ellipse([(18 * u, 102 * u), (28 * u, 112 * u)], fill=W)
    # Binding collar where the head is socketed
    d.ellipse([(76 * u, 38 * u), (92 * u, 54 * u)], fill=W)

    # Leaf head: kite polygon along the axis, tip at the top-right corner
    tip = (114 * u, 14 * u)
    base = (80 * u, 48 * u)
    mid = ((tip[0] + base[0] * 2) // 3, (tip[1] + base[1] * 2) // 3)
    half_w = 13 * u
    # perpendicular of the (1,-1) axis is (1,1)/sqrt2 ~= (0.707, 0.707)
    p = int(half_w * 0.707)
    d.polygon([
        tip,
        (mid[0] + p, mid[1] + p),
        base,
        (mid[0] - p, mid[1] - p),
    ], fill=W)

    out_path = os.path.join(ROOT, "tools", "gameicons", "spear.png")
    img_small = img.resize((px, px), Image.LANCZOS)
    img_small.save(out_path)
    _save(img, "spear.png", (px, px))


# --- weapon-advantage arrow (Circle of Carnage HUD diagram) ------------------
def advantage_arrow(name, px=18):
    """Small right chevron between weapon glyphs in the HUD triangle."""
    s = (px * SS, px * SS)
    img = Image.new("RGBA", s, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    W = (255, 255, 255, 235)
    u = SS
    d.polygon([(5 * u, 2 * u), (14 * u, 9 * u), (5 * u, 16 * u),
               (8 * u, 9 * u)], fill=W)
    _save(img, name, (px, px))


# --- Circle of Carnage ring (TB-style: 3 icons threaded on a loop) ----------
def carnage_ring(name, w=150, h=36):
    """Background for the HUD's weapon-advantage circle, drawn like TB's:
    a flattened loop whose line sweeps under the icons and wraps at both
    ends, with a small chevron ahead of each of the three icon slots.
    Battle.gd overlays the weapon glyphs at slot centers x = 42 / 78 / 114
    (y center 15 at 1x) reading the chain from Enums.WEAPON_RELATIONSHIPS,
    so the order stays engine-driven."""
    C = (226, 228, 232, 210)  # pale line, like the reference
    s = (w * SS, h * SS)
    img = Image.new("RGBA", s, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = SS

    # The loop: under-line sweeping the full row, wrapping up at both ends
    d.arc([4 * u, 6 * u, 26 * u, 32 * u], start=90, end=245, fill=C, width=2 * u)
    d.arc([124 * u, 6 * u, 146 * u, 32 * u], start=295, end=90, fill=C, width=2 * u)
    d.line([(15 * u, 32 * u), (135 * u, 32 * u)], fill=C, width=2 * u)

    # A chevron ahead of each icon slot
    for cx in (27, 63, 99):
        d.polygon([
            ((cx - 4) * u, 8 * u),
            ((cx + 3) * u, 15 * u),
            ((cx - 4) * u, 22 * u),
            ((cx - 2) * u, 15 * u),
        ], fill=C)

    _save(img, name, (w, h))


# --- outlined weapon badges (battle-card overlays, TB-style spill-out) ------
def weapon_badges():
    """TB's card weapon icons overhang the tile and survive any backdrop
    because they carry a dark outline. Build <name>_badge.png from each base
    glyph: near-black dilated outline + soft shadow under the white glyph.
    Regenerates from the plain glyphs, so re-running never fattens the rim."""
    for name in ("sword", "gun", "spear", "staff"):
        src = os.path.join(TERRA, "%s.png" % name)
        glyph = Image.open(src).convert("RGBA")
        alpha = glyph.split()[3]

        # Outline = alpha dilated a few px, painted dark
        rim = alpha.filter(ImageFilter.MaxFilter(7))
        outline = Image.new("RGBA", glyph.size, (0, 0, 0, 0))
        outline.paste((16, 18, 24, 255), mask=rim)

        # Soft drop shadow for lift off busy art
        shadow = Image.new("RGBA", glyph.size, (0, 0, 0, 0))
        shadow.paste((0, 0, 0, 140), mask=rim)
        shadow = shadow.filter(ImageFilter.GaussianBlur(4))

        img = Image.new("RGBA", glyph.size, (0, 0, 0, 0))
        img.alpha_composite(shadow, (2, 3))
        img.alpha_composite(outline)
        img.alpha_composite(glyph)
        _save(img, "%s_badge.png" % name, glyph.size)


# --- drag-mode gesture glyphs (assets/ui/, white, tinted at use sites) ------
def _save_abs(img, abspath, size):
    """Like _save but for files outside assets/terra/ui/."""
    if os.path.exists(abspath):
        shutil.copy2(abspath, os.path.join(BACKUP, os.path.basename(abspath)))
    img = img.resize(size, Image.LANCZOS)
    img.save(abspath)
    print("  wrote %-30s %s" % (abspath, size))


def _gesture_finger(d):
    """Shared pointing-finger silhouette (128-space): index finger + fist."""
    W = (255, 255, 255, 255)
    d.rounded_rectangle([52, 34, 70, 88], radius=9, fill=W)      # index finger
    d.rounded_rectangle([52, 76, 98, 112], radius=18, fill=W)    # folded hand


def gesture_glyphs(px=32):
    """Replace the desktop-mouse drag-mode icons with device-neutral gesture
    glyphs: tap ripples = click-to-move, motion arrow = hold-to-drag. Same
    finger silhouette in both so they read as two states of one control."""
    W = (255, 255, 255, 255)
    s = (px * SS, px * SS)

    # click.png — pointing finger with tap ripples above the fingertip
    img = Image.new("RGBA", s, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    _gesture_finger(d)
    for r in (20, 34):
        d.arc([61 - r, 30 - r, 61 + r, 30 + r], start=185, end=355, fill=W, width=8)
    _save_abs(img, os.path.join(ROOT, "assets", "ui", "click.png"), (px, px))

    # drag.png — same finger with a bold rightward motion arrow
    img = Image.new("RGBA", s, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    _gesture_finger(d)
    d.rounded_rectangle([28, 16, 88, 28], radius=6, fill=W)      # arrow shaft
    d.polygon([(86, 6), (86, 38), (110, 22)], fill=W)            # arrow head
    _save_abs(img, os.path.join(ROOT, "assets", "ui", "drag.png"), (px, px))


# --- attribute corner triangle (white, tinted in code) ----------------------
def attr_triangle(name, px=16):
    s = (px * SS, px * SS)
    img = Image.new("RGBA", s, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(0, s[1] - 1), (s[0] - 1, s[1] - 1), (s[0] - 1, 0)], fill=(255, 255, 255, 255))
    d.line([(0, s[1] - 1), (s[0] - 1, 0)], fill=(255, 255, 255, 255), width=SS)
    _save(img, name, (px, px))


# --- weapon chevron backing (corner pennant, white, tinted in code) ---------
def chevron(name, px=32):
    s = (px * SS, px * SS)
    img = Image.new("RGBA", s, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # top-right anchored triangle tab
    d.polygon([(0, 0), (s[0] - 1, 0), (s[0] - 1, s[1] - 1)], fill=(255, 255, 255, 255))
    _save(img, name, (px, px))


def main():
    print("Generating battle-UI art (backups -> %s):" % BACKUP)
    tile("unit_square_bg.png", 98, 16)
    tile("unit_square_bg_2x2.png", 196, 30)
    border("unit_player_border.png", 98, 16, ALLY_CYAN, ALLY_CYAN_HI)
    border("enemy_border.png", 98, 16, ENEMY_RED, ENEMY_RED_HI)
    border("enemy_border_2x2.png", 196, 30, ENEMY_RED, ENEMY_RED_HI)
    border("boss_border.png", 98, 16, BOSS_GOLD, BOSS_GOLD_HI)
    border("boss_border_2x2.png", 196, 30, BOSS_GOLD, BOSS_GOLD_HI)
    bar("hp_bar_fill.png", (104, 8), HP_TOP, HP_BOT)
    bar("hp_bar_fill_enemy.png", (104, 8), HP_ENEMY_TOP, HP_ENEMY_BOT)
    bar("hp_bar_bg.png", (104, 8), HP_TRACK, HP_TRACK, rim=HP_TRACK_RIM)
    weapon_badges()
    bar("bar_fill.png", (119, 16), GOLD_TOP, GOLD_BOT)
    bar("bar_bg.png", (119, 16), GAUGE_TRACK, GAUGE_TRACK, rim=GAUGE_TRACK_RIM)
    grid("grid.png")
    vignette("battle_vignette.png")
    countdown_plate("countdown_plate.png")
    vendored_weapons()
    advantage_arrow("advantage_arrow.png")
    carnage_ring("carnage_ring.png")
    gesture_glyphs()
    attr_triangle("attr_triangle.png")
    chevron("chevron_marker.png")
    print("Done.")


if __name__ == "__main__":
    main()
