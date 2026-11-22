extends Node
## Headless smoke test for Phase 15d: the possession sequence at a boss phase change. It checks the trigger (once per
## boss, at its threshold and not before), what it stops (the boss, the projectiles, the hazards) and who it locks (the
## player), the timings from the config, the persistent look and how it fades, the reduced mode, the edge cases (skip
## when the boss dies in the same hit, player death, pause, leaving the level), no leaked nodes, the readability of the
## red background (contrast) and the photosensitivity limits, plus the boss 2 tuning. Lines starting with "MEASURE|" go
## to docs/BALANCE_REPORT.md. Development only. Run:
##   <godot> --headless --path game res://frontend/scenes/test/phase15d_smoke_test.tscn
## Uses a redirected save path and a throwaway settings file; the real save and the real settings are never touched.

const TEST_SAVE: String = "user://test_save_phase15d.json"
const TEST_SETTINGS: String = "user://test_settings_phase15d.cfg"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const PROJECTILE_SCENE: PackedScene = preload("res://backend/combat/projectile.tscn")
const ENEMY_PROJECTILE_STATS: ProjectileStats = preload("res://backend/combat/stats/enemy_projectile_stats.tres")
const MIN_CONTRAST: float = 2.5
const BIOME_DIR: String = "res://frontend/levels/biome/"

var failures: int = 0
var real_save_before: String = ""
var real_settings_before: String = ""
var real_controls_before: String = ""
var config: PossessionConfig = null
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig


func _ready() -> void:
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	GameSettings.path_override = TEST_SETTINGS
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
	real_settings_before = _read_file(GameSettings.PATH)
	real_controls_before = _read_file(ControlsConfig.DEFAULT_PATH)
	config = PossessionConfig.get_default()
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


func _set_effects(on: bool) -> void:
	var values: Dictionary = GameSettings.DEFAULTS.duplicate()
	values["corruption_effects"] = on
	GameSettings.save_settings(values)


func _run() -> void:
	_clean_state()
	_test_config_and_guards()
	await _test_trigger_per_boss()
	await _test_world_stopped()
	await _test_timing_and_release()
	await _test_persistent_look()
	await _test_reduced_mode()
	await _test_edge_cases()
	await _test_bar()
	await _test_leaks()
	_test_readability()
	_test_boss_two_tuning()
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
	var level := (load("res://frontend/levels/level_%d.tscn" % number) as PackedScene).instantiate() as LevelBase
	(level.get_node("PossessionDirector") as PossessionDirector).play_when_headless = true
	return level


## A boss fight: the level open, the boss awake against the player in the arena.
func _fight(number: int) -> LevelBase:
	var level: LevelBase = _level(number)
	add_child(level)
	await _frames(8)
	level.player.global_position = level.encounter.global_position
	await _physics(10)
	return level


func _director(level: LevelBase) -> PossessionDirector:
	return level.get_node("PossessionDirector") as PossessionDirector


## The health at which the boss crosses its line is `max * ratio`; this damages it to exactly `above` points over it.
func _hurt_boss_to(level: LevelBase, remaining: int) -> void:
	var boss: BossBase = level.boss
	var amount: int = boss.health.current_health - remaining
	if amount > 0:
		boss.health.apply_damage(DamageInfo.create(amount, Vector2.ZERO, level.player, CombatLayers.Team.PLAYER))


func _threshold_of(boss: BossBase) -> float:
	return float(boss.health.max_health) * boss.stats.phase_2_health_ratio


func _enemy_projectile(parent: Node, at: Vector2) -> Projectile:
	var projectile := PROJECTILE_SCENE.instantiate() as Projectile
	parent.add_child(projectile)
	projectile.global_position = at
	projectile.launch(Vector2.LEFT, CombatLayers.Team.ENEMY, ENEMY_PROJECTILE_STATS, null)
	return projectile


# ---------------------------------------------------------------------------------------------
# Config and guards
# ---------------------------------------------------------------------------------------------

