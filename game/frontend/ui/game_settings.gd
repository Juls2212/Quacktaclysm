class_name GameSettings
extends RefCounted
## Player preferences from the Options menu: fullscreen and master volume.
## Stored in their own file (`user://settings.cfg`), never in the save game.

const PATH: String = "user://settings.cfg"
const SECTION: String = "settings"


static func load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	var result: Dictionary = { "fullscreen": false, "volume": 0.8 }
	if cfg.load(PATH) == OK:
		result["fullscreen"] = bool(cfg.get_value(SECTION, "fullscreen", false))
		result["volume"] = clampf(float(cfg.get_value(SECTION, "volume", 0.8)), 0.0, 1.0)
	return result


static func save_settings(values: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "fullscreen", bool(values.get("fullscreen", false)))
	cfg.set_value(SECTION, "volume", clampf(float(values.get("volume", 0.8)), 0.0, 1.0))
	cfg.save(PATH)


static func apply(values: Dictionary) -> void:
	var volume: float = clampf(float(values.get("volume", 0.8)), 0.0, 1.0)
	AudioServer.set_bus_mute(0, volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
	if DisplayServer.get_name() == "headless":
		return
	var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if values.get("fullscreen", false) else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
