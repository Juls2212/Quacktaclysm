extends Node
## Smoke test for Phase 15j: boss 3 redesigned (the possessed duck, the summoned ducklings, the collapsing floor, the red eye). The floating
## eye, the sweeping beam and the arena wind vents are gone; phase 1 is the duck alone; phase 2 is the summoner stage (platforms
## and a boss-only perch, ducklings in batches of 2 with a shield, the floor that trembles and collapses, the platform barrage, the vulnerable
## window, the cycle); phase 3 is the red eye with red lightning and the duck. Margins are computed from the REAL player
## numbers; times are real GAME time (the physics delta), never ticks under a time scale. Lines starting with "MEASURE|" go to the docs.
## Development only. Run (alone, a few minutes):
##   <godot> --headless --path game res://frontend/scenes/test/phase15j_smoke_test.tscn
## Uses a redirected save path and a throwaway settings file; the real save, settings and controls are never touched.

const TEST_SAVE: String = "user://test_save_phase15j.json"
const TEST_SETTINGS: String = "user://test_settings_phase15j.cfg"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const BIOME_DIR: String = "res://frontend/levels/biome/"
const MIN_CONTRAST: float = 2.5
const LEVEL_ONE_MD5: String = "0e26106a46848215f2ec25d5280c1fed"
const LEVEL_TWO_MD5: String = "09e2ccd6a5c2c4e0b53846990e7eef61"

var failures: int = 0
var real_save_before: String = ""
var real_settings_before: String = ""
var real_controls_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig
var player_stats: PlayerStats = load("res://backend/player/default_player_stats.tres") as PlayerStats
var config: StageConfig = StageConfig.get_default()
var boss_stats: BossStats = load("res://backend/bosses/stats/boss_three_stats.tres") as BossStats
var started_ms: int = 0


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
	started_ms = Time.get_ticks_msec()
	_clean_state()
	_test_guards()
	await _test_removed()
	_test_config_and_numbers()
	_test_platform_math()
	_test_barrage_math()
	_test_bolt_math()
	_test_balance_numbers()
	_test_contrast()
	await _test_phase_one()
	await _test_thresholds_and_possession()
	await _test_cycle()
	await _test_phase_three()
	await _test_cancel_each_mechanic()
	await _test_death_retry_leave_pause()
	await _test_extra_tool_states()
	await _test_reduced_and_flash()
	_clean_state()
	SaveSystem.purge()
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	GameSettings.path_override = ""
	GameState.autosave_enabled = true
	_check("the real save file was not touched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	_check("the real settings file was not touched", _read_file(GameSettings.PATH) == real_settings_before)
	_check("the real controls file was not touched", _read_file(ControlsConfig.DEFAULT_PATH) == real_controls_before)
	print("MEASURE|test duration %.0f s" % (float(Time.get_ticks_msec() - started_ms) / 1000.0))
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------

func _level_three() -> LevelBase:
	var level := (load("res://frontend/levels/level_3.tscn") as PackedScene).instantiate() as LevelBase
	(level.get_node("PossessionDirector") as PossessionDirector).play_when_headless = true
	return level


## Boss 3 awake against the player in the arena (the gate is closed). The player is invulnerable unless asked.
func _fight(vulnerable: bool = false) -> LevelBase:
	var level: LevelBase = _level_three()
	add_child(level)
	await _frames(8)
	level.player.story_invulnerable = not vulnerable
	level.player.global_position = level.encounter.global_position
	await _physics(12)
	return level


func _damage(level: LevelBase, amount: int) -> void:
	level.boss.health.apply_damage(DamageInfo.create(amount, Vector2.ZERO, level.player, CombatLayers.Team.PLAYER))


func _hurt_to(level: LevelBase, remaining: int) -> void:
	var amount: int = level.boss.health.current_health - remaining
	if amount > 0:
		_damage(level, amount)


func _threshold_hp(boss: BossBase, index: int) -> float:
	return float(boss.health.max_health) * boss.stats.get_phase_thresholds()[index]


func _skip_possession(director: PossessionDirector) -> void:
	var guard: int = 0
	while director.active and guard < 60 * 8:
		director.elapsed = maxf(director.elapsed, director.duration - 0.02)
		await get_tree().process_frame
		guard += 1
	await _physics(100)


func _walk_time(distance: float) -> float:
	if distance <= 0.0:
		return 0.0
	var accel_distance: float = player_stats.max_speed * player_stats.max_speed / (2.0 * player_stats.acceleration)
	if distance <= accel_distance:
		return sqrt(2.0 * distance / player_stats.acceleration)
	return player_stats.max_speed / player_stats.acceleration + (distance - accel_distance) / player_stats.max_speed


func _pattern(boss: BossBase, id: StringName) -> BossPattern:
	for pattern in boss.patterns:
		if pattern.pattern_id == id:
			return pattern
	return null


func _stage(level: LevelBase) -> BossStage:
	return level.boss.get_meta(&"stage") as BossStage


func _hit(boss: BossBase, kind: StringName, amount: int = 1) -> bool:
	return boss.hurtbox.receive_hit(DamageInfo.create(amount, Vector2.ZERO, null, CombatLayers.Team.PLAYER, kind))


## Crosses the first line and plays the possession to its end: the boss is in phase 2 (its cycle starts by itself).
func _to_phase_two(level: LevelBase) -> void:
	_hurt_to(level, int(floor(_threshold_hp(level.boss, 0))))
	await _physics(3)
	await _skip_possession(level.get_node("PossessionDirector") as PossessionDirector)


func _to_phase_three(level: LevelBase) -> void:
	_hurt_to(level, int(floor(_threshold_hp(level.boss, 1))))
	await _physics(3)
	await _skip_possession(level.get_node("PossessionDirector") as PossessionDirector)


## Waits (real game time) until the condition holds; true if it did within `seconds`.
func _until(condition: Callable, seconds: float) -> bool:
	var waited: float = 0.0
	while waited < seconds:
		if condition.call():
			return true
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	return condition.call()


func _game_time() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


func _projectiles(level: Node) -> int:
	var count: int = 0
	for node in level.find_children("*", "Projectile", true, false):
		if not (node as Node).is_queued_for_deletion():
			count += 1
	return count


func _hitboxes_off(boss: BossBase) -> bool:
	for child in boss.attack_pivot.get_children():
		if child is Hitbox and (child as Hitbox).is_active:
			return false
	return true


func _channel(value: float) -> float:
	return value / 12.92 if value <= 0.03928 else pow((value + 0.055) / 1.055, 2.4)


func _luminance(color: Color) -> float:
	return 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b)


func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


# ---------------------------------------------------------------------------------------------
# Guards and what is gone
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
	_check("levels 1 and 2 are byte-identical to before", FileAccess.get_md5("res://frontend/levels/level_1.tscn") == LEVEL_ONE_MD5 and FileAccess.get_md5("res://frontend/levels/level_2.tscn") == LEVEL_TWO_MD5)


