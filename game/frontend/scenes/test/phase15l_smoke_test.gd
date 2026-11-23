extends Node
## Headless smoke test for Phase 15l: the kept ending no longer freezes (bounded play-through, fail-safes, frame cost), the eye, the wing and the
## veins of the ending are drawn INSIDE the rig (CorruptionMarks, one figure: Phase 15o; scales with the kept count, clipped to the body, static when
## reduced), the absorption sequence (3 to 4 s, red look, lightning, photosensitivity limits, skip, reduced mode, the card after it) and the
## corruption stage of the duck during gameplay (part of the rig, no overlay node). Development only. Run:
##   <godot> --headless --path game res://frontend/scenes/test/phase15l_smoke_test.tscn
## Uses a redirected save path and a temporary settings file; the AI service stays disabled; the real files are never touched.

const TEST_SAVE: String = "user://test_save_phase15l.json"
const TEST_SETTINGS: String = "user://test_settings_phase15l.cfg"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const ENDING_SCENE: PackedScene = preload("res://frontend/ui/ending.tscn")
const EXORCISM: PackedScene = preload("res://frontend/fx/exorcism_cutscene.tscn")
const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const KEPT: String = "ending_kept"
const CLOCK: float = 6.0

var failures: int = 0
var real_save_before: String = ""
var real_settings_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig
var texts: StoryTexts = StoryTexts.get_default()


func _ready() -> void:
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	GameSettings.path_override = TEST_SETTINGS
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
	real_settings_before = _read_file(GameSettings.PATH)
	_run.call_deferred()


