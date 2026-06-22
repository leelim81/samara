#!/bin/bash
# Runs every headless unit / integration test in the project and reports a
# single PASS / FAIL summary. The authoritative gates are validate_check
# (deterministic load of all 984 files) plus the combat/stats/save/battle tests.
#   bash tools/run_tests.sh
cd /Users/leelim/Documents/samara-game || exit 1
GODOT=/usr/local/bin/godot
SAVE="save-data-debug.sav"
fail=0

run() {
	local name="$1" script="$2" needle="$3"
	local out
	out=$("$GODOT" --headless --script "$script" 2>&1)
	if echo "$out" | grep -qE "$needle"; then
		printf "  PASS  %s\n" "$name"
	else
		printf "  FAIL  %s\n" "$name"
		echo "$out" | grep -iE "fail|error|nonexistent|invalid" | head -6 | sed 's/^/        /'
		fail=1
	fi
}

echo "=== samara test suite ==="
run "validate: load all resources"  res://validate_check.gd            "checked [0-9]+ files, 0 load failures"
run "combat: damage formula"         res://tools/test_damage.gd         "test_damage: PASS"
run "stats: level curve"             res://tools/test_stats_curve.gd    "test_stats_curve: PASS"
run "leveling: exp table"            res://tools/test_leveling.gd       "test_leveling: PASS"

[ -f "$SAVE" ] && cp "$SAVE" "$SAVE.testbak"
run "save: round-trip + migration"   res://tools/test_save_roundtrip.gd "test_save_roundtrip: PASS"
if [ -f "$SAVE.testbak" ]; then mv "$SAVE.testbak" "$SAVE"; else rm -f "$SAVE"; fi

run "battle: pincer integration"     res://test_pincer.gd               "TEST PASS"
run "powered point: 100% activation" res://tools/test_powered_point.gd   "test_powered_point: PASS"

echo "========================="
if [ "$fail" = "0" ]; then echo "ALL TESTS PASS"; else echo "SOME TESTS FAILED"; fi
exit $fail