func _test_removed() -> void:
	var classes: PackedStringArray = PackedStringArray()
	for entry in ProjectSettings.get_global_class_list():
		classes.append(String(entry["class"]))
	var gone: bool = true
	for name in ["BossHover", "BeamSweepPattern", "LightningColumnsPattern", "StormFx"]:
		gone = gone and not classes.has(name)
	for path in ["res://backend/bosses/boss_hover.gd", "res://backend/bosses/patterns/beam_sweep_pattern.gd", "res://backend/bosses/patterns/lightning_columns_pattern.gd", "res://frontend/fx/storm_fx.gd", "res://backend/arena/arena_wind_vent_config.tres"]:
		gone = gone and not FileAccess.file_exists(path)
	_check("removed: the floating eye (hover), the sweeping beam, the lightning columns pattern and the old storm fx are gone (classes and files)", gone)
	var level: LevelBase = _level_three()
	add_child(level)
	await _frames(4)
	var vents: Array[Node] = level.find_children("Vent*", "", true, false)
	var plates: Array[Node] = level.find_children("*", "ElectricPlate", true, false)
	var bound: bool = false
	_check("removed: level 3 has no wind vents at all (Phase 15o) (%d) and the electric plate (%d) is untouched" % [vents.size(), plates.size()], vents.is_empty() and plates.size() == 1 and not bound and level.find_children("ArenaVent*", "", true, false).is_empty())
	_check("removed: the boss has no hover node, no beam and no column patterns", level.boss.get_node_or_null(^"Hover") == null and _pattern(level.boss, &"beam") == null and _pattern(level.boss, &"columns") == null and _pattern(level.boss, &"beam_storm") == null and _pattern(level.boss, &"columns_storm") == null)
	_check("removed: the summoner stage, the platforms' scene and the duckling scene are wired in the level", _stage(level) != null and _stage(level).platform_scene != null and _stage(level).duckling_scene != null)
	level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# Numbers and calculation
# ---------------------------------------------------------------------------------------------

func _test_config_and_numbers() -> void:
	_check("config: the vulnerable window is %.1f s, inside its allowed range (%.0f to %.0f s, and 4 to 8 s)" % [config.window_seconds, config.window_min, config.window_max], config.window_seconds >= config.window_min and config.window_seconds <= config.window_max and config.window_seconds >= 4.0 and config.window_seconds <= 8.0)
	_check("config: batches of %d every %.1f s until %d are summoned, at most %d alive" % [config.batch_size, config.batch_interval, config.wave_size, config.max_alive], config.batch_size == 2 and is_equal_approx(config.batch_interval, 2.5) and config.wave_size == 6 and config.max_alive == 6)
	_check("config: the collapse numbers (tremble %.1f s, barrage %.1f s, lane telegraph %.1f s, shimmer %.1f s)" % [config.tremble_time, config.barrage_time, config.lane_telegraph, config.shimmer_time], is_equal_approx(config.tremble_time, 1.5) and is_equal_approx(config.barrage_time, 5.0) and is_equal_approx(config.lane_telegraph, 0.8) and is_equal_approx(config.shimmer_time, 1.0))
	_check("config: the eye's bolts are announced %.1f s (at least 1.0) and strike %.1f s; the duck of phase 3 is faster (cooldown factor %.2f)" % [config.bolt_telegraph, config.bolt_active, boss_stats.phase_3_cooldown_factor], config.bolt_telegraph >= 1.0 and is_equal_approx(config.bolt_active, 0.4) and is_equal_approx(boss_stats.phase_3_cooldown_factor, 0.75))
	var duckling: Duckling = (load("res://backend/enemies/duckling.tscn") as PackedScene).instantiate() as Duckling
	var duck_stats: EnemyStats = duckling.stats
	_check("duckling: %d HP, %.0f px/s, a %.2f s telegraph for %d heart, %d soul (from its resources)" % [duck_stats.max_health, duck_stats.move_speed, duck_stats.attack_startup_time, duck_stats.attack_damage, config.duckling_soul_gain], duck_stats.max_health == 1 and absf(duck_stats.move_speed - 120.0) < 1.0 and is_equal_approx(duck_stats.attack_startup_time, 0.5) and duck_stats.attack_damage == 1 and config.duckling_soul_gain == 5 and duck_stats.contact_damage == 0)
	duckling.free()


func _test_platform_math() -> void:
	var floor_top: float = 600.0
	var ceiling_gap: float = 440.0
	var rise: float = StageMath.jump_rise(player_stats)
	var double: float = StageMath.double_rise(player_stats)
	_check("platforms: the real jump rises %.1f px and the double jump %.1f px (the numbers of the brief: 106.8 and 183.9)" % [rise, double], absf(rise - 106.8) < 0.5 and absf(double - 183.9) < 0.5)
	var worst_step: float = 0.0
	var steps_ok: bool = true
	var previous_top: float = 0.0
	var spread_ok: bool = true
	var reach_ok: bool = true
	var margin_reach: float = INF
	for i in config.platform_heights.size():
		var step: float = config.platform_heights[i] - previous_top
		worst_step = maxf(worst_step, step)
		steps_ok = steps_ok and step <= rise - 15.0
		previous_top = config.platform_heights[i]
		if i > 0:
			spread_ok = spread_ok and absf(config.platform_offsets[i] - config.platform_offsets[i - 1]) >= 150.0
			var a: Vector2 = StageMath.platform_span(config, 0.0, i - 1)
			var b: Vector2 = StageMath.platform_span(config, 0.0, i)
			var gap: float = maxf(maxf(b.x - a.y, a.x - b.y), 0.0)
			var air: float = StageMath.air_time_to(player_stats, step)
			var run_px: float = StageMath.run(player_stats, air)
			reach_ok = reach_ok and gap <= run_px
			margin_reach = minf(margin_reach, run_px - gap)
	_check("platforms: every step is a SINGLE jump (the biggest is %.0f px against a rise of %.1f px, margin >= 15) starting from the floor" % [worst_step, rise], steps_ok and worst_step > 0.0)
	_check("platforms: neighbours are at least 150 px apart and the next one is reachable horizontally during the jump (worst margin %.0f px)" % margin_reach, spread_ok and reach_ok)
	var top_platform: float = config.platform_heights[config.platform_heights.size() - 1]
	var head_clear: float = ceiling_gap - (top_platform + StageMath.BODY_HEIGHT + rise)
	_check("platforms: a player jumping from the highest platform keeps %.0f px under the arena ceiling (440 px above the floor)" % head_clear, head_clear >= 20.0)
	_check("platforms: no platform needs the double jump (the highest sits %.0f px up, under what two jumps reach in a chain)" % top_platform, top_platform - (config.platform_heights.size() - 1) * worst_step <= rise)
	var boss_top: float = config.perch_height + 88.0
	_check("perch: a boss standing on it (88 px tall) tops out %.0f px under the ceiling and the perch is above the highest platform by %.0f px" % [ceiling_gap - boss_top, config.perch_height - top_platform], ceiling_gap - boss_top >= 20.0 and config.perch_height - top_platform >= 40.0)
	var wide_enough: bool = true
	for i in config.platform_heights.size():
		var span: Vector2 = StageMath.platform_span(config, 0.0, i)
		wide_enough = wide_enough and span.y - span.x >= 100.0 and absf(span.x) < 515.0 and absf(span.y) < 515.0
	_check("platforms: all four stand inside the arena (half width 515 px) and are wide enough to land on", wide_enough)


