extends Node
## Smoke test for Phase 16a: the local AI Director. Telemetry (counts and categories), deterministic themes, the local planner,
## the plan validator, the plan applied at level load (extra enemies and boss pattern weights), the debug override, the cache across
## a retry and the guards (seven save keys, three autoloads, real save untouched). No network, no remote AI. Development only.
## Run (alone, a minute or two): <godot> --headless --path game res://frontend/scenes/test/phase16a_smoke_test.tscn
## Uses a redirected save path; the real save, settings and controls are never touched. Times are game time.

const TEST_SAVE: String = "user://test_save_phase16a.json"
const TEST_SETTINGS: String = "user://test_settings_phase16a.cfg"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const LEVELS: Dictionary = {
	1: "res://frontend/levels/level_1.tscn",
	2: "res://frontend/levels/level_2.tscn",
	3: "res://frontend/levels/level_3.tscn",
}
const BOSSES: Dictionary = {
	1: "res://backend/bosses/placeholder_boss.tscn",
	2: "res://backend/bosses/boss_two.tscn",
	3: "res://backend/bosses/boss_three.tscn",
}
const PROFILES: Array[String] = ["compassionate", "neutral", "corrupt"]

var failures: int = 0
var real_save_before: String = ""
var real_settings_before: String = ""
var real_controls_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig
var config: TelemetryConfig = TelemetryConfig.get_default()


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
	GameState.director.clear_overrides()
	GameState.director.simulate_release = false
	GameState.autosave_enabled = false
	AbilityCard.forget_all()
	BossDialogue.forget_all()
	GameSettings.save_settings(GameSettings.DEFAULTS.duplicate())


func _run() -> void:
	_clean_state()
	_test_guards()
	_test_telemetry_counts()
	_test_telemetry_sources()
	_test_themes()
	_test_planner()
	_test_validator()
	await _test_observer_in_level()
	await _test_level_one_and_no_telemetry_are_neutral()
	await _test_struggling_and_comfortable_levels()
	await _test_extras_grid()
	await _test_boss_weights()
	await _test_bosses_neutral_unchanged()
	await _test_debug_override()
	await _test_cache_across_retry()
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

func _summary(overrides: Dictionary = {}) -> Dictionary:
	var summary: Dictionary = {}
	for metric in RunTelemetry.METRICS:
		summary[metric] = "low"
	for key: Variant in overrides.keys():
		summary[String(key)] = overrides[key]
	return summary


func _load_level(level_number: int, profile: String = "neutral") -> LevelBase:
	GameState.set_adaptive_profile(profile)
	var level := (load(LEVELS[level_number]) as PackedScene).instantiate() as LevelBase
	add_child(level)
	await _frames(3)
	return level


func _free_level(level: LevelBase) -> void:
	level.free()
	await _frames(2)


## Paths of the variant groups whose node is still in the level.
func _extras_left(level: LevelBase) -> Array[NodePath]:
	var left: Array[NodePath] = []
	for group_id: Variant in level.variant_groups.keys():
		for raw_path: Variant in level.variant_groups[group_id] as Array:
			if level.get_node_or_null(NodePath(raw_path)) != null:
				left.append(NodePath(raw_path))
	return left


func _rotation_ids(boss_number: int) -> PackedStringArray:
	var boss := (load(BOSSES[boss_number]) as PackedScene).instantiate() as BossBase
	var ids := PackedStringArray()
	for child in boss.get_node("Patterns").get_children():
		if child is BossPattern and (child as BossPattern).fallback_priority == 0 and (child as BossPattern).weight > 0.0:
			ids.append(String((child as BossPattern).pattern_id))
	boss.free()
	return ids


func _scene_weights(boss_number: int) -> Dictionary:
	var boss := (load(BOSSES[boss_number]) as PackedScene).instantiate() as BossBase
	var weights: Dictionary = {}
	for child in boss.get_node("Patterns").get_children():
		if child is BossPattern:
			weights[String((child as BossPattern).pattern_id)] = (child as BossPattern).weight
	boss.free()
	return weights


func _boss_weights(boss: BossBase) -> Dictionary:
	var weights: Dictionary = {}
	for pattern in boss.patterns:
		weights[String(pattern.pattern_id)] = pattern.weight
	return weights


func _seed(level_number: int, metrics: Dictionary, worst: String = "") -> void:
	for metric: Variant in metrics.keys():
		GameState.director.telemetry.add(level_number, String(metric), float(metrics[metric]))
	if not worst.is_empty():
		GameState.director.telemetry.add_pattern_damage(level_number, worst, 5.0)


# ---------------------------------------------------------------------------------------------
# Guards
# ---------------------------------------------------------------------------------------------

func _test_guards() -> void:
	var keys: Array = GameState.to_dict().keys()
	keys.sort()
	var expected: Array = SAVE_KEYS.duplicate()
	expected.sort()
	_check("save: still exactly the seven keys (the telemetry and the plans are not saved)", keys == expected, str(keys))
	var autoloads: PackedStringArray = PackedStringArray()
	for property in ProjectSettings.get_property_list():
		var property_name: String = property["name"]
		if property_name.begins_with("autoload/"):
			autoloads.append(property_name.trim_prefix("autoload/"))
	autoloads.sort()
	_check("autoloads: exactly GameState, SceneManager and AudioDirector", autoloads == PackedStringArray(["AudioDirector", "GameState", "SceneManager"]), str(autoloads))
	var director_value: Variant = GameState.director
	_check("director: it is a plain object field of GameState, not a node", director_value is RefCounted and not director_value is Node)


