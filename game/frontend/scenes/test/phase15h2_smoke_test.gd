extends Node
## Smoke test for Phase 15h-bis: the gaps of level 3 measured with the REAL player. Nothing solid or damaging sits in a jump arc;
## ground enemies keep out of the last 250 px before an edge and cannot push the player off a takeoff; every gap gives a real player
## the timing and takeoff windows of docs/BALANCE_REPORT.md (the second action's window in ms, the takeoff window in px); the
## strategies that must fail do; the double jump is there in every entry path; and the stuck-player assist (a wreck platform after 4 falls
## into the same gap) stays in memory only. Lines starting with "MEASURE|" go to the docs. Development only.
## Run (alone, a few minutes, the clock runs fast): <godot> --headless --path game res://frontend/scenes/test/phase15h2_smoke_test.tscn
## Uses a redirected save path; the real save, settings and controls are never touched.

const TEST_SAVE: String = "user://test_save_phase15h2.json"
const TEST_SETTINGS: String = "user://test_settings_phase15h2.cfg"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const LEVEL_THREE: PackedScene = preload("res://frontend/levels/level_3.tscn")
const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const LEVEL_ONE_MD5: String = "0e26106a46848215f2ec25d5280c1fed"
const LEVEL_TWO_MD5: String = "09e2ccd6a5c2c4e0b53846990e7eef61"
const FLOOR_Y: float = 620.0
const FRAME_MS: float = 1000.0 / 60.0
const CLOCK_SCALE: float = 8.0
const FAST_TICKS: float = 480.0
const BUDGET_MS: int = 290000
const EXPECTED_WIDTHS: Array[float] = [336.0, 450.0, 484.0]

var failures: int = 0
var real_save_before: String = ""
var real_settings_before: String = ""
var real_controls_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig
var config: GapSafetyConfig = GapSafetyConfig.get_default()
var stats: PlayerStats = PlayerStats.new()
var started_ms: int = 0
var budget_hit: bool = false
var runs: int = 0
var world: Node2D = null
var player: Player = null


func _ready() -> void:
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	GameSettings.path_override = TEST_SETTINGS
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
	real_settings_before = _read_file(GameSettings.PATH)
	real_controls_before = _read_file(ControlsConfig.DEFAULT_PATH)
	_run.call_deferred()


## Phase 15q: Engine.time_scale also multiplies the physics delta (a step of 1/60 s becomes 8/60 s at scale 8), which distorted every jump and made all the
## timing windows read 0 ms. The fast clock now raises the physics rate and the scale together: 480 steps per second at scale 8 is still a 1/60 s step.
func _fast(on: bool) -> void:
	Engine.physics_ticks_per_second = int(FAST_TICKS) if on else 60
	Engine.time_scale = CLOCK_SCALE if on else 1.0


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


func _clean_state() -> void:
	_fast(false)
	PauseLock.reset(get_tree())
	get_tree().paused = false
	for action in [&"move_right", &"jump", &"dash"]:
		Input.action_release(action)
	SaveSystem.purge()
	GameSettings.save_settings(GameSettings.DEFAULTS.duplicate())
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.director.clear_overrides()
	GameState.autosave_enabled = false
	AbilityCard.forget_all()
	BossDialogue.forget_all()


func _decide(count: int) -> void:
	for i in count:
		GameState.record_decision("test_%d" % i, "x", i + 1, GameState.CHOICE_KEPT)