func _test_config_and_guards() -> void:
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
	_check("config: the sequence lasts 3.0 s by default, within 2.5 to 4.0 s; the reduced freeze is 1.0 s", is_equal_approx(config.duration, 3.0)
		and config.duration >= PossessionConfig.MIN_DURATION and config.duration <= PossessionConfig.MAX_DURATION and is_equal_approx(config.reduced_freeze, 1.0))
	var custom := PossessionConfig.new()
	var override := PossessionOverride.new()
	override.boss_id = &"boss_two"
	override.duration = 3.6
	override.color = Color(0.2, 0.9, 0.3, 1.0)
	custom.overrides = [override]
	_check("config: a per-boss override changes the duration and the color of that boss only",
		is_equal_approx(custom.duration_for(&"boss_two"), 3.6) and is_equal_approx(custom.duration_for(&"boss_three"), custom.duration)
		and custom.color_for(&"boss_two").is_equal_approx(Color(0.2, 0.9, 0.3, 1.0)) and custom.color_for(&"boss_three").is_equal_approx(Color(custom.color, 1.0)))
	override.duration = 9.0
	_check("config: an override longer than 4 s is clamped to the allowed range", is_equal_approx(custom.duration_for(&"boss_two"), PossessionConfig.MAX_DURATION))
	_check("config: no flash faster than 3 per second (%d in the busiest second), flash alpha capped at %.2f" % [config.max_flashes_in_a_second(), config.flash_alpha_cap],
		config.max_flashes_in_a_second() <= PossessionConfig.MAX_FLASHES_PER_SECOND and config.flash_alpha_cap <= 0.5)
	var spacing_ok: bool = true
	for i in range(1, config.flash_times.size()):
		spacing_ok = spacing_ok and config.flash_times[i] - config.flash_times[i - 1] >= 1.0 / float(PossessionConfig.MAX_FLASHES_PER_SECOND)
	_check("config: consecutive flashes are at least a third of a second apart and the flash color is red (never white)", spacing_ok
		and config.flash_color.r > config.flash_color.g * 2.0 and config.flash_color.r > config.flash_color.b * 2.0)
	_check("config: the pulses of the glow and the vignette are slow (<= 2.5 Hz)", config.pulse_hz <= 2.5 and config.vignette_pulse_hz <= 2.5)
	_check("config: the bar mid-line pulses slowly too (%.1f Hz)" % BossHealthBar.MARKER_PULSE_HZ, BossHealthBar.MARKER_PULSE_HZ <= 2.5)


# ---------------------------------------------------------------------------------------------
# 1. The trigger, once per boss, at its threshold and not before
# ---------------------------------------------------------------------------------------------

func _test_trigger_per_boss() -> void:
	for number in [1, 2, 3]:
		_clean_state()
		var level: LevelBase = await _fight(number)
		var boss: BossBase = level.boss
		var director: PossessionDirector = _director(level)
		var threshold: float = _threshold_of(boss)
		var just_above: int = int(floor(threshold)) + 1
		_hurt_boss_to(level, just_above)
		await _physics(4)
		_check("boss %d: just above its line (%d of %d) the sequence does not start" % [number, just_above, boss.health.max_health], director.sequences_started == 0 and not director.active
			and boss.state != BossBase.State.PHASE_TRANSITION and boss.current_phase == 1)
		_hurt_boss_to(level, just_above - 1)
		await _physics(4)
		_check("boss %d: crossing the line starts the sequence at once" % number, director.sequences_started == 1 and director.active and boss.state == BossBase.State.PHASE_TRANSITION)
		_check("boss %d: the boss is held in its transition and stays in phase 1 while it plays" % number, boss.is_transition_held() and boss.current_phase == 1)
		await _skip_to_end(director)
		await _physics(6)
		_check("boss %d: phase 2 begins after the sequence" % number, boss.current_phase == 2 and not director.active and director.persistent)
		# It never plays a second time in the same fight.
		boss.health.apply_damage(DamageInfo.create(1, Vector2.ZERO, level.player, CombatLayers.Team.PLAYER))
		await _physics(6)
		_check("boss %d: it happens exactly once per fight" % number, director.sequences_started == 1)
		level.free()
		await _frames(2)


## Jumps the running sequence to its end (the tests do not wait three real seconds each time), then waits out the rest
## of the boss own transition time (1.5 s), which starts counting at the same moment: phase 2 begins after both.
func _skip_to_end(director: PossessionDirector) -> void:
	var guard: int = 0
	while director.active and guard < 60 * 8:
		director.elapsed = maxf(director.elapsed, director.duration - 0.02)
		await get_tree().process_frame
		guard += 1
	await _physics(100)


