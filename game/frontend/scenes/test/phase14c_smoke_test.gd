extends Node
## Headless smoke test for Phase 14c (visible and audible corruption, presentation only): the
## ProfilePresentation resource, what the presenter applies per profile (background layers only,
## overlay, plaque, duck and enemy rigs, music), blends that settle at their target, the music filter
## and pitch being given back, the "Efectos de corrupción" option, the decision pulse and the
## guarantee that no gameplay value depends on the presentation. Development only. Run:
##   <godot> --headless --path game res://frontend/scenes/test/phase14c_smoke_test.tscn
## Uses a redirected save path and settings file; the AI service stays disabled; the real save and
## the real settings are never touched.

const TEST_SAVE: String = "user://test_save_phase14c.json"
const TEST_SETTINGS: String = "user://test_settings_phase14c.cfg"
var PRESENTATION: ProfilePresentation = load("res://frontend/presentation/default_profile_presentation.tres") as ProfilePresentation
const LEVEL_PATHS: Dictionary = {
	1: "res://frontend/levels/level_1.tscn",
	2: "res://frontend/levels/level_2.tscn",
	3: "res://frontend/levels/level_3.tscn",
}
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const COMP: String = "compassionate"
const NEUT: String = "neutral"
const CORR: String = "corrupt"

var failures: int = 0
var real_save_before: String = ""
var real_settings_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig


func _ready() -> void:
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
	real_settings_before = _read_file(GameSettings.PATH)
	GameSettings.path_override = TEST_SETTINGS
	_delete_settings()
	_run.call_deferred()


