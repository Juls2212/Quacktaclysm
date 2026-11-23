extends Node
## Headless smoke test for Phase 15o: the red absorption restored with lightning and a bottom emblem (no purple vignette), level 3 without wind columns,
## boss 3 without its armor shell, the corruption drawn INSIDE the duck's rig (no overlays), the optional sprite override slot and the ending poses as
## single drawings. Development only. Run:
##   <godot> --headless --path game res://frontend/scenes/test/phase15o_smoke_test.tscn
## Uses a redirected save path and a temporary settings file; the AI service stays disabled; the real files are never touched.

const TEST_SAVE: String = "user://test_save_phase15o.json"
const TEST_SETTINGS: String = "user://test_settings_phase15o.cfg"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const LEVEL_THREE: PackedScene = preload("res://frontend/levels/level_3.tscn")
const EXORCISM: PackedScene = preload("res://frontend/fx/exorcism_cutscene.tscn")
const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const OLD_GAPS: Array[float] = [336.0, 450.0, 484.0]
const POSES: Array = [&"stand", &"labored", &"stagger", &"kneel", &"reach", &"resist", &"kneel_edge", &"walk", &"head_down"]

var failures: int = 0
var real_save_before: String = ""
var real_settings_before: String = ""
var real_controls_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig


func _ready() -> void:
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	GameSettings.path_override = TEST_SETTINGS
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
	real_settings_before = _read_file(GameSettings.PATH)
	real_controls_before = _read_file(ControlsConfig.DEFAULT_PATH)
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


## Phase 15q: the probe player is freed (it used to stay alive until the engine quit, leaking its body, areas and shapes).
func _player_has_updraft() -> bool:
	var probe := PLAYER_SCENE.instantiate() as Player
	var has: bool = probe.has_method(&"apply_updraft")
	probe.free()
	return has


