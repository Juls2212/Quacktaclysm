extends Node
## Smoke test for Phase 15d-bis: the charge is never wasted on a platform, the boss never stands without an attack, the
## lily pads are raised on spring stems, boss 2 has 50 HP and the sword wave has a different color for each upgrade level.
## Lines starting with "MEASURE|" go to docs/BALANCE_REPORT.md. Development only. Run (alone; it takes a few minutes):
##   <godot> --headless --path game res://frontend/scenes/test/phase15d2_smoke_test.tscn
## Uses a redirected save path and a throwaway settings file; the real save, settings and controls are never touched.

const TEST_SAVE: String = "user://test_save_phase15d2.json"
const TEST_SETTINGS: String = "user://test_settings_phase15d2.cfg"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const PAD_SCENE: PackedScene = preload("res://backend/arena/bounce_pad.tscn")
const WAVE_SCENE: PackedScene = preload("res://backend/combat/sword_wave_projectile.tscn")
const BIOME_DIR: String = "res://frontend/levels/biome/"
const FLOOR_Y: float = 300.0
const MIN_CONTRAST: float = 2.5
const INK := Color(0.106, 0.098, 0.122)

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


func _physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _clean_state() -> void:
	Engine.time_scale = 1.0
	PauseLock.reset(get_tree())
	get_tree().paused = false
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.autosave_enabled = false
	AbilityCard.forget_all()
	BossDialogue.forget_all()
	GameSettings.save_settings(GameSettings.DEFAULTS.duplicate())


func _run() -> void:
	_clean_state()
	_test_guards()
	await _test_charge()
	await _test_idle_sweep()
	await _test_pads()
	await _test_shelter_margin()
	await _test_boss_health()
	await _test_wave_colors()
	await _test_wave_card_and_burst()
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

func _level(number: int) -> LevelBase:
	return (load("res://frontend/levels/level_%d.tscn" % number) as PackedScene).instantiate() as LevelBase


func _fight() -> LevelBase:
	var level: LevelBase = _level(2)
	add_child(level)
	await _frames(8)
	level.player.story_invulnerable = true
	level.player.global_position = level.encounter.global_position
	await _physics(10)
	return level


func _anchor_position(level: LevelBase, anchor_name: String) -> Vector2:
	return (level.find_child(anchor_name, true, false) as Node2D).global_position


func _patterns_by_id(boss: BossBase, id: StringName) -> BossPattern:
	for pattern in boss.patterns:
		if pattern.pattern_id == id:
			return pattern
	return null


# ---------------------------------------------------------------------------------------------
# Guards
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


# ---------------------------------------------------------------------------------------------
# 1. The charge is never wasted
# ---------------------------------------------------------------------------------------------