# ---------------------------------------------------------------------------------------------
# 1. Telemetry
# ---------------------------------------------------------------------------------------------

func _test_telemetry_counts() -> void:
	var telemetry := RunTelemetry.new()
	for i in 3:
		telemetry.add(2, "deaths")
	telemetry.add(2, "dash_use", 12.0)
	telemetry.add(2, "double_jump_use", 4.0)
	telemetry.add(2, "heals")
	telemetry.add(2, "kills", 6.0)
	telemetry.add(2, "time_in_level", 100.5)
	telemetry.add(2, "time_in_boss", 31.0)
	telemetry.add(2, "low_health_time", 12.0)
	for kind in [&"light", &"light", &"heavy", &"dash_slash", &"wave", &"wave", &"wave", &"unknown"]:
		telemetry.add_weapon(2, kind)
	telemetry.add(2, "nonsense", 5.0)
	telemetry.add(2, "deaths", -3.0)
	telemetry.add(2, "deaths", NAN)
	_check("telemetry: scripted events add up by level and metric", telemetry.get_value(2, "deaths") == 3.0 and telemetry.get_value(2, "dash_use") == 12.0 and telemetry.get_value(2, "kills") == 6.0
		and is_equal_approx(telemetry.get_value(2, "time_in_level"), 100.5) and telemetry.get_value(1, "deaths") == 0.0)
	_check("telemetry: weapons are counted by their attack kind (light 2, heavy 1, dash slash 1, wave 3; unknown ignored)", telemetry.get_value(2, "light_use") == 2.0 and telemetry.get_value(2, "heavy_use") == 1.0
		and telemetry.get_value(2, "dash_slash_use") == 1.0 and telemetry.get_value(2, "wave_use") == 3.0)
	_check("telemetry: unknown metrics, negative and non-finite amounts are ignored", telemetry.get_value(2, "nonsense") == 0.0 and telemetry.get_value(2, "deaths") == 3.0)
	var summary: Dictionary = telemetry.summarize(2, config)
	var categorical: bool = true
	for metric in RunTelemetry.METRICS:
		categorical = categorical and summary.has(metric) and ["low", "mid", "high"].has(summary[metric])
	_check("telemetry: the summary has every metric and ONLY low / mid / high values (never counts)", categorical and summary.size() == RunTelemetry.METRICS.size())
	_check("telemetry: deaths 3 is mid, dash 12 is mid, time 100 s is mid, kills 6 is mid, heals 1 is mid, low-health time 12 s is mid", summary["deaths"] == "mid" and summary["dash_use"] == "mid" and summary["time_in_level"] == "mid" and summary["kills"] == "mid"
		and summary["heals"] == "mid" and summary["low_health_time"] == "mid")
	_check("telemetry: the thresholds come from the resource (deaths 1 low, 2 mid, 5 high)", config.categorize("deaths", 1.0) == "low" and config.categorize("deaths", 2.0) == "mid" and config.categorize("deaths", 4.9) == "mid" and config.categorize("deaths", 5.0) == "high")
	telemetry.reset()
	_check("telemetry: reset forgets everything", not telemetry.has_level(2) and telemetry.get_value(2, "deaths") == 0.0)
	var patterns := RunTelemetry.new()
	patterns.add_pattern_damage(2, "swipe", 2.0)
	patterns.add_pattern_damage(2, "charge", 5.0)
	patterns.add_pattern_damage(2, "leap", 5.0)
	_check("telemetry: the worst pattern is the one with most damage (tie: first id alphabetically)", patterns.worst_pattern(2) == "charge" and patterns.worst_pattern(3) == "")


func _test_telemetry_sources() -> void:
	var melee := (load("res://backend/enemies/melee_enemy.tscn") as PackedScene).instantiate()
	var fast := (load("res://backend/enemies/fast_enemy.tscn") as PackedScene).instantiate()
	var ranged := (load("res://backend/enemies/ranged_enemy.tscn") as PackedScene).instantiate()
	var boss := (load(BOSSES[2]) as PackedScene).instantiate()
	var hazard := FloorHazard.new()
	var kill_zone := KillZone.new()
	var projectile := Projectile.new()
	projectile.source = ranged
	_check("sources: melee and fast enemies are melee, the ranged enemy and its projectile are ranged, the boss, hazard and kill zone have their own",
		RunTelemetry.source_category(melee) == "melee" and RunTelemetry.source_category(fast) == "melee" and RunTelemetry.source_category(ranged) == "ranged"
		and RunTelemetry.source_category(projectile) == "ranged" and RunTelemetry.source_category(boss) == "boss" and RunTelemetry.source_category(hazard) == "hazard"
		and RunTelemetry.source_category(kill_zone) == "fall" and RunTelemetry.source_category(null) == "other")
	var hitbox: Node = melee.find_children("*", "Hitbox", true, false)[0]
	_check("sources: a hitbox counts as the enemy that owns it", RunTelemetry.source_category(hitbox) == "melee")
	var telemetry := RunTelemetry.new()
	telemetry.record_damage(2, melee, 2)
	telemetry.record_damage(2, ranged, 1)
	telemetry.record_damage(2, projectile, 1)
	telemetry.record_damage(2, boss, 3)
	telemetry.record_damage(2, hazard, 1)
	telemetry.record_damage(2, kill_zone, 8)
	_check("sources: damage is counted by category (melee 2, ranged 2, boss 3, hazard 1) and a fall counts as a fall, not as hearts",
		telemetry.get_value(2, "melee_damage") == 2.0 and telemetry.get_value(2, "ranged_damage") == 2.0 and telemetry.get_value(2, "boss_damage") == 3.0
		and telemetry.get_value(2, "hazard_damage") == 1.0 and telemetry.get_value(2, "fall_deaths") == 1.0 and telemetry.get_value(2, "damage_taken") == 8.0)
	for node in [melee, fast, ranged, boss, hazard, kill_zone]:
		node.free()
	projectile.free()


