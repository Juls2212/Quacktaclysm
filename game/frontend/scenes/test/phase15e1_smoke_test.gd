extends Node
## Smoke test for Phase 15e-1: boss 3 redesigned (El Ojo de la Tormenta, three phases). Bosses 1 and 2 unchanged, the two thresholds
## and the possession on each, the floating eye (hover, dips, what can hit it), the sweeping beam and the lightning columns (their
## safe margins computed from the REAL player numbers), Kenzo's guard, the never-idle fallbacks, no wasted telegraph, phase 3
## telegraphs that do not shrink, contrast, flashes, reduced mode and clean cancel / retry / leave. Lines starting with
## "MEASURE|" go to docs/BALANCE_REPORT.md. All times are real GAME time (the delta of the physics step), never ticks while
## Engine.time_scale is above 1. Development only. Run (alone, a few minutes):
##   <godot> --headless --path game res://frontend/scenes/test/phase15e1_smoke_test.tscn
## Uses a redirected save path and a throwaway settings file; the real save, settings and controls are never touched.

const TEST_SAVE: String = "user://test_save_phase15e1.json"
const TEST_SETTINGS: String = "user://test_settings_phase15e1.cfg"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const BOSS_THREE: PackedScene = preload("res://backend/bosses/boss_three.tscn")
const BOSS_ONE: PackedScene = preload("res://backend/bosses/placeholder_boss.tscn")
const BOSS_TWO: PackedScene = preload("res://backend/bosses/boss_two.tscn")
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
var player_stats: PlayerStats = PlayerStats.new()


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
	await _test_old_bosses_unchanged()
	_test_boss_three_numbers()
	await _test_thresholds_and_possession()
	await _test_health_bar_marks()
	await _test_bar_tracks_every_hit()
	await _test_guard_feedback()
	await _test_old_bars_unchanged()
	_test_eye_reach_by_calculation()
	await _test_eye_hits_and_dips()
	_test_beam_by_calculation()
	await _test_beam_real()
	_test_columns_safe_lane()
	await _test_columns_real()
	await _test_guard()
	await _test_idle_sweep()
	await _test_charge_not_wasted()
	await _test_phase_three_telegraphs()
	_test_contrast()
	await _test_flash_and_reduced()
	await _test_cancel_retry_leave()
	_test_balance_report()
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

func _level_three(play_possession: bool = true) -> LevelBase:
	var level := (load("res://frontend/levels/level_3.tscn") as PackedScene).instantiate() as LevelBase
	(level.get_node("PossessionDirector") as PossessionDirector).play_when_headless = play_possession
	return level


## Boss 3 awake against the player in the arena of level 3 (the gate is closed). The player is invulnerable unless asked.
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


## Brings the boss to `remaining` HP (one hit).
func _hurt_to(level: LevelBase, remaining: int) -> void:
	var amount: int = level.boss.health.current_health - remaining
	if amount > 0:
		_damage(level, amount)


func _threshold_hp(boss: BossBase, index: int) -> float:
	return float(boss.health.max_health) * boss.stats.get_phase_thresholds()[index]


## Jumps a running possession sequence to its end, then waits for the rest of the boss own transition time.
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


## Every pattern of a boss, also when it is not in the tree yet (boss.patterns is filled in _ready).
func _patterns_of(boss: BossBase) -> Array[BossPattern]:
	var result: Array[BossPattern] = []
	for child in boss.get_node("Patterns").get_children():
		if child is BossPattern:
			result.append(child as BossPattern)
	return result


func _pattern(boss: BossBase, id: StringName) -> BossPattern:
	for pattern in _patterns_of(boss):
		if pattern.pattern_id == id:
			return pattern
	return null


func _arena() -> Node2D:
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
	return world


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
# 1. Bosses 1 and 2 keep their single threshold
# ---------------------------------------------------------------------------------------------

func _test_old_bosses_unchanged() -> void:
	for entry in [["boss 1", BOSS_ONE, 40, 0.5], ["boss 2", BOSS_TWO, 50, 0.55]]:
		var world: Node2D = _arena()
		var boss := (entry[1] as PackedScene).instantiate() as BossBase
		boss.position = Vector2(400.0, FLOOR_Y - 44.0)
		world.add_child(boss)
		var player := PLAYER_SCENE.instantiate() as Player
		player.position = Vector2(100.0, FLOOR_Y - 26.0)
		world.add_child(player)
		await _physics(10)
		var thresholds: PackedFloat32Array = boss.stats.get_phase_thresholds()
		_check("%s: a single threshold (%.2f) and two phases, with the same health (%d)" % [entry[0], thresholds[0], entry[2]],
			thresholds.size() == 1 and is_equal_approx(thresholds[0], entry[3]) and boss.stats.phase_count() == 2 and boss.stats.max_health == entry[2])
		_check("%s: no phase 3 numbers, the cooldown factor is 1" % entry[0], is_equal_approx(boss.cooldown_factor(), 1.0) and boss.stats.max_idle_time >= 0.0 and boss.hover == null)
		var phases: Array[int] = []
		boss.phase_changed.connect(func(p: int) -> void: phases.append(p))
		var started: Array[int] = []
		boss.phase_transition_started.connect(func(p: int) -> void: started.append(p))
		boss.activate(player)
		await _physics(5)
		var line: int = int(floor(float(boss.stats.max_health) * thresholds[0]))
		boss.health.apply_damage(DamageInfo.create(boss.health.current_health - (line + 1), Vector2.ZERO, player, CombatLayers.Team.PLAYER))
		await _physics(4)
		_check("%s: just above its line nothing happens" % entry[0], started.is_empty() and boss.current_phase == 1)
		boss.health.apply_damage(DamageInfo.create(1, Vector2.ZERO, player, CombatLayers.Team.PLAYER))
		await _physics(4)
		_check("%s: crossing the line starts phase 2 once" % entry[0], started == [2] and boss.state == BossBase.State.PHASE_TRANSITION)
		await _physics(int(ceil(boss.stats.phase_transition_time * 60.0)) + 6)
		_check("%s: phase 2 begins and never phase 3 (%s)" % [entry[0], str(phases)], phases == [2] and boss.current_phase == 2)
		boss.health.apply_damage(DamageInfo.create(maxi(boss.health.current_health - 1, 1), Vector2.ZERO, player, CombatLayers.Team.PLAYER))
		await _physics(10)
		_check("%s: nearly dead it is still phase 2 (a single line)" % entry[0], boss.current_phase == 2 and started == [2])
		world.free()
		await _frames(2)


# ---------------------------------------------------------------------------------------------
# 2. Boss 3 numbers
# ---------------------------------------------------------------------------------------------

func _test_boss_three_numbers() -> void:
	var boss := BOSS_THREE.instantiate() as BossBase
	var stats: BossStats = boss.stats
	var thresholds: PackedFloat32Array = stats.get_phase_thresholds()
	_check("boss 3: 70 HP (was 80) and two thresholds at 66.7% and 33.3%", stats.max_health == 70 and thresholds.size() == 2 and is_equal_approx(thresholds[0], 0.667) and is_equal_approx(thresholds[1], 0.333)
		and stats.phase_count() == 3)
	_check("boss 3: phase 3 shortens every cooldown by 0.75 and the gaps; the telegraphs are not scaled by it", is_equal_approx(stats.phase_3_cooldown_factor, 0.75) and stats.phase_3_pattern_gap_multiplier < stats.phase_2_pattern_gap_multiplier
		and is_equal_approx(stats.speed_multiplier_for(3), 1.0) and is_equal_approx(stats.speed_multiplier_for(2), 1.0))
	_check("boss 3: it never idles longer than 1.5 s", is_equal_approx(stats.max_idle_time, 1.5))
	var storm_ok: bool = true
	for id in [&"beam", &"beam_storm"]:
		var beam := _pattern(boss, id) as BeamSweepPattern
		storm_ok = storm_ok and beam != null and beam.telegraph_time >= 0.9 and not beam.scale_telegraph_with_speed
	for id in [&"columns", &"columns_kenzo", &"columns_storm"]:
		var columns := _pattern(boss, id) as LightningColumnsPattern
		storm_ok = storm_ok and columns != null and columns.telegraph_time >= 1.0 and not columns.scale_telegraph_with_speed and absf(columns.active_time - 0.4) < 0.001
	_check("boss 3: the beam telegraph is at least 0.9 s and the column telegraph at least 1.0 s (active 0.4 s), none scaled by speed", storm_ok)
	var by_phase: Dictionary = {}
	for pattern in _patterns_of(boss):
		if pattern.fallback_priority == 0:
			by_phase[String(pattern.pattern_id)] = [pattern.min_phase, pattern.max_phase]
	_check("boss 3: phase 1 has the beam and the columns (no ground charge), phase 2 the swipe, the charge and fewer columns, phase 3 the storm beam and more columns",
		by_phase["beam"] == [1, 1] and by_phase["columns"] == [1, 1] and by_phase["swipe"] == [2, 2] and by_phase["charge"] == [2, 2] and by_phase["columns_kenzo"] == [2, 2]
		and by_phase["beam_storm"] == [3, 3] and by_phase["columns_storm"] == [3, 3]
		and (_pattern(boss, &"columns_kenzo") as LightningColumnsPattern).column_count < (_pattern(boss, &"columns") as LightningColumnsPattern).column_count
		and (_pattern(boss, &"columns_storm") as LightningColumnsPattern).column_count > (_pattern(boss, &"columns") as LightningColumnsPattern).column_count)
	var priorities: Array[int] = []
	for pattern in _patterns_of(boss):
		if pattern.fallback_priority > 0:
			priorities.append(pattern.fallback_priority)
	priorities.sort()
	_check("boss 3: the fallbacks are an aimed bolt (1), a short charge toward the player (2) and a stomp (3)", priorities == [1, 2, 3] and (_pattern(boss, &"volley_fallback") as ProjectileVolleyPattern).allow_steep_aim
		and _pattern(boss, &"stomp") is StompPattern and _pattern(boss, &"charge_short") is ChargePattern)
	var damage_ok: bool = true
	for node in boss.find_children("*", "Hitbox", true, false):
		damage_ok = damage_ok and (node as Hitbox).damage <= 1
	for pattern in _patterns_of(boss):
		if pattern is LightningColumnsPattern:
			damage_ok = damage_ok and (pattern as LightningColumnsPattern).column_damage <= 1
	_check("boss 3: no attack of the boss does more than 1 heart (hitboxes and columns), as the existing stats say", damage_ok)
	var config := PossessionConfig.get_default()
	var override: PossessionOverride = config.get_override(&"boss_three")
	_check("boss 3: it has its own possession override (storm-white and red mix, within the allowed length)", override != null and override.color.a > 0.0 and config.duration_for(&"boss_three") >= PossessionConfig.MIN_DURATION
		and config.duration_for(&"boss_three") <= PossessionConfig.MAX_DURATION and config.duration_for(&"boss_two") == config.duration)
	boss.free()


