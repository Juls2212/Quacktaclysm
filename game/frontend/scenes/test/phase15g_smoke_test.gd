extends Node
## Smoke test for Phase 15g: the interactive scenery of level 3 (electric plates, reactive decor; the wind vents and the upper route were removed in Phase 15o). The numbers are computed from the REAL player stats and the real configs; the vent, the plate and the
## upper route are also run with the real player in a flat world. Lines starting with "MEASURE|" go to docs/BALANCE_REPORT.md.
## Development only. Run (alone, a few minutes): <godot> --headless --path game res://frontend/scenes/test/phase15g_smoke_test.tscn
## Uses a redirected save path and a throwaway settings file. Times are real game time.

const TEST_SAVE: String = "user://test_save_phase15g.json"
const TEST_SETTINGS: String = "user://test_settings_phase15g.cfg"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const LEVEL_THREE: PackedScene = preload("res://frontend/levels/level_3.tscn")
const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const PLATE_SCENE: PackedScene = preload("res://backend/arena/electric_plate.tscn")
const BIOME_DIR: String = "res://frontend/levels/biome/"
const LEVEL_ONE_MD5: String = "0e26106a46848215f2ec25d5280c1fed"
const LEVEL_TWO_MD5: String = "09e2ccd6a5c2c4e0b53846990e7eef61"
const FLOOR_TOP: float = 600.0
const MIN_CONTRAST: float = 2.5
const OLD_GAPS: Array[float] = [336.0, 450.0, 484.0]
const CHECKPOINTS: Array[float] = [200.0, 1701.0, 3276.0, 5375.0]

var failures: int = 0
var real_save_before: String = ""
var real_settings_before: String = ""
var real_controls_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig
var stats: PlayerStats = PlayerStats.new()
var plate_config: ElectricPlateConfig = ElectricPlateConfig.get_default()
var decor_config: StormDecorConfig = StormDecorConfig.get_default()


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


func _physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _clean_state() -> void:
	Engine.time_scale = 1.0
	PauseLock.reset(get_tree())
	get_tree().paused = false
	for action in [&"jump", &"dash", &"move_left", &"move_right"]:
		Input.action_release(action)
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.director.clear_overrides()
	GameState.autosave_enabled = false
	AbilityCard.forget_all()
	BossDialogue.forget_all()
	GameSettings.save_settings(GameSettings.DEFAULTS.duplicate())
	# Level 3 is entered with the double jump unlocked (two decisions made).
	GameState.record_decision("test_a", "x", 1, GameState.CHOICE_KEPT)
	GameState.record_decision("test_b", "x", 2, GameState.CHOICE_KEPT)


## Phase 15q: the probe player is freed (it used to stay alive until the engine quit, leaking its body, areas and shapes).
func _player_has_updraft() -> bool:
	var probe := PLAYER_SCENE.instantiate() as Player
	var has: bool = probe.has_method(&"apply_updraft")
	probe.free()
	return has


func _run() -> void:
	_clean_state()
	_test_guards()
	_test_configs()
	_test_no_wind_columns()
	await _test_plate_real()
	await _test_plate_timings()
	_test_shelter_and_colors()
	_test_placement_rules()
	await _test_decor()
	_test_unchanged_geometry()
	await _test_no_leaks()
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
# Helpers
# ---------------------------------------------------------------------------------------------

func _flat_world() -> Node2D:
	var world := Node2D.new()
	add_child(world)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	floor_body.position = Vector2(0.0, FLOOR_TOP + 20.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6000.0, 40.0)
	shape.shape = rect
	floor_body.add_child(shape)
	world.add_child(floor_body)
	return world


func _add_player(world: Node2D, x: float) -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(x, FLOOR_TOP - 26.0)
	world.add_child(player)
	return player


func _feet(player: Player) -> float:
	return FLOOR_TOP - (player.global_position.y + 26.0)


