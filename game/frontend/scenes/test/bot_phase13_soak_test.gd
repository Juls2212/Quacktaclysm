extends Node
## Phase 13a soak / fuzz bot. A seeded bot injects real InputEvents every physics frame (walk right,
## random jumps / dashes / sword attacks / wave casts, idling, pausing) in the tutorial, levels 1-3
## and boss_test for >= 5400 physics frames (~90 simulated seconds) each, with invariants checked
## on every frame; plus a "boss duel" per boss. Development only.
## Run: <godot> --headless --fixed-fps 60 --path game res://frontend/scenes/test/bot_phase13_soak_test.tscn [-- --seed=N --frames=N --only=name]
## `--fixed-fps 60` makes every rendered frame exactly one physics tick and removes the real-time wait
## (without it the same run takes ~25 minutes). tools/run_all_tests.py passes it automatically.
## Uses a redirected save path, the AI service stays disabled and SceneManager.dry_run is on.

const TEST_SAVE: String = "user://test_save_phase13_bot.json"
const DEFAULT_REGISTRY: SceneRegistry = preload("res://backend/progression/default_scene_registry.tres")
const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const BOSSES: Dictionary = {
	"boss_one": preload("res://backend/bosses/placeholder_boss.tscn"),
	"boss_two": preload("res://backend/bosses/boss_two.tscn"),
	"boss_three": preload("res://backend/bosses/boss_three.tscn"),
}
const SCENARIOS: Array[Dictionary] = [
	{"name": "tutorial", "path": "res://frontend/levels/tutorial.tscn", "arena": false},
	{"name": "level_1", "path": "res://frontend/levels/level_1.tscn", "arena": true},
	{"name": "level_2", "path": "res://frontend/levels/level_2.tscn", "arena": true},
	{"name": "level_3", "path": "res://frontend/levels/level_3.tscn", "arena": true},
	{"name": "boss_test", "path": "res://frontend/scenes/test/boss_test.tscn", "arena": false},
]
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const BASE_SEEDS: Array[int] = [1301, 2602, 3903]
const DEFAULT_FRAMES: int = 5400
const MAX_PROJECTILES_ALLOWED: int = 60
const OUT_OF_BOUNDS_MARGIN: float = 400.0
const OUT_OF_BOUNDS_FRAMES: int = 45
const STUCK_CHECKS: int = 4
const STUCK_CHECK_INTERVAL: int = 30
const DEAD_TIMEOUT_FRAMES: int = 900
const BOSS_IDLE_TIMEOUT_FRAMES: int = 900
const PROJECTILE_DRAIN_FRAMES: int = 300
const DUEL_TIMEOUT_SECONDS: float = 300.0
const DUEL_PLAYER_HEALTH: int = 60
const FLOOR_Y: float = 300.0

var failures: int = 0
var real_save_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig
var frames_per_run: int = DEFAULT_FRAMES
var seeds: Array[int] = BASE_SEEDS.duplicate()
var only: String = ""
var duel_summary: Array[String] = []


func _ready() -> void:
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			var base: int = int(argument.trim_prefix("--seed="))
			seeds = [base, base + 1, base + 2]
		elif argument.begins_with("--frames="):
			frames_per_run = int(argument.trim_prefix("--frames="))
		elif argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
	_run.call_deferred()