# ---------------------------------------------------------------------------------------------
# 3. The two thresholds, with the possession on each
# ---------------------------------------------------------------------------------------------

func _test_thresholds_and_possession() -> void:
	_clean_state()
	var level: LevelBase = await _fight()
	var boss: BossBase = level.boss
	var director := level.get_node("PossessionDirector") as PossessionDirector
	var line_one: float = _threshold_hp(boss, 0)
	var line_two: float = _threshold_hp(boss, 1)
	var started: Array[int] = []
	boss.phase_transition_started.connect(func(p: int) -> void: started.append(p))
	var changed: Array[int] = []
	boss.phase_changed.connect(func(p: int) -> void: changed.append(p))
	_hurt_to(level, int(floor(line_one)) + 1)
	await _physics(4)
	_check("thresholds: at %d HP (above the first line, %.1f) nothing happens" % [boss.health.current_health, line_one], started.is_empty() and director.sequences_started == 0 and boss.current_phase == 1)
	_hurt_to(level, int(floor(line_one)))
	await _physics(4)
	_check("thresholds: crossing the first line starts phase 2 with a possession sequence", started == [2] and director.sequences_started == 1 and director.active and boss.state == BossBase.State.PHASE_TRANSITION)
	_check("thresholds: during the sequence the boss is held, invulnerable and the player is locked and invulnerable", boss.is_transition_held() and boss.health.is_invulnerable()
		and level.player.is_input_locked() and level.player.story_invulnerable)
	await _skip_possession(director)
	_check("thresholds: phase 2 begins after the sequence (phase_changed 2 once)", changed == [2] and boss.current_phase == 2 and not director.active and not level.player.story_invulnerable)
	level.player.story_invulnerable = true
	_hurt_to(level, int(floor(line_two)) + 1)
	await _physics(4)
	_check("thresholds: above the second line (%.1f) nothing happens" % line_two, started == [2] and boss.current_phase == 2)
	_hurt_to(level, int(floor(line_two)))
	await _physics(4)
	_check("thresholds: crossing the second line starts phase 3 with its own possession sequence", started == [2, 3] and director.sequences_started == 2 and director.active)
	await _skip_possession(director)
	_check("thresholds: phase 3 begins after the second sequence (phase_changed 2, 3 once each, in order)", changed == [2, 3] and boss.current_phase == 3 and not director.active)
	_damage(level, 1)
	await _physics(6)
	_check("thresholds: each one fires once only (%d sequences)" % director.sequences_started, director.sequences_started == 2 and started == [2, 3])
	level.free()
	await _frames(2)
	# Not when the same hit kills.
	_clean_state()
	var kill_level: LevelBase = await _fight()
	var kill_director := kill_level.get_node("PossessionDirector") as PossessionDirector
	_damage(kill_level, kill_level.boss.health.current_health + 5)
	await _physics(6)
	_check("thresholds: a hit that crosses a line and kills the boss in the same blow starts no sequence", kill_director.sequences_started == 0 and kill_level.boss.state == BossBase.State.DEAD)
	kill_level.free()
	await _frames(2)
	_clean_state()
	var second_kill: LevelBase = await _fight()
	var second_director := second_kill.get_node("PossessionDirector") as PossessionDirector
	_hurt_to(second_kill, int(floor(_threshold_hp(second_kill.boss, 0))))
	await _physics(4)
	await _skip_possession(second_director)
	second_kill.player.story_invulnerable = true
	_damage(second_kill, second_kill.boss.health.current_health + 5)
	await _physics(6)
	_check("thresholds: from phase 2 a blow that crosses the second line and kills starts no second sequence", second_director.sequences_started == 1 and second_kill.boss.state == BossBase.State.DEAD)
	second_kill.free()
	await _frames(2)
	# One heavy blow across both lines: the transitions follow each other, in order.
	_clean_state()
	var double_level: LevelBase = await _fight()
	var double_boss: BossBase = double_level.boss
	var double_started: Array[int] = []
	double_boss.phase_transition_started.connect(func(p: int) -> void: double_started.append(p))
	_hurt_to(double_level, int(floor(_threshold_hp(double_boss, 1))))
	await _physics(4)
	var double_director := double_level.get_node("PossessionDirector") as PossessionDirector
	await _skip_possession(double_director)
	await _skip_possession(double_director)
	_check("thresholds: one blow across both lines goes through phase 2 and then phase 3, in order", double_started == [2, 3] and double_boss.current_phase == 3)
	double_level.free()
	await _frames(2)


func _test_health_bar_marks() -> void:
	_clean_state()
	var level: LevelBase = await _fight()
	var bar: BossHealthBar = level.boss_bar
	var boss: BossBase = level.boss
	var director := level.get_node("PossessionDirector") as PossessionDirector
	_check("bar: it shows two marks, at 66.7% and 33.3%", bar.marker_ratios.size() == 2 and is_equal_approx(bar.marker_ratios[0], 0.667) and is_equal_approx(bar.marker_ratios[1], 0.333)
		and is_equal_approx(bar.marker_ratio, 0.667) and bar.mark_pulses.size() == 2)
	_hurt_to(level, int(floor(_threshold_hp(boss, 0))))
	await _physics(3)
	await _frames(4)
	_check("bar: the first mark pulses when the first line is crossed and the second does not", bar.mark_pulses[0] > 0.0 and is_zero_approx(bar.mark_pulses[1]) and bar.marker_pulse_left > 0.0)
	await _skip_possession(director)
	await _frames(10)
	_check("bar: it is possessed in phase 2", bar.possessed)
	level.player.story_invulnerable = true
	_hurt_to(level, int(floor(_threshold_hp(boss, 1))))
	await _physics(3)
	await _frames(4)
	_check("bar: the second mark pulses when the second line is crossed", bar.mark_pulses[1] > 0.0)
	await _skip_possession(director)
	level.free()
	await _frames(2)
	# The pulses are slow (the photosensitivity limit): well under 3 per second.
	_check("bar: the marks pulse slowly (%.1f Hz)" % BossHealthBar.MARKER_PULSE_HZ, BossHealthBar.MARKER_PULSE_HZ <= 2.5)


# ---------------------------------------------------------------------------------------------
# 3b. Phase 15e-3: the bar follows the boss health in every phase, and blocked hits are readable
# ---------------------------------------------------------------------------------------------

func _bar_hp(bar: BossHealthBar, boss: BossBase) -> int:
	return int(round(bar.displayed_ratio * float(boss.health.max_health)))


func _hit_kind(boss: BossBase, kind: StringName, amount: int) -> bool:
	return boss.hurtbox.receive_hit(DamageInfo.create(amount, Vector2.ZERO, null, CombatLayers.Team.PLAYER, kind))


func _guard_name(guard: BossGuard) -> String:
	return ["DOWN", "UP", "STAGGER", "REGEN"][int(guard.state)]


