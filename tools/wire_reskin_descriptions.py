#!/usr/bin/env python3
"""Wire re-skin unit DESCRIPTIONS into job .tres files (unit detail screen).

Heroes get their character background (real name + no-spoiler bio); enemies and
bosses get their one-line appearance. Text overlay only; re-runnable.

Single source of truth = tools/build_reskin_xlsx.py.
Run: python3 tools/wire_reskin_descriptions.py
Then: godot --headless --import
"""
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_reskin_xlsx as R  # noqa: E402

ROOT = R.ROOT
BEST = R.data["bestiary"]


def clean(t):
    # .tres strings are double-quoted; keep them single-quote / dash safe.
    return (t or "").replace(" — ", " - ").replace("—", "-").replace("–", "-").replace('"', "'")


# hero re-skin tag -> job slug (mirrors the _ICONS portrait map)
TAG_SLUG = {
    "Auditor": "bahl", "Echo": "grace", "Patch": "kuscah", "Undertow": "shberdan",
    "Stormfront": "daiana", "Hauler": "macuri", "Inkwork": "gegonago", "Triage": "amimari",
    "Soft Rain": "mizell", "Burnout": "kem", "Blackout": "zan", "Sixteen-Bar": "korin",
    "Wetware": "eileen", "Rebar": "samupi", "Bluechip": "bagunar", "Deadeye": "harold",
    "Bruise": "burbaba", "Shortfuse": "maralme", "Nightstick": "nakupi", "Fastpass": "sorman",
    "Drifter": "iskar", "Nine Dragons": "zenzoze", "Riptide": "gigojago", "Deadman": "unasag",
    "Cleaver": "amazora", "Longarm": "raprow", "Slingshot": "manmer", "Courier": "lan",
}
HERO_DESC = {}
for c in R.CHARACTERS:
    slug = TAG_SLUG.get(c[1])
    if slug:
        HERO_DESC[slug] = clean(c[3])


def uslug(n):
    return re.sub(r"[^a-z0-9]+", "_", n.lower()).strip("_")


# slug -> (name, is_boss, level, weapon, attribute); keep highest-level on clash
SLUG = {}
for _e in BEST.values():
    s = uslug(_e["name"])
    et = _e.get("enemy_type") or ""
    is_boss = ("Boss" in et) or ("2x2" in et)
    lvl = _e.get("level") or 0
    if s not in SLUG or lvl > SLUG[s][2]:
        SLUG[s] = (_e["name"], is_boss, lvl, _e.get("weapon") or "", _e.get("attribute") or "None")
for _s, (_n, _b) in {
    "orbling_boss": ("Orbling", True),
    "wee_orbling_bow": ("Wee Orbling", False),
    "wee_orbling_spear": ("Wee Orbling", False),
    "wee_orbling_sword": ("Wee Orbling", False),
}.items():
    src = next((v for v in SLUG.values() if v[0] == _n), None)
    SLUG[_s] = (_n, _b, 999, src[3] if src else "", src[4] if src else "None")


def enemy_desc(slug):
    info = SLUG.get(slug)
    if not info:
        return None
    name, is_boss, _, weap, attr = info
    if is_boss and name in R.BOSS:
        return clean(R.BOSS[name][1])
    rn = R.reskin_enemy(name, is_boss)
    return clean(R.reskin_appearance(rn, weap, attr))


def set_desc(jobpath, desc):
    txt = open(jobpath).read()
    if re.search(r'description = "[^"]*"', txt):
        new = re.sub(r'description = "[^"]*"', lambda m: 'description = "%s"' % desc, txt, count=1)
    elif re.search(r'job_name = "[^"]*"', txt):
        new = re.sub(r'(job_name = "[^"]*")', lambda m: m.group(1) + '\ndescription = "%s"' % desc, txt, count=1)
    else:
        new = re.sub(r'(\[resource\]\nscript = ExtResource\([^)]*\))',
                     lambda m: m.group(1) + '\ndescription = "%s"' % desc, txt, count=1)
    if new != txt:
        open(jobpath, "w").write(new)
        return True
    return False


def main():
    heroes = enemies = 0
    for job in sorted(glob.glob(os.path.join(ROOT, "jobs", "terra", "*_job.tres"))):
        slug = os.path.basename(job)[:-len("_job.tres")]
        if slug in HERO_DESC:
            if set_desc(job, HERO_DESC[slug]):
                heroes += 1
            continue
        d = enemy_desc(slug)
        if d and set_desc(job, d):
            enemies += 1
    print("hero descriptions: %d, enemy descriptions: %d" % (heroes, enemies))


if __name__ == "__main__":
    main()
