extends SceneTree
# Attaches the six advanced status effects to thematically-matched enemy skills so
# players actually encounter them in battle. Loads each skill, sets its
# status_effects, and re-saves (Godot rewrites the .tres). Idempotent. Run:
#   godot --headless --script res://tools/wire_statuses.gd

const WIRING := {
	"res://skills/resources/terra/d_venomous_aim_bow.tres": "res://status_effects/venom.tres",
	"res://skills/resources/terra/d_petrifier_staff.tres": "res://status_effects/petrify.tres",
	"res://skills/resources/terra/d_ice_strike.tres": "res://status_effects/icebind.tres",
	"res://skills/resources/terra/d_dark_mist.tres": "res://status_effects/blind.tres",
	"res://skills/resources/terra/d_dark_matter.tres": "res://status_effects/weakness.tres",
	"res://skills/resources/terra/d_shadow_breath.tres": "res://status_effects/deep_sleep.tres",
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	for skill_path in WIRING:
		var skill = load(skill_path)
		var status = load(WIRING[skill_path])

		if skill == null or status == null:
			print("MISSING: %s or %s" % [skill_path, WIRING[skill_path]])
			continue

		skill.status_effects = [status]

		if skill.status_effect_infliction_rate <= 0.0:
			skill.status_effect_infliction_rate = 0.35

		var error := ResourceSaver.save(skill, skill_path)
		print("%s %s <- %s" % ["OK " if error == OK else "ERR", skill_path.get_file(), WIRING[skill_path].get_file()])

	quit(0)