# ---------------------------------------------------------------------------------------------
# 1b. What stops and who is locked
# ---------------------------------------------------------------------------------------------

func _test_world_stopped() -> void:
	_clean_state()
	var level: LevelBase = await _fight(2)
	var boss: BossBase = level.boss
	var director: PossessionDirector = _director(level)
	var player: Player = level.player
	var hazard := level.get_node("Content/FloorHazard") as FloorHazard
	# Something in the air, a hazard running and a pattern in progress.
	var hostile: Projectile = _enemy_projectile(level, boss.global_position + Vector2(-80.0, -20.0))
	var friendly := PROJECTILE_SCENE.instantiate() as Projectile
	level.add_child(friendly)
	friendly.global_position = player.global_position + Vector2(100.0, -40.0)
	friendly.launch(Vector2.RIGHT, CombatLayers.Team.PLAYER, ENEMY_PROJECTILE_STATS, player)
	hazard.start()
	var cooldown_marks: Array[float] = []
	for pattern in boss.patterns:
		pattern.cooldown_left = 3.0
	_check("before: the player is free and vulnerable", not player.is_input_locked() and not player.story_invulnerable)
	_hurt_boss_to(level, int(floor(_threshold_of(boss))))
	await _physics(5)
	_check("sequence: the boss is invulnerable and its patterns are cancelled", director.active and boss.health.is_invulnerable() and boss.current_pattern == null and boss.state == BossBase.State.PHASE_TRANSITION)
	var hp: int = boss.health.current_health
	var hit: bool = boss.hurtbox.receive_hit(DamageInfo.create(5, Vector2.ZERO, player, CombatLayers.Team.PLAYER))
	await _physics(2)
	_check("sequence: a hit on the boss does nothing, however late into the sequence", not hit and boss.health.current_health == hp)
	_check("sequence: enemy projectiles in the air are cleared and the player's own stay", not is_instance_valid(hostile) or hostile.is_queued_for_deletion())
	_check("sequence: the player's own projectiles are not cleared", is_instance_valid(friendly) and not friendly.is_queued_for_deletion())
	_check("sequence: the boss-driven hazard is stopped", not hazard.running and hazard.state == FloorHazard.State.IDLE)
	_check("sequence: the player is input-locked and invulnerable (story_invulnerable)", player.is_input_locked() and player.story_invulnerable and player.is_invulnerable())
	var hit_player: bool = player.hurtbox.receive_hit(DamageInfo.create(1, Vector2.ZERO, null, CombatLayers.Team.ENEMY))
	_check("sequence: nothing can hurt the player", not hit_player)
	# The cooldowns of the boss do not advance while the sequence plays.
	await _physics(30)
	var frozen: bool = true
	for pattern in boss.patterns:
		frozen = frozen and is_equal_approx(pattern.cooldown_left, 3.0)
	_check("sequence: the pattern cooldowns of the boss do not advance", frozen)
	_check("sequence: the boss spikes have not started during it", not hazard.running)
	# Spikes start only after it.
	await _skip_to_end(director)
	await _physics(6)
	_check("after: boss 2 enters phase 2 and ITS spikes start only now", boss.current_phase == 2 and hazard.running and hazard.state == FloorHazard.State.WARNING)
	_check("after: the player is fully released (unlocked, vulnerable, music duck gone)", not player.is_input_locked() and not player.story_invulnerable and not player.is_invulnerable())
	var after_hit: bool = player.hurtbox.receive_hit(DamageInfo.create(1, Vector2.ZERO, null, CombatLayers.Team.ENEMY))
	_check("after: the player can be hurt again", after_hit)
	level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 2. Timing
# ---------------------------------------------------------------------------------------------

func _test_timing_and_release() -> void:
	_clean_state()
	var level: LevelBase = await _fight(1)
	var boss: BossBase = level.boss
	var director: PossessionDirector = _director(level)
	Engine.time_scale = 8.0
	_hurt_boss_to(level, int(floor(_threshold_of(boss))))
	await _physics(2)
	var expected: float = config.duration_for(boss.stats.boss_id)
	_check("timing: the duration is the one of the config (%.1f s)" % director.duration, is_equal_approx(director.duration, expected) and not director.reduced)
	var game_seconds: float = 0.0
	var counted: int = 0
	while director.active and counted < 60 * 20:
		await get_tree().process_frame
		game_seconds += get_process_delta_time()
		counted += 1
	Engine.time_scale = 1.0
	_check("timing: the sequence really lasts the configured time (%.2f s of game time for %.1f s)" % [game_seconds, expected], absf(game_seconds - expected) < 0.3)
	_check("timing: flashes and shake kicks fired as configured (%d flashes, %d kicks)" % [director.flashes_fired, director.kicks_made],
		director.flashes_fired == config.flash_times.size() and director.kicks_made == config.shake_times.size())
	level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 2b. The persistent look
