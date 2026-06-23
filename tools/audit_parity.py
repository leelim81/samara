#!/usr/bin/env python3
"""Deterministic TB-parity audit across all 42 chapters:
  1. PLACEMENT: every enemy sits on a valid grid cell; 2x2 bosses fit (col<=4,
     row<=6); no two enemies share a cell in a wave; flags row-0 (un-flankable).
  2. STATS: each enemy's generated HP/ATK/DEF/MATK/MDEF (computed from its
     stats .tres percentage at its level, the legacy-linear engine formula)
     matches the Terra Battle wiki value in tools/out/terra_dataset.json.
  3. DIFFICULTY CURVE: per-chapter enemy level range vs the wiki.
No Godot needed (enemies use legacy-linear growth); fast + reproducible.
  python3 tools/audit_parity.py
"""
import json, os, re, glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def P(*a): return os.path.join(ROOT, *a)
def read(rel):
    p = P(rel)
    return open(p).read() if os.path.exists(p) else ""

TILE = 100
GRID_W, GRID_H = 6, 8
HP_BASE, STAT_BASE, GROWTH = 1500, 50, 0.1

ds = json.load(open(P("tools/out/terra_dataset.json")))
bestiary = ds["bestiary"]

ROMAN = {"Ⅰ": "i", "Ⅱ": "ii", "Ⅲ": "iii", "Ⅳ": "iv", "Ⅴ": "v"}
def norm(s):
    s = (s or "").strip().lower()
    for k, v in ROMAN.items():
        s = s.replace(k, v)
    s = s.replace("β", "beta").replace("α", "alpha").replace("γ", "gamma")
    s = s.replace("_", " ").replace("-", " ")
    s = re.sub(r"[^a-z0-9 ]", "", s)
    return re.sub(r"\s+", " ", s).strip()

# wiki entries keyed by (name, level) and by name
best_by_name_level, best_by_name = {}, {}
for e in bestiary.values():
    nm = norm(e["name"])
    best_by_name_level[(nm, e.get("level"))] = e
    best_by_name.setdefault(nm, []).append(e)

def parse_stats(path):
    t = read(path)
    def g(f, d=1.0):
        m = re.search(rf"^{f} = ([-\d.]+)", t, re.M)
        return float(m.group(1)) if m else d
    nm = re.search(r'unit_name = "([^"]*)"', t)
    return {"name": nm.group(1) if nm else "",
            "hp": g("health_percentage"), "atk": g("attack_percentage"),
            "def": g("defense_percentage"), "matk": g("spiritual_attack_percentage"),
            "mdef": g("spiritual_defense_percentage")}

def parse_enemy(path):
    t = read(path)
    lm = re.search(r"^level = (\d+)", t, re.M)
    jm = re.search(r"(jobs/terra/[a-z0-9_]+\.tres)", t)
    return {"level": int(lm.group(1)) if lm else 1,
            "is2x2": bool(re.search(r"^size = 1", t, re.M)),
            "job": jm.group(1) if jm else None}

def job_stats(job_path):
    m = re.search(r"(stats/terra/[a-z0-9_]+\.tres)", read(job_path))
    return m.group(1) if m else None

def gen_stat(level, base, pct): return round(level * base * GROWTH * pct)

# ---------- 1. STAT PARITY (over every enemy scene) ----------
stat_issues, level_issues, unmatched = [], [], []
checked = 0
for esc in sorted(glob.glob(P("units/enemies/terra/*.tscn"))):
    rel = os.path.relpath(esc, ROOT)
    en = parse_enemy(rel)
    if not en["job"]: continue
    sp = job_stats(en["job"])
    if not sp: continue
    st = parse_stats(sp)
    nm = norm(st["name"])
    be = best_by_name_level.get((nm, en["level"]))
    if be is None:
        cands = best_by_name.get(nm)
        if not cands:
            unmatched.append((rel, st["name"]))
            continue
        be = cands[0]  # name matches but level differs
        if be.get("level") != en["level"]:
            level_issues.append((rel, en["level"], be.get("level"), st["name"]))
    checked += 1
    for key, base, pct in [("hp", HP_BASE, st["hp"]), ("atk", STAT_BASE, st["atk"]),
                           ("def", STAT_BASE, st["def"]), ("matk", STAT_BASE, st["matk"]),
                           ("mdef", STAT_BASE, st["mdef"])]:
        wiki = be.get(key)
        if wiki is None: continue
        gen = gen_stat(en["level"], base, pct)
        if abs(gen - wiki) > max(2, round(wiki * 0.03)):
            stat_issues.append((rel, key, gen, wiki, en["level"]))