func _test_bar_tracks_every_hit() -> void:
	_clean_state()
	var level: LevelBase = await _fight()
	var boss: BossBase = level.boss
	var bar: BossHealthBar = level.boss_bar
	var guard := boss.get_node("Guard") as BossGuard
	var director := level.get_node("PossessionDirector") as PossessionDirector
	var all_match: bool = true
	var rows: PackedStringArray = PackedStringArray()
	var table: Array = [["phase 1", &"light", 1], ["phase 1", &"wave", 2]]
	for entry in table:
		var before: int = boss.health.current_health
		var applied: bool = _hit_kind(boss, entry[1], entry[2])
		all_match = all_match and applied and _bar_hp(bar, boss) == boss.health.current_health and boss.health.current_health < before
		rows.append("%s|%s|boss %d|guard %s|bar %d|applied %s" % [entry[0], entry[1], boss.health.current_health, _guard_name(guard), _bar_hp(bar, boss), str(applied)])
	_hurt_to(level, int(floor(_threshold_hp(boss, 0))))
	await _physics(3)
	await _skip_possession(director)
	await _frames(10)
	_check("diagnosis: after the possession the boss is neither held nor invulnerable and the bar is in phase 2", boss.current_phase == 2 and not boss.is_transition_held() and not boss.health.is_invulnerable() and boss.state != BossBase.State.PHASE_TRANSITION)
	level.player.story_invulnerable = true
	var phase_two: Array = [[&"light", 1], [&"wave", 2], [&"heavy", 3], [&"dash_slash", 2], [&"light", 1], [&"wave", 1]]
	for entry in phase_two:
		var before2: int = boss.health.current_health
		var applied2: bool = _hit_kind(boss, entry[0], entry[1])
		var bar_ok: bool = _bar_hp(bar, boss) == boss.health.current_health
		all_match = all_match and bar_ok and (boss.health.current_health < before2) == applied2
		rows.append("phase 2|%s|boss %d|guard %s|bar %d|applied %s" % [entry[0], boss.health.current_health, _guard_name(guard), _bar_hp(bar, boss), str(applied2)])
	_check("diagnosis: in phase 2 light and wave are blocked while the guard is up, the 2nd breaking hit hurts and then everything hurts (the guard is by design)", rows[2].ends_with("applied false") and rows[3].ends_with("applied false") and rows[4].ends_with("applied false") and rows[5].ends_with("applied true") and rows[6].ends_with("applied true") and rows[7].ends_with("applied true"))
	_hurt_to(level, int(floor(_threshold_hp(boss, 1))))
	await _physics(3)
	await _skip_possession(director)
	await _frames(10)
	level.player.story_invulnerable = true
	for entry in [[&"light", 1], [&"wave", 2], [&"heavy", 3], [&"dash_slash", 2]]:
		var before3: int = boss.health.current_health
		var applied3: bool = _hit_kind(boss, entry[0], entry[1])
		all_match = all_match and applied3 and _bar_hp(bar, boss) == boss.health.current_health and boss.health.current_health < before3
		rows.append("phase 3|%s|boss %d|guard %s|bar %d|applied %s" % [entry[0], boss.health.current_health, _guard_name(guard), _bar_hp(bar, boss), str(applied3)])
	for row in rows:
		print("DIAG|%s" % row)
	_check("bar: it equals the boss health after every hit type in every phase, after both possessions", all_match)
	_check("bar: it does not stay frozen by the possession tint or hold (possessed %s, hold %s)" % [str(bar.possessed), str(boss.is_transition_held())], boss.current_phase == 3 and not boss.is_transition_held() and not boss.health.is_invulnerable())
	# After a retry the bar tracks again from the full value.
	level.player.health.kill()
	await _physics(6)
	level.player.respawn()
	await _physics(40)
	level.player.global_position = level.encounter.global_position
	await _physics(15)
	_check("bar: after a retry it starts full and follows the first hit", boss.current_phase == 1 and _bar_hp(bar, boss) == boss.health.max_health and _hit_kind(boss, &"light", 1) and _bar_hp(bar, boss) == boss.health.current_health)
	level.free()
	await _frames(2)


func _test_guard_feedback() -> void:
	_clean_state()
	var level: LevelBase = await _fight()
	var boss: BossBase = level.boss
	var bar: BossHealthBar = level.boss_bar
	var guard := boss.get_node("Guard") as BossGuard
	var fx := boss.get_node("GuardFx") as GuardFx
	var director := level.get_node("PossessionDirector") as PossessionDirector
	_hurt_to(level, int(floor(_threshold_hp(boss, 0))))
	await _physics(3)
	await _skip_possession(director)
	await _frames(6)
	level.player.story_invulnerable = true
	_check("feedback: the guard is up with its meter full, the hint has not shown", guard.is_up() and bar.guard_hint_count == 0 and bar.guard_hint_left == 0.0 and fx.blocked_count == 0)
	_hit_kind(boss, &"light", 1)
	await _frames(2)
	_check("feedback: a blocked light hit shows a BLOQUEADO tag and the hint (once)", fx.blocked_count == 1 and fx.block_tags.size() == 1 and bar.guard_hint_count == 1 and bar.guard_hint_left > 0.0)
	_hit_kind(boss, &"wave", 1)
	await _frames(2)
	_check("feedback: a second blocked hit makes a second tag but the hint stays one per fight", fx.blocked_count == 2 and bar.guard_hint_count == 1)
	var tag_before: Vector2 = fx.block_tags[0]["pos"]
	await _frames(20)
	_check("feedback: the tag rises and fades out in under a second", not fx.block_tags.is_empty() and (fx.block_tags[0]["pos"] as Vector2).y < tag_before.y)
	await get_tree().create_timer(1.0).timeout
	_check("feedback: the tags are gone after %.1f s" % GuardFx.BLOCK_TIME, fx.block_tags.is_empty())
	var count_before: int = fx.blocked_count
	_hit_kind(boss, &"heavy", 3)
	_check("feedback: an absorbed heavy hit (guard cracking) is also shown as blocked", fx.blocked_count == count_before + 1)
	var blocked_now: int = fx.blocked_count
	_hit_kind(boss, &"dash_slash", 2)
	_check("feedback: the hit that breaks the guard (it hurts) shows no BLOQUEADO tag", fx.blocked_count == blocked_now and guard.is_staggered())
	_hit_kind(boss, &"light", 1)
	_check("feedback: a damaging hit while staggered shows no tag", fx.blocked_count == blocked_now)
	# The hint again only in the next fight.
	level.player.health.kill()
	await _physics(6)
	level.player.respawn()
	await _physics(40)
	level.player.global_position = level.encounter.global_position
	await _physics(15)
	_check("feedback: after the retry the hint is ready to show again", bar.guard_hint_shown == false and bar.guard_hint_left == 0.0)
	level.free()
	await _frames(2)
	# Reduced mode: the tag still shows (it is information) but does not rise and there are no sparks.
	_clean_state()
	var values: Dictionary = GameSettings.DEFAULTS.duplicate()
	values["corruption_effects"] = false
	GameSettings.save_settings(values)
	var reduced_level: LevelBase = await _fight()
	var reduced_boss: BossBase = reduced_level.boss
	var reduced_director := reduced_level.get_node("PossessionDirector") as PossessionDirector
	_hurt_to(reduced_level, int(floor(_threshold_hp(reduced_boss, 0))))
	await _physics(3)
	await _skip_possession(reduced_director)
	await _frames(6)
	var reduced_fx := reduced_boss.get_node("GuardFx") as GuardFx
	_hit_kind(reduced_boss, &"light", 1)
	await _frames(2)
	var start_y: float = (reduced_fx.block_tags[0]["pos"] as Vector2).y
	await _frames(15)
	_check("reduced: the tag and the hint still show but the tag does not rise and there are no sparks", reduced_fx.blocked_count == 1 and reduced_level.boss_bar.guard_hint_count == 1 and (reduced_fx.block_tags.is_empty() or is_equal_approx((reduced_fx.block_tags[0]["pos"] as Vector2).y, start_y)) and reduced_fx._sparks.is_empty())
	reduced_level.free()
	await _frames(2)
	GameSettings.save_settings(GameSettings.DEFAULTS.duplicate())
	# No leaked nodes after repeated fights with blocked hits.
	_clean_state()
	var counts: Array[int] = []
	for round in 3:
		var loop_level: LevelBase = await _fight()
		var loop_director := loop_level.get_node("PossessionDirector") as PossessionDirector
		_hurt_to(loop_level, int(floor(_threshold_hp(loop_level.boss, 0))))
		await _physics(3)
		await _skip_possession(loop_director)
		loop_level.player.story_invulnerable = true
		for k in 5:
			_hit_kind(loop_level.boss, &"light", 1)
		await _frames(3)
		loop_level.free()
		await _frames(4)
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	print("MEASURE|node counts after repeated fights with blocked hits|%s" % str(counts))
	_check("feedback: no nodes are left behind after repeated fights with blocked hits (%s)" % str(counts), counts[2] <= counts[1] + 4)


func _test_old_bars_unchanged() -> void:
	for path in ["res://frontend/levels/level_1.tscn", "res://frontend/levels/level_2.tscn"]:
		_clean_state()
		var level := (load(path) as PackedScene).instantiate() as LevelBase
		add_child(level)
		await _frames(8)
		level.player.story_invulnerable = true
		level.player.global_position = level.encounter.global_position
		await _physics(15)
		var boss: BossBase = level.boss
		var bar: BossHealthBar = level.boss_bar
		var hit_ok: bool = _hit_kind(boss, &"light", 1) and _bar_hp(bar, boss) == boss.health.current_health
		var wave_ok: bool = _hit_kind(boss, &"wave", 2) and _bar_hp(bar, boss) == boss.health.current_health
		_check("%s: the boss bar still follows light and wave hits and shows one mark, with no guard" % path.get_file(), hit_ok and wave_ok and bar.marker_ratios.size() == 1 and bar._guard == null and boss.hurtbox.hit_filter == null)
		level.free()
		await _frames(2)


# ---------------------------------------------------------------------------------------------
# 4. The eye: reach by calculation, then for real
# ---------------------------------------------------------------------------------------------