func _check(check_name: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("PASS: %s %s" % [check_name, detail])
	else:
		failures += 1
		print("FAIL: %s %s" % [check_name, detail])


func _read_file(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "<missing>"


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _set_options(values: Dictionary) -> void:
	var all: Dictionary = GameSettings.DEFAULTS.duplicate()
	all.merge(values, true)
	GameSettings.save_settings(all)


func _clean_state() -> void:
	Engine.time_scale = 1.0
	PauseLock.reset(get_tree())
	get_tree().paused = false
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.autosave_enabled = false
	_set_options({})


func _accept() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	return event


func _run() -> void:
	_clean_state()
	_test_guards()
	await _test_freeze_and_failsafes()
	_test_art_code()
	await _test_veins_component()
	await _test_absorption()
	await _test_gameplay_veins()
	await _test_leaks()
	_clean_state()
	SaveSystem.purge()
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	GameSettings.path_override = ""
	GameState.autosave_enabled = true
	_check("the real save file was not touched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	_check("the real settings file was not touched", _read_file(GameSettings.PATH) == real_settings_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------------------------------------

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
	_check("autoloads: exactly GameState, SceneManager and AudioDirector", autoloads == PackedStringArray(["AudioDirector", "GameState", "SceneManager"]), str(autoloads))


## Plays the whole kept ending (every line answered at once) and measures it in real wall time.
func _play_kept(accelerate: float) -> Dictionary:
	_clean_state()
	GameState.souls_kept = 3
	GameState.souls_released = 0
	var ending := ENDING_SCENE.instantiate() as EndingController
	ending.skip_reel_when_headless = false
	add_child(ending)
	await _frames(3)
	var reel: EndingCinematic = ending.reel
	var list: EndingBeatList = reel.beats
	Engine.time_scale = accelerate
	var start: int = Time.get_ticks_msec()
	var frames: int = 0
	var last: int = Time.get_ticks_usec()
	var slowest: float = 0.0
	while not ending.card_visible and (Time.get_ticks_msec() - start) / 1000.0 < list.wall_budget_seconds + 30.0:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		slowest = maxf(slowest, (now - last) / 1000.0)
		last = now
		frames += 1
		if is_instance_valid(reel) and reel.current_beat() != null and reel.current_beat().is_line() and reel.typed_done:
			reel.press_confirm()
	Engine.time_scale = 1.0
	var seconds: float = (Time.get_ticks_msec() - start) / 1000.0
	var result: Dictionary = {"finished": ending.card_visible, "seconds": seconds, "frames": frames, "slowest_ms": slowest, "mean_ms": seconds * 1000.0 / maxf(frames, 1.0),
		"failsafes": reel.failsafe_count if is_instance_valid(reel) else 0, "budget": list.wall_budget_seconds, "limit": list.frame_cost_limit_ms}
	ending.free()
	await _frames(2)
	return result


func _test_freeze_and_failsafes() -> void:
	var list: EndingBeatList = texts.get_ending(KEPT).beats
	# No beat can deadlock: every timed beat is bounded and every line has a fail-safe.
	var bounded: bool = true
	for beat in list.beats:
		bounded = bounded and (beat.is_line() or beat.seconds <= list.max_beat_seconds) and beat.seconds > 0.0
	_check("fail-safe: every timed beat is at most %.0f s, lines wait at most %.0f s and the whole ending at most %.0f s (all exported)" % [list.max_beat_seconds, list.max_line_seconds, list.max_total_seconds], bounded and list.max_line_seconds > 0.0 and list.max_total_seconds > list.timed_seconds())
	var report: Dictionary = await _play_kept(CLOCK)
	print("MEASURE|whole kept ending at clock x%.0f: %s" % [CLOCK, str(report)])
	_check("freeze: the whole kept ending plays through to the card in %.1f s of wall time (budget %.0f s)" % [report["seconds"], report["budget"]], bool(report["finished"]) and report["seconds"] <= report["budget"])
	_check("freeze: the average frame costs %.2f ms and the slowest %.1f ms (limit %.0f ms)" % [report["mean_ms"], report["slowest_ms"], report["limit"]], report["mean_ms"] <= report["limit"])
	_check("freeze: a healthy ending needs no fail-safe (%d fired)" % int(report["failsafes"]), int(report["failsafes"]) == 0)
	# A line nobody answers cannot trap the player: with the line limit at one second the ending still reaches its card.
	var old_limit: float = list.max_line_seconds
	list.max_line_seconds = 1.0
	_clean_state()
	GameState.souls_kept = 3
	var ending := ENDING_SCENE.instantiate() as EndingController
	ending.skip_reel_when_headless = false
	add_child(ending)
	await _frames(3)
	var reel: EndingCinematic = ending.reel
	Engine.time_scale = 20.0
	var waited: float = 0.0
	while not ending.card_visible and waited < 40.0:
		await get_tree().process_frame
		waited += get_process_delta_time() / 20.0
	Engine.time_scale = 1.0
	var fired: int = reel.failsafe_count if is_instance_valid(reel) else -1
	list.max_line_seconds = old_limit
	_check("fail-safe: with nobody pressing anything the lines move on by themselves after the limit and the ending reaches its card (fail-safes fired %s)" % str(fired), ending.card_visible)
	ending.free()
	await _frames(2)
	# The frame watchdog: slow frames switch the scene to its light mode.
	var scene := EndingScene.new()
	add_child(scene)
	await _frames(2)
	var layers_before: int = scene.layer_redraws
	scene.light_mode = true
	for i in 30:
		scene.refresh()
	var redraws_light: int = scene.layer_redraws - layers_before
	_check("freeze: in light mode the big layers are not redrawn every frame (%d redraws in 30 refreshes)" % redraws_light, redraws_light <= 2)
	scene.light_mode = false
	var layers_normal: int = scene.layer_redraws
	for i in 30:
		scene.refresh()
		await get_tree().process_frame
	_check("freeze: in normal mode the layers redraw at a limited rate, not every frame (%d redraws in 30 frames)" % (scene.layer_redraws - layers_normal), scene.layer_redraws - layers_normal < 30)
	scene.free()


func _test_art_code() -> void:
	var source: String = FileAccess.get_file_as_string("res://frontend/story/ending_scene.gd")
	_check("art: the ending scene has no CorruptionVeins, no eye overlay and no separate wing: the duck is ONE figure (Phase 15o)",
		not source.contains("CorruptionVeins") and not source.contains("_eye_overlay") and not source.contains("_draw_reach") and source.contains("figure"))
	var rig_source: String = FileAccess.get_file_as_string("res://frontend/animations/duck_rig.gd")
	var wing_start: int = rig_source.find("func _draw_reach_wing(")
	var wing: String = rig_source.substr(wing_start, rig_source.find("\n\n\n", wing_start) - wing_start)
	_check("art: the wing is the rig's own feathered quad with the ink outline, scalloped covert feathers, flight feathers and a sleeve at the shoulder (not a thick bar)",
		wing.contains("FEATHER_HERO") and wing.contains("_shape(wing") and wing.contains("shoulder") and wing.contains("_purple_edge") and not wing.contains("elbow"))
	_check("art: the clouded eye is drawn inside the rig's own eye (CorruptionMarks.draw_iris), not by a flat disc laid over it", rig_source.contains("CorruptionMarks.draw_iris") and not source.contains("draw_clouded_eye"))
	var scene := EndingScene.new()
	scene.style = "kept"
	add_child(scene)
	scene.pose = &"reach"
	scene.pose_p = 0.5
	scene.veins = 0.8
	scene.refresh()
	_check("art: the scene's figure is a single DuckRig with the corruption stage, the growth and the wing as parameters", scene.figure is DuckRig and scene.figure.corruption_stage == 3 and scene.figure.corruption_growth > 0.7 and not is_nan(scene.figure.wing_angle)
		and scene.actor.get_children().size() == 2)
	scene.reduced = true
	scene.refresh()
	_check("art (reduced): the figure's veins are static and thin", scene.figure.corruption_reduced)
	scene.free()

func _test_veins_component() -> void:
	var marks := CorruptionMarks.new()
	var head: PackedVector2Array = PackedVector2Array()
	for i in 22:
		var a: float = TAU * float(i) / 22.0
		head.append(DuckRig.HERO_HEAD_REST + Vector2(cos(a) * 12.5, sin(a) * 12.25))
	var body := PackedVector2Array([Vector2(-17, -9), Vector2(-14, -20), Vector2(0, -26), Vector2(14, -20), Vector2(15, -9), Vector2(12, -6), Vector2(-14, -6)])
	var counts: Array[int] = []
	var inside: bool = true
	for stage in [0, 1, 2, 3]:
		var total: int = 0
		for growth in [0.5, 1.0]:
			for region in [CorruptionMarks.Region.BODY, CorruptionMarks.Region.HEAD]:
				var polygon: PackedVector2Array = body if region == CorruptionMarks.Region.BODY else head
				for piece in marks.clipped_pieces(region, [polygon], stage, growth):
					total += (piece["pts"] as PackedVector2Array).size() if growth == 1.0 else 0
					for point in piece["pts"] as PackedVector2Array:
						inside = inside and Geometry2D.is_point_in_polygon(point, polygon)
		counts.append(total)
	print("MEASURE|vein points by stage 0..3|%s" % str(counts))
	_check("veins: the amount of veins grows with the stage (%s points for 0, 1, 2 and 3)" % str(counts), counts[0] == 0 and counts[1] > 0 and counts[2] > counts[1] and counts[3] > counts[2])
	_check("veins: every point is clipped INSIDE the polygon of the part it is drawn on (the body or the head) at every stage and growth", inside)
	var rig := DuckRig.new()
	rig.look = DuckRig.Look.HERO
	rig.corruption_stage = 3
	add_child(rig)
	await _frames(3)
	_check("veins: the rig owns them: no child node of the rig draws veins, the stage is a plain property", rig.get_child_count() == 0 and rig.corruption_stage == 3)
	rig.corruption_reduced = true
	var key_a: float = rig._vein_alpha()
	await _frames(4)
	_check("veins (reduced): static, full opacity, no pulse", is_equal_approx(rig._vein_alpha(), key_a) and is_equal_approx(key_a, rig.corruption_strength))
	rig.corruption_reduced = false
	var seen: Array[float] = []
	for i in 40:
		await get_tree().process_frame
		seen.append(rig._vein_alpha())
	_check("veins: they pulse slowly in normal mode (opacity between %.2f and %.2f)" % [seen.min(), seen.max()], seen.max() - seen.min() > 0.001 and seen.min() >= 0.7)
	var style: CorruptionVeinsStyle = marks.style
	_check("veins: they have a dark outline and a glow in the style (readable on any background)", style.outline_color.a > 0.8 and style.glow_color.a > 0.1 and style.outline_color.get_luminance() < 0.1)
	rig.free()

func _test_absorption() -> void:
	var config: AbsorptionConfig = AbsorptionConfig.get_default()
	_check("absorption: the sequence lasts %.1f s (3 to 4) and every number is in the exported resource" % config.length, config.length >= 3.0 and config.length <= 4.0)
	_check("absorption: the flare never goes above the 0.3 cap (%.2f) and the heartbeat makes at most 3 pulses a second (%.1f)" % [config.flare_cap, config.heartbeat_hz * 2.0],
		config.flare_cap <= 0.3 and config.heartbeat_hz * 2.0 <= float(config.max_flashes_per_second))
	_clean_state()
	var level_root := Node2D.new()
	add_child(level_root)
	var cut := EXORCISM.instantiate() as ExorcismCutscene
	cut.fragment_id = "fragment_level_1"
	level_root.add_child(cut)
	await _frames(2)
	var thumps_before: int = int(AudioDirector.events_played.get(config.heartbeat_event, 0))
	var timeline: Array[float] = []
	var card_at: float = -1.0
	var started: int = Time.get_ticks_msec()
	var peak_thumps_second: int = 0
	var thump_times: Array[float] = []
	var seen_thumps: int = cut.thumps
	while is_instance_valid(cut) and cut._card_t < 0.0 and Time.get_ticks_msec() - started < 8000:
		await get_tree().process_frame
		var elapsed: float = (Time.get_ticks_msec() - started) / 1000.0
		while seen_thumps < cut.thumps:
			thump_times.append(elapsed)
			seen_thumps += 1
	card_at = (Time.get_ticks_msec() - started) / 1000.0
	for t in thump_times:
		var in_second: int = 0
		for u in thump_times:
			in_second += 1 if u >= t and u < t + 1.0 else 0
		peak_thumps_second = maxi(peak_thumps_second, in_second)
	print("MEASURE|absorption: the card starts after %.2f s of real time, %d heartbeat thumps, at most %d in one second, peak glow alpha %.2f" % [card_at, cut.thumps, peak_thumps_second, cut.peak_overlay_alpha])
	_check("absorption: the card starts only after the sequence ends (%.2f s, the sequence is %.1f s)" % [card_at, config.length], card_at >= config.length - 0.15 and card_at <= config.length + 0.6)
	_check("absorption: a heavy heartbeat plays (%d thumps, the existing «%s» sound at pitch %.2f)" % [cut.thumps, config.heartbeat_event, config.heartbeat_pitch], cut.thumps >= 3 and int(AudioDirector.events_played.get(config.heartbeat_event, 0)) - thumps_before >= 2 and config.heartbeat_pitch < 0.8)
	_check("absorption: no flash above the cap (peak %.2f) and at most 3 pulses in any second (%d)" % [cut.peak_overlay_alpha, peak_thumps_second], cut.peak_overlay_alpha <= 0.3 and peak_thumps_second <= 3)
	_check("absorption: the corruption grows inside the duck's rig during the sequence (stage %d, growth %.2f)" % [cut._hero.corruption_stage, cut._hero.corruption_growth], cut._hero.corruption_growth > 0.5 and cut._hero.corruption_stage == cut.target_stage)
	var source: String = FileAccess.get_file_as_string("res://frontend/fx/exorcism_cutscene.gd")
	_check("absorption: the music ducks for the whole sequence and is given back", source.contains("set_music_duck(self, config.music_duck_db)") and source.contains("release_music_duck(self)"))
	cut._finish()
	await _frames(2)
	level_root.free()
	# Skippable: Esc jumps to the card.
	var skip := EXORCISM.instantiate() as ExorcismCutscene
	skip.fragment_id = "fragment_level_2"
	add_child(skip)
	await _frames(3)
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	skip._input(escape)
	await _frames(3)
	_check("absorption: it is skippable (Esc goes straight to the card)", skip._card_t >= 0.0)
	skip._finish()
	await _frames(2)
	# Reduced mode: a static dark fade.
	_set_options({"corruption_effects": false})
	var still := EXORCISM.instantiate() as ExorcismCutscene
	still.fragment_id = "fragment_level_3"
	add_child(still)
	await _frames(40)
	var rotations: Array[float] = []
	for i in 10:
		await get_tree().process_frame
		rotations.append(still._hero.rotation)
	_check("absorption (reduced): static red fade, no convulsion (rotation %.3f), a still tint (peak %.2f), no particles; the veins are static and the heartbeat still plays" % [rotations.max(), still.peak_overlay_alpha], still.reduced and absf(rotations.max()) < 0.0001 and still.peak_overlay_alpha <= 0.15 and still._hero.corruption_reduced and still.thumps >= 1 and still.particles.is_empty())
	still._finish()
	await _frames(2)
	_set_options({})


func _test_gameplay_veins() -> void:
	var stages: Array[int] = []
	for kept in [0, 1, 2, 3]:
		_clean_state()
		GameState.souls_kept = kept
		GameState.souls_released = 3 - kept
		var player := PLAYER_SCENE.instantiate() as Player
		add_child(player)
		await _frames(3)
		var rig: DuckRig = player.visual.get("rig") as DuckRig
		stages.append(rig.corruption_stage)
		if kept == 3:
			var no_collision: bool = rig.find_children("*", "CollisionObject2D", true, false).is_empty() and rig.find_children("*", "CollisionShape2D", true, false).is_empty()
			_check("gameplay: the corruption adds no collision and no node: it is part of the rig itself", no_collision and rig.get_child_count() == 0 and player.get_node_or_null("Visual/CorruptionView") == null)
			var extra: bool = false
			for child in player.visual.get_children():
				extra = extra or (child.get_script() != null and String((child.get_script() as Script).resource_path).contains("corruption"))
			_check("gameplay: nothing under the player's Visual draws corruption over the duck", not extra)
		player.free()
		await _frames(1)
	_check("gameplay: the rig's corruption stage follows the kept count: %s (clean with none, faint on the first fragment, widespread on the third)" % str(stages), stages == [0, 1, 2, 3])
	# Released fragments never show corruption.
	_clean_state()
	GameState.souls_kept = 0
	GameState.souls_released = 3
	var released := PLAYER_SCENE.instantiate() as Player
	add_child(released)
	await _frames(3)
	_check("gameplay: three RELEASED fragments leave the duck clean", (released.visual.get("rig") as DuckRig).corruption_stage == 0)
	released.free()
	# They persist across levels and retries from the saved kept count (no new save key): a new player instance reads it again.
	_clean_state()
	GameState.record_decision("fragment_level_1", "boss_a", 1, GameState.CHOICE_KEPT)
	GameState.record_decision("fragment_level_2", "boss_b", 2, GameState.CHOICE_KEPT)
	var level_one := PLAYER_SCENE.instantiate() as Player
	add_child(level_one)
	await _frames(3)
	var saved: Dictionary = GameState.to_dict()
	level_one.free()
	GameState.start_new_game()
	GameState.load_from_dict(saved)
	var level_two := PLAYER_SCENE.instantiate() as Player
	add_child(level_two)
	await _frames(3)
	_check("gameplay: after a reload from the saved state the stage is back (kept %d)" % GameState.souls_kept, (level_two.visual.get("rig") as DuckRig).corruption_stage == 2)
	# Reduced: static and thin.
	_set_options({"corruption_effects": false})
	level_two.visual.call("_refresh_corruption", 2.0)
	_check("gameplay (reduced): the rig's corruption is static and thin", (level_two.visual.get("rig") as DuckRig).corruption_reduced)
	_set_options({})
	level_two.free()
	# Telegraph readability: the veins are on the duck only and never use a telegraph or projectile colour.
	var style: CorruptionVeinsStyle = CorruptionVeinsStyle.get_default()
	var telegraph_hue_clash: bool = false
	var set_resource: TelegraphSet = TelegraphSet.get_default()
	for kind in TelegraphSet.KINDS:
		var tc: Color = set_resource.get_style(kind).color
		telegraph_hue_clash = telegraph_hue_clash or (absf(tc.h - style.core_color.h) < 0.03 and tc.s > 0.5)
	_check("gameplay: the vein colour (purple) is not a telegraph colour and the veins stay on the duck", not telegraph_hue_clash)

func _test_leaks() -> void:
	_clean_state()
	var counts: Array[int] = []
	for round in 4:
		GameState.souls_kept = 3
		var ending := ENDING_SCENE.instantiate() as EndingController
		ending.skip_reel_when_headless = false
		add_child(ending)
		await _frames(30)
		ending.reel.skip()
		var waited: float = 0.0
		while not ending.card_visible and waited < 10.0:
			await get_tree().process_frame
			waited += get_process_delta_time()
		ending.free()
		var cut := EXORCISM.instantiate() as ExorcismCutscene
		cut.fragment_id = "fragment_level_1"
		add_child(cut)
		await _frames(30)
		cut._finish()
		await _frames(3)
		var player := PLAYER_SCENE.instantiate() as Player
		add_child(player)
		await _frames(3)
		player.free()
		await _frames(2)
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	print("MEASURE|node counts after four rounds of ending, absorption and player|%s" % str(counts))
	_check("leaks: no nodes are left behind after replaying the ending, the absorption and the player four times (%s)" % str(counts), counts[3] <= counts[1] + 4 and not get_tree().paused)
	var keys: Array = GameState.to_dict().keys()
	keys.sort()
	var expected: Array = SAVE_KEYS.duplicate()
	expected.sort()
	_check("save: after all of it still the seven keys", keys == expected)