# ---------------------------------------------------------------------------------------------

func _look_state(level: LevelBase) -> Dictionary:
	var director: PossessionDirector = _director(level)
	var backdrop := level.get_node("Backdrop") as Backdrop
	var glow: float = director.glow_amount
	var rise: float = director.rise_amount
	if is_instance_valid(level.boss):
		var visual: Node = level.boss.get_node("Visual")
		var rig: DuckRig = visual.get("rig") as DuckRig
		glow = rig.possession if rig != null else -1.0
		rise = float(visual.get("possession_rise"))
	return {"glow": glow, "grade": backdrop.possession_grade, "layer": director.get_node_or_null("PossessionLayer"), "rise": rise}


func _test_persistent_look() -> void:
	_clean_state()
	var level: LevelBase = await _fight(1)
	var boss: BossBase = level.boss
	var director: PossessionDirector = _director(level)
	var backdrop := level.get_node("Backdrop") as Backdrop
	var neutral_grade: Color = backdrop.grade
	_hurt_boss_to(level, int(floor(_threshold_of(boss))))
	await _physics(3)
	await get_tree().create_timer(0.5).timeout
	var mid: Dictionary = _look_state(level)
	_check("look: during the sequence the boss rises, glows red and the backdrop turns red",
		float(mid["glow"]) > 0.2 and float(mid["rise"]) > 0.1 and (mid["grade"] as Color).g < 0.95 and mid["layer"] != null)
	# The red composes with the Phase 14c profile look instead of replacing it.
	var effective: Color = backdrop.get_effective_grade()
	_check("look: the red is a second multiplier over the profile grade (the profile grade is untouched)", backdrop.grade.is_equal_approx(neutral_grade)
		and absf(effective.r - neutral_grade.r * backdrop.possession_grade.r) < 0.001 and absf(effective.g - neutral_grade.g * backdrop.possession_grade.g) < 0.001)
	await _skip_to_end(director)
	await _frames(4)
	var after: Dictionary = _look_state(level)
	_check("look: afterwards the boss keeps a red glow (%.2f) and the background a subtle red tint (g %.2f)" % [float(after["glow"]), (after["grade"] as Color).g],
		director.persistent and absf(float(after["glow"]) - config.persistent_glow) < 0.05 and (after["grade"] as Color).g < 0.97
		and absf((after["grade"] as Color).g - lerpf(1.0, config.sky_tint.g, config.persistent_sky)) < 0.03)
	_check("look: the boss is back on the ground after the sequence (rise 0)", float(after["rise"]) < 0.01)
	# Fades on death.
	boss.health.kill()
	await _physics(2)
	_check("look: when the boss dies the persistent look starts to fade", not director.persistent and director.glow_amount <= config.persistent_glow)
	await get_tree().create_timer(config.fade_out_time + 0.4).timeout
	var gone: Dictionary = _look_state(level)
	_check("look: after the fade the glow, the tint and the overlay are gone", is_zero_approx(director.glow_amount) and (gone["grade"] as Color).is_equal_approx(Color.WHITE) and gone["layer"] == null)
	level.free()
	await _frames(2)
	# Fades when the fight is cancelled (the player dies, the encounter is reset).
	_clean_state()
	var cancel_level: LevelBase = await _fight(1)
	var cancel_director: PossessionDirector = _director(cancel_level)
	_hurt_boss_to(cancel_level, int(floor(_threshold_of(cancel_level.boss))))
	await _physics(3)
	await _skip_to_end(cancel_director)
	await _physics(3)
	var persistent_before: bool = cancel_director.persistent
	# The player steps out of the arena trigger and the encounter is cancelled (as after a retry).
	cancel_level.player.global_position = cancel_level.get_node("SpawnPoint").global_position
	await _physics(10)
	cancel_level.encounter.reset()
	await _physics(2)
	_check("look: a cancelled fight starts the fade of the persistent look", persistent_before and not cancel_director.persistent)
	await get_tree().create_timer(config.fade_out_time + 0.4).timeout
	var cancel_gone: Dictionary = _look_state(cancel_level)
	_check("look: after a cancelled fight everything is clean", is_zero_approx(cancel_director.glow_amount) and (cancel_gone["grade"] as Color).is_equal_approx(Color.WHITE))
	# A retry starts from phase 1 with a clean state and the sequence can play again.
	cancel_level.player.global_position = cancel_level.encounter.global_position
	await _physics(10)
	_hurt_boss_to(cancel_level, int(floor(_threshold_of(cancel_level.boss))))
	await _physics(3)
	_check("retry: a retried fight starts clean in phase 1 and the sequence plays again", cancel_director.sequences_started == 2 and cancel_director.active)
	await _skip_to_end(cancel_director)
	cancel_level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 4. Reduced mode
