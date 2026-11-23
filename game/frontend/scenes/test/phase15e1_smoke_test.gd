extends Node
## Smoke test for Phase 15e-1 (reduced by Phase 15j): boss 3's three phases. Bosses 1 and 2 unchanged, the two thresholds and the possession on
## each, the health bar and its marks, the bar following every hit and the duck's charge (never wasted). The floating eye, the beam, the columns,
## the never-idle sweeps, the contrast, flash and reduced-mode checks and the cancel / retry / leave tests of the old design moved to
## phase15j_smoke_test (the redesigned fight). Lines starting with
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
	await _test_old_bars_unchanged()
	await _test_charge_not_wasted()
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
		_check("%s: no phase 3 numbers, the cooldown factor is 1" % entry[0], is_equal_approx(boss.cooldown_factor(), 1.0) and boss.stats.max_idle_time >= 0.0)
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
	_check("boss 3: 102 HP (Phase 15p; phases 2 and 3 keep 23 HP) and two thresholds at 45.1% and 22.55%", stats.max_health == 102 and thresholds.size() == 2 and is_equal_approx(thresholds[0], 0.451) and is_equal_approx(thresholds[1], 0.2255)
		and stats.phase_count() == 3)
	_check("boss 3: phase 3 shortens every cooldown by 0.75 and the gaps; the telegraphs are not scaled by it", is_equal_approx(stats.phase_3_cooldown_factor, 0.75) and stats.phase_3_pattern_gap_multiplier < stats.phase_2_pattern_gap_multiplier
		and is_equal_approx(stats.speed_multiplier_for(3), 1.0) and is_equal_approx(stats.speed_multiplier_for(2), 1.0))
	_check("boss 3: it never idles longer than 1.5 s", is_equal_approx(stats.max_idle_time, 1.5))
	var by_phase: Dictionary = {}
	for pattern in _patterns_of(boss):
		if pattern.fallback_priority == 0:
			by_phase[String(pattern.pattern_id)] = [pattern.min_phase, pattern.max_phase, Array(pattern.excluded_phases)]
	_check("boss 3 (Phase 15j): the duck's swipe, charge and volley run in phases 1 and 3 (never in 2); the summoner cycle is the only attack of phase 2; no beam, no columns, no hover",
		by_phase.get("swipe") == [1, 3, [2]] and by_phase.get("charge") == [1, 3, [2]] and by_phase.get("volley") == [1, 3, [2]] and by_phase.get("summon_cycle") == [2, 2, []] and by_phase.size() == 4 and boss.get_node_or_null(^"Hover") == null)
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
	_check("boss 3: no attack of the boss does more than 1 heart (hitboxes), as the existing stats say", damage_ok)
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
	_check("bar: it shows two marks, at 45.1% and 22.55%", bar.marker_ratios.size() == 2 and is_equal_approx(bar.marker_ratios[0], 0.451) and is_equal_approx(bar.marker_ratios[1], 0.2255)
		and is_equal_approx(bar.marker_ratio, 0.451) and bar.mark_pulses.size() == 2)
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


func _bar_hp(bar: BossHealthBar, boss: BossBase) -> int:
	return int(round(bar.displayed_ratio * float(boss.health.max_health)))


func _hit_kind(boss: BossBase, kind: StringName, amount: int) -> bool:
	return boss.hurtbox.receive_hit(DamageInfo.create(amount, Vector2.ZERO, null, CombatLayers.Team.PLAYER, kind))


## The bar equals the boss health after every kind of hit in every phase (Phase 15o: boss 3 has no shell, so every hit hurts in every phase).
func _test_bar_tracks_every_hit() -> void:
	_clean_state()
	var level: LevelBase = await _fight()
	var boss: BossBase = level.boss
	var bar: BossHealthBar = level.boss_bar
	var director := level.get_node("PossessionDirector") as PossessionDirector
	var all_match: bool = true
	for entry in [[&"light", 1, true], [&"wave", 2, true], [&"heavy", 3, true], [&"light", 1, true], [&"wave", 2, true], [&"dash_slash", 2, true]]:
		var before: int = boss.health.current_health
		var applied: bool = _hit_kind(boss, entry[0], entry[1])
		all_match = all_match and applied == entry[2] and _bar_hp(bar, boss) == boss.health.current_health and (boss.health.current_health < before) == applied
	_hurt_to(level, int(floor(_threshold_hp(boss, 0))))
	await _physics(3)
	await _skip_possession(director)
	await _frames(10)
	level.player.story_invulnerable = true
	for entry in [[&"light", 1], [&"wave", 2], [&"heavy", 3], [&"dash_slash", 2]]:
		var before2: int = boss.health.current_health
		var applied2: bool = _hit_kind(boss, entry[0], entry[1])
		all_match = all_match and applied2 and _bar_hp(bar, boss) == boss.health.current_health and boss.health.current_health < before2
	_hurt_to(level, int(floor(_threshold_hp(boss, 1))))
	await _physics(3)
	await _skip_possession(director)
	await _frames(10)
	level.player.story_invulnerable = true
	for entry in [[&"light", 1], [&"wave", 2], [&"heavy", 3], [&"dash_slash", 2]]:
		var before3: int = boss.health.current_health
		var applied3: bool = _hit_kind(boss, entry[0], entry[1])
		all_match = all_match and applied3 and _bar_hp(bar, boss) == boss.health.current_health and boss.health.current_health < before3
	_check("bar: it equals the boss health after every hit type in every phase, after both possessions", all_match)
	level.player.health.kill()
	await _physics(6)
	level.player.respawn()
	await _physics(40)
	level.player.global_position = level.encounter.global_position
	await _physics(15)
	_check("bar: after a retry it starts full", boss.current_phase == 1 and _bar_hp(bar, boss) == boss.health.max_health)
	level.free()
	await _frames(2)


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
# 7. Kenzo's guard
# ---------------------------------------------------------------------------------------------

func _hit(boss: BossBase, kind: StringName, amount: int = 1) -> bool:
	return boss.hurtbox.receive_hit(DamageInfo.create(amount, Vector2.ZERO, null, CombatLayers.Team.PLAYER, kind))


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
	boss.current_phase = 1
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
	# In the summoner stage (phase 2) the duck never charges.
	boss.reset_encounter()
	boss.global_position = Vector2(6325.0, 556.0)
	boss.activate(player)
	boss.current_phase = 2
	await _physics(30)
	charge.cooldown_left = 0.0
	_check("charge: in phase 2 (the summoner stage) the charge is never eligible", not charge.can_start(boss) and not short_charge.can_start_fallback(boss, true))
	level.free()
	await _frames(2)

