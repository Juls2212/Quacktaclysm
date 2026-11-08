class_name GameSettings
extends RefCounted
## Player preferences from the Options menu: fullscreen, master / music / effects volume and
## camera shake. Stored in their own file (`user://settings.cfg`), never in the save game.
## The "Music" and "SFX" audio buses are created at run time (routed to Master) when the
## project has none, so the sliders always have something to drive.

const PATH: String = "user://settings.cfg"
const SECTION: String = "settings"
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
const DEFAULTS: Dictionary = {
	"fullscreen": false,
	"volume": 0.8,
	"music_volume": 0.8,
	"sfx_volume": 0.8,
	"camera_shake": true,
}


static func load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	var result: Dictionary = DEFAULTS.duplicate()
	if cfg.load(PATH) == OK:
		result["fullscreen"] = bool(cfg.get_value(SECTION, "fullscreen", DEFAULTS["fullscreen"]))
		for key in ["volume", "music_volume", "sfx_volume"]:
			result[key] = clampf(float(cfg.get_value(SECTION, key, DEFAULTS[key])), 0.0, 1.0)
		result["camera_shake"] = bool(cfg.get_value(SECTION, "camera_shake", DEFAULTS["camera_shake"]))
	return result


static func save_settings(values: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "fullscreen", bool(values.get("fullscreen", DEFAULTS["fullscreen"])))
	for key in ["volume", "music_volume", "sfx_volume"]:
		cfg.set_value(SECTION, key, clampf(float(values.get(key, DEFAULTS[key])), 0.0, 1.0))
	cfg.set_value(SECTION, "camera_shake", bool(values.get("camera_shake", DEFAULTS["camera_shake"])))
	cfg.save(PATH)


static func apply(values: Dictionary) -> void:
	ensure_buses()
	_set_bus(0, float(values.get("volume", DEFAULTS["volume"])))
	_set_bus(AudioServer.get_bus_index(MUSIC_BUS), float(values.get("music_volume", DEFAULTS["music_volume"])))
	_set_bus(AudioServer.get_bus_index(SFX_BUS), float(values.get("sfx_volume", DEFAULTS["sfx_volume"])))
	if DisplayServer.get_name() == "headless":
		return
	var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if values.get("fullscreen", false) else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


## Whether gameplay code may shake the camera (read from the settings file each call).
static func is_camera_shake_enabled() -> bool:
	return bool(load_settings()["camera_shake"])


## Creates the Music and SFX buses (sending to Master) if the project does not define them.
static func ensure_buses() -> void:
	for bus_name in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")


static func _set_bus(index: int, value: float) -> void:
	if index < 0 or index >= AudioServer.bus_count:
		return
	var volume: float = clampf(value, 0.0, 1.0)
	AudioServer.set_bus_mute(index, volume <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.001)))