# ---------------------------------------------------------------------------------------------

func _test_reduced_mode() -> void:
	_clean_state()
	_set_effects(false)
	var level: LevelBase = await _fight(2)
	var boss: BossBase = level.boss
	var director: PossessionDirector = _director(level)
	var player: Player = level.player
	_hurt_boss_to(level, int(floor(_threshold_of(boss))))
	await _physics(3)
	await _frames(10)
	_check("reduced: with the option off the sequence is a short freeze (%.1f s)" % director.duration, director.active and director.reduced and is_equal_approx(director.duration, config.reduced_freeze))
	var look: Dictionary = _look_state(level)
	_check("reduced: no screen tint, no vignette, no flash and no overlay", is_zero_approx(director.sky_amount) and is_zero_approx(director.vignette_amount) and is_zero_approx(director.flash_amount)
		and (look["grade"] as Color).is_equal_approx(Color.WHITE) and look["layer"] == null)
	_check("reduced: the boss pose changes (it rises and glows) and the player is held as always", float(look["glow"]) > 0.0 and float(look["rise"]) > 0.0 and player.is_input_locked() and player.story_invulnerable)
	_check("reduced: no camera shake is requested", director.kicks_made == 0)
	await _skip_to_end(director)
	await _physics(6)
	_check("reduced: it ends, unlocks the player and phase 2 begins", not director.active and not player.is_input_locked() and not player.story_invulnerable and boss.current_phase == 2)
	var after: Dictionary = _look_state(level)
	_check("reduced: afterwards only the boss glows (no background tint)", float(after["glow"]) > 0.0 and (after["grade"] as Color).is_equal_approx(Color.WHITE) and after["layer"] == null)
	level.free()
	await _frames(2)
	_set_effects(true)


# ---------------------------------------------------------------------------------------------
# 6. Edge cases
# ---------------------------------------------------------------------------------------------

