class_name SceneRegistry
extends Resource
## Maps scene ids to `res://` paths plus the fade settings of SceneManager.
## Ids: tutorial, level_1..level_3, ending (final scene, not part of `level_scene_ids`) and main_menu.

@export var scenes: Dictionary = {}
@export var new_game_scene_id: String = "tutorial"
@export var main_menu_scene_id: String = "main_menu"
@export var level_scene_ids: PackedStringArray = PackedStringArray(["level_1", "level_2", "level_3"])
@export_range(0.0, 5.0, 0.01) var fade_out_time: float = 0.35
@export_range(0.0, 5.0, 0.01) var fade_in_time: float = 0.35
@export var fade_color: Color = Color(0.0, 0.0, 0.0, 1.0)


## "" if the id is unknown.
func get_path_for(id: String) -> String:
	var value: Variant = scenes.get(id, "")
	return value if value is String else ""


## Known id AND the file exists.
func has_scene(id: String) -> bool:
	var path: String = get_path_for(id)
	return not path.is_empty() and ResourceLoader.exists(path)


## Level number (1-based) mapped to a scene id, clamped to the available levels. "" if none.
func scene_id_for_level(level: int) -> String:
	if level_scene_ids.is_empty():
		return ""
	return level_scene_ids[clampi(level - 1, 0, level_scene_ids.size() - 1)]
