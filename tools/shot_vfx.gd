extends SceneTree
# Dev tool: renders every battle VFX variant on one dark canvas so the set can
# be eyeballed: the 4 per-weapon attack impacts (top row), the 4 elemental hit
# bursts (middle row), and the status particle scenes (bottom rows). Run
# windowed (NOT --headless):
#   godot --path . --script res://tools/shot_vfx.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var canvas := Node2D.new()
	root.add_child(canvas)

	# Row 1: per-weapon basic attack impacts (sword, gun, spear, staff).
	var attack_scene = load("res://skills/effects/attack_effect.tscn")
	for i in 4:
		var fx = attack_scene.instantiate()
		fx.setup(i, [0, 2, 3, 4][i]) # each with a different element spark tint
		canvas.add_child(fx)
		fx.position = Vector2(105 + i * 170, 140)

	# Row 2: elemental skill hit bursts.
	var bursts := [
		"res://skills/effects/fire_hit_animation.tscn",
		"res://skills/effects/ice_hit_animation.tscn",
		"res://skills/effects/lightning_hit_animation.tscn",
		"res://skills/effects/shadow_hit_animation.tscn",
	]
	var anims := []
	for i in bursts.size():
		var anim = (load(bursts[i]) as PackedScene).instantiate()
		canvas.add_child(anim)
		anim.position = Vector2(105 + i * 170, 340)
		anim.frame = 0
		anim.play()
		anims.append(anim)

	# Rows 3 and 4: status particle scenes (persistent emitters).
	var particles := [
		"poison", "venom", "sleep", "deep_sleep", "paralyze",
		"petrify", "icebind", "blind", "weakness", "demoralize", "regenerate",
	]
	for i in particles.size():
		var scene = load("res://status_effects/effects/%s_particles.tscn" % particles[i])
		var p = scene.instantiate()
		canvas.add_child(p)
		p.position = Vector2(80 + (i % 6) * 112, 500 + (i / 6) * 130)

	# Capture mid-animation, when flashes and bursts are near peak.
	for i in 10:
		await process_frame

	for a in anims:
		print("burst state: playing=%s frame=%d visible=%s pos=%s tex=%s" % [
				a.is_playing(), a.frame, a.visible, a.position,
				a.sprite_frames.get_frame_texture("default", a.frame) != null])

	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/vfx_shot_early.png")

	for i in 30:
		await process_frame

	img = root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/vfx_shot_late.png")

	print("SHOTS SAVED")
	quit(0)