func _test_edge_cases() -> void:
	# The boss would die in the same hit that crosses the line: no sequence.
	_clean_state()
	var level: LevelBase = await _fight(1)
	var director: PossessionDirector = _director(level)
	var boss: BossBase = level.boss
	boss.health.apply_damage(DamageInfo.create(boss.health.current_health + 5, Vector2.ZERO, level.player, CombatLayers.Team.PLAYER))
	await _physics(4)
	_check("edge: if the same hit kills the boss the sequence is skipped", director.sequences_started == 0 and not director.active and boss.state == BossBase.State.DEAD and not level.player.story_invulnerable)
	level.free()
	await _frames(2)
	# The player dies during the sequence (a kill zone, say).
	_clean_state()
	var die_level: LevelBase = await _fight(2)
	var die_director: PossessionDirector = _director(die_level)
	_hurt_boss_to(die_level, int(floor(_threshold_of(die_level.boss))))
	await _physics(4)
	var was_active: bool = die_director.active
	die_level.player.health.kill()
	await _physics(3)
	_check("edge: if the player dies during the sequence it is cancelled and the boss resets", was_active and not die_director.active and die_level.boss.state == BossBase.State.INACTIVE and not die_level.boss.is_transition_held())
	_check("edge: the player is never left locked or invulnerable after dying in it", not die_level.player.story_invulnerable)
	die_level.player.respawn()
	await _physics(30)
	_check("edge: after respawning the player is free", not die_level.player.is_input_locked() and not die_level.player.story_invulnerable)
	var hazard := die_level.get_node("Content/FloorHazard") as FloorHazard
	_check("edge: the spikes did not start from a cancelled sequence", not hazard.running)
	die_level.free()
	await _frames(2)
	# Pausing: the sequence stands still and resumes.
	_clean_state()
	var pause_level: LevelBase = await _fight(1)
	var pause_director: PossessionDirector = _director(pause_level)
	_hurt_boss_to(pause_level, int(floor(_threshold_of(pause_level.boss))))
	await _physics(3)
	await _frames(10)
	get_tree().paused = true
	var frozen_at: float = pause_director.elapsed
	await get_tree().create_timer(0.4, true, false, true).timeout
	_check("edge: pausing freezes the sequence (it does not advance while paused)", is_equal_approx(pause_director.elapsed, frozen_at) and pause_director.active)
	get_tree().paused = false
	await _frames(10)
	_check("edge: and it carries on after resuming", pause_director.elapsed > frozen_at and pause_director.active)
	await _skip_to_end(pause_director)
	_check("edge: it still ends and releases the player after a pause", not pause_director.active and not pause_level.player.story_invulnerable and not pause_level.player.is_input_locked())
	pause_level.free()
	await _frames(2)
	# Leaving the level in the middle of it.
	_clean_state()
	var leave_level: LevelBase = await _fight(2)
	var leave_player: Player = leave_level.player
	var leave_boss: BossBase = leave_level.boss
	_hurt_boss_to(leave_level, int(floor(_threshold_of(leave_boss))))
	await _physics(4)
	_check("edge: (setup) the sequence is running", _director(leave_level).active and leave_player.story_invulnerable)
	# Leaving the level removes the director from the tree first: it must give everything back as it goes.
	var leaving_director: PossessionDirector = _director(leave_level)
	leave_level.remove_child(leaving_director)
	_check("edge: leaving the level in the middle leaves nobody locked or invulnerable and the boss is not held", not leave_player.story_invulnerable and not leave_player.is_input_locked()
		and not leave_boss.is_transition_held())
	leaving_director.free()
	leave_level.free()
	await _frames(3)
	_check("edge: nothing is left paused or holding the pause after leaving", not get_tree().paused and not PauseLock.is_locked())
	# Headless runs complete it instantly (no hold) unless the flag is set.
	_clean_state()
	var quiet := (load("res://frontend/levels/level_1.tscn") as PackedScene).instantiate() as LevelBase
	add_child(quiet)
	await _frames(8)
	quiet.player.global_position = quiet.encounter.global_position
	await _physics(10)
	_hurt_boss_to(quiet, int(floor(_threshold_of(quiet.boss))))
	await _physics(4)
	_check("headless: by default no sequence is held (the old behaviour: the roar of 1.5 s and then phase 2)", _director(quiet).sequences_started == 0 and not quiet.boss.is_transition_held()
		and quiet.boss.state == BossBase.State.PHASE_TRANSITION)
	await _physics(120)
	_check("headless: and phase 2 begins after the normal transition time", quiet.boss.current_phase == 2)
	quiet.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 5. The boss bar
# ---------------------------------------------------------------------------------------------

func _test_bar() -> void:
	_clean_state()
	var level: LevelBase = await _fight(1)
	var bar: BossHealthBar = level.boss_bar
	var director: PossessionDirector = _director(level)
	_check("bar: it starts normal (purple, no pulse)", not bar.possessed and is_zero_approx(bar.possession_k) and is_zero_approx(bar.marker_pulse_left))
	_hurt_boss_to(level, int(floor(_threshold_of(level.boss))))
	await _physics(3)
	await _frames(5)
	_check("bar: when the line is crossed its mid-line pulses", bar.marker_pulse_left > 0.0)
	await _skip_to_end(director)
	await _frames(60)
	_check("bar: in phase 2 the bar has a persistent possessed tint", bar.possessed and bar.possession_k > 0.9)
	level.boss.health.kill()
	await _frames(4)
	_check("bar: the tint goes away with the boss", not bar.possessed and is_zero_approx(bar.possession_k))
	level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# Leaks
# ---------------------------------------------------------------------------------------------