func _test_charge() -> void:
	_clean_state()
	var level: LevelBase = await _fight()
	var boss: BossBase = level.boss
	var player: Player = level.player
	var charge := _patterns_by_id(boss, &"charge") as ChargePattern
	_check("charge: it measures its lane before it starts (min useful lane %.0f px)" % charge.min_useful_lane, charge.min_useful_lane > 0.0)
	# On every platform the charge is ineligible, whatever the player does.
	var platform_spots: Array[String] = ["AnchorLowA", "AnchorLowB", "AnchorHighA", "AnchorHighB"]
	var player_spots: Array[Vector2] = [Vector2(4700.0, 574.0), Vector2(5400.0, 574.0), Vector2(4900.0, 484.0), Vector2(5330.0, 324.0)]
	var wasted_on_platform: int = 0
	for anchor_name in platform_spots:
		boss.reset_encounter()
		boss.global_position = _anchor_position(level, anchor_name)
		boss.velocity = Vector2.ZERO
		boss.activate(player)
		await _physics(6)
		for spot in player_spots:
			player.global_position = spot
			charge.cooldown_left = 0.0
			boss.current_phase = 1
			if charge.can_start(boss):
				wasted_on_platform += 1
		# Whichever way it would run, the lane of a platform is shorter than a useful charge.
		for direction in [-1, 1]:
			if charge.lane_available(boss, direction) >= charge.min_useful_lane:
				wasted_on_platform += 1
	_check("charge: it is never eligible while the boss stands on a platform (%d wasted cases)" % wasted_on_platform, wasted_on_platform == 0)
	# On the floor it is eligible only with a useful lane, and then it covers it.
	var floor_ok: bool = true
	var lanes: Array = []
	var eligible_count: int = 0
	var spots: Array[Vector2] = [Vector2(4700.0, 556.0), Vector2(5000.0, 556.0), Vector2(5250.0, 556.0), Vector2(5370.0, 556.0), Vector2(5470.0, 556.0)]
	for boss_spot in spots:
		for player_x in [4660.0, 4800.0, 5100.0, 5300.0, 5500.0]:
			boss.reset_encounter()
			boss.global_position = boss_spot
			boss.velocity = Vector2.ZERO
			boss.activate(player)
			await _physics(6)
			player.global_position = Vector2(player_x, 574.0)
			charge.cooldown_left = 0.0
			var direction: int = 1 if player_x >= boss_spot.x else -1
			var lane: float = charge.lane_available(boss, direction)
			var eligible: bool = charge.can_start(boss)
			lanes.append(lane)
			if eligible:
				eligible_count += 1
				floor_ok = floor_ok and lane >= charge.min_useful_lane
			else:
				# Not eligible: a short lane, or the player is closer than the charge's own minimum distance.
				floor_ok = floor_ok and (lane < charge.min_useful_lane or absf(player_x - boss_spot.x) < charge.min_distance_to_target)
	_check("charge: on the floor it is eligible exactly when its lane is long enough (%d of %d cases)" % [eligible_count, lanes.size()], floor_ok and eligible_count > 0)
	# A real charge on the floor covers its planned lane and the telegraph drew that lane.
	boss.reset_encounter()
	boss.global_position = Vector2(5370.0, 556.0)
	boss.velocity = Vector2.ZERO
	boss.activate(player)
	await _physics(10)
	player.global_position = Vector2(4800.0, 574.0)
	charge.cooldown_left = 0.0
	var start_x: float = boss.global_position.x
	boss._set_state(BossBase.State.IDLE)
	boss._start_pattern(charge)
	await _physics(25)
	var telegraph := boss.find_child("Telegraph", true, false) as TelegraphDrawer
	var drawn_lane: float = telegraph.reach if telegraph != null else -1.0
	var guard: int = 0
	while boss.state == BossBase.State.PATTERN and guard < 60 * 6:
		guard += 1
		await get_tree().physics_frame
	var covered: float = absf(boss.global_position.x - start_x)
	_check("charge: the telegraph draws the REAL lane (%.0f px of %.0f px nominal)" % [drawn_lane, charge.charge_speed * charge.charge_duration],
		telegraph != null and absf(drawn_lane - maxf(charge.planned_lane, 1.0)) < 1.0 and charge.planned_lane >= charge.min_useful_lane)
	_check("charge: the charge covers its planned lane, so it is never wasted (%.0f px of %.0f px)" % [covered, charge.planned_lane], covered >= charge.planned_lane * 0.75)
	# A charge toward a wall near the boss is clipped, drawn clipped and still reaches the wall.
	boss.reset_encounter()
	boss.global_position = Vector2(5330.0, 556.0)
	boss.velocity = Vector2.ZERO
	boss.activate(player)
	await _physics(10)
	player.global_position = Vector2(5500.0, 574.0)
	charge.cooldown_left = 0.0
	var wall_lane: float = charge.lane_available(boss, 1)
	_check("charge: toward the right wall the lane is clipped to the wall (%.0f px, less than the full %.0f)" % [wall_lane, charge.charge_speed * charge.charge_duration * boss.speed_multiplier],
		wall_lane < charge.charge_speed * charge.charge_duration * boss.speed_multiplier and wall_lane >= 0.0)
	# The audit: the other patterns and bosses 1 and 3.
	var swipe := _patterns_by_id(boss, &"swipe") as SwipePattern
	_check("audit: the swipe has no lane (it hits in front of the boss, near the player), so it is never wasted by an edge", swipe != null and swipe.max_distance_to_target > 0.0)
	level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 2. The boss never stands without an attack
# ---------------------------------------------------------------------------------------------

