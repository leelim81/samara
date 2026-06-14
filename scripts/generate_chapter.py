#!/usr/bin/env python3
"""Dataset-driven chapter generator (vertical slice toward all 42 chapters).

Reads tools/out/terra_dataset.json and emits everything needed to make one
chapter playable: enemy stats, skills, jobs, enemy scenes, the battle scene
(the chapter's final stage), the ChapterData resource + chapter_list entry,
story/dialogue text, captions, and enemy art (token + full from the fetched
sprites). Counter skills and 2x2 bosses are not yet handled (Ch3 has neither).

Usage: python3 scripts/generate_chapter.py <chapter_number>

This is the extension of scripts/generate_terra_content.py that consumes the
joined wiki dataset instead of hardcoded tables; ch1-2 stay as-is for now.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATASET = os.path.join(ROOT, "tools", "out", "terra_dataset.json")
ENEMY_ART = os.path.join(ROOT, "assets", "terra", "enemies")
DEVNULL = open(os.devnull, "wb")

SWORD, BOW, SPEAR, STAFF = 0, 1, 2, 3
ST_ATTACK, ST_HEAL, ST_COUNTER = 0, 1, 5
AOE_NONE, AOE_PINCER, AOE_AREA_X, AOE_CROSS_X, AOE_HORIZONTAL_X, AOE_VERTICAL_X = 0, 2, 3, 4, 6, 7
# Enums.Attribute: NONE 0, LIGHTNING 1, FIRE 2, ICE 3, DARKNESS 4, SOLAR 5,
# LUNAR 6, PHOTON 7, GRAVITON 8, HEALING 9
ATTR = {"Lightning": 1, "Fire": 2, "Ice": 3, "Darkness": 4, "Dark": 4,
        "Solar": 5, "Lunar": 6, "Photon": 7, "Graviton": 8}
WEAPON = {"Sword": SWORD, "Bow": BOW, "Gun": BOW, "Spear": SPEAR, "Staff": STAFF,
          "Unarmed": SWORD, None: SWORD, "": SWORD}

EFFECTS = {
    "hit": "res://skills/effects/simple_hit_skill_effect.tscn",
    "spear": "res://skills/effects/simple_spear_skill_effect.tscn",
    "shoot": "res://skills/effects/shooting_skill_effect.tscn",
    "heal": "res://skills/effects/heal_skill_effect.tscn",
    "sweep": "res://skills/effects/sweep_skill_effect.tscn",
}

# wiki skill name -> engine skill spec  (offensive / heal; drives AI actions)
# (slug, display, type, aoe, power, rate, pusher, weapon, attr, effect)
SKILL_SPECS = {
    "Slash":       ("slash", "SLASH", ST_ATTACK, AOE_HORIZONTAL_X, 1.5, 0.3, False, SWORD, 0, "hit"),
    "Sever":       ("sever", "SEVER", ST_ATTACK, AOE_HORIZONTAL_X, 1.5, 0.3, True, SWORD, 0, "sweep"),
    "Stab":        ("stab", "STAB", ST_ATTACK, AOE_VERTICAL_X, 1.5, 0.3, False, SPEAR, 0, "spear"),
    "Thrust Away": ("thrust_away", "THRUST_AWAY", ST_ATTACK, AOE_VERTICAL_X, 1.0, 0.3, True, SPEAR, 0, "spear"),
    "Arrow":       ("arrow", "ARROW", ST_ATTACK, AOE_AREA_X, 1.5, 0.3, False, BOW, 0, "shoot"),
    "Heal":        ("heal", "HEAL", ST_HEAL, AOE_AREA_X, 1.5, 0.8, False, STAFF, 0, "heal"),
    # elemental staff attacks carry their attribute so the element triangle applies
    "Fire":        ("fire", "FIRE", ST_ATTACK, AOE_CROSS_X, 1.0, 0.3, False, STAFF, 2, "hit"),
    "Ice":         ("ice", "ICE", ST_ATTACK, AOE_CROSS_X, 1.0, 0.3, False, STAFF, 3, "hit"),
    "Shadow":      ("shadow", "SHADOW", ST_ATTACK, AOE_CROSS_X, 1.0, 0.3, False, STAFF, 4, "hit"),
    "Thunder":     ("thunder", "THUNDER", ST_ATTACK, AOE_CROSS_X, 1.0, 0.3, False, STAFF, 1, "hit"),
}
WEAPON_DEFAULT_SKILL = {SWORD: "Slash", BOW: "Arrow", SPEAR: "Stab", STAFF: "Heal"}
# a single generic counterattack stands in for all "* Counter" wiki skills
# (skill_type COUNTER is collected passively and fires when the unit is pincered)
COUNTER_SPEC = ("counterattack", "COUNTERATTACK", ST_COUNTER, AOE_PINCER, 1.5, 0.3, False, SWORD, 0, "hit")

# ---- skill derivation from the wiki skill table (range / effect / emitratio) ----
# Curated specs above are hand-tuned; everything else is derived here. Only
# ATTACK / HEAL are produced (buffs / status approximate to a basic attack),
# so derived skills always load and behave.
_ELEMENTS = [
    (("fire", "flame", "fiery", "burn", "inferno", "magma", "lava", "blaze", "ember", "pyro", "scorch"), 2),
    (("ice", "frost", "blizzard", "freeze", "frozen", "glaci", "cryo", "chill"), 3),
    (("lightning", "thunder", "electric", "shock", "spark", "volt", "discharge", "plasma"), 1),
    (("dark", "shadow", "abyss", "void", "doom", "curse", "death", "night"), 4),
    (("solar", "sunlight", "radiant"), 5),
    (("lunar", "moon"), 6),
    (("photon", "prism", "laser", "beam"), 7),
    (("gravit", "graviton"), 8),
]
_WEAP_AOE = {SWORD: AOE_HORIZONTAL_X, BOW: AOE_AREA_X, SPEAR: AOE_VERTICAL_X, STAFF: AOE_CROSS_X}
_WEAP_KEY = {SWORD: "sword", BOW: "bow", SPEAR: "spear", STAFF: "staff"}
_WEAP_FX = {SWORD: "hit", BOW: "shoot", SPEAR: "spear", STAFF: "hit"}


def element_from(text):
    for kws, aid in _ELEMENTS:
        if any(kw in text for kw in kws):
            return aid
    return 0


def parse_power(effect, default, cap):
    m = re.search(r"[x×]\s*([\d.]+)", effect or "")
    try:
        return min(float(m.group(1)), cap) if m else default
    except ValueError:
        return default


def aoe_from(rng, weapon):
    r = (rng or "").lower()
    if "cross" in r:
        return AOE_CROSS_X
    if "vert" in r:
        return AOE_VERTICAL_X
    if "lateral" in r or "row" in r or "horiz" in r:
        return AOE_HORIZONTAL_X
    if "area" in r:
        return AOE_AREA_X
    if "self" in r:
        return AOE_NONE
    if "pincer" in r:
        return AOE_PINCER
    return _WEAP_AOE[weapon]


def derive_skill(sk, weapon):
    """Map a wiki skill dict -> engine spec tuple
    (slug, name, type, aoe, power, rate, pusher, weapon, attr, effect).
    Elemental skills are shared (staff/MATK); physical ones are weapon-keyed."""
    name = (sk.get("name") or "Attack").replace('"', "'")
    eff = sk.get("effect") or ""
    low = (name + " " + eff).lower()
    rate = min(1.0, (sk.get("emitratio") or 30) / 100.0)
    pusher = any(w in low for w in ("knock", "blow", "thrust", "ram", "blast", "repel"))
    if "heal" in low or ("restore" in low and "hp" in low):
        return ("d_" + uslug(name), name, ST_HEAL, AOE_AREA_X,
                parse_power(eff, 1.5, 8.0), rate, False, STAFF, 0, "heal")
    attr = element_from(low)
    power = parse_power(eff, 1.5, 6.0)
    if attr:
        return ("d_" + uslug(name), name, ST_ATTACK, aoe_from(sk.get("range"), STAFF),
                power, rate, pusher, STAFF, attr, "hit")
    return ("d_%s_%s" % (uslug(name), _WEAP_KEY[weapon]), name, ST_ATTACK,
            aoe_from(sk.get("range"), weapon), power, rate, pusher, weapon, 0, _WEAP_FX[weapon])


def synth_battles(chapter, best):
    """Stub chapter (no enemy lists on the wiki) but with recovered enemy stat
    blocks: synthesize the final stage's battles from real enemies — invented
    placement, bosses in the finale. Grounded reconstruction, flagged by caller."""
    keys = chapter["recovered_enemy_keys"]
    n = max(1, min(chapter["stages"][-1].get("battles") or 4, 5))
    bosses = [k for k in keys if "Boss" in (best[k].get("enemy_type") or "")]
    regs = [k for k in keys if k not in bosses] or keys

    def ent(k, count, boss=False):
        e = best[k]
        return {"enemy_key": k, "name": e["name"], "level": e["level"], "count": count, "boss": boss}

    battles = []
    for b in range(n):
        if b == n - 1:                       # finale: bosses + a couple regulars
            es = [ent(bk, 1, True) for bk in bosses[:2]]
            es += [ent(regs[i % len(regs)], 1) for i in range(min(2, len(regs)))]
        else:
            es = [ent(regs[(b * 2 + j) % len(regs)], 1 + (j % 2)) for j in range(3)]
        battles.append({"n": b + 1, "enemies": es})
    return battles


def pct(v, level, base):
    return round((v or 0) / (level * base * 0.1), 4) if level else 0.0


def uslug(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def hslug(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def attr_id(a):
    return ATTR.get(a, 0)                           # all 8 Terra elements; else NONE


def vuln_from(avoids):
    if not avoids:
        return 1.0
    return round(max(0.0, min(1.0, 1 - sum(avoids.values()) / len(avoids) / 100.0)), 2)


def write(path, content):
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w") as f:
        f.write(content)
    return path


# ---------------------------------------------------------------- templates
STATS_T = """[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://stats/stats.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
unit_name = "{display}"
unit_type = "MONSTER"
health_percentage = {hp}
attack_percentage = {atk}
defense_percentage = {deff}
spiritual_attack_percentage = {matk}
spiritual_defense_percentage = {mdef}
status_ailment_vulnerability = {vuln}
status_ailment_vulnerabilities = {{
}}
same_attribute_resistance = 0.5
attribute = {attr}
weapon_type = {weapon}
max_turn_counter = {counter}
can_randomize_turn_counter = true
movement_range = {move}
skill_activation_rate_modifier = 0.0
"""

SKILL_T = """[gd_resource type="Resource" load_steps=3 format=2]

[ext_resource path="res://skills/skill.gd" type="Script" id=1]
[ext_resource path="{effect}" type="PackedScene" id=2]

[resource]
script = ExtResource( 1 )
skill_name = "{name}"
skill_type = {stype}
area_of_effect = {aoe}
area_of_effect_size = 1
activation_rate = {rate}
is_pusher = {pusher}
primary_power = {power}
primary_weapon_type = {weapon}
primary_attribute = {attr}
secondary_power = 0.0
secondary_weapon_type = 1
secondary_attribute = 0
absorb_rate = 0.0
max_heal = 700
status_effects = [  ]
status_effect_infliction_rate = 0.3
cured_status_effects = [  ]
effect_scene = ExtResource( 2 )
is_delayed = false
"""

JOB_T = """[gd_resource type="Resource" load_steps={steps} format=2]

[ext_resource path="res://jobs/job.gd" type="Script" id=1]
[ext_resource path="res://stats/terra/{slug}_stats.tres" type="Resource" id=2]
[ext_resource path="res://assets/terra/tokens/{token}_token.png" type="Texture2D" id=3]
[ext_resource path="res://assets/terra/full/{token}_full.png" type="Texture2D" id=4]
{skill_res}
[resource]
script = ExtResource( 1 )
stats = ExtResource( 2 )
skills = [ {skill_refs} ]
job_name = "{display}"
portrait = ExtResource( 3 )
full_portrait = ExtResource( 4 )
"""

ENEMY_T = """[gd_scene load_steps={steps} format=2]

[ext_resource path="res://units/enemy.tscn" type="PackedScene" id=1]
[ext_resource path="res://jobs/terra/{slug}_job.tres" type="Resource" id=2]
[ext_resource path="res://assets/terra/tokens/{token}_token.png" type="Texture2D" id=3]
[ext_resource path="res://units/ai/condition.tscn" type="PackedScene" id=4]
[ext_resource path="res://units/ai/action.tscn" type="PackedScene" id=5]
{skill_res}
[node name="{node}" instance=ExtResource( 1 )]
level = {level}
turn_counter = {counter}

[node name="Job" parent="." index="2"]
job = ExtResource( 2 )

[node name="Icon" parent="Sprite2D" index="1"]
texture = ExtResource( 3 )

{border}[node name="UnitName" parent="CanvasLayer" index="3"]
text = "{display}"

{actions}
[editable path="CanvasLayer/ActivatedSkillMarginContainer"]
"""

# 2x2 boss scene (parameterised from the working Spinetrich scene). enemy.tscn
# is id=2 here and skill ext_resources start at id=20 (actions_block start_id).
ENEMY_2X2_T = """[gd_scene load_steps={steps} format=2]

[ext_resource path="res://units/enemy.tscn" type="PackedScene" id=2]
[ext_resource path="res://jobs/terra/{slug}_job.tres" type="Resource" id=3]
[ext_resource path="res://assets/ui/enemy_border_2x2.png" type="Texture2D" id=9]
[ext_resource path="res://assets/ui/unit_square_bg_2x2.png" type="Texture2D" id=10]
[ext_resource path="res://units/ai/condition.tscn" type="PackedScene" id=4]
[ext_resource path="res://units/ai/action.tscn" type="PackedScene" id=5]
{skill_res}

[sub_resource type="RectangleShape2D" id=1]
extents = Vector2( 80, 80 )

[sub_resource type="RectangleShape2D" id=3]
extents = Vector2( 96.5, 96.5 )

[node name="{node}" instance=ExtResource( 2 )]
size = 1
level = {level}
turn_counter = {counter}

[node name="Job" parent="." index="2"]
job = ExtResource( 3 )

[node name="CollisionShape2D" parent="." index="4"]
visible = true
position = Vector2( 48, 48 )
shape = SubResource( 1 )

[node name="Sprite2D" parent="." index="5"]
position = Vector2( 51.5, 51.5 )
texture = ExtResource( 10 )

[node name="Glow" parent="Sprite2D" index="0"]
scale = Vector2( 2, 2 )

[node name="Border" parent="Sprite2D" index="2"]
texture = ExtResource( 9 )

[node name="CollisionShape2D" parent="SelectionArea2D" index="0"]
position = Vector2( 47.5, 47.5 )
shape = SubResource( 3 )

[node name="HpBar" parent="Control" index="0"]
offset_left = 16.0
offset_top = 63.0
offset_right = 120.0
offset_bottom = 70.0
nine_patch_stretch = true

[node name="CanvasLayer" parent="." index="10"]
position = Vector2( 48, 48 )

[node name="WeaponType" parent="CanvasLayer/Control" index="0"]
offset_left = -8.0
offset_top = -53.0
offset_right = 57.0
offset_bottom = 12.0

[node name="Icon" parent="CanvasLayer/StatusEffectsIcons" index="0"]
offset_left = 0.0
offset_top = 0.0
offset_right = 48.0
offset_bottom = 48.0

[node name="ActivatedSkillMarginContainer" parent="CanvasLayer" index="2"]
offset_left = 0.0
offset_right = 0.0
offset_bottom = 0.0

[node name="UnitName" parent="CanvasLayer" index="3"]
offset_left = -48.0
offset_top = -48.0
offset_right = 52.0
offset_bottom = 52.0
text = "{display}"

[node name="Sprite2D" parent="CanvasLayer/UnitName" index="0"]
position = Vector2( 48, 48 )

{actions}
[editable path="CanvasLayer/ActivatedSkillMarginContainer"]
"""

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
caption = "{caption}"
difficulty = "{difficulty}"
battle_scene_path = "res://battles/terra/{scene}.tscn"
battle_info = SubResource( 1 )
"""


def actions_block(skill_slugs, start_id=6):
    res, blocks = [], []
    for i, s in enumerate(skill_slugs):
        res.append(f'[ext_resource path="res://skills/resources/terra/{s}.tres" type="Resource" id={start_id + i}]')
        blocks.append(
            f'[node name="Action{i + 1}" parent="AIController" index="{i}" instance=ExtResource( 5 )]\n'
            f'behavior = 1\nskill = ExtResource( {start_id + i} )\n\n'
            f'[node name="Condition" parent="AIController/Action{i + 1}" index="0" instance=ExtResource( 4 )]\n')
    mi = len(skill_slugs)
    blocks.append(
        f'[node name="ActionMove" parent="AIController" index="{mi}" instance=ExtResource( 5 )]\n'
        f'behavior = 2\nweight = 3\n\n'
        f'[node name="Condition" parent="AIController/ActionMove" index="0" instance=ExtResource( 4 )]\n')
    return res, blocks


def tile(col, row):
    return (50 + 100 * col, 50 + 100 * row)


# Checkerboard cells in rows 1-4 (never row 0, so a vertical flank is always
# in range; orthogonal neighbours have opposite parity, so they stay empty and
# every enemy is flankable on both axes). Avoids the "wall of enemies" bug.
PLACEMENT = [(1, 1), (3, 1), (5, 1),
             (0, 2), (2, 2), (4, 2),
             (1, 3), (3, 3), (5, 3),
             (0, 4), (2, 4), (4, 4)]


# top-left corners for up to 3 2x2 bosses (each fits cols 0-5 / rows 1-4)
BOSS_CORNERS = [(2, 1), (0, 1), (4, 1)]


def _place(flat, boss2x2):
    """Assign a grid cell to each enemy in a battle. 2x2 bosses take a footprint
    plus reserved flank cells (so they stay flankable); 1x1 enemies fill the
    checkerboard around them. -> list of (col, row) per index."""
    pos = {}
    reserved = set()
    bi = 0
    for i, slug in enumerate(flat):
        if slug in boss2x2:
            c, r = BOSS_CORNERS[bi % len(BOSS_CORNERS)]
            bi += 1
            pos[i] = (c, r)
            reserved |= {(c, r), (c + 1, r), (c, r + 1), (c + 1, r + 1),
                         (c - 1, r), (c + 2, r), (c, r - 1), (c, r + 2)}
    avail = [cell for cell in PLACEMENT if cell not in reserved]
    ai = 0
    for i, slug in enumerate(flat):
        if i in pos:
            continue
        pos[i] = avail[ai % len(avail)] if avail else (1, 1)
        ai += 1
    return [pos[i] for i in range(len(flat))]


def battle_scene(phases, fixed_level, boss2x2):
    used = sorted({slug for ph in phases for (slug, _) in ph})
    lines = [f"[gd_scene load_steps={2 + len(used)} format=2]", "",
             '[ext_resource path="res://board/battle.tscn" type="PackedScene" id=1]']
    ids = {}
    for i, slug in enumerate(used):
        ids[slug] = 10 + i
        lines.append(f'[ext_resource path="res://units/enemies/terra/{slug}.tscn" type="PackedScene" id={10 + i}]')
    lines += ["", '[node name="BoardUI" instance=ExtResource( 1 )]', "",
              '[node name="Board" parent="." index="0"]',
              f"fixed_player_units_level = {fixed_level}", ""]
    counters = {}
    for p, ph in enumerate(phases, start=1):
        lines += [f'[node name="Phase{p}" parent="Board/EnemyPhases" index="{p - 1}"]', "visible = false", ""]
        flat = []
        for slug, count in ph:
            flat += [slug] * count
        # cap battle size so a 6-unit party isn't swarmed and enemies don't
        # mutually block flank cells (2x2 bosses are always kept)
        in_b = [s for s in flat if s in boss2x2]
        in_r = [s for s in flat if s not in boss2x2]
        flat = in_b + in_r[:max(1, 7 - len(in_b))]
        cells = _place(flat, boss2x2)
        for i, slug in enumerate(flat):
            counters[slug] = counters.get(slug, 0) + 1
            node = f"{slug.title().replace('_', '')}{counters[slug]}"
            x, y = tile(*cells[i])
            lines += [f'[node name="{node}" parent="Board/EnemyPhases/Phase{p}" index="{i}" instance=ExtResource( {ids[slug]} )]',
                      f"position = Vector2( {x}, {y} )", ""]
    return "\n".join(lines)


def make_art(name, token, boss2x2=False):
    src = os.path.join(ENEMY_ART, hslug(name) + ".png")
    if not os.path.exists(src):
        return False
    full_dst = os.path.join(ROOT, "assets", "terra", "full", token + "_full.png")
    tok_dst = os.path.join(ROOT, "assets", "terra", "tokens", token + "_token.png")
    subprocess.run(["sips", "-s", "format", "png", src, "--out", full_dst],
                   stdout=DEVNULL, stderr=DEVNULL, check=True)
    from PIL import Image
    im = Image.open(full_dst).convert("RGBA")
    if boss2x2:
        # 2x2 icon shows the whole boss, fit into a square with transparent pad
        s = max(im.size)
        sq = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        sq.paste(im, ((s - im.width) // 2, (s - im.height) // 2))
        sq.resize((420, 420)).save(tok_dst)
    else:
        w, h = im.size
        s = min(w, h)
        left = (w - s) // 2
        im.crop((left, 0, left + s, s)).resize((220, 220)).save(tok_dst)
    return True


# ---------------------------------------------------------------- main
def main():
    chapter_num = int(sys.argv[1])
    data = json.load(open(DATASET))
    best = data["bestiary"]
    chapter = next(c for c in data["chapters"] if c["num"] == chapter_num)
    with_enemies = [s for s in chapter["stages"]
                    if any(b["enemies"] for b in s.get("battles_detail", []))]
    if with_enemies:
        stage = with_enemies[-1]                       # last real stage = the playable battle
    elif chapter.get("recovered_enemy_keys"):          # stub chapter, recovered stats only
        stage = dict(chapter["stages"][-1], battles_detail=synth_battles(chapter, best))
    else:
        print(f"SKIP Ch{chapter_num} {chapter['name']}: no enemy data (wiki stub)")
        return
    title = re.sub(r"[^A-Z0-9]+", "_", chapter["name"].upper()).strip("_")
    slug_ch = title.lower()
    print(f"Generating Ch{chapter_num} {chapter['name']} -> {title} (stage {stage['id']})")

    # 1. collect unique enemies in the final stage
    enemies = {}
    for btl in stage["battles_detail"]:
        for e in btl["enemies"]:
            k = e["enemy_key"]
            if k and k not in enemies:
                enemies[k] = best[k]
    if not enemies:
        print(f"SKIP Ch{chapter_num} {chapter['name']}: no matchable enemies")
        return
    print(f"  {len(enemies)} unique enemies")

    # 2. resolve engine skills per enemy. AI skills (offensive/heal) drive the
    #    AIController; counters are passive and go in the job only.
    needed_skills, enemy_ai_skills, enemy_job_skills = {}, {}, {}
    for k, e in enemies.items():
        weapon = WEAPON.get(e["weapon"], SWORD)
        ai, has_counter = [], False
        for s in e["skills"]:
            if "counter" in s["name"].lower():
                has_counter = True
                continue
            spec = SKILL_SPECS.get(s["name"]) or derive_skill(s, weapon)
            ai.append(spec[0])
            needed_skills[spec[0]] = spec
        if not ai:                                     # ensure the AI has an action
            spec = SKILL_SPECS[WEAPON_DEFAULT_SKILL[weapon]]
            ai = [spec[0]]
            needed_skills[spec[0]] = spec
        ai = list(dict.fromkeys(ai))[:4]               # cap AI actions per enemy
        enemy_ai_skills[k] = ai
        job = list(ai)
        if has_counter:
            needed_skills[COUNTER_SPEC[0]] = COUNTER_SPEC
            job.append(COUNTER_SPEC[0])
        enemy_job_skills[k] = job

    # 3. write skills
    for slug, (sl, disp, stype, aoe, power, rate, pusher, weapon, attr, eff) in needed_skills.items():
        write(f"skills/resources/terra/{slug}.tres", SKILL_T.format(
            name=disp, stype=stype, aoe=aoe, rate=rate, pusher=str(pusher).lower(),
            power=power, weapon=weapon, attr=attr, effect=EFFECTS[eff]))

    # 4. per enemy: stats, art, job, enemy scene
    weapon_counts = {"sword": 0, "gun": 0, "spear": 0, "staff": 0}
    wname = {SWORD: "sword", BOW: "gun", SPEAR: "spear", STAFF: "staff"}
    boss2x2 = set()
    art_ok, art_missing, n_2x2, n_counter = 0, [], 0, 0
    for k, e in enemies.items():
        slug = uslug(e["name"])
        lv = e["level"] or 1
        weapon = WEAPON.get(e["weapon"], SWORD)
        etype = e.get("enemy_type") or ""
        is_2x2 = etype.endswith("2x2")
        is_boss1x1 = etype == "Boss 1x1"
        if is_2x2:
            boss2x2.add(slug)
            n_2x2 += 1
        write(f"stats/terra/{slug}_stats.tres", STATS_T.format(
            display=title_name(e["name"]), hp=pct(e["hp"], lv, 1500),
            atk=pct(e["atk"], lv, 50), deff=pct(e["def"], lv, 50),
            matk=pct(e["matk"], lv, 50), mdef=pct(e["mdef"], lv, 50),
            vuln=vuln_from(e["avoids"]), attr=attr_id(e["attribute"]),
            weapon=weapon, counter=e["move"] or 4, move=4))

        token = slug if make_art(e["name"], slug, boss2x2=is_2x2) else "orbling"
        if token == slug:
            art_ok += 1
        else:
            art_missing.append(e["name"])

        ai_slugs = enemy_ai_skills[k]
        job_slugs = enemy_job_skills[k]
        if len(job_slugs) > len(ai_slugs):
            n_counter += 1
        # job (carries AI skills + any passive counter)
        jr, jrefs = [], []
        for i, s in enumerate(job_slugs):
            jr.append(f'[ext_resource path="res://skills/resources/terra/{s}.tres" type="Resource" id={5 + i}]')
            jrefs.append(f"ExtResource( {5 + i} )")
        write(f"jobs/terra/{slug}_job.tres", JOB_T.format(
            steps=5 + len(job_slugs), slug=slug, token=token,
            skill_res="\n".join(jr) + ("\n" if jr else ""),
            skill_refs=", ".join(jrefs), display=enemy_display(e["name"])))
        # enemy scene — AI actions use only the offensive/heal skills
        if is_2x2:
            res, blocks = actions_block(ai_slugs, start_id=20)
            scene = ENEMY_2X2_T.format(
                steps=8 + len(ai_slugs), slug=slug, node=node_name(e["name"]),
                level=lv, counter=e["move"] or 4, display=enemy_display(e["name"]),
                skill_res="\n".join(res), actions="\n".join(blocks))
        else:
            res, blocks = actions_block(ai_slugs, start_id=6)
            border, steps = "", 6 + len(ai_slugs)
            if is_boss1x1:
                res.append('[ext_resource path="res://assets/terra/ui/boss_border.png" type="Texture2D" id=9]')
                border = '[node name="Border" parent="Sprite2D" index="2"]\ntexture = ExtResource( 9 )\n\n'
                steps += 1
            scene = ENEMY_T.format(
                steps=steps, slug=slug, token=token, node=node_name(e["name"]),
                level=lv, counter=e["move"] or 4, display=enemy_display(e["name"]),
                border=border, skill_res="\n".join(res), actions="\n".join(blocks))
        write(f"units/enemies/terra/{slug}.tscn", scene)
        weapon_counts[wname[weapon]] += 1

    # 5. battle scene (phases = battles)
    phases = []
    for btl in stage["battles_detail"]:
        ph = []
        for e in btl["enemies"]:
            if e["enemy_key"]:
                ph.append((uslug(best[e["enemy_key"]]["name"]), e["count"]))
        phases.append(ph)
    max_lv = max((e["level"] or 1) for e in enemies.values())
    # party gets a small level edge so it can burst high-HP 2x2 bosses
    write(f"battles/terra/{slug_ch}.tscn", battle_scene(phases, max_lv + 3, boss2x2))

    # 6. chapter resource + difficulty
    recs = [s["rec_level"] for s in chapter["stages"] if s["rec_level"]]
    difficulty = f"{min(recs)}-{max(recs)}" if recs else "?"
    write(f"chapter_data/terra/{slug_ch}.tres", CHAPTER_T.format(
        title=title, caption=f"{title}_CAPTION", difficulty=difficulty,
        scene=slug_ch, phases=len(phases), **weapon_counts))

    print(f"  art: {art_ok} ok, {len(art_missing)} missing {art_missing or ''}")
    print(f"  2x2 bosses: {n_2x2}, enemies with counters: {n_counter}")
    print(f"  weapons: {weapon_counts}, difficulty {difficulty}, phases {len(phases)}")
    print(f"DONE. Now run: register chapter, add text, import, verify.")
    # emit machine-readable summary for the wrapper step
    json.dump({"title": title, "slug": slug_ch, "difficulty": difficulty,
               "scene": f"res://battles/terra/{slug_ch}.tscn",
               "enemies": [e["name"] for e in enemies.values()],
               "art_missing": art_missing},
              open(os.path.join(ROOT, "tools", "out", f"gen_{slug_ch}.json"), "w"), indent=1)


def title_name(name):
    return re.sub(r"[^A-Z0-9 ]+", "", name.upper())


def enemy_display(name):
    return name.upper().replace("'", "")


def node_name(name):
    return re.sub(r"[^A-Za-z0-9]", "", name)


if __name__ == "__main__":
    main()
