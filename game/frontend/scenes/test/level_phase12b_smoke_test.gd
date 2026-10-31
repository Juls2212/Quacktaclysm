extends Node
## Headless smoke test for Phase 12b: boss aggression, bosses 2 and 3, LevelBase adaptive application,
## last-level completion ("ending" marker), main menu "Continuar", ending scene, static reachability
## analysis of levels 1-3 (with reach values measured from a real Player simulation) and scene loads.
## Development only. Run: <godot> --headless --path game res://frontend/scenes/test/level_phase12b_smoke_test.tscn
## Uses a redirected save path and SceneManager.dry_run; the AI service stays disabled; the real
## save is never touched. The full playthroughs live in level_phase12b_playthrough_test.

const TEST_SAVE: String = "user://test_save_phase12b.json"
const DEFAULT_REGISTRY: SceneRegistry = preload("res://backend/progression/default_scene_registry.tres")
const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const BOSS_ONE: PackedScene = preload("res://backend/bosses/placeholder_boss.tscn")
const BOSS_TWO: PackedScene = preload("res://backend/bosses/boss_two.tscn")
const BOSS_THREE: PackedScene = preload("res://backend/bosses/boss_three.tscn")
const ENDING_SCENE: PackedScene = preload("res://frontend/ui/ending.tscn")
const MAIN_MENU_SCENE: PackedScene = preload("res://frontend/ui/main_menu.tscn")
const LEVEL_PATHS: Dictionary = {
	1: "res://frontend/levels/level_1.tscn",
	2: "res://frontend/levels/level_2.tscn",
	3: "res://frontend/levels/level_3.tscn",
}
const NEW_SCRIPTS: Array[String] = [
	"res://backend/progression/level_base.gd",
	"res://backend/progression/ending_controller.gd",
	"res://backend/progression/level_debug.gd",
]
const FLOOR_Y: float = 300.0
const PLAYER_HALF_HEIGHT: float = 26.0
const PLAYER_HALF_WIDTH: float = 14.0
const ENEMY_HALF_SIZE: Vector2 = Vector2(14.0, 24.0)
const BOSS_HALF_SIZE: Vector2 = Vector2(28.0, 44.0)
const ACTIONS: Array[String] = ["move_left", "move_right", "jump", "dash", "attack"]
const DASH_DELAY_DEFAULT: float = 0.3
const DASH_SWEEP: Array[float] = [0.2, 0.3, 0.4, 0.5, 0.6, 0.7]
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const PROFILES: Array[String] = ["compassionate", "neutral", "corrupt"]
const PROFILE_AGGRESSION: Dictionary = {"compassionate": 0.9, "neutral": 1.0, "corrupt": 1.15}
const PROFILE_ENDING: Dictionary = {"compassionate": "ending_compassionate", "neutral": "ending_neutral", "corrupt": "ending_corrupt"}
## Designed enemy counts: level -> {melee, fast, ranged} of the BASELINE and the number of corrupted extras.
const DESIGNED: Dictionary = {
	1: {"melee": 3, "fast": 2, "ranged": 1, "extras": 0},
	2: {"melee": 3, "fast": 2, "ranged": 3, "extras": 2},
	3: {"melee": 3, "fast": 3, "ranged": 3, "extras": 3},
}
const GROUND_TOP: float = 600.0

var failures: int = 0
var started_signals: Array[String] = []
var real_save_before: String = ""
var reach: Dictionary = {}
## Shared (cached) resource of the levels' refiners; disabled in memory for the whole test.
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig


## Records the evaluation point it is asked for instead of calling any service.
class FakeRefiner extends AdaptiveRefiner:
	var points: Array[String] = []

	func request_refinement(point: String = AdaptiveInput.POINT_AFTER_DECISION) -> bool:
		points.append(point)
		return false


func _ready() -> void:
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
	_run.call_deferred()