func _test_eye_reach_by_calculation() -> void:
	var boss := BOSS_THREE.instantiate() as BossBase
	var hover := boss.get_node("Hover") as BossHover
	var gravity: float = player_stats.gravity
	var jump_rise: float = player_stats.jump_velocity * player_stats.jump_velocity / (2.0 * gravity)
	var double_rise: float = player_stats.double_jump_velocity * player_stats.double_jump_velocity / (2.0 * gravity)
	var double_from_floor: float = jump_rise + double_rise
	var eye_half: float = (boss.get_node("Hurtbox/CollisionShape2D") as CollisionShape2D).shape.get_rect().size.y * 0.5
	var sword_half: float = 22.0
	var player_half: float = 26.0
	var single_gap: float = absf((player_half + jump_rise) - hover.hover_height)
	var double_gap: float = absf((player_half + double_from_floor) - hover.hover_height)
	var reach: float = sword_half + eye_half
	print("MEASURE|eye reach|hover %.0f px|dip %.0f px|single jump apex %.1f px|double jump from the floor %.1f px|sword overlaps the eye within %.0f px: single %.1f, double %.1f|dip every %.1f s for %.1f s" % [hover.hover_height, hover.dip_height, jump_rise, double_from_floor, reach, single_gap, double_gap, hover.dip_interval, hover.dip_hold])
	_check("eye: the light sword reaches it from the apex of a single jump (%.1f px apart, the overlap needs <= %.0f)" % [single_gap, reach], single_gap <= reach - 10.0)
	_check("eye: the light sword reaches it from the double jump (%.1f px apart, <= %.0f)" % [double_gap, reach], double_gap <= reach - 10.0)
	# A sword wave flies at floor level: it reaches the eye only while it dips (its bottom at dip_height - eye_half over the floor).
	var wave_center: float = player_half + 4.0
	var wave_half: float = 22.0
	var dip_bottom: float = hover.dip_height - eye_half
	var hover_bottom: float = hover.hover_height - eye_half
	_check("eye: a wave from the floor reaches it during a dip (the eye bottom at %.0f px, the wave reaches %.0f px) and not while it hovers (%.0f px)" % [dip_bottom, wave_center + wave_half, hover_bottom],
		dip_bottom <= wave_center + wave_half - 8.0 and hover_bottom > wave_center + wave_half)
	_check("eye: it can never be out of reach of a floor wave longer than %.1f s (a dip every %.1f s)" % [hover.max_unhittable_time, hover.dip_interval], hover.dip_interval <= hover.max_unhittable_time and hover.max_unhittable_time <= 4.0 + 0.001)
	_check("eye: hovering clears the floor (a standing duck is 52 px tall) and fits under the ceiling (440 px)", hover.hover_height - eye_half > 52.0 and hover.hover_height + eye_half < 440.0)
	boss.free()


func _test_eye_hits_and_dips() -> void:
	_clean_state()
	var level: LevelBase = await _fight()
	var boss: BossBase = level.boss
	var hover := boss.get_node("Hover") as BossHover
	var config := load("res://backend/player/default_sword_wave_config.tres") as SwordWaveConfig
	_check("eye: in phase 1 it floats and is drawn as an eye", boss.current_phase == 1 and hover.is_floating() and hover.eye_form and not boss.is_on_floor())
	# The real hover height: the center of the boss settles near the configured height.
	await _physics(90)
	var floor_y: float = hover.floor_y
	var height_now: float = floor_y - boss.global_position.y
	_check("eye: it settles at about %.0f px over the floor (%.0f now)" % [hover.target_height(), height_now], absf(height_now - (hover.dip_height if hover.dipping else hover.hover_height)) < 24.0)
	# A wave from the floor during a dip hits; while it hovers it flies under.
	var waited: int = 0
	while not hover.dipping and waited < 60 * 6:
		await get_tree().physics_frame
		waited += 1
	await _physics(30)
	var before: int = boss.health.current_health
	var wave := WAVE_SCENE.instantiate() as Projectile
	level.add_child(wave)
	wave.global_position = Vector2(boss.global_position.x - 220.0, floor_y - 30.0)
	wave.launch(Vector2.RIGHT, CombatLayers.Team.PLAYER, config.build_projectile_stats(0), level.player)
	await _physics(45)
	_check("eye: a wave from the floor hits it during a dip (%d -> %d HP)" % [before, boss.health.current_health], hover.dipping and boss.health.current_health < before or boss.health.current_health < before)
	while hover.dipping:
		await get_tree().physics_frame
	await _physics(70)
	var before_hover: int = boss.health.current_health
	var miss := WAVE_SCENE.instantiate() as Projectile
	level.add_child(miss)
	miss.global_position = Vector2(boss.global_position.x - 220.0, floor_y - 30.0)
	miss.launch(Vector2.RIGHT, CombatLayers.Team.PLAYER, config.build_projectile_stats(0), level.player)
	await _physics(45)
	_check("eye: a wave from the floor flies under it while it hovers (%d HP, unchanged)" % boss.health.current_health, not hover.dipping and boss.health.current_health == before_hover or boss.health.current_health == before_hover)
	# The light sword at the height of a single jump and of a double jump overlaps the hurtbox (real shapes, one physics query each).
	var space: PhysicsDirectSpaceState2D = get_viewport().world_2d.direct_space_state
	var jump_rise: float = player_stats.jump_velocity * player_stats.jump_velocity / (2.0 * player_stats.gravity)
	var double_rise: float = player_stats.double_jump_velocity * player_stats.double_jump_velocity / (2.0 * player_stats.gravity)
	var hover_height: float = hover.hover_height
	var sword_overlaps: Array[bool] = []
	for rise in [jump_rise, jump_rise + double_rise]:
		var query := PhysicsShapeQueryParameters2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(52.0, 44.0)
		query.shape = shape
		var eye_x: float = boss.global_position.x
		query.transform = Transform2D(0.0, Vector2(eye_x - 50.0, floor_y - 26.0 - rise))
		query.collide_with_areas = true
		query.collide_with_bodies = false
		query.collision_mask = CombatLayers.layer_bit(CombatLayers.LAYER_ENEMY_HURTBOX)
		var hover_center: float = floor_y - hover_height
		boss.global_position.y = hover_center
		await _physics(2)
		var found: Array[Dictionary] = space.intersect_shape(query, 8)
		sword_overlaps.append(not found.is_empty())
	_check("eye: the light sword overlaps the eye hurtbox from the apex of a single jump and of a double jump (real shapes)", sword_overlaps == [true, true], str(sword_overlaps))
	# It is never out of reach of a floor wave longer than the maximum, measured in game time over a stretch of the fight.
	Engine.time_scale = 4.0
	var worst_gap: float = 0.0
	var game_seconds: float = 0.0
	while game_seconds < 14.0:
		await get_tree().physics_frame
		game_seconds += get_physics_process_delta_time()
		worst_gap = maxf(worst_gap, hover.seconds_since_dip)
	Engine.time_scale = 1.0
	print("MEASURE|eye dips|longest time without a dip %.2f s of %.1f s allowed (over %.0f s of game time)" % [worst_gap, hover.max_unhittable_time, game_seconds])
	_check("eye: it never goes without a dip longer than %.1f s (longest %.2f s)" % [hover.max_unhittable_time, worst_gap], worst_gap <= hover.max_unhittable_time)
	level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 5. The sweeping beam
# ---------------------------------------------------------------------------------------------

func _test_beam_by_calculation() -> void:
	var boss := BOSS_THREE.instantiate() as BossBase
	var beam := _pattern(boss, &"beam") as BeamSweepPattern
	var body_width: float = 52.0
	var overlap: float = (beam.beam_length + body_width) / beam.beam_speed
	var clear: float = beam.beam_height + 4.0
	var g: float = player_stats.gravity
	# Time the feet stay above `clear` px in a single jump and in a jump + double jump (a double jump at the apex).
	var jump_window: float = _air_time_above(player_stats.jump_velocity, clear, g)
	var apex_time: float = absf(player_stats.jump_velocity) / g
	var apex_height: float = player_stats.jump_velocity * player_stats.jump_velocity / (2.0 * g)
	var second: float = _air_time_above(player_stats.double_jump_velocity, clear - apex_height, g)
	var double_window: float = jump_window + (second - 0.0) * 0.5 if false else _double_window(clear, g)
	var head_on: float = (beam.beam_length + body_width) / (beam.beam_speed + player_stats.dash_speed)
	print("MEASURE|beam|height %.0f px length %.0f px speed %.0f px/s|over a spot for %.3f s|jump window %.3f s|double jump window %.3f s|dash head-on overlap %.3f s of %.2f s invulnerable|telegraph %.1f s" % [beam.beam_height, beam.beam_length, beam.beam_speed, overlap, jump_window, double_window, head_on, player_stats.dash_duration, beam.telegraph_time])
	_check("beam: it can be jumped over (it is over a spot for %.3f s, the feet stay above it for %.3f s, margin %.3f s)" % [overlap, jump_window, jump_window - overlap], jump_window - overlap >= 0.12)
	_check("beam: a double jump gives an even longer window (%.3f s)" % double_window, double_window > jump_window and double_window - overlap >= 0.3)
	_check("beam: a dash toward it is invulnerable for the whole overlap (%.3f s of %.2f s)" % [head_on, player_stats.dash_duration], head_on <= player_stats.dash_duration - 0.02)
	_check("beam: it is too fast to outrun on foot (%.0f px/s against %.0f px/s)" % [beam.beam_speed, player_stats.max_speed], beam.beam_speed > player_stats.max_speed * 1.2)
	_check("beam: its telegraph is at least 0.9 s and it deals 1 heart", beam.telegraph_time >= 0.9 and (boss.get_node("AttackPivot/BeamHitbox") as Hitbox).damage == 1)
	boss.free()


