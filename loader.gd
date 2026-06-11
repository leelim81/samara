extends Node


# Emitted when change_scene() is called and a new scene is going to be loaded
signal scene_changed()

# Path of the scene currently being loaded in the background, empty if idle
var _loading_path: String = ""

var _wait_frames: int = 1

var _current_scene: Node = null

# Data passed from one scene to another
var data: RefCounted = null

var _loading_screen_instance: Node = null

# Flag set to true when the loading screen is active, so that it not
# instanced again in that case.
var _is_loading: bool = false

# Some nodes try to change scenes in their _ready() method. When that happens,
# the fade out animation should only play once, not every time the scene is changed.
# This flag is reset when the loader is started, and is set before adding the new scene
# to the tree, and checked again afterwards. It it is false, it means the new scene
# changed scenes in its  _ready() method and a new loader was created. If it
# remains true then the new scene did not change scenes in its _ready() method,
# and we can fade out.
var _can_fade_out: bool = false

@onready var _loading_screen: PackedScene = preload("res://ui/loading_screen.tscn")


func _ready() -> void:
	var root: Node = get_tree().get_root()
	
	_current_scene = root.get_child(root.get_child_count() - 1)
	
	set_process(false)


func _process(_delta: float) -> void:
	if _loading_path.is_empty():
		set_process(false)
	else:
		if _wait_frames > 0:
			_wait_frames -= 1

			return

		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(_loading_path, progress)

		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				var resource := ResourceLoader.load_threaded_get(_loading_path)
				_loading_path = ""

				_set_new_scene(resource)
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				if _loading_screen_instance != null and not progress.is_empty():
					_loading_screen_instance.update_progress(progress[0])
			_:
				printerr("Error loading scene")

				_loading_path = ""


# https://www.youtube.com/watch?v=5aV_GSAE1kM
# https://dicode1q.blogspot.com/2022/10/background-loading-in-godot-dicode.html
# https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html#example
func change_scene_to_file(path: String, _data = null) -> int:
	if path == "":
		return ERR_CANT_CREATE
	
	if not _loading_path.is_empty():
		push_warning("Loader is busy")

		return ERR_ALREADY_IN_USE

	var error := ResourceLoader.load_threaded_request(path)

	if error != OK:
		printerr("Couldn't start threaded load for scene %s" % path)

		return ERR_CANT_CREATE
	else:
		_loading_path = path
		data = _data

		if _is_loading:
			_start_loader()
		else:
			call_deferred("_play_loading_animation")

		emit_signal("scene_changed")

		return OK


func _play_loading_animation() -> void:
	_is_loading = true
	
	_loading_screen_instance = _loading_screen.instantiate()
	
	get_tree().get_root().add_child(_loading_screen_instance)
	
	var _error = _loading_screen_instance.connect("fade_in_finished", Callable(self, "_on_LoadingScreen_fade_in_finished"))
	
	_loading_screen_instance.play_loading_animation()


func _set_new_scene(resource: Resource) -> void:
	_can_fade_out = true
	
	_current_scene = resource.instantiate()
	
	if _current_scene.has_method("on_instance"):
		_current_scene.on_instance(data)
		
		data = null
	
	get_tree().get_root().add_child(_current_scene)
	
	# This flag can be set to false if the _current_scene wants to change
	# scenes in its _ready() method (when it is added to the tree) and 
	# _start_loader() is called
	# This is so that the fade out animation is only played once, for the last
	# scene changed to
	if _can_fade_out:
		var _error = _loading_screen_instance.connect("fade_out_finished", Callable(self, "_on_LoadingScreen_fade_out_finished"))
		
		_loading_screen_instance.fade_out()


func _start_loader() -> void:
	# Wait until sound effects and such have finished playing
	# TODO: _current_scene.cleanup()
	_current_scene.queue_free()
	
	_wait_frames = 1
	
	set_process(true)
	
	_can_fade_out = false


func _on_LoadingScreen_fade_in_finished() -> void:
	_start_loader()


func _on_LoadingScreen_fade_out_finished() -> void:
	_is_loading = false
	
	_loading_screen_instance.queue_free()
	
	# Enable buttons, input
	if _current_scene.has_method("on_fade_out_finished"):
		_current_scene.on_fade_out_finished()