func _walk_time(distance: float) -> float:
	if distance <= 0.0:
		return 0.0
	var accel_distance: float = stats.max_speed * stats.max_speed / (2.0 * stats.acceleration)
	if distance <= accel_distance:
		return sqrt(2.0 * distance / stats.acceleration)
	return stats.max_speed / stats.acceleration + (distance - accel_distance) / stats.max_speed


func _floor_nodes(level: Node) -> Array[Node2D]:
	var floors: Array[Node2D] = []
	for floor_name in ["FloorA", "FloorB", "FloorC", "FloorD"]:
		floors.append(level.get_node("Content/%s" % floor_name) as Node2D)
	return floors


func _gap_edges(level: Node) -> Array[float]:
	var floors: Array[Node2D] = _floor_nodes(level)
	var edges: Array[float] = []
	for i in floors.size() - 1:
		edges.append(floors[i].position.x + float(floors[i].get("size").x) * 0.5)
		edges.append(floors[i + 1].position.x - float(floors[i + 1].get("size").x) * 0.5)
	return edges


# ---------------------------------------------------------------------------------------------
# Guards and configs
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


func _test_configs() -> void:
	_check("configs: the plate config exists, exported: warning 1.2 s, active 2.0 s, rest 3.0 s, 1 heart", plate_config != null and is_equal_approx(plate_config.warning_time, 1.2) and is_equal_approx(plate_config.active_time, 2.0)
		and is_equal_approx(plate_config.rest_time, 3.0) and plate_config.damage == 1)
	_check("configs: the decor config exists, with the particle and node caps and the flicker limits", decor_config != null and decor_config.max_particles > 0 and decor_config.max_nodes >= 4 and decor_config.flash_hz <= 3.0 and decor_config.max_flash_alpha <= 0.3)
	var bounce := BounceConfig.get_default()
	var hazard := FloorHazardConfig.get_default()
	_check("configs: the lily pad and spike resources are untouched (launch -930, warning 1.2 s / active 3.0 s / rest 4.0 s)", is_equal_approx(bounce.launch_velocity, -930.0) and is_equal_approx(hazard.warning_time, 1.2)
		and is_equal_approx(hazard.active_time, 3.0) and is_equal_approx(hazard.rest_time, 4.0))


# ---------------------------------------------------------------------------------------------
# No wind columns (Phase 15o)
# ---------------------------------------------------------------------------------------------

func _test_no_wind_columns() -> void:
	var level: Node = LEVEL_THREE.instantiate()
	var content: Node = level.get_node("Content")
	var bad: PackedStringArray = PackedStringArray()
	for node in level.find_children("*", "", true, false):
		var lowered: String = String(node.name).to_lower()
		if lowered.contains("vent") or lowered.contains("updraft") or lowered.contains("chevron") or lowered.contains("windcolumn") or lowered == "upperrouted":
			bad.append(String(node.name))
		var script: Script = node.get_script() as Script
		if script != null and (script.resource_path.contains("wind_vent") or script.resource_path.contains("updraft")):
			bad.append(String(node.name))
	_check("level 3: no wind column, vent, updraft or chevron node is left (%s)" % str(bad), bad.is_empty())
	_check("level 3: the vent scripts, the config and the art are gone from the project", not ResourceLoader.exists("res://backend/arena/wind_vent.gd") and not ResourceLoader.exists("res://backend/arena/default_wind_vent_config.tres") and not ResourceLoader.exists("res://frontend/arena/wind_vent_art.gd") and not ResourceLoader.exists("res://backend/arena/wind_vent.tscn"))
	_check("level 3: the player no longer has an updraft hook", not _player_has_updraft())
	_check("level 3: the electric plates and the crane platforms are still there", level.find_children("*", "ElectricPlate", true, false).size() >= 1 and content.get_node_or_null("CraneHookA") != null and content.get_node_or_null("CraneHookB") != null)
	# Nothing mandatory depends on a raised platform that only a vent could reach: the floors, the gaps and the checkpoints are the route.
	var edges: Array[float] = _gap_edges(level)
	var gaps: Array[float] = []
	for i in range(0, edges.size() - 1, 2):
		gaps.append(snappedf(edges[i + 1] - edges[i], 1.0))
	_check("level 3: the three gaps are still 336 / 450 / 484 px wide and the checkpoints are unchanged (%s)" % str(gaps), gaps.size() == 3 and is_equal_approx(gaps[0], OLD_GAPS[0]) and is_equal_approx(gaps[1], OLD_GAPS[1]) and is_equal_approx(gaps[2], OLD_GAPS[2]))
	level.free()