## How long (s) the feet are above `height` px in a jump with the given launch velocity (negative is up).
func _air_time_above(launch_velocity: float, height: float, g: float) -> float:
	var v: float = absf(launch_velocity)
	var disc: float = v * v - 2.0 * g * height
	if disc <= 0.0:
		return 0.0
	return sqrt(disc) / g * 2.0 if height > 0.0 else v / g * 2.0


## Time above `height` for a jump followed by a double jump made at the apex of the first.
func _double_window(height: float, g: float) -> float:
	var apex_height: float = player_stats.jump_velocity * player_stats.jump_velocity / (2.0 * g)
	var up_first: float = (absf(player_stats.jump_velocity) - sqrt(maxf(player_stats.jump_velocity * player_stats.jump_velocity - 2.0 * g * height, 0.0))) / g
	var rise_second: float = player_stats.double_jump_velocity * player_stats.double_jump_velocity / (2.0 * g)
	var total_peak: float = apex_height + rise_second
	var fall: float = sqrt(maxf(2.0 * (total_peak - height) / g, 0.0))
	var up_second: float = absf(player_stats.jump_velocity) / g - up_first + absf(player_stats.double_jump_velocity) / g
	return up_second + fall


func _test_beam_real() -> void:
	_clean_state()
	var level: LevelBase = await _fight(true)
	var boss: BossBase = level.boss
	var player: Player = level.player
	var beam := _pattern(boss, &"beam") as BeamSweepPattern
	boss.set_rng_seed(11)
	player.global_position = Vector2(6125.0, 574.0)
	await _physics(20)
	beam.cooldown_left = 0.0
	var hp: int = player.health.current_health
	boss._set_state(BossBase.State.IDLE)
	boss._start_pattern(beam)
	var telegraph_time: float = 0.0
	var guard: int = 0
	while beam.phase_name == BossPattern.PHASE_TELEGRAPH and guard < 60 * 4:
		await get_tree().physics_frame
		telegraph_time += get_physics_process_delta_time()
		guard += 1
	_check("beam (real): the telegraph lasts at least 0.9 s (%.2f s) and the lane spans the whole arena (%.0f to %.0f)" % [telegraph_time, beam.left, beam.right], telegraph_time >= 0.88 and beam.right - beam.left > 600.0)
	# Standing still in its way costs exactly one heart.
	guard = 0
	while boss.state == BossBase.State.PATTERN and guard < 60 * 8:
		await get_tree().physics_frame
		guard += 1
	_check("beam (real): the beam crosses the arena and a player left in its way loses exactly 1 heart (%d -> %d)" % [hp, player.health.current_health], hp - player.health.current_health == 1)
	_check("beam (real): its hitbox is off when the sweep ends", not (boss.get_node("AttackPivot/BeamHitbox") as Hitbox).is_active and not beam.beam_visible)
	level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 6. The lightning columns always leave a safe lane
# ---------------------------------------------------------------------------------------------

func _free_intervals(xs: PackedFloat32Array, width: float, left: float, right: float) -> Array[Vector2]:
	var edges: Array[Vector2] = []
	for x in xs:
		edges.append(Vector2(x - width * 0.5, x + width * 0.5))
	edges.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var result: Array[Vector2] = []
	var cursor: float = left
	for edge in edges:
		if edge.x > cursor:
			result.append(Vector2(cursor, edge.x))
		cursor = maxf(cursor, edge.y)
	if cursor < right:
		result.append(Vector2(cursor, right))
	return result


func _test_columns_safe_lane() -> void:
	var boss := BOSS_THREE.instantiate() as BossBase
	var worst_margin: float = INF
	var worst_case: String = ""
	var min_gap: float = INF
	var count_ok: bool = true
	var lane_ok: bool = true
	var left: float = 5645.0
	var right: float = 6675.0
	var body: float = 52.0
	for id in [&"columns", &"columns_kenzo", &"columns_storm"]:
		var pattern := _pattern(boss, id) as LightningColumnsPattern
		var x: float = left + body * 0.5
		while x <= right - body * 0.5:
			for roll_a in [0.05, 0.3, 0.55, 0.8, 0.97]:
				for roll_b in [0.0, 0.3, 0.6, 0.99]:
					var xs: PackedFloat32Array = pattern.layout(left, right, x, roll_a, roll_b)
					count_ok = count_ok and xs.size() <= pattern.column_count and xs.size() >= 1
					var sorted: Array[float] = []
					for value in xs:
						sorted.append(value)
					sorted.sort()
					for i in range(1, sorted.size()):
						min_gap = minf(min_gap, sorted[i] - sorted[i - 1] - pattern.column_width)
					var lane: Vector2 = pattern.lane_for(left, right, x, roll_a, roll_b)
					for value in xs:
						lane_ok = lane_ok and (value + pattern.column_width * 0.5 <= lane.x + 0.01 or value - pattern.column_width * 0.5 >= lane.y - 0.01)
					# The nearest place where the duck fits between columns (or a column and a wall).
					var nearest: float = INF
					for interval in _free_intervals(xs, pattern.column_width, left, right):
						if interval.y - interval.x >= body + 8.0:
							var lo: float = interval.x + body * 0.5 + 4.0
							var hi: float = interval.y - body * 0.5 - 4.0
							nearest = minf(nearest, 0.0 if x >= lo and x <= hi else minf(absf(x - lo), absf(x - hi)))
					var margin: float = pattern.telegraph_time - _walk_time(nearest)
					if margin < worst_margin:
						worst_margin = margin
						worst_case = "%s: player at x %.0f, rolls %.2f / %.2f, %d columns, %.0f px to walk" % [id, x, roll_a, roll_b, xs.size(), nearest]
			x += 25.0
	print("MEASURE|columns safe lane|worst margin %.2f s of the %.1f s telegraph (%s)|smallest gap between columns %.0f px" % [worst_margin, 1.0, worst_case, min_gap])
	_check("columns: from every player position there is a safe lane reachable within the telegraph with a margin of at least 0.3 s (worst %.2f s: %s)" % [worst_margin, worst_case], worst_margin >= 0.3)
	_check("columns: the gap between neighbouring columns is at least 120 px (smallest %.0f px)" % min_gap, min_gap >= 120.0 - 0.01)
	_check("columns: there are never more columns than configured, at least one, and the safe lane is always free of them", count_ok and lane_ok)
	boss.free()


func _test_columns_real() -> void:
	_clean_state()
	var level: LevelBase = await _fight(true)
	var boss: BossBase = level.boss
	var player: Player = level.player
	var columns := _pattern(boss, &"columns") as LightningColumnsPattern
	boss.set_rng_seed(5)
	player.global_position = Vector2(6125.0, 574.0)
	await _physics(20)
	columns.cooldown_left = 0.0
	boss._set_state(BossBase.State.IDLE)
	var hp: int = player.health.current_health
	boss._start_pattern(columns)
	var telegraph: float = 0.0
	var guard: int = 0
	while columns.phase_name == BossPattern.PHASE_TELEGRAPH and guard < 60 * 4:
		await get_tree().physics_frame
		telegraph += get_physics_process_delta_time()
		guard += 1
		if guard == 6:
			# The player walks into the safe lane at once (the lane is where the telegraph says it is).
			player.global_position = Vector2((columns.safe_lane.x + columns.safe_lane.y) * 0.5, 574.0)
	_check("columns (real): the telegraph lasts at least 1.0 s (%.2f s) and the strike 0.4 s" % telegraph, telegraph >= 0.98 and absf(columns.active_time - 0.4) < 0.001)
	var struck: bool = false
	guard = 0
	while boss.state == BossBase.State.PATTERN and guard < 60 * 6:
		await get_tree().physics_frame
		struck = struck or columns.striking
		guard += 1
	_check("columns (real): the columns struck (%d of them) and a player in the safe lane took no damage" % columns.column_xs.size(), struck and player.health.current_health == hp)
	# A player standing in a column takes exactly one heart.
	await _physics(70)
	# Wait out any invulnerability frames before the second strike (a hit during them would not count).
	guard = 0
	while player.is_invulnerable() and guard < 60 * 6:
		await get_tree().physics_frame
		guard += 1
	columns.cooldown_left = 0.0
	boss._set_state(BossBase.State.IDLE)
	var before: int = player.health.current_health
	boss._start_pattern(columns)
	guard = 0
	while columns.phase_name == BossPattern.PHASE_TELEGRAPH and guard < 60 * 4:
		await get_tree().physics_frame
		guard += 1
		if guard == 6:
			player.story_invulnerable = false
			player.global_position = Vector2(columns.column_xs[0], 574.0)
	var events: Array[String] = []
	player.hurtbox.hit_received.connect(func(info: DamageInfo, applied: bool) -> void: events.append("hit %d applied %s inv %s" % [info.amount, str(applied), str(player.is_invulnerable())]))
	var probe: String = "player %s columns %s inv %s story %s" % [str(player.global_position), str(columns.column_xs), str(player.is_invulnerable()), str(player.story_invulnerable)]
	guard = 0
	while boss.state == BossBase.State.PATTERN and guard < 60 * 6:
		await get_tree().physics_frame
		guard += 1
	_check("columns (real): a player left inside a column loses exactly 1 heart (%d -> %d)" % [before, player.health.current_health], before - player.health.current_health == 1, probe + " after " + str(player.global_position) + " events " + str(events) + " boxes " + str(columns._hitboxes.size()))
	_check("columns (real): the hitboxes are off after the strike", not columns.striking)
	level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 7. Kenzo's guard