func _run() -> void:
	_clean_state()
	_test_guards()
	await _test_absorption_look()
	await _test_absorption_flow()
	await _test_level_three()
	await _test_boss_three()
	await _test_rig_corruption()
	_test_override_slot()
	await _test_ending_poses()
	await _test_leaks()
	_clean_state()
	SaveSystem.purge()
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	GameSettings.path_override = ""
	GameState.autosave_enabled = true
	_check("the real save file was not touched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	_check("the real settings file was not touched", _read_file(GameSettings.PATH) == real_settings_before)
	_check("the real controls file was not touched", _read_file(ControlsConfig.DEFAULT_PATH) == real_controls_before)
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
	var classes: PackedStringArray = PackedStringArray()
	for entry in ProjectSettings.get_global_class_list():
		classes.append(String(entry["class"]))
	_check("overlays retired: CorruptionVeins, PlayerCorruptionView, WindVent and GuardShellStyle are gone, the new classes exist",
		not classes.has("CorruptionVeins") and not classes.has("PlayerCorruptionView") and not classes.has("WindVent") and not classes.has("GuardShellStyle")
		and classes.has("CorruptionMarks") and classes.has("CorruptionSpriteSet"))


func _test_absorption_look() -> void:
	var config: AbsorptionConfig = AbsorptionConfig.get_default()
	_check("absorption: lasts %.1f s (3 to 4)" % config.length, config.length >= 3.0 and config.length <= 4.0)
	_check("absorption: the palette is DARK with RED touches (background near black, haze, edge glow, embers and bolts are red-dominant), not purple",
		config.background_color.get_luminance() < 0.05 and config.haze_color.r > config.haze_color.b * 3.0 and config.edge_glow_color.r > config.edge_glow_color.b * 3.0
		and config.bolt_color.r > 0.9 and config.bolt_color.b < 0.3 and config.tendril_color.r > config.tendril_color.b * 3.0 and config.gem_color.r > config.gem_color.b * 3.0)
	var source: String = FileAccess.get_file_as_string("res://frontend/fx/exorcism_cutscene.gd")
	var config_source: String = FileAccess.get_file_as_string("res://frontend/fx/absorption_config.gd")
	_check("absorption: there is no purple vignette any more (no vignette in the code or in the config)", not source.to_lower().contains("vignette_alpha") and not config_source.contains("vignette") and not source.contains("0.1, 0.02, 0.18"))
	_check("absorption: photosensitivity limits in the resource (flare cap %.2f <= 0.3, heartbeat %.1f flashes a second <= 3)" % [config.flare_cap, config.heartbeat_hz * 2.0], config.flare_cap <= 0.3 and config.heartbeat_hz * 2.0 <= float(config.max_flashes_per_second))
	_clean_state()
	GameState.record_decision("fragment_level_1", "boss_a", 1, GameState.CHOICE_KEPT)
	var holder := Node2D.new()
	add_child(holder)
	var cut := EXORCISM.instantiate() as ExorcismCutscene
	cut.fragment_id = "fragment_level_1"
	holder.add_child(cut)
	await _frames(3)
	var seen_max: int = 0
	var converge_ok: bool = true
	var from_emblem: bool = false
	var dark_flashes: bool = true
	for step in 14:
		cut._t = config.length * (0.3 + 0.04 * float(step))
		cut._bolt_clock = 99.0
		await _frames(2)
		seen_max = maxi(seen_max, cut.bolts.size())
		for bolt in cut.bolts:
			if not bool(bolt["branch"]):
				var pts: PackedVector2Array = bolt["pts"]
				converge_ok = converge_ok and pts[pts.size() - 1].distance_to(cut._chest()) < 2.0
			from_emblem = from_emblem or bolt["source"] == &"emblem"
			dark_flashes = dark_flashes and (bolt["pts"] as PackedVector2Array).size() >= 8
	_check("absorption: red lightning bolts appear (up to %d at once) and every main bolt ends exactly in the duck's chest" % seen_max, seen_max >= 4 and converge_ok)
	_check("absorption: they come from the emblem, from the fragment and from the screen edges (%s), jagged (many points) and redrawn %d times" % [str(cut.sources_seen.keys()), cut.bolt_redraws],
		cut.sources_seen.has(&"emblem") and cut.sources_seen.has(&"fragment") and cut.sources_seen.has(&"edge") and from_emblem and dark_flashes and cut.bolt_redraws >= 5)
	_check("absorption: dark-red particles stream into the duck (%d now), embers rise from the edges (%d) and the corruption stage grows in the rig (stage %d)" % [cut.particles.size(), cut.embers.size(), cut._hero.corruption_stage],
		cut.embers.size() > 10 and cut._hero.corruption_stage == cut.target_stage and cut._hero.corruption_stage >= 1)
	_check("absorption: the bolts are THIN lines (width %.1f px) and the only full-screen tint never passes the cap (peak %.2f of %.2f)" % [config.bolt_width, cut.peak_overlay_alpha, config.flare_cap], config.bolt_width <= 3.0 and cut.peak_overlay_alpha <= config.flare_cap + 0.001)
	var emblem_y: float = cut._emblem_center().y
	_check("absorption: the emblem sits at the bottom of the screen (y %.0f of 720) and the duck is the rig itself" % emblem_y, emblem_y > 540.0 and emblem_y < 720.0 and cut._hero is DuckRig and cut._hero.get_child_count() == 0)
	cut._finish()
	await _frames(2)
	holder.free()


func _test_absorption_flow() -> void:
	var config: AbsorptionConfig = AbsorptionConfig.get_default()
	_clean_state()
	GameState.record_decision("fragment_level_2", "boss_b", 2, GameState.CHOICE_KEPT)
	var cut := EXORCISM.instantiate() as ExorcismCutscene
	cut.fragment_id = "fragment_level_2"
	add_child(cut)
	await _frames(3)
	var before_card: bool = cut._card_t < 0.0
	cut._t = config.length - 0.05
	await _frames(8)
	_check("absorption: the card of levels 1 and 2 starts only after the sequence (it was closed before, now %.2f)" % cut._card_t, before_card and cut._card_t >= 0.0)
	cut._finish()
	await _frames(2)
	# Skip with the same input as before (Esc).
	var skip := EXORCISM.instantiate() as ExorcismCutscene
	skip.fragment_id = "fragment_level_2"
	add_child(skip)
	await _frames(3)
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	skip._input(escape)
	await _frames(3)
	_check("absorption: Esc skips straight to the card", skip._card_t >= 0.0)
	skip._finish()
	await _frames(2)
	# The last boss: no card, straight on to the ending flow.
	var last := EXORCISM.instantiate() as ExorcismCutscene
	last.fragment_id = "fragment_level_3"
	var finished_flag: Array[bool] = [false]
	last.finished.connect(func() -> void: finished_flag[0] = true)
	add_child(last)
	await _frames(3)
	last._t = config.length
	await _frames(4)
	_check("absorption: after the last boss there is no card: the sequence ends and goes on (finished %s)" % str(finished_flag[0]), finished_flag[0] and (not is_instance_valid(last) or last._card_t < 0.0))
	# Reduced mode: static red fade with the emblem and a few static bolts, no flicker, no convulsion, no particles.
	_set_options({"corruption_effects": false})
	var still := EXORCISM.instantiate() as ExorcismCutscene
	still.fragment_id = "fragment_level_1"
	add_child(still)
	await _frames(30)
	var first_bolts: int = still.bolts.size()
	var key_a: Array = []
	for bolt in still.bolts:
		key_a.append((bolt["pts"] as PackedVector2Array)[1])
	await _frames(20)
	var key_b: Array = []
	for bolt in still.bolts:
		key_b.append((bolt["pts"] as PackedVector2Array)[1])
	var rotations: Array[float] = []
	for i in 6:
		await get_tree().process_frame
		rotations.append(still._hero.rotation)
	_check("absorption (reduced): a few STATIC bolts (%d, identical over time), no particles, no convulsion, a still tint" % first_bolts,
		still.reduced and first_bolts == config.static_bolts and key_a == key_b and still.particles.is_empty() and absf(rotations.max()) < 0.0001 and still.peak_overlay_alpha <= config.flare_cap * 0.5 + 0.001 and still._hero.corruption_reduced)
	still._finish()
	await _frames(2)
	_set_options({})


func _floors(level: Node) -> Array[Node2D]:
	var floors: Array[Node2D] = []
	for floor_name in ["FloorA", "FloorB", "FloorC", "FloorD"]:
		floors.append(level.get_node("Content/%s" % floor_name) as Node2D)
	return floors


func _test_level_three() -> void:
	var level: Node = LEVEL_THREE.instantiate()
	var bad: PackedStringArray = PackedStringArray()
	for node in level.find_children("*", "", true, false):
		var lowered: String = String(node.name).to_lower()
		if lowered.contains("vent") or lowered.contains("updraft") or lowered.contains("chevron") or lowered.contains("windcolumn") or lowered == "upperrouted":
			bad.append(String(node.name))
		var script: Script = node.get_script() as Script
		if script != null and (script.resource_path.contains("wind_vent") or script.resource_path.contains("updraft")):
			bad.append(String(node.name))
	_check("level 3: no wind column, updraft or chevron node (%s) and the old vent files are gone" % str(bad), bad.is_empty() and not ResourceLoader.exists("res://backend/arena/wind_vent.gd") and not ResourceLoader.exists("res://frontend/arena/wind_vent_art.gd"))
	var floors: Array[Node2D] = _floors(level)
	var gaps: Array[float] = []
	for i in floors.size() - 1:
		var right: float = floors[i].position.x + float(floors[i].get("size").x) * 0.5
		var left: float = floors[i + 1].position.x - float(floors[i + 1].get("size").x) * 0.5
		gaps.append(snappedf(left - right, 1.0))
	_check("level 3: the gaps are still 336 / 450 / 484 px and the four floors A, B, C, D exist (%s)" % str(gaps), gaps == OLD_GAPS)
	var tops_ok: bool = true
	for floor_node in floors:
		tops_ok = tops_ok and absf(floor_node.position.y - floors[0].position.y) < 0.5 + float(floors[3].get("size").y)
	_check("level 3: the floors keep a common surface (every part of the route is on the floors, no vent is needed to progress)", tops_ok)
	# Every platform that is not a floor or the arena is reachable from the floor by jump + double jump (rise 183.9 px): nothing depends on a vent.
	var content: Node = level.get_node("Content")
	var floor_top: float = floors[0].position.y - float(floors[0].get("size").y) * 0.5
	var unreachable: PackedStringArray = PackedStringArray()
	var surfaces: Array[Dictionary] = []
	for child in content.get_children():
		if child is PlaceholderPlatform and not String(child.name).begins_with("Floor") and not String(child.name).begins_with("Arena") and not String(child.name).begins_with("Wall"):
			surfaces.append({"name": String(child.name), "rise": floor_top - ((child as Node2D).position.y - float((child as Node2D).get("size").y) * 0.5)})
	surfaces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["rise"]) < float(b["rise"]))
	var reached: Array[float] = [0.0]
	for surface in surfaces:
		var rise: float = float(surface["rise"])
		var ok: bool = false
		for base in reached:
			ok = ok or rise - base <= 183.9 + 0.5
		if ok:
			reached.append(rise)
		else:
			unreachable.append("%s %.0f px" % [surface["name"], rise])
	_check("level 3: every platform of the level is reachable from the floor or from a lower platform with the double jump (rise 183.9 px) (%s)" % str(unreachable), unreachable.is_empty())
	_check("level 3: the electric plates and the crane platforms remain", level.find_children("*", "ElectricPlate", true, false).size() >= 1 and content.get_node_or_null("CraneHookA") != null)
	_check("player: no updraft hook is left", not _player_has_updraft())
	level.free()
	await _frames(1)


