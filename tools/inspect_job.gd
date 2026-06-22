extends SceneTree


func _initialize() -> void:
	var job: Resource = load("res://jobs/terra/oxsecian_guard_sp_job.tres")
	print("job script: ", job.get_script().resource_path)
	print("skills size: ", job.skills.size())

	for i in job.skills.size():
		var s = job.skills[i]
		var desc := "null"
		if s != null:
			desc = s.get_class()
			if s.get_script() != null:
				desc += " / " + s.get_script().resource_path
		print("  [%d] %s" % [i, desc])

	print("unlocked(level 20):")
	for s in job.get_unlocked_skills(20):
		var d = s.get_class() if s != null else "null"
		print("   ", d)

	quit()