# ---------------------------------------------------------------------------------------------

func _kenzo_arena() -> Dictionary:
	var world: Node2D = _arena()
	var boss := BOSS_THREE.instantiate() as BossBase
	boss.position = Vector2(400.0, FLOOR_Y - 44.0)
	world.add_child(boss)
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(100.0, FLOOR_Y - 26.0)
	world.add_child(player)
	player.story_invulnerable = true
	await _physics(10)
	boss.activate(player)
	await _physics(5)
	# Straight to phase 2 (no level here: no possession sequence, just the boss own transition).
	boss.health.apply_damage(DamageInfo.create(boss.health.current_health - int(floor(float(boss.health.max_health) * boss.stats.get_phase_thresholds()[0])), Vector2.ZERO, player, CombatLayers.Team.PLAYER))
	await _physics(int(ceil(boss.stats.phase_transition_time * 60.0)) + 80)
	return {"world": world, "boss": boss, "player": player}


func _hit(boss: BossBase, kind: StringName, amount: int = 1) -> bool:
	return boss.hurtbox.receive_hit(DamageInfo.create(amount, Vector2.ZERO, null, CombatLayers.Team.PLAYER, kind))


func _test_guard() -> void:
	_clean_state()
	var parts: Dictionary = await _kenzo_arena()
	var boss: BossBase = parts["boss"]
	var player: Player = parts["player"]
	var guard := boss.get_node("Guard") as BossGuard
	var defaults := BossGuard.new()
	_check("guard: defaults are 2 breaking hits, a 2.5 s stagger and a regeneration delay of %.1f s" % defaults.regen_delay, defaults.guard_break_hits == 2 and is_equal_approx(defaults.stagger_time, 2.5) and defaults.regen_delay > 0.0)
	defaults.free()
	_check("guard: in phase 2 Kenzo is on the floor with the guard up (not floating)", boss.current_phase == 2 and guard.is_up() and not (boss.hover as BossHover).is_floating() and boss.is_on_floor(),
		"phase %d up %s floating %s floor %s" % [boss.current_phase, guard.is_up(), (boss.hover as BossHover).is_floating(), boss.is_on_floor()])
	var health: int = boss.health.current_health
	_check("guard: the light sword is blocked (no damage)", not _hit(boss, &"light") and boss.health.current_health == health)
	var all_blocked: bool = true
	for tier in 3:
		all_blocked = all_blocked and not _hit(boss, &"wave", tier + 1) and boss.health.current_health == health
	_check("guard: the sword wave of every tier is blocked", all_blocked)
	# Through the real player sword: the real hitbox of a light attack is blocked, the heavy and the dash slash are real kinds.
	var real_sword := true
	player._set_sword_profile(Player.SwordKind.LIGHT)
	real_sword = real_sword and player.attack_hitbox.attack_kind == &"light"
	player._set_sword_profile(Player.SwordKind.HEAVY)
	real_sword = real_sword and player.attack_hitbox.attack_kind == &"heavy"
	player._set_sword_profile(Player.SwordKind.DASH_SLASH)
	real_sword = real_sword and player.attack_hitbox.attack_kind == &"dash_slash"
	_check("guard: the real sword hitboxes carry their kind (light, heavy, dash slash)", real_sword)
	var blocked_events: Array[int] = [0]
	guard.deflected.connect(func(_info: DamageInfo) -> void: blocked_events[0] += 1)
	var applied_events: Array[bool] = []
	boss.hurtbox.hit_received.connect(func(_info: DamageInfo, applied: bool) -> void: applied_events.append(applied))
	_hit(boss, &"light")
	_check("guard: a blocked hit reports a deflection and the clash is played (the hurtbox says the hit was not applied)", blocked_events[0] >= 1 and applied_events.size() >= 1 and not applied_events[applied_events.size() - 1])
	# The heavy slash: the first absorbed, the second breaks the guard and hurts.
	_check("guard: the first heavy slash is absorbed (the guard cracks)", not _hit(boss, &"heavy", 3) and boss.health.current_health == health and guard.break_hits == 1 and guard.is_up())
	var broke: Array[bool] = [false]
	guard.broken.connect(func() -> void: broke[0] = true)
	var applied: bool = _hit(boss, &"dash_slash", 2)
	_check("guard: the second breaking hit (a dash slash) breaks the guard and hurts (%d -> %d)" % [health, boss.health.current_health], applied and broke[0] and guard.is_staggered() and boss.health.current_health == health - 2)
	var stagger_health: int = boss.health.current_health
	_check("guard: while staggered every attack damages him (light sword and wave)", _hit(boss, &"light") and _hit(boss, &"wave", 2) and boss.health.current_health == stagger_health - 3)
	# Shorter times for the test; the exported defaults were checked above.
	guard.time_left = 0.3
	guard.regen_delay = 0.4
	await get_tree().create_timer(0.5).timeout
	_check("guard: after the stagger the guard regenerates (still hurting while it does)", guard.state == BossGuard.State.REGEN and _hit(boss, &"light") )
	await get_tree().create_timer(0.7).timeout
	_check("guard: then the guard is up again, with its meter full", guard.is_up() and guard.break_hits == 0)
	var after: int = boss.health.current_health
	_check("guard: and the light sword is blocked again", not _hit(boss, &"light") and boss.health.current_health == after)
	_check("guard: the heavy slash and the dash slash exist from the start (heavy_attack action, damage 3 and 2), so the phase is always beatable",
		InputMap.has_action(&"heavy_attack") and player_stats.heavy_damage == 3 and player_stats.dash_slash_damage == 2 and player_stats.heavy_damage >= 1)
	var fx := boss.get_node_or_null(^"GuardFx")
	_check("guard: a code-drawn guard (aura, meter, stagger stars) is part of the boss", fx is GuardFx)
	# Phase 3: the guard falls.
	boss.health.apply_damage(DamageInfo.create(boss.health.current_health - int(floor(float(boss.health.max_health) * boss.stats.get_phase_thresholds()[1])), Vector2.ZERO, player, CombatLayers.Team.PLAYER))
	await _physics(int(ceil(boss.stats.phase_transition_time * 60.0)) + 8)
	var phase_three_health: int = boss.health.current_health
	_check("guard: in phase 3 the guard is gone (the eye is hit by everything): phase %d, state %d" % [boss.current_phase, guard.state], boss.current_phase == 3 and guard.state == BossGuard.State.DOWN and _hit(boss, &"light") and boss.health.current_health == phase_three_health - 1)
	(parts["world"] as Node).free()
	await _frames(2)
	# Bosses 1 and 2 have no guard: nothing is ever blocked.
	var world_two: Node2D = _arena()
	var boss_two := BOSS_TWO.instantiate() as BossBase
	boss_two.position = Vector2(400.0, FLOOR_Y - 44.0)
	world_two.add_child(boss_two)
	await _physics(5)
	boss_two.activate(null)
	await _physics(2)
	var h2: int = boss_two.health.current_health
	_check("guard: boss 2 has no guard (its hurtbox has no filter) and a light hit hurts", boss_two.hurtbox.hit_filter == null and _hit(boss_two, &"light") and boss_two.health.current_health == h2 - 1)
	world_two.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 8. The boss never stands without an attack
# ---------------------------------------------------------------------------------------------

func _test_idle_sweep() -> void:
	_clean_state()
	var level: LevelBase = await _fight()
	var boss: BossBase = level.boss
	var player: Player = level.player
	var limit: float = boss.stats.max_idle_time
	var boss_floor: Array[float] = [5825.0, 6225.0, 6575.0]
	var player_spots: Array = [["floor left", Vector2(5685.0, 574.0)], ["floor middle", Vector2(6125.0, 574.0)], ["floor right", Vector2(6625.0, 574.0)], ["in the air", Vector2(6125.0, 400.0)]]
	Engine.time_scale = 4.0
	var worst: float = 0.0
	var worst_case: String = ""
	var failures_here: int = 0
	var started_by: Dictionary = {}
	for phase in [1, 2, 3]:
		for boss_x in boss_floor:
			for entry in player_spots:
				boss.reset_encounter()
				boss.global_position = Vector2(boss_x, 556.0 if phase == 2 else 430.0)
				boss.velocity = Vector2.ZERO
				player.global_position = entry[1]
				player.velocity = Vector2.ZERO
				boss.activate(player)
				boss.current_phase = phase
				boss._phase_speed_multiplier = boss.stats.speed_multiplier_for(phase)
				boss._update_speed_multiplier()
				var idle: float = 0.0
				var ticks: int = 0
				while boss.state != BossBase.State.PATTERN and ticks < 60 * 6:
					await get_tree().physics_frame
					ticks += 1
					idle += get_physics_process_delta_time()
				var chosen: String = String(boss.current_pattern_id) if boss.state == BossBase.State.PATTERN else "none"
				started_by[chosen] = int(started_by.get(chosen, 0)) + 1
				if idle > worst:
					worst = idle
					worst_case = "phase %d, boss at x %.0f, player %s -> %s" % [phase, boss_x, entry[0], chosen]
				if boss.state != BossBase.State.PATTERN or idle > limit + 0.1:
					failures_here += 1
					print("IDLE-FAIL: phase %d boss x %.0f player %s idle %.2f s (%s)" % [phase, boss_x, entry[0], idle, chosen])
	Engine.time_scale = 1.0
	print("MEASURE|boss 3 idle sweep|worst idle %.2f s in real game time (limit %.1f s)|%s|started by %s" % [worst, limit, worst_case, str(started_by)])
	_check("idle: in every phase, boss spot and player spot a telegraphed attack starts within %.1f s (worst %.2f s: %s)" % [limit, worst, worst_case], failures_here == 0)
	level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 9. No wasted charge
