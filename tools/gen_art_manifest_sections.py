#!/usr/bin/env python3
# Appends three sections to docs/placeholder_art.md covering every generated
# art file that was not yet documented: battle UI textures, button icons, and
# battle VFX. Idempotent per section (skips a section whose marker exists).
#   python3 tools/gen_art_manifest_sections.py
import os

ROOT = os.path.join(os.path.dirname(__file__), "..")
MANIFEST = os.path.join(ROOT, "docs", "placeholder_art.md")

BATTLE_UI = """
## Battle UI textures (tools/gen_battle_ui_art.py)
The battle HUD and board are skinned by procedurally generated textures (dark field, gold HUD). Real art should keep each file's exact dimensions (code pins the geometry) and transparent background where present, overwrite the file at *Path*, then re-run `godot --headless --import`. Regenerate the whole set anytime with `python3 tools/gen_battle_ui_art.py`.

| Path | Description |
| --- | --- |
| `assets/terra/ui/grid.png` | The 6x8 board grid overlay: thin pale lines with a jade frame. |
| `assets/terra/ui/unit_square_bg.png` | Tile plate behind a 1x1 unit token. |
| `assets/terra/ui/unit_square_bg_2x2.png` | Tile plate behind a 2x2 boss token. |
| `assets/terra/ui/unit_player_border.png` | Jade rim marking a player unit's tile. |
| `assets/terra/ui/enemy_border.png` | Vermilion rim marking an enemy tile. |
| `assets/terra/ui/enemy_border_2x2.png` | Vermilion rim for 2x2 enemies. |
| `assets/terra/ui/boss_border.png` | Gold rim marking a boss tile. |
| `assets/terra/ui/boss_border_2x2.png` | Gold rim for 2x2 bosses. |
| `assets/terra/ui/hp_bar_bg.png` | Small HP bar track under every token. |
| `assets/terra/ui/hp_bar_fill.png` | Player HP fill (jade gradient). |
| `assets/terra/ui/hp_bar_fill_enemy.png` | Enemy HP fill (vermilion gradient). |
| `assets/terra/ui/bar_bg.png` | Power Gauge track in the HUD. |
| `assets/terra/ui/bar_fill.png` | Power Gauge gold fill. |
| `assets/terra/ui/carnage_ring.png` | Circle of Carnage weapon-triangle diagram ring. |
| `assets/terra/ui/attr_triangle.png` | Element relationship diagram. |
| `assets/terra/ui/advantage_arrow.png` | Small arrow used in the advantage diagrams. |
| `assets/terra/ui/chevron_marker.png` | Chevron marking the acting unit. |
| `assets/terra/ui/countdown_plate.png` | Enemy turn-counter plate (vermilion rim). |
| `assets/terra/ui/battle_vignette.png` | Soft darkening vignette over the battlefield. |
| `assets/terra/ui/coin.png` | Coin glyph used by the wallet rows and battle spoils. |
| `assets/terra/ui/sword.png` | Sword weapon-type glyph (menus). |
| `assets/terra/ui/spear.png` | Spear weapon-type glyph (menus). |
| `assets/terra/ui/gun.png` | Gun weapon-type glyph (menus). |
| `assets/terra/ui/staff.png` | Staff weapon-type glyph (menus). |
| `assets/terra/ui/sword_badge.png` | Outlined sword badge overlaid on battle cards. |
| `assets/terra/ui/spear_badge.png` | Outlined spear badge overlaid on battle cards. |
| `assets/terra/ui/gun_badge.png` | Outlined gun badge overlaid on battle cards. |
| `assets/terra/ui/staff_badge.png` | Outlined staff badge overlaid on battle cards. |
| `assets/terra/ui/unit_player_border_menu.png` | Menu variant of the player tile rim (tools/gen_menu_border.py). |
| `assets/ui/click.png` | Tap gesture glyph for the drag-mode toggle. |
| `assets/ui/drag.png` | Drag gesture glyph for the drag-mode toggle. |
"""