func _test_barrage_math() -> void:
	var speed: float = config.barrage_projectile_stats.speed
	var left: float = 5645.0
	var right: float = 6675.0
	var center: float = (left + right) * 0.5
	var floor_top: float = 600.0
	var worst_margin: float = INF
	var worst_text: String = ""
	var plans_ok: bool = true
	var neighbours_ok: bool = true
	var most_dangerous: int = 0
	var rng := RandomNumberGenerator.new()
	for seed_value in 600:
		rng.seed = seed_value + 1
		var plan: Array[Dictionary] = StageMath.barrage_plan(config, rng, config.platform_heights.size())
		plans_ok = plans_ok and plan.size() == config.lane_events
		var crossing: float = (right - left) / speed
		for i in plan.size():
			var event: Dictionary = plan[i]
			var lane: int = int(event["lane"])
			if i > 0:
				var before: int = int(plan[i - 1]["lane"])
				plans_ok = plans_ok and before != lane and absi(before - lane) >= 2 and int(plan[i - 1]["side"]) != int(event["side"])
			# Dangerous lanes at the moment this lane's projectile arrives: this one and any whose window overlaps.
			var arrive: float = float(event["start"]) + config.lane_telegraph
			var dangerous: Array[int] = [lane]
			for other in plan.size():
				if other != i and float(plan[other]["start"]) + config.lane_telegraph <= arrive + crossing and float(plan[other]["start"]) + config.lane_telegraph + crossing >= arrive:
					dangerous.append(int(plan[other]["lane"]))
			most_dangerous = maxi(most_dangerous, dangerous.size())
			plans_ok = plans_ok and dangerous.size() < config.platform_heights.size()
			# A neighbour of the dangerous platform is safe, and the worst case to reach it leaves the margin.
			var found_safe: bool = false
			for other_lane: int in [lane - 1, lane + 1]:
				if other_lane < 0 or other_lane >= config.platform_heights.size() or dangerous.has(other_lane):
					continue
				found_safe = true
				var travel: float = StageMath.neighbour_time(player_stats, config, center, floor_top, lane, other_lane)
				var margin: float = StageMath.arrival_time(config, speed, left, right, center, lane, int(event["side"])) - travel
				if margin < worst_margin:
					worst_margin = margin
					worst_text = "lane %d to %d, %.2f s to move, %.2f s before it arrives" % [lane, other_lane, travel, margin + travel]
				break
			neighbours_ok = neighbours_ok and found_safe
	print("MEASURE|barrage worst case over 600 plans: %s, margin %.2f s (needs %.1f), at most %d lanes dangerous at once of %d" % [worst_text, worst_margin, config.safe_margin, most_dangerous, config.platform_heights.size()])
	_check("barrage: every plan has %d events, never the same lane twice in a row nor neighbours, alternating sides, never all lanes dangerous (at most %d of %d during one crossing)" % [config.lane_events, most_dangerous, config.platform_heights.size()], plans_ok and most_dangerous <= 3)
	_check("barrage: a neighbouring platform is ALWAYS safe, and the worst-case time to reach it from anywhere on the dangerous one leaves a margin of %.2f s (at least %.1f s)" % [worst_margin, config.safe_margin], neighbours_ok and worst_margin >= config.safe_margin)
	_check("barrage: the lane marker shows %.1f s before the projectile and the dash is the invulnerable way through (dash %.2f s)" % [config.lane_telegraph, player_stats.dash_duration], config.lane_telegraph >= 0.8 and player_stats.dash_duration > 0.1)


func _test_bolt_math() -> void:
	var left: float = 5645.0
	var right: float = 6675.0
	var floor_top: float = 600.0
	var eye := Vector2((left + right) * 0.5, floor_top - config.eye_height)
	var worst_margin: float = INF
	var safe_ok: bool = true
	var counts_ok: bool = true
	var checked: int = 0
	var rolls: Array[float] = [0.0, 0.3, 0.7, 0.99]
	var x: float = left + 20.0
	while x < right - 20.0:
		for roll_a in rolls:
			for roll_b in rolls:
				var plan: Dictionary = StageMath.bolt_plan(config, left, right, eye, floor_top, x, roll_a, roll_b)
				var lane: Vector2 = plan["lane"]
				checked += 1
				for extent: Vector2 in plan["extents"]:
					safe_ok = safe_ok and (extent.y <= lane.x or extent.x >= lane.y)
				counts_ok = counts_ok and (plan["verticals"] as PackedFloat32Array).size() + (plan["radials"] as PackedFloat32Array).size() >= 2
				# The player walks to the nearest edge of the lane (a standing duck is 28 px wide, so half of it must fit inside).
				var distance: float = 0.0
				if x < lane.x + 14.0:
					distance = lane.x + 14.0 - x
				elif x > lane.y - 14.0:
					distance = x - (lane.y - 14.0)
				var margin: float = config.bolt_telegraph - _walk_time(distance)
				worst_margin = minf(worst_margin, margin)
		x += 10.0
	print("MEASURE|red bolts worst case over %d plans: margin %.2f s to reach the safe lane (needs 0.3), lane width %.0f px" % [checked, worst_margin, config.min_lane_width])
	_check("bolts: %d plans swept over every player position: no vertical column or diagonal bolt touches the safe lane (a lane of %.0f px at most %.0f px from the player) and every volley has at least 2 bolts" % [checked, config.min_lane_width, config.max_lane_offset], safe_ok and counts_ok)
	_check("bolts: the worst-case time to walk into the safe lane leaves %.2f s of the %.1f s telegraph (at least 0.3 s)" % [worst_margin, config.bolt_telegraph], worst_margin >= 0.3)


func _test_balance_numbers() -> void:
	var hp: int = boss_stats.max_health
	var line_one: float = floor(float(hp) * boss_stats.get_phase_thresholds()[0])
	var line_two: float = floor(float(hp) * boss_stats.get_phase_thresholds()[1])
	var phase_two: float = line_one - line_two
	var light_dps: float = float(player_stats.attack_damage) / 0.45
	var heavy_cycle: float = player_stats.heavy_startup_time + player_stats.heavy_active_time + player_stats.heavy_recovery_time + player_stats.heavy_cooldown
	var heavy_dps: float = float(player_stats.heavy_damage) / heavy_cycle
	var approach: float = 0.8
	var usable: float = config.window_seconds - approach
	var light_per_window: float = light_dps * usable
	var heavy_per_window: float = heavy_dps * usable
	var cycles_light: int = int(ceil(phase_two / light_per_window))
	var cycles_heavy: int = int(ceil(phase_two / heavy_per_window))
	_check("cycles: phase 2 holds %.0f HP; with the sword alone one %.1f s window deals %.1f (light) to %.1f (heavy) damage, so it takes %d to %d cycles (2 to 3 wanted)" % [phase_two, config.window_seconds, light_per_window, heavy_per_window, cycles_heavy, cycles_light], cycles_light >= 2 and cycles_light <= 3 and cycles_heavy >= 2 and cycles_heavy <= 3)
	var cycle_length: float = config.first_batch_delay + float(config.wave_size / config.batch_size - 1) * config.batch_interval + 0.5 + config.tremble_time + config.leap_up_time + config.crumble_time + config.barrage_time + config.shimmer_time + config.land_time + config.window_seconds + config.perch_leap_time
	var wave_config := load("res://backend/player/default_sword_wave_config.tres") as SwordWaveConfig
	var phase_one: float = float(hp) - line_one
	var rows: PackedStringArray = PackedStringArray()
	# Phase 15o: no shell, every hit lands: the best sustained rate is the better of the light and heavy slash.
	var phase_one_time: float = phase_one / maxf(light_dps, heavy_dps)
	var phase_two_time: float = float(cycles_heavy - 1) * cycle_length + (cycle_length - config.perch_leap_time - config.window_seconds) + approach + (phase_two - heavy_per_window * float(cycles_heavy - 1)) / heavy_dps
	rows.append("sword only: phase 1 %.0f HP in about %.0f s (no shell: every hit lands), phase 2 about %.0f s (%d cycles of about %.0f s, the last cut short), phase 3 %.0f HP in %.0f s" % [phase_one, phase_one_time, phase_two_time, cycles_heavy, cycle_length, line_two, line_two / light_dps])
	for tier in 3:
		var wave: SwordWaveTier = wave_config.get_tier(tier)
		var cooldown: float = maxf(wave.cooldown, wave_config.startup_time + wave_config.recovery_time)
		var wave_dps: float = float(wave.damage) / cooldown
		var per_window: float = wave_dps * usable
		var wave_cycles: int = int(ceil(phase_two / per_window))
		rows.append("wave tier %d (%d damage every %.2f s): phase 2 takes %d cycle(s), phase 3 in %.0f s" % [tier, wave.damage, cooldown, wave_cycles, line_two / wave_dps])
	print("MEASURE|boss 3 ideal times|%s|one cycle of phase 2 lasts about %.1f s with perfect play|window %.1f s, light %.2f dps, heavy %.2f dps" % [" | ".join(rows), cycle_length, config.window_seconds, light_dps, heavy_dps])
	_check("balance: one whole cycle lasts about %.0f s with perfect play (no dead time added by the kills)" % cycle_length, cycle_length > 15.0 and cycle_length < 40.0)