func _test_idle_sweep() -> void:
	_clean_state()
	var level: LevelBase = await _fight()
	var boss: BossBase = level.boss
	var player: Player = level.player
	var limit: float = boss.stats.max_idle_time
	_check("idle: the maximum idle time is exported on the boss stats (%.1f s)" % limit, is_equal_approx(limit, 1.5))
	var boss_spots: Array[String] = ["AnchorFloor1", "AnchorFloor2", "AnchorFloor3", "AnchorLowA", "AnchorLowB", "AnchorHighA", "AnchorHighB"]
	var player_spots: Array = [
		["floor left", Vector2(4680.0, 574.0)], ["floor middle", Vector2(5000.0, 574.0)], ["floor right", Vector2(5500.0, 574.0)],
		["low platform A", Vector2(4900.0, 484.0)], ["low platform B", Vector2(5350.0, 484.0)],
		["high platform A", Vector2(4960.0, 324.0)], ["high platform B", Vector2(5330.0, 324.0)],
		["air above pad B", Vector2(5150.0, 360.0)],
	]
	Engine.time_scale = 4.0
	var worst: float = 0.0
	var worst_case: String = ""
	var failures_here: int = 0
	var started_by: Dictionary = {}
	for phase in [1, 2]:
		for boss_name in boss_spots:
			for spot_entry in player_spots:
				if phase == 2 and (spot_entry[0] == "floor right" or spot_entry[0] == "low platform B" or spot_entry[0] == "high platform A"):
					continue
				boss.reset_encounter()
				boss.global_position = _anchor_position(level, boss_name)
				boss.velocity = Vector2.ZERO
				player.global_position = spot_entry[1]
				player.velocity = Vector2.ZERO
				boss.activate(player)
				boss.current_phase = phase
				var ticks: int = 0
				var idle: float = 0.0
				while boss.state != BossBase.State.PATTERN and ticks < 60 * 4:
					await get_tree().physics_frame
					ticks += 1
					# Game time of each tick (the same whatever the time scale does to the step).
					idle += get_physics_process_delta_time()
				var chosen: String = String(boss.current_pattern_id) if boss.state == BossBase.State.PATTERN else "none"
				started_by[chosen] = int(started_by.get(chosen, 0)) + 1
				if idle > worst:
					worst = idle
					worst_case = "phase %d, boss at %s, player at %s -> %s" % [phase, boss_name, spot_entry[0], chosen]
				if boss.state != BossBase.State.PATTERN or idle > limit + 0.1:
					failures_here += 1
					print("IDLE-FAIL: phase %d boss %s player %s idle %.2f s (%s)" % [phase, boss_name, spot_entry[0], idle, chosen])
	Engine.time_scale = 1.0
	print("MEASURE|boss 2 idle sweep|worst idle %.2f s (limit %.1f s)|%s|started by %s" % [worst, limit, worst_case, str(started_by)])
	_check("idle: in every combination of boss spot and player spot a telegraphed attack starts within %.1f s (worst %.2f s: %s)" % [limit, worst, worst_case], failures_here == 0)
	_check("idle: the fallbacks were used (the volley, the leap and the stomp are all in the pool)", _patterns_by_id(boss, &"volley_fallback") != null and _patterns_by_id(boss, &"leap_fallback") != null
		and _patterns_by_id(boss, &"leap_stomp") != null)
	# The fallback order is volley, then leap, then stomp.
	var priorities: Array[int] = []
	for pattern in boss.patterns:
		if pattern.fallback_priority > 0:
			priorities.append(pattern.fallback_priority)
	priorities.sort()
	_check("idle: the fallbacks have the priorities 1 (volley), 2 (leap toward the player) and 3 (stomp)", priorities == [1, 2, 3])
	var volley := _patterns_by_id(boss, &"volley_fallback") as ProjectileVolleyPattern
	_check("idle: the fallback volley can aim steeply (the player above or below)", volley != null and volley.allow_steep_aim)
	# The fallbacks never enter the random rotation.
	boss.reset_encounter()
	boss.global_position = _anchor_position(level, "AnchorFloor3")
	player.global_position = Vector2(5000.0, 574.0)
	boss.activate(player)
	var in_rotation: bool = false
	for i in 40:
		var chosen_pattern: BossPattern = boss._choose_pattern()
		if chosen_pattern != null and chosen_pattern.fallback_priority > 0:
			in_rotation = true
	_check("idle: the fallbacks are never chosen from the normal rotation", not in_rotation)
	level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 3. Raised lily pads on spring stems
# ---------------------------------------------------------------------------------------------