# ---------------------------------------------------------------------------------------------
# Electric plates
# ---------------------------------------------------------------------------------------------

func _test_plate_real() -> void:
	_clean_state()
	var world: Node2D = _flat_world()
	var plate := PLATE_SCENE.instantiate() as ElectricPlate
	plate.position = Vector2(0.0, FLOOR_TOP)
	plate.length = 220.0
	plate.start_offset = plate_config.warning_time
	world.add_child(plate)
	var hitbox := plate.get_node("Hitbox") as Hitbox
	var plate_variant: Variant = plate
	var hitbox_variant: Variant = hitbox
	_check("plate: damage 1 heart through the normal hitbox (ENEMY team), not a KillZone, and the dangerous band is only %.0f px tall over the floor" % plate_config.band_height,
		hitbox.damage == 1 and hitbox.team == CombatLayers.Team.ENEMY and not plate_variant is KillZone and not hitbox_variant is KillZone and is_equal_approx(plate.config.band_height, 22.0))
	var player: Player = _add_player(world, 110.0)
	var events: Array[int] = []
	player.hurtbox.hit_received.connect(func(info: DamageInfo, applied: bool) -> void:
		if applied:
			events.append(info.amount))
	var hearts: int = player.health.current_health
	await _physics(5)
	_check("plate: it starts ACTIVE at the configured offset", plate.state == ElectricPlate.State.ACTIVE and plate.is_dangerous())
	await _wait(0.5)
	_check("plate: a player standing on it loses exactly 1 heart (%d -> %d, hits %s)" % [hearts, player.health.current_health, str(events)], hearts - player.health.current_health == 1 and events == [1])
	world.free()
	await _frames(2)
	# The dash is fully immune.
	_clean_state()
	var dash_world: Node2D = _flat_world()
	var dash_plate := PLATE_SCENE.instantiate() as ElectricPlate
	dash_plate.position = Vector2(0.0, FLOOR_TOP)
	dash_plate.length = 220.0
	dash_plate.start_offset = plate_config.warning_time
	dash_world.add_child(dash_plate)
	var dasher: Player = _add_player(dash_world, -70.0)
	var damage_while_dashing: Array[int] = [0]
	var overlapped: Array[int] = [0]
	dasher.hurtbox.hit_received.connect(func(_info: DamageInfo, applied: bool) -> void:
		if applied and dasher.state == Player.State.DASH:
			damage_while_dashing[0] += 1)
	await _physics(30)
	var hearts_before: int = dasher.health.current_health
	Input.action_press(&"move_right")
	Input.action_press(&"dash")
	var frames: int = 0
	while frames < 14:
		await get_tree().physics_frame
		frames += 1
		Input.action_release(&"dash")
		if dasher.state == Player.State.DASH and dasher.global_position.x > 0.0:
			overlapped[0] += 1
			_check_hurtbox_immune(dasher)
	Input.action_release(&"move_right")
	_check("plate: the dash is fully immune (%d frames dashing over the active plate, %d damage while dashing)" % [overlapped[0], damage_while_dashing[0]], overlapped[0] > 0 and damage_while_dashing[0] == 0 and dash_plate.state == ElectricPlate.State.ACTIVE)
	var level_for_safety: Node = LEVEL_THREE.instantiate()
	var plate_a := level_for_safety.get_node("Content/PlateA") as ElectricPlate
	var gaps_ok: bool = true
	for edge in _gap_edges(level_for_safety):
		gaps_ok = gaps_ok and (edge < plate_a.global_x_range().x - 100.0 or edge > plate_a.global_x_range().y + 100.0)
	var lowest_platform: float = 1e9
	for child in level_for_safety.get_node("Content").get_children():
		if child is PlaceholderPlatform and not String(child.name).begins_with("Floor") and not String(child.name).begins_with("Wall") and not String(child.name).begins_with("Arena"):
			lowest_platform = minf(lowest_platform, FLOOR_TOP - ((child as Node2D).position.y - float(child.get("size").y) * 0.5))
	_check("plate: platforms and the gaps between plates are safe: the band is %.0f px tall and the top of the lowest platform is %.0f px over the floor; the plate covers only part of its stretch (%.0f px of floor A)" % [plate_config.band_height, lowest_platform, plate_a.length],
		lowest_platform > plate_config.band_height + 26.0 and gaps_ok and plate_a.length < 400.0)
	level_for_safety.free()
	dash_world.free()
	await _frames(2)


