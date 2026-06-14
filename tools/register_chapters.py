#!/usr/bin/env python3
"""Register every generated chapter into the game menu.

Scans chapter_data/terra/<slug>.tres (whatever generate_chapter.py has produced,
plus the hand-built ch1-2), rebuilds main_story_chapter_list.tres in chapter
order, and appends any missing caption keys to text/text.csv. Idempotent.

Unlocking is handled dynamically in game_data.unlock_default_chapters (reads the
list), so this script does not touch save code.

Run: python3 tools/register_chapters.py
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATASET = os.path.join(ROOT, "tools", "out", "terra_dataset.json")
LIST = os.path.join(ROOT, "chapter_data", "main_story_chapter_list.tres")
CSV = os.path.join(ROOT, "text", "text.csv")


def title_key(name):
    return re.sub(r"[^A-Z0-9]+", "_", name.upper()).strip("_")


def caption_for(name):
    return f"The path presses on through {name}."


def main():
    data = json.load(open(DATASET))
    found = []
    for c in sorted(data["chapters"], key=lambda c: c["num"]):
        title = title_key(c["name"])
        slug = title.lower()
        if os.path.exists(os.path.join(ROOT, "chapter_data", "terra", slug + ".tres")):
            found.append((c["num"], title, slug, c["name"]))

    # rebuild the chapter list in order
    lines = [f'[gd_resource type="Resource" load_steps={len(found) + 2} format=2]', "",
             '[ext_resource path="res://chapter_data/chapter_list.gd" type="Script" id=1]']
    for i, (_, _, slug, _) in enumerate(found):
        lines.append(f'[ext_resource path="res://chapter_data/terra/{slug}.tres" type="Resource" id={2 + i}]')
    lines += ["", "[resource]", "script = ExtResource( 1 )",
              "chapters = [ " + ", ".join(f"ExtResource( {2 + i} )" for i in range(len(found))) + " ]", ""]
    open(LIST, "w").write("\n".join(lines))

    # ensure caption keys exist (title display + caption line), EN/ES
    csv = open(CSV, encoding="utf-8").read()
    keys = {ln.split(",", 1)[0] for ln in csv.splitlines()}
    add = []
    for _, title, _, name in found:
        if title not in keys:
            add.append(f"{title},{name},{name}")
        cap = title + "_CAPTION"
        if cap not in keys:
            line = caption_for(name)
            add.append(f"{cap},{line},{line}")
    if add:
        if not csv.endswith("\n"):
            csv += "\n"
        open(CSV, "w", encoding="utf-8").write(csv + "\n".join(add) + "\n")

    print(f"registered {len(found)} chapters: {[n for n, _, _, _ in found]}")
    print(f"added {len(add)} caption rows")


if __name__ == "__main__":
    main()
