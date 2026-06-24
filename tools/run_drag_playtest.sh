#!/bin/bash
# Runs the REAL-DRAG playthrough oracle (tools/test_drag_playthrough.gd) against
# every chapter's battle scene in story order, one Godot process per chapter
# (sequential — never concurrent, which would corrupt the .godot cache). Records
# PASS / FAIL / ERROR, any script errors, and the completing/setup move counts.
#   bash tools/run_drag_playtest.sh
cd /Users/leelim/Documents/samara-game || exit 1
OUT=/tmp/drag_playtest_results.txt
: > "$OUT"
PER_CHAPTER_TIMEOUT=420

python3 - > /tmp/drag_scenes.txt <<'PY'
import re
lst = open('chapter_data/main_story_chapter_list.tres').read()
slugs = re.findall(r'chapter_data/terra/([a-z0-9_]+)\.tres', lst)
for slug in slugs:
    tre = f'chapter_data/terra/{slug}.tres'
    m = re.search(r'battle_scene_path = "([^"]+)"', open(tre).read())
    if m:
        print(slug, m.group(1))
PY

i=0
pass_n=0
while read -r slug scene; do
    i=$((i + 1))
    res=$(perl -e 'alarm shift; exec @ARGV' "$PER_CHAPTER_TIMEOUT" \
        /usr/local/bin/godot --headless --script res://tools/test_drag_playthrough.gd -- "$scene" 2>&1)
    if echo "$res" | grep -q 'TEST PASS'; then
        status="PASS"
        line=$(echo "$res" | grep -o 'TEST PASS:.*' | head -1)
        pass_n=$((pass_n + 1))
    elif echo "$res" | grep -q 'TEST FAIL'; then
        status="FAIL"
        line=$(echo "$res" | grep -o 'TEST FAIL:.*' | head -1)
    else
        status="ERROR"
        line="(no PASS/FAIL printed — likely per-chapter timeout)"
    fi
    errs=$(echo "$res" | grep -ciE 'SCRIPT ERROR|Assertion failed|Parse Error|Invalid call|Invalid get index|Nonexistent function|Attempt to call|Jumped more than 1 tile')
    printf "%2d  %-22s %-5s scripterr=%s  %s\n" "$i" "$slug" "$status" "$errs" "$line" | tee -a "$OUT"
done < /tmp/drag_scenes.txt
echo "=== DONE ($i scenes, $pass_n PASS) ===" | tee -a "$OUT"