func _test_contrast() -> void:
	var presentation := load("res://frontend/presentation/default_profile_presentation.tres") as ProfilePresentation
	var possession := PossessionConfig.get_default()
	var storm := load(BIOME_DIR + "storm_biome.tres") as Biome
	var items: Array = [
		["bolt telegraph", BossStageFx.BOLT_TELEGRAPH, BossStageFx.BOLT_OUTLINE],
		["active bolt core", BossStageFx.BOLT_CORE, BossStageFx.BOLT_OUTLINE],
		["lane marker", BossStageFx.LANE, BossStageFx.INK],
		["eye", BossStageFx.EYE_WHITE, BossStageFx.BOLT_OUTLINE],
	]
	var worst: Dictionary = {}
	var possessed_worst: float = 99.0
	for item in items:
		worst[item[0]] = 99.0
	var scenery: Array[Color] = [storm.sky_top, storm.sky_bottom, storm.haze, storm.far_color, storm.mid_color, storm.near_color]
	var ground: Array[Color] = [storm.grass, storm.grass_dark, storm.soil, storm.soil_dark, storm.rock, storm.rock_dark]
	for profile in ["neutral", "compassionate", "corrupt"]:
		var tint: Color = presentation.get_look(profile).background_tint
		for amount in [0.0, possession.persistent_sky, 1.0]:
			var red: Color = Color.WHITE.lerp(possession.sky_tint, amount)
			for color in scenery:
				var shown := Color(clampf(color.r * tint.r * red.r, 0.0, 1.0), clampf(color.g * tint.g * red.g, 0.0, 1.0), clampf(color.b * tint.b * red.b, 0.0, 1.0))
				for item in items:
					var value: float = maxf(_contrast(item[1], shown), _contrast(item[2], shown))
					worst[item[0]] = minf(float(worst[item[0]]), value)
					if amount > 0.0:
						possessed_worst = minf(possessed_worst, value)
	for color in ground:
		for item in items:
			worst[item[0]] = minf(float(worst[item[0]]), maxf(_contrast(item[1], color), _contrast(item[2], color)))
	var summary: PackedStringArray = PackedStringArray()
	var all_ok: bool = true
	for item in items:
		summary.append("%s %.2f" % [item[0], worst[item[0]]])
		all_ok = all_ok and float(worst[item[0]]) >= MIN_CONTRAST
	print("MEASURE|boss 3 stage contrast over the storm biome and the three profiles, also with the possession red|%s|worst with the possession red %.2f" % [", ".join(summary), possessed_worst])
	_check("contrast: the eye, its bolts (a white-hot core in a dark outline) and the lane markers read over the storm biome and the persistent possession red (>= %.1f): %s" % [MIN_CONTRAST, ", ".join(summary)], all_ok and possessed_worst >= MIN_CONTRAST)
	_check("contrast: the red palette is its own: the core is white-hot and the wave's cyan-white is not used", BossStageFx.BOLT_RED.r > 0.8 and BossStageFx.BOLT_RED.b < 0.3 and BossStageFx.BOLT_CORE.r > 0.9)


# ---------------------------------------------------------------------------------------------
# Phase 1: the duck alone
# ---------------------------------------------------------------------------------------------

func _test_phase_one() -> void:
	_clean_state()
	var level: LevelBase = await _fight()
	var boss: BossBase = level.boss
	var stage: BossStage = _stage(level)
	var guard := boss.get_node("Shield") as BossShield
	_check("phase 1: the duck fights alone: no platform, no duckling, no vent, no eye, the floor is whole and there is NO shell (Phase 15o)", stage.platforms_state == &"down" and stage.alive_count() == 0 and not stage.eye.is_active() and stage.floor_state == &"solid" and not guard.shield_up and boss.current_phase == 1 and not "state" in guard)
	var before: int = boss.health.current_health
	var light_lands: bool = _hit(boss, &"light", 1)
	var wave_lands: bool = _hit(boss, &"wave", 1)
	var heavy_lands: bool = _hit(boss, &"heavy", 3)
	var dash_lands: bool = _hit(boss, &"dash_slash", 2)
	_check("phase 1: with no shell EVERY attack lands at full damage (light 1, wave 1, heavy 3, dash slash 2: %d to %d, expected -7)" % [before, boss.health.current_health], light_lands and wave_lands and heavy_lands and dash_lands and boss.health.current_health == before - 7 and boss.hurtbox.hit_filter == guard)
	# The patterns the duck uses in phase 1, and the longest it ever stands without attacking, in real game time.
	boss.health.reset()
	guard._reset()
	var allowed: Array[StringName] = [&"swipe", &"charge", &"volley", &"volley_fallback", &"charge_short", &"stomp"]
	var seen: Dictionary = {}
	var foreign: bool = false
	var worst_idle: float = 0.0
	var idle_run: float = 0.0
	boss.pattern_started.connect(func(id: StringName) -> void:
		seen[id] = true
		if not allowed.has(id):
			foreign = true)
	var elapsed: float = 0.0
	level.player.global_position = Vector2(level.encounter.global_position.x + 150.0, level.encounter.global_position.y)
	while elapsed < 24.0:
		await get_tree().physics_frame
		var delta: float = get_physics_process_delta_time()
		elapsed += delta
		if boss.state == BossBase.State.IDLE:
			idle_run += delta
			worst_idle = maxf(worst_idle, idle_run)
		else:
			idle_run = 0.0
	print("MEASURE|phase 1 never idle: worst idle %.2f s over %.0f s of real game time, patterns seen: %s" % [worst_idle, elapsed, str(seen.keys())])
	_check("phase 1: only the duck's patterns run (swipe, charge, volley and the fallbacks), %d different ones in 24 s and nothing of the old eye" % seen.size(), not foreign and seen.size() >= 2)
	_check("phase 1: never idle for more than %.1f s (worst %.2f s)" % [boss_stats.max_idle_time, worst_idle], worst_idle <= boss_stats.max_idle_time + 0.1)
	level.free()
	await _frames(2)


func _test_thresholds_and_possession() -> void:
	_clean_state()
	var level: LevelBase = await _fight()
	var boss: BossBase = level.boss
	var director := level.get_node("PossessionDirector") as PossessionDirector
	var order: Array[int] = []
	boss.phase_transition_started.connect(func(next: int) -> void: order.append(next))
	_hurt_to(level, int(floor(_threshold_hp(boss, 0))) + 1)
	await _physics(3)
	_check("thresholds: just above the first line nothing happens", order.is_empty() and boss.current_phase == 1)
	_hurt_to(level, int(floor(_threshold_hp(boss, 0))))
	await _physics(3)
	_check("possession: crossing the first line starts the possession sequence once (phase 2 next)", order == [2] and director.active and boss.state == BossBase.State.PHASE_TRANSITION)
	await _skip_possession(director)
	var cycle_started: bool = await _until(func() -> bool: return boss.current_pattern is SummonerCyclePattern, 4.0)
	_check("thresholds: the boss is in phase 2 and its summoner cycle is running", boss.current_phase == 2 and cycle_started)
	_hurt_to(level, int(floor(_threshold_hp(boss, 1))))
	await _physics(3)
	_check("possession: crossing the second line starts the second sequence (phase 3 next)", order == [2, 3] and director.active)
	await _skip_possession(director)
	_check("thresholds: the boss is in phase 3, each possession played exactly once, in order (%s)" % str(director.phases_shown), boss.current_phase == 3 and director.sequences_started == 2 and director.phases_shown == [2, 3])
	_damage(level, boss.health.current_health)
	await _physics(4)
	_check("thresholds: the hit that kills the boss skips any transition (dead, no third sequence)", boss.state == BossBase.State.DEAD and director.sequences_started == 2)
	level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# Phase 2: the summoner stage, one full cycle with real time