func _test_observer_in_level() -> void:
	_clean_state()
	var level: LevelBase = await _load_level(2)
	var telemetry: RunTelemetry = GameState.director.telemetry
	_check("observer: a numbered level creates it and the telemetry has a record for the level", level.telemetry_observer != null and telemetry.has_level(2))
	var player: Player = level.player
	player.story_invulnerable = false
	var melee_enemy: Node = level.find_children("*", "MeleeEnemy", true, false)[0] if not level.find_children("*", "MeleeEnemy", true, false).is_empty() else null
	var source: Node = melee_enemy if melee_enemy != null else level.find_children("*", "EnemyBase", true, false)[0]
	player.health.apply_damage(DamageInfo.create(2, Vector2.ZERO, source, CombatLayers.Team.ENEMY))
	player.dash_started.emit()
	player.double_jumped.emit()
	player.attack_started.emit()
	player.heavy_attack_started.emit()
	player.dash_slash_started.emit()
	player.wave_cast.emit(1)
	player.focus_completed.emit(1)
	var enemy := level.find_children("*", "EnemyBase", true, false)[0] as EnemyBase
	enemy.died.emit(enemy)
	_check("observer: a hit from an enemy is recorded as damage from that category", telemetry.get_value(2, "damage_taken") == 2.0 and telemetry.get_value(2, "melee_damage") + telemetry.get_value(2, "ranged_damage") == 2.0)
	_check("observer: dash, double jump, the four weapons, a heal and a kill are recorded from the existing signals", telemetry.get_value(2, "dash_use") == 1.0 and telemetry.get_value(2, "double_jump_use") == 1.0
		and telemetry.get_value(2, "light_use") == 1.0 and telemetry.get_value(2, "heavy_use") == 1.0 and telemetry.get_value(2, "dash_slash_use") == 1.0 and telemetry.get_value(2, "wave_use") == 1.0
		and telemetry.get_value(2, "heals") == 1.0 and telemetry.get_value(2, "kills") == 1.0)
	# Time is game time: the delta of the physics steps.
	var before: float = telemetry.get_value(2, "time_in_level")
	var elapsed: float = 0.0
	for i in 30:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	var counted: float = telemetry.get_value(2, "time_in_level") - before
	_check("observer: the time in the level is game time (%.3f s counted over %.3f s)" % [counted, elapsed], absf(counted - elapsed) < 0.05)
	# Low hearts: time at or below the configured hearts is measured, only while alive.
	player.health.current_health = config.low_health_hearts
	var low_before: float = telemetry.get_value(2, "low_health_time")
	await _physics(30)
	_check("observer: time spent at low hearts is measured (%.2f s)" % (telemetry.get_value(2, "low_health_time") - low_before), telemetry.get_value(2, "low_health_time") - low_before > 0.3)
	player.health.current_health = player.health.max_health
	# Boss fight time only while the boss is awake.
	var boss_before: float = telemetry.get_value(2, "time_in_boss")
	await _physics(10)
	_check("observer: no boss time before the fight", telemetry.get_value(2, "time_in_boss") == boss_before)
	level.boss.activate(player)
	await _physics(30)
	var in_fight: float = telemetry.get_value(2, "time_in_boss") - boss_before
	level.boss.reset_encounter()
	await _physics(2)
	var after_reset: float = telemetry.get_value(2, "time_in_boss")
	await _physics(20)
	_check("observer: the boss time counts while it fights (%.2f s) and stops when the encounter resets" % in_fight, in_fight > 0.3 and is_equal_approx(telemetry.get_value(2, "time_in_boss"), after_reset))
	player.health.kill()
	await _physics(3)
	_check("observer: a death is recorded", telemetry.get_value(2, "deaths") >= 1.0)
	await _free_level(level)
	# A new game forgets it all.
	GameState.start_new_game()
	_check("telemetry: a new game resets it", not GameState.director.telemetry.has_level(2))
	var level_again: LevelBase = await _load_level(2)
	GameState.director.telemetry.add(2, "deaths")
	GameState.load_from_dict(GameState.to_dict())
	_check("telemetry: loading a save resets it (continue from disk starts without telemetry)", not GameState.director.telemetry.has_level(2))
	await _free_level(level_again)
	var tutorial := (load("res://frontend/levels/tutorial.tscn") as PackedScene).instantiate() as LevelBase
	add_child(tutorial)
	await _frames(3)
	_check("observer: the tutorial (level 0) records nothing", tutorial.telemetry_observer == null and not GameState.director.telemetry.has_level(0) and tutorial.get_applied_plan().is_neutral())
	await _free_level(tutorial)