func _run() -> void:
	started_ms = Time.get_ticks_msec()
	_clean_state()
	_test_guards()
	_test_other_levels()
	var level: Node = _level()
	var gaps: Array[Vector2] = _gaps_of(level)
	_test_gap_widths(gaps)
	_test_arc_audit(level, gaps)
	_test_enemy_placement(level, gaps)
	level.free()
	await _test_enemy_edges()
	await _test_double_jump_paths()
	await _test_sweeps(gaps)
	await _test_assist()
	_clean_state()
	SaveSystem.purge()
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	GameSettings.path_override = ""
	GameState.autosave_enabled = true
	_check("the real save file was not touched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	_check("the real settings file was not touched", _read_file(GameSettings.PATH) == real_settings_before)
	_check("the real controls file was not touched", _read_file(ControlsConfig.DEFAULT_PATH) == real_controls_before)
	print("MEASURE|test duration %.0f s, %d crossing runs" % [float(Time.get_ticks_msec() - started_ms) / 1000.0, runs])
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------

## A level 3 without its intro scene (it would take the controls), not added to the tree.
func _level() -> Node:
	var level: Node = LEVEL_THREE.instantiate()
	level.get_node("ElderScene").free()
	level.get_node("LevelTitleCard").free()
	# No game-over screen: the player comes back at the checkpoint by itself, as the test needs after each fall.
	level.set("show_game_over", false)
	return level


func _left(node: Node2D) -> float:
	return node.position.x - float(node.get("size").x) * 0.5


func _right(node: Node2D) -> float:
	return node.position.x + float(node.get("size").x) * 0.5


func _gaps_of(level: Node) -> Array[Vector2]:
	var content: Node = level.get_node("Content")
	var gaps: Array[Vector2] = []
	var names: Array[String] = ["FloorA", "FloorB", "FloorC", "FloorD"]
	for i in names.size() - 1:
		gaps.append(Vector2(_right(content.get_node(names[i]) as Node2D), _left(content.get_node(names[i + 1]) as Node2D)))
	return gaps


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


func _test_other_levels() -> void:
	_check("levels 1 and 2 are byte-identical to before", FileAccess.get_md5("res://frontend/levels/level_1.tscn") == LEVEL_ONE_MD5 and FileAccess.get_md5("res://frontend/levels/level_2.tscn") == LEVEL_TWO_MD5)


func _test_gap_widths(gaps: Array[Vector2]) -> void:
	var widths: Array[float] = []
	for gap in gaps:
		widths.append(gap.y - gap.x)
	_check("gaps: three gaps of %s px (never below %.0f px for the first)" % [str(widths), config.gap_one_min_width], widths == EXPECTED_WIDTHS and widths[0] >= config.gap_one_min_width)


# ---------------------------------------------------------------------------------------------
# Step 0: nothing solid or damaging in a jump arc; enemies keep away from the edges
# ---------------------------------------------------------------------------------------------

func _shape_rects(body: CollisionObject2D) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for child in body.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape != null:
			var shape_node := child as CollisionShape2D
			var local: Rect2 = shape_node.shape.get_rect()
			var origin: Vector2 = body.position + shape_node.position
			rects.append(Rect2(origin + local.position, local.size))
	return rects


func _walk_bodies(node: Node, out: Array[CollisionObject2D]) -> void:
	for child in node.get_children():
		if child is CollisionObject2D:
			out.append(child as CollisionObject2D)
		_walk_bodies(child, out)


func _test_arc_audit(level: Node, gaps: Array[Vector2]) -> void:
	var content: Node = level.get_node("Content")
	var bodies: Array[CollisionObject2D] = []
	_walk_bodies(content, bodies)
	var arc_top: float = 600.0 - 320.0
	var offenders: PackedStringArray = PackedStringArray()
	var scanned: int = 0
	for body in bodies:
		if body is KillZone or body.get_parent() != content and not body is CharacterBody2D:
			continue
		for rect in _shape_rects(body):
			scanned += 1
			for gap in gaps:
				# The jump arc volume: the gap's width, from 320 px above the floor down to the kill zone.
				var arc := Rect2(gap.x, arc_top, gap.y - gap.x, 900.0 - arc_top)
				if arc.intersects(rect) and (body.collision_layer != 0):
					offenders.append("%s %s" % [body.name, str(rect)])
	_check("arcs: nothing with a collision layer (solid, hurtbox or hitbox) lies inside any gap's jump volume (%d shapes scanned)" % scanned, offenders.is_empty(), str(offenders))
	var sensors: PackedStringArray = PackedStringArray()
	for body in bodies:
		if body.collision_layer == 0 and not body is KillZone:
			for rect in _shape_rects(body):
				for gap in gaps:
					if Rect2(gap.x, arc_top, gap.y - gap.x, 900.0 - arc_top).intersects(rect) and not body.name.begins_with("Detection") and not body is Checkpoint:
						sensors.append(body.name)
	print("MEASURE|sensor areas (no layer, harmless) inside a gap volume besides detection ranges and checkpoints: %s" % str(sensors))
	# The dark structure of the screenshot is scenery: the terrain skin, the backdrop and the storm decor are Node2D drawings.
	var decor_ok: bool = true
	var decor: Node = level.get_node("Decor")
	decor_ok = decor_ok and decor is Node2D and not decor is CollisionObject2D
	for layer in decor.get_children():
		decor_ok = decor_ok and not layer is CollisionObject2D
	_check("arcs: the storm decor (towers, chains, lamps, puddles) is drawing only, it has no collision", decor_ok)
	var inside: PackedStringArray = PackedStringArray()
	for gap in gaps:
		for child in content.get_children():
			if child is Node2D and child.position.x > gap.x and child.position.x < gap.y and not child is KillZone and not child is EnemyBase and child.get("size") != null and (child as Node2D).position.y < 900.0 and child is StaticBody2D:
				inside.append(child.name)
	_check("arcs: no platform, wall or gate has its center inside a gap", inside.is_empty(), str(inside))
	var killzone := content.get_node("KillZone") as Node2D
	_check("arcs: the only thing in the pit is the kill zone, far below the floors (y %.0f)" % killzone.position.y, killzone.position.y - float(killzone.get("size").y) * 0.5 >= 900.0)


func _test_enemy_placement(level: Node, gaps: Array[Vector2]) -> void:
	var content: Node = level.get_node("Content")
	var closest: float = 1e9
	var closest_name: String = ""
	var count: int = 0
	for child in content.get_children():
		if not child is EnemyBase:
			continue
		count += 1
		for gap in gaps:
			for edge: float in [gap.x, gap.y]:
				var distance: float = absf((child as Node2D).position.x - edge)
				if distance < closest:
					closest = distance
					closest_name = "%s at x %.0f from the edge %.0f" % [child.name, (child as Node2D).position.x, edge]
	print("MEASURE|closest enemy to a gap edge %.0f px (%s)" % [closest, closest_name])
	_check("enemies: none of the %d enemies (the three adaptive extras included) is placed within %.0f px of a gap edge (closest %.0f px: %s)" % [count, config.enemy_edge_keepout, closest, closest_name], count >= 12 and closest >= config.enemy_edge_keepout)
	var ground_flagged: bool = true
	for child in content.get_children():
		if child is EnemyBase and (child as Node2D).position.y >= config.ground_enemy_min_y:
			ground_flagged = ground_flagged and (child as Node2D).position.y < 600.0
	_check("enemies: every ground enemy stands over a floor (nobody spawns over a pit)", ground_flagged)


## The real level, the real enemies: the player waits on the last pixels of a floor and no enemy comes within the keep-out, hurts
## the player or pushes them into the pit.
func _test_enemy_edges() -> void:
	_clean_state()
	_decide(2)
	var level: Node = _level()
	add_child(level)
	await _physics(10)
	var guard := level.get_node("GapGuard") as GapGuard
	var lvl_player: Player = level.get("player") as Player
	var keepout_set: bool = guard != null and guard.gaps.size() == 3
	var enemies: Array[EnemyBase] = []
	for child in level.get_node("Content").get_children():
		if child is EnemyBase:
			enemies.append(child as EnemyBase)
			if (child as Node2D).position.y >= config.ground_enemy_min_y:
				keepout_set = keepout_set and absf((child as EnemyBase)._ledge_origin.x - (22.0 + config.enemy_edge_keepout)) < 0.01
	_check("enemy edges: the guard found 3 gaps and gave every ground enemy the keep-out", keepout_set)
	var edges: Array[float] = [1300.0, 2751.0, 4226.0]
	var closest: float = 1e9
	var hurt: bool = false
	var fell: bool = false
	_fast(true)
	for edge in edges:
		lvl_player.global_position = Vector2(edge - 10.0, 574.0)
		lvl_player.velocity = Vector2.ZERO
		# 5 s of game time on the last pixels of the floor, with every enemy free to chase.
		for i in 300:
			await get_tree().physics_frame
			hurt = hurt or lvl_player.state == Player.State.HURT
			fell = fell or lvl_player.global_position.y > 700.0
			for enemy in enemies:
				if enemy.position.y >= config.ground_enemy_min_y and enemy.global_position.x < edge + 1.0 and enemy.global_position.x > edge - 700.0:
					closest = minf(closest, edge - enemy.global_position.x)
	_fast(false)
	print("MEASURE|real enemies chasing a player standing at each takeoff edge for 5 s each: closest approach %.0f px, hurt %s, fell %s" % [closest, str(hurt), str(fell)])
	_check("enemy edges: a player waiting on the last pixels of each floor is never reached (closest enemy %.0f px, keep-out %.0f)" % [closest, config.enemy_edge_keepout], closest >= config.enemy_edge_keepout - 25.0)
	_check("enemy edges: nobody hurt or pushed into a gap during those 15 s (no knockback at takeoff)", not hurt and not fell)
	level.free()
	await _physics(2)


# ---------------------------------------------------------------------------------------------
# The double jump is there in every entry path
# ---------------------------------------------------------------------------------------------

func _test_double_jump_paths() -> void:
	# 1. A new game through levels 1 and 2 leaves two decisions.
	_clean_state()
	GameState.set_current_level(1)
	GameState.record_decision("fragment_level_1", "x", 1, GameState.CHOICE_KEPT)
	GameState.set_current_level(2)
	GameState.record_decision("fragment_level_2", "x", 2, GameState.CHOICE_RELEASED)
	GameState.set_current_level(3)
	var probe := PLAYER_SCENE.instantiate() as Player
	add_child(probe)
	_check("double jump: a new game through levels 1 and 2 reaches level 3 with it (unlock = GameState.decisions.size() >= %d, now %d)" % [stats.double_jump_unlock_decisions, GameState.decisions.size()], probe.has_double_jump())
	# 2. Loading at the start of level 3 and at every level 3 checkpoint, and continuing from disk.
	var snapshot: Dictionary = GameState.to_dict()
	var all_paths: bool = true
	for checkpoint in ["level_3_start", "level_3_mid_1", "level_3_mid_2", "level_3_arena", "ending"]:
		GameState.start_new_game()
		GameState.checkpoint = checkpoint
		var data: Dictionary = snapshot.duplicate(true)
		data["checkpoint"] = checkpoint
		var loaded: Dictionary = GameState.load_from_dict(data)
		all_paths = all_paths and loaded["ok"] and probe.has_double_jump()
	_check("double jump: loading a save at the start, at each of the three checkpoints and at the ending still has it", all_paths)
	GameState.start_new_game()
	_decide(2)
	GameState.set_checkpoint("level_3_mid_2")
	GameState.save_to_disk()
	GameState.start_new_game()
	var disk_result: Dictionary = GameState.load_from_disk()
	var from_disk: bool = bool(disk_result.get("ok", false))
	_check("double jump: continuing from disk (a real file) keeps the decisions and so the double jump", from_disk and probe.has_double_jump())
	# 3. A respawn at a checkpoint does not touch the decisions.
	var level: Node = _level()
	add_child(level)
	await _physics(6)
	var level_player: Player = level.get("player") as Player
	var before: int = GameState.decisions.size()
	level_player.global_position = Vector2(1468.0, 960.0)
	await _physics(90)
	_check("double jump: after dying in a gap and respawning at a checkpoint it is still there (%d decisions, unlocked %s)" % [GameState.decisions.size(), str(level_player.has_double_jump())], GameState.decisions.size() == before and level_player.has_double_jump())
	level.free()
	# 4. Fewer than two decisions: not unlocked, by design; gap 1 and the assist are the way (measured below).
	_clean_state()
	_decide(1)
	_check("double jump: with fewer than two decisions it is NOT unlocked (by design); gap 1 is crossed with jump + dash and the assist helps from the fourth fall", not probe.has_double_jump())
	probe.free()
	await _physics(2)


# ---------------------------------------------------------------------------------------------
# Step 1: the real player over each gap
# ---------------------------------------------------------------------------------------------

func _build_world(gap: float) -> void:
	if world != null:
		world.free()
	world = Node2D.new()
	add_child(world)
	for spec in [[-2000.0, 0.0], [gap, gap + 2000.0]]:
		var body := StaticBody2D.new()
		body.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
		body.position = Vector2((float(spec[0]) + float(spec[1])) * 0.5, FLOOR_Y + 20.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(absf(float(spec[1]) - float(spec[0])), 40.0)
		shape.shape = rect
		body.add_child(shape)
		world.add_child(body)
	player = PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(-300.0, FLOOR_Y - 26.0)
	world.add_child(player)
	player.story_invulnerable = true


## One run: the player runs right, takes off when the body center reaches `tx` (relative to the floor edge at 0), double jumps at
## `double_frame` and dashes at `dash_frame` (physics frames after takeoff, -1 = never). Returns {"ok", "takeoff"}.
func _attempt(gap: float, tx: float, double_frame: int, dash_frame: int) -> Dictionary:
	runs += 1
	player.global_position = Vector2(tx - 110.0, FLOOR_Y - 26.0)
	player.velocity = Vector2.ZERO
	await _physics(16)
	Input.action_press(&"move_right")
	var result: Dictionary = {"ok": false, "takeoff": 0.0}
	var frame: int = -1
	var guard: int = 0
	while guard < 400:
		await get_tree().physics_frame
		guard += 1
		if frame < 0:
			if player.global_position.x >= tx:
				result["takeoff"] = player.global_position.x
				Input.action_press(&"jump")
				frame = 0
			continue
		frame += 1
		if double_frame >= 0:
			if frame == double_frame - 1 and double_frame > 1:
				Input.action_release(&"jump")
			if frame == double_frame:
				Input.action_press(&"jump")
			if frame == double_frame + 24:
				Input.action_release(&"jump")
		elif frame == 26:
			Input.action_release(&"jump")
		if dash_frame >= 0:
			if frame == dash_frame:
				Input.action_press(&"dash")
			if frame == dash_frame + 2:
				Input.action_release(&"dash")
		if frame > 4 and player.is_on_floor():
			result["ok"] = player.global_position.x > gap - 20.0
			break
		if player.global_position.y > FLOOR_Y + 60.0:
			break
		if frame > 150:
			break
	for action in [&"move_right", &"jump", &"dash"]:
		Input.action_release(action)
	return result


## Sweeps one action's frame from `low` to `high` (the other fixed); returns the frames that crossed.
func _sweep(gap: float, tx: float, which: String, low: int, high: int, step: int, fixed_double: int, fixed_dash: int) -> Array[int]:
	var good: Array[int] = []
	var frame: int = low
	while frame <= high:
		if Time.get_ticks_msec() - started_ms > BUDGET_MS:
			budget_hit = true
			break
		var attempt: Dictionary = await _attempt(gap, tx, frame if which == "double" else fixed_double, frame if which == "dash" else fixed_dash)
		if attempt["ok"]:
			good.append(frame)
		frame += step
	return good


## The longest run of consecutive frames in `good` (step 1) as [first, last]; [-1, -1] if none.
func _longest(good: Array[int]) -> Array[int]:
	var best: Array[int] = [-1, -1]
	var start: int = -1
	var previous: int = -99
	for frame in good:
		if frame != previous + 1:
			start = frame
		previous = frame
		if best[0] < 0 or frame - start > best[1] - best[0]:
			best = [start, frame]
	return best


func _window_ms(run: Array[int]) -> float:
	return 0.0 if run[0] < 0 else float(run[1] - run[0] + 1) * FRAME_MS


## Takeoff positions (the body center, relative to the edge) from -30 to +14 in steps of 3: the contiguous width that crossed.
func _offset_window(gap: float, double_frame: int, dash_frame: int) -> Array[float]:
	var good: Array[float] = []
	var tx: float = -30.0
	while tx <= 14.0:
		if Time.get_ticks_msec() - started_ms > BUDGET_MS:
			budget_hit = true
			break
		var attempt: Dictionary = await _attempt(gap, tx, double_frame, dash_frame)
		if attempt["ok"]:
			good.append(float(attempt["takeoff"]))
		tx += 3.0
	return good


func _span(positions: Array[float]) -> float:
	if positions.is_empty():
		return 0.0
	return positions.max() - positions.min() + 3.0


## Finds the best timing of the two second actions for a strategy and returns {"a", "b", "a_ms", "b_ms", "offset_px"}.
func _measure(gap: float, uses_double: bool, uses_dash: bool) -> Dictionary:
	var a_best: int = -1
	var b_best: int = -1
	var out: Dictionary = {"a": -1, "b": -1, "a_ms": 0.0, "b_ms": 0.0, "offset_px": 0.0, "ok": false}
	if uses_double and not uses_dash:
		var good: Array[int] = await _sweep(gap, 0.0, "double", 3, 70, 1, -1, -1)
		var run: Array[int] = _longest(good)
		out["a_ms"] = _window_ms(run)
		a_best = (run[0] + run[1]) / 2 if run[0] >= 0 else -1
	elif uses_dash and not uses_double:
		var good_b: Array[int] = await _sweep(gap, 0.0, "dash", 3, 70, 1, -1, -1)
		var run_b: Array[int] = _longest(good_b)
		out["b_ms"] = _window_ms(run_b)
		b_best = (run_b[0] + run_b[1]) / 2 if run_b[0] >= 0 else -1
	else:
		# The chain: a coarse grid to find a pair that crosses, then a fine sweep of each action around the other.
		var seed_a: int = -1
		var seed_b: int = -1
		var a_try: int = 16
		while a_try <= 52 and seed_a < 0:
			var b_try: int = 4
			while b_try <= 44 and seed_a < 0:
				if Time.get_ticks_msec() - started_ms > BUDGET_MS:
					budget_hit = true
					return out
				var attempt: Dictionary = await _attempt(gap, 0.0, a_try, b_try)
				if attempt["ok"]:
					seed_a = a_try
					seed_b = b_try
				b_try += 4
			a_try += 4
		if seed_a < 0:
			return out
		var good_a: Array[int] = await _sweep(gap, 0.0, "double", 3, 70, 1, -1, seed_b)
		var run_a: Array[int] = _longest(good_a)
		a_best = (run_a[0] + run_a[1]) / 2 if run_a[0] >= 0 else seed_a
		var good_d: Array[int] = await _sweep(gap, 0.0, "dash", 3, 70, 1, a_best, -1)
		var run_d: Array[int] = _longest(good_d)
		b_best = (run_d[0] + run_d[1]) / 2 if run_d[0] >= 0 else seed_b
		var again: Array[int] = await _sweep(gap, 0.0, "double", 3, 70, 1, -1, b_best)
		var run_again: Array[int] = _longest(again)
		out["a_ms"] = _window_ms(run_again)
		out["b_ms"] = _window_ms(run_d)
		a_best = (run_again[0] + run_again[1]) / 2 if run_again[0] >= 0 else a_best
	out["a"] = a_best
	out["b"] = b_best
	if (uses_double and a_best < 0) or (uses_dash and b_best < 0):
		return out
	var offsets: Array[float] = await _offset_window(gap, a_best if uses_double else -1, b_best if uses_dash else -1)
	out["offset_px"] = _span(offsets)
	out["ok"] = true
	return out


## Whether any timing of the given action alone (or the plain jump) crosses: a coarse sweep of 2 frames.
func _can_cross(gap: float, which: String) -> bool:
	if which == "jump":
		for tx in [-20.0, -10.0, 0.0, 10.0, 14.0]:
			var attempt: Dictionary = await _attempt(gap, tx, -1, -1)
			if attempt["ok"]:
				return true
		return false
	var good: Array[int] = await _sweep(gap, 0.0, which, 3, 70, 2, -1, -1)
	if which == "double":
		for tx in [-10.0, 10.0]:
			var better: Array[int] = await _sweep(gap, tx, which, 3, 70, 4, -1, -1)
			good.append_array(better)
	return not good.is_empty()


func _test_sweeps(gaps: Array[Vector2]) -> void:
	_fast(true)
	var table: PackedStringArray = PackedStringArray()
	for i in 3:
		var gap: float = gaps[i].y - gaps[i].x
		_clean_state()
		_fast(true)
		_build_world(gap)
		await _physics(8)
		var timing_target: float = config.target_timing_seconds[i] * 1000.0
		var offset_target: float = config.target_offset_px[i]
		if i == 0:
			# Gap 1: jump + double jump (two decisions), jump + dash with the double jump LOCKED (one decision), and all three.
			_decide(2)
			var both: Dictionary = await _measure(gap, true, false)
			var all_three: Dictionary = await _measure(gap, true, true)
			GameState.start_new_game()
			_decide(1)
			var locked: bool = not player.has_double_jump()
			var dash_only: Dictionary = await _measure(gap, false, true)
			_decide(1)
			var plain: bool = await _can_cross(gap, "jump")
			_report(table, i, gap, "jump + double jump", both, true, false)
			_report(table, i, gap, "jump + dash (double jump locked)", dash_only, false, true)
			_report(table, i, gap, "jump + double jump + dash", all_three, true, true)
			_check("gap 1: jump + double jump gives a %.0f ms timing window (target %.0f) and a %.0f px takeoff window (target %.0f)" % [both["a_ms"], timing_target, both["offset_px"], offset_target], both["ok"] and both["a_ms"] >= timing_target and both["offset_px"] >= offset_target)
			_check("gap 1: jump + dash, with the double jump locked (fewer than 2 decisions), gives a %.0f ms window (target %.0f) and a %.0f px takeoff window (target %.0f)" % [dash_only["b_ms"], timing_target, dash_only["offset_px"], offset_target], locked and dash_only["ok"] and dash_only["b_ms"] >= timing_target and dash_only["offset_px"] >= offset_target)
			_check("gap 1: the three-action chain crosses too (second action %.0f ms, third %.0f ms)" % [all_three["a_ms"], all_three["b_ms"]], all_three["ok"] and all_three["a_ms"] >= timing_target)
			_check("gap 1: the plain jump does not cross it", not plain)
		else:
			_decide(2)
			var chain: Dictionary = await _measure(gap, true, true)
			var double_alone: bool = await _can_cross(gap, "double")
			var dash_alone: bool = await _can_cross(gap, "dash")
			var jump_alone: bool = await _can_cross(gap, "jump")
			_report(table, i, gap, "jump + double jump + dash", chain, true, true)
			_check("gap %d: the three-action chain gives a %.0f ms window for the double jump and %.0f ms for the dash (target %.0f) and a %.0f px takeoff window" % [i + 1, chain["a_ms"], chain["b_ms"], timing_target, chain["offset_px"]], chain["ok"] and chain["a_ms"] >= timing_target and chain["b_ms"] >= timing_target and chain["offset_px"] >= offset_target)
			_check("gap %d: the double jump alone, the dash alone and the plain jump all fail (%s / %s / %s)" % [i + 1, str(double_alone), str(dash_alone), str(jump_alone)], not double_alone and not dash_alone and not jump_alone)
	_fast(false)
	if world != null:
		world.free()
		world = null
		player = null
	print("MEASURE|tolerance windows (real player, takeoff at the edge, timing in ms, takeoff in px)|%s" % " || ".join(table))
	_check("sweeps: finished inside the time budget (%d runs, %.0f s)" % [runs, float(Time.get_ticks_msec() - started_ms) / 1000.0], not budget_hit)


func _report(table: PackedStringArray, index: int, gap: float, strategy: String, result: Dictionary, uses_double: bool, uses_dash: bool) -> void:
	var timing: String = ""
	if uses_double:
		timing += "double jump at %.2f s window %.0f ms" % [float(result["a"]) / 60.0, result["a_ms"]]
	if uses_dash:
		timing += (" / " if uses_double else "") + "dash at %.2f s window %.0f ms" % [float(result["b"]) / 60.0, result["b_ms"]]
	table.append("gap %d (%.0f px) %s: %s, takeoff window %.0f px" % [index + 1, gap, strategy, timing, result["offset_px"]])


# ---------------------------------------------------------------------------------------------
# The stuck-player assist
# ---------------------------------------------------------------------------------------------

func _fall_into(level_player: Player, x: float) -> void:
	level_player.global_position = Vector2(x, 960.0)
	var guard: int = 0
	while not level_player.is_dead and guard < 120:
		await get_tree().physics_frame
		guard += 1
	guard = 0
	while level_player.is_dead and guard < 600:
		await get_tree().physics_frame
		guard += 1


func _assist_nodes(level: Node) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for child in level.get_node("Content").get_children():
		if child.name.begins_with("AssistWreck"):
			names.append(child.name)
	return names


func _test_assist() -> void:
	_clean_state()
	_decide(2)
	var level: Node = _level()
	add_child(level)
	await _physics(8)
	var guard := level.get_node("GapGuard") as GapGuard
	var level_player: Player = level.get("player") as Player
	_fast(true)
	_check("assist: no platform at the start of the session", _assist_nodes(level).is_empty())
	for i in 3:
		await _fall_into(level_player, 1468.0)
	_check("assist: three falls into gap 1 do not bring it (the count is %d)" % GameState.director.telemetry.gap_fall_count(3, 0), GameState.director.telemetry.gap_fall_count(3, 0) == 3 and _assist_nodes(level).is_empty())
	for i in 3:
		await _fall_into(level_player, 2976.0)
	_check("assist: falls into another gap are counted apart (gap 2 has %d, gap 1 still %d, nothing appears)" % [GameState.director.telemetry.gap_fall_count(3, 1), GameState.director.telemetry.gap_fall_count(3, 0)], GameState.director.telemetry.gap_fall_count(3, 1) == 3 and _assist_nodes(level).is_empty())
	await _fall_into(level_player, 1468.0)
	var names: PackedStringArray = _assist_nodes(level)
	_check("assist: the fourth fall into gap 1 adds exactly one wreck platform, in gap 1 only", names == PackedStringArray(["AssistWreck1"]) and guard.assists.size() == 1, str(names))
	var wreck := level.get_node("Content/AssistWreck1") as Node2D
	var gap_one := guard.gaps[0]
	var size: Vector2 = wreck.get("size")
	_check("assist: %.0f px wide, one-way, its top at the floor height (%.0f), centered in the gap (x %.0f, gap %.0f to %.0f), inside it" % [size.x, wreck.position.y - size.y * 0.5, wreck.position.x, gap_one.x, gap_one.y],
		is_equal_approx(size.x, config.assist_width) and bool(wreck.get("one_way")) and is_equal_approx(wreck.position.y - size.y * 0.5, 600.0)
		and is_equal_approx(wreck.position.x, (gap_one.x + gap_one.y) * 0.5) and wreck.position.x - size.x * 0.5 > gap_one.x and wreck.position.x + size.x * 0.5 < gap_one.y)
	var reach: float = 206.0 + 58.0
	var worst_half: float = 0.0
	for index in guard.gaps.size():
		worst_half = maxf(worst_half, (guard.gaps[index].y - guard.gaps[index].x - config.assist_width) * 0.5)
	_check("assist: with it every gap becomes two jumps of at most %.0f px, inside the plain jump reach (%.0f px)" % [worst_half, reach], worst_half <= reach)
	# A fifth fall changes nothing; a death far from every gap and one in the boss arena never count.
	await _fall_into(level_player, 1468.0)
	_check("assist: more falls do not add another", _assist_nodes(level).size() == 1)
	var counts_before: Dictionary = GameState.director.telemetry.gap_falls.duplicate(true)
	_check("assist: the boss arena (x 5700 to 6700) is not in any gap, so a death there never counts or adds a platform", guard.gap_index_at(6200.0) == -1 and guard.gap_index_at(5800.0) == -1 and GameState.director.telemetry.gap_falls == counts_before)
	_fast(false)
	# It is in memory only.
	var saved: String = JSON.stringify(GameState.to_dict())
	var keys: Array = GameState.to_dict().keys()
	_check("assist: nothing about it is saved (the seven keys, no gap in the save data)", keys.size() == 7 and not saved.to_lower().contains("gap") and not saved.to_lower().contains("assist") and not saved.to_lower().contains("wreck"))
	_check("assist: it is not a metric: the telemetry metrics and its summary never mention it", not RunTelemetry.METRICS.has("gap_falls") and not GameState.director.telemetry.summarize(3).has("gap_falls"))
	# The platform is back when level 3 is entered again in the same session.
	level.free()
	await _physics(2)
	var again: Node = _level()
	add_child(again)
	await _physics(8)
	_check("assist: entering level 3 again in the same session brings it back (gap 1 only)", _assist_nodes(again) == PackedStringArray(["AssistWreck1"]))
	again.free()
	await _physics(2)
	# New game and loaded save reset it.
	GameState.start_new_game()
	_decide(2)
	var fresh: Node = _level()
	add_child(fresh)
	await _physics(8)
	_check("assist: a new game forgets the falls (no platform, count 0)", _assist_nodes(fresh).is_empty() and GameState.director.telemetry.gap_fall_count(3, 0) == 0)
	fresh.free()
	GameState.director.telemetry.record_gap_fall(3, 0)
	var snapshot: Dictionary = GameState.to_dict()
	GameState.load_from_dict(snapshot)
	_check("assist: loading a save forgets the falls too", GameState.director.telemetry.gap_fall_count(3, 0) == 0)
	await _physics(2)
	var nodes_before: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var churn: Node = _level()
	add_child(churn)
	await _physics(4)
	churn.free()
	await _physics(4)
	_check("leaks: no nodes are left behind by a level load (%d nodes before, %d after)" % [nodes_before, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))], int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) <= nodes_before + 2)