func _check(check_name: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("PASS: %s %s" % [check_name, detail])
	else:
		failures += 1
		print("FAIL: %s %s" % [check_name, detail])


func _read_file(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "<missing>"


func _delete_settings() -> void:
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _clean_state() -> void:
	PauseLock.reset(get_tree())
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.autosave_enabled = false
	AudioDirector.clear_music_profile()


func _make_level(number: int, profile: String) -> LevelBase:
	_clean_state()
	GameState.adaptive_profile = profile
	var level := (load(LEVEL_PATHS[number]) as PackedScene).instantiate() as LevelBase
	add_child(level)
	return level


func _presenter(level: LevelBase) -> Node:
	return level.get_node("ProfilePresenter")


func _run() -> void:
	_test_resource()
	_test_guards()
	await _test_profiles()
	await _test_blend_and_cleanup()
	await _test_option()
	await _test_pulse()
	await _test_stats_equal()
	_test_music_released_outside_levels()
	_clean_state()
	_delete_settings()
	GameSettings.path_override = ""
	SaveSystem.purge()
	GameState.autosave_enabled = true
	_check("the real save file was not touched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	_check("the real settings file was not touched", _read_file(GameSettings.PATH) == real_settings_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------------------------------------
# 1. The resource
# ---------------------------------------------------------------------------------------------

func _test_resource() -> void:
	_check("resource: the three entries exist", PRESENTATION.has_all_looks())
	var neutral: ProfileLook = PRESENTATION.get_look(NEUT)
	_check("resource: neutral is the identity (white tint, no vignette, glow, aura, pulse-free audio)", neutral.is_identity())
	_check("resource: unknown profile gives neutral", PRESENTATION.get_look("???") == neutral)
	var comp: ProfileLook = PRESENTATION.get_look(COMP)
	var corrupt: ProfileLook = PRESENTATION.get_look(CORR)
	_check("resource: compassionate is warmer and brighter than neutral",
		comp.background_tint.r > 1.0 and comp.background_tint.r > comp.background_tint.b and comp.vignette_color.a > 0.0 and comp.aura_color.a > 0.0)
	_check("resource: corrupt is darker, cold purple, with vignette, glow, lower pitch and a low-pass",
		corrupt.background_tint.r < 0.9 and corrupt.background_tint.b > corrupt.background_tint.g and corrupt.vignette_color.a >= 0.4
		and corrupt.enemy_glow_color.a > 0.0 and corrupt.music_pitch < 1.0 and corrupt.music_lowpass_hz < ProfileLook.FILTER_OPEN_HZ)
	_check("resource: compassionate never muffles the music", comp.music_lowpass_hz >= ProfileLook.FILTER_OPEN_HZ)
	_check("resource: toggle text is Spanish with its accent", PRESENTATION.toggle_text == "Efectos de corrupción")
	for look: ProfileLook in [comp, neutral, corrupt]:
		_check("resource: pulse has a color and a duration", look.pulse_duration > 0.0 and look.pulse_color.a > 0.0)
	# The blend helper: ends exactly on the target, starts exactly on the origin.
	var into := ProfileLook.new()
	ProfileLook.blend(neutral, corrupt, 1.0, into)
	_check("blend: t=1 equals the target", into.background_tint.is_equal_approx(corrupt.background_tint)
		and into.vignette_color.is_equal_approx(corrupt.vignette_color) and is_equal_approx(into.music_pitch, corrupt.music_pitch)
		and is_equal_approx(into.music_lowpass_hz, corrupt.music_lowpass_hz))
	ProfileLook.blend(neutral, corrupt, 0.0, into)
	_check("blend: t=0 equals the origin", into.is_identity())


func _test_guards() -> void:
	var keys: Array = GameState.to_dict().keys()
	keys.sort()
	var expected: Array = SAVE_KEYS.duplicate()
	expected.sort()
	_check("save: still exactly the seven keys", keys == expected, str(keys))
	var autoloads: PackedStringArray = PackedStringArray()
	for property in ProjectSettings.get_property_list():
		var property_name: String = property["name"]
		if property_name.begins_with("autoload/"):
			autoloads.append(property_name.trim_prefix("autoload/"))
	autoloads.sort()
	_check("autoloads: exactly GameState, SceneManager and AudioDirector",
		autoloads == PackedStringArray(["AudioDirector", "GameState", "SceneManager"]), str(autoloads))
	_check("settings: the option defaults to ON", bool(GameSettings.load_settings()["corruption_effects"]))


# ---------------------------------------------------------------------------------------------
# 2. What each profile applies
# ---------------------------------------------------------------------------------------------

func _enemy_rigs(level: LevelBase) -> Array[DuckRig]:
	# Every enemy and boss rig registers with the presenter as its visual loads.
	return _presenter(level)._enemy_rigs


func _test_profiles() -> void:
	for profile in [NEUT, COMP, CORR]:
		var level: LevelBase = _make_level(1, profile)
		var presenter: Node = _presenter(level)
		var look: ProfileLook = PRESENTATION.get_look(profile)
		presenter.finish_transition()
		var tag: String = "profile %s" % profile
		var backdrop: Backdrop = level.get_node("Backdrop") as Backdrop
		_check("%s: the backdrop gets the background tint" % tag, backdrop.modulate.is_equal_approx(look.background_tint))
		_check("%s: the gameplay layer is untouched (player, content, enemies keep white modulate)" % tag,
			level.player.modulate.is_equal_approx(Color.WHITE) and (level.get_node("Content") as Node2D).modulate.is_equal_approx(Color.WHITE)
			and level.modulate.is_equal_approx(Color.WHITE))
		var sky_ok: bool = true
		for sky in backdrop.find_children("*", "SkyPainter", true, false):
			var tint: Color = (sky as CanvasItem).modulate
			sky_ok = sky_ok and is_equal_approx(tint.r, look.background_tint.r) and is_equal_approx(tint.b, look.background_tint.b)
		_check("%s: the sky is tinted too" % tag, sky_ok)
		var overlay: ColorRect = presenter.find_child("ProfileOverlay", true, false) as ColorRect
		_check("%s: vignette overlay %s" % [tag, "shown" if look.vignette_color.a > 0.0 else "hidden"],
			overlay.visible == (look.vignette_color.a > 0.0))
		_check("%s: the HUD plaque tint follows" % tag, level.hud.plaque_tint.is_equal_approx(look.plaque_tint))
		var rig: DuckRig = presenter._player_rigs[0] if not presenter._player_rigs.is_empty() else null
		_check("%s: the hero rig gets aura and eye tint" % tag, rig != null and rig.aura_color.is_equal_approx(look.aura_color)
			and rig.eye_tint.is_equal_approx(look.eye_color))
		var enemy_rigs: Array[DuckRig] = _enemy_rigs(level)
		var glow_ok: bool = not enemy_rigs.is_empty()
		for enemy_rig in enemy_rigs:
			glow_ok = glow_ok and enemy_rig.glow_color.is_equal_approx(look.enemy_glow_color)
		_check("%s: %d enemy rigs get the glow" % [tag, enemy_rigs.size()], glow_ok)
		var music: Dictionary = AudioDirector.get_music_profile()
		_check("%s: music pitch %.2f and filter %s" % [tag, look.music_pitch, "on" if look.music_lowpass_hz < ProfileLook.FILTER_OPEN_HZ else "off"],
			is_equal_approx(float(music["pitch"]), look.music_pitch)
			and bool(music["filter_on_bus"]) == (look.music_lowpass_hz < ProfileLook.FILTER_OPEN_HZ))
		if look.music_lowpass_hz < ProfileLook.FILTER_OPEN_HZ:
			_check("%s: cutoff applied" % tag, is_equal_approx(float(music["cutoff_hz"]), look.music_lowpass_hz))
		if profile == NEUT:
			_check("neutral: nothing is dressed (same visuals as before this phase)",
				level.hud.plaque_tint.a <= 0.0 and rig.aura_color.a <= 0.0 and rig.eye_tint.a <= 0.0 and not overlay.visible
				and not bool(music["filter_on_bus"]) and is_equal_approx(float(music["pitch"]), 1.0))
		level.free()
		await _frames(2)


# ---------------------------------------------------------------------------------------------
# 3. Blends and clean-up
# ---------------------------------------------------------------------------------------------

func _test_blend_and_cleanup() -> void:
	var level: LevelBase = _make_level(1, CORR)
	var presenter: Node = _presenter(level)
	var backdrop: Backdrop = level.get_node("Backdrop") as Backdrop
	var target: ProfileLook = PRESENTATION.get_look(CORR)
	_check("blend: a level loads blending in (not instant)", presenter.is_blending()
		and not backdrop.modulate.is_equal_approx(target.background_tint))
	await get_tree().create_timer(PRESENTATION.fade_time + 0.4).timeout
	_check("blend: it ends exactly on the target values", not presenter.is_blending()
		and backdrop.modulate.is_equal_approx(target.background_tint)
		and presenter.get_current_look().vignette_color.is_equal_approx(target.vignette_color))
	_check("music filter is on the Music bus while the level is open", bool(AudioDirector.get_music_profile()["filter_on_bus"]))
	var bus: int = AudioServer.get_bus_index(GameSettings.MUSIC_BUS)
	var effects_in_level: int = AudioServer.get_bus_effect_count(bus)
	level.free()
	await _frames(2)
	_check("closing the level takes the filter off the bus and resets the pitch",
		AudioServer.get_bus_effect_count(bus) == effects_in_level - 1
		and not bool(AudioDirector.get_music_profile()["filter_on_bus"])
		and is_equal_approx(float(AudioDirector.get_music_profile()["pitch"]), 1.0))
	# Two levels in a row never stack filters.
	for i in 3:
		var again: LevelBase = _make_level(1 + i % 2, CORR)
		again.free()
	_check("repeated levels leave no effect behind", AudioServer.get_bus_effect_count(bus) == effects_in_level - 1)


# ---------------------------------------------------------------------------------------------
# 4. The option
# ---------------------------------------------------------------------------------------------

func _test_option() -> void:
	var values: Dictionary = GameSettings.load_settings()
	values["corruption_effects"] = false
	GameSettings.save_settings(values)
	_check("option: OFF persists in the settings file", not bool(GameSettings.load_settings()["corruption_effects"])
		and not GameSettings.is_corruption_effects_enabled())
	var level: LevelBase = _make_level(1, CORR)
	var presenter: Node = _presenter(level)
	presenter.finish_transition()
	var backdrop: Backdrop = level.get_node("Backdrop") as Backdrop
	var overlay: ColorRect = presenter.find_child("ProfileOverlay", true, false) as ColorRect
	var rig: DuckRig = presenter._player_rigs[0]
	var enemies: Array[DuckRig] = _enemy_rigs(level)
	var enemy_glow: bool = false
	for enemy_rig in enemies:
		enemy_glow = enemy_glow or enemy_rig.glow_color.a > 0.0
	var music: Dictionary = AudioDirector.get_music_profile()
	_check("option OFF: no tint, vignette, aura, glow or music effect", not presenter.enabled
		and backdrop.modulate.is_equal_approx(Color.WHITE) and not overlay.visible and rig.aura_color.a <= 0.0
		and rig.eye_tint.a <= 0.0 and not enemy_glow and not bool(music["filter_on_bus"]) and is_equal_approx(float(music["pitch"]), 1.0))
	_check("option OFF: the HUD plaque keeps its profile and tint",
		level.hud.profile == CORR and level.hud.plaque_tint.a > 0.0 and level.hud.get_indicator_text().begins_with("Corrupto"))
	_check("option OFF: the consequence line is still built", not level.consequence_line.is_empty())
	# Switching it back on while the level is open (what the options menu does).
	values["corruption_effects"] = true
	GameSettings.save_settings(values)
	get_tree().call_group(&"profile_presenter", "refresh_settings")
	await _frames(3)
	presenter.finish_transition()
	_check("option ON again (live): the look and the music come back", presenter.enabled
		and backdrop.modulate.is_equal_approx(PRESENTATION.get_look(CORR).background_tint)
		and bool(AudioDirector.get_music_profile()["filter_on_bus"]))
	values["corruption_effects"] = false
	GameSettings.save_settings(values)
	get_tree().call_group(&"profile_presenter", "refresh_settings")
	presenter.finish_transition()
	_check("option OFF again (live): back to neutral, nothing left on the bus", backdrop.modulate.is_equal_approx(Color.WHITE)
		and not bool(AudioDirector.get_music_profile()["filter_on_bus"]))
	level.free()
	await _frames(2)
	_delete_settings()


# ---------------------------------------------------------------------------------------------
# 5. The decision pulse
# ---------------------------------------------------------------------------------------------

func _test_pulse() -> void:
	var level: LevelBase = _make_level(1, NEUT)
	var presenter: Node = _presenter(level)
	presenter.finish_transition()
	level.decision_flow.decision_made.emit("p14c_a", "released")
	_check("pulse: a decision that does not move the profile does not pulse", presenter.pulses_fired == 0
		and level.hud.get_plaque_pulse_left() <= 0.0)
	GameState.set_adaptive_profile(CORR)
	level.decision_flow.decision_made.emit("p14c_b", "kept")
	_check("pulse: a decision that changes the profile pulses once (plaque and screen)", presenter.pulses_fired == 1
		and level.hud.get_plaque_pulse_left() > 0.0 and presenter.shown_profile == CORR and presenter.is_blending())
	_check("pulse: the music starts blending to the corrupt profile", float(AudioDirector.get_music_profile()["pitch"]) <= 1.0)
	level.decision_flow.decision_made.emit("p14c_c", "kept")
	_check("pulse: the same profile again does not pulse", presenter.pulses_fired == 1)
	presenter.finish_transition()
	await get_tree().create_timer(0.3).timeout
	var overlay: ColorRect = presenter.find_child("ProfileOverlay", true, false) as ColorRect
	_check("pulse: the overlay stays for the vignette after the pulse", overlay.visible)
	level.free()
	await _frames(2)
	# With the option OFF a profile change blends the plaque only and never pulses.
	var values: Dictionary = GameSettings.load_settings()
	values["corruption_effects"] = false
	GameSettings.save_settings(values)
	var quiet: LevelBase = _make_level(1, NEUT)
	var quiet_presenter: Node = _presenter(quiet)
	GameState.set_adaptive_profile(COMP)
	quiet.decision_flow.decision_made.emit("p14c_d", "released")
	_check("pulse: option OFF -> no pulse even when the profile changes", quiet_presenter.pulses_fired == 0
		and quiet.hud.get_plaque_pulse_left() <= 0.0)
	quiet.free()
	await _frames(2)
	_delete_settings()


# ---------------------------------------------------------------------------------------------
# 6. No gameplay value depends on the presentation
# ---------------------------------------------------------------------------------------------

func _gameplay_snapshot(level: LevelBase) -> Dictionary:
	var enemies: Array = []
	for node in level.find_children("*", "EnemyBase", true, false):
		var enemy := node as EnemyBase
		enemies.append([enemy.stats.max_health, enemy.stats.move_speed, enemy.global_position, enemy.stats.contact_damage])
	var boss_aggression: float = level.boss.aggression_multiplier if level.boss != null else 0.0
	return {
		"max_health": level.player.health.max_health,
		"speed": level.player.stats.max_speed,
		"jump": level.player.stats.jump_velocity,
		"enemies": enemies,
		"boss_aggression": boss_aggression,
	}


func _test_stats_equal() -> void:
	for profile in [NEUT, COMP, CORR]:
		var values: Dictionary = GameSettings.load_settings()
		values["corruption_effects"] = true
		GameSettings.save_settings(values)
		var on_level: LevelBase = _make_level(2, profile)
		var with_effects: Dictionary = _gameplay_snapshot(on_level)
		on_level.free()
		await _frames(2)
		values["corruption_effects"] = false
		GameSettings.save_settings(values)
		var off_level: LevelBase = _make_level(2, profile)
		var without_effects: Dictionary = _gameplay_snapshot(off_level)
		off_level.free()
		await _frames(2)
		_check("stats: %s level has identical gameplay values with effects ON and OFF" % profile, with_effects == without_effects,
			"%d enemies" % (with_effects["enemies"] as Array).size())
	var players: Array[int] = []
	for profile in [NEUT, COMP, CORR]:
		var level: LevelBase = _make_level(1, profile)
		players.append(level.player.health.max_health)
		_check("stats: the hero's speed and jump do not depend on the profile (%s)" % profile,
			is_equal_approx(level.player.stats.max_speed, (load("res://backend/player/default_player_stats.tres") as PlayerStats).max_speed))
		level.free()
		await _frames(2)
	_check("stats: the hero's max health is the same in every profile (only released souls change it)", players[0] == players[1] and players[1] == players[2], str(players))
	_delete_settings()


func _test_music_released_outside_levels() -> void:
	AudioDirector.set_music_profile(0.9, 1500.0, 0.0, self)
	_check("music: a profile can be set", bool(AudioDirector.get_music_profile()["filter_on_bus"]))
	# This test's scene is not a level, exactly like the menu, the prologue and the ending.
	AudioDirector._on_scene_changed()
	var state: Dictionary = AudioDirector.get_music_profile()
	_check("music: outside a level (menu, prologue, ending) the pitch and the filter are neutral",
		not bool(state["filter_on_bus"]) and is_equal_approx(float(state["pitch"]), 1.0))
	AudioDirector.set_music_profile(0.9, 1500.0, 0.0, self)
	var stranger := Node.new()
	AudioDirector.release_music_profile(stranger)
	_check("music: only the owner can release the profile", bool(AudioDirector.get_music_profile()["filter_on_bus"]))
	AudioDirector.release_music_profile(self)
	_check("music: the owner releases it", not bool(AudioDirector.get_music_profile()["filter_on_bus"]))
	stranger.free()