# ---------------------------------------------------------------------------------------------
# 2. Themes
# ---------------------------------------------------------------------------------------------

func _test_themes() -> void:
	var rules: Array = [
		["recursos", {"heals": "low", "low_health_time": "high"}],
		["distancia", {"ranged_damage": "high"}],
		["calma", {"deaths": "high", "melee_damage": "mid"}],
		["ritmo", {"boss_damage": "mid"}],
		["paciencia", {"damage_taken": "high", "time_in_level": "low"}],
		["valor", {"light_use": "low", "wave_use": "low", "time_in_level": "high"}],
	]
	var all_ok: bool = true
	for entry in rules:
		var theme: String = DirectorThemes.select(_summary(entry[1]), config)
		all_ok = all_ok and theme == entry[0]
		if theme != entry[0]:
			print("theme mismatch: expected %s got %s for %s" % [entry[0], theme, str(entry[1])])
	_check("themes: each rule picks its theme (rushing into melee -> calma, ranged hits -> distancia, no heals while low -> recursos...)", all_ok)
	_check("themes: nothing matching gives the default (equilibrio)", DirectorThemes.select(_summary(), config) == "equilibrio" and DirectorThemes.select({}, config) == "equilibrio")
	var first: String = DirectorThemes.select(_summary({"ranged_damage": "mid", "deaths": "high", "melee_damage": "high"}), config)
	_check("themes: the first matching rule wins (ranged hits come before rushing into melee)", first == "distancia")
	var same: bool = true
	var seed_summary: Dictionary = _summary({"deaths": "mid", "melee_damage": "high", "heals": "mid"})
	for i in 5:
		same = same and DirectorThemes.select(seed_summary, config) == "calma"
	_check("themes: the same summary always gives the same theme", same)
	var in_list: bool = true
	for rule in config.theme_rules:
		in_list = in_list and config.themes.has(rule.theme)
	_check("themes: the list is exactly calma, paciencia, distancia, ritmo, recursos, valor, equilibrio and every rule uses one of them", config.themes == PackedStringArray(["calma", "paciencia", "distancia", "ritmo", "recursos", "valor", "equilibrio"]) and in_list)


# ---------------------------------------------------------------------------------------------
# 3. Planner
# ---------------------------------------------------------------------------------------------

func _test_planner() -> void:
	var neutral: DirectorPlan = LocalDirectorPlanner.plan(_summary({"time_in_level": "mid", "deaths": "mid"}), "charge", config)
	_check("planner: a mid player gets the neutral plan (delta 0, no weights)", neutral.extras_delta == 0 and neutral.boss_pattern_weights.is_empty() and neutral.is_neutral())
	var mild: DirectorPlan = LocalDirectorPlanner.plan(_summary({"deaths": "high"}), "charge", config)
	_check("planner: struggling (many deaths) lowers the extras by 1 and the worst pattern to 0.8", mild.extras_delta == -1 and is_equal_approx(float(mild.boss_pattern_weights["charge"]), 0.8))
	var damaged: DirectorPlan = LocalDirectorPlanner.plan(_summary({"damage_taken": "high"}), "leap", config)
	_check("planner: struggling (high damage) does the same", damaged.extras_delta == -1 and is_equal_approx(float(damaged.boss_pattern_weights["leap"]), 0.8))
	var severe: DirectorPlan = LocalDirectorPlanner.plan(_summary({"deaths": "high", "damage_taken": "high"}), "charge", config)
	_check("planner: struggling badly lowers the extras to -2 (the floor) and the pattern to 0.6 (the floor)", severe.extras_delta == -2 and is_equal_approx(float(severe.boss_pattern_weights["charge"]), 0.6))
	var comfortable: DirectorPlan = LocalDirectorPlan_comfortable()
	_check("planner: a comfortable player (no deaths, little damage, really played) gets +1 extra and the pattern that hurt most weighted up to 1.4 (under 1.5)",
		comfortable.extras_delta == 1 and is_equal_approx(float(comfortable.boss_pattern_weights["charge"]), 1.4) and float(comfortable.boss_pattern_weights["charge"]) <= config.weight_max)
	var idle: DirectorPlan = LocalDirectorPlanner.plan(_summary({"time_in_level": "low"}), "charge", config)
	_check("planner: a level that was barely played is never read as comfortable (neutral)", idle.is_neutral())
	var no_pattern: DirectorPlan = LocalDirectorPlanner.plan(_summary({"deaths": "high"}), "", config)
	_check("planner: with no pattern data only the extras change (no weights)", no_pattern.extras_delta == -1 and no_pattern.boss_pattern_weights.is_empty())
	var again: DirectorPlan = LocalDirectorPlanner.plan(_summary({"deaths": "high", "damage_taken": "high"}), "charge", config)
	_check("planner: same input, same plan", again.to_dict() == severe.to_dict())
	_check("planner: the plan has exactly the four fields and never a profile", DirectorPlan.new().to_dict().keys() == ["theme", "extras_delta", "boss_pattern_weights", "epilogue_variant"] and not severe.to_dict().has("profile"))
	_check("planner: the epilogue variant is stored (0 neutral, 1 comfortable, 2 struggling)", neutral.epilogue_variant == 0 and comfortable.epilogue_variant == 1 and severe.epilogue_variant == 2)
	var unknown: DirectorPlan = LocalDirectorPlanner.plan(_summary({"deaths": "high"}), "charge", config, PackedStringArray(["swipe"]))
	_check("planner: a pattern the boss does not have is dropped by the validator", unknown.boss_pattern_weights.is_empty())