ICONS = """
## Button icons (tools/gen_button_icons.py)
Every button in the game carries a small gold glyph beside its label, applied in code through `ui/button_icons.gd`. Real icons should stay single-color gold (around #E8C67C with a darker outline), read at 22px, keep the 40x40 canvas with transparent background, and overwrite the file at *Path*. Regenerate the whole set with `python3 tools/gen_button_icons.py`.

| Path | Used for | Description |
| --- | --- | --- |
| `assets/ui/icons/return.png` | RETURN buttons | Left chevron. |
| `assets/ui/icons/battle.png` | START / battle entry | Crossed swords. |
| `assets/ui/icons/gear.png` | SETTINGS | Cog wheel. |
| `assets/ui/icons/door.png` | QUIT / return to main menu | Doorway with exit arrow. |
| `assets/ui/icons/squad.png` | SQUAD | Two figures side by side. |
| `assets/ui/icons/figure.png` | CHARACTERS | Single bust. |
| `assets/ui/icons/book.png` | BESTIARY | Open book. |
| `assets/ui/icons/pouch.png` | ITEMS | Drawstring pouch. |
| `assets/ui/icons/scales.png` | MARKET | Merchant scales. |
| `assets/ui/icons/question.png` | HOW TO PLAY | Question mark. |
| `assets/ui/icons/plus.png` | ADD UNIT | Plus sign. |
| `assets/ui/icons/cross.png` | REMOVE / UNEQUIP-like actions | Diagonal cross. |
| `assets/ui/icons/swap.png` | CHANGE / CHOOSE unit | Two opposing arrows. |
| `assets/ui/icons/train.png` | TRAIN | Up arrow over a base. |
| `assets/ui/icons/companion.png` | COMPANION | Bird silhouette. |
| `assets/ui/icons/awaken.png` | AWAKEN | Eight-point starburst. |
| `assets/ui/icons/jobs.png` | JOBS | Three-branch path. |
| `assets/ui/icons/switch.png` | SWITCH job | Circular arrows. |
| `assets/ui/icons/unlock.png` | UNLOCK job | Open padlock. |
| `assets/ui/icons/locked.png` | Locked states | Closed padlock. |
| `assets/ui/icons/check.png` | Tap-to-confirm states | Check mark. |
| `assets/ui/icons/link.png` | EQUIP companion | Chain links. |
| `assets/ui/icons/unlink.png` | UNEQUIP companion | Broken chain links. |
| `assets/ui/icons/buy.png` | BUY | Coin. |
| `assets/ui/icons/skip.png` | SKIP cutscene | Double chevron to a bar. |
| `assets/ui/icons/retry.png` | TRY AGAIN | Loop arrow. |
| `assets/ui/icons/arrow_right.png` | CONTINUE | Right arrow. |
| `assets/ui/icons/pause.png` | Pause (battle HUD) | Two bars. |
| `assets/ui/icons/fast_forward.png` | Fast forward (battle HUD) | Double triangle. |
| `assets/ui/icons/play.png` | RESUME | Play triangle. |
| `assets/ui/icons/flag.png` | GIVE UP | Raised flag. |
| `assets/ui/icons/globe.png` | Language picker | Globe. |
| `assets/ui/icons/funnel.png` | Sort picker | Stacked filter lines. |
"""

VFX = """
## Battle VFX (tools/gen_vfx_art.py)
Per-element skill bursts and per-weapon impact sprites. The four burst sheets are 768x512 atlases of six 256px frames (rows of three, played at 18 fps by `skills/effects/*_hit_animation.tscn`); the weapon impacts are single sprites drawn additively by `skills/effects/attack_effect.gd`. Real art must keep the exact sheet layout and dimensions and stay luminous on transparency (the scenes use additive blending). Regenerate the whole set with `python3 tools/gen_vfx_art.py`. The other files in `assets/vfx/` are original hand-authored effects, not placeholders.

| Path | Description |
| --- | --- |
| `assets/vfx/fire_burst.png` | Fire skill hit: ragged flame starburst with drifting embers. |
| `assets/vfx/ice_burst.png` | Ice skill hit: crystal shards that grow then shatter outward. |
| `assets/vfx/lightning_burst.png` | Lightning skill hit: jagged flickering bolts around a flash. |
| `assets/vfx/shadow_burst.png` | Darkness skill hit: imploding violet ring with spiraling wisps. |
| `assets/vfx/slash_cut.png` | Sword basic attack impact: crossed slash streaks. |
| `assets/vfx/thrust_streak.png` | Spear basic attack impact: triple horizontal thrust streak. |
| `assets/vfx/ricochet_star.png` | Gun basic attack impact: sharp ricochet star with chips. |
| `assets/vfx/arcane_glyph.png` | Staff basic attack impact: spinning rune circle. |
"""


def append_section(text, section):
    marker = section.strip().splitlines()[0]
    if marker in text:
        print("skip (present): %s" % marker)
        return text
    print("append: %s" % marker)
    return text.rstrip("\n") + "\n" + section


def main():
    text = open(MANIFEST).read()
    for section in (BATTLE_UI, ICONS, VFX):
        text = append_section(text, section)
    open(MANIFEST, "w").write(text)


main()