func _check_hurtbox_immune(player: Player) -> void:
	if player.hurtbox.receive_hit(DamageInfo.create(1, Vector2.ZERO, null, CombatLayers.Team.ENEMY)):
		failures += 1
		print("FAIL: plate: a hit landed on a dashing player")


func _test_plate_timings() -> void:
	_clean_state()
	var world: Node2D = _flat_world()
	var plate := PLATE_SCENE.instantiate() as ElectricPlate
	plate.position = Vector2(3000.0, FLOOR_TOP)
	world.add_child(plate)
	var in_state: Dictionary = {ElectricPlate.State.WARNING: 0.0, ElectricPlate.State.ACTIVE: 0.0, ElectricPlate.State.REST: 0.0}
	var elapsed: float = 0.0
	while elapsed < plate.cycle_length() - 0.05:
		await get_tree().physics_frame
		var step: float = get_physics_process_delta_time()
		elapsed += step
		in_state[plate.state] = float(in_state[plate.state]) + step
	print("MEASURE|electric plate cycle|warning %.2f s, active %.2f s, rest %.2f s (config %.1f / %.1f / %.1f)" % [in_state[ElectricPlate.State.WARNING], in_state[ElectricPlate.State.ACTIVE], in_state[ElectricPlate.State.REST], plate_config.warning_time, plate_config.active_time, plate_config.rest_time])
	_check("plate: warning %.2f s, active %.2f s, rest %.2f s from the config (1.2 / 2.0 / 3.0)" % [in_state[ElectricPlate.State.WARNING], in_state[ElectricPlate.State.ACTIVE], in_state[ElectricPlate.State.REST]],
		absf(float(in_state[ElectricPlate.State.WARNING]) - 1.2) < 0.1 and absf(float(in_state[ElectricPlate.State.ACTIVE]) - 2.0) < 0.1 and absf(float(in_state[ElectricPlate.State.REST]) - 3.0) < 0.15)
	world.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# Shelter and colors
# ---------------------------------------------------------------------------------------------

func _channel(value: float) -> float:
	return value / 12.92 if value <= 0.03928 else pow((value + 0.055) / 1.055, 2.4)


func _luminance(color: Color) -> float:
	return 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b)


