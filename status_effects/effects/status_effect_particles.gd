extends CPUParticles2D


# TODO: Make particles scenes inherit from one scene
func stop() -> void:
	emitting = false
	
	$Timer.wait_time = lifetime * 2
	
	$Timer.start()
	
	await $Timer.timeout
	
	queue_free()