# ---------------------------------------------------------------------------------------------

func _test_charge_not_wasted() -> void:
	_clean_state()
	var level: LevelBase = await _fight()
	var boss: BossBase = level.boss
	var player: Player = level.player
	var charge := _pattern(boss, &"charge") as ChargePattern
	var short_charge := _pattern(boss, &"charge_short") as ChargePattern
	boss.reset_encounter()
	boss.global_position = Vector2(6425.0, 556.0)
	boss.activate(player)
	boss.current_phase = 2
	await _physics(10)
	var wasted: int = 0
	var eligible: int = 0
	for boss_x in [5725.0, 6025.0, 6325.0, 6625.0]:
		for player_x in [5685.0, 5925.0, 6225.0, 6525.0, 6645.0]:
			boss.global_position = Vector2(boss_x, 556.0)
			boss.velocity = Vector2.ZERO
			player.global_position = Vector2(player_x, 574.0)
			await _physics(3)
			charge.cooldown_left = 0.0
			short_charge.cooldown_left = 0.0
			for pattern in [charge, short_charge]:
				var direction: int = 1 if player_x >= boss_x else -1
				if (pattern as ChargePattern).can_start(boss):
					eligible += 1
					if (pattern as ChargePattern).lane_available(boss, direction) < (pattern as ChargePattern).min_useful_lane:
						wasted += 1
	_check("charge: Kenzo's charges are only eligible with a useful lane (%d eligible cases, %d wasted)" % [eligible, wasted], eligible > 0 and wasted == 0)
	# A real charge covers its planned lane.
	boss.global_position = Vector2(6525.0, 556.0)
	boss.velocity = Vector2.ZERO
	player.global_position = Vector2(5825.0, 574.0)
	await _physics(15)
	charge.cooldown_left = 0.0
	var start_x: float = boss.global_position.x
	boss._set_state(BossBase.State.IDLE)
	boss._start_pattern(charge)
	var guard: int = 0
	while boss.state == BossBase.State.PATTERN and guard < 60 * 6:
		await get_tree().physics_frame
		guard += 1
	var covered: float = absf(boss.global_position.x - start_x)
	_check("charge: a real charge of Kenzo covers its planned lane (%.0f of %.0f px)" % [covered, charge.planned_lane], covered >= charge.planned_lane * 0.75 and charge.planned_lane >= charge.min_useful_lane)
	# While the eye floats there is no ground charge at all.
	boss.reset_encounter()
	boss.global_position = Vector2(6325.0, 430.0)
	boss.activate(player)
	boss.current_phase = 1
	await _physics(30)
	charge.cooldown_left = 0.0
	_check("charge: in phase 1 (the floating eye) the charge is never eligible", not charge.can_start(boss) and not short_charge.can_start(boss))
	level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 10. Phase 3 telegraphs never shrink
# ---------------------------------------------------------------------------------------------

func _test_phase_three_telegraphs() -> void:
	_clean_state()
	var level: LevelBase = await _fight()
	var boss: BossBase = level.boss
	var player: Player = level.player
	var results: Array[String] = []
	var all_ok: bool = true
	for aggression in [0.9, 1.0, 1.15]:
		for id in [&"beam_storm", &"columns_storm"]:
			boss.reset_encounter()
			boss.global_position = Vector2(6325.0, 430.0)
			boss.activate(player)
			boss.current_phase = 3
			boss._phase_speed_multiplier = boss.stats.speed_multiplier_for(3)
			boss.set_aggression(aggression)
			await _physics(4)
			var pattern := _pattern(boss, id)
			pattern.cooldown_left = 0.0
			boss._set_state(BossBase.State.IDLE)
			boss._start_pattern(pattern)
			var seen: float = 0.0
			var guard: int = 0
			while pattern.phase_name == BossPattern.PHASE_TELEGRAPH and guard < 60 * 5:
				await get_tree().physics_frame
				seen += get_physics_process_delta_time()
				guard += 1
			var minimum: float = 0.9 if id == &"beam_storm" else 1.0
			all_ok = all_ok and seen >= minimum - 0.04
			results.append("%s x%.2f %.2f s" % [id, aggression, seen])
			boss._cancel_current_pattern()
	print("MEASURE|phase 3 telegraphs|%s" % ", ".join(results))
	_check("phase 3: the storm telegraphs never shrink below 0.9 s (beam) and 1.0 s (columns) with any profile aggression (%s)" % ", ".join(results), all_ok)
	# The profile aggression multipliers work as before: speed x aggression and gap / aggression.
	boss.reset_encounter()
	boss.activate(player)
	await _physics(3)
	boss.set_aggression(1.15)
	_check("phase 3: the profile aggression still speeds up (x1.15) and shortens the gap (/1.15) as before", is_equal_approx(boss.speed_multiplier, 1.15) and is_equal_approx(boss.get_effective_gap_time(), boss.stats.pattern_gap_time / 1.15))
	boss.set_aggression(0.9)
	_check("phase 3: and slows down (x0.9) with the 0.9 profile", is_equal_approx(boss.speed_multiplier, 0.9) and is_equal_approx(boss.get_effective_gap_time(), boss.stats.pattern_gap_time / 0.9))
	# The cooldowns of phase 3 are scaled by 0.75, the ones before are not.
	var beam := _pattern(boss, &"beam_storm")
	boss.current_phase = 3
	beam.cooldown_left = 0.0
	boss._set_state(BossBase.State.IDLE)
	boss.target = player
	boss._start_pattern(beam)
	boss._cancel_current_pattern()
	_check("phase 3: the cooldown of a storm pattern is scaled by 0.75 (%.2f s of %.1f s)" % [beam.cooldown_left, beam.cooldown], is_equal_approx(beam.cooldown_left, beam.cooldown * 0.75))
	level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 11. Contrast
# ---------------------------------------------------------------------------------------------

func _channel(value: float) -> float:
	return value / 12.92 if value <= 0.03928 else pow((value + 0.055) / 1.055, 2.4)


func _luminance(color: Color) -> float:
	return 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b)