func LocalDirectorPlan_comfortable() -> DirectorPlan:
	return LocalDirectorPlanner.plan(_summary({"time_in_level": "mid"}), "charge", config)


# ---------------------------------------------------------------------------------------------
# 4. Validator
# ---------------------------------------------------------------------------------------------

func _validate(raw: Variant, known: PackedStringArray = PackedStringArray()) -> Dictionary:
	return DirectorPlanValidator.validate(raw, "calma", config, known)


func _test_validator() -> void:
	var good: Dictionary = _validate({"theme": "ritmo", "extras_delta": 1, "boss_pattern_weights": {"charge": 1.2}, "epilogue_variant": 2})
	_check("validator: a good plan passes unchanged", good["ok"] and good["plan"].theme == "ritmo" and good["plan"].extras_delta == 1 and is_equal_approx(float(good["plan"].boss_pattern_weights["charge"]), 1.2) and good["plan"].epilogue_variant == 2)
	_check("validator: anything that is not a dictionary is rejected", not _validate("plan")["ok"] and not _validate(null)["ok"] and not _validate([1, 2])["ok"] and not _validate(5)["ok"])
	var rejected_all: bool = true
	for key in ["profile", "adaptive_profile", "boss_hp", "max_health", "damage", "aggression", "boss_aggression", "cooldown", "telegraph_time", "PROFILE"]:
		rejected_all = rejected_all and not _validate({"theme": "calma", key: 1})["ok"]
	_check("validator: a plan with a profile key (or HP, damage, aggression, cooldown, telegraph) is REJECTED", rejected_all)
	var dropped: Dictionary = _validate({"theme": "calma", "banana": 5, "extras_delta": 0})
	_check("validator: any other unknown key is dropped (the plan is still accepted)", dropped["ok"] and not (dropped["plan"] as DirectorPlan).to_dict().has("banana") and not (dropped["warnings"] as Array).is_empty())
	_check("validator: a theme out of the list is replaced by the local theme", _validate({"theme": "venganza"})["plan"].theme == "calma" and _validate({"theme": 7})["plan"].theme == "calma" and _validate({})["plan"].theme == "calma")
	_check("validator: the extras delta is clamped to -2..+1 (and a non-number becomes 0)", _validate({"extras_delta": -9})["plan"].extras_delta == -2 and _validate({"extras_delta": 9})["plan"].extras_delta == 1
		and _validate({"extras_delta": 1.4})["plan"].extras_delta == 1 and _validate({"extras_delta": "mucho"})["plan"].extras_delta == 0 and _validate({"extras_delta": NAN})["plan"].extras_delta == 0)
	var weights: Dictionary = _validate({"boss_pattern_weights": {"a": 0, "b": -3, "c": 0.1, "d": 5, "e": 1.0, "f": "x", "g": INF, "h": 0.6, "i": 1.5}})["plan"].boss_pattern_weights
	_check("validator: zero and negative weights are replaced by 1.0, small ones clamped up to 0.6 and big ones down to 1.5 (never 0)",
		is_equal_approx(float(weights["a"]), 1.0) and is_equal_approx(float(weights["b"]), 1.0) and is_equal_approx(float(weights["c"]), 0.6) and is_equal_approx(float(weights["d"]), 1.5)
		and is_equal_approx(float(weights["e"]), 1.0) and is_equal_approx(float(weights["f"]), 1.0) and is_equal_approx(float(weights["g"]), 1.0) and is_equal_approx(float(weights["h"]), 0.6) and is_equal_approx(float(weights["i"]), 1.5))
	var all_in_range: bool = true
	for id: Variant in weights.keys():
		all_in_range = all_in_range and float(weights[id]) >= config.weight_min and float(weights[id]) <= config.weight_max
	_check("validator: every weight that comes out is within 0.6 and 1.5", all_in_range)
	var known: Dictionary = _validate({"boss_pattern_weights": {"charge": 1.2, "ghost": 1.2, "Bad Id": 1.2}}, PackedStringArray(["charge", "swipe"]))
	_check("validator: unknown pattern ids (and malformed ones) are dropped", (known["plan"].boss_pattern_weights as Dictionary).keys() == ["charge"])
	_check("validator: without a known list any well-formed id passes, a malformed one never", _validate({"boss_pattern_weights": {"charge": 1.2, "Bad Id": 1.2}})["plan"].boss_pattern_weights.keys() == ["charge"])
	_check("validator: the epilogue variant is clamped to 0..2", _validate({"epilogue_variant": 7})["plan"].epilogue_variant == 2 and _validate({"epilogue_variant": -3})["plan"].epilogue_variant == 0 and _validate({"epilogue_variant": "x"})["plan"].epilogue_variant == 0)
	var empty: DirectorPlan = _validate({})["plan"]
	_check("validator: an empty plan becomes the neutral one with the local theme", empty.is_neutral() and empty.theme == "calma" and empty.epilogue_variant == 0)
	_check("validator: a weights field that is not a dictionary is ignored", _validate({"boss_pattern_weights": [1, 2]})["plan"].boss_pattern_weights.is_empty())