func _test_leaks() -> void:
	_clean_state()
	var counts: Array[int] = []
	for round in 5:
		var level: LevelBase = await _fight(2)
		var director: PossessionDirector = _director(level)
		_hurt_boss_to(level, int(floor(_threshold_of(level.boss))))
		await _physics(3)
		if round % 2 == 0:
			await _skip_to_end(director)
			await _physics(30)
		else:
			level.player.health.kill()
			await _physics(10)
		level.free()
		await _frames(4)
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	print("MEASURE|node counts after repeated possession sequences|%s" % str(counts))
	_check("leaks: no nodes are left behind after repeated sequences, finished or cancelled (%s)" % str(counts), counts[counts.size() - 1] <= counts[1] + 4)
	_check("leaks: nothing is left paused or locked", not get_tree().paused and not PauseLock.is_locked())


# ---------------------------------------------------------------------------------------------
# 3. Readability
# ---------------------------------------------------------------------------------------------

func _channel(value: float) -> float:
	return value / 12.92 if value <= 0.03928 else pow((value + 0.055) / 1.055, 2.4)


func _luminance(color: Color) -> float:
	return 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b)


func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## Over a backdrop tinted by the possession (the profile look times the possession tint) the things the player must read
## keep the contrast of Phases 14e / 14f (best of the color and its dark outline, >= 2.5).
func _test_readability() -> void:
	var presentation := load("res://frontend/presentation/default_profile_presentation.tres") as ProfilePresentation
	var set_resource := TelegraphSet.get_default()
	var foreground: Array = []
	for kind in TelegraphSet.KINDS:
		var style: TelegraphStyle = set_resource.get_style(kind)
		foreground.append(["telegraph " + String(kind), style.color, style.outline_color])
	foreground.append(["spike warning", FloorHazardArt.GLOW, FloorHazardArt.OUTLINE])
	foreground.append(["spike body", FloorHazardArt.SPIKE, FloorHazardArt.OUTLINE])
	var enemy_stats := load("res://backend/combat/stats/enemy_projectile_stats.tres") as ProjectileStats
	foreground.append(["enemy projectile", enemy_stats.tint if "tint" in enemy_stats else Color(1.0, 0.5, 0.3), Color(0.106, 0.098, 0.122)])
	foreground.append(["the duck's body", Color(0.98, 0.93, 0.8), Color(0.106, 0.098, 0.122)])
	var worst_overall: float = 99.0
	var worst_name: String = ""
	var per_biome: Array = []
	var biomes: Array[Biome] = []
	for number in [1, 2, 3]:
		var level_scene := (load("res://frontend/levels/level_%d.tscn" % number) as PackedScene).instantiate()
		var candidates: Array[Node] = [level_scene]
		candidates.append_array(level_scene.find_children("*", "", true, false))
		for node in candidates:
			var value: Variant = node.get(&"biome")
			if value is Biome and not biomes.has(value):
				biomes.append(value as Biome)
		level_scene.free()
	for biome in biomes:
		var scenery: Array[Color] = [biome.sky_top, biome.sky_bottom, biome.haze, biome.far_color, biome.mid_color, biome.near_color]
		var ground: Array[Color] = [biome.grass, biome.grass_dark, biome.soil, biome.soil_dark, biome.rock, biome.rock_dark]
		var worst_here: float = 99.0
		for profile in ["neutral", "compassionate", "corrupt"]:
			var tint: Color = presentation.get_look(profile).background_tint
			for amount in [config.persistent_sky, 1.0]:
				var possession: Color = Color.WHITE.lerp(config.sky_tint, amount)
				for color in scenery:
					var shown := Color(clampf(color.r * tint.r * possession.r, 0.0, 1.0), clampf(color.g * tint.g * possession.g, 0.0, 1.0), clampf(color.b * tint.b * possession.b, 0.0, 1.0))
					for entry in foreground:
						var value: float = maxf(_contrast(entry[1], shown), _contrast(entry[2], shown))
						if value < worst_here:
							worst_here = value
						if value < worst_overall:
							worst_overall = value
							worst_name = "%s over %s" % [entry[0], biome.resource_path.get_file()]
		# The play field is never tinted: its colors are unchanged, so the ground keeps its own contrast.
		for color in ground:
			for entry in foreground:
				worst_here = minf(worst_here, maxf(_contrast(entry[1], color), _contrast(entry[2], color)))
		per_biome.append([biome.resource_path.get_file(), worst_here])
	for entry in per_biome:
		print("MEASURE|possession contrast|%s|worst %.2f|threshold %.1f" % [entry[0], entry[1], MIN_CONTRAST])
	print("MEASURE|possession contrast overall|worst %.2f (%s)" % [worst_overall, worst_name])
	_check("readability: ground, hazards, projectiles, telegraphs and the player keep >= %.1f over the possessed background in the %d biomes of the three levels (worst %.2f: %s)" % [MIN_CONTRAST, per_biome.size(), worst_overall, worst_name],
		per_biome.size() >= 3 and worst_overall >= MIN_CONTRAST)
	var vignette_dark: float = config.vignette_peak
	_check("readability: the vignette and the flash never cover the whole screen (peak vignette %.2f, flash cap %.2f)" % [vignette_dark, config.flash_alpha_cap], vignette_dark <= 0.7 and config.flash_alpha_cap <= 0.35)