func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _test_shelter_and_colors() -> void:
	var level: Node = LEVEL_THREE.instantiate()
	var worst_margin: float = 1e9
	var worst_walk: float = 0.0
	for node in level.find_children("*", "ElectricPlate", true, false):
		var plate := node as ElectricPlate
		# Worst case: standing in the middle of the plate; safe once the whole body (14 px each side) is outside it.
		var distance: float = plate.length * 0.5 + 14.0
		var walk: float = _walk_time(distance)
		worst_walk = maxf(worst_walk, walk)
		worst_margin = minf(worst_margin, plate.config.warning_time - walk)
	print("MEASURE|electric plate shelter|worst walk to a safe spot %.2f s of the %.1f s warning (margin %.2f s)" % [worst_walk, plate_config.warning_time, worst_margin])
	_check("shelter: from the middle of any plate the player walks out in %.2f s, the margin over the %.1f s warning is %.2f s (needs 0.3)" % [worst_walk, plate_config.warning_time, worst_margin], worst_margin >= 0.3)
	_check("shelter: no plate is longer than the 320 px of the design (and none shorter than 220)", level.find_children("*", "ElectricPlate", true, false).all(func(n: Node) -> bool: return (n as ElectricPlate).length <= 320.0 and (n as ElectricPlate).length >= 220.0))
	# Colors.
	var colors: Array = [["plate warning", ElectricPlateArt.WARN, ElectricPlateArt.OUTLINE], ["plate shock", ElectricPlateArt.SHOCK, ElectricPlateArt.OUTLINE], ["plate bolt", ElectricPlateArt.BOLT, ElectricPlateArt.OUTLINE]]
	var cool: bool = true
	for entry in colors:
		var color: Color = entry[1]
		# Never red or orange (hue under 0.11 or over 0.95 with real color) and never the warm palette of the enemy projectiles.
		var warm: bool = color.s > 0.2 and (color.h < 0.11 or color.h > 0.95)
		cool = cool and not warm
	_check("colors: the plates use blue-white and yellow-white, never red or orange", cool)
	var profiles := load("res://frontend/presentation/default_profile_presentation.tres") as ProfilePresentation
	var possession := PossessionConfig.get_default()
	var backgrounds: Array[Color] = []
	var directory: DirAccess = DirAccess.open(BIOME_DIR)
	for file in directory.get_files():
		if not file.ends_with(".tres"):
			continue
		var biome := load(BIOME_DIR + file) as Biome
		if biome == null:
			continue
		for property in ["sky_top", "sky_bottom", "haze", "far_color", "mid_color", "near_color", "grass", "grass_dark", "soil", "soil_dark", "rock", "rock_dark"]:
			var value: Variant = biome.get(property)
			if value is Color:
				backgrounds.append(value)
	var worst: Dictionary = {}
	for entry in colors:
		worst[entry[0]] = 99.0
	for profile in ["neutral", "compassionate", "corrupt"]:
		var tint: Color = profiles.get_look(profile).background_tint
		for amount in [0.0, possession.persistent_sky, 1.0]:
			var red: Color = Color.WHITE.lerp(possession.sky_tint, amount)
			for color in backgrounds:
				var shown := Color(clampf(color.r * tint.r * red.r, 0.0, 1.0), clampf(color.g * tint.g * red.g, 0.0, 1.0), clampf(color.b * tint.b * red.b, 0.0, 1.0))
				for entry in colors:
					worst[entry[0]] = minf(float(worst[entry[0]]), maxf(_contrast(entry[1], shown), _contrast(entry[2], shown)))
	var summary: PackedStringArray = PackedStringArray()
	var all_ok: bool = true
	for entry in colors:
		summary.append("%s %.2f" % [entry[0], worst[entry[0]]])
		all_ok = all_ok and float(worst[entry[0]]) >= MIN_CONTRAST
	print("MEASURE|plate contrast over the storm and industrial scenery and the three profile backgrounds|%s" % ", ".join(summary))
	_check("contrast: the plate warning, the shock and the bolt read over every scenery color and profile background (>= %.1f): %s" % [MIN_CONTRAST, ", ".join(summary)], all_ok and backgrounds.size() > 20)
	level.free()


# ---------------------------------------------------------------------------------------------
# Placement rules
# ---------------------------------------------------------------------------------------------

