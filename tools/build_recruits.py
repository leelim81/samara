#!/usr/bin/env python3
"""Build the 19 samara recruits as playable units from a fetched TB manifest.

Input: a JSON manifest (list of units) produced by the fetch-recruit-tb-units
workflow, each entry:
  { recruit, tb_unit, slug, weapon, tb_class, attribute, hp,atk,def,matk,mdef,
    stat_level, token_url, full_url, download_ok }

For each unit it:
  - downloads token_url + full_url from the Fandom CDN, converts WebP->PNG, and
    writes assets/terra/tokens/<slug>_token.png + assets/terra/full/<slug>_full.png
  - writes stats/terra/<slug>_stats.tres (authentic TB stats via the engine's
    percentage formula) and jobs/terra/<slug>_job.tres (samara name key + a
    weapon-appropriate existing skill)
  - records text.csv name key (CHAR_<RECRUIT> -> samara display name) and a
    banter _ICONS entry (samara name -> token)

Then it patches text/text.csv and ui/cutscenes/dialogue_message_container.gd.
Art is a placeholder (real TB image) the user will later swap KEEPING the filename.

Usage: python3 tools/build_recruits.py /tmp/recruits_manifest.json
Then:  godot --headless --import   (imports the new PNGs + recompiles text.csv)
"""
import json
import os
import re
import subprocess
import sys
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/120 Safari/537.36"

WEAPON = {"sword": 0, "bow": 1, "spear": 2, "staff": 3}
# one existing skill per weapon so each job is functional (no new skills authored)
SKILL = {0: "sever", 1: "arrow_player", 2: "stab_player", 3: "heal_kuscah"}
ATTR = {"none": 0, "lightning": 1, "fire": 2, "ice": 3, "darkness": 4, "dark": 4,
        "healing": 9, "remedy": 9, "water": 0, "wind": 0, "light": 0, "": 0, None: 0}

STATS_T = '''[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://stats/stats.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
unit_name = "{key}"
unit_type = "HUMAN"
health_percentage = {hp}
attack_percentage = {atk}
defense_percentage = {deff}
spiritual_attack_percentage = {matk}
spiritual_defense_percentage = {mdef}
status_ailment_vulnerability = 1.0
status_ailment_vulnerabilities = {{
}}
same_attribute_resistance = 0.5
attribute = {attr}
weapon_type = {weapon}
max_turn_counter = 1
can_randomize_turn_counter = false
movement_range = 5
skill_activation_rate_modifier = 0.0
'''

JOB_T = '''[gd_resource type="Resource" load_steps=6 format=2]

[ext_resource path="res://jobs/job.gd" type="Script" id=1]
[ext_resource path="res://stats/terra/{slug}_stats.tres" type="Resource" id=2]
[ext_resource path="res://assets/terra/tokens/{slug}_token.png" type="Texture2D" id=3]
[ext_resource path="res://assets/terra/full/{slug}_full.png" type="Texture2D" id=4]
[ext_resource path="res://skills/resources/terra/{skill}.tres" type="Resource" id=5]

[resource]
script = ExtResource( 1 )
stats = ExtResource( 2 )
skills = [ ExtResource( 5 ) ]
job_name = "{key}"
portrait = ExtResource( 3 )
full_portrait = ExtResource( 4 )
'''


def pct(value, level, base):
    return round(float(value) / (level * base * 0.1), 4)


def key_of(recruit):
    return "CHAR_" + re.sub(r"[^A-Z0-9]+", "_", recruit.upper()).strip("_")


def dl_png(url, dest):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Referer": "https://terrabattle.fandom.com/"})
    data = urllib.request.urlopen(req, timeout=30).read()
    tmp = dest + ".dl"
    with open(tmp, "wb") as f:
        f.write(data)
    try:
        Image.open(tmp).convert("RGBA").save(dest)  # PIL, if webp supported
    except Exception:
        subprocess.run(["sips", "-s", "format", "png", tmp, "--out", dest],
                       check=True, capture_output=True)  # macOS fallback (handles webp)
    os.remove(tmp)


def main():
    manifest = json.load(open(sys.argv[1] if len(sys.argv) > 1 else "/tmp/recruits_manifest.json"))
    if isinstance(manifest, dict):
        manifest = manifest.get("manifest", [])

    csv_rows, icon_rows, built, skipped = [], [], [], []
    for u in manifest:
        slug = re.sub(r"[^a-z0-9]+", "", u["slug"].lower())
        recruit = u["recruit"]
        if not u.get("download_ok", False):
            skipped.append((recruit, "download_ok=false"))
            continue
        try:
            dl_png(u["token_url"], os.path.join(ROOT, f"assets/terra/tokens/{slug}_token.png"))
            dl_png(u["full_url"], os.path.join(ROOT, f"assets/terra/full/{slug}_full.png"))
        except Exception as e:
            skipped.append((recruit, "art download failed: %s" % e))
            continue

        key = key_of(recruit)
        lv = int(u.get("stat_level", 1)) or 1
        w = WEAPON.get(u["weapon"].lower(), 0)
        a = ATTR.get((u.get("attribute") or "none").lower(), 0)
        with open(os.path.join(ROOT, f"stats/terra/{slug}_stats.tres"), "w") as f:
            f.write(STATS_T.format(key=key, hp=pct(u["hp"], lv, 1500), atk=pct(u["atk"], lv, 50),
                                   deff=pct(u["def"], lv, 50), matk=pct(u["matk"], lv, 50),
                                   mdef=pct(u["mdef"], lv, 50), attr=a, weapon=w))
        with open(os.path.join(ROOT, f"jobs/terra/{slug}_job.tres"), "w") as f:
            f.write(JOB_T.format(slug=slug, key=key, skill=SKILL[w]))

        csv_rows.append("%s,%s,%s" % (key, recruit, recruit))
        icon_rows.append('\t"%s": "res://assets/terra/tokens/%s_token.png",' % (recruit, slug))
        built.append((recruit, slug, u["tb_unit"]))

    # patch text.csv (append name keys)
    csv_path = os.path.join(ROOT, "text/text.csv")
    with open(csv_path, "a") as f:
        f.write("\n".join(csv_rows) + "\n")

    # patch banter _ICONS: insert before the closing brace of the const dict
    gd_path = os.path.join(ROOT, "ui/cutscenes/dialogue_message_container.gd")
    gd = open(gd_path).read()
    anchor = '\t"Timely Rain": "res://assets/terra/tokens/mizell_token.png"'
    gd = gd.replace(anchor, anchor + ",\n" + "\n".join(icon_rows).rstrip(","))
    open(gd_path, "w").write(gd)

    print("BUILT %d recruits:" % len(built))
    for r, s, t in built:
        print("  %-26s -> %s (TB: %s)" % (r, s, t))
    if skipped:
        print("SKIPPED %d:" % len(skipped))
        for r, why in skipped:
            print("  %-26s %s" % (r, why))


if __name__ == "__main__":
    main()