# ---------------------------------------------------------------------------------------------
# 5. The plan applied at level load
# ---------------------------------------------------------------------------------------------

func _test_level_one_and_no_telemetry_are_neutral() -> void:
	_clean_state()
	# Level 1, even with a terrible level 0 behind it, and level 2 without telemetry are neutral.
	_seed(0, {"deaths": 20, "damage_taken": 50})
	var one: LevelBase = await _load_level(1)
	_check("neutral: level 1 always gets the neutral plan", one.get_applied_plan().is_neutral() and one.get_applied_plan().extras_delta == 0)
	await _free_level(one)
	_clean_state()
	var two: LevelBase = await _load_level(2, "corrupt")
	_check("neutral: level 2 with no telemetry behind it (continue from disk) is neutral and keeps its profile extras (%d)" % _extras_left(two).size(), two.get_applied_plan().is_neutral() and _extras_left(two).size() == 2)
	await _free_level(two)
	_clean_state()
	var base_weights: Dictionary = _scene_weights(2)
	var two_neutral: LevelBase = await _load_level(2, "neutral")
	_check("neutral: a neutral plan leaves every boss pattern weight as the scene had it", _boss_weights(two_neutral.boss) == base_weights and _extras_left(two_neutral).is_empty())
	await _free_level(two_neutral)


func _test_struggling_and_comfortable_levels() -> void:
	# Struggling in level 1 -> level 2: fewer extras and the worst pattern weighted down.
	_clean_state()
	var rotation: PackedStringArray = _rotation_ids(2)
	var worst: String = rotation[0]
	_seed(1, {"deaths": 6, "damage_taken": 20, "time_in_level": 200}, worst)
	var base: float = float(_scene_weights(2)[worst])
	var hard: LevelBase = await _load_level(2, "corrupt")
	var plan: DirectorPlan = hard.get_applied_plan()
	_check("struggling: level 2 gets delta %d and weight %.2f for '%s'" % [plan.extras_delta, float(plan.boss_pattern_weights.get(worst, 0.0)), worst], plan.extras_delta == -2 and is_equal_approx(float(plan.boss_pattern_weights.get(worst, 0.0)), 0.6))
	_check("struggling: a corrupt profile (2 extras) is lowered to %d extras (never below 0)" % _extras_left(hard).size(), _extras_left(hard).is_empty())
	var weight_now: float = float(_boss_weights(hard.boss)[worst])
	_check("struggling: the boss pattern weight is the scene one times 0.6 (%.2f of %.2f)" % [weight_now, base], is_equal_approx(weight_now, base * 0.6))
	await _free_level(hard)
	# Comfortable in level 1 -> level 2.
	_clean_state()
	_seed(1, {"time_in_level": 150, "kills": 8}, worst)
	var easy: LevelBase = await _load_level(2, "neutral")
	var easy_plan: DirectorPlan = easy.get_applied_plan()
	var added: Array[NodePath] = _extras_left(easy)
	_check("comfortable: level 2 gets delta +1 and the pattern weighted up to 1.4", easy_plan.extras_delta == 1 and is_equal_approx(float(easy_plan.boss_pattern_weights.get(worst, 0.0)), 1.4))
	var edges: Array[float] = easy.get_gap_edges(config.gap_min_width)
	var fair: bool = true
	for path in added:
		for edge in edges:
			fair = fair and absf((easy.get_node(path) as Node2D).global_position.x - edge) >= config.slot_min_gap_edge_distance
	_check("comfortable: the neutral profile (0 extras) gets at most +1 extra, from a defined slot at least 150 px from every gap edge (%d added)" % added.size(), added.size() <= 1 and fair)
	_check("comfortable: the boss weight is the scene one times 1.4 (%.2f)" % float(_boss_weights(easy.boss)[worst]), is_equal_approx(float(_boss_weights(easy.boss)[worst]), base * 1.4))
	await _free_level(easy)
	# Level 3 corrupt (3 extras) and comfortable: still 3 (the cap).
	_clean_state()
	_seed(2, {"time_in_level": 150}, "")
	var three: LevelBase = await _load_level(3, "corrupt")
	_check("comfortable: a corrupt level 3 (3 extras) with +1 is still 3 (the cap)", three.get_applied_plan().extras_delta == 1 and _extras_left(three).size() == 3)
	await _free_level(three)
	# Level 3 corrupt and struggling: two fewer.
	_clean_state()
	_seed(2, {"deaths": 6, "damage_taken": 20}, "")
	var hard_three: LevelBase = await _load_level(3, "corrupt")
	_check("struggling: a corrupt level 3 (3 extras) with -2 keeps 1 (the first slot)", hard_three.get_applied_plan().extras_delta == -2 and _extras_left(hard_three).size() == 1)
	await _free_level(hard_three)