func _test_pads() -> void:
	_clean_state()
	GameState.decisions.clear()
	GameState.record_decision("fragment_level_1", "placeholder_boss", 1, GameState.CHOICE_RELEASED)
	var level: LevelBase = _level(2)
	add_child(level)
	await _frames(8)
	level.player.story_invulnerable = true
	var config := BounceConfig.get_default()
	var stats := PlayerStats.new()
	var pads: Array[Node] = level.find_children("ArenaPad*", "Area2D", true, false)
	_check("pads: three pads in the arena, raised %.0f px over the floor" % config.pad_height, pads.size() == 3 and is_equal_approx(config.pad_height, 56.0))
	var raised: bool = true
	for node in pads:
		var pad := node as BouncePad
		raised = raised and absf(pad.floor_y() - 600.0) < 0.5 and absf(pad.top_y() - (600.0 - config.pad_height)) < 0.5
	_check("pads: each pad top is 56 px over the floor and its stem stands on the floor", raised)
	# Launch numbers from the stats by calculation.
	var rise: float = config.launch_velocity * config.launch_velocity / (2.0 * stats.gravity)
	var peak: float = config.pad_height + config.top_margin + rise
	var high_tier: float = 250.0
	var head_room: float = 440.0 - (peak + 52.0)
	print("MEASURE|pad numbers|launch %.0f px/s|rise %.1f px from the pad top|feet peak %.1f px over the floor|margin over the high tier %.1f px|clearance to the ceiling %.1f px" % [config.launch_velocity, rise, peak, peak - high_tier, head_room])
	_check("pads: the launch from the pad top reaches the high tier with margin (peak %.0f px over the floor, tier at %.0f px, margin %.0f px)" % [peak, high_tier, peak - high_tier], peak - high_tier >= 30.0 and head_room > 20.0)
	var jump_rise: float = stats.jump_velocity * stats.jump_velocity / (2.0 * stats.gravity)
	_check("pads: the pad top is reachable with the normal jump (a %.0f px jump, the pad at %.0f px)" % [jump_rise, config.pad_height + config.top_margin], jump_rise > config.pad_height + config.top_margin + 20.0)
	# The high tier stays reachable only through a pad or the double jump: a jump + double jump from the FLOOR rises less.
	var from_floor: float = jump_rise + stats.double_jump_velocity * stats.double_jump_velocity / (2.0 * stats.gravity)
	_check("pads: the high tier is still out of reach from the floor with the double jump alone (%.0f of 250 px)" % from_floor, from_floor < high_tier)
	# The stem is not solid: nothing in the pad collides with the player and the player walks beneath it.
	var pad_a := level.get_node("Content/ArenaPadA") as BouncePad
	var solid_children: int = 0
	for child in pad_a.find_children("*", "CollisionObject2D", true, false):
		solid_children += 1 if child is StaticBody2D or child is CharacterBody2D or child is RigidBody2D else 0
	_check("pads: the stem is not solid (no body in the pad) and the pad only sees the player", solid_children == 0 and pad_a.collision_layer == 0
		and pad_a.collision_mask == CombatLayers.layer_bit(CombatLayers.LAYER_PLAYER))
	var player: Player = level.player
	player.global_position = Vector2(pad_a.global_position.x - 140.0, 574.0)
	player.velocity = Vector2.ZERO
	await _physics(20)
	Input.action_press(&"move_right")
	await _physics(70)
	Input.action_release(&"move_right")
	_check("pads: walking beneath a pad does not launch it and the stem does not block the way (x %.0f, past the pad at %.0f)" % [player.global_position.x, pad_a.global_position.x],
		pad_a.launch_count == 0 and player.global_position.x > pad_a.global_position.x + 40.0 and player.is_on_floor())
	# A jump from the floor reaches the pad top and the pad throws the player up.
	var launched: bool = false
	for offset in [-170.0, -150.0, -130.0, -110.0, -190.0]:
		player.global_position = Vector2(pad_a.global_position.x + offset, 574.0)
		player.velocity = Vector2.ZERO
		await _physics(25)
		pad_a.cooldown_left = 0.0
		var before: int = pad_a.launch_count
		Input.action_press(&"move_right")
		Input.action_press(&"jump")
		await _physics(22)
		Input.action_release(&"jump")
		await _physics(30)
		Input.action_release(&"move_right")
		if pad_a.launch_count > before:
			launched = true
			break
		await _physics(60)
	_check("pads: a jump from the floor lands on the raised pad and launches the player", launched)
	await _physics(120)
	# The stem compresses like a spring when the pad launches.
	var art := pad_a.get_node("Art") as BouncePadArt
	pad_a.launched.emit(player)
	await _frames(4)
	var squash_seen: float = art.compression
	await get_tree().create_timer(config.squash_time + 0.3).timeout
	_check("pads: the stem squashes when the pad launches (compression %.2f) and settles back (%.2f)" % [squash_seen, art.compression], squash_seen > 0.25 and is_zero_approx(art.compression))
	# Enemies and the boss ignore pads.
	var enemy := (load("res://backend/enemies/melee_enemy.tscn") as PackedScene).instantiate() as EnemyBase
	enemy.global_position = Vector2(pad_a.global_position.x, pad_a.global_position.y - 120.0)
	level.add_child(enemy)
	pad_a.cooldown_left = 0.0
	var count_before: int = pad_a.launch_count
	await _physics(90)
	_check("pads: enemies ignore them", pad_a.launch_count == count_before)
	var boss: BossBase = level.boss
	boss.global_position = Vector2(pad_a.global_position.x, pad_a.global_position.y - 120.0)
	boss.velocity = Vector2.ZERO
	await _physics(60)
	_check("pads: the boss ignores them", pad_a.launch_count == count_before)
	# The pads and the platforms are above the spike band.
	var hazard := level.get_node("Content/FloorHazard") as FloorHazard
	var band_top: float = hazard.global_position.y - hazard.config.band_height
	var safe: bool = true
	for node in pads:
		safe = safe and (node as BouncePad).top_y() < band_top
	for node in level.find_children("Arena*", "StaticBody2D", true, false):
		var shape_node := node.get_node_or_null(^"CollisionShape2D") as CollisionShape2D
		if shape_node != null and shape_node.shape is RectangleShape2D:
			var top: float = (node as Node2D).global_position.y - (shape_node.shape as RectangleShape2D).size.y * 0.5
			if String(node.name).begins_with("ArenaLow") or String(node.name).begins_with("ArenaHigh"):
				safe = safe and top < band_top
	_check("pads: the pads and the platforms are above the spikes, so they are safe spots (band top %.0f)" % band_top, safe)
	level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 3b. The shelter margin with the raised pads
