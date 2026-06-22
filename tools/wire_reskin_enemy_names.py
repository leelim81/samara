#!/usr/bin/env python3
"""Wire the re-skin ENEMY + BOSS names into battle (in-battle labels).

For every generated enemy scene, replace the UnitName label (in the .tscn) and
the job_name (in the matching job .tres) with the re-skin name produced by
build_reskin_xlsx.reskin_enemy() -- bosses get bespoke names, regulars get
family names (Heaven's Warden, Furnace Construct, Demon-beast, ...).

Text/name overlay only; no stat or layout change. Re-runnable & reversible.
Run: python3 tools/wire_reskin_enemy_names.py
"""
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_reskin_xlsx as R  # noqa: E402

ROOT = R.ROOT
BEST = R.data["bestiary"]


def uslug(n):
    return re.sub(r"[^a-z0-9]+", "_", n.lower()).strip("_")


# slug -> (exact name, is_boss); keep the highest-level entry on slug clashes
SLUG = {}
for _k, _e in BEST.items():
    s = uslug(_e["name"])
    et = _e.get("enemy_type") or ""
    is_boss = ("Boss" in et) or ("2x2" in et)
    lvl = _e.get("level") or 0
    if s not in SLUG or lvl > SLUG[s][2]:
        SLUG[s] = (_e["name"], is_boss, lvl)

# scene slugs whose name doesn't match a bestiary key directly
for _s, (_n, _b) in {
    "orbling_boss": ("Orbling", True),
    "wee_orbling_bow": ("Wee Orbling", False),
    "wee_orbling_spear": ("Wee Orbling", False),
    "wee_orbling_sword": ("Wee Orbling", False),
}.items():
    SLUG[_s] = (_n, _b, 999)


def reskin_for(slug):
    info = SLUG.get(slug)
    if not info:
        return None
    name, is_boss, _ = info
    rn = R.reskin_enemy(name, is_boss).replace(" (boss)", "")
    return rn.replace("—", "-").replace("–", "-")


def main():
    renamed, skipped = 0, []
    for scene in sorted(glob.glob(os.path.join(ROOT, "units/enemies/terra/*.tscn"))):
        slug = os.path.splitext(os.path.basename(scene))[0]
        rn = reskin_for(slug)
        if rn is None:
            skipped.append(slug)
            continue

        # 1. UnitName label in the scene
        txt = open(scene).read()
        new_txt = re.sub(r'(name="UnitName".*?text = )"[^"]*"',
                         lambda m: m.group(1) + '"' + rn + '"', txt, count=1, flags=re.S)
        if new_txt != txt:
            open(scene, "w").write(new_txt)

        # 2. job_name in the job resource
        job = os.path.join(ROOT, "jobs", "terra", slug + "_job.tres")
        if os.path.exists(job):
            jtxt = open(job).read()
            new_j = re.sub(r'job_name = "[^"]*"',
                           lambda m: 'job_name = "' + rn + '"', jtxt, count=1)
            if new_j != jtxt:
                open(job, "w").write(new_j)

        renamed += 1

    print("enemies renamed: %d" % renamed)
    if skipped:
        print("skipped (no bestiary match, kept original): %d -> %s" % (len(skipped), skipped))


if __name__ == "__main__":
    main()