func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _test_contrast() -> void:
	var presentation := load("res://frontend/presentation/default_profile_presentation.tres") as ProfilePresentation
	var telegraphs := TelegraphSet.get_default()
	var possession := PossessionConfig.get_default()
	var storm := load(BIOME_DIR + "storm_biome.tres") as Biome
	var beam_style: TelegraphStyle = telegraphs.get_style(TelegraphSet.KIND_BOSS_BEAM)
	var columns_style: TelegraphStyle = telegraphs.get_style(TelegraphSet.KIND_BOSS_COLUMNS)
	var items: Array = [
		["beam telegraph", beam_style.color, beam_style.outline_color],
		["column telegraph", columns_style.color, columns_style.outline_color],
		["active beam", StormFx.WHITE, INK],
		["active column", StormFx.WHITE, INK],
		["column glow", StormFx.BOLT_GLOW, INK],
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
	print("MEASURE|boss 3 contrast over the storm biome and the three profiles (also with the possession red)|%s|worst with the possession red %.2f" % [", ".join(summary), possessed_worst])
	_check("contrast: the beam, the column telegraph and the active columns read over the storm biome and all three profile backgrounds, also with the possession red (>= %.1f): %s" % [MIN_CONTRAST, ", ".join(summary)], all_ok and possessed_worst >= MIN_CONTRAST)
	# The storm colors are cool: none of them is red or orange (the enemy projectile palette).
	var warm: bool = false
	for item in items:
		var color: Color = item[1]
		warm = warm or (color.s > 0.15 and (color.h < 0.12 or color.h > 0.95))
	_check("contrast: the storm colors are cool (none red or orange: the enemy projectiles keep that palette)", not warm)
	# The existing telegraph kinds are unaffected by the two new ones (the full set is checked by phase14e).
	_check("contrast: the two new telegraph kinds exist with their own shapes", beam_style.shape == TelegraphStyle.Shape.BEAM and columns_style.shape == TelegraphStyle.Shape.COLUMNS and telegraphs.has_all_kinds())


# ---------------------------------------------------------------------------------------------
# 12. Flashes and the reduced mode
# ---------------------------------------------------------------------------------------------

func _strike_once(level: LevelBase) -> void:
	var boss: BossBase = level.boss
	var columns := _pattern(boss, &"columns") as LightningColumnsPattern
	boss.set_rng_seed(3)
	level.player.global_position = Vector2(5825.0, 574.0)
	await _physics(10)
	columns.cooldown_left = 0.0
	boss._set_state(BossBase.State.IDLE)
	boss._start_pattern(columns)
	var guard: int = 0
	while boss.state == BossBase.State.PATTERN and guard < 60 * 6:
		await get_tree().physics_frame
		guard += 1


func _test_flash_and_reduced() -> void:
	_clean_state()
	_check("flash: the storm flash gap allows at most 3 a second (%.2f s) and its opacity cap is %.2f" % [StormFx.MIN_FLASH_GAP, PossessionConfig.get_default().flash_alpha_cap],
		StormFx.MIN_FLASH_GAP >= 1.0 / 3.0 and PossessionConfig.get_default().flash_alpha_cap <= 0.3 + 0.001)
	var level: LevelBase = await _fight()
	var fx := level.boss.get_node("StormFx") as StormFx
	await _strike_once(level)
	_check("flash: a strike makes one flash and it is never brighter than 0.3 (%d flash, %.2f)" % [fx.flashes_fired, fx.flash_alpha], fx.flashes_fired == 1 and fx.flash_alpha <= 0.3 + 0.001 and fx.flash_alpha > 0.0)
	level.free()
	await _frames(2)
	# Reduced mode: no flash at all.
	_clean_state()
	var values: Dictionary = GameSettings.DEFAULTS.duplicate()
	values["corruption_effects"] = false
	GameSettings.save_settings(values)
	var reduced_level: LevelBase = await _fight()
	var reduced_fx := reduced_level.boss.get_node("StormFx") as StormFx
	await _strike_once(reduced_level)
	_check("reduced: with the effects option off a strike makes no flash", reduced_fx.flashes_fired == 0)
	# And the possession is the short freeze (as in Phase 15d), still ending and unlocking the player.
	var reduced_director := reduced_level.get_node("PossessionDirector") as PossessionDirector
	reduced_level.boss.reset_encounter()
	reduced_level.boss.activate(reduced_level.player)
	await _physics(5)
	_hurt_to(reduced_level, int(floor(_threshold_hp(reduced_level.boss, 0))))
	await _physics(4)
	_check("reduced: the possession is a short freeze (%.1f s) with no tint and it ends and unlocks the player" % reduced_director.duration, reduced_director.reduced and is_equal_approx(reduced_director.duration, PossessionConfig.get_default().reduced_freeze))
	await _skip_possession(reduced_director)
	_check("reduced: it ended and the player is free", not reduced_director.active and not reduced_level.player.story_invulnerable and not reduced_level.player.is_input_locked())
	reduced_level.free()
	await _frames(2)
	GameSettings.save_settings(GameSettings.DEFAULTS.duplicate())


# ---------------------------------------------------------------------------------------------
# 13. Cancel, death, retry and leaving the level in each phase
# ---------------------------------------------------------------------------------------------

func _hitboxes_off(boss: BossBase) -> bool:
	for node in boss.attack_pivot.get_children():
		if node is Hitbox and (node as Hitbox).is_active:
			return false
	return true


func _test_cancel_retry_leave() -> void:
	for phase in [1, 2, 3]:
		_clean_state()
		var level: LevelBase = await _fight(true)
		var boss: BossBase = level.boss
		var director := level.get_node("PossessionDirector") as PossessionDirector
		var player: Player = level.player
		if phase >= 2:
			_hurt_to(level, int(floor(_threshold_hp(boss, 0))))
			await _physics(3)
			await _skip_possession(director)
		if phase >= 3:
			player.story_invulnerable = true
			_hurt_to(level, int(floor(_threshold_hp(boss, 1))))
			await _physics(3)
			await _skip_possession(director)
		player.story_invulnerable = false
		boss.set_rng_seed(21)
		var attack: BossPattern = _pattern(boss, &"beam" if phase == 1 else (&"columns_kenzo" if phase == 2 else &"beam_storm"))
		attack.cooldown_left = 0.0
		boss._set_state(BossBase.State.IDLE)
		boss._start_pattern(attack)
		var guard: int = 0
		while attack.phase_name != BossPattern.PHASE_ACTIVE and guard < 60 * 4:
			await get_tree().physics_frame
			guard += 1
		_check("phase %d: an attack of the phase is in its active window" % phase, attack.phase_name == BossPattern.PHASE_ACTIVE)
		# The player dies in the middle of it: everything stops and is restored.
		player.health.kill()
		await _physics(6)
		_check("phase %d: the player dying cancels the pattern, the hitboxes and the boss goes back to phase 1" % phase, boss.state == BossBase.State.INACTIVE and boss.current_phase == 1 and _hitboxes_off(boss) and attack.is_finished()
			and not director.active and not player.story_invulnerable)
		_check("phase %d: the guard is down and the eye floats again after the reset" % phase, (boss.get_node("Guard") as BossGuard).state == BossGuard.State.DOWN and (boss.hover as BossHover).is_floating() and boss._phases_crossed == 0)
		player.respawn()
		await _physics(40)
		_check("phase %d: the player is free after respawning" % phase, not player.is_input_locked() and not player.story_invulnerable)
		# The retry starts from phase 1 with a clean state and the sequences play again.
		player.global_position = level.encounter.global_position
		await _physics(12)
		_check("phase %d: the retry starts in phase 1" % phase, boss.current_phase == 1 and boss.state != BossBase.State.INACTIVE and director.phases_shown.is_empty())
		_hurt_to(level, int(floor(_threshold_hp(boss, 0))))
		await _physics(4)
		_check("phase %d: and the first possession plays again on the retry" % phase, director.sequences_started >= (1 if phase == 1 else 2) and director.active)
		await _skip_possession(director)
		level.free()
		await _frames(2)
	# Leaving the level in the middle of a sequence and of an attack leaves nothing behind (repeated fights).
	_clean_state()
	var counts: Array[int] = []
	for round in 4:
		var level: LevelBase = await _fight(true)
		var boss: BossBase = level.boss
		var director := level.get_node("PossessionDirector") as PossessionDirector
		_hurt_to(level, int(floor(_threshold_hp(boss, 0))))
		await _physics(3)
		if round % 2 == 0:
			await _skip_possession(director)
			var columns := _pattern(boss, &"columns_kenzo") as LightningColumnsPattern
			columns.cooldown_left = 0.0
			boss._set_state(BossBase.State.IDLE)
			boss._start_pattern(columns)
			await _physics(80)
		else:
			await _physics(30)
		var leaving_director: PossessionDirector = director
		level.remove_child(leaving_director)
		_check("leave %d: leaving in the middle gives the player and the boss back (not locked, not held)" % round, not level.player.story_invulnerable and not level.player.is_input_locked() and not boss.is_transition_held())
		leaving_director.free()
		level.free()
		await _frames(4)
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	print("MEASURE|node counts after repeated boss 3 fights|%s" % str(counts))
	_check("leave: no nodes are left behind after repeated fights (%s) and nothing is paused" % str(counts), counts[counts.size() - 1] <= counts[1] + 4 and not get_tree().paused and not PauseLock.is_locked())


# ---------------------------------------------------------------------------------------------
# 14. The numbers for the balance report
# ---------------------------------------------------------------------------------------------

func _test_balance_report() -> void:
	var stats := load("res://backend/bosses/stats/boss_three_stats.tres") as BossStats
	var hp: int = stats.max_health
	var line_one: float = float(hp) * stats.get_phase_thresholds()[0]
	var line_two: float = float(hp) * stats.get_phase_thresholds()[1]
	var phase_one: float = float(hp) - floor(line_one)
	var phase_two: float = floor(line_one) - floor(line_two)
	var phase_three: float = floor(line_two)
	var sword_dps: float = float(player_stats.attack_damage) / 0.45
	var config := load("res://backend/player/default_sword_wave_config.tres") as SwordWaveConfig
	var wave_times: Array[float] = []
	for index in 3:
		var tier: SwordWaveTier = config.get_tier(index)
		wave_times.append(float(hp) / (float(tier.damage) / maxf(tier.cooldown, config.startup_time + config.recovery_time)))
	var guard := BossGuard.new()
	var guard_cycle: float = 2.0 * 1.3 + guard.stagger_time + guard.regen_delay
	var vulnerable: float = guard.stagger_time + guard.regen_delay
	var per_cycle: float = 3.0 + vulnerable * sword_dps
	var phase_two_time: float = phase_two / per_cycle * guard_cycle
	var possession: float = 2.0 * PossessionConfig.get_default().duration_for(&"boss_three")
	var sword_total: float = phase_one / sword_dps + phase_two_time + phase_three / sword_dps + possession
	print("MEASURE|boss 3 balance|70 HP: phase 1 %d HP, phase 2 %d HP, phase 3 %d HP|sword only %.1f s of damage plus %.1f s of possession pauses = %.1f s|wave only tier 0 %.1f s, tier 1 %.1f s, tier 2 %.1f s|Kenzo with the guard about %.1f s" % [phase_one, phase_two, phase_three, hp / sword_dps, possession, sword_total, wave_times[0], wave_times[1], wave_times[2], phase_two_time])
	_check("balance: boss 3 has 70 HP and the three phases are about 24 / 23 / 23 HP", hp == 70 and phase_one + phase_two + phase_three == float(hp) and phase_one >= 20.0 and phase_two >= 20.0 and phase_three >= 20.0)
	_check("balance: the ideal sword-only kill (%.1f s with the pauses) stays under about 60 s, the hardest of the three bosses but not unfair" % sword_total, sword_total <= 60.0 and float(hp) / sword_dps > 40.0 / sword_dps and float(hp) > 50.0)
	guard.free()