# ---------------------------------------------------------------------------------------------

## The shortest time (s) in which a player standing at `x` can be on a safe spot: a lily pad (landed on from a jump, the pad top
## at pad_height + top_margin over the floor) or a low platform. Walks for a while, then jumps while steering; the player's
## real stats drive the numbers.
func _shelter_time(x0: float, pad_xs: Array, lows: Array, stats: PlayerStats, config: BounceConfig) -> float:
	var step: float = 1.0 / 60.0
	var best: float = INF
	var pad_top: float = config.pad_height + config.top_margin
	var pad_half: float = config.trigger_size.x * 0.5 - 2.0
	for direction in [-1.0, 1.0]:
		for walk_index in 25:
			var walk_time: float = float(walk_index) * 0.05
			for steer in [-1.0, 0.0, 1.0]:
				var x: float = x0
				var vx: float = 0.0
				var vy: float = 0.0
				var height: float = 0.0
				var previous: float = 0.0
				var time: float = 0.0
				var airborne: bool = false
				for i in 240:
					if not airborne:
						if time < walk_time:
							vx = move_toward(vx, direction * stats.max_speed, stats.acceleration * step)
						else:
							airborne = true
							vy = -stats.jump_velocity
					if airborne:
						if steer != 0.0:
							vx = move_toward(vx, steer * stats.max_speed, stats.air_acceleration * step)
						vy -= stats.gravity * step
					x += vx * step
					time += step
					if not airborne:
						continue
					previous = height
					height += vy * step
					if vy < 0.0:
						for pad_x in pad_xs:
							if previous >= pad_top and height < pad_top and absf(x - float(pad_x)) <= pad_half:
								best = minf(best, time)
						for low in lows:
							var span: Vector3 = low
							if previous >= span.z and height < span.z and x >= span.x and x <= span.y:
								best = minf(best, time)
						if height <= 0.0:
							break
	return best


func _test_shelter_margin() -> void:
	_clean_state()
	var level: LevelBase = _level(2)
	add_child(level)
	await _frames(6)
	var stats := PlayerStats.new()
	var config := BounceConfig.get_default()
	var hazard := level.get_node("Content/FloorHazard") as FloorHazard
	var pad_xs: Array = []
	for node in level.find_children("ArenaPad*", "Area2D", true, false):
		pad_xs.append((node as BouncePad).global_position.x)
	var lows: Array = []
	for node in level.find_children("ArenaLow*", "StaticBody2D", true, false):
		var shape_node := node.get_node(^"CollisionShape2D") as CollisionShape2D
		var size: Vector2 = (shape_node.shape as RectangleShape2D).size
		var center: Vector2 = (node as Node2D).global_position
		lows.append(Vector3(center.x - size.x * 0.5, center.x + size.x * 0.5, 600.0 - (center.y - size.y * 0.5)))
	var left: float = hazard.global_position.x
	var right: float = left + hazard.length
	var worst: float = 0.0
	var worst_x: float = left
	var x: float = left
	while x <= right:
		var best: float = _shelter_time(x, pad_xs, lows, stats, config)
		if best > worst:
			worst = best
			worst_x = x
		x += 20.0
	var warning: float = hazard.config.warning_time
	print("MEASURE|shelter with raised pads|worst %.2f s at x %.0f|warning %.1f s|margin %.2f s" % [worst, worst_x, warning, warning - worst])
	_check("shelter: from every floor x a safe spot (a raised pad by a jump, or a low platform) is reached within the warning with a margin of at least 0.3 s (worst %.2f s at x %.0f of %.1f s)" % [worst, worst_x, warning],
		worst < INF and warning - worst >= 0.3)
	_check("shelter: the spike warning and the other spike values did not change (1.2 s, 3.0 s, 4.0 s)", is_equal_approx(warning, 1.2) and is_equal_approx(hazard.config.active_time, 3.0) and is_equal_approx(hazard.config.rest_time, 4.0))
	level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 4. Boss 2 has 50 HP
# ---------------------------------------------------------------------------------------------