# ---------- 2. PLACEMENT (per battle scene) ----------
# chapter order from the story list
clist = read("chapter_data/main_story_chapter_list.tres")
slugs = re.findall(r"chapter_data/terra/([a-z0-9_]+)\.tres", clist)
battles = []
for slug in slugs:
    m = re.search(r'battle_scene_path = "([^"]+)"', read(f"chapter_data/terra/{slug}.tres"))
    if m: battles.append((slug, m.group(1).replace("res://", "")))

place_issues = []
chapter_levels = []  # (slug, [levels])
for slug, bpath in battles:
    bt = read(bpath)
    ext = dict(re.findall(r'\[ext_resource path="res://(units/enemies/terra/[a-z0-9_]+\.tscn)" type="PackedScene" id=(\d+)\]', bt))
    ext = {v: k for k, v in ext.items()}  # id -> path
    # iterate nodes with a phase parent + position
    levels = []
    occupied = {}  # phase -> set of (col,row)
    for nm, phase, eid, after in re.findall(
            r'\[node name="([^"]+)" parent="Board/EnemyPhases/(Phase\d+)"[^\]]*instance=ExtResource\(\s*(\d+)\s*\)\]\s*\n(.*?)(?=\n\[node|\Z)',
            bt, re.S):
        pm = re.search(r"position = Vector2\(\s*([-\d.]+),\s*([-\d.]+)\s*\)", after)
        if not pm: continue
        x, y = float(pm.group(1)), float(pm.group(2))
        col, row = int(x // TILE), int(y // TILE)
        epath = ext.get(eid)
        is2x2 = parse_enemy(epath)["is2x2"] if epath else False
        if epath: levels.append(parse_enemy(epath)["level"])
        # checks
        if not (0 <= col < GRID_W and 0 <= row < GRID_H):
            place_issues.append((slug, nm, f"OFF-GRID col{col} row{row} (pos {x:.0f},{y:.0f})"))
            continue
        if is2x2 and not (col <= GRID_W - 2 and row <= GRID_H - 2):
            place_issues.append((slug, nm, f"2x2 OVERHANG at col{col} row{row}"))
        if row == 0:
            place_issues.append((slug, nm, f"ROW-0 (un-flankable) col{col}"))
        cells = [(col, row)]
        if is2x2: cells = [(col, row), (col + 1, row), (col, row + 1), (col + 1, row + 1)]
        for c in cells:
            if c in occupied.setdefault(phase, set()):
                place_issues.append((slug, nm, f"OVERLAP at {c} in {phase} (also {occupied[phase]})"))
            occupied[phase].add(c)
    chapter_levels.append((slug, levels))

# ---------- REPORT ----------
print("=" * 70)
print("TB PARITY AUDIT")
print("=" * 70)
print(f"\n[1] STAT PARITY — checked {checked} enemy scenes vs wiki bestiary")
print(f"    unmatched (no wiki name): {len(unmatched)}")
for r, n in unmatched[:12]: print(f"      - {r}  ('{n}')")
print(f"    stat mismatches (>3%): {len(stat_issues)}")
for r, k, g, w, lv in stat_issues[:25]: print(f"      - {os.path.basename(r):28} {k.upper():4} gen={g} wiki={w} (L{lv})")
if len(stat_issues) > 25: print(f"      ... +{len(stat_issues)-25} more")
print(f"    level mismatches vs wiki: {len(level_issues)}")
for r, gl, wl, n in level_issues[:15]: print(f"      - {os.path.basename(r):28} scene L{gl} vs wiki L{wl}")

print(f"\n[2] PLACEMENT — {len(battles)} battle scenes")
print(f"    placement glitches: {len(place_issues)}")
for s, n, msg in place_issues[:30]: print(f"      - {s:22} {n:22} {msg}")
if len(place_issues) > 30: print(f"      ... +{len(place_issues)-30} more")

print(f"\n[3] DIFFICULTY CURVE — per-chapter enemy level (min..max)")
prev_max = 0
for i, (slug, lv) in enumerate(chapter_levels, 1):
    if not lv:
        print(f"    {i:2} {slug:22} (no enemies parsed)"); continue
    mn, mx = min(lv), max(lv)
    arrow = "UP" if mx >= prev_max else "down"
    print(f"    {i:2} {slug:22} L{mn:>3}..{mx:<3}  ({len(lv)} enemies)  {arrow}")
    prev_max = mx
print("\nDONE")
