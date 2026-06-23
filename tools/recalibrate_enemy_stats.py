#!/usr/bin/env python3
"""Recalibrate every enemy's stat percentages so in-game stats reproduce the
Terra Battle wiki value (tools/out/terra_dataset.json bestiary) at the enemy's
level. Fixes snapshot drift + ch1-2 hardcoded values. Surgical: rewrites only
the *_percentage lines in stats/terra/*.tres for enemies that drifted.

The engine computes stat = round(level * base * 0.1 * pct) (legacy linear), so
pct = wiki_value / (level * base * 0.1), rounded to 4 dp (generator convention).
  python3 tools/recalibrate_enemy_stats.py [--apply]
Without --apply it's a dry run.
"""
import json, os, re, glob, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def P(*a): return os.path.join(ROOT, *a)
def read(rel):
    p = P(rel); return open(p).read() if os.path.exists(p) else ""

APPLY = "--apply" in sys.argv
HP_BASE, STAT_BASE, GROWTH = 1500, 50, 0.1

ds = json.load(open(P("tools/out/terra_dataset.json")))
ROMAN = {"Ⅰ": "i", "Ⅱ": "ii", "Ⅲ": "iii", "Ⅳ": "iv", "Ⅴ": "v"}
def norm(s):
    s = (s or "").strip().lower()
    for k, v in ROMAN.items(): s = s.replace(k, v)
    s = s.replace("β", "beta").replace("α", "alpha").replace("γ", "gamma")
    s = s.replace("_", " ").replace("-", " ")
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9 ]", "", s)).strip()

best = {}
for e in ds["bestiary"].values():
    best[(norm(e["name"]), e.get("level"))] = e

def enemy_level_job(path):
    t = read(path)
    lm = re.search(r"^level = (\d+)", t, re.M)
    jm = re.search(r"(jobs/terra/[a-z0-9_]+\.tres)", t)
    return (int(lm.group(1)) if lm else 1), (jm.group(1) if jm else None)

def stats_path(job_path):
    m = re.search(r"(stats/terra/[a-z0-9_]+\.tres)", read(job_path))
    return m.group(1) if m else None

def pct_for(value, base, level):
    return round(value / (level * base * GROWTH), 4) if level else 0.0

FIELDS = [("health_percentage", "hp", HP_BASE), ("attack_percentage", "atk", STAT_BASE),
          ("defense_percentage", "def", STAT_BASE), ("spiritual_attack_percentage", "matk", STAT_BASE),
          ("spiritual_defense_percentage", "mdef", STAT_BASE)]

# map stats_path -> (level, wiki entry), dedup
targets = {}
for esc in sorted(glob.glob(P("units/enemies/terra/*.tscn"))):
    rel = os.path.relpath(esc, ROOT)
    level, job = enemy_level_job(rel)
    if not job: continue
    sp = stats_path(job)
    if not sp: continue
    nm = re.search(r'unit_name = "([^"]*)"', read(sp))
    if not nm: continue
    be = best.get((norm(nm.group(1)), level))
    if be: targets[sp] = (level, be)

changed, skipped = [], 0
for sp, (level, be) in sorted(targets.items()):
    t = read(sp)
    new_t = t
    deltas = []
    for field, key, base in FIELDS:
        wiki = be.get(key)
        if wiki is None: continue
        want = pct_for(wiki, base, level)
        m = re.search(rf"^{field} = ([-\d.]+)", new_t, re.M)
        cur = float(m.group(1)) if m else None
        if cur is None or abs(cur - want) > 1e-9:
            new_t = re.sub(rf"^{field} = [-\d.]+", f"{field} = {want}", new_t, count=1, flags=re.M)
            if cur is None or abs(cur - want) > 0.0005:
                deltas.append(f"{key}:{cur}->{want}")
    if new_t != t:
        changed.append((sp, deltas))
        if APPLY:
            open(P(sp), "w").write(new_t)
    else:
        skipped += 1

print(f"{'APPLIED' if APPLY else 'DRY RUN'} — {len(changed)} stats files recalibrated, {skipped} already exact")
for sp, d in changed[:40]:
    print(f"  {os.path.basename(sp):34} {', '.join(d) if d else '(rounding only)'}")
if len(changed) > 40: print(f"  ... +{len(changed)-40} more")