func _test_boss_three() -> void:
	_clean_state()
	var level := LEVEL_THREE.instantiate() as LevelBase
	(level.get_node("PossessionDirector") as PossessionDirector).play_when_headless = true
	add_child(level)
	await _frames(8)
	level.player.story_invulnerable = true
	var boss: BossBase = level.boss
	var guard := boss.get_node("Shield") as BossShield
	var before: int = boss.health.current_health
	var applied: Array[bool] = []
	for kind in [&"light", &"wave", &"heavy", &"dash_slash"]:
		applied.append(boss.hurtbox.receive_hit(DamageInfo.create(1, Vector2.ZERO, null, CombatLayers.Team.PLAYER, kind)))
	_check("boss 3: in phase 1 EVERY attack lands at full damage (%s, health %d to %d): no block, no break, no stagger" % [str(applied), before, boss.health.current_health], applied.all(func(a: bool) -> bool: return a) and boss.health.current_health == before - 4)
	_check("boss 3: the guard has no shell: no state, no stagger or regeneration time, no break hits, no phase list", not "state" in guard and not "stagger_time" in guard and not "regen_delay" in guard and not "guard_break_hits" in guard and not "guard_phases" in guard)
	var every_phase: bool = true
	for phase in [1, 2, 3]:
		guard._on_phase_changed(phase)
		for kind in [&"light", &"wave", &"heavy", &"dash_slash"]:
			var info := DamageInfo.create(1, Vector2.ZERO, null, CombatLayers.Team.PLAYER, kind)
			every_phase = every_phase and not guard.filter_hit(info)
	_check("boss 3: with the summoner shield down no phase blocks any hit (the stage's shield is a separate mechanic and stays)", every_phase and not guard.shield_up)
	guard.set_shield(true)
	_check("boss 3: the summoner stage's shield still blocks every hit while it is up", guard.filter_hit(DamageInfo.create(1, Vector2.ZERO, null, CombatLayers.Team.PLAYER, &"heavy")))
	guard.set_shield(false)
	var fx := boss.get_node("ShieldFx") as ShieldFx
	_check("boss 3: the shell visual, its style resource and the plate code are gone (the node only draws the shield bubble)", not ResourceLoader.exists("res://frontend/fx/default_guard_shell.tres") and not ResourceLoader.exists("res://frontend/fx/guard_shell_style.gd") and fx != null and not "plate_alphas" in fx)
	_check("boss 3: HP and thresholds are the Phase 15p ones (102 HP, lines %s)" % str(boss.stats.get_phase_thresholds()), boss.stats.max_health == 102 and boss.stats.get_phase_thresholds() == PackedFloat32Array([0.451, 0.2255]))
	level.free()
	await _frames(2)