# ---------------------------------------------------------------------------------------------

func _test_cycle() -> void:
	_clean_state()
	var level: LevelBase = await _fight()
	var boss: BossBase = level.boss
	var stage: BossStage = _stage(level)
	var guard := boss.get_node("Shield") as BossShield
	var cycle := _pattern(boss, &"summon_cycle") as SummonerCyclePattern
	var steps: Array[Dictionary] = []
	cycle.step_changed.connect(func(step: StringName) -> void: steps.append({"step": step, "t": _game_time()}))
	var floors: Array[StringName] = []
	stage.floor_changed.connect(func(state: StringName) -> void: floors.append(state))
	var summon_times: Array[float] = []
	var summon_counts: Array[int] = []
	var seen_summoned: Array[int] = [0]
	await _to_phase_two(level)
	var max_alive: int = 0
	var shield_checks: Array[String] = []
	var killing: bool = false
	var kill_clock: float = 0.0
	var void_checked: bool = false
	var window_checked: bool = false
	var worst_idle: float = 0.0
	var idle_run: float = 0.0
	var platforms_ok: bool = true
	var perch_solid_for_player: bool = true
	var cycles_seen_two: bool = false
	var total: float = 0.0
	var hearts_before: int = 0
	var rescue_ok: bool = false
	var checkpoint_before: String = GameState.checkpoint
	while total < 80.0 and not cycles_seen_two:
		await get_tree().physics_frame
		var delta: float = get_physics_process_delta_time()
		total += delta
		if boss.state == BossBase.State.IDLE:
			idle_run += delta
			worst_idle = maxf(worst_idle, idle_run)
		else:
			idle_run = 0.0
		if stage.summoned != seen_summoned[0] and stage.summoned > 0:
			seen_summoned[0] = stage.summoned
			summon_times.append(_game_time())
			summon_counts.append(stage.summoned)
		max_alive = maxi(max_alive, stage.alive_count())
		var current: StringName = cycle.step_name() if boss.current_pattern == cycle else &""
		if stage.platforms_state == &"up" and platforms_ok:
			for i in stage.platforms.size():
				var top: float = stage.platforms[i].position.y - config.platform_thickness * 0.5
				platforms_ok = platforms_ok and absf(top - (stage.floor_top - config.platform_heights[i])) < 0.5
			perch_solid_for_player = perch_solid_for_player and (level.player.collision_mask & stage.perch.collision_layer) == 0 and (boss.collision_mask & stage.perch.collision_layer) != 0
		# The player kills the ducklings one by one once all six are out (to see six alive at once, then the shield go).
		if stage.summoned >= config.wave_size and stage.alive_count() > 0 and not killing:
			killing = true
			kill_clock = 0.0
			shield_checks.append("blocks light %s, heavy %s, dash slash %s, wave %s with %d alive" % [str(not _hit(boss, &"light")), str(not _hit(boss, &"heavy", 3)), str(not _hit(boss, &"dash_slash", 2)), str(not _hit(boss, &"wave")), stage.alive_count()])
		if killing:
			kill_clock += delta
			if kill_clock > 0.4 and stage.alive_count() > 0:
				kill_clock = 0.0
				for duckling in stage.ducklings:
					if is_instance_valid(duckling) and duckling.state != EnemyBase.State.DEAD:
						var alive_before: int = stage.alive_count()
						duckling.hurtbox.receive_hit(DamageInfo.create(1, Vector2.ZERO, level.player, CombatLayers.Team.PLAYER, &"light"))
						await get_tree().physics_frame
						shield_checks.append("%d->%d alive, shield %s" % [alive_before, stage.alive_count(), str(stage.shield_is_up())])
						break
		# The void: while the floor is gone a player who falls loses 1 heart and comes back on the lowest platform.
		if current == &"barrage" and not void_checked and stage.floor_state == &"gone":
			void_checked = true
			level.player.story_invulnerable = false
			level.player.health.reset()
			hearts_before = level.player.health.current_health
			level.player.global_position = Vector2(stage.arena_center, stage.floor_top - 12.0)
			level.player.velocity = Vector2.ZERO
			var back: bool = await _until(func() -> bool: return level.player.global_position.y < stage.floor_top - 60.0, 1.5)
			var span: Vector2 = StageMath.platform_span(config, stage.arena_center, 0)
			rescue_ok = back and level.player.global_position.x >= span.x - 10.0 and level.player.global_position.x <= span.y + 10.0 and not level.player.is_dead and level.player.health.current_health == hearts_before - 1 and level.player.health.is_invulnerable() and GameState.checkpoint == checkpoint_before and stage.falls == 1
			print("MEASURE|void test: hearts %d -> %d, player at %s, back %s, invulnerable %s, falls %d" % [hearts_before, level.player.health.current_health, str(level.player.global_position), str(back), str(level.player.health.is_invulnerable()), stage.falls])
			level.player.story_invulnerable = true
		# The vulnerable window: no shield, no shell, every attack at full damage, the boss kneels and pants.
		if current == &"window" and not window_checked and boss.is_on_floor():
			window_checked = true
			var health_before: int = boss.health.current_health
			var light: bool = _hit(boss, &"light", 1)
			var heavy: bool = _hit(boss, &"heavy", 3)
			var wave: bool = _hit(boss, &"wave", 1)
			var dash_slash: bool = _hit(boss, &"dash_slash", 2)
			shield_checks.append("window: light %s heavy %s wave %s dash slash %s, health %d -> %d (expected -7), exhausted %s, shield %s" % [str(light), str(heavy), str(wave), str(dash_slash), health_before, boss.health.current_health, str(boss.exhausted), str(stage.shield_is_up())])
			_check("window: every attack lands at FULL damage (7 of 7), the boss is exhausted and has no shield", light and heavy and wave and dash_slash and boss.health.current_health == health_before - 7 and boss.exhausted and not stage.shield_is_up())
		if cycle.cycles_completed >= 1 and current == &"summon":
			cycles_seen_two = true
	var order: Array[StringName] = []
	for entry in steps:
		order.append(entry["step"])
	var expected: Array[StringName] = [&"rise", &"to_perch", &"summon", &"wait_kills", &"tremble", &"leap_up", &"collapse", &"barrage", &"shimmer", &"land", &"window", &"back_to_perch", &"done", &"summon"]
	_check("cycle: the whole sequence runs in order and then starts again (%s)" % str(order), order.size() >= expected.size() and order.slice(0, expected.size()) == expected)
	var at: Dictionary = {}
	for entry in steps:
		if not at.has(entry["step"]):
			at[entry["step"]] = float(entry["t"])
	var rise_time: float = float(at[&"to_perch"]) - float(at[&"rise"])
	_check("platforms: they rise in %.2f s (about 1.2) to the exact heights %s above the floor, and the perch is solid for the boss and NOT for the player" % [rise_time, str(config.platform_heights)], rise_time >= 1.1 and rise_time <= 1.4 and platforms_ok and perch_solid_for_player)
	print("MEASURE|summon times %s counts %s" % [str(summon_times), str(summon_counts)])
	var cadence_ok: bool = summon_counts == [2, 4, 6] and summon_times.size() == 3
	if cadence_ok:
		cadence_ok = absf(summon_times[0] - (float(at[&"summon"]) + config.first_batch_delay)) < 0.15 and absf(summon_times[1] - summon_times[0] - config.batch_interval) < 0.15 and absf(summon_times[2] - summon_times[1] - config.batch_interval) < 0.15
	_check("summoning: batches of 2 at the exported cadence (%.1f s), 6 per wave, never more than %d alive (the most seen: %d)" % [config.batch_interval, config.max_alive, max_alive], cadence_ok and max_alive == 6)
	_check("shield: it blocks every kind of hit while a duckling lives and drops with the last one (%s)" % str(shield_checks), shield_checks.size() >= 8 and (shield_checks[0] as String).begins_with("blocks light true, heavy true, dash slash true, wave true with 6") and (shield_checks[shield_checks.size() - 2] as String).contains("1->0 alive, shield false"))
	var tremble_span: float = float(at[&"leap_up"]) - float(at[&"tremble"])
	var barrage_span: float = float(at[&"shimmer"]) - float(at[&"barrage"])
	var shimmer_span: float = float(at[&"land"]) - float(at[&"shimmer"])
	var window_span: float = float(at[&"back_to_perch"]) - float(at[&"window"])
	_check("collapse: the floor trembles %.2f s (1.5), the barrage lasts %.2f s (5.0), the outline shimmers %.2f s (1.0) before it returns, the vulnerable window lasts %.2f s (%.1f)" % [tremble_span, barrage_span, shimmer_span, window_span, config.window_seconds],
		absf(tremble_span - config.tremble_time) < 0.15 and barrage_span >= config.barrage_time - 0.05 and barrage_span <= config.barrage_time + 0.4 and absf(shimmer_span - config.shimmer_time) < 0.15 and absf(window_span - config.window_seconds) < 0.2)
	_check("collapse: the floor goes trembling, crumbling, gone, shimmering, back (%s) and the platforms remain risen the whole time" % str(floors), floors.slice(0, 5) == [&"trembling", &"crumbling", &"gone", &"shimmering", &"solid"] and stage.platforms_state == &"up")
	_check("void: falling costs exactly 1 heart, puts the player back on the lowest platform with invulnerability and is never a checkpoint respawn nor a softlock", rescue_ok)
	_check("cycle: the boss stands on the floor exhausted in the window and leaps back to its perch; the next wave starts (cycles completed %d)" % cycle.cycles_completed, cycle.cycles_completed >= 1 and cycles_seen_two)
	print("MEASURE|phase 2 worst idle between cycles %.2f s" % worst_idle)
	_check("never idle: between two cycles the boss waits at most %.2f s (limit %.1f s); inside the cycle it is always in a defined step" % [worst_idle, boss_stats.max_idle_time], worst_idle <= boss_stats.max_idle_time + 0.1)
	level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# Phase 3: the red eye