func _check(check_name: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("PASS: %s %s" % [check_name, detail])
	else:
		failures += 1
		print("FAIL: %s %s" % [check_name, detail])


func _physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _wait_idle(max_frames: int = 90) -> void:
	var waited: int = 0
	while SceneManager.is_transitioning() and waited < max_frames:
		await get_tree().process_frame
		waited += 1


func _wait_until(condition: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _read_file(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "<missing>"


func _saved_json() -> Dictionary:
	var parsed: Variant = JSON.parse_string(_read_file(TEST_SAVE))
	return parsed if parsed is Dictionary else {}


func _release_actions() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func _test_registry() -> SceneRegistry:
	var registry := SceneRegistry.new()
	registry.scenes = DEFAULT_REGISTRY.scenes.duplicate()
	registry.fade_out_time = 0.0
	registry.fade_in_time = 0.0
	return registry


func _clean_state() -> void:
	_release_actions()
	PauseLock.reset(get_tree())
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.autosave_enabled = true
	SceneManager.set_registry(_test_registry())
	SceneManager.last_requested_scene_id = ""
	SceneManager.last_requested_path = ""
	started_signals.clear()


func _set_profile(profile: String) -> void:
	_clean_state()
	GameState.set_adaptive_profile(profile)


func _add_floor(parent: Node, left: float = -4000.0, right: float = 4000.0) -> StaticBody2D:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	floor_body.collision_mask = 0
	floor_body.position = Vector2((left + right) * 0.5, FLOOR_Y + 20.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(right - left, 40.0)
	shape.shape = rect
	floor_body.add_child(shape)
	parent.add_child(floor_body)
	return floor_body


func _make_level(level_number: int) -> LevelBase:
	var level := (load(LEVEL_PATHS[level_number]) as PackedScene).instantiate() as LevelBase
	add_child(level)
	return level


func _kill_boss(level: LevelBase) -> void:
	level.boss.hurtbox.receive_hit(DamageInfo.create(9999, Vector2.ZERO, level.player, CombatLayers.Team.PLAYER))


func _free_fragments() -> void:
	for child in get_children():
		if child is SoulFragment:
			child.free()


func _find_fragment() -> SoulFragment:
	for child in get_children():
		if child is SoulFragment:
			return child as SoulFragment
	return null


func _run() -> void:
	SceneManager.dry_run = true
	SceneManager.set_registry(_test_registry())
	SceneManager.transition_started.connect(func(id: String) -> void: started_signals.append(id))
	_check("AI service disabled for the whole test", not ai_config.enabled)
	_test_game_state_helpers()
	await _test_aggression()
	await _test_extra_bosses()
	await _test_level_adaptive()
	await _test_intro_and_unknown_variant()
	await _test_completion_last_level()
	await _test_completed_game_entry()
	await _test_main_menu()
	await _test_ending_scene()
	await _measure_reach()
	await _test_gap_crossings()
	for level_number in [1, 2, 3]:
		_test_reachability(level_number)
	await _test_level_loads()
	await _test_debug_helper()
	_test_static_scans()
	_clean_state()
	SceneManager.dry_run = false
	SaveSystem.purge()
	_check("real save file untouched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


# --- GameState / resources ---

func _test_game_state_helpers() -> void:
	_clean_state()
	_check("GameState: ending constant", GameState.CHECKPOINT_ENDING == "ending")
	_check("GameState: fresh run is not completed", not GameState.is_game_completed())
	GameState.set_checkpoint(GameState.CHECKPOINT_ENDING)
	_check("GameState: ending marker means completed", GameState.is_game_completed())
	var data: Dictionary = GameState.to_dict()
	_check("GameState: exactly seven save keys", data.keys().size() == SAVE_KEYS.size() and SAVE_KEYS.all(func(key: String) -> bool: return data.has(key)))
	GameState.start_new_game()
	var outcome: Dictionary = GameState.load_from_dict(data)
	_check("GameState: load_from_dict accepts the ending checkpoint", outcome["ok"] == true and GameState.is_game_completed())
	data["checkpoint"] = "some_other_checkpoint"
	GameState.load_from_dict(data)
	_check("GameState: any non-empty checkpoint is still accepted", GameState.checkpoint == "some_other_checkpoint" and not GameState.is_game_completed())
	var fragment_two: SoulFragmentData = load("res://backend/decisions/data/fragment_level_2.tres") as SoulFragmentData
	var fragment_three: SoulFragmentData = load("res://backend/decisions/data/fragment_level_3.tres") as SoulFragmentData
	var fragment_one: SoulFragmentData = load("res://backend/decisions/data/fragment_level_1.tres") as SoulFragmentData
	_check("fragments: boss ids", fragment_one.boss_id == "placeholder_boss" and fragment_two.boss_id == "boss_two" and fragment_three.boss_id == "boss_three"
		and fragment_two.fragment_id == "fragment_level_2" and fragment_three.fragment_id == "fragment_level_3")
	_check("registry: levels 2, 3 and ending are real scenes", DEFAULT_REGISTRY.get_path_for("level_2") == LEVEL_PATHS[2]
		and DEFAULT_REGISTRY.get_path_for("level_3") == LEVEL_PATHS[3] and DEFAULT_REGISTRY.get_path_for("ending") == "res://frontend/ui/ending.tscn"
		and DEFAULT_REGISTRY.has_scene("level_2") and DEFAULT_REGISTRY.has_scene("level_3") and DEFAULT_REGISTRY.has_scene("ending")
		and not DEFAULT_REGISTRY.level_scene_ids.has("ending"))
	_clean_state()


# --- BossBase aggression ---

func _make_world_boss(scene: PackedScene, seed_value: int = 11) -> Dictionary:
	var world := Node2D.new()
	add_child(world)
	_add_floor(world)
	var target := Node2D.new()
	target.position = Vector2(90.0, FLOOR_Y - PLAYER_HALF_HEIGHT)
	world.add_child(target)
	var boss := scene.instantiate() as BossBase
	boss.rng_seed = seed_value
	boss.position = Vector2(0.0, FLOOR_Y - BOSS_HALF_SIZE.y)
	world.add_child(boss)
	return {"world": world, "boss": boss, "target": target}


func _hit(boss: BossBase, amount: int) -> bool:
	return boss.hurtbox.receive_hit(DamageInfo.create(amount, Vector2.ZERO, null, CombatLayers.Team.PLAYER))


func _all_hitboxes_off(boss: BossBase) -> bool:
	for child in boss.attack_pivot.get_children():
		if child is Hitbox and (child as Hitbox).is_active:
			return false
	return true


## Frames until the first pattern starts and until it finishes, with `aggression` set before activation.
## `interrupt_with` >= 0 calls set_aggression(interrupt_with) in the middle of the pattern.
func _first_pattern_frames(scene: PackedScene, aggression: float, interrupt_with: float = -1.0) -> Dictionary:
	var parts: Dictionary = _make_world_boss(scene)
	var boss: BossBase = parts["boss"]
	await _physics(3)
	boss.set_aggression(aggression)
	var log := {"started": -1, "finished": -1, "id": &"", "interrupt_applied": null, "speed_before": 0.0, "speed_after": 0.0}
	var frame: Array[int] = [0]
	boss.pattern_started.connect(func(id: StringName) -> void:
		log["started"] = frame[0]
		log["id"] = id)
	boss.pattern_finished.connect(func(_id: StringName) -> void: log["finished"] = frame[0])
	boss.activate(parts["target"])
	var interrupted: bool = false
	while frame[0] < 900 and log["finished"] < 0:
		await get_tree().physics_frame
		frame[0] += 1
		if interrupt_with >= 0.0 and not interrupted and log["started"] >= 0 and frame[0] >= log["started"] + 25:
			interrupted = true
			log["speed_before"] = boss.speed_multiplier
			log["interrupt_applied"] = boss.set_aggression(interrupt_with)
			log["speed_after"] = boss.speed_multiplier
			log["aggression_after"] = boss.aggression_multiplier
	log["boss_state_after"] = boss.state
	log["idle_apply"] = boss.set_aggression(1.0) if interrupt_with >= 0.0 else null
	log["hitboxes_off"] = _all_hitboxes_off(boss)
	(parts["world"] as Node).free()
	return log


func _test_aggression() -> void:
	_clean_state()
	# Defaults reproduce the previous behavior exactly (old formula: speed = phase multiplier, gap = base * phase gap multiplier).
	for scene: PackedScene in [BOSS_ONE, BOSS_TWO, BOSS_THREE]:
		var parts: Dictionary = _make_world_boss(scene)
		var boss: BossBase = parts["boss"]
		await _physics(2)
		var stats: BossStats = boss.stats
		_check("aggression (%s): default is 1.0" % stats.boss_id, boss.aggression_multiplier == 1.0 and boss.speed_multiplier == 1.0)
		_check("aggression (%s): default phase-1 gap equals the old formula exactly" % stats.boss_id, boss.get_effective_gap_time() == stats.pattern_gap_time)
		var damage: int = stats.max_health - int(floor(stats.max_health * stats.phase_2_health_ratio))
		boss.activate(parts["target"])
		_hit(boss, damage)
		await _physics(int(ceil(stats.phase_transition_time * 60.0)) + 3)
		_check("aggression (%s): default phase-2 speed equals the old formula exactly" % stats.boss_id,
			boss.current_phase == 2 and boss.speed_multiplier == stats.phase_2_speed_multiplier
			and boss.get_effective_gap_time() == stats.pattern_gap_time * stats.phase_2_pattern_gap_multiplier,
			"speed %.3f gap %.3f" % [boss.speed_multiplier, boss.get_effective_gap_time()])
		(parts["world"] as Node).free()
	# 1.15 / 0.9: multiplicative with the phase multipliers, in one place.
	var parts_two: Dictionary = _make_world_boss(BOSS_TWO)
	var boss_two: BossBase = parts_two["boss"]
	await _physics(2)
	var base_gap: float = boss_two.stats.pattern_gap_time
	boss_two.set_aggression(1.15)
	_check("aggression: 1.15 speeds up and shortens the gap", is_equal_approx(boss_two.speed_multiplier, 1.15) and boss_two.get_effective_gap_time() < base_gap
		and is_equal_approx(boss_two.get_effective_gap_time(), base_gap / 1.15))
	boss_two.set_aggression(0.9)
	_check("aggression: 0.9 slows down and lengthens the gap", is_equal_approx(boss_two.speed_multiplier, 0.9) and boss_two.get_effective_gap_time() > base_gap
		and is_equal_approx(boss_two.get_effective_gap_time(), base_gap / 0.9))
	boss_two.set_aggression(1.15)
	var stats_two: BossStats = boss_two.stats
	boss_two.activate(parts_two["target"])
	_hit(boss_two, stats_two.max_health - int(floor(stats_two.max_health * stats_two.phase_2_health_ratio)))
	await _physics(int(ceil(stats_two.phase_transition_time * 60.0)) + 3)
	_check("aggression: combines multiplicatively with the phase 2 multipliers", boss_two.current_phase == 2
		and is_equal_approx(boss_two.speed_multiplier, stats_two.phase_2_speed_multiplier * 1.15)
		and is_equal_approx(boss_two.get_effective_gap_time(), base_gap * stats_two.phase_2_pattern_gap_multiplier / 1.15))
	(parts_two["world"] as Node).free()
	# Clamp and invalid values.
	var parts_clamp: Dictionary = _make_world_boss(BOSS_ONE)
	var boss_clamp: BossBase = parts_clamp["boss"]
	await _physics(2)
	boss_clamp.set_aggression(5.0)
	var high: float = boss_clamp.aggression_multiplier
	boss_clamp.set_aggression(0.0)
	var low: float = boss_clamp.aggression_multiplier
	boss_clamp.set_aggression(-3.0)
	var negative: float = boss_clamp.aggression_multiplier
	_check("aggression: clamped to 0.5 - 2.0", high == 2.0 and low == 0.5 and negative == 0.5 and is_equal_approx(boss_clamp.speed_multiplier, 0.5))
	boss_clamp.set_aggression(1.2)
	var nan_applied: bool = boss_clamp.set_aggression(NAN)
	var inf_applied: bool = boss_clamp.set_aggression(INF)
	_check("aggression: NaN and INF are ignored", not nan_applied and not inf_applied and boss_clamp.aggression_multiplier == 1.2)
	(parts_clamp["world"] as Node).free()
	# Timing effect on a real pattern (same seed => same first pattern).
	var normal: Dictionary = await _first_pattern_frames(BOSS_TWO, 1.0)
	var fast: Dictionary = await _first_pattern_frames(BOSS_TWO, 1.15)
	var slow: Dictionary = await _first_pattern_frames(BOSS_TWO, 0.9)
	var same_pattern: bool = normal["id"] == fast["id"] and normal["id"] == slow["id"] and normal["finished"] > 0
	_check("aggression: the same pattern is compared", same_pattern, str(normal["id"]))
	_check("aggression: 1.15 starts and finishes earlier, 0.9 later (gap and pattern timeline)",
		fast["started"] < normal["started"] and normal["started"] < slow["started"] and fast["finished"] < normal["finished"] and normal["finished"] < slow["finished"],
		"start %d/%d/%d finish %d/%d/%d" % [fast["started"], normal["started"], slow["started"], fast["finished"], normal["finished"], slow["finished"]])
	# A call during a running pattern is ignored and does not change its timeline.
	var interrupted: Dictionary = await _first_pattern_frames(BOSS_TWO, 1.0, 1.8)
	_check("aggression: a call during a running pattern is ignored", interrupted["interrupt_applied"] == false
		and interrupted["speed_before"] == interrupted["speed_after"] and interrupted["aggression_after"] == 1.0)
	_check("aggression: the interrupted pattern keeps its exact timeline", interrupted["started"] == normal["started"] and interrupted["finished"] == normal["finished"]
		and interrupted["hitboxes_off"], "finish %d vs %d" % [interrupted["finished"], normal["finished"]])
	_check("aggression: accepted again once the pattern ended", interrupted["idle_apply"] == true)


# --- Bosses 2 and 3 ---

## Exported values of every pattern node, keyed by node name.
func _pattern_signature(boss: BossBase) -> Dictionary:
	var signature: Dictionary = {}
	for child in boss.get_node("Patterns").get_children():
		var values: Dictionary = {}
		for property: Dictionary in child.get_property_list():
			if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and property["usage"] & PROPERTY_USAGE_EDITOR:
				var value: Variant = child.get(property["name"])
				if value is Object or value == null:
					continue
				values[property["name"]] = value
		signature[child.name] = values
	return signature


func _swipe_width(boss: BossBase) -> float:
	var shape_node := boss.get_node("AttackPivot/Hitbox/CollisionShape2D") as CollisionShape2D
	return (shape_node.shape as RectangleShape2D).size.x


func _test_extra_bosses() -> void:
	_clean_state()
	var one: BossBase = BOSS_ONE.instantiate() as BossBase
	var two: BossBase = BOSS_TWO.instantiate() as BossBase
	var three: BossBase = BOSS_THREE.instantiate() as BossBase
	var signatures: Array[Dictionary] = [_pattern_signature(one), _pattern_signature(two), _pattern_signature(three)]
	_check("boss 2: stats", two.stats.boss_id == &"boss_two" and two.stats.max_health == 60 and not two.stats.display_name.is_empty())
	_check("boss 3: stats", three.stats.boss_id == &"boss_three" and three.stats.max_health == 80 and not three.stats.display_name.is_empty())
	_check("bosses: more health than the previous one", one.stats.max_health < two.stats.max_health and two.stats.max_health < three.stats.max_health)
	_check("bosses: different phase-2 configuration", two.stats.phase_2_health_ratio != one.stats.phase_2_health_ratio
		and three.stats.phase_2_speed_multiplier != two.stats.phase_2_speed_multiplier and three.stats.phase_2_pattern_gap_multiplier != two.stats.phase_2_pattern_gap_multiplier)
	_check("bosses: different pattern configuration", signatures[0] != signatures[1] and signatures[1] != signatures[2] and signatures[0] != signatures[2])
	var charge_one: ChargePattern = one.get_node("Patterns/Charge")
	var charge_two: ChargePattern = two.get_node("Patterns/Charge")
	_check("boss 2: emphasizes the charge and a wider swipe", charge_two.weight > charge_one.weight and charge_two.charge_speed > charge_one.charge_speed
		and _swipe_width(two) > _swipe_width(one) and charge_two.weight > (two.get_node("Patterns/Swipe") as SwipePattern).weight)
	var has_swipe: bool = false
	var has_charge: bool = false
	var volleys: Array[ProjectileVolleyPattern] = []
	for child in three.get_node("Patterns").get_children():
		has_swipe = has_swipe or child is SwipePattern
		has_charge = has_charge or child is ChargePattern
		if child is ProjectileVolleyPattern:
			volleys.append(child as ProjectileVolleyPattern)
	var light: ProjectileVolleyPattern = three.get_node("Patterns/VolleyLight")
	var heavy: ProjectileVolleyPattern = three.get_node("Patterns/VolleyHeavy")
	var volley_one: ProjectileVolleyPattern = one.get_node("Patterns/Volley")
	_check("boss 3: combines the three pattern types", has_swipe and has_charge and volleys.size() == 2)
	_check("boss 3: heavier phase-2 volley (more projectiles, wider spread, own projectile stats)", heavy.min_phase == 2 and heavy.projectile_count > volley_one.projectile_count
		and heavy.projectile_count > light.projectile_count and heavy.spread_angle_degrees > volley_one.spread_angle_degrees
		and heavy.projectile_stats != volley_one.projectile_stats and heavy.projectile_stats.speed > volley_one.projectile_stats.speed and heavy.projectile_stats.damage <= 1)
	_check("boss 3: shorter gaps than boss 1 and boss 2", three.stats.pattern_gap_time < two.stats.pattern_gap_time and two.stats.pattern_gap_time < one.stats.pattern_gap_time)
	one.free()
	two.free()
	three.free()
	for scene: PackedScene in [BOSS_TWO, BOSS_THREE]:
		# Applied stats and a completable fight (kill while a pattern runs).
		var parts: Dictionary = _make_world_boss(scene)
		var boss: BossBase = parts["boss"]
		await _physics(2)
		var label: String = String(boss.stats.boss_id)
		_check("%s: health applied from the stats" % label, boss.health.max_health == boss.stats.max_health and boss.health.current_health == boss.stats.max_health)
		var defeated: Array[int] = [0]
		boss.defeated.connect(func(_b: BossBase) -> void: defeated[0] += 1)
		boss.activate(parts["target"])
		var running: bool = await _wait_until(func() -> bool: return boss.state == BossBase.State.PATTERN, 600)
		_check("%s: starts a pattern when activated" % label, running)
		_hit(boss, boss.stats.max_health * 2)
		_check("%s: lethal damage defeats it exactly once" % label, defeated[0] == 1 and boss.state == BossBase.State.DEAD)
		_hit(boss, 5)
		await _physics(5)
		_check("%s: no hitbox active and no second defeat" % label, _all_hitboxes_off(boss) and defeated[0] == 1 and not boss.hurtbox.enabled)
		(parts["world"] as Node).free()
		# Phase transition.
		var phase_parts: Dictionary = _make_world_boss(scene)
		var phase_boss: BossBase = phase_parts["boss"]
		await _physics(2)
		var phases: Array[int] = []
		phase_boss.phase_changed.connect(func(phase: int) -> void: phases.append(phase))
		phase_boss.activate(phase_parts["target"])
		await _physics(5)
		var needed: int = phase_boss.stats.max_health - int(floor(phase_boss.stats.max_health * phase_boss.stats.phase_2_health_ratio))
		_hit(phase_boss, needed - 1)
		_check("%s: no transition before the threshold" % label, phase_boss.state != BossBase.State.PHASE_TRANSITION and phase_boss.current_phase == 1)
		_hit(phase_boss, 1)
		_check("%s: transition starts at the threshold" % label, phase_boss.state == BossBase.State.PHASE_TRANSITION and _all_hitboxes_off(phase_boss))
		await _physics(int(ceil(phase_boss.stats.phase_transition_time * 60.0)) + 3)
		_check("%s: phase 2 starts once with its multipliers" % label, phase_boss.current_phase == 2 and phases == [2]
			and is_equal_approx(phase_boss.speed_multiplier, phase_boss.stats.phase_2_speed_multiplier))
		(phase_parts["world"] as Node).free()


# --- LevelBase adaptive application ---

func _enemy_counts(level: LevelBase) -> Dictionary:
	var counts: Dictionary = {"melee": 0, "fast": 0, "ranged": 0}
	for child in level.get_node("Content").get_children():
		if child.scene_file_path.ends_with("melee_enemy.tscn"):
			counts["melee"] += 1
		elif child.scene_file_path.ends_with("fast_enemy.tscn"):
			counts["fast"] += 1
		elif child.scene_file_path.ends_with("ranged_enemy.tscn"):
			counts["ranged"] += 1
	counts["total"] = counts["melee"] + counts["fast"] + counts["ranged"]
	return counts


func _test_level_adaptive() -> void:
	for level_number in [2, 3]:
		var designed: Dictionary = DESIGNED[level_number]
		var baseline_total: int = designed["melee"] + designed["fast"] + designed["ranged"]
		var baseline_names: Array[String] = []
		for profile in PROFILES:
			_set_profile(profile)
			var scene := load(LEVEL_PATHS[level_number]) as PackedScene
			var level := scene.instantiate() as LevelBase
			var extras: Array[Node] = []
			for path: Variant in level.variant_groups["corrupted"]:
				extras.append(level.get_node(NodePath(path)))
			var all_before: int = _enemy_counts(level)["total"]
			add_child(level)
			await _physics(3)
			var label: String = "level %d / %s" % [level_number, profile]
			var applied: AdaptiveResult = level.get_applied_adaptive_result()
			_check("%s: applied result matches the profile" % label, applied != null and applied.profile == profile)
			_check("%s: boss aggression %.2f" % [label, PROFILE_AGGRESSION[profile]], is_equal_approx(level.boss.aggression_multiplier, PROFILE_AGGRESSION[profile])
				and is_equal_approx(level.boss.speed_multiplier, PROFILE_AGGRESSION[profile]))
			var counts: Dictionary = _enemy_counts(level)
			var expected_total: int = baseline_total + (designed["extras"] if profile == "corrupt" else 0)
			_check("%s: enemy count %d (all variants in the scene: %d)" % [label, expected_total, all_before], counts["total"] == expected_total and all_before == baseline_total + designed["extras"],
				str(counts))
			_check("%s: baseline per-type counts untouched" % label, counts["melee"] >= designed["melee"] and counts["fast"] >= designed["fast"] and counts["ranged"] >= designed["ranged"])
			var gone: bool = true
			for extra in extras:
				if profile == "corrupt":
					gone = gone and is_instance_valid(extra) and extra.is_inside_tree()
				else:
					gone = gone and (not is_instance_valid(extra) or (not extra.is_inside_tree() and extra.is_queued_for_deletion()))
			_check("%s: corrupted extras %s" % [label, "kept" if profile == "corrupt" else "removed from the tree"], gone)
			var names: Array[String] = []
			for child in level.get_node("Content").get_children():
				if not String(child.name).begins_with("Extra"):
					names.append(String(child.name))
			if baseline_names.is_empty():
				baseline_names = names
			_check("%s: every baseline node is present" % label, names == baseline_names)
			if profile != "corrupt":
				await _physics(3)
				var freed: bool = true
				for extra in extras:
					freed = freed and not is_instance_valid(extra)
				var strays: int = 0
				for node in get_tree().get_nodes_in_group("enemies"):
					if String(node.name).begins_with("Extra"):
						strays += 1
				_check("%s: removed extras are freed and no longer in any group" % label, freed and strays == 0)
			level.free()
			_free_fragments()
	# Applied once: a later profile change does not alter the loaded level.
	_set_profile("neutral")
	var once_level: LevelBase = _make_level(2)
	await _physics(3)
	var enemies_before: int = _enemy_counts(once_level)["total"]
	GameState.set_adaptive_profile("corrupt")
	await _physics(30)
	_check("applied once: aggression and enemies do not change after load", once_level.boss.aggression_multiplier == 1.0
		and _enemy_counts(once_level)["total"] == enemies_before and once_level.get_applied_adaptive_result().profile == "neutral")
	once_level.free()
	# Level 1 (baseline levels) keep their behavior with neutral defaults.
	_clean_state()
	var level_one: LevelBase = _make_level(1)
	await _physics(3)
	_check("level 1: neutral defaults leave the boss unchanged and the intro hidden", level_one.boss.aggression_multiplier == 1.0
		and not level_one.is_intro_visible() and not level_one.background.visible and _enemy_counts(level_one)["total"] == 6)
	level_one.free()
	_clean_state()


func _test_intro_and_unknown_variant() -> void:
	for profile in PROFILES:
		_set_profile(profile)
		var level: LevelBase = _make_level(2)
		await _physics(2)
		var variant: String = level.get_applied_adaptive_result().narrative_variant
		_check("intro (%s): the line of '%s' is shown" % [profile, variant], level.is_intro_visible() and level.intro_label.text == String(level.intro_lines[variant]))
		level.free()
	_set_profile("compassionate")
	var timed: LevelBase = (load(LEVEL_PATHS[3]) as PackedScene).instantiate() as LevelBase
	timed.intro_duration = 0.25
	add_child(timed)
	await _physics(3)
	var shown_first: bool = timed.is_intro_visible()
	await _wait_until(func() -> bool: return not timed.is_intro_visible(), 120)
	_check("intro: visible, then hidden after intro_duration", shown_first and not timed.is_intro_visible())
	_check("intro: does not pause the tree or lock the player", not get_tree().paused and not timed.player.is_input_locked())
	timed.free()
	var empty: LevelBase = (load(LEVEL_PATHS[2]) as PackedScene).instantiate() as LevelBase
	empty.intro_lines = {}
	add_child(empty)
	await _physics(2)
	_check("intro: nothing is shown without an entry", not empty.is_intro_visible())
	empty.free()
	var partial: LevelBase = (load(LEVEL_PATHS[2]) as PackedScene).instantiate() as LevelBase
	partial.intro_lines = {"burden": "solo otra variante"}
	add_child(partial)
	await _physics(2)
	_check("intro: nothing is shown when only other variants have entries", not partial.is_intro_visible())
	partial.free()
	# Unknown / corrupt variant strings from a custom config: no error, every variant group removed.
	_clean_state()
	var weird_config: AdaptiveConfig = (GameState.get_adaptive_config() as AdaptiveConfig).duplicate(true) as AdaptiveConfig
	weird_config.params_neutral.encounter_variant = "does_not_exist"
	weird_config.params_neutral.narrative_variant = "???"
	weird_config.params_neutral.ending_variant = "ending_unknown"
	weird_config.params_neutral.boss_aggression = 1.0
	GameState.set_adaptive_config(weird_config)
	var weird: LevelBase = _make_level(3)
	await _physics(3)
	var counts: Dictionary = _enemy_counts(weird)
	_check("unknown variant: loads, no extras and no intro", counts["total"] == 9 and not weird.is_intro_visible() and weird.get_applied_adaptive_result().encounter_variant == "does_not_exist")
	weird.free()
	_clean_state()


# --- Completion of the last level ---

func _test_completion_last_level() -> void:
	_clean_state()
	var level: LevelBase = _make_level(3)
	await _physics(3)
	level.advance_delay = 0.2
	level.refine_wait_timeout = 0.5
	_check("level 3: next scene is the ending (not a level id)", level.next_scene_id == "ending" and not DEFAULT_REGISTRY.level_scene_ids.has(level.next_scene_id))
	_check("level 3: fresh arrival state", GameState.current_level == 3 and GameState.checkpoint == "level_3_start" and not GameState.is_game_completed())
	_check("level 3: decision flow evaluates at the ending", level.decision_flow.refinement_point == AdaptiveInput.POINT_ENDING)
	var fake := FakeRefiner.new()
	level.add_child(fake)
	level.decision_flow.refiner = fake
	var completed: Array[int] = []
	level.level_completed.connect(func(number: int) -> void: completed.append(number))
	_kill_boss(level)
	var spawned: bool = await _wait_until(func() -> bool: return _find_fragment() != null, 120)
	_check("level 3: boss defeat spawns the fragment", spawned)
	level.player.global_position = _find_fragment().global_position
	var opened: bool = await _wait_until(func() -> bool: return level.get_node("DecisionPanel").is_open(), 60)
	_check("level 3: panel opens", opened)
	_check("level 3: no completion before the decision", completed.is_empty() and not GameState.is_game_completed())
	level.get_node("DecisionPanel").keep_button.pressed.emit()
	_check("level 3: the refiner is asked for the 'ending' point", fake.points == [AdaptiveInput.POINT_ENDING], str(fake.points))
	await _wait_until(func() -> bool: return not completed.is_empty(), 180)
	await _physics(3)
	_check("level 3: completion emitted once", completed == [3])
	_check("level 3: requests the ending scene", SceneManager.last_requested_scene_id == "ending" and started_signals == ["ending"])
	_check("level 3: GameState has the ending marker and keeps level 3", GameState.checkpoint == "ending" and GameState.current_level == 3 and GameState.is_game_completed())
	var saved: Dictionary = _saved_json()
	var keys_ok: bool = saved.keys().size() == SAVE_KEYS.size() and SAVE_KEYS.all(func(key: String) -> bool: return saved.has(key))
	_check("level 3: the save has exactly seven keys and the marker", keys_ok and saved.get("checkpoint", "") == "ending" and int(saved.get("current_level", 0)) == 3, str(saved.keys()))
	await _physics(60)
	_check("level 3: advances exactly once", started_signals.size() == 1 and completed.size() == 1)
	level.free()
	_free_fragments()
	await _wait_idle()
	# Level 2 evaluates at 'after_decision' and goes to level 3 (12a rules).
	_clean_state()
	var level_two: LevelBase = _make_level(2)
	await _physics(3)
	var fake_two := FakeRefiner.new()
	level_two.add_child(fake_two)
	level_two.decision_flow.refiner = fake_two
	level_two.advance_delay = 0.2
	_kill_boss(level_two)
	await _wait_until(func() -> bool: return _find_fragment() != null, 120)
	level_two.player.global_position = _find_fragment().global_position
	await _wait_until(func() -> bool: return level_two.get_node("DecisionPanel").is_open(), 60)
	level_two.get_node("DecisionPanel").release_button.pressed.emit()
	await _wait_until(func() -> bool: return SceneManager.last_requested_scene_id != "", 180)
	_check("level 2: evaluation point stays after_decision", fake_two.points == [AdaptiveInput.POINT_AFTER_DECISION])
	_check("level 2: advances to level 3 with the 12a rules", SceneManager.last_requested_scene_id == "level_3" and GameState.current_level == 3
		and GameState.checkpoint == "level_3_start" and not GameState.is_game_completed())
	level_two.free()
	_free_fragments()
	await _wait_idle()
	# A rejected ending request keeps the player in control and does not leave the marker behind.
	_clean_state()
	var broken := _test_registry()
	broken.scenes.erase("ending")
	SceneManager.set_registry(broken)
	var level_rejected: LevelBase = _make_level(3)
	await _physics(3)
	level_rejected.advance_delay = 0.1
	GameState.record_decision("fragment_level_3", "boss_three", 3, GameState.CHOICE_RELEASED)
	_kill_boss(level_rejected)
	await _wait_until(func() -> bool: return level_rejected.is_completed, 120)
	await _physics(5)
	_check("level 3: rejected ending keeps control, marker rolled back", level_rejected.is_completed and not level_rejected.player.is_input_locked()
		and not SceneManager.is_transitioning() and GameState.checkpoint == "level_3_start" and not GameState.is_game_completed()
		and _saved_json().get("checkpoint", "") == "level_3_start")
	level_rejected.free()
	_free_fragments()
	_clean_state()


func _test_completed_game_entry() -> void:
	_clean_state()
	GameState.set_current_level(3)
	GameState.set_checkpoint(GameState.CHECKPOINT_ENDING)
	GameState.record_decision("fragment_level_1", "placeholder_boss", 1, GameState.CHOICE_RELEASED)
	GameState.save_to_disk()
	var state_before: Dictionary = GameState.to_dict()
	var save_before: String = _read_file(TEST_SAVE)
	for level_number in [3, 2, 1]:
		var level: LevelBase = _make_level(level_number)
		await _physics(10)
		var spawn: Vector2 = level.spawn_point.global_position
		_check("completed game (level %d): fresh arrival, no restore inside the level" % level_number, level.player.global_position.distance_to(spawn) < 40.0)
		_check("completed game (level %d): GameState and save unchanged" % level_number, GameState.to_dict() == state_before and _read_file(TEST_SAVE) == save_before)
		_check("completed game (level %d): autosave suspended while the level lives" % level_number, not GameState.autosave_enabled)
		# Touching a checkpoint must not overwrite the marker on disk.
		var checkpoints: Array[Checkpoint] = level.get_level_checkpoints()
		level.player.global_position = checkpoints[1].global_position
		await _physics(10)
		_check("completed game (level %d): touching a checkpoint never rewrites the save file" % level_number, _read_file(TEST_SAVE) == save_before)
		level.free()
		_check("completed game (level %d): autosave restored on exit" % level_number, GameState.autosave_enabled)
		GameState.load_from_dict(state_before)
		GameState.autosave_enabled = true
	_clean_state()


# --- Main menu ---

func _menu_continue(slot_level: int, checkpoint_id: String, registry: SceneRegistry) -> Dictionary:
	_clean_state()
	if registry != null:
		SceneManager.set_registry(registry)
	GameState.set_current_level(slot_level)
	GameState.set_checkpoint(checkpoint_id)
	GameState.save_to_disk()
	GameState.start_new_game()
	var menu: MainMenu = MAIN_MENU_SCENE.instantiate() as MainMenu
	add_child(menu)
	await _physics(2)
	menu.continue_button.pressed.emit()
	await _physics(2)
	var result := {"scene": SceneManager.last_requested_scene_id, "message": menu.message_label.text, "disabled": menu.continue_button.disabled}
	menu.free()
	await _wait_idle()
	return result


func _test_main_menu() -> void:
	var completed: Dictionary = await _menu_continue(3, "ending", null)
	_check("menu: Continuar with a completed save requests 'ending'", completed["scene"] == "ending", str(completed))
	var normal: Dictionary = await _menu_continue(2, "level_2_start", null)
	_check("menu: Continuar with a normal save requests the saved level", normal["scene"] == "level_2", str(normal))
	var broken := _test_registry()
	broken.scenes.erase("ending")
	var fallback: Dictionary = await _menu_continue(3, "ending", broken)
	_check("menu: missing ending scene falls back to the saved level and says so", fallback["scene"] == "level_3" and not String(fallback["message"]).is_empty(), str(fallback))
	var missing_all := _test_registry()
	missing_all.scenes.erase("ending")
	missing_all.scenes.erase("level_3")
	var failed: Dictionary = await _menu_continue(3, "ending", missing_all)
	_check("menu: nothing can be opened -> safe message, no crash", failed["scene"] == "" and not String(failed["message"]).is_empty(), str(failed))
	_clean_state()


# --- Ending scene ---

func _ending_state(profile: String) -> void:
	_clean_state()
	var choices: Array[String] = []
	match profile:
		"compassionate":
			choices = [GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED]
		"corrupt":
			choices = [GameState.CHOICE_KEPT, GameState.CHOICE_KEPT, GameState.CHOICE_KEPT]
		_:
			choices = [GameState.CHOICE_RELEASED, GameState.CHOICE_KEPT, GameState.CHOICE_RELEASED]
	for index in choices.size():
		GameState.record_decision("fragment_level_%d" % (index + 1), "boss_%d" % (index + 1), index + 1, choices[index])
	GameState.refresh_adaptive_profile(AdaptiveInput.POINT_ENDING)
	GameState.set_current_level(3)
	GameState.set_checkpoint(GameState.CHECKPOINT_ENDING)
	GameState.save_to_disk()


func _test_ending_scene() -> void:
	for profile in PROFILES:
		_ending_state(profile)
		_check("ending (%s): the local classifier produces the profile" % profile, GameState.adaptive_profile == profile, GameState.adaptive_profile)
		var before: Dictionary = GameState.to_dict()
		var save_before: String = _read_file(TEST_SAVE)
		var ending: EndingController = ENDING_SCENE.instantiate() as EndingController
		add_child(ending)
		await _physics(3)
		var expected_variant: String = PROFILE_ENDING[profile]
		_check("ending (%s): shows %s" % [profile, expected_variant], ending.shown_variant == expected_variant
			and ending.ending_label.text == String(ending.ending_texts[expected_variant]) and not ending.ending_label.text.is_empty())
		_check("ending (%s): soul counts" % profile, ending.released_label.text == ending.souls_released_format % GameState.souls_released
			and ending.kept_label.text == ending.souls_kept_format % GameState.souls_kept, "%s / %s" % [ending.released_label.text, ending.kept_label.text])
		_check("ending (%s): narrative variant in small text" % profile, ending.narrative_label.visible
			and ending.narrative_label.text == ending.narrative_format % GameState.get_adaptive_result().narrative_variant)
		_check("ending (%s): focus on the back button" % profile, ending.back_button.has_focus())
		_check("ending (%s): GameState and save untouched" % profile, GameState.to_dict() == before and _read_file(TEST_SAVE) == save_before and GameState.is_game_completed())
		ending.back_button.pressed.emit()
		_check("ending (%s): the button goes to the main menu" % profile, SceneManager.last_requested_scene_id == "main_menu" and started_signals == ["main_menu"])
		ending.back_button.pressed.emit()
		_check("ending (%s): ignored during a transition" % profile, started_signals.size() == 1)
		ending.free()
		await _wait_idle()
		_check("ending (%s): still untouched after leaving" % profile, GameState.to_dict() == before and _read_file(TEST_SAVE) == save_before)
	# Texts are distinct, unknown variant, empty state, hidden narrative text.
	var probe: EndingController = ENDING_SCENE.instantiate() as EndingController
	var texts: Array = probe.ending_texts.values()
	_check("ending: three distinct texts", texts.size() == 3 and texts[0] != texts[1] and texts[1] != texts[2] and texts[0] != texts[2])
	probe.free()
	_clean_state()
	var weird_config: AdaptiveConfig = (GameState.get_adaptive_config() as AdaptiveConfig).duplicate(true) as AdaptiveConfig
	weird_config.params_neutral.ending_variant = "ending_unknown"
	GameState.set_adaptive_config(weird_config)
	var unknown: EndingController = ENDING_SCENE.instantiate() as EndingController
	add_child(unknown)
	await _physics(2)
	_check("ending: an unknown variant falls back to the neutral text", unknown.shown_variant == "ending_neutral" and unknown.ending_label.text == String(unknown.ending_texts["ending_neutral"]))
	unknown.free()
	_clean_state()
	var empty_state: EndingController = ENDING_SCENE.instantiate() as EndingController
	add_child(empty_state)
	await _physics(2)
	_check("ending: an empty/default state works (neutral)", empty_state.shown_variant == "ending_neutral" and empty_state.released_label.text == empty_state.souls_released_format % 0
		and empty_state.kept_label.text == empty_state.souls_kept_format % 0)
	empty_state.free()
	var no_texts: EndingController = ENDING_SCENE.instantiate() as EndingController
	no_texts.ending_texts = {}
	no_texts.show_narrative_variant = false
	add_child(no_texts)
	await _physics(2)
	_check("ending: generic text when the dictionary is empty; narrative text can be hidden", no_texts.ending_label.text == no_texts.fallback_text and not no_texts.narrative_label.visible)
	no_texts.free()
	_clean_state()


# --- Reach measurement (real Player simulation) ---

## Runs at full speed off a floor ending at x = 0 and jumps at the edge (jump held). Dash at
## `dash_delay` seconds after the jump if >= 0. Returns {distance, height}.
func _measure_jump(player: Player, dash_delay: float) -> Dictionary:
	_release_actions()
	player.global_position = Vector2(-300.0, FLOOR_Y - PLAYER_HALF_HEIGHT)
	player.velocity = Vector2.ZERO
	await _physics(30)
	Input.action_press("move_right")
	while player.global_position.x < -4.0:
		await get_tree().physics_frame
	var start: Vector2 = player.global_position
	var top_y: float = start.y
	Input.action_press("jump")
	var elapsed: float = 0.0
	var dashed: bool = false
	while elapsed < 3.0:
		await get_tree().physics_frame
		elapsed += 1.0 / Engine.physics_ticks_per_second
		top_y = minf(top_y, player.global_position.y)
		if dash_delay >= 0.0 and not dashed and elapsed >= dash_delay:
			Input.action_press("dash")
			dashed = true
		elif dashed:
			Input.action_release("dash")
		if elapsed > 0.1 and player.global_position.y >= FLOOR_Y - PLAYER_HALF_HEIGHT and player.velocity.y >= 0.0:
			break
	var result := {"distance": player.global_position.x - start.x, "height": start.y - top_y}
	_release_actions()
	return result


func _measure_reach() -> void:
	_clean_state()
	var arena := Node2D.new()
	add_child(arena)
	_add_floor(arena, -4000.0, 0.0)
	var player := PLAYER_SCENE.instantiate() as Player
	arena.add_child(player)
	await _physics(2)
	var plain: Dictionary = await _measure_jump(player, -1.0)
	var default_dash: Dictionary = await _measure_jump(player, DASH_DELAY_DEFAULT)
	var best: float = 0.0
	var best_delay: float = 0.0
	var sweep: PackedStringArray = PackedStringArray()
	for delay in DASH_SWEEP:
		var sample: Dictionary = await _measure_jump(player, delay)
		sweep.append("%.1fs=%.0f" % [delay, sample["distance"]])
		if sample["distance"] > best:
			best = sample["distance"]
			best_delay = delay
	var coyote_reach: float = player.stats.coyote_time * player.stats.max_speed
	reach = {
		"jump": plain["distance"], "height": plain["height"], "dash": default_dash["distance"], "dash_max": best,
		"generous_jump_limit": plain["distance"] + PLAYER_HALF_WIDTH * 2.0 + coyote_reach,
	}
	print("MEASURED (real Player simulation): jump alone %.1f px | max jump height %.1f px | jump+dash (dash at %.1fs) %.1f px | best jump+dash %.1f px (dash at %.1fs) | edge-hugging jump limit %.1f px" % [
		reach["jump"], reach["height"], DASH_DELAY_DEFAULT, reach["dash"], reach["dash_max"], best_delay, reach["generous_jump_limit"]])
	print("DASH SWEEP: %s" % ", ".join(sweep))
	_check("reach: sane measurements", reach["jump"] > 150.0 and reach["height"] > 60.0 and reach["dash"] > reach["jump"] and reach["dash_max"] >= reach["dash"])
	arena.free()
	_release_actions()


## Real physics: every distinct ground gap of the three levels is crossed (or not) by a simulated player.
func _test_gap_crossings() -> void:
	var widths: Array[float] = []
	for level_number in [1, 2, 3]:
		var level := (load(LEVEL_PATHS[level_number]) as PackedScene).instantiate() as LevelBase
		var floors: Array[Dictionary] = []
		for surface in _surfaces_of(level):
			if absf(surface["top"] - GROUND_TOP) < 0.5:
				floors.append(surface)
		floors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["left"] < b["left"])
		for index in range(1, floors.size()):
			var width: float = floors[index]["left"] - floors[index - 1]["right"]
			if width > 0.0 and not widths.has(width):
				widths.append(width)
		level.free()
	widths.sort()
	for width in widths:
		var plain: bool = width <= 0.85 * reach["jump"]
		for use_dash in [false, true]:
			_clean_state()
			var world := Node2D.new()
			add_child(world)
			_add_floor(world, -4000.0, 0.0)
			_add_floor(world, width, width + 2000.0)
			var runner := PLAYER_SCENE.instantiate() as Player
			world.add_child(runner)
			await _physics(2)
			await _measure_jump(runner, DASH_DELAY_DEFAULT if use_dash else -1.0)
			await _physics(60)
			var crossed: bool = runner.global_position.x > width and runner.global_position.y < FLOOR_Y
			var expected: bool = plain or use_dash
			_check("real crossing: %.0f px gap, %s -> %s" % [width, "jump + dash" if use_dash else "jump alone", "crosses" if crossed else "falls"],
				crossed == expected, "x %.0f y %.0f" % [runner.global_position.x, runner.global_position.y])
			_release_actions()
			world.free()


# --- Static reachability analysis ---

func _rect_of(node: Node2D) -> Rect2:
	var size: Vector2 = node.get("size")
	return Rect2(node.position - size * 0.5, size)


## Walkable surfaces: platform tops (walls and the arena ceiling are not walkable).
func _surfaces_of(level: LevelBase) -> Array[Dictionary]:
	var surfaces: Array[Dictionary] = []
	for child in level.get_node("Content").get_children():
		if not child is PlaceholderPlatform or child.scene_file_path.ends_with("placeholder_wall.tscn") or String(child.name).contains("Ceiling"):
			continue
		var rect: Rect2 = _rect_of(child as Node2D)
		surfaces.append({"name": String(child.name), "left": rect.position.x, "right": rect.end.x, "top": rect.position.y})
	return surfaces


func _solid_rects(level: LevelBase) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for child in level.get_node("Content").get_children():
		if child is PlaceholderPlatform or child is ArenaGate:
			rects.append(_rect_of(child as Node2D))
	return rects


func _surface_index_at(surfaces: Array[Dictionary], x: float, y: float, tolerance: float) -> int:
	for index in surfaces.size():
		var surface: Dictionary = surfaces[index]
		if x >= surface["left"] and x <= surface["right"] and absf(surface["top"] - y) <= tolerance:
			return index
	return -1


## Edges follow the task rules: rise <= 0.9 * max jump height and horizontal gap <= 0.9 * jump reach ("jump")
## or <= 0.9 * jump+dash reach ("dash"). Falling is allowed within the same horizontal reach.
func _edge_kind(from_surface: Dictionary, to_surface: Dictionary, dash_reach: float) -> String:
	var rise: float = from_surface["top"] - to_surface["top"]
	if rise > 0.9 * reach["height"]:
		return ""
	var gap: float = maxf(0.0, maxf(to_surface["left"] - from_surface["right"], from_surface["left"] - to_surface["right"]))
	if gap <= 0.9 * reach["jump"]:
		return "jump"
	if gap <= 0.9 * dash_reach:
		return "dash"
	return ""


## Minimum number of dash edges needed from `start` to `target` (-1 if unreachable), 0-1 BFS.
func _min_dashes(surfaces: Array[Dictionary], start: int, target: int, allow_dash: bool, dash_reach: float) -> int:
	var best: Array[int] = []
	best.resize(surfaces.size())
	best.fill(-1)
	var queue: Array[int] = [start]
	best[start] = 0
	var head: int = 0
	while head < queue.size():
		var current: int = queue[head]
		head += 1
		for other in surfaces.size():
			if other == current:
				continue
			var kind: String = _edge_kind(surfaces[current], surfaces[other], dash_reach)
			if kind.is_empty() or (kind == "dash" and not allow_dash):
				continue
			var cost: int = best[current] + (1 if kind == "dash" else 0)
			if best[other] == -1 or cost < best[other]:
				best[other] = cost
				queue.append(other)
	return best[target]


func _encounter_rect(level: LevelBase) -> Rect2:
	var encounter: Node2D = level.get_node("Content/Encounter")
	var shape_node := encounter.get_node("CollisionShape2D") as CollisionShape2D
	var rect: Rect2 = shape_node.shape.get_rect()
	return Rect2(encounter.position + shape_node.position + rect.position, rect.size)


func _test_reachability(level_number: int) -> void:
	var level := (load(LEVEL_PATHS[level_number]) as PackedScene).instantiate() as LevelBase
	var tag: String = "level %d" % level_number
	var content: Node2D = level.get_node("Content")
	var surfaces: Array[Dictionary] = _surfaces_of(level)
	var solids: Array[Rect2] = _solid_rects(level)
	_check("%s: Content sits at the origin (local positions are world positions)" % tag, content.position == Vector2.ZERO and level.position == Vector2.ZERO)
	# Exports.
	var drop: SoulFragmentDrop = level.fragment_drop
	_check("%s: gate/encounter/boss/drop exports are assigned" % tag, level.boss != null and level.encounter != null and drop != null and level.arena_gates.size() >= 1
		and drop.fragment_data != null and drop.fragment_scene != null and drop.boss == level.boss and level.encounter.boss == level.boss
		and (level.get_node("DecisionFlow") as DecisionFlow).drop == drop and not level.next_scene_id.is_empty())
	_check("%s: fragment data matches the level and boss" % tag, drop.fragment_data.level == level_number and drop.fragment_data.fragment_id == "fragment_level_%d" % level_number
		and String(level.boss.stats.boss_id) == drop.fragment_data.boss_id if level_number >= 2 else drop.fragment_data.boss_id == "placeholder_boss")
	# Start, arena checkpoint, boss floor.
	var spawn: Vector2 = level.get_node("SpawnPoint").position
	var start_index: int = -1
	for index in surfaces.size():
		var surface: Dictionary = surfaces[index]
		if spawn.x >= surface["left"] and spawn.x <= surface["right"] and surface["top"] >= spawn.y and (start_index == -1 or surface["top"] < surfaces[start_index]["top"]):
			start_index = index
	var checkpoints: Array[Node] = []
	var arena_cp: Node2D = null
	var arena_order: int = -1
	for child in content.get_children():
		if child is Checkpoint:
			checkpoints.append(child)
			if (child as Checkpoint).order > arena_order:
				arena_order = (child as Checkpoint).order
				arena_cp = child as Node2D
	var arena_index: int = _surface_index_at(surfaces, arena_cp.position.x, arena_cp.position.y, 1.0)
	var boss_node: Node2D = level.boss
	var boss_index: int = _surface_index_at(surfaces, boss_node.position.x, boss_node.position.y + BOSS_HALF_SIZE.y, 1.0)
	_check("%s: start, arena checkpoint and boss stand on surfaces" % tag, start_index >= 0 and arena_index >= 0 and boss_index >= 0, "%d/%d/%d" % [start_index, arena_index, boss_index])
	_check("%s: checkpoint ids: start, mid(s), arena (highest order)" % tag, String((checkpoints[0] as Checkpoint).checkpoint_id) == "level_%d_start" % level_number
		and String((arena_cp as Checkpoint).checkpoint_id) == "level_%d_arena" % level_number and checkpoints.size() >= 3 - (1 if level_number == 1 else 0))
	# Reachability.
	var dash_reach: float = reach["dash_max"]
	var with_dash: int = _min_dashes(surfaces, start_index, arena_index, true, dash_reach)
	var jump_only: int = _min_dashes(surfaces, start_index, arena_index, false, dash_reach)
	var boss_with_dash: int = _min_dashes(surfaces, start_index, boss_index, true, dash_reach)
	_check("%s: arena checkpoint and boss arena are reachable from the start" % tag, with_dash >= 0 and boss_with_dash >= 0, "min dashes %d / %d" % [with_dash, boss_with_dash])
	_check("%s: every path needs at least one dash (not reachable by jumps alone)" % tag, with_dash >= 1 and jump_only == -1, "min dashes on the best path: %d" % with_dash)
	# Gaps between ground-level floors.
	var floors: Array[Dictionary] = []
	for surface in surfaces:
		if absf(surface["top"] - GROUND_TOP) < 0.5:
			floors.append(surface)
	floors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["left"] < b["left"])
	var kill_zones: Array[Rect2] = []
	for child in content.get_children():
		if child is KillZone:
			kill_zones.append(_rect_of(child as Node2D))
	var plain_gaps: int = 0
	var dash_gaps: int = 0
	var report: PackedStringArray = PackedStringArray()
	for index in range(1, floors.size()):
		var gap_left: float = floors[index - 1]["right"]
		var gap_right: float = floors[index]["left"]
		var width: float = gap_right - gap_left
		if width <= 0.0:
			continue
		var kind: String = "INVALID"
		if width <= 0.85 * reach["jump"]:
			kind = "plain jump"
			plain_gaps += 1
		elif width >= 1.1 * reach["jump"] and width <= 0.9 * reach["dash"]:
			kind = "dash (comfortable)"
			dash_gaps += 1
		elif width >= 1.1 * reach["jump"] and width <= 0.9 * reach["dash_max"]:
			kind = "dash (tight: needs a well-timed dash)"
			dash_gaps += 1
		var covered: bool = false
		for zone in kill_zones:
			covered = covered or (zone.position.x <= gap_left and zone.end.x >= gap_right and zone.position.y > GROUND_TOP)
		_check("%s: gap %.0f-%.0f (%.0f px = %.0f%% of jump, %.0f%% of jump+dash) is '%s' with a KillZone below" % [tag, gap_left, gap_right, width,
			100.0 * width / reach["jump"], 100.0 * width / reach["dash"], kind], kind != "INVALID" and covered)
		if kind.begins_with("dash"):
			_check("%s: dash gap %.0f cannot be cleared by an edge-hugging plain jump (limit %.0f)" % [tag, width, reach["generous_jump_limit"]], width > reach["generous_jump_limit"])
		report.append("%.0fpx %s" % [width, kind])
	print("GAP CLASSIFICATION %s: %s" % [tag, "; ".join(report)])
	if level_number >= 2:
		_check("%s: at least two dash-required gaps and one plain jump gap" % tag, dash_gaps >= 2 and plain_gaps >= (1 if level_number == 2 else 0), "dash %d plain %d" % [dash_gaps, plain_gaps])
		_check("%s: every dash gap is comfortable (<= 90%% of the measured jump+dash)" % tag, str(report).find("tight") == -1)
	else:
		_check("%s: at least one dash-required gap" % tag, dash_gaps >= 1)
	# Vertical steps.
	var worst_step: float = 0.0
	for surface in surfaces:
		if absf(surface["top"] - GROUND_TOP) < 0.5:
			continue
		var smallest: float = INF
		for other in surfaces:
			if other == surface:
				continue
			var rise: float = other["top"] - surface["top"]
			var gap: float = maxf(0.0, maxf(surface["left"] - other["right"], other["left"] - surface["right"]))
			if rise > 0.0 and gap <= 0.9 * reach["jump"]:
				smallest = minf(smallest, rise)
		worst_step = maxf(worst_step, smallest if smallest != INF else 9999.0)
	_check("%s: vertical steps <= 85%% of the measured jump height (worst %.0f <= %.0f)" % [tag, worst_step, 0.85 * reach["height"]], worst_step <= 0.85 * reach["height"])
	# Nothing inside solids; enemies grounded.
	var inside: PackedStringArray = PackedStringArray()
	var ungrounded: PackedStringArray = PackedStringArray()
	var melee: int = 0
	var fast: int = 0
	var ranged: int = 0
	var extras: int = 0
	for child in content.get_children():
		var half: Vector2 = Vector2.ZERO
		var is_enemy: bool = false
		if child.scene_file_path.ends_with("melee_enemy.tscn"):
			melee += 1
			is_enemy = true
		elif child.scene_file_path.ends_with("fast_enemy.tscn"):
			fast += 1
			is_enemy = true
		elif child.scene_file_path.ends_with("ranged_enemy.tscn"):
			ranged += 1
			is_enemy = true
		if is_enemy:
			half = ENEMY_HALF_SIZE
			if String(child.name).begins_with("Extra"):
				extras += 1
			var enemy_node := child as Node2D
			if _surface_index_at(surfaces, enemy_node.position.x, enemy_node.position.y + half.y, 1.0) < 0:
				ungrounded.append(String(child.name))
		elif child == level.boss:
			half = BOSS_HALF_SIZE
		elif child is Checkpoint:
			half = Vector2(1.0, 1.0)
		if half == Vector2.ZERO:
			continue
		var center: Vector2 = (child as Node2D).position
		if child is Checkpoint:
			center += (child as Checkpoint).respawn_offset
		var body := Rect2(center - half, half * 2.0)
		for solid in solids:
			if solid.intersects(body):
				inside.append(String(child.name))
	_check("%s: no checkpoint, enemy or boss inside a solid" % tag, inside.is_empty(), str(inside))
	_check("%s: every enemy stands on a surface" % tag, ungrounded.is_empty(), str(ungrounded))
	var designed: Dictionary = DESIGNED[level_number]
	_check("%s: enemy counts %d melee / %d fast / %d ranged (+%d corrupted extras)" % [tag, designed["melee"] + (0), designed["fast"], designed["ranged"], designed["extras"]],
		melee + fast + ranged - extras == designed["melee"] + designed["fast"] + designed["ranged"] and extras == designed["extras"],
		"scene total %d melee %d fast %d ranged %d extras %d" % [melee + fast + ranged, melee, fast, ranged, extras])
	if level_number >= 2:
		var ranged_level_one: int = DESIGNED[1]["ranged"]
		_check("%s: more ranged enemies than level 1" % tag, DESIGNED[level_number]["ranged"] > ranged_level_one)
	# Arena geometry.
	var trigger: Rect2 = _encounter_rect(level)
	var cp_point: Vector2 = arena_cp.position + (arena_cp as Checkpoint).respawn_offset
	_check("%s: arena checkpoint and its respawn point are outside the encounter trigger" % tag, not trigger.has_point(arena_cp.position) and not trigger.has_point(cp_point))
	var gate_x: float = (level.arena_gates[0] as Node2D).position.x
	_check("%s: order along x: arena checkpoint < gate < trigger < boss" % tag, arena_cp.position.x < gate_x and gate_x < trigger.position.x and trigger.end.x < boss_node.position.x)
	if level_number >= 2:
		_check("%s: distinct palette and narrative placeholders" % tag, level.background_color.a > 0.0 and level.intro_lines.size() == 5 and level.camera_limits.size.x > 5000
			and level.variant_groups.has("calm") and level.variant_groups.has("standard") and level.variant_groups["calm"].is_empty() and level.variant_groups["standard"].is_empty()
			and (level.variant_groups["corrupted"] as Array).size() == designed["extras"])
	level.free()


# --- Scene loads ---

func _test_level_loads() -> void:
	for level_number in [2, 3]:
		_clean_state()
		var level: LevelBase = _make_level(level_number)
		await _physics(300)
		_check("load: level %d runs 300 frames" % level_number, is_instance_valid(level) and not level.player.is_dead and level.player.health.current_health > 0
			and level.camera_limits.size != Vector2i.ZERO and level.player.camera.limit_right == level.camera_limits.end.x and level.background.visible)
		level.free()
		_free_fragments()
	var ending: EndingController = ENDING_SCENE.instantiate() as EndingController
	add_child(ending)
	await _physics(300)
	_check("load: ending runs 300 frames", is_instance_valid(ending))
	ending.free()
	_clean_state()


# --- Debug helper ---

func _press_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	get_viewport().push_input(event)
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	get_viewport().push_input(release)


func _test_debug_helper() -> void:
	for level_number in [2, 3]:
		_clean_state()
		var level: LevelBase = _make_level(level_number)
		await _physics(3)
		var debug_node: LevelDebug = level.get_node_or_null("LevelDebug") as LevelDebug
		_check("debug (level %d): the helper follows OS.is_debug_build()" % level_number, (debug_node != null) == OS.is_debug_build())
		if debug_node != null:
			_check("debug (level %d): F2 teleports to the arena checkpoint" % level_number, debug_node.teleport_to_arena_checkpoint()
				and level.player.global_position.is_equal_approx(debug_node.find_arena_checkpoint().get_respawn_position()))
			_check("debug (level %d): the arena checkpoint is the highest order one" % level_number, String(debug_node.find_arena_checkpoint().checkpoint_id) == "level_%d_arena" % level_number)
			var max_health: int = level.boss.health.max_health
			_press_key(KEY_H)
			await _physics(2)
			var hurt: int = max_health - level.boss.health.current_health
			_check("debug (level %d): H hurts the boss 10%% through a real key event" % level_number, hurt == maxi(int(max_health / 10.0), 1), "hurt %d of %d" % [hurt, max_health])
			_press_key(KEY_F3)
			await _physics(2)
			_check("debug (level %d): F3 toggles the info label" % level_number, debug_node._label.visible)
			_press_key(KEY_K)
			await _physics(2)
			_check("debug (level %d): K kills the boss through a real key event" % level_number, level.boss.state == BossBase.State.DEAD)
		level.free()
		_free_fragments()
	_clean_state()


# --- Static scans of the new scripts ---

func _test_static_scans() -> void:
	var forbidden: RegEx = RegEx.create_from_string("KEY_(G|R|L|[1-7])\\b")
	var absolute: RegEx = RegEx.create_from_string("(^|[^A-Za-z])[A-Za-z]:[\\\\/]|/Users/|/home/")
	for path in NEW_SCRIPTS:
		var text: String = FileAccess.get_file_as_string(path)
		_check("scan: %s does not use keys 1-7, G, R or L" % path.get_file(), forbidden.search(text) == null)
		_check("scan: %s has no absolute paths" % path.get_file(), absolute.search(text) == null)
	var input_actions: PackedStringArray = PackedStringArray()
	for text_path in NEW_SCRIPTS:
		var text: String = FileAccess.get_file_as_string(text_path)
		if text.contains("Input.is_action") or text.contains("InputMap"):
			input_actions.append(text_path.get_file())
	_check("scan: the new scripts do not read input actions", input_actions.is_empty(), str(input_actions))