func _test_extras_grid() -> void:
	var worst_closest: float = 1e9
	var bounds_ok: bool = true
	var added_fair: bool = true
	var combos: int = 0
	var gaps_checked: int = 0
	for level_number in [2, 3]:
		for profile in PROFILES:
			for delta in [-2, -1, 0, 1]:
				_clean_state()
				GameState.director.set_forced_plan({"theme": "calma", "extras_delta": delta})
				var level: LevelBase = await _load_level(level_number, profile)
				var base_group: Array[NodePath] = []
				var group_id: String = {"compassionate": "calm", "neutral": "standard", "corrupt": "corrupted"}[profile]
				for raw_path: Variant in level.variant_groups.get(group_id, []) as Array:
					base_group.append(NodePath(raw_path))
				var left: Array[NodePath] = _extras_left(level)
				var expected: int = clampi(base_group.size() + delta, 0, config.extras_total_cap) if delta != 0 else base_group.size()
				var edges: Array[float] = level.get_gap_edges(config.gap_min_width)
				gaps_checked += edges.size()
				bounds_ok = bounds_ok and left.size() >= 0 and left.size() <= config.extras_total_cap and (left.size() == expected or left.size() < expected)
				for path in left:
					if base_group.has(path):
						continue
					for edge in edges:
						var distance: float = absf((level.get_node(path) as Node2D).global_position.x - edge)
						worst_closest = minf(worst_closest, distance)
						added_fair = added_fair and distance >= config.slot_min_gap_edge_distance
				combos += 1
				await _free_level(level)
	print("MEASURE|extras grid|%d combinations of level, profile and delta|closest added slot to a gap edge %.0f px" % [combos, worst_closest])
	_check("extras: over every level, profile and delta (%d combinations) the extras are never below 0 or above 3 and match clamp(profile extras + delta)" % combos, bounds_ok)
	_check("extras: every slot added by a plan stands at least 150 px from a gap edge (closest %.0f px)" % worst_closest, added_fair)
	# Authored slots of level 3 (the only level with gaps) also respect the rule, as in Phase 15e-2.
	_clean_state()
	var three: LevelBase = await _load_level(3, "neutral")
	var edges3: Array[float] = three.get_gap_edges(config.gap_min_width)
	var authored_ok: bool = edges3.size() == 6
	for group: Variant in three.variant_groups.values():
		for raw_path: Variant in group as Array:
			var node := three.get_node_or_null(NodePath(raw_path)) as Node2D
			if node == null:
				continue
			for edge in edges3:
				authored_ok = authored_ok and absf(node.global_position.x - edge) >= 150.0
	_check("extras: the gap edges are found in level 3 (6) and its authored slots keep 150 px from them", authored_ok, str(edges3))
	await _free_level(three)


func _test_boss_weights() -> void:
	_clean_state()
	var level: LevelBase = await _load_level(3, "neutral")
	var boss: BossBase = level.boss
	var base: Dictionary = _scene_weights(3)
	var rotation: PackedStringArray = boss.rotation_pattern_ids()
	_check("weights: boss 3 rotation patterns are the beam, columns, swipe and charge ones (no fallbacks)", rotation.has("beam") and rotation.has("columns") and rotation.has("swipe") and rotation.has("charge")
		and not rotation.has("stomp") and not rotation.has("volley_fallback") and not rotation.has("charge_short"))
	boss.apply_pattern_weights({"beam": 1.5, "columns": 0.6, "stomp": 1.5, "volley_fallback": 1.5, "charge_short": 0.6, "nothing": 1.2})
	var weights: Dictionary = _boss_weights(boss)
	_check("weights: the rotation patterns are multiplied and the fallback patterns are untouched", is_equal_approx(float(weights["beam"]), float(base["beam"]) * 1.5) and is_equal_approx(float(weights["columns"]), float(base["columns"]) * 0.6)
		and weights["stomp"] == base["stomp"] and weights["volley_fallback"] == base["volley_fallback"] and weights["charge_short"] == base["charge_short"] and weights["swipe"] == base["swipe"])
	boss.apply_pattern_weights({"beam": 1.5})
	_check("weights: applying twice never compounds (always from the scene weight)", is_equal_approx(float(_boss_weights(boss)["beam"]), float(base["beam"]) * 1.5) and is_equal_approx(float(_boss_weights(boss)["columns"]), float(base["columns"])))
	boss.apply_pattern_weights({"beam": 9.0, "columns": 0.0, "swipe": -4.0})
	var clamped: Dictionary = _boss_weights(boss)
	_check("weights: out-of-range multipliers are clamped even if a plan got past the validator (0.6 to 1.5)", is_equal_approx(float(clamped["beam"]), float(base["beam"]) * 1.5) and is_equal_approx(float(clamped["columns"]), float(base["columns"]) * 0.6)
		and is_equal_approx(float(clamped["swipe"]), float(base["swipe"]) * 0.6))
	var untouched: bool = true
	for pattern in boss.patterns:
		var scene_pattern: BossPattern = null
		untouched = untouched and pattern.max_phase >= pattern.min_phase
	_check("weights: only `weight` changes (phases and fallback priorities are as authored)", untouched)
	boss.apply_pattern_weights({})
	_check("weights: an empty dictionary restores every weight", _boss_weights(boss) == base)
	# Through a forced plan at load: the validator drops fallback ids, the boss only gets rotation ones.
	await _free_level(level)
	_clean_state()
	GameState.director.set_forced_plan({"theme": "valor", "boss_pattern_weights": {"beam": 1.4, "stomp": 1.5, "swipe": 0.7}})
	var forced: LevelBase = await _load_level(3, "neutral")
	var applied: Dictionary = _boss_weights(forced.boss)
	_check("weights: a forced plan reaches the boss at load; the fallback id is ignored", is_equal_approx(float(applied["beam"]), float(base["beam"]) * 1.4) and is_equal_approx(float(applied["swipe"]), float(base["swipe"]) * 0.7) and applied["stomp"] == base["stomp"])
	await _free_level(forced)