# ---------------------------------------------------------------------------------------------

func _test_phase_three() -> void:
	_clean_state()
	var level: LevelBase = await _fight()
	var boss: BossBase = level.boss
	var stage: BossStage = _stage(level)
	var guard := boss.get_node("Shield") as BossShield
	await _to_phase_two(level)
	await _physics(80)
	_check("phase 2 to 3: the platforms were risen before", stage.platforms_state == &"up" or stage.platforms_state == &"rising")
	await _to_phase_three(level)
	var sunk: bool = await _until(func() -> bool: return stage.platforms_state == &"down", config.sink_time + 0.6)
	var hidden: bool = true
	for plat in stage.platforms:
		hidden = hidden and not plat.visible
	_check("phase 3: the platforms and the perch sink away (animated, %.1f s) and nothing stays solid or visible; the floor is whole" % config.sink_time, sunk and hidden and not stage.perch.is_solid() and stage.floor_state == &"solid")
	var eye: StormEye = stage.eye
	var appeared: bool = await _until(func() -> bool: return eye.is_active() and eye.appear_amount() >= 1.0, config.eye_appear_time + 0.8)
	var eye_variant: Variant = eye
	var no_body: bool = eye.find_children("*", "Hurtbox", true, false).is_empty() and not eye_variant is CollisionObject2D
	_check("phase 3: the red eye is in the sky (appeared %s) and invulnerable: it has no hurtbox, every hit goes through the duck" % str(appeared), appeared and no_body)
	var hit_applied: bool = _hit(boss, &"light", 1)
	_check("phase 3: the duck has no shell and no shield: a light hit lands (%s) and the cooldown factor is %.2f" % [str(hit_applied), boss.cooldown_factor()], hit_applied and not guard.shield_up and is_equal_approx(boss.cooldown_factor(), 0.75) and boss.current_phase == 3)
	var readable: bool = true
	for pattern in boss.patterns:
		if pattern.fallback_priority == 0 and boss.current_phase >= pattern.min_phase and boss.current_phase <= pattern.max_phase and not pattern.excluded_phases.has(3) and pattern.pattern_id != &"summon_cycle":
			var effective: float = pattern.telegraph_time / (boss.speed_multiplier if pattern.scale_telegraph_with_speed else 1.0)
			readable = readable and effective >= pattern.telegraph_time - 0.001
	_check("phase 3: the duck's telegraphs never shrink below their readable minimum (speed multiplier %.2f)" % boss.speed_multiplier, readable)
	# Volleys and real time: announce, strike and rest timings, hitboxes only while striking, and the plans.
	level.player.global_position = Vector2(stage.arena_center + 100.0, stage.floor_top - 30.0)
	var volleys: Array[Dictionary] = []
	var announced_at: Array[float] = [-1.0]
	var struck_at: Array[float] = [-1.0]
	var clock: Array[float] = [0.0]
	eye.volley_announced.connect(func(plan: Dictionary) -> void:
		announced_at[0] = clock[0]
		volleys.append({"plan": plan, "announced": clock[0]}))
	eye.volley_struck.connect(func(_plan: Dictionary) -> void:
		struck_at[0] = clock[0]
		volleys[volleys.size() - 1]["struck"] = clock[0])
	var rested_at: Array[float] = []
	var was_striking: bool = false
	var hitbox_outside_strike: bool = false
	var worst_idle: float = 0.0
	var idle_run: float = 0.0
	var elapsed: float = 0.0
	var fx := stage.get_node("StageFx") as BossStageFx
	var flash_max: float = 0.0
	while elapsed < 22.0:
		await get_tree().physics_frame
		var delta: float = get_physics_process_delta_time()
		elapsed += delta
		clock[0] += delta
		if boss.state == BossBase.State.IDLE:
			idle_run += delta
			worst_idle = maxf(worst_idle, idle_run)
		else:
			idle_run = 0.0
		var striking: bool = eye.is_striking()
		if was_striking and not striking and not volleys.is_empty():
			volleys[volleys.size() - 1]["ended"] = clock[0]
		was_striking = striking
		flash_max = maxf(flash_max, fx.flash_alpha)
		if not striking:
			for child in boss.attack_pivot.get_children():
				if child is Hitbox and (child as Hitbox).top_level and (child as Hitbox).is_active:
					hitbox_outside_strike = true
	var telegraph_ok: bool = volleys.size() >= 3
	var active_ok: bool = true
	var lane_ok: bool = true
	var worst_telegraph: float = INF
	var worst_active: float = 0.0
	var best_telegraph: float = 0.0
	for volley in volleys:
		if volley.has("struck"):
			var span: float = float(volley["struck"]) - float(volley["announced"])
			worst_telegraph = minf(worst_telegraph, span)
			best_telegraph = maxf(best_telegraph, span)
			telegraph_ok = telegraph_ok and span >= config.bolt_telegraph - 0.05 and span <= config.bolt_telegraph + 0.15
		if volley.has("ended"):
			var active_span: float = float(volley["ended"]) - float(volley["struck"])
			worst_active = maxf(worst_active, absf(active_span - config.bolt_active))
			active_ok = active_ok and absf(active_span - config.bolt_active) < 0.12
		var plan: Dictionary = volley["plan"]
		var lane: Vector2 = plan["lane"]
		for extent: Vector2 in plan["extents"]:
			lane_ok = lane_ok and (extent.y <= lane.x or extent.x >= lane.y)
	print("MEASURE|phase 3 over %.0f s: %d volleys, shortest telegraph %.2f s, worst idle %.2f s, the largest flash %.2f" % [elapsed, volleys.size(), worst_telegraph, worst_idle, flash_max])
	_check("phase 3: the eye's volleys are announced for about %.1f s (never less) with a safe lane in every plan, strike for %.1f s and the hitboxes are off the rest of the time (%d volleys)" % [config.bolt_telegraph, config.bolt_active, volleys.size()], telegraph_ok and active_ok and lane_ok and not hitbox_outside_strike, "telegraph %s (%.2f to %.2f s), active %s (off by %.2f s), lane %s, hitbox outside a strike %s" % [str(telegraph_ok), worst_telegraph, best_telegraph, str(active_ok), worst_active, str(lane_ok), str(hitbox_outside_strike)])
	_check("phase 3: never idle for more than %.1f s (worst %.2f s) while the eye keeps firing" % [boss_stats.max_idle_time, worst_idle], worst_idle <= boss_stats.max_idle_time + 0.1)
	_check("flash: the red flash of a strike never goes above %.1f opacity (%.2f) and fires at most 3 times a second (%d in %.0f s)" % [BossStageFx.MAX_FLASH_ALPHA, flash_max, fx.flashes_fired, elapsed], flash_max <= BossStageFx.MAX_FLASH_ALPHA + 0.001 and float(fx.flashes_fired) <= elapsed * 3.0)
	level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# A threshold crossing or the boss's death during each mechanic