# ---------------------------------------------------------------------------------------------
# 7. Boss 2 tuning and nothing else changed
# ---------------------------------------------------------------------------------------------

func _test_boss_two_tuning() -> void:
	var boss := (load("res://backend/bosses/boss_two.tscn") as PackedScene).instantiate() as BossBase
	var light := boss.get_node("Patterns/LeapLight") as LeapPattern
	var strong := boss.get_node("Patterns/Leap") as LeapPattern
	_check("tuning: the phase 2 leap weight is 1.2 (was 1.8) and the cooldowns are 7 s and 8 s (were 5 s and 6 s)",
		is_equal_approx(strong.weight, 1.2) and is_equal_approx(strong.cooldown, 7.0) and is_equal_approx(light.cooldown, 8.0))
	_check("tuning: the phase 1 leap weight (0.6) and the leap timings are unchanged", is_equal_approx(light.weight, 0.6) and is_equal_approx(light.telegraph_time, 0.7)
		and is_equal_approx(light.recovery_time, 0.8) and is_equal_approx(strong.telegraph_time, 0.7) and is_equal_approx(strong.recovery_time, 0.8))
	var hazard := FloorHazardConfig.get_default()
	_check("tuning: the spikes (1.2 s warning, 3.0 s active, 4.0 s rest) and the pad launch are unchanged", is_equal_approx(hazard.warning_time, 1.2) and is_equal_approx(hazard.active_time, 3.0)
		and is_equal_approx(hazard.rest_time, 4.0) and is_equal_approx(BounceConfig.get_default().launch_velocity, -1030.0))
	var stats: BossStats = boss.stats
	_check("tuning: boss 2 HP is 50 (Phase 15d-bis, was 60); threshold and armor timings are unchanged (55%, 1.5 s, x1.35, x0.55, 1.1 s)", stats.max_health == 50 and is_equal_approx(stats.phase_2_health_ratio, 0.55)
		and is_equal_approx(stats.phase_transition_time, 1.5) and is_equal_approx(stats.phase_2_speed_multiplier, 1.35) and is_equal_approx(stats.phase_2_pattern_gap_multiplier, 0.55)
		and is_equal_approx(stats.pattern_gap_time, 1.1))
	var swipe := boss.get_node("Patterns/Swipe") as BossPattern
	var charge := boss.get_node("Patterns/Charge") as ChargePattern
	var volley := boss.get_node("Patterns/Volley") as ProjectileVolleyPattern
	_check("tuning: the old patterns of boss 2 keep their numbers", is_equal_approx(swipe.weight, 0.8) and is_equal_approx(swipe.cooldown, 1.8) and is_equal_approx(charge.weight, 2.0)
		and is_equal_approx(charge.cooldown, 2.2) and is_equal_approx(charge.charge_speed, 560.0) and is_equal_approx(volley.weight, 0.7) and is_equal_approx(volley.cooldown, 5.0))
	for path in ["res://backend/bosses/placeholder_boss.tscn", "res://backend/bosses/boss_three.tscn"]:
		var other := (load(path) as PackedScene).instantiate() as BossBase
		# Boss 3 was redesigned in Phase 15e-1: 70 HP and its first line at 66.7%.
		var expected_health: int = 40 if path.contains("placeholder") else 70
		var expected_ratio: float = 0.5 if path.contains("placeholder") else 0.667
		_check("tuning: %s keeps its health and threshold" % path.get_file(), other.stats.max_health == expected_health and is_equal_approx(other.stats.phase_2_health_ratio, expected_ratio))
		other.free()
	boss.free()
