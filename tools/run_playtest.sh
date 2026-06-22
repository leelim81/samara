#!/bin/bash
# Runs the teleport-pincer playthrough bot against every chapter's battle scene
# in story order and records PASS / FAIL / ERROR plus any script errors.
cd /Users/leelim/Documents/samara-game || exit 1
OUT=/tmp/playtest_results.txt
: > "$OUT"

python3 - > /tmp/scenes.txt <<'PY'
import re, os
lst = open('chapter_data/main_story_chapter_list.tres').read()
slugs = re.findall(r'chapter_data/terra/([a-z0-9_]+)\.tres', lst)
for slug in slugs:
    tre = f'chapter_data/terra/{slug}.tres'
    m = re.search(r'battle_scene_path = "([^"]+)"', open(tre).read())
    if m:
        print(slug, m.group(1))
PY

i=0
while read -r slug scene; do
    i=$((i + 1))
    res=$(godot --headless --script res://test_playthrough.gd -- "$scene" 2>&1)
    if echo "$res" | grep -q 'TEST PASS'; then
        status="PASS"
        line=$(echo "$res" | grep -o 'TEST PASS:.*' | head -1)
    elif echo "$res" | grep -q 'TEST FAIL'; then
        status="FAIL"
        line=$(echo "$res" | grep -o 'TEST FAIL:.*' | head -1)
    else
        status="ERROR"
        line="(no PASS/FAIL printed)"
    fi
    errs=$(echo "$res" | grep -ciE 'SCRIPT ERROR|Assertion failed|Parse Error|Invalid call|Invalid get index|Nonexistent function|Attempt to call|area_of_effect')
    printf "%2d  %-22s %-5s scripterr=%s  %s\n" "$i" "$slug" "$status" "$errs" "$line" >> "$OUT"
done < /tmp/scenes.txt
echo "=== DONE ($i scenes) ===" >> "$OUT"