func _check(check_name: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("PASS: %s %s" % [check_name, detail])
	else:
		failures += 1
		print("FAIL: %s %s" % [check_name, detail])


func _read_file(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "<missing>"


func _physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _test_registry() -> SceneRegistry:
	var registry := SceneRegistry.new()
	registry.scenes = DEFAULT_REGISTRY.scenes.duplicate()
	registry.level_scene_ids = DEFAULT_REGISTRY.level_scene_ids
	registry.fade_out_time = 0.0
	registry.fade_in_time = 0.0
	return registry


func _clean_state() -> void:
	get_tree().paused = false
	PauseLock.reset(get_tree())
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.autosave_enabled = true
	for child in get_children():
		if child is Projectile or child is SoulFragment:
			child.free()


func _run() -> void:
	SceneManager.dry_run = true
	SceneManager.set_registry(_test_registry())
	print("SOAK seeds %s, %d frames per run" % [str(seeds), frames_per_run])
	_check("AI service disabled for the whole test", not ai_config.enabled)
	for scenario in SCENARIOS:
		if not only.is_empty() and String(scenario["name"]) != only:
			continue
		await _soak(scenario, seeds[0], false)
		await _soak(scenario, seeds[1], false)
		await _soak(scenario, seeds[2], bool(scenario["arena"]))
	if only.is_empty() or only == "duel":
		for boss_name in BOSSES:
			await _duel(String(boss_name), seeds[0])
		print("BOSS DUEL SUMMARY:")
		for line in duel_summary:
			print("  " + line)
	_clean_state()
	SceneManager.dry_run = false
	SaveSystem.purge()
	_check("real save file untouched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


# --- Input injection (real InputEvents built from the InputMap) ---

func _event_for(action: StringName, pressed: bool) -> InputEvent:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			var copy := key.duplicate() as InputEventKey
			copy.pressed = pressed
			return copy
	var fallback := InputEventAction.new()
	fallback.action = action
	fallback.pressed = pressed
	return fallback


## Gameplay reads the Input singleton (parse_input_event); UI nodes such as the pause menu listen to
## `_unhandled_input`, which only receives events pushed into the viewport.
func _send(action: StringName, pressed: bool) -> void:
	var event: InputEvent = _event_for(action, pressed)
	if action == &"pause":
		get_viewport().push_input(event)
	else:
		Input.parse_input_event(event)


func _press(action: StringName) -> void:
	_send(action, true)


func _release(action: StringName) -> void:
	_send(action, false)


func _release_all() -> void:
	for action in [&"move_left", &"move_right", &"jump", &"dash", &"attack", &"wave", &"heavy_attack", &"pause"]:
		_release(action)


## Seeded random driver. `held` maps action -> remaining frames it stays pressed.
class Bot extends RefCounted:
	var rng := RandomNumberGenerator.new()
	var held: Dictionary = {}
	var walk_dir: int = 1
	var walk_left: int = 0
	var pause_open_frames: int = 0

	func _init(seed_value: int) -> void:
		rng.seed = seed_value

	func chance(probability: float) -> bool:
		return rng.randf() < probability


func _drive(bot: Bot, player: Player, boss: BossBase, frame: int) -> void:
	# Release actions whose hold time ended.
	for action: Variant in bot.held.keys():
		bot.held[action] -= 1
		if bot.held[action] <= 0:
			_release(action)
			bot.held.erase(action)
	if get_tree().paused:
		return
	# Movement: mostly right, sometimes idle or back; biased toward an active boss.
	bot.walk_left -= 1
	if bot.walk_left <= 0:
		var roll: float = bot.rng.randf()
		bot.walk_dir = 1 if roll < 0.78 else (0 if roll < 0.9 else -1)
		bot.walk_left = bot.rng.randi_range(20, 70)
		if boss != null and is_instance_valid(boss) and boss.state != BossBase.State.INACTIVE and boss.state != BossBase.State.DEAD and bot.chance(0.6):
			bot.walk_dir = 1 if boss.global_position.x >= player.global_position.x else -1
		_release(&"move_left")
		_release(&"move_right")
		if bot.walk_dir > 0:
			_press(&"move_right")
		elif bot.walk_dir < 0:
			_press(&"move_left")
	var fighting: bool = boss != null and is_instance_valid(boss) and boss.state != BossBase.State.INACTIVE and boss.state != BossBase.State.DEAD
	if bot.chance(0.04) and not bot.held.has(&"jump"):
		_press(&"jump")
		bot.held[&"jump"] = bot.rng.randi_range(4, 22)
	if bot.chance(0.015) and not bot.held.has(&"dash"):
		_press(&"dash")
		bot.held[&"dash"] = 2
	if bot.chance(0.10 if fighting else 0.035) and not bot.held.has(&"attack"):
		_press(&"attack")
		bot.held[&"attack"] = 2
	if bot.chance(0.03 if fighting else 0.01) and not bot.held.has(&"heavy_attack"):
		_press(&"heavy_attack")
		bot.held[&"heavy_attack"] = 2
	if bot.chance(0.04 if fighting else 0.015) and not bot.held.has(&"wave"):
		_press(&"wave")
		bot.held[&"wave"] = 2
	if bot.chance(0.003) and not bot.held.has(&"pause"):
		_press(&"pause")
		bot.held[&"pause"] = 2


# --- Invariants ---

func _collect(root: Node, type_check: Callable, into: Array[Node]) -> void:
	for child in root.get_children():
		if type_check.call(child):
			into.append(child)
		_collect(child, type_check, into)


func _projectile_count() -> int:
	var count: int = 0
	for child in get_children():
		if child is Projectile and not child.is_queued_for_deletion():
			count += 1
	return count


func _embedded(player: Player, shape: RectangleShape2D) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, player.global_position)
	query.collision_mask = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	query.exclude = [player.get_rid()]
	return not player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## Closes whatever is open (game over, decision, pause menu) until the tree runs and the player lives.
func _settle_menus(player: Player, game_over: GameOverPanel, decision_panel: DecisionPanel, pause_menus: Array[Node]) -> void:
	for settle in 300:
		if game_over != null and game_over.is_open():
			game_over.retry_button.pressed.emit()
		elif decision_panel != null and decision_panel.is_open():
			decision_panel.release_button.pressed.emit()
		elif get_tree().paused and not pause_menus.is_empty() and settle % 10 == 0:
			_press(&"pause")
			await _physics(1)
			_release(&"pause")
		if not get_tree().paused and not player.is_dead:
			break
		await _physics(1)


func _soak(scenario: Dictionary, seed_value: int, from_arena: bool) -> void:
	_clean_state()
	var name: String = String(scenario["name"])
	var label: String = "%s seed %d %s" % [name, seed_value, "from the arena checkpoint" if from_arena else "from the start"]
	var level := (load(String(scenario["path"])) as PackedScene).instantiate()
	add_child(level)
	await _physics(5)
	var player := level.get_node("Player") as Player
	var boss: BossBase = level.get("boss") as BossBase
	var limits := Rect2(-2000.0, -2000.0, 12000.0, 6000.0)
	var camera_limits: Variant = level.get("camera_limits")
	if camera_limits is Rect2i and (camera_limits as Rect2i).size != Vector2i.ZERO:
		var box: Rect2i = camera_limits
		limits = Rect2(Vector2(box.position) - Vector2.ONE * OUT_OF_BOUNDS_MARGIN, Vector2(box.size) + Vector2.ONE * OUT_OF_BOUNDS_MARGIN * 2.0)
	if from_arena and level is LevelBase:
		var best: Checkpoint = null
		for checkpoint in (level as LevelBase).get_level_checkpoints():
			if best == null or checkpoint.order > best.order:
				best = checkpoint
		player.global_position = best.get_respawn_position()
		player.set_respawn_point(best.get_respawn_position())
		await _physics(3)
	var enemies: Array[Node] = []
	_collect(level, func(node: Node) -> bool: return node is EnemyBase, enemies)
	var kills: Array[int] = [0]
	for enemy in enemies:
		(enemy as EnemyBase).health.died.connect(func() -> void: kills[0] += 1)
	var bosses_defeated: Array[int] = [0]
	if boss != null:
		boss.defeated.connect(func(_b: BossBase) -> void: bosses_defeated[0] += 1)
	var pause_menus: Array[Node] = level.find_children("*", "PauseMenu", true, false)
	var game_over: GameOverPanel = null
	var game_over_nodes: Array[Node] = level.find_children("*", "GameOverPanel", true, false)
	if not game_over_nodes.is_empty():
		game_over = game_over_nodes[0] as GameOverPanel
	var decision_panel: DecisionPanel = null
	var decision_nodes: Array[Node] = level.find_children("*", "DecisionPanel", true, false)
	if not decision_nodes.is_empty():
		decision_panel = decision_nodes[0] as DecisionPanel
	var probe := RectangleShape2D.new()
	probe.size = Vector2(24.0, 48.0)
	var bot := Bot.new(seed_value)
	# Detector sanity (canary): a probe placed inside a solid platform must be reported as embedded.
	var canary_ok: bool = false
	for body in level.find_children("*", "StaticBody2D", true, false):
		var solid := body as StaticBody2D
		if solid.collision_layer & CombatLayers.layer_bit(CombatLayers.LAYER_WORLD) != 0 and solid.get_child_count() > 0:
			var holder := CollisionShape2D.new()
			for child in solid.get_children():
				if child is CollisionShape2D and (child as CollisionShape2D).shape is RectangleShape2D:
					holder = child as CollisionShape2D
			if holder.shape != null:
				var query := PhysicsShapeQueryParameters2D.new()
				query.shape = probe
				query.transform = Transform2D(0.0, solid.global_position)
				query.collision_mask = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
				canary_ok = not player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
				break
	_check("%s: the stuck-in-geometry detector flags a probe placed inside a platform" % label, canary_ok)
	# Real pause sanity: the pause action opens and closes the menu and leaves no lock behind.
	var pause_works: bool = true
	if not pause_menus.is_empty():
		_press(&"pause")
		await _physics(2)
		_release(&"pause")
		var opened: bool = get_tree().paused
		await _physics(2)
		_press(&"pause")
		await _physics(2)
		_release(&"pause")
		await _physics(2)
		pause_works = opened and not get_tree().paused and PauseLock.holder_count() == 0
	_check("%s: the pause action opens and closes the pause menu with real key events" % label, pause_works or pause_menus.is_empty())
	var stats := {"deaths": 0, "retries": 0, "respawns_ok": 0, "pauses": 0, "decisions": 0, "max_projectiles": 0}
	var anomalies := {"nan": 0, "out_of_bounds_max": 0, "stuck": [], "respawn_failures": [], "enemy_after_death": 0, "boss_stuck": 0, "pause_stuck": 0}
	var out_run: int = 0
	var stuck_run: int = 0
	var dead_frames: int = 0
	var was_dead: bool = false
	var paused_frames: int = 0
	var boss_signature: Array = []
	var boss_same: int = 0
	var boss_active_frames: int = 0
	var dead_enemies: Dictionary = {}
	for frame in frames_per_run:
		await get_tree().physics_frame
		if not is_instance_valid(player):
			break
		_drive(bot, player, boss, frame)
		var position: Vector2 = player.global_position
		var velocity: Vector2 = player.velocity
		if not (is_finite(position.x) and is_finite(position.y) and is_finite(velocity.x) and is_finite(velocity.y)):
			anomalies["nan"] += 1
		if not player.is_dead and not limits.has_point(position):
			out_run += 1
			anomalies["out_of_bounds_max"] = maxi(anomalies["out_of_bounds_max"], out_run)
		else:
			out_run = 0
		if frame % STUCK_CHECK_INTERVAL == 0 and not player.is_dead:
			if _embedded(player, probe):
				stuck_run += 1
				if stuck_run == STUCK_CHECKS:
					anomalies["stuck"].append(position)
			else:
				stuck_run = 0
		var projectiles: int = _projectile_count()
		stats["max_projectiles"] = maxi(stats["max_projectiles"], projectiles)
		# Death / respawn.
		var dead_now: bool = player.is_dead
		if dead_now:
			if not was_dead:
				stats["deaths"] += 1
			dead_frames += 1
			if game_over != null and game_over.is_open() and dead_frames > 20:
				game_over.retry_button.pressed.emit()
				stats["retries"] += 1
			elif dead_frames > DEAD_TIMEOUT_FRAMES:
				anomalies["respawn_failures"].append("dead for %d frames at %s" % [dead_frames, str(position)])
				player.respawn()
				dead_frames = 0
		else:
			if was_dead:
				var restored: bool = player.health.current_health == player.health.max_health and player.state != Player.State.DEAD and not player.is_input_locked()
				if restored:
					stats["respawns_ok"] += 1
				else:
					anomalies["respawn_failures"].append("respawn left hp %d/%d state %d" % [player.health.current_health, player.health.max_health, player.state])
			dead_frames = 0
		was_dead = dead_now
		# Decision panel (a defeated boss dropped a fragment and the bot touched it).
		if decision_panel != null and decision_panel.is_open() and frame % 7 == 0:
			decision_panel.release_button.pressed.emit()
			stats["decisions"] += 1
		# Pause menu closing: the bot taps pause again once it has been open a little.
		if get_tree().paused and (game_over == null or not game_over.is_open()) and (decision_panel == null or not decision_panel.is_open()):
			paused_frames += 1
			if paused_frames == 1:
				stats["pauses"] += 1
			if paused_frames % 12 == 0:
				_press(&"pause")
				bot.held[&"pause"] = 2
			if paused_frames > 600:
				anomalies["pause_stuck"] += 1
				PauseLock.reset(get_tree())
				get_tree().paused = false
				paused_frames = 0
		else:
			paused_frames = 0
		# Dead enemies must stay dead and harmless.
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			var body := enemy as EnemyBase
			if body.health.is_dead:
				dead_enemies[body] = true
				if body.attack_hitbox.is_active or body.hurtbox.enabled:
					anomalies["enemy_after_death"] += 1
		# Boss state machine.
		if boss != null and is_instance_valid(boss):
			if boss.state == BossBase.State.IDLE or boss.state == BossBase.State.PATTERN or boss.state == BossBase.State.PHASE_TRANSITION:
				boss_active_frames += 1
				var signature: Array = [boss.state, boss.current_phase, boss.current_pattern_id]
				if signature == boss_signature:
					boss_same += 1
					if boss_same == BOSS_IDLE_TIMEOUT_FRAMES:
						anomalies["boss_stuck"] += 1
				else:
					boss_signature = signature
					boss_same = 0
			else:
				boss_signature = []
				boss_same = 0
	# Teardown: stop the bot, settle every menu (game over, decision, pause) and wait for a living player.
	_release_all()
	var kills_in_run: int = kills[0]
	await _settle_menus(player, game_over, decision_panel, pause_menus)
	await _physics(5)
	var paused_at_end: bool = get_tree().paused
	if boss != null and is_instance_valid(boss) and boss.state != BossBase.State.DEAD:
		boss.reset_encounter()
	for enemy in enemies:
		if is_instance_valid(enemy) and not (enemy as EnemyBase).health.is_dead:
			(enemy as EnemyBase).health.kill()
	await _physics(PROJECTILE_DRAIN_FRAMES)
	await _settle_menus(player, game_over, decision_panel, pause_menus)
	var remaining_projectiles: int = _projectile_count()
	var saved: Variant = JSON.parse_string(_read_file(TEST_SAVE)) if FileAccess.file_exists(TEST_SAVE) else null
	print("STATS %s: frames=%d deaths=%d retries=%d respawns_ok=%d kills=%d/%d bosses_defeated=%d pauses=%d decisions=%d boss_active_frames=%d max_projectiles=%d" % [
		label, frames_per_run, stats["deaths"], stats["retries"], stats["respawns_ok"], kills_in_run, enemies.size(), bosses_defeated[0], stats["pauses"], stats["decisions"], boss_active_frames, stats["max_projectiles"]])
	_check("%s: position and velocity always finite" % label, anomalies["nan"] == 0)
	_check("%s: never outside the level bounds for more than %d frames (worst %d)" % [label, OUT_OF_BOUNDS_FRAMES, anomalies["out_of_bounds_max"]], anomalies["out_of_bounds_max"] <= OUT_OF_BOUNDS_FRAMES)
	_check("%s: never stuck inside solid geometry" % label, (anomalies["stuck"] as Array).is_empty(), str(anomalies["stuck"]))
	_check("%s: every respawn restored full health and control" % label, (anomalies["respawn_failures"] as Array).is_empty(), str(anomalies["respawn_failures"]))
	_check("%s: respawns happened after every death" % label, stats["respawns_ok"] >= stats["deaths"] - 1, "%d deaths, %d respawns" % [stats["deaths"], stats["respawns_ok"]])
	_check("%s: projectiles stayed below %d (max %d) and all expired" % [label, MAX_PROJECTILES_ALLOWED, stats["max_projectiles"]], stats["max_projectiles"] < MAX_PROJECTILES_ALLOWED and remaining_projectiles == 0, "left %d" % remaining_projectiles)
	_check("%s: the tree was not left paused and PauseLock is empty" % label, not paused_at_end and anomalies["pause_stuck"] == 0 and PauseLock.holder_count() == 0 and not get_tree().paused,
		"holders %d" % PauseLock.holder_count())
	_check("%s: killed enemies stay dead and harmless" % label, anomalies["enemy_after_death"] == 0)
	_check("%s: the boss state machine never got stuck" % label, anomalies["boss_stuck"] == 0)
	_check("%s: GameState and the save keep exactly seven keys" % label, GameState.to_dict().keys().size() == SAVE_KEYS.size()
		and (saved == null or (saved is Dictionary and (saved as Dictionary).keys().size() == SAVE_KEYS.size())))
	level.free()
	_release_all()
	for child in get_children():
		if child is Projectile or child is SoulFragment:
			child.free()
	while SceneManager.is_transitioning():
		await get_tree().process_frame
	await _physics(2)


# --- Boss duel ---

func _duel(boss_name: String, seed_value: int) -> void:
	_clean_state()
	var world := Node2D.new()
	add_child(world)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	floor_body.position = Vector2(400.0, FLOOR_Y + 20.0)
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(2000.0, 40.0)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	for wall_x in [-560.0, 1360.0]:
		var wall := StaticBody2D.new()
		wall.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
		wall.position = Vector2(wall_x, FLOOR_Y - 300.0)
		var wall_shape := CollisionShape2D.new()
		var wall_rect := RectangleShape2D.new()
		wall_rect.size = Vector2(40.0, 800.0)
		wall_shape.shape = wall_rect
		wall.add_child(wall_shape)
		world.add_child(wall)
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(0.0, FLOOR_Y - 26.0)
	world.add_child(player)
	var boss := (BOSSES[boss_name] as PackedScene).instantiate() as BossBase
	boss.rng_seed = seed_value
	boss.position = Vector2(700.0, FLOOR_Y - 44.0)
	world.add_child(boss)
	await _physics(5)
	# Test-only: a sturdier player so the duel measures the boss fight and not the bot's dodging.
	player.health.max_health = DUEL_PLAYER_HEALTH
	player.health.reset()
	player.set_respawn_point(player.global_position)
	var bot := Bot.new(seed_value)
	var defeated: Array[bool] = [false]
	var defeat_count: Array[int] = [0]
	boss.defeated.connect(func(_b: BossBase) -> void:
		defeated[0] = true
		defeat_count[0] += 1)
	var phase_two: Array[bool] = [false]
	boss.phase_changed.connect(func(_phase: int) -> void: phase_two[0] = true)
	boss.activate(player)
	var max_frames: int = int(DUEL_TIMEOUT_SECONDS * 60.0)
	var frame: int = 0
	var deaths: int = 0
	var was_dead: bool = false
	var max_projectiles: int = 0
	while frame < max_frames and not defeated[0]:
		await get_tree().physics_frame
		frame += 1
		for action: Variant in bot.held.keys():
			bot.held[action] -= 1
			if bot.held[action] <= 0:
				_release(action)
				bot.held.erase(action)
		if player.is_dead:
			if not was_dead:
				deaths += 1
			was_dead = true
			continue
		was_dead = false
		var dx: float = boss.global_position.x - player.global_position.x
		var direction: StringName = &"move_right" if dx > 0.0 else &"move_left"
		var other: StringName = &"move_left" if dx > 0.0 else &"move_right"
		_release(other)
		if absf(dx) > 70.0 or bot.chance(0.3):
			_press(direction)
		else:
			_release(direction)
		if absf(dx) <= 110.0 and bot.chance(0.08) and not bot.held.has(&"heavy_attack"):
			_press(&"heavy_attack")
			bot.held[&"heavy_attack"] = 2
		elif absf(dx) <= 110.0 and bot.chance(0.35) and not bot.held.has(&"attack"):
			_press(&"attack")
			bot.held[&"attack"] = 2
		elif absf(dx) > 110.0 and bot.chance(0.3) and not bot.held.has(&"wave"):
			_press(&"wave")
			bot.held[&"wave"] = 2
		if bot.chance(0.02) and not bot.held.has(&"jump"):
			_press(&"jump")
			bot.held[&"jump"] = bot.rng.randi_range(4, 18)
		if bot.chance(0.01) and not bot.held.has(&"dash"):
			_press(&"dash")
			bot.held[&"dash"] = 2
		max_projectiles = maxi(max_projectiles, _projectile_count())
	_release_all()
	var seconds: float = float(frame) / 60.0
	var by_bot: bool = defeated[0]
	if not by_bot and is_instance_valid(boss):
		boss.hurtbox.receive_hit(DamageInfo.create(9999, Vector2.ZERO, player, CombatLayers.Team.PLAYER))
	await _physics(5)
	var hitboxes_off: bool = true
	if is_instance_valid(boss):
		for child in boss.attack_pivot.get_children():
			if child is Hitbox and (child as Hitbox).is_active:
				hitboxes_off = false
	# Slowest possible fight: all the boss health with the sword alone, no misses, no idle time.
	var max_health: int = boss.stats.max_health if is_instance_valid(boss) else 0
	var sword_dps: float = float(player.stats.attack_damage) / (player.stats.attack_startup_time + player.stats.attack_active_time + player.stats.attack_recovery_time + player.stats.attack_cooldown)
	var fastest: float = float(max_health) / (sword_dps + 2.0)
	var line: String = "%s: %s in %.1f simulated seconds (%d player deaths, max %d projectiles, phase 2 reached: %s, theoretical minimum %.1fs)" % [
		boss_name, "defeated by the bot" if by_bot else "NOT defeated by the bot; lethal damage used after %.0fs" % DUEL_TIMEOUT_SECONDS, seconds, deaths, max_projectiles, str(phase_two[0]), fastest]
	duel_summary.append(line)
	print("DUEL " + line)
	_check("duel %s: the fight finishes (defeated exactly once, hitboxes off)" % boss_name, defeat_count[0] == 1 and hitboxes_off)
	_check("duel %s: not faster than the theoretical minimum" % boss_name, not by_bot or seconds >= fastest)
	_check("duel %s: the bot itself defeats the boss within %.0fs" % [boss_name, DUEL_TIMEOUT_SECONDS], by_bot, "%.1fs" % seconds)
	_check("duel %s: projectiles stayed bounded (max %d)" % [boss_name, max_projectiles], max_projectiles < MAX_PROJECTILES_ALLOWED)
	world.free()
	for child in get_children():
		if child is Projectile or child is SoulFragment:
			child.free()
	_release_all()