func _test_placement_rules() -> void:
	var level: Node = LEVEL_THREE.instantiate()
	var content: Node = level.get_node("Content")
	var edges: Array[float] = _gap_edges(level)
	var gate := content.get_node("ArenaGate") as Node2D
	var gate_left: float = gate.position.x - float(gate.get("size").x) * 0.5
	var plates: Array[ElectricPlate] = []
	for node in level.find_children("*", "ElectricPlate", true, false):
		plates.append(node as ElectricPlate)
	var ground: Array[Node2D] = []
	var all_enemies: Array[Node2D] = []
	for child in content.get_children():
		if child is EnemyBase:
			all_enemies.append(child as Node2D)
			if (child as Node2D).position.y >= 560.0:
				ground.append(child as Node2D)
	var closest_edge_plate: float = 1e9
	var closest_cp_plate: float = 1e9
	var closest_enemy_plate: float = 1e9
	var in_arena: bool = false
	for plate in plates:
		var span: Vector2 = plate.global_x_range()
		in_arena = in_arena or span.y > gate_left
		for edge in edges:
			closest_edge_plate = minf(closest_edge_plate, minf(absf(span.x - edge), absf(span.y - edge)))
			_check("placement: no plate band overlaps a gap edge (%.0f)" % edge, edge < span.x or edge > span.y)
		for checkpoint in CHECKPOINTS:
			closest_cp_plate = minf(closest_cp_plate, minf(absf(span.x - checkpoint), absf(span.y - checkpoint)))
			_check("placement: no plate band covers a checkpoint respawn (%.0f)" % checkpoint, checkpoint < span.x or checkpoint > span.y)
		for enemy in ground:
			closest_enemy_plate = minf(closest_enemy_plate, minf(absf(enemy.position.x - span.x), absf(enemy.position.x - span.y)) if (enemy.position.x < span.x or enemy.position.x > span.y) else 0.0)
	print("MEASURE|placement|plates %d (closest gap edge %.0f px, checkpoint %.0f px, ground enemy %.0f px)" % [plates.size(), closest_edge_plate, closest_cp_plate, closest_enemy_plate])
	_check("placement: %d plate band(s), none of them in the boss arena floor" % plates.size(), plates.size() >= 1 and not in_arena)
	_check("placement: every plate band is at least 350 px from any gap edge (closest %.0f px), so also out of the 200 px run-up of a gap and never over a gap" % closest_edge_plate, closest_edge_plate >= 350.0)
	_check("placement: every plate band is at least 350 px from every checkpoint respawn (closest %.0f px)" % closest_cp_plate, closest_cp_plate >= 350.0)
	_check("placement: no ground enemy or extra within 150 px of a plate band (closest %.0f px)" % closest_enemy_plate, closest_enemy_plate >= 150.0)
	# The adaptive extra-enemy slots are all still there.
	var extras: int = 0
	for group: Variant in (level as LevelBase).variant_groups.values():
		extras += (group as Array).size()
	_check("placement: the adaptive extra-enemy slots of the Director are all kept (%d) and none lands on a plate" % extras, extras == 3)
	var slot_ok: bool = true
	for group: Variant in (level as LevelBase).variant_groups.values():
		for raw_path: Variant in group as Array:
			var slot := level.get_node(NodePath(raw_path)) as Node2D
			for plate in plates:
				slot_ok = slot_ok and (slot.position.x < plate.global_x_range().x - 150.0 or slot.position.x > plate.global_x_range().y + 150.0)
	_check("placement: the extra slots keep clear of every plate band (150 px)", slot_ok)
	# The arena has no platform and no plate.
	var arena_clutter: PackedStringArray = PackedStringArray()
	for child in content.get_children():
		var child_x: float = (child as Node2D).position.x if child is Node2D else 0.0
		if child_x > gate_left and (child is ElectricPlate or (child is PlaceholderPlatform and not String(child.name).begins_with("Floor") and not String(child.name).begins_with("Arena") and not String(child.name).begins_with("Wall"))):
			arena_clutter.append(String(child.name))
	_check("arena: no platform and no plate in the boss 3 arena (only the floor, the ceiling, the gate and the wall; the boss stage builds its platforms during the fight)", arena_clutter.is_empty(), str(arena_clutter))
	level.free()