func _test_boss_health() -> void:
	_clean_state()
	var level: LevelBase = _level(2)
	(level.get_node("PossessionDirector") as PossessionDirector).play_when_headless = true
	add_child(level)
	await _frames(8)
	level.player.global_position = level.encounter.global_position
	await _physics(10)
	var boss: BossBase = level.boss
	var director := level.get_node("PossessionDirector") as PossessionDirector
	var threshold: float = float(boss.health.max_health) * boss.stats.phase_2_health_ratio
	_check("health: boss 2 has 50 HP and its line is at 55%% (%.1f HP)" % threshold, boss.stats.max_health == 50 and boss.health.max_health == 50 and is_equal_approx(threshold, 27.5))
	var above: int = int(floor(threshold)) + 1
	boss.health.apply_damage(DamageInfo.create(boss.health.current_health - above, Vector2.ZERO, level.player, CombatLayers.Team.PLAYER))
	await _physics(4)
	_check("health: at %d HP (above the line) nothing happens" % above, director.sequences_started == 0 and boss.state != BossBase.State.PHASE_TRANSITION)
	boss.health.apply_damage(DamageInfo.create(1, Vector2.ZERO, level.player, CombatLayers.Team.PLAYER))
	await _physics(4)
	_check("health: at %d HP the possession sequence starts once" % boss.health.current_health, director.sequences_started == 1 and director.active and boss.state == BossBase.State.PHASE_TRANSITION)
	var guard: int = 0
	while director.active and guard < 60 * 8:
		director.elapsed = maxf(director.elapsed, director.duration - 0.02)
		await get_tree().process_frame
		guard += 1
	await _physics(100)
	boss.health.apply_damage(DamageInfo.create(1, Vector2.ZERO, level.player, CombatLayers.Team.PLAYER))
	await _physics(6)
	_check("health: phase 2 begins after the sequence and it does not trigger again", boss.current_phase == 2 and director.sequences_started == 1)
	var stats := PlayerStats.new()
	var sword_dps: float = float(stats.attack_damage) / 0.45
	var kill: float = 50.0 / sword_dps
	print("MEASURE|boss 2 ideal sword-only kill time|50 HP / %.2f dps = %.1f s (60 HP was %.1f s)" % [sword_dps, kill, 60.0 / sword_dps])
	_check("health: the ideal sword-only kill time is 22.5 s by calculation (50 HP at 2.22 dps)", absf(kill - 22.5) < 0.1)
	level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 5. Sword wave colors
# ---------------------------------------------------------------------------------------------

func _channel(value: float) -> float:
	return value / 12.92 if value <= 0.03928 else pow((value + 0.055) / 1.055, 2.4)


func _luminance(color: Color) -> float:
	return 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b)


func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _hue_distance(a: float, b: float) -> float:
	var d: float = absf(a - b)
	return minf(d, 1.0 - d)


func _is_warm(color: Color) -> bool:
	# Red and orange: the enemy projectile palette (hue 0 to 0.12, or wrapping to 0.95).
	return color.s > 0.15 and (color.h < 0.12 or color.h > 0.95)