func _quiet_rig(stage: int, growth: float = 1.0) -> DuckRig:
	var rig := DuckRig.new()
	rig.look = DuckRig.Look.HERO
	rig.corruption_stage = stage
	rig.corruption_growth = growth
	add_child(rig)
	return rig


func _test_rig_corruption() -> void:
	var counts: Array[int] = []
	for stage in [0, 1, 2, 3]:
		var rig: DuckRig = _quiet_rig(stage)
		await _frames(3)
		var marks: CorruptionMarks = rig._corruption_marks()
		var body := PackedVector2Array([Vector2(-17, -9), Vector2(-14, -20), Vector2(0, -26), Vector2(14, -20), Vector2(15, -9), Vector2(12, -6), Vector2(-14, -6)])
		var total: int = 0
		for piece in marks.clipped_pieces(CorruptionMarks.Region.BODY, [body], stage, 1.0):
			total += (piece["pts"] as PackedVector2Array).size()
		for piece in marks.clipped_pieces(CorruptionMarks.Region.HEAD, [PackedVector2Array([Vector2(-5, -49), Vector2(19, -49), Vector2(19, -25), Vector2(-5, -25)])], stage, 1.0):
			total += (piece["pts"] as PackedVector2Array).size()
		counts.append(total)
		_check("rig stage %d: drawn inside the rig, the rig has no child nodes (no overlay)" % stage, rig.get_child_count() == 0 and rig.corruption_stage == stage)
		rig.free()
	_check("rig: stages 0..3 draw more and more veins (%s points)" % str(counts), counts[0] == 0 and counts[1] > 0 and counts[2] > counts[1] and counts[3] > counts[2])
	var growing: DuckRig = _quiet_rig(3, 0.0)
	var k_start: float = growing._corr_k()
	growing.corruption_growth = 1.0
	_check("rig: the corruption grows with the growth (%.2f to %.2f) and a clean duck is 0" % [k_start, growing._corr_k()], k_start < growing._corr_k() and _quiet_rig(0)._corr_k() == 0.0)
	growing.free()
	var source: String = FileAccess.get_file_as_string("res://frontend/animations/duck_rig.gd")
	_check("rig: the eye, the tail, the sleeve and the wing change by stage inside their own parts", source.contains("CorruptionMarks.draw_iris") and source.contains("_corrupt_feather(FEATHER_HERO, corr)") and source.contains("_purple_edge") and source.contains("_corrupt_head") and source.contains("_corrupt_body"))
	_check("rig: the veins are clipped to the part polygons (Geometry2D) with the style's margin, not drawn free", FileAccess.get_file_as_string("res://frontend/fx/corruption_marks.gd").contains("intersect_polyline_with_polygon") and CorruptionVeinsStyle.get_default().clip_margin > 0.0)
	# The hitbox is unchanged: the player's collision shape does not depend on the stage.
	var sizes: Array[Vector2] = []
	for kept in [0, 3]:
		_clean_state()
		GameState.souls_kept = kept
		var player := PLAYER_SCENE.instantiate() as Player
		add_child(player)
		await _frames(2)
		var shape := player.get_node("CollisionShape2D") as CollisionShape2D
		sizes.append((shape.shape as RectangleShape2D).size if shape.shape is RectangleShape2D else Vector2.ZERO)
		player.free()
	_check("rig: the hitbox does not change with the stage (%s)" % str(sizes), sizes[0] == sizes[1] and sizes[0] != Vector2.ZERO)


