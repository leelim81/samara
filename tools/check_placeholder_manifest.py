#!/usr/bin/env python3
"""Placeholder-manifest completeness check. Fails (exit 1) when:
  A. the manifest references an asset path that does not exist on disk, or
  B. a generated placeholder art file on disk is not documented in the manifest.

Covered generator output dirs (B): assets/ui/icons, assets/ui/status,
assets/ui/items, assets/terra/subjobs, assets/terra/awakened, plus the named
outputs of gen_battle_ui_art.py, gen_menu_border.py and gen_vfx_art.py that
live in shared directories.

Run from the project root:  python3 tools/check_placeholder_manifest.py
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MANIFEST = os.path.join(ROOT, "docs", "placeholder_art.md")

# Directories whose every image is a generated placeholder.
FULLY_GENERATED_DIRS = [
    "assets/ui/icons",
    "assets/ui/status",
    "assets/ui/items",
    "assets/terra/subjobs",
    "assets/terra/awakened",
]

# Generated files living in shared directories (listed explicitly).
NAMED_GENERATED = [
    # tools/gen_vfx_art.py
    "assets/vfx/fire_burst.png", "assets/vfx/ice_burst.png",
    "assets/vfx/lightning_burst.png", "assets/vfx/shadow_burst.png",
    "assets/vfx/slash_cut.png", "assets/vfx/thrust_streak.png",
    "assets/vfx/ricochet_star.png", "assets/vfx/arcane_glyph.png",
    # tools/gen_menu_border.py
    "assets/terra/ui/unit_player_border_menu.png",
    # tools/gen_battle_ui_art.py (gesture glyphs; the rest live in
    # assets/terra/ui and are covered by the battle-UI table check below)
    "assets/ui/click.png", "assets/ui/drag.png",
]

BATTLE_UI_DIR = "assets/terra/ui"
# Hand-authored (non-generated) files in assets/terra/ui, exempt from B.
BATTLE_UI_HAND_AUTHORED = {
    "panel_card.png", "splash.png", "ui_icons.png",
    "stat_atk.png", "stat_def.png", "stat_satk.png", "stat_sdef.png",
}


def main():
    text = open(MANIFEST).read()
    referenced = set(re.findall(r"`(assets/[^`]+?\.(?:png|webp))`", text))

    problems = []

    # A. Every referenced path exists.
    for rel in sorted(referenced):
        if not os.path.exists(os.path.join(ROOT, rel)):
            problems.append("A missing on disk: %s" % rel)

    # B. Every generated file is documented.
    undocumented = []

    def check_documented(rel):
        if rel not in referenced:
            undocumented.append(rel)

    for d in FULLY_GENERATED_DIRS:
        full = os.path.join(ROOT, d)
        for name in sorted(os.listdir(full)):
            if name.endswith((".png", ".webp")):
                check_documented("%s/%s" % (d, name))

    for rel in NAMED_GENERATED:
        if os.path.exists(os.path.join(ROOT, rel)):
            check_documented(rel)
        else:
            problems.append("B expected generated file missing: %s" % rel)

    full = os.path.join(ROOT, BATTLE_UI_DIR)
    for name in sorted(os.listdir(full)):
        if name.endswith((".png", ".webp")) and name not in BATTLE_UI_HAND_AUTHORED:
            check_documented("%s/%s" % (BATTLE_UI_DIR, name))

    for rel in undocumented:
        problems.append("B undocumented placeholder: %s" % rel)

    if problems:
        print("MANIFEST CHECK FAILED (%d problems)" % len(problems))
        for p in problems:
            print("  " + p)
        sys.exit(1)

    print("manifest check OK: %d referenced paths, all generated art documented"
            % len(referenced))


main()