# ---------------------------------------------------------------------------------------------

func _in_step(level: LevelBase, label: String) -> void:
	var boss: BossBase = level.boss
	var stage: BossStage = _stage(level)
	var cycle := _pattern(boss, &"summon_cycle") as SummonerCyclePattern
	await _until(func() -> bool: return boss.current_pattern == cycle and stage.platforms_state == &"up", 8.0)
	match label:
		"summon":
			await _until(func() -> bool: return stage.alive_count() >= 1, 6.0)
		"wait_kills":
			cycle._enter(boss, SummonerCyclePattern.Step.WAIT_KILLS)
			stage.begin_wave()
			stage.summon(2)
			await _physics(5)
		"tremble":
			cycle._enter(boss, SummonerCyclePattern.Step.TREMBLE)
			await _physics(30)
		"barrage":
			cycle._enter(boss, SummonerCyclePattern.Step.LEAP_UP)
			await _physics(40)
			cycle._enter(boss, SummonerCyclePattern.Step.COLLAPSE)
			await _physics(50)
			cycle._enter(boss, SummonerCyclePattern.Step.BARRAGE)
			await _until(func() -> bool: return stage.barrage.fired >= 2, 3.0)
		"shimmer":
			cycle._enter(boss, SummonerCyclePattern.Step.LEAP_UP)
			await _physics(40)
			cycle._enter(boss, SummonerCyclePattern.Step.COLLAPSE)
			await _physics(50)
			cycle._enter(boss, SummonerCyclePattern.Step.SHIMMER)
			await _physics(20)
		"window":
			cycle._enter(boss, SummonerCyclePattern.Step.LEAP_UP)
			await _physics(40)
			cycle._enter(boss, SummonerCyclePattern.Step.LAND)
			await _until(func() -> bool: return boss.is_on_floor(), 2.0)
			cycle._enter(boss, SummonerCyclePattern.Step.WINDOW)
			await _physics(10)


func _arena_clean(level: LevelBase, boss: BossBase, stage: BossStage) -> bool:
	return stage.alive_count() == 0 and not stage.shield_is_up() and not stage.barrage.is_busy() and _projectiles(level) == 0 and stage.floor_state == &"solid" and is_equal_approx(boss.gravity_scale, 1.0) and not boss.exhausted and _hitboxes_off(boss) and not stage.eye.is_striking()


func _test_cancel_each_mechanic() -> void:
	var summary: PackedStringArray = PackedStringArray()
	for label in ["summon", "wait_kills", "tremble", "barrage", "shimmer", "window"]:
		_clean_state()
		var level: LevelBase = await _fight()
		var boss: BossBase = level.boss
		var stage: BossStage = _stage(level)
		var director := level.get_node("PossessionDirector") as PossessionDirector
		await _to_phase_two(level)
		await _in_step(level, label)
		_hurt_to(level, int(floor(_threshold_hp(boss, 1))))
		await _physics(4)
		var cancelled: bool = boss.state == BossBase.State.PHASE_TRANSITION and _arena_clean(level, boss, stage) and boss.global_position.y > stage.floor_top - 90.0
		await _skip_possession(director)
		var sunk: bool = await _until(func() -> bool: return stage.platforms_state == &"down", config.sink_time + 0.8)
		var phase_three: bool = boss.current_phase == 3 and stage.eye.is_active() and sunk and director.phases_shown == [2, 3]
		_check("threshold during «%s»: everything is cancelled cleanly (no duckling, shield, projectile, bolt; the floor whole; the boss on the floor, released) and then phase 3 starts with the platforms gone and the eye in the sky" % label, cancelled and phase_three, "cancelled %s phase three %s" % [str(cancelled), str(phase_three)])
		summary.append(label)
		level.free()
		await _frames(2)
	_clean_state()
	var kills: int = 0
	for label in ["tremble", "barrage", "window"]:
		_clean_state()
		var level: LevelBase = await _fight()
		var boss: BossBase = level.boss
		var stage: BossStage = _stage(level)
		var director := level.get_node("PossessionDirector") as PossessionDirector
		await _to_phase_two(level)
		await _in_step(level, label)
		var sequences: int = director.sequences_started
		_damage(level, boss.health.current_health)
		await _physics(6)
		var down: bool = stage.platforms_state == &"down" or stage.platforms_state == &"sinking"
		if boss.state == BossBase.State.DEAD and director.sequences_started == sequences and _arena_clean(level, boss, stage) and down:
			kills += 1
		level.free()
		await _frames(2)
	_check("the hit that kills the boss in the middle of a mechanic skips the transition and leaves the arena clean (3 of 3, got %d)" % kills, kills == 3)


func _test_death_retry_leave_pause() -> void:
	_clean_state()
	var level: LevelBase = await _fight(true)
	var boss: BossBase = level.boss
	var stage: BossStage = _stage(level)
	var director := level.get_node("PossessionDirector") as PossessionDirector
	var player: Player = level.player
	var guard := boss.get_node("Shield") as BossShield
	player.story_invulnerable = true
	await _to_phase_two(level)
	await _in_step(level, "summon")
	# Pause: nothing moves while the game is paused and everything goes on afterwards.
	var cycle := _pattern(boss, &"summon_cycle") as SummonerCyclePattern
	var step_time: float = cycle.step_time
	get_tree().paused = true
	await get_tree().create_timer(0.6, true).timeout
	var frozen: bool = is_equal_approx(cycle.step_time, step_time)
	get_tree().paused = false
	await _physics(10)
	_check("pause: pausing in the middle of the summoning freezes the cycle (step time %.2f s) and it goes on after" % step_time, frozen and cycle.step_time > step_time)
	player.story_invulnerable = false
	player.health.kill()
	await _physics(8)
	await _frames(2)
	_check("death: the player dying in the middle of phase 2 restores the whole arena (platforms down, no duckling, no shield, floor whole, boss inactive in phase 1)", boss.state == BossBase.State.INACTIVE and boss.current_phase == 1 and stage.platforms_state == &"down" and _arena_clean(level, boss, stage) and not director.active and level.find_children("*", "Duckling", true, false).is_empty() and not stage.wave_active)
	player.respawn()
	await _physics(40)
	player.story_invulnerable = true
	player.global_position = level.encounter.global_position
	await _physics(12)
	_check("retry: the retry starts clean in phase 1 (no platform, no duckling, the possession ready to play again)", boss.current_phase == 1 and boss.state != BossBase.State.INACTIVE and stage.platforms_state == &"down" and director.phases_shown.is_empty())
	level.free()
	await _frames(2)
	_clean_state()
	var counts: Array[int] = []
	for round in 4:
		var fight: LevelBase = await _fight()
		var fight_boss: BossBase = fight.boss
		await _to_phase_two(fight)
		await _in_step(fight, ["summon", "barrage", "tremble", "window"][round])
		var leaving: PossessionDirector = fight.get_node("PossessionDirector") as PossessionDirector
		fight.remove_child(leaving)
		_check("leave %d: leaving in the middle of a mechanic gives the player back (not locked, not held)" % round, not fight.player.story_invulnerable and not fight.player.is_input_locked() and not fight_boss.is_transition_held())
		leaving.free()
		fight.free()
		await _frames(4)
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	print("MEASURE|node counts after repeated boss 3 fights|%s" % str(counts))
	_check("leave: no nodes are left behind after repeated fights (%s) and nothing is paused" % str(counts), counts[counts.size() - 1] <= counts[1] + 4 and not get_tree().paused and not PauseLock.is_locked())