func _test_override_slot() -> void:
	var default_set: CorruptionSpriteSet = CorruptionSpriteSet.get_default()
	_check("override slot: by default every slot is empty and the code drawing is used", default_set.is_empty() and default_set.texture_for(&"kneel", 3) == null)
	var rig: DuckRig = _quiet_rig(2)
	_check("override slot: the rig draws with code by default (no sprite)", not (rig.override_texture() != null))
	var image := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.8, 0.2, 0.2))
	var texture := ImageTexture.create_from_image(image)
	var custom := CorruptionSpriteSet.new()
	custom.stage_textures = [null, null, texture, null]
	custom.pose_textures = {&"kneel": texture}
	rig.sprite_set = custom
	_check("override slot: a texture in the slot of stage 2 is used instead of the code drawing", (rig.override_texture() != null) and custom.texture_for(&"", 2) == texture and custom.texture_for(&"", 3) == null)
	rig.corruption_stage = 3
	_check("override slot: an empty slot (stage 3) falls back to the code drawing", not (rig.override_texture() != null))
	rig.pose_name = &"kneel"
	_check("override slot: a pose texture wins over the stage and works for the ending poses", (rig.override_texture() != null))
	rig.free()


func _test_ending_poses() -> void:
	var scene := EndingScene.new()
	scene.style = "kept"
	add_child(scene)
	await _frames(2)
	var single: bool = scene.actor.get_children().size() == 2 and scene.figure.get_child_count() == 0 and scene.figure is DuckRig
	_check("ending poses: the duck is ONE drawing (a single rig plus one halo behind it, no veins, eye or wing nodes laid over it)", single)
	var wings: Dictionary = {}
	var bows: Dictionary = {}
	for pose in POSES:
		scene.pose = pose
		scene.pose_p = 0.8
		scene.veins = 1.0
		scene.refresh()
		wings[pose] = not is_nan(scene.figure.wing_angle)
		bows[pose] = scene.figure.head_bow
		await _frames(1)
	_check("ending poses: the wing belongs to the figure and shows only in reach and resist (%s)" % str(wings), wings[&"reach"] and wings[&"resist"] and not wings[&"stand"] and not wings[&"kneel"] and not wings[&"head_down"])
	_check("ending poses: the head bows inside the figure (head down %.2f, standing %.2f)" % [bows[&"head_down"], bows[&"stand"]], bows[&"head_down"] > bows[&"stand"] + 0.2)
	_check("ending poses: the corruption (stage %d, growth %.2f) is integrated in the figure and the veins fade with the silhouette" % [scene.figure.corruption_stage, scene.figure.corruption_growth], scene.figure.corruption_stage == 3 and scene.figure.corruption_growth > 0.9)
	scene.silhouette = true
	scene.reduced = true
	scene.refresh()
	scene._process(1.0)
	scene.refresh()
	_check("ending poses: in the silhouette the veins are hidden and the figure goes dark", scene.figure.corruption_strength == 0.0 and scene.figure.modulate.r < 0.2)
	var source: String = FileAccess.get_file_as_string("res://frontend/story/ending_scene.gd")
	var rig_source: String = FileAccess.get_file_as_string("res://frontend/animations/duck_rig.gd")
	var wing_start: int = rig_source.find("func _draw_reach_wing(")
	var wing_source: String = rig_source.substr(wing_start, rig_source.find("\n\n\n", wing_start) - wing_start).to_lower()
	var banned_ok: bool = true
	for word in ["blood", "wound", "stab", "impact", "gore", "knife", "pierce"]:
		banned_ok = banned_ok and not source.to_lower().contains(word) and not wing_source.contains(word)
	_check("ending safety: no blood, wound, stab or impact in the ending scene or in the wing code, and the weapon is never drawn in the wing poses", banned_ok and wing_source.find("_draw_katana") == -1)
	scene.free()


func _test_leaks() -> void:
	_clean_state()
	var counts: Array[int] = []
	for round in 4:
		GameState.record_decision("fragment_level_1", "boss_a", 1, GameState.CHOICE_KEPT)
		var cut := EXORCISM.instantiate() as ExorcismCutscene
		cut.fragment_id = "fragment_level_1"
		add_child(cut)
		await _frames(30)
		cut._finish()
		await _frames(3)
		var scene := EndingScene.new()
		scene.style = "kept"
		add_child(scene)
		await _frames(5)
		scene.free()
		var rig: DuckRig = _quiet_rig(3)
		await _frames(3)
		rig.free()
		await _frames(2)
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	print("MEASURE|node counts after four rounds of absorption, ending scene and rig|%s" % str(counts))
	_check("leaks: no nodes are left behind after four rounds (%s) and nothing stays paused" % str(counts), counts[3] <= counts[1] + 4 and not get_tree().paused)