func _test_bosses_neutral_unchanged() -> void:
	for level_number in [1, 2, 3]:
		_clean_state()
		GameState.director.set_force_neutral(true)
		var base: Dictionary = _scene_weights(level_number)
		var level: LevelBase = await _load_level(level_number, "corrupt")
		_check("neutral: boss %d keeps every pattern weight as authored with the neutral plan" % level_number, _boss_weights(level.boss) == base)
		var extras: int = 0
		for group: Variant in level.variant_groups.values():
			extras += (group as Array).size() if (group as Array).size() > 0 else 0
		var expected: int = (level.variant_groups.get("corrupted", []) as Array).size()
		_check("neutral: level %d keeps its profile extras (%d) and the profile aggression 1.15" % [level_number, expected], _extras_left(level).size() == expected and is_equal_approx(level.boss.aggression_multiplier, 1.15))
		await _free_level(level)
	_clean_state()
	var compassionate: LevelBase = await _load_level(3, "compassionate")
	_check("neutral: the aggression table of the profile still works (0.9) and the plan never changes it", is_equal_approx(compassionate.boss.aggression_multiplier, 0.9) and _extras_left(compassionate).is_empty())
	await _free_level(compassionate)


func _test_debug_override() -> void:
	_clean_state()
	var director: Director = GameState.director
	_check("debug: this run is a debug build, so the overrides are allowed", OS.is_debug_build() and director.overrides_allowed())
	_check("debug: a fixed plan is accepted (validated) and every level load uses it", director.set_forced_plan({"theme": "paciencia", "extras_delta": -2, "boss_pattern_weights": {"charge": 0.7}}) and director.has_override())
	var forced: LevelBase = await _load_level(2, "corrupt")
	_check("debug: level 2 loads the forced plan (theme %s, delta %d) with no telemetry at all" % [forced.get_applied_plan().theme, forced.get_applied_plan().extras_delta], forced.get_applied_plan().theme == "paciencia" and forced.get_applied_plan().extras_delta == -2 and _extras_left(forced).is_empty())
	await _free_level(forced)
	var one: LevelBase = await _load_level(1, "neutral")
	_check("debug: even level 1 uses a forced plan (for QA)", one.get_applied_plan().theme == "paciencia")
	await _free_level(one)
	_check("debug: a forced plan with a profile key is refused", not director.set_forced_plan({"profile": "corrupt"}))
	director.clear_overrides()
	_check("debug: 'always neutral' mode wins over a bad telemetry", director.set_force_neutral(true))
	_seed(1, {"deaths": 6, "damage_taken": 20, "time_in_level": 200}, "swipe")
	var neutral: LevelBase = await _load_level(2, "neutral")
	_check("debug: always-neutral gives the neutral plan", neutral.get_applied_plan().is_neutral())
	await _free_level(neutral)
	director.clear_overrides()
	director.simulate_release = true
	_check("release: the overrides are refused in a release build", not director.set_forced_plan({"theme": "valor", "extras_delta": 1}) and not director.set_force_neutral(true) and not director.has_override())
	var release: LevelBase = await _load_level(2, "neutral")
	_check("release: the level uses the local plan (struggling: delta %d)" % release.get_applied_plan().extras_delta, release.get_applied_plan().extras_delta == -2)
	await _free_level(release)
	director.simulate_release = false


func _test_cache_across_retry() -> void:
	_clean_state()
	_seed(1, {"deaths": 6, "damage_taken": 20, "time_in_level": 200}, "swipe")
	var first: LevelBase = await _load_level(2, "neutral")
	var first_plan: Dictionary = first.get_applied_plan().to_dict()
	await _free_level(first)
	# The player did better meanwhile (telemetry changes), but the retry reuses the cached plan.
	GameState.director.telemetry.reset()
	GameState.director.telemetry.add(1, "time_in_level", 150.0)
	var retry: LevelBase = await _load_level(2, "neutral")
	_check("cache: a retry of the level in the same session reuses the cached plan", retry.get_applied_plan().to_dict() == first_plan and first_plan["extras_delta"] == -2)
	await _free_level(retry)
	var fresh: DirectorPlan = GameState.director.plan_for_level(3)
	_check("cache: another level computes its own plan (level 3 has no telemetry behind it: neutral)", fresh.is_neutral())
	GameState.director.reset()
	_check("cache: a new game or a loaded save drops the cached plans", GameState.director.get_cached_plan(2) == null)


func _test_no_leaks() -> void:
	_clean_state()
	var counts: Array[int] = []
	for round in 5:
		_seed(1, {"time_in_level": 150}, "swipe")
		var level: LevelBase = await _load_level(2, "corrupt")
		await _physics(10)
		await _free_level(level)
		await _frames(2)
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	print("MEASURE|node counts after repeated level loads|%s" % str(counts))
	_check("leaks: no nodes are left behind after repeated level loads (%s)" % str(counts), counts[4] <= counts[1] + 4 and not get_tree().paused)