## The developer tool at any point of the fight: it must leave the arena clean and the player free in every state (Phase 15p).
func _test_extra_tool_states() -> void:
	var results: PackedStringArray = PackedStringArray()
	for label in ["possession", "shield", "collapse", "barrage", "window", "phase3"]:
		_clean_state()
		var level: LevelBase = await _fight()
		var boss: BossBase = level.boss
		var stage: BossStage = _stage(level)
		var helper: Node = level.get_node_or_null(^"DeveloperShortcut")
		if helper == null:
			_check("debug helper: it exists in the level", false)
			level.free()
			continue
		match label:
			"possession":
				_hurt_to(level, int(floor(_threshold_hp(boss, 0))))
				await _physics(6)
			"shield":
				await _to_phase_two(level)
				await _in_step(level, "wait_kills")
			"collapse":
				await _to_phase_two(level)
				await _in_step(level, "tremble")
			"barrage":
				await _to_phase_two(level)
				await _in_step(level, "barrage")
			"window":
				await _to_phase_two(level)
				await _in_step(level, "window")
			"phase3":
				await _to_phase_two(level)
				await _to_phase_three(level)
				await _until(func() -> bool: return stage.eye.is_striking(), 8.0)
		helper.call(&"run")
		await _physics(20)
		var final_phase: bool = label == "phase3"
		# Phase 15p: the shortcut sends the boss to its NEXT corruption state; only in the last phase does it defeat the boss. (The old expectation, that it
		# defeated the boss in every state, was stale since Phase 15e-1.) The arena is always left clean.
		var advanced: bool = boss.state == BossBase.State.PHASE_TRANSITION or boss.current_phase >= 2 or boss.state == BossBase.State.DEAD
		var clean: bool = _arena_clean(level, boss, stage) and (stage.platforms_state == &"down" or stage.platforms_state == &"sinking")
		var dead: bool = boss.state == BossBase.State.DEAD
		var dialogue: BossDialogue = null
		for node in level.find_children("*", "BossDialogue", true, false):
			dialogue = node as BossDialogue
		var locked_by_defeat: bool = false
		if final_phase:
			# The guardian's last words (Phase 15n) hold the player, safely, until they end: that is by design, not a lock. Skipping gives everything back.
			await _physics(80)
			var still_held: bool = dead and dialogue != null and dialogue.is_speaking() and level.player.is_input_locked() and level.player.story_invulnerable
			if dialogue != null:
				dialogue.skip()
			await _physics(10)
			locked_by_defeat = still_held
		else:
			var director := level.get_node("PossessionDirector") as PossessionDirector
			if boss.state == BossBase.State.PHASE_TRANSITION:
				await _skip_possession(director)
			await _physics(80)
			# After the next state has begun the stage must be free of the previous one's mechanics (the new phase's own eye may be striking).
			clean = stage.alive_count() == 0 and not stage.shield_is_up() and not stage.barrage.is_busy() and _projectiles(level) == 0 and stage.floor_state == &"solid" and is_equal_approx(boss.gravity_scale, 1.0) and not boss.exhausted
		var free: bool = not level.player.is_input_locked() and not level.player.story_invulnerable and not get_tree().paused and not PauseLock.is_locked()
		var ok: bool = clean and advanced and free and (dead == final_phase) and (not final_phase or locked_by_defeat)
		results.append("%s %s" % [label, str(ok)])
		_check("shortcut in «%s»: %s, the arena is clean and the player ends free (the defeat dialogue held them first: %s)" % [label, "the boss falls" if final_phase else "the boss goes to its next state", str(locked_by_defeat)], ok,
			"dead %s advanced %s clean %s free %s locked_by_defeat %s state %d phase %d locked %s invulnerable %s paused %s lock %s" % [str(dead), str(advanced), str(clean), str(free), str(locked_by_defeat), boss.state if is_instance_valid(boss) else -1, boss.current_phase if is_instance_valid(boss) else -1, str(level.player.is_input_locked()), str(level.player.story_invulnerable), str(get_tree().paused), str(PauseLock.is_locked())])
		level.free()
		await _frames(3)


# ---------------------------------------------------------------------------------------------
# Reduced mode
# ---------------------------------------------------------------------------------------------

func _test_reduced_and_flash() -> void:
	_clean_state()
	var values: Dictionary = GameSettings.DEFAULTS.duplicate()
	values["corruption_effects"] = false
	GameSettings.save_settings(values)
	var level: LevelBase = await _fight()
	var boss: BossBase = level.boss
	var stage: BossStage = _stage(level)
	var fx := stage.get_node("StageFx") as BossStageFx
	await _to_phase_two(level)
	await _until(func() -> bool: return stage.platforms_state == &"rising" or stage.platforms_state == &"up", 6.0)
	var static_rise: bool = true
	if stage.platforms_state == &"rising":
		for i in stage.platforms.size():
			static_rise = static_rise and absf(stage.platforms[i].position.y - stage._platform_rest(i).y) < 0.5
	_check("reduced: the platforms appear by fading, without moving (no rise offset), the fx and the stage know it", stage.reduced and fx.reduced and static_rise)
	var cycle := _pattern(boss, &"summon_cycle") as SummonerCyclePattern
	await _until(func() -> bool: return boss.current_pattern == cycle and stage.platforms_state == &"up", 8.0)
	cycle._enter(boss, SummonerCyclePattern.Step.TREMBLE)
	await _physics(100)
	_check("reduced: the tremble shakes nothing (no camera kick: %d) and throws no dust" % fx.kicks_made, fx.kicks_made == 0)
	cycle._enter(boss, SummonerCyclePattern.Step.LEAP_UP)
	await _physics(40)
	cycle._enter(boss, SummonerCyclePattern.Step.COLLAPSE)
	await _physics(20)
	_check("reduced: the floor crumbles without flying chunks (%d)" % fx.chunks.size(), fx.chunks.is_empty())
	cycle._enter(boss, SummonerCyclePattern.Step.WINDOW)
	await _to_phase_three(level)
	await _until(func() -> bool: return stage.eye.is_striking(), 10.0)
	_check("reduced: the eye's strike fires no flash (%d flashes, alpha %.2f) and the same bolts exist" % [fx.flashes_fired, fx.flash_alpha], fx.flashes_fired == 0 and is_zero_approx(fx.flash_alpha) and stage.eye.is_striking())
	GameSettings.save_settings(GameSettings.DEFAULTS.duplicate())
	level.free()
	await _frames(2)
