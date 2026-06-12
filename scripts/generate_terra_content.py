#!/usr/bin/env python3
"""Generates the Terra Battle fan-recreation content: stats, skills, jobs,
enemy scenes, battle scenes, chapter data, translations and default save.

Stat sources: Terra Battle wiki enemy data module / character pages, as
documented in docs/gameplay/stages-1-2.md and assets/terra/characters/manifest.json.

The engine computes a stat as: level * base * 0.1 * percentage
(base HP 1500, base other stats 50), so percentage = wiki_value / (level * base * 0.1).
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Weapon types: SWORD=0 GUN(bow)=1 SPEAR=2 STAFF=3
SWORD, BOW, SPEAR, STAFF = 0, 1, 2, 3
# Attributes: NONE=0 ATTRIBUTE_1(lightning)=1 ATTRIBUTE_2(fire)=2
NONE, LIGHTNING, FIRE = 0, 1, 2
# Skill types (enums.gd SkillType): ATTACK=0 HEAL=1 ...
ST_ATTACK, ST_HEAL = 0, 1
# AreaOfEffect enum indices (enums.gd)
AOE_NONE, AOE_EQUIP, AOE_PINCER, AOE_AREA_X, AOE_CROSS_X, AOE_SELF, AOE_HORIZONTAL_X, AOE_VERTICAL_X = 0, 1, 2, 3, 4, 5, 6, 7

def pct(value, level, base):
    return round(value / (level * base * 0.1), 4)


def write(path, content):
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w") as f:
        f.write(content)
    print("wrote", path)


# ---------------------------------------------------------------- stats
# name: (display, type, level, hp, atk, deff, matk, mdef, weapon, attribute,
#        max_turn_counter, vulnerability, movement_range)
PLAYERS = {
    "bahl":      ("BAHL", "HUMAN", 1, 321, 31, 26, 13, 15, SWORD, NONE),
    "grace":     ("GRACE", "HUMAN", 1, 318, 31, 24, 15, 17, BOW, NONE),
    "kuscah":    ("KUSCAH", "HUMAN", 1, 293, 12, 17, 29, 26, STAFF, NONE),
    "shberdan":  ("SHBERDAN", "LIZARDFOLK", 1, 317, 29, 24, 29, 21, SPEAR, NONE),
    "daiana":    ("DAIANA", "STONEFOLK", 1, 317, 18, 20, 37, 28, STAFF, FIRE),
    "macuri":    ("MACURI", "LIZARDFOLK", 1, 318, 40, 25, 12, 14, SPEAR, NONE),
}

ENEMIES = {
    # slug: (display, lv, hp, atk, def, matk, mdef, weapon, attr, counter, vuln, move_range)
    "wee_orbling_sword": ("WEE_ORBLING", 1, 85, 13, 3, 10, 11, SWORD, NONE, 5, 0.8, 5),
    "wee_orbling_spear": ("WEE_ORBLING", 1, 88, 14, 3, 10, 12, SPEAR, NONE, 5, 0.8, 5),
    "wee_orbling_bow":   ("WEE_ORBLING", 1, 84, 13, 4, 10, 12, BOW, NONE, 5, 0.8, 5),
    "orbling_boss":      ("ORBLING", 3, 101, 21, 4, 12, 15, SWORD, NONE, 4, 0.0, 5),
    "gorf":              ("GORF", 4, 158, 28, 16, 26, 21, STAFF, NONE, 6, 0.5, 6),
    "dracorin":          ("DRACORIN", 5, 411, 28, 28, 34, 28, BOW, LIGHTNING, 4, 0.6, 4),
    "sabertooth":        ("SABERTOOTH", 6, 425, 32, 34, 15, 24, SPEAR, NONE, 4, 0.8, 4),
    "spinetrich":        ("SPINETRICH", 9, 3949, 36, 49, 38, 51, SPEAR, LIGHTNING, 3, 0.0, 4),
}

STATS_TEMPLATE = """[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://stats/stats.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
unit_name = "{display}"
unit_type = "{unit_type}"
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
can_randomize_turn_counter = {rand_counter}
movement_range = {move}
skill_activation_rate_modifier = 0.0
"""

for slug, (display, unit_type, lv, hp, atk, deff, matk, mdef, weapon, attr) in PLAYERS.items():
    write(f"stats/terra/{slug}_stats.tres", STATS_TEMPLATE.format(
        display=display, unit_type=unit_type,
        hp=pct(hp, lv, 1500), atk=pct(atk, lv, 50), deff=pct(deff, lv, 50),
        matk=pct(matk, lv, 50), mdef=pct(mdef, lv, 50),
        vuln=1.0, attr=attr, weapon=weapon, counter=1, rand_counter="false", move=5))

for slug, (display, lv, hp, atk, deff, matk, mdef, weapon, attr, counter, vuln, move) in ENEMIES.items():
    write(f"stats/terra/{slug}_stats.tres", STATS_TEMPLATE.format(
        display=display, unit_type="MONSTER",
        hp=pct(hp, lv, 1500), atk=pct(atk, lv, 50), deff=pct(deff, lv, 50),
        matk=pct(matk, lv, 50), mdef=pct(mdef, lv, 50),
        vuln=vuln, attr=attr, weapon=weapon, counter=counter,
        rand_counter="true", move=move))

# ---------------------------------------------------------------- skills
EFFECTS = {
    "hit": "res://skills/effects/simple_hit_skill_effect.tscn",
    "spear": "res://skills/effects/simple_spear_skill_effect.tscn",
    "shoot": "res://skills/effects/shooting_skill_effect.tscn",
    "heal": "res://skills/effects/heal_skill_effect.tscn",
    "sweep": "res://skills/effects/sweep_skill_effect.tscn",
}

SKILL_TEMPLATE = """[gd_resource type="Resource" load_steps=3 format=2]

[ext_resource path="res://skills/skill.gd" type="Script" id=1]
[ext_resource path="{effect}" type="PackedScene" id=2]

[resource]
script = ExtResource( 1 )
skill_name = "{name}"
skill_type = {skill_type}
area_of_effect = {aoe}
area_of_effect_size = {aoe_size}
activation_rate = {rate}
is_pusher = {pusher}
primary_power = {power}
primary_weapon_type = {weapon}
primary_attribute = {attr}
secondary_power = 0.0
secondary_weapon_type = 1
secondary_attribute = 0
absorb_rate = 0.0
max_heal = {max_heal}
status_effects = [  ]
status_effect_infliction_rate = 0.3
cured_status_effects = [  ]
effect_scene = ExtResource( 2 )
is_delayed = false
"""

SKILLS = {
    # slug: (name, type, aoe, size, rate, pusher, power, weapon, attr, effect)
    "slash":          ("SLASH", ST_ATTACK, AOE_HORIZONTAL_X, 1, 0.3, False, 1.5, SWORD, NONE, "hit"),
    "sever":          ("SEVER", ST_ATTACK, AOE_HORIZONTAL_X, 1, 0.4, True, 1.5, SWORD, NONE, "sweep"),
    "stab":           ("STAB", ST_ATTACK, AOE_VERTICAL_X, 1, 0.3, False, 1.5, SPEAR, NONE, "spear"),
    "stab_player":    ("STAB", ST_ATTACK, AOE_VERTICAL_X, 1, 0.4, False, 1.5, SPEAR, NONE, "spear"),
    "arrow":          ("ARROW", ST_ATTACK, AOE_AREA_X, 1, 0.3, False, 1.5, BOW, NONE, "shoot"),
    "arrow_player":   ("ARROW", ST_ATTACK, AOE_AREA_X, 1, 0.4, False, 1.5, BOW, NONE, "shoot"),
    "heal_gorf":      ("HEAL", ST_HEAL, AOE_AREA_X, 1, 1.0, False, 1.5, STAFF, NONE, "heal"),
    "heal_kuscah":    ("HEAL", ST_HEAL, AOE_AREA_X, 1, 0.6, False, 1.5, STAFF, NONE, "heal"),
    "fire":           ("FIRE", ST_ATTACK, AOE_CROSS_X, 1, 0.4, False, 1.0, STAFF, FIRE, "hit"),
    "thunder_arrows": ("THUNDER_ARROWS", ST_ATTACK, AOE_CROSS_X, 1, 0.3, False, 1.0, BOW, LIGHTNING, "shoot"),
    "thrust_away":    ("THRUST_AWAY", ST_ATTACK, AOE_VERTICAL_X, 1, 0.3, True, 1.0, SPEAR, NONE, "spear"),
    "discharge":      ("DISCHARGE", ST_ATTACK, AOE_AREA_X, 1, 0.3, False, 2.0, STAFF, LIGHTNING, "hit"),
}

for slug, (name, stype, aoe, size, rate, pusher, power, weapon, attr, effect) in SKILLS.items():
    write(f"skills/resources/terra/{slug}.tres", SKILL_TEMPLATE.format(
        name=name, skill_type=stype, aoe=aoe, aoe_size=size, rate=rate,
        pusher="true" if pusher else "false", power=power, weapon=weapon,
        attr=attr, max_heal=700, effect=EFFECTS[effect]))

# ---------------------------------------------------------------- jobs
JOB_TEMPLATE = """[gd_resource type="Resource" load_steps={steps} format=2]

[ext_resource path="res://jobs/job.gd" type="Script" id=1]
[ext_resource path="res://stats/terra/{slug}_stats.tres" type="Resource" id=2]
[ext_resource path="res://assets/terra/tokens/{token}_token.png" type="Texture2D" id=3]
[ext_resource path="res://assets/terra/full/{token}_full.png" type="Texture2D" id=4]
{skill_resources}
[resource]
script = ExtResource( 1 )
stats = ExtResource( 2 )
skills = [ {skill_refs} ]
job_name = "{job_name}"
portrait = ExtResource( 3 )
full_portrait = ExtResource( 4 )
"""

# job slug: (token, job display key, [skill slugs])
JOBS = {
    "bahl":      ("bahl", "JOB_DARK_DUELIST", ["sever"]),
    "grace":     ("grace", "JOB_ARCHER", ["arrow_player"]),
    "kuscah":    ("kuscah", "JOB_ACOLYTE", ["heal_kuscah"]),
    "shberdan":  ("shberdan", "JOB_MALODOROUS", ["stab_player"]),
    "daiana":    ("daiana", "JOB_FIREDRINKER", ["fire"]),
    "macuri":    ("macuri", "JOB_TORMENTED", ["stab_player"]),
    "wee_orbling_sword": ("orbling", "WEE_ORBLING", ["slash"]),
    "wee_orbling_spear": ("orbling", "WEE_ORBLING", ["stab"]),
    "wee_orbling_bow":   ("orbling", "WEE_ORBLING", ["arrow"]),
    "orbling_boss":      ("orbling", "ORBLING", ["slash"]),
    "gorf":              ("gorf", "GORF", ["heal_gorf"]),
    "dracorin":          ("dracorin", "DRACORIN", ["thunder_arrows"]),
    "sabertooth":        ("sabertooth", "SABERTOOTH", ["stab", "thrust_away"]),
    "spinetrich":        ("spinetrich", "SPINETRICH", ["stab", "thrust_away", "discharge", "slash"]),
}

for slug, (token, job_name, skill_slugs) in JOBS.items():
    skill_lines = []
    refs = []
    for i, s in enumerate(skill_slugs):
        skill_lines.append(f'[ext_resource path="res://skills/resources/terra/{s}.tres" type="Resource" id={5 + i}]')
        refs.append(f"ExtResource( {5 + i} )")
    write(f"jobs/terra/{slug}_job.tres", JOB_TEMPLATE.format(
        steps=5 + len(skill_slugs), slug=slug, token=token,
        skill_resources="\n".join(skill_lines) + ("\n" if skill_lines else ""),
        skill_refs=", ".join(refs), job_name=job_name))

# ---------------------------------------------------------------- enemy scenes
ENEMY_SCENE_TEMPLATE = """[gd_scene load_steps=6 format=2]

[ext_resource path="res://units/enemy.tscn" type="PackedScene" id=1]
[ext_resource path="res://jobs/terra/{slug}_job.tres" type="Resource" id=2]
[ext_resource path="res://assets/terra/tokens/{token}_token.png" type="Texture2D" id=3]
[ext_resource path="res://units/ai/condition.tscn" type="PackedScene" id=4]
[ext_resource path="res://units/ai/action.tscn" type="PackedScene" id=5]

[node name="{node_name}" instance=ExtResource( 1 )]
level = {level}
turn_counter = {turn_counter}

[node name="Job" parent="." index="2"]
job = ExtResource( 2 )

[node name="Icon" parent="Sprite2D" index="1"]
texture = ExtResource( 3 )

{border_override}[node name="UnitName" parent="CanvasLayer" index="3"]
text = "{display}"

{actions}
[editable path="CanvasLayer/ActivatedSkillMarginContainer"]
"""

# Behaviors (units/ai/action.gd): assumed 0=NONE,1=USE_SKILL,2=MOVE per prototype scenes
def actions_block(skill_slugs, start_id=6):
    blocks = []
    res_lines = []
    for i, s in enumerate(skill_slugs):
        res_lines.append(f'[ext_resource path="res://skills/resources/terra/{s}.tres" type="Resource" id={start_id + i}]')
        blocks.append(f"""[node name="Action{i + 1}" parent="AIController" index="{i}" instance=ExtResource( 5 )]
behavior = 1
skill = ExtResource( {start_id + i} )

[node name="Condition" parent="AIController/Action{i + 1}" index="0" instance=ExtResource( 4 )]
""")
    move_index = len(skill_slugs)
    blocks.append(f"""[node name="ActionMove" parent="AIController" index="{move_index}" instance=ExtResource( 5 )]
behavior = 2
weight = 3

[node name="Condition" parent="AIController/ActionMove" index="0" instance=ExtResource( 4 )]
""")
    return res_lines, blocks

ENEMY_SCENES = {
    "wee_orbling_sword": "WeeOrblingSword",
    "wee_orbling_spear": "WeeOrblingSpear",
    "wee_orbling_bow": "WeeOrblingBow",
    "orbling_boss": "OrblingBoss",
    "gorf": "Gorf",
    "dracorin": "Dracorin",
    "sabertooth": "Sabertooth",
}

for slug, node_name in ENEMY_SCENES.items():
    display = JOBS[slug][1]
    skill_slugs = JOBS[slug][2]
    token = JOBS[slug][0]
    enemy_level = ENEMIES[slug][1]
    enemy_counter = ENEMIES[slug][9]
    res_lines, blocks = actions_block(skill_slugs)
    # 1x1 bosses get the golden frame
    border_override = ""
    if slug == "orbling_boss":
        res_lines.append('[ext_resource path="res://assets/terra/ui/boss_border.png" type="Texture2D" id=9]')
        border_override = '[node name="Border" parent="Sprite2D" index="2"]\ntexture = ExtResource( 9 )\n\n'
    scene = ENEMY_SCENE_TEMPLATE.format(
        slug=slug, node_name=node_name, display=display, level=enemy_level,
        turn_counter=enemy_counter, token=token, border_override=border_override,
        actions="\n".join(blocks))
    # splice extra ext_resources for skills after id=5 line
    scene = scene.replace('[ext_resource path="res://units/ai/action.tscn" type="PackedScene" id=5]',
                          '[ext_resource path="res://units/ai/action.tscn" type="PackedScene" id=5]\n' + "\n".join(res_lines))
    scene = scene.replace("load_steps=6", f"load_steps={6 + len(skill_slugs) + (1 if border_override else 0)}")
    write(f"units/enemies/terra/{slug}.tscn", scene)

# Spinetrich is a 2x2 boss: based on the enemy_2x2 layout
SPINETRICH_SKILLS = JOBS["spinetrich"][2]
res_lines, blocks = actions_block(SPINETRICH_SKILLS, start_id=20)
SPINETRICH_SCENE = """[gd_scene load_steps={steps} format=2]

[ext_resource path="res://units/enemy.tscn" type="PackedScene" id=2]
[ext_resource path="res://jobs/terra/spinetrich_job.tres" type="Resource" id=3]
[ext_resource path="res://assets/ui/enemy_border_2x2.png" type="Texture2D" id=9]
[ext_resource path="res://assets/ui/unit_square_bg_2x2.png" type="Texture2D" id=10]
[ext_resource path="res://units/ai/condition.tscn" type="PackedScene" id=4]
[ext_resource path="res://units/ai/action.tscn" type="PackedScene" id=5]
{res_lines}

[sub_resource type="RectangleShape2D" id=1]
extents = Vector2( 80, 80 )

[sub_resource type="RectangleShape2D" id=3]
extents = Vector2( 96.5, 96.5 )

[node name="Spinetrich" instance=ExtResource( 2 )]
size = 1
level = 9
turn_counter = 3

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
text = "SPINETRICH"

[node name="Sprite2D" parent="CanvasLayer/UnitName" index="0"]
position = Vector2( 48, 48 )

{actions}
[editable path="CanvasLayer/ActivatedSkillMarginContainer"]
""".format(steps=8 + len(SPINETRICH_SKILLS), res_lines="\n".join(res_lines), actions="\n".join(blocks))
write("units/enemies/terra/spinetrich.tscn", SPINETRICH_SCENE)

# ---------------------------------------------------------------- battle scenes
def tile(col, row):
    """Tile origin in pixels for the 6x8 grid (100px tiles)."""
    return (50 + 100 * col, 50 + 100 * row)

def battle_scene(name, fixed_level, phases, icon_id_map):
    """phases: list of list of (enemy_slug, col, row)."""
    used = sorted({slug for phase in phases for (slug, _, _) in phase})
    lines = [f'[gd_scene load_steps={2 + len(used)} format=2]', ""]
    lines.append('[ext_resource path="res://board/battle.tscn" type="PackedScene" id=1]')
    ids = {}
    for i, slug in enumerate(used):
        ids[slug] = 10 + i
        lines.append(f'[ext_resource path="res://units/enemies/terra/{slug}.tscn" type="PackedScene" id={10 + i}]')
    lines.append("")
    lines.append(f'[node name="BoardUI" instance=ExtResource( 1 )]')
    lines.append("")
    lines.append('[node name="Board" parent="." index="0"]')
    lines.append(f"fixed_player_units_level = {fixed_level}")
    lines.append("")
    counters = {}
    for p, phase in enumerate(phases, start=1):
        lines.append(f'[node name="Phase{p}" parent="Board/EnemyPhases" index="{p - 1}"]')
        lines.append("visible = false")
        lines.append("")
        for i, (slug, col, row) in enumerate(phase):
            counters[slug] = counters.get(slug, 0) + 1
            node_name = f"{slug.title().replace('_', '')}{counters[slug]}"
            x, y = tile(col, row)
            lines.append(f'[node name="{node_name}" parent="Board/EnemyPhases/Phase{p}" index="{i}" instance=ExtResource( {ids[slug]} )]')
            lines.append(f"position = Vector2( {x}, {y} )")
            lines.append("")
    return "\n".join(lines)

# Stage 1 - Borderlands (chapter 1-5 layout: 3 battles, boss at the end)
STAGE_1 = [
    [("wee_orbling_sword", 1, 2), ("wee_orbling_spear", 4, 3)],
    [("wee_orbling_bow", 2, 1), ("wee_orbling_sword", 3, 4)],
    [("wee_orbling_bow", 1, 1), ("wee_orbling_spear", 4, 1), ("orbling_boss", 2, 2)],
]

# Stage 2 - To the Capital (chapter 2-5 layout: 5 battles, Spinetrich finale)
STAGE_2 = [
    [("sabertooth", 1, 1), ("sabertooth", 4, 1), ("gorf", 2, 3)],
    [("sabertooth", 0, 2), ("sabertooth", 5, 2), ("dracorin", 2, 1), ("gorf", 3, 3)],
    [("dracorin", 1, 1), ("dracorin", 4, 1), ("dracorin", 2, 3), ("dracorin", 3, 2)],
    [("sabertooth", 1, 2), ("sabertooth", 4, 2), ("dracorin", 2, 1), ("dracorin", 3, 1), ("gorf", 2, 4)],
    [("sabertooth", 0, 1), ("sabertooth", 5, 1), ("spinetrich", 2, 1)],
]

write("battles/terra/borderlands.tscn", battle_scene("Borderlands", 1, STAGE_1, {}))
write("battles/terra/to_the_capital.tscn", battle_scene("ToTheCapital", 4, STAGE_2, {}))

# ---------------------------------------------------------------- chapters
CHAPTER_TEMPLATE = """[gd_resource type="Resource" load_steps=4 format=2]

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

def battle_info(phases):
    weapons = {"sword": 0, "gun": 0, "spear": 0, "staff": 0}
    weapon_of = {
        "wee_orbling_sword": "sword", "wee_orbling_spear": "spear", "wee_orbling_bow": "gun",
        "orbling_boss": "sword", "gorf": "staff", "dracorin": "gun",
        "sabertooth": "spear", "spinetrich": "spear",
    }
    for phase in phases:
        for slug, _, _ in phase:
            weapons[weapon_of[slug]] += 1
    return weapons

w1 = battle_info(STAGE_1)
write("chapter_data/terra/borderlands.tres", CHAPTER_TEMPLATE.format(
    title="BORDERLANDS", caption="BORDERLANDS_CAPTION", difficulty="1-4",
    scene="borderlands", phases=len(STAGE_1), **w1))
w2 = battle_info(STAGE_2)
write("chapter_data/terra/to_the_capital.tres", CHAPTER_TEMPLATE.format(
    title="TO_THE_CAPITAL", caption="TO_THE_CAPITAL_CAPTION", difficulty="5-6",
    scene="to_the_capital", phases=len(STAGE_2), **w2))

write("chapter_data/main_story_chapter_list.tres", """[gd_resource type="Resource" load_steps=4 format=2]

[ext_resource path="res://chapter_data/chapter_list.gd" type="Script" id=1]
[ext_resource path="res://chapter_data/terra/borderlands.tres" type="Resource" id=2]
[ext_resource path="res://chapter_data/terra/to_the_capital.tres" type="Resource" id=3]

[resource]
script = ExtResource( 1 )
chapters = [ ExtResource( 2 ), ExtResource( 3 ) ]
""")

# ---------------------------------------------------------------- default save
SAVE_TEMPLATE_HEAD = """[gd_resource type="Resource" load_steps={steps} format=2]

[ext_resource path="res://save_data/save_data.gd" type="Script" id=1]
"""
job_slugs = ["bahl", "grace", "kuscah", "shberdan", "daiana", "macuri"]
lines = [SAVE_TEMPLATE_HEAD.format(steps=2 + len(job_slugs))]
for i, slug in enumerate(job_slugs):
    lines.append(f'[ext_resource path="res://jobs/terra/{slug}_job.tres" type="Resource" id={2 + i}]')
lines.append("")
lines.append("[resource]")
lines.append("script = ExtResource( 1 )")
lines.append("version = 1")
lines.append("jobs = [ " + ", ".join(f"ExtResource( {2 + i} )" for i in range(len(job_slugs))) + " ]")
lines.append("active_units = [ 0, 1, 2, 3 ]")
lines.append("music_volume = 1.0")
lines.append("sound_effects_volume = 1.0")
lines.append('locale = ""')
lines.append("drag_mode = 0")
write("save_data/default_save_data.tres", "\n".join(lines) + "\n")

print("done")