func _test_wave_colors() -> void:
	var config := load("res://backend/player/default_sword_wave_config.tres") as SwordWaveConfig
	var tiers: Array[SwordWaveTier] = [config.get_tier(0), config.get_tier(1), config.get_tier(2)]
	_check("wave: three tiers", config.tiers.size() == 3)
	_check("wave: tier 0 is blue-white, tier 1 emerald, tier 2 violet", tiers[0].tint.h > 0.5 and tiers[0].tint.h < 0.62 and tiers[0].tint.v > 0.9 and tiers[1].tint.h > 0.38 and tiers[1].tint.h < 0.46
		and tiers[2].tint.h > 0.7 and tiers[2].tint.h < 0.8, "%.2f %.2f %.2f" % [tiers[0].tint.h, tiers[1].tint.h, tiers[2].tint.h])
	var different: bool = true
	for i in 3:
		for j in range(i + 1, 3):
			different = different and (tiers[i].tint.r - tiers[j].tint.r) * (tiers[i].tint.r - tiers[j].tint.r) + (tiers[i].tint.g - tiers[j].tint.g) * (tiers[i].tint.g - tiers[j].tint.g) \
				+ (tiers[i].tint.b - tiers[j].tint.b) * (tiers[i].tint.b - tiers[j].tint.b) > 0.15 and _hue_distance(tiers[i].tint.h, tiers[j].tint.h) > 0.12
	_check("wave: the three colors are clearly different from each other", different)
	var warm: bool = false
	for tier in tiers:
		for color in [tier.tint, tier.rim_color, tier.glow_color, tier.core_color if tier.core_color.a > 0.0 else tier.tint]:
			warm = warm or _is_warm(color)
			warm = warm or _hue_distance(color.h, DangerOutline.HALO.h) < 0.2 and color.s > 0.15
	_check("wave: no color of any tier is red, orange or near the enemy projectile halo", not warm)
	_check("wave: a stronger wave has a longer trail and a brighter glow (trails %.0f / %.0f / %.0f, glow %.2f / %.2f / %.2f)" % [tiers[0].trail_length, tiers[1].trail_length, tiers[2].trail_length, tiers[0].glow_strength, tiers[1].glow_strength, tiers[2].glow_strength],
		tiers[0].trail_length < tiers[1].trail_length and tiers[1].trail_length < tiers[2].trail_length and tiers[0].glow_strength < tiers[1].glow_strength and tiers[1].glow_strength < tiers[2].glow_strength)
	_check("wave: only the violet tier has a dark core (and a light rim)", tiers[0].core_color.a == 0.0 and tiers[1].core_color.a == 0.0 and tiers[2].core_color.a > 0.0
		and _luminance(tiers[2].core_color) < 0.02 and _luminance(tiers[2].rim_color) > 0.6)
	# Nothing but the visuals changed.
	# Phase 15d-ter raised the damage of the stronger tiers on purpose (1, 2, 3); everything else is as before.
	var recorded: Array = [[1, 520.0, 0.9, 1.0, 0, 1.0], [2, 580.0, 1.1, 1.35, 1, 0.9], [3, 640.0, 1.3, 1.7, 2, 1.2]]
	var gameplay_ok: bool = true
	for i in 3:
		var tier: SwordWaveTier = tiers[i]
		var row: Array = recorded[i]
		gameplay_ok = gameplay_ok and tier.damage == row[0] and is_equal_approx(tier.speed, row[1]) and is_equal_approx(tier.lifetime, row[2]) and is_equal_approx(tier.size_scale, row[3]) \
			and tier.pierce_count == row[4] and is_equal_approx(tier.cooldown, row[5])
	_check("wave: damage, speed, lifetime, size, piercing and cooldown of every tier are unchanged", gameplay_ok)
	var probe := WAVE_SCENE.instantiate() as Projectile
	add_child(probe)
	await _frames(2)
	var shape := (probe.get_node("Hitbox/CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	_check("wave: the hitbox of the wave scene is unchanged (16 x 44) and the glow cannot enlarge it", shape != null and shape.size == Vector2(16.0, 44.0))
	probe.free()
	var launch_ok: bool = true
	for i in 3:
		var wave := WAVE_SCENE.instantiate() as Projectile
		add_child(wave)
		wave.global_position = Vector2(-5000.0, -5000.0)
		wave.launch(Vector2.RIGHT, CombatLayers.Team.PLAYER, config.build_projectile_stats(i), null)
		await _frames(1)
		var hit_shape := (wave.get_node("Hitbox/CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
		launch_ok = launch_ok and wave.stats.glow_strength == tiers[i].glow_strength and wave.stats.trail_length == tiers[i].trail_length and wave.hitbox.damage == tiers[i].damage \
			and absf(hit_shape.size.y - 44.0 * tiers[i].size_scale) < 0.01 and is_equal_approx(wave.stats.speed, tiers[i].speed)
		wave.free()
	_check("wave: a launched wave carries its tier look and the hitbox grows only with the tier size scale as before", launch_ok)
	# Contrast against every background and the arenas (the Phase 14e rule: best of the colors and the dark outline).
	var presentation := load("res://frontend/presentation/default_profile_presentation.tres") as ProfilePresentation
	var biomes: Array[Biome] = []
	for number in [1, 2, 3]:
		var level_scene := _level(number)
		var candidates: Array[Node] = [level_scene]
		candidates.append_array(level_scene.find_children("*", "", true, false))
		for node in candidates:
			var value: Variant = node.get(&"biome")
			if value is Biome and not biomes.has(value):
				biomes.append(value as Biome)
		level_scene.free()
	var worst_by_tier: Array[float] = [99.0, 99.0, 99.0]
	var worst_violet_on_corrupt: float = 99.0
	for biome in biomes:
		var scenery: Array[Color] = [biome.sky_top, biome.sky_bottom, biome.haze, biome.far_color, biome.mid_color, biome.near_color]
		var ground: Array[Color] = [biome.grass, biome.grass_dark, biome.soil, biome.soil_dark, biome.rock, biome.rock_dark]
		for profile in ["neutral", "compassionate", "corrupt"]:
			var tint: Color = presentation.get_look(profile).background_tint
			var shown: Array[Color] = []
			for color in scenery:
				shown.append(Color(clampf(color.r * tint.r, 0.0, 1.0), clampf(color.g * tint.g, 0.0, 1.0), clampf(color.b * tint.b, 0.0, 1.0)))
			for i in 3:
				for bg in shown:
					var value: float = maxf(maxf(_contrast(tiers[i].tint, bg), _contrast(tiers[i].rim_color, bg)), _contrast(INK, bg))
					if tiers[i].core_color.a > 0.0:
						value = maxf(value, _contrast(tiers[i].core_color, bg))
					worst_by_tier[i] = minf(worst_by_tier[i], value)
			if profile == "corrupt":
				for bg in shown:
					worst_violet_on_corrupt = minf(worst_violet_on_corrupt, maxf(_contrast(tiers[2].rim_color, bg), _contrast(tiers[2].core_color, bg)))
		for i in 3:
			for bg in ground:
				var ground_value: float = maxf(maxf(_contrast(tiers[i].tint, bg), _contrast(tiers[i].rim_color, bg)), _contrast(INK, bg))
				if tiers[i].core_color.a > 0.0:
					ground_value = maxf(ground_value, _contrast(tiers[i].core_color, bg))
				worst_by_tier[i] = minf(worst_by_tier[i], ground_value)
	print("MEASURE|wave contrast|tier 0 worst %.2f|tier 1 worst %.2f|tier 2 worst %.2f|violet rim and core on the corrupt profile worst %.2f|%d biomes" % [worst_by_tier[0], worst_by_tier[1], worst_by_tier[2], worst_violet_on_corrupt, biomes.size()])
	_check("wave: every tier reads against the three profile backgrounds and the arenas (worst %.2f / %.2f / %.2f, >= %.1f)" % [worst_by_tier[0], worst_by_tier[1], worst_by_tier[2], MIN_CONTRAST],
		biomes.size() >= 3 and worst_by_tier[0] >= MIN_CONTRAST and worst_by_tier[1] >= MIN_CONTRAST and worst_by_tier[2] >= MIN_CONTRAST)
	_check("wave: the violet tier does not disappear on the violet corrupt background (rim and dark core worst %.2f)" % worst_violet_on_corrupt, worst_violet_on_corrupt >= MIN_CONTRAST)


# ---------------------------------------------------------------------------------------------
# 5b. The card and the hit effect
# ---------------------------------------------------------------------------------------------

func _test_wave_card_and_burst() -> void:
	_clean_state()
	var config := load("res://backend/player/default_sword_wave_config.tres") as SwordWaveConfig
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	var level: LevelBase = _level(1)
	var intro := level.get_node("AbilityIntro") as AbilityIntro
	intro.play_when_headless = true
	add_child(level)
	await _frames(6)
	GameState.record_decision("fragment_level_1", "placeholder_boss", 1, GameState.CHOICE_KEPT)
	level.decision_flow.decision_made.emit("fragment_level_1", GameState.CHOICE_KEPT)
	await _frames(8)
	var card: AbilityCard = intro.card
	var tier_one: SwordWaveTier = config.get_tier(1)
	_check("card: the wave upgrade card shows the color of the new tier (an emerald swatch)", card != null and card.is_open and card.swatch_color.is_equal_approx(tier_one.tint), str(card.swatch_color) if card != null else "null")
	if card != null:
		card._elapsed = 1.0
		card._input(accept)
	await _frames(4)
	level.free()
	await _frames(2)
	# The hit effect of a wave takes the color of its tier.
	_clean_state()
	var world := Node2D.new()
	add_child(world)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	floor_body.position = Vector2(400.0, FLOOR_Y + 20.0)
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(3000.0, 40.0)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	var enemy := (load("res://backend/enemies/melee_enemy.tscn") as PackedScene).instantiate() as EnemyBase
	enemy.position = Vector2(300.0, FLOOR_Y - 30.0)
	world.add_child(enemy)
	enemy.health.max_health = 999
	enemy.health.reset()
	await _physics(5)
	var tier_two: SwordWaveTier = config.get_tier(2)
	var wave := WAVE_SCENE.instantiate() as Projectile
	world.add_child(wave)
	wave.global_position = Vector2(230.0, FLOOR_Y - 30.0)
	wave.launch(Vector2.RIGHT, CombatLayers.Team.PLAYER, config.build_projectile_stats(2), null)
	var burst: WaveBurst = null
	for i in 90:
		await get_tree().physics_frame
		for node in world.get_children():
			if node is WaveBurst:
				burst = node as WaveBurst
		if burst != null:
			break
	_check("burst: a wave that hits something makes a burst in the colors of its tier", burst != null and burst.glow_color.is_equal_approx(tier_two.glow_color) and burst.rim_color.is_equal_approx(tier_two.rim_color)
		and burst.core_color.is_equal_approx(tier_two.core_color))
	await get_tree().create_timer(WaveBurst.LIFETIME + 0.3).timeout
	var leftover: int = 0
	for node in world.get_children():
		leftover += 1 if node is WaveBurst else 0
	_check("burst: it frees itself", leftover == 0)
	# An enemy projectile has no wave glow and draws nothing extra.
	var enemy_projectile := (load("res://backend/combat/projectile.tscn") as PackedScene).instantiate() as Projectile
	world.add_child(enemy_projectile)
	enemy_projectile.global_position = Vector2(-4000.0, -4000.0)
	enemy_projectile.launch(Vector2.LEFT, CombatLayers.Team.ENEMY, load("res://backend/combat/stats/enemy_projectile_stats.tres") as ProjectileStats, null)
	await _frames(2)
	_check("burst: an enemy projectile keeps its orange-red halo and has no wave glow", enemy_projectile.stats.glow_strength == 0.0 and enemy_projectile.get_node_or_null(^"GlowBehind") == null)
	world.free()
	await _frames(2)