# ---------------------------------------------------------------------------------------------
# Upper route, in the real world
# ---------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------
# Decor
# ---------------------------------------------------------------------------------------------

func _test_decor() -> void:
	_clean_state()
	var level := LEVEL_THREE.instantiate() as LevelBase
	add_child(level)
	await _frames(3)
	var decor := level.get_node("Decor") as StormDecor
	_check("decor: the decor exists with puddles, lamps, chains and background towers and uses %d nodes (cap %d)" % [decor.node_count(), decor.config.max_nodes],
		decor.puddles.size() > 0 and decor.lamps.size() > 0 and decor.chains.size() > 0 and decor.towers.size() > 0 and decor.node_count() <= decor.config.max_nodes)
	var player: Player = level.player
	# A splash when landing in a puddle.
	player.global_position = Vector2(decor.puddles[0], 520.0)
	player.velocity = Vector2.ZERO
	await _wait(0.6)
	_check("decor: the puddle splashes when the player lands in it (%d splash)" % decor.splash_count, decor.splash_count >= 1)
	# The cap holds under any number of splashes.
	for i in 40:
		decor._splash_cooldown[0] = 0.0
		decor._splash_puddle(0)
	_check("decor: the particles never go over the cap (%d of %d) however many splashes" % [decor.particles.size(), decor.config.max_particles], decor.particles.size() <= decor.config.max_particles)
	# Chains sway and lamps flicker when the player passes.
	player.global_position = Vector2(decor.chains[0], 560.0)
	player.velocity = Vector2(120.0, 0.0)
	await _frames(4)
	_check("decor: a chain sways when the player passes (amplitude %.2f)" % decor.sway[0], decor.sway[0] > 0.0)
	player.global_position = Vector2(decor.lamps[0], 560.0)
	await _frames(4)
	_check("decor: a lamp flickers when the player passes", decor.flicker_left[0] > 0.0)
	# Flash limit: never above the alpha cap and never more than 3 flickers per second.
	decor.flicker_left[0] = 100.0
	var highest: float = 0.0
	var rising: int = 0
	var previous: float = decor.config.lamp_base_alpha
	var samples: int = 1000
	for i in samples:
		decor._time = float(i) * 0.002
		var value: float = decor.lamp_alpha(0)
		highest = maxf(highest, value)
		if value > previous + 0.001:
			rising += 1
		previous = value
	print("MEASURE|decor lamp|highest flicker opacity %.2f, %d rises in 2 s (%.1f flashes per second), cap %.1f flashes/s and %.2f" % [highest, rising, float(rising) / 2.0, decor.config.flash_hz, decor.config.max_flash_alpha])
	_check("decor: a lamp is never brighter than 0.3 (%.2f) and flickers at most 3 times a second (%.1f)" % [highest, float(rising) / 2.0], highest <= 0.3 + 0.0001 and float(rising) / 2.0 <= 3.0 and decor.config.flash_hz <= 3.0)
	await _free_level(level)
	# Reduced mode: static.
	_clean_state()
	var values: Dictionary = GameSettings.DEFAULTS.duplicate()
	values["corruption_effects"] = false
	GameSettings.save_settings(values)
	var quiet := LEVEL_THREE.instantiate() as LevelBase
	add_child(quiet)
	await _frames(3)
	var quiet_decor := quiet.get_node("Decor") as StormDecor
	quiet.player.global_position = Vector2(quiet_decor.puddles[0], 520.0)
	await _wait(0.6)
	quiet.player.global_position = Vector2(quiet_decor.chains[0], 560.0)
	quiet.player.velocity = Vector2(120.0, 0.0)
	await _frames(4)
	quiet.player.global_position = Vector2(quiet_decor.lamps[0], 560.0)
	await _frames(4)
	var steady: bool = true
	for i in quiet_decor.lamps.size():
		steady = steady and is_equal_approx(quiet_decor.lamp_alpha(i), quiet_decor.config.lamp_base_alpha)
	_check("decor: with «Efectos de corrupción» off nothing splashes, flickers or sways: the decor stays static", quiet_decor.reduced and quiet_decor.splash_count == 0 and quiet_decor.particles.is_empty() and steady and quiet_decor.sway[0] == 0.0)
	await _free_level(quiet)
	GameSettings.save_settings(GameSettings.DEFAULTS.duplicate())


