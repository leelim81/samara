#!/usr/bin/env python3
"""Wire the four endgame chapters (39-42) the wiki left as stubs.

Ch39-42 have stage metadata (rec levels 79-80) but no recovered enemy stats, so
generate_chapter.py skips them. Rather than invent new enemies (and risk
clobbering shared, already-generated enemy scenes / art), this builds their
battle scenes by REUSING enemy scenes already generated for chapters 25-38 -
an escalating roster of high-level regulars and 2x2 bosses so difficulty keeps
climbing into the finale (boss Lv 85 -> 86 -> 88 -> two Lv99 Wardens).

Player level per battle is fixed at max-enemy-level + 3 (same model the
generator uses for chapters 1-38), so the difficulty stays fair and monotonic.

Run:  python3 tools/wire_finale_chapters.py
Then: python3 tools/register_chapters.py
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "scripts"))
import generate_chapter as G  # noqa: E402  (battle_scene, write, ROOT, WEAPON, DATASET)

ROOT = G.ROOT
DATA = json.load(open(G.DATASET))
BEST = DATA["bestiary"]
CH_META = {c["num"]: c for c in DATA["chapters"]}

WNAME = {0: "sword", 1: "gun", 2: "spear", 3: "staff"}


def uslug(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


# highest-level bestiary entry per slug (matches what generate_chapter wrote)
SLUG2E = {}
for _k, _e in BEST.items():
    _s = uslug(_e["name"])
    if _s not in SLUG2E or (_e.get("level") or 0) > (SLUG2E[_s].get("level") or 0):
        SLUG2E[_s] = _e


# num: (TITLE, slug, phases, {2x2 boss slugs}).  Each phase is a list of
# (enemy_slug, count); the last phase is the boss finale.  Every slug must
# already have a generated scene at units/enemies/terra/<slug>.tscn.
CHAPTERS = {
    39: ("PROPOSITION", "proposition",
         [[("devourer", 2), ("harrier", 1)],
          [("negaton", 2), ("negale", 1)],
          [("wisprat", 2), ("devourer", 1)],
          [("xaepha", 1), ("negaton", 1), ("negale", 1)]],
         {"xaepha"}),
    40: ("ASH_OF_SOULS", "ash_of_souls",
         [[("negale", 2), ("negat", 1)],
          [("negaton", 2), ("falaan", 1)],
          [("leefa", 2), ("negale", 1)],
          [("giant_nega", 1), ("negaton", 1), ("falaan", 1)]],
         {"giant_nega"}),
    41: ("A_TOWER_REBORN", "a_tower_reborn",
         [[("aurochs", 2), ("right_creeper", 1)],
          [("gnorusk", 2), ("incapacitator", 1)],
          [("kirusk", 2), ("incapacitator", 1)],
          [("relic", 1), ("kirusk", 1), ("incapacitator", 1)]],
         {"relic"}),
    42: ("TERRA_BATTLE", "terra_battle",
         [[("kirusk", 2), ("incapacitator", 2)],
          [("negaton", 2), ("kirusk", 2)],
          [("6zoo", 1), ("3coo", 1), ("kirusk", 1)]],
         {"6zoo", "3coo"}),
}

CHAPTER_T = """[gd_resource type="Resource" load_steps=4 format=2]

[ext_resource path="res://chapter_data/chapter_data.gd" type="Script" id=1]
[ext_resource path="res://chapter_data/battle_info.gd" type="Script" id=2]

[sub_resource type="Resource" id=1]
script = ExtResource( 2 )
sword_enemy_count = {sword}
gun_enemy_count = {gun}
spear_enemy_count = {spear}
staff_enemy_count = {staff}
phases_count = {phases}

[resource]
script = ExtResource( 1 )
title = "{title}"
caption = "{title}_CAPTION"
difficulty = "{difficulty}"
battle_scene_path = "res://battles/terra/{slug}.tscn"
locked = false
battle_info = SubResource( 1 )
"""


def main():
    for num, (title, slug, phases, boss2x2) in sorted(CHAPTERS.items()):
        used = sorted({s for ph in phases for (s, _) in ph})

        missing = [s for s in used
                   if not os.path.exists(os.path.join(ROOT, "units", "enemies", "terra", s + ".tscn"))]
        if missing:
            print("ABORT Ch%d %s: missing enemy scenes %s" % (num, title, missing))
            sys.exit(1)

        unknown = [s for s in used if s not in SLUG2E]
        if unknown:
            print("ABORT Ch%d %s: enemy not in bestiary %s" % (num, title, unknown))
            sys.exit(1)

        max_lv = max((SLUG2E[s].get("level") or 1) for s in used)
        fixed = max_lv + 3

        wc = {"sword": 0, "gun": 0, "spear": 0, "staff": 0}
        for s in used:
            wc[WNAME[G.WEAPON.get(SLUG2E[s].get("weapon"), 0)]] += 1

        recs = [st["rec_level"] for st in CH_META[num]["stages"] if st.get("rec_level")]
        if recs and min(recs) != max(recs):
            difficulty = "%d-%d" % (min(recs), max(recs))
        elif recs:
            difficulty = str(recs[0])
        else:
            difficulty = "?"

        G.write("battles/terra/%s.tscn" % slug, G.battle_scene(phases, fixed, boss2x2))
        G.write("chapter_data/terra/%s.tres" % slug, CHAPTER_T.format(
            sword=wc["sword"], gun=wc["gun"], spear=wc["spear"], staff=wc["staff"],
            phases=len(phases), title=title, difficulty=difficulty, slug=slug))

        print("Ch%d %-15s %d phases  playerLv%d  bosses=%s  enemies=%s  diff=%s"
              % (num, title, len(phases), fixed, sorted(boss2x2), used, difficulty))


if __name__ == "__main__":
    main()