func _free_level(level: LevelBase) -> void:
	level.free()
	await _frames(3)


# ---------------------------------------------------------------------------------------------
# Arena vents
# ---------------------------------------------------------------------------------------------

func _threshold_hp(boss: BossBase, index: int) -> float:
	return float(boss.health.max_health) * boss.stats.get_phase_thresholds()[index]


func _fight() -> LevelBase:
	var level := LEVEL_THREE.instantiate() as LevelBase
	(level.get_node("PossessionDirector") as PossessionDirector).play_when_headless = true
	add_child(level)
	await _frames(8)
	level.player.story_invulnerable = true
	await _frames(2)
	return level


# ---------------------------------------------------------------------------------------------
# Unchanged geometry and leaks
# ---------------------------------------------------------------------------------------------

func _test_unchanged_geometry() -> void:
	var level: Node = LEVEL_THREE.instantiate()
	var floors: Array[Node2D] = _floor_nodes(level)
	var widths: Array[float] = []
	for i in floors.size() - 1:
		widths.append((floors[i + 1].position.x - float(floors[i + 1].get("size").x) * 0.5) - (floors[i].position.x + float(floors[i].get("size").x) * 0.5))
	_check("geometry: the three gap widths are unchanged (%s)" % str(widths), widths == OLD_GAPS)
	var floor_ok: bool = floors[0].position.x == 650.0 and floors[1].position.x == 2193.5 and floors[2].position.x == 3713.5 and floors[3].position.x == 5717.5
	var checkpoints_ok: bool = true
	for i in 4:
		var name_of: String = ["CheckpointStart", "CheckpointMid1", "CheckpointMid2", "CheckpointArena"][i]
		checkpoints_ok = checkpoints_ok and (level.get_node("Content/%s" % name_of) as Node2D).position.x == CHECKPOINTS[i]
	_check("geometry: the floor positions and the four checkpoints are unchanged", floor_ok and checkpoints_ok)
	var camera: Rect2i = (level as LevelBase).camera_limits
	_check("geometry: the camera limit is unchanged (%d)" % camera.end.x, camera.end.x == 6745)
	level.free()
	_check("geometry: levels 1 and 2 are byte-identical to before", FileAccess.get_md5("res://frontend/levels/level_1.tscn") == LEVEL_ONE_MD5 and FileAccess.get_md5("res://frontend/levels/level_2.tscn") == LEVEL_TWO_MD5)


func _test_no_leaks() -> void:
	_clean_state()
	var counts: Array[int] = []
	for round in 4:
		var level := LEVEL_THREE.instantiate() as LevelBase
		add_child(level)
		await _wait(0.5)
		level.player.global_position = Vector2((level.get_node("Decor") as StormDecor).puddles[0], 520.0)
		await _wait(0.5)
		await _free_level(level)
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	print("MEASURE|node counts after repeated level 3 loads|%s" % str(counts))
	_check("leaks: no nodes are left behind after repeated level 3 loads (%s) and nothing is paused" % str(counts), counts[3] <= counts[1] + 4 and not get_tree().paused)
