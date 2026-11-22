extends Node
## Smoke test for Phase 15e-2: the gaps of level 3 redesigned for the double jump. The reach table is computed from the real
## player stats (a small time-step model of the real movement code), every gap of level 3 is checked against it, the rest of the
## level is checked to have shifted consistently, enemies keep 150 px from every gap edge, the boss 3 arena has no hole and levels
## 1 and 2 are byte-identical to before. A synthetic copy of the three gaps is then crossed with the REAL player. Lines starting with
## "MEASURE|" go to docs/BALANCE_REPORT.md. Development only. Run (alone, about a minute):
##   <godot> --headless --path game res://frontend/scenes/test/phase15e2_smoke_test.tscn
## Uses a redirected save path; the real save, settings and controls are never touched.

const TEST_SAVE: String = "user://test_save_phase15e2.json"
const TEST_SETTINGS: String = "user://test_settings_phase15e2.cfg"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const LEVEL_THREE: PackedScene = preload("res://frontend/levels/level_3.tscn")
const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const LEVEL_ONE_MD5: String = "0e26106a46848215f2ec25d5280c1fed"
const LEVEL_TWO_MD5: String = "09e2ccd6a5c2c4e0b53846990e7eef61"
const OLD_GAPS: Array[float] = [285.0, 175.0, 285.0]
## Old (Phase 15e-1) x of every level 3 element that sits after the first floor, with the floor it was on (1 = B, 2 = C, 3 = D).
const OLD_X: Dictionary = {
	"FloorB": [2142.5, 1], "LedgeLow": [1900.0, 1], "LedgeHigh": [2150.0, 1], "CheckpointMid1": [1650.0, 1], "Ranged1": [1900.0, 1],
	"Ranged2": [2150.0, 1], "Melee1": [2330.0, 1], "Fast1": [2550.0, 1], "ExtraMelee": [2020.0, 1],
	"FloorC": [3387.5, 2], "TowerLow": [3150.0, 2], "TowerMid": [3350.0, 2], "TowerTop": [3550.0, 2], "CheckpointMid2": [2950.0, 2],
	"Fast2": [3050.0, 2], "Ranged3": [3550.0, 2], "Melee2": [3750.0, 2], "ExtraRanged": [3350.0, 2],
	"FloorD": [5192.5, 3], "Melee3": [4500.0, 3], "GirderB": [4300.0, 3], "ContainerB": [4940.0, 3], "CraneHookB": [4760.0, 3],
	"CheckpointArena": [4850.0, 3], "ExtraFast": [4650.0, 3], "ArenaGate": [5100.0, 3], "ArenaCeiling": [5640.0, 3], "WallRight": [6170.0, 3],
	"Encounter": [5220.0, 3], "Boss": [5800.0, 3],
}
const OLD_STILL: Dictionary = {"WallLeft": -20.0, "FloorA": 650.0, "CheckpointStart": 200.0, "Fast3": 1000.0, "ContainerA": 450.0, "GirderA": 650.0, "CraneHookA": 830.0}
const OLD_CAMERA_RIGHT: int = 6220
const OLD_BIOME_ZONE_X: float = 2787.5
const FLOOR_Y: float = 620.0

var failures: int = 0
var real_save_before: String = ""
var real_settings_before: String = ""
var real_controls_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig
var stats: PlayerStats = PlayerStats.new()

## Center travel of the best timing of each combination (px), and the forgiveness added by the real collision/coyote rules.
var reach_jump: float = 0.0
var reach_double: float = 0.0
var reach_dash: float = 0.0
var reach_all: float = 0.0
var forgiveness: float = 0.0
var best_args: Dictionary = {}
var last_cross: String = ""


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
	_test_reach_table()
	var level: Node = LEVEL_THREE.instantiate()
	var gaps: Array[Dictionary] = _test_gaps(level)
	_test_shift(level, gaps)
	_test_checkpoints(level, gaps)
	_test_enemy_placement(level, gaps)
	_test_no_hazards_and_softlock(level, gaps)
	_test_arena_static(level)
	level.free()
	_test_other_levels()
	await _test_arena_real()
	await _test_real_crossings(gaps)
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
# 1. The reach table, from the real stats
# ---------------------------------------------------------------------------------------------

## One airborne jump from a floor edge, step by step, with the movement rules of player.gd: horizontal speed max_speed, gravity,
## the double jump `double_dj_at` seconds after the jump (never during a dash), and the dash `dash_at` seconds after the jump
## (gravity off and speed dash_speed for dash_duration). Returns the horizontal travel of the body center until it is back on the
## takeoff height. A negative time means "not used".
func _simulate(double_dj_at: float, dash_at: float, dt: float) -> float:
	var t: float = 0.0
	var y: float = 0.0
	var vy: float = -stats.jump_velocity
	var x: float = 0.0
	var doubled: bool = double_dj_at < 0.0
	var dashed: bool = dash_at < 0.0
	var dash_end: float = -1.0
	while t < 6.0:
		var dashing: bool = dash_end > 0.0 and t < dash_end
		if not doubled and t >= double_dj_at and not dashing:
			vy = -stats.double_jump_velocity
			doubled = true
		if not dashed and t >= dash_at:
			dashed = true
			dash_end = t + stats.dash_duration
			dashing = true
		if dashing:
			vy = 0.0
			x += stats.dash_speed * dt
		else:
			vy -= stats.gravity * dt
			y += vy * dt
			x += stats.max_speed * dt
		t += dt
		if y <= 0.0 and vy < 0.0 and t > 0.05:
			return x
	return x


func _best(use_double: bool, use_dash: bool) -> float:
	var best: float = 0.0
	var best_a: float = -1.0
	var best_b: float = -1.0
	var a_values: Array[float] = []
	var b_values: Array[float] = []
	if use_double:
		for i in 50:
			a_values.append(float(i) * 0.02)
	else:
		a_values.append(-1.0)
	if use_dash:
		for i in 76:
			b_values.append(float(i) * 0.02)
	else:
		b_values.append(-1.0)
	for a in a_values:
		for b in b_values:
			var travel: float = _simulate(a, b, 0.004)
			if travel > best:
				best = travel
				best_a = a
				best_b = b
	# A finer pass round the best timing.
	var fine_best: float = best
	for da in ([-0.016, -0.008, 0.0, 0.008, 0.016] if use_double else [0.0]):
		for db in ([-0.016, -0.008, 0.0, 0.008, 0.016] if use_dash else [0.0]):
			var a2: float = best_a + da if use_double else -1.0
			var b2: float = best_b + db if use_dash else -1.0
			var travel2: float = _simulate(a2, b2, 0.002)
			if travel2 > fine_best:
				fine_best = travel2
				best_a = a2
				best_b = b2
	best_args[[use_double, use_dash]] = [best_a, best_b]
	return fine_best


func _test_reach_table() -> void:
	var body := PLAYER_SCENE.instantiate() as Player
	var body_width: float = ((body.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size.x
	body.free()
	reach_jump = _best(false, false)
	reach_double = _best(true, false)
	reach_dash = _best(false, true)
	reach_all = _best(true, true)
	# Forgiveness of the real rules: the body stays on the floor while it overlaps it (half its width past the edge), the coyote
	# time lets the jump start a little later and the landing only needs the body to overlap the far floor (half its width).
	forgiveness = body_width * 0.5 + stats.coyote_time * stats.max_speed + body_width * 0.5
	var analytic_jump: float = stats.max_speed * 2.0 * absf(stats.jump_velocity) / stats.gravity
	print("MEASURE|reach (body center travel, best timing)|jump %.1f|jump + double jump %.1f|jump + dash %.1f|jump + double jump + dash %.1f|forgiveness %.0f px (takeoff overhang %.0f + coyote %.0f + landing overlap %.0f)" % [reach_jump, reach_double, reach_dash, reach_all, forgiveness, body_width * 0.5, stats.coyote_time * stats.max_speed, body_width * 0.5])
	print("MEASURE|reach (widest floor gap, with the forgiveness)|jump %.0f|jump + double jump %.0f|jump + dash %.0f|jump + double jump + dash %.0f|best timing (s after the jump): double jump %.2f / dash %.2f for the three-move combination" % [reach_jump + forgiveness, reach_double + forgiveness, reach_dash + forgiveness, reach_all + forgiveness, best_args[[true, true]][0], best_args[[true, true]][1]])
	_check("reach: the plain jump matches the closed form (%.1f px against %.1f)" % [reach_jump, analytic_jump], absf(reach_jump - analytic_jump) < 3.0)
	_check("reach: every extra move adds distance (jump < jump + dash < jump + double jump + dash, jump < jump + double jump < all)", reach_jump < reach_dash and reach_dash < reach_all and reach_jump < reach_double and reach_double < reach_all)
	_check("reach: the dash adds at least its own extra travel (%.0f px)" % ((stats.dash_speed - stats.max_speed) * stats.dash_duration), reach_dash - reach_jump >= (stats.dash_speed - stats.max_speed) * stats.dash_duration - 2.0)


# ---------------------------------------------------------------------------------------------
# 2. The gaps
# ---------------------------------------------------------------------------------------------

func _floor_nodes(level: Node) -> Array[Node2D]:
	var floors: Array[Node2D] = []
	for floor_name in ["FloorA", "FloorB", "FloorC", "FloorD"]:
		floors.append(level.get_node("Content/%s" % floor_name) as Node2D)
	return floors


func _left(node: Node2D) -> float:
	return node.position.x - float(node.get("size").x) * 0.5


func _right(node: Node2D) -> float:
	return node.position.x + float(node.get("size").x) * 0.5


## The combination a gap needs, from its width and the effective reach table.
func _needs(width: float) -> String:
	if width <= reach_jump + forgiveness:
		return "jump"
	if width <= minf(reach_double, reach_dash) + forgiveness:
		return "double jump or dash"
	if width <= maxf(reach_double, reach_dash) + forgiveness:
		return "double jump + dash"
	if width <= reach_all + forgiveness:
		return "double jump + dash"
	return "impossible"


func _test_gaps(level: Node) -> Array[Dictionary]:
	var floors: Array[Node2D] = _floor_nodes(level)
	var gaps: Array[Dictionary] = []
	for i in floors.size() - 1:
		gaps.append({"start": _right(floors[i]), "end": _left(floors[i + 1]), "width": _left(floors[i + 1]) - _right(floors[i]), "dy": floors[i + 1].position.y - floors[i].position.y,
			"landing": float(floors[i + 1].get("size").x)})
	var double_alone: float = maxf(reach_double, reach_dash) + forgiveness
	var chain_top: float = 0.88 * reach_all
	var easy_top: float = 0.88 * (reach_double + forgiveness)
	var rows: PackedStringArray = PackedStringArray()
	var open_pits: bool = true
	for i in gaps.size():
		var gap: Dictionary = gaps[i]
		var width: float = gap["width"]
		open_pits = open_pits and absf(float(gap["dy"])) < 0.01
		var need_reach: float = reach_double if i == 0 else reach_all
		var need_eff: float = need_reach + forgiveness
		rows.append("gap %d: x %.0f to %.0f, old %.0f, new %.0f px, needs %s, margin over the centre travel %.1f%% (%.0f px of %.1f), effective margin %.1f%% (%.0f px of %.0f)" % [i + 1, gap["start"], gap["end"], OLD_GAPS[i], width, _needs(width), (1.0 - width / need_reach) * 100.0, need_reach - width, need_reach, (1.0 - width / need_eff) * 100.0, need_eff - width, need_eff])
	for row in rows:
		print("MEASURE|%s" % row)
	var w1: float = gaps[0]["width"]
	var w2: float = gaps[1]["width"]
	var w3: float = gaps[2]["width"]
	_check("gaps: there are three gaps and the pits are open (the same floor height on both sides, nothing between)", gaps.size() == 3 and open_pits)
	_check("gaps: gap 1 (%.0f px) is easy: wider than the plain jump (%.0f) and within jump + double jump with a margin (%.0f px of %.0f effective), so the dash is NOT required" % [w1, reach_jump + forgiveness, easy_top, reach_double + forgiveness],
		w1 > reach_jump + forgiveness and w1 <= easy_top)
	_check("gaps: gap 1 is at most 88%% of the centre-travel reach of jump + double jump (%.1f px of %.1f) and wider than the plain jump (%.0f)" % [0.88 * reach_double, reach_double, reach_jump + forgiveness], w1 <= 0.88 * reach_double + 0.01 and w1 > reach_jump + forgiveness)
	_check("gaps: gaps 2 and 3 (%.0f, %.0f px) are wider than jump + double jump (%.0f) and jump + dash (%.0f), so all three actions are needed" % [w2, w3, reach_double + forgiveness, reach_dash + forgiveness], w2 > double_alone and w3 > double_alone)
	_check("gaps: gaps needing the whole chain are at most 88%% of the centre-travel reach (%.1f px of %.1f)" % [chain_top, reach_all], w2 <= chain_top and w3 <= chain_top)
	_check("gaps: easy, medium, hard (%.0f < %.0f < %.0f)" % [w1, w2, w3], w1 < w2 and w2 < w3)
	var widths: Array[float] = [w1, w2, w3]
	_check("gaps: every one is wider than before the phase", w1 > OLD_GAPS[0] and w2 > OLD_GAPS[1] and w3 > OLD_GAPS[2])
	# A landing platform of at least 200 px, and room for the dash cooldown before the next gap (and a run-up for it).
	var recovery: float = 200.0
	var cooldown_run: float = stats.dash_cooldown * stats.max_speed
	var landing_ok: bool = true
	for i in gaps.size():
		var floor_after: float = gaps[i]["landing"]
		landing_ok = landing_ok and floor_after >= recovery and floor_after >= recovery + cooldown_run
	_check("gaps: every landing floor is at least 200 px plus the dash cooldown run (%.0f px) before the next edge" % cooldown_run, landing_ok)
	var min_landing: float = 1e9
	for gap in gaps:
		min_landing = minf(min_landing, float(gap["landing"]))
	print("MEASURE|shortest landing floor after a gap %.0f px, dash cooldown %.1f s = %.0f px of walking" % [min_landing, stats.dash_cooldown, cooldown_run])
	return gaps


# ---------------------------------------------------------------------------------------------
# 3. The rest of the level moved by the added distance
# ---------------------------------------------------------------------------------------------

func _test_shift(level: Node, gaps: Array[Dictionary]) -> void:
	var added: Array[float] = []
	var running: float = 0.0
	for i in gaps.size():
		running += float(gaps[i]["width"]) - OLD_GAPS[i]
		added.append(running)
	var content: Node = level.get_node("Content")
	var wrong: PackedStringArray = PackedStringArray()
	for node_name: String in OLD_X.keys():
		var entry: Array = OLD_X[node_name]
		var expected: float = float(entry[0]) + added[int(entry[1]) - 1]
		var actual: float = (content.get_node(node_name) as Node2D).position.x
		if absf(actual - expected) > 0.01:
			wrong.append("%s %.1f instead of %.1f" % [node_name, actual, expected])
	for node_name: String in OLD_STILL.keys():
		if absf((content.get_node(node_name) as Node2D).position.x - float(OLD_STILL[node_name])) > 0.01:
			wrong.append("%s moved" % node_name)
	_check("shift: every platform, checkpoint, enemy, gate, wall, encounter and boss after a gap moved by exactly the distance added before it (%s)" % str(added), wrong.is_empty(), str(wrong))
	var gap_two_center: float = (float(gaps[1]["start"]) + float(gaps[1]["end"])) * 0.5
	var zone: Node2D = level.get_node("BiomeZone") as Node2D
	_check("shift: the storm biome trigger is still in the middle of the second gap (%.1f, old %.1f)" % [zone.position.x, OLD_BIOME_ZONE_X], absf(zone.position.x - gap_two_center) < 0.01)
	var camera: Rect2i = (level as LevelBase).camera_limits
	_check("shift: the camera limit grew by the whole added distance (%d instead of %d)" % [camera.end.x, OLD_CAMERA_RIGHT + int(added[2])], camera.end.x == OLD_CAMERA_RIGHT + int(added[2]) and camera.position.x == 0)
	var kill := content.get_node("KillZone") as Node2D
	var kill_half: float = float(kill.get("size").x) * 0.5
	_check("shift: the kill zone still spans the whole level (%.0f to %.0f) and sits under the floors" % [kill.position.x - kill_half, kill.position.x + kill_half], kill.position.x - kill_half <= 0.0 and kill.position.x + kill_half >= float(camera.end.x) and kill.position.y > FLOOR_Y + 100.0)
	var gate: Node2D = content.get_node("ArenaGate") as Node2D
	var encounter: Node2D = content.get_node("Encounter") as Node2D
	var boss: Node2D = content.get_node("Boss") as Node2D
	var wall: Node2D = content.get_node("WallRight") as Node2D
	_check("shift: the arena keeps its relative layout (gate to encounter %.0f, gate to boss %.0f, gate to right wall %.0f)" % [encounter.position.x - gate.position.x, boss.position.x - gate.position.x, wall.position.x - gate.position.x],
		is_equal_approx(encounter.position.x - gate.position.x, 120.0) and is_equal_approx(boss.position.x - gate.position.x, 700.0) and is_equal_approx(wall.position.x - gate.position.x, 1070.0))
	var beam_fallback: float = (level.get_node("Content/Boss/Patterns/Beam") as BeamSweepPattern).fallback_left
	_check("shift: the boss patterns' arena fall-back limits moved with the arena (%.0f, gate at %.0f)" % [beam_fallback, gate.position.x], absf(beam_fallback - (gate.position.x + 30.0)) < 0.01
		and absf((level.get_node("Content/Boss/Patterns/Beam") as BeamSweepPattern).fallback_right - (wall.position.x - 30.0)) < 0.01)
	var spawn: Node2D = level.get_node("SpawnPoint") as Node2D
	_check("shift: the spawn point and the first floor did not move", is_equal_approx(spawn.position.x, 120.0) and _left(content.get_node("FloorA") as Node2D) == 0.0)


func _test_checkpoints(level: Node, gaps: Array[Dictionary]) -> void:
	var content: Node = level.get_node("Content")
	var floors: Array[Node2D] = _floor_nodes(level)
	var checkpoints: Array[Node2D] = []
	for child in content.get_children():
		if child is Checkpoint:
			checkpoints.append(child as Node2D)
	checkpoints.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.x < b.position.x)
	var all_ok: bool = true
	var detail: PackedStringArray = PackedStringArray()
	for i in gaps.size():
		var start: float = gaps[i]["start"]
		var last: Node2D = null
		for checkpoint in checkpoints:
			if checkpoint.position.x < start:
				last = checkpoint
		var on_floor: bool = last != null and last.position.x >= _left(floors[i]) and last.position.x <= _right(floors[i])
		var run_up: float = start - last.position.x if last != null else 0.0
		all_ok = all_ok and on_floor and run_up >= 200.0
		detail.append("gap %d: respawn at x %.0f on the floor before it, %.0f px of run-up" % [i + 1, last.position.x if last != null else -1.0, run_up])
	_check("checkpoints: before every gap the last checkpoint is on the floor just before it with at least 200 px of run-up, so a fall never respawns past or before an impossible jump (%s)" % str(detail), all_ok)
	var past_hard: bool = false
	var hardest_index: int = 0
	for i in gaps.size():
		if float(gaps[i]["width"]) > float(gaps[hardest_index]["width"]):
			hardest_index = i
	for checkpoint in checkpoints:
		if checkpoint.position.x > float(gaps[hardest_index]["start"]) and checkpoint.position.x < float(gaps[hardest_index]["end"]):
			past_hard = true
	var arena_cp: Node2D = content.get_node("CheckpointArena") as Node2D
	_check("checkpoints: none sits over a gap, and the arena one is after the hardest gap's far edge (%.0f > %.0f)" % [arena_cp.position.x, float(gaps[hardest_index]["end"])], not past_hard and arena_cp.position.x > float(gaps[hardest_index]["end"]))
	var gate: Node2D = content.get_node("ArenaGate") as Node2D
	_check("checkpoints: the arena checkpoint is outside the arena, before the gate (%.0f px)" % (gate.position.x - arena_cp.position.x), gate.position.x - arena_cp.position.x >= 150.0)
	var order_ok: bool = true
	var last_order: int = -1
	for checkpoint in checkpoints:
		order_ok = order_ok and int(checkpoint.get("order")) > last_order
		last_order = int(checkpoint.get("order"))
	_check("checkpoints: their order matches their position along the level", order_ok)
	for checkpoint in checkpoints:
		var supported: bool = false
		for floor_node in floors:
			supported = supported or (checkpoint.position.x > _left(floor_node) + 20.0 and checkpoint.position.x < _right(floor_node) - 20.0 and checkpoint.position.y < floor_node.position.y)
		if not supported:
			_check("checkpoints: %s stands on a floor" % checkpoint.name, false)
			return
	_check("checkpoints: every checkpoint stands on a floor, away from its edges", true)


func _test_enemy_placement(level: Node, gaps: Array[Dictionary]) -> void:
	var content: Node = level.get_node("Content")
	var enemies: Array[Node2D] = []
	for child in content.get_children():
		if child is EnemyBase:
			enemies.append(child as Node2D)
	var closest: float = 1e9
	var closest_name: String = ""
	for enemy in enemies:
		for gap in gaps:
			for edge: float in [gap["start"], gap["end"]]:
				var distance: float = absf(enemy.position.x - edge)
				if distance < closest:
					closest = distance
					closest_name = "%s at x %.0f from the edge at %.0f" % [enemy.name, enemy.position.x, edge]
	print("MEASURE|closest enemy to a gap edge %.0f px (%s)" % [closest, closest_name])
	_check("enemies: none of the %d enemies (extras included) spawns within 150 px of a gap edge (closest %.0f px: %s)" % [enemies.size(), closest, closest_name], enemies.size() >= 12 and closest >= 150.0 - 0.01)
	# The adaptive extras are the `variant_groups` nodes of the level: fixed positions, so the same rule applies to them.
	var extras: int = 0
	var extras_ok: bool = true
	var groups: Dictionary = (level as LevelBase).variant_groups
	for group_id: Variant in groups.keys():
		for path: NodePath in groups[group_id]:
			var node: Node2D = level.get_node(path) as Node2D
			extras += 1
			for gap in gaps:
				extras_ok = extras_ok and absf(node.position.x - float(gap["start"])) >= 150.0 and absf(node.position.x - float(gap["end"])) >= 150.0
	_check("enemies: the %d adaptive extra enemies of the corrupted variant respect the 150 px rule too (the placement logic is fixed positions and did not need a change)" % extras, extras == 3 and extras_ok)
	var on_floor_ok: bool = true
	for enemy in enemies:
		var supported: bool = false
		for floor_node in _floor_nodes(level):
			supported = supported or (enemy.position.x > _left(floor_node) and enemy.position.x < _right(floor_node))
		on_floor_ok = on_floor_ok and supported
	_check("enemies: every enemy stands over a floor (nobody spawns over a pit)", on_floor_ok)


func _test_no_hazards_and_softlock(level: Node, gaps: Array[Dictionary]) -> void:
	var hazards: int = level.find_children("*", "FloorHazard", true, false).size()
	_check("softlock: level 3 has no floor hazards, so a respawn is never inside a hazard lane", hazards == 0)
	var floors: Array[Node2D] = _floor_nodes(level)
	var contiguous: bool = true
	for floor_node in floors:
		contiguous = contiguous and float(floor_node.get("size").x) >= 600.0
	var kill := level.get_node("Content/KillZone") as Node2D
	_check("softlock: every floor is long enough to walk back and forth, and any fall is a death that respawns at the last checkpoint (the kill zone is %.0f px under the floor)" % (kill.position.y - FLOOR_Y), contiguous and kill.position.y > FLOOR_Y)
	# Every ledge, tower and girder hangs over a floor (nothing is out of reach of a fall back to the floor).
	var over_floor: bool = true
	for child in level.get_node("Content").get_children():
		if child is PlaceholderPlatform and not str(child.name).begins_with("Floor") and not str(child.name).begins_with("Arena") and not str(child.name).begins_with("Wall"):
			var supported: bool = false
			for floor_node in floors:
				supported = supported or ((child as Node2D).position.x > _left(floor_node) and (child as Node2D).position.x < _right(floor_node))
			over_floor = over_floor and supported
	_check("softlock: every ledge, tower and girder hangs over a floor, so any jump down lands on ground that leads on (and none is needed to progress)", over_floor and gaps.size() == 3)


# ---------------------------------------------------------------------------------------------
# 4. Boss 3 arena without holes
# ---------------------------------------------------------------------------------------------

func _test_arena_static(level: Node) -> void:
	var content: Node = level.get_node("Content")
	var floor_d: Node2D = content.get_node("FloorD") as Node2D
	var gate: Node2D = content.get_node("ArenaGate") as Node2D
	var ceiling: Node2D = content.get_node("ArenaCeiling") as Node2D
	var wall: Node2D = content.get_node("WallRight") as Node2D
	var gate_left: float = gate.position.x - float(gate.get("size").x) * 0.5
	var wall_outer: float = wall.position.x + float(wall.get("size").x) * 0.5
	_check("arena: one single floor runs under the whole arena, from before the gate (%.0f) to past the outer face of the right wall (%.0f)" % [_left(floor_d), wall_outer], _left(floor_d) < gate_left - 200.0 and _right(floor_d) >= wall_outer)
	var wall_top: float = wall.position.y - float(wall.get("size").y) * 0.5
	var wall_bottom: float = wall.position.y + float(wall.get("size").y) * 0.5
	var gate_top: float = gate.position.y - float(gate.get("size").y) * 0.5
	var gate_bottom: float = gate.position.y + float(gate.get("size").y) * 0.5
	var ceiling_bottom: float = ceiling.position.y + float(ceiling.get("size").y) * 0.5
	var ceiling_top: float = ceiling.position.y - float(ceiling.get("size").y) * 0.5
	var floor_top: float = floor_d.position.y - float(floor_d.get("size").y) * 0.5
	_check("arena: the right wall reaches the floor (bottom %.0f, floor top %.0f) and the ceiling (top %.0f, ceiling bottom %.0f), no gap at its foot or its head" % [wall_bottom, floor_top, wall_top, ceiling_bottom], wall_bottom >= floor_top and wall_top <= ceiling_bottom)
	_check("arena: the gate reaches the floor (bottom %.0f) and the ceiling (top %.0f, ceiling bottom %.0f)" % [gate_bottom, gate_top, ceiling_bottom], gate_bottom >= floor_top and gate_top <= ceiling_bottom + 0.01)
	_check("arena: the ceiling spans from the gate to the right wall's outer face (%.0f to %.0f over %.0f to %.0f)" % [_left(ceiling), _right(ceiling), gate_left, wall_outer], _left(ceiling) <= gate_left + 20.0 and _right(ceiling) >= wall_outer)
	_check("arena: the ceiling is high enough not to bump the double jump (ceiling bottom %.0f)" % ceiling_bottom, ceiling_top < ceiling_bottom and floor_top - ceiling_bottom >= 400.0)


func _test_arena_real() -> void:
	_clean_state()
	var level := LEVEL_THREE.instantiate() as LevelBase
	add_child(level)
	await _physics(10)
	var player: Player = level.player
	player.story_invulnerable = true
	var gate: Node2D = level.get_node("Content/ArenaGate") as Node2D
	var wall: Node2D = level.get_node("Content/WallRight") as Node2D
	player.global_position = level.encounter.global_position
	await _physics(30)
	var lowest: float = 0.0
	var left_most: float = 1e9
	var right_most: float = -1e9
	var highest: float = 1e9
	Input.action_press(&"move_left")
	for i in 150:
		await get_tree().physics_frame
		left_most = minf(left_most, player.global_position.x)
		lowest = maxf(lowest, player.global_position.y)
	Input.action_release(&"move_left")
	Input.action_press(&"move_right")
	for i in 260:
		await get_tree().physics_frame
		right_most = maxf(right_most, player.global_position.x)
		lowest = maxf(lowest, player.global_position.y)
	# Jumping, double jumping and dashing along the right wall and under the ceiling.
	for i in 3:
		Input.action_press(&"jump")
		await _physics(3)
		Input.action_release(&"jump")
		await _physics(24)
		Input.action_press(&"jump")
		await _physics(3)
		Input.action_release(&"jump")
		Input.action_press(&"dash")
		await _physics(2)
		Input.action_release(&"dash")
		for k in 60:
			await get_tree().physics_frame
			highest = minf(highest, player.global_position.y)
			right_most = maxf(right_most, player.global_position.x)
	Input.action_release(&"move_right")
	var gate_right: float = gate.position.x + float(gate.get("size").x) * 0.5
	var wall_inner: float = wall.position.x - float(wall.get("size").x) * 0.5
	print("MEASURE|arena walk|left-most x %.0f (gate face %.0f)|right-most x %.0f (wall face %.0f)|lowest y %.0f|highest y %.0f" % [left_most, gate_right, right_most, wall_inner, lowest, highest])
	_check("arena (real): walking to both ends the player stays between the gate and the right wall (%.0f to %.0f inside %.0f to %.0f)" % [left_most, right_most, gate_right, wall_inner], left_most >= gate_right - 1.0 and right_most <= wall_inner + 1.0)
	_check("arena (real): the player never falls below the floor (lowest y %.0f) nor leaves through the ceiling (highest y %.0f)" % [lowest, highest], lowest < 640.0 and highest > 150.0)
	level.free()
	await _physics(3)


# ---------------------------------------------------------------------------------------------
# 5. Levels 1 and 2 untouched
# ---------------------------------------------------------------------------------------------

func _test_other_levels() -> void:
	_check("levels 1 and 2: their scene files are byte-identical to before the phase", FileAccess.get_md5("res://frontend/levels/level_1.tscn") == LEVEL_ONE_MD5 and FileAccess.get_md5("res://frontend/levels/level_2.tscn") == LEVEL_TWO_MD5,
		"%s %s" % [FileAccess.get_md5("res://frontend/levels/level_1.tscn"), FileAccess.get_md5("res://frontend/levels/level_2.tscn")])
	for path in ["res://frontend/levels/level_1.tscn", "res://frontend/levels/level_2.tscn"]:
		var level: Node = (load(path) as PackedScene).instantiate()
		var floors: int = 0
		var longest_gap: float = 0.0
		var edges: Array[Vector2] = []
		for child in level.get_node("Content").get_children():
			if child is PlaceholderPlatform and str(child.name).begins_with("Floor"):
				floors += 1
				edges.append(Vector2(_left(child as Node2D), _right(child as Node2D)))
		edges.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		for i in range(1, edges.size()):
			longest_gap = maxf(longest_gap, edges[i].x - edges[i - 1].y)
		print("MEASURE|%s: %d floors, widest gap %.0f px" % [path.get_file(), floors, longest_gap])
		_check("%s: its widest floor gap (%.0f px) is within the plain jump + dash reach, as designed for that level" % [path.get_file(), longest_gap], longest_gap <= reach_dash + forgiveness)
		level.free()


# ---------------------------------------------------------------------------------------------
# 6. The real player crosses (and does not cross) a copy of the three gaps
# ---------------------------------------------------------------------------------------------

## A flat world with a floor ending at x = 0 and the next one starting `gap` px later, and the real player on the first floor.
func _crossing_world(gap: float) -> Dictionary:
	var world := Node2D.new()
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
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(-500.0, FLOOR_Y - 26.0)
	world.add_child(player)
	player.story_invulnerable = true
	return {"world": world, "player": player}


## Runs the crossing with the given plan (frames after the jump at which to double jump and to dash; -1 = never). True if the
## player lands on the far floor.
func _cross(gap: float, double_frame: int, dash_frame: int) -> bool:
	var parts: Dictionary = _crossing_world(gap)
	var world: Node2D = parts["world"]
	var player: Player = parts["player"]
	await _physics(10)
	GameState.start_new_game()
	GameState.record_decision("test_a", "x", 1, GameState.CHOICE_KEPT)
	GameState.record_decision("test_b", "x", 2, GameState.CHOICE_KEPT)
	var landed: bool = false
	var doubles: Array[int] = [0]
	var dashes: Array[int] = [0]
	player.double_jumped.connect(func() -> void: doubles[0] += 1)
	player.dash_started.connect(func() -> void: dashes[0] += 1)
	Input.action_press(&"move_right")
	var frame: int = -1
	var guard: int = 0
	while guard < 60 * 8:
		await get_tree().physics_frame
		guard += 1
		if frame < 0:
			if player.global_position.x >= -1.0:
				Input.action_press(&"jump")
				frame = 0
			continue
		frame += 1
		if frame == 26:
			Input.action_release(&"jump")
		if frame == double_frame and double_frame >= 0:
			Input.action_press(&"jump")
		if frame == double_frame + 20 and double_frame >= 0:
			Input.action_release(&"jump")
		if frame == dash_frame and dash_frame >= 0:
			Input.action_press(&"dash")
		if frame == dash_frame + 2 and dash_frame >= 0:
			Input.action_release(&"dash")
		if frame > 20 and player.is_on_floor():
			landed = player.global_position.x > gap - 20.0
			break
		if player.global_position.y > FLOOR_Y + 150.0:
			break
	last_cross = "doubles %d dashes %d end x %.0f y %.0f unlocked %s" % [doubles[0], dashes[0], player.global_position.x, player.global_position.y, str(player.has_double_jump())]
	Input.action_release(&"move_right")
	Input.action_release(&"jump")
	Input.action_release(&"dash")
	world.free()
	await _physics(2)
	return landed


func _test_real_crossings(gaps: Array[Dictionary]) -> void:
	_clean_state()
	GameState.record_decision("test_a", "x", 1, GameState.CHOICE_KEPT)
	GameState.record_decision("test_b", "x", 2, GameState.CHOICE_KEPT)
	_check("crossing: the double jump is unlocked on entering level 3 (two decisions)", GameState.decisions.size() >= stats.double_jump_unlock_decisions)
	# The bot timings of the test code: double jump 36 frames and dash 69 frames after the jump (39 frames for the double jump alone).
	var results: PackedStringArray = PackedStringArray()
	for i in gaps.size():
		var width: float = gaps[i]["width"]
		if i == 0:
			var easy: bool = await _cross(width, 39, -1)
			var plain: bool = await _cross(width, -1, -1)
			results.append("gap 1 (%.0f px): jump + double jump %s (no dash), jump only %s" % [width, str(easy), str(plain)])
			_check("crossing: the real player crosses gap 1 (%.0f px) with jump + double jump and NO dash" % width, easy)
			_check("crossing: the real player does not cross gap 1 with the plain jump", not plain)
			continue
		var full: bool = await _cross(width, 36, 69)
		var no_dash: bool = await _cross(width, 36, -1)
		var no_double: bool = await _cross(width, -1, 14)
		var none: bool = await _cross(width, -1, -1)
		results.append("gap %d (%.0f px): all three moves %s, no dash %s, no double jump %s, jump only %s" % [i + 1, width, str(full), str(no_dash), str(no_double), str(none)])
		_check("crossing: the real player crosses gap %d (%.0f px) with jump + double jump + dash" % [i + 1, width], full)
		_check("crossing: the real player does not cross gap %d with the double jump alone, the dash alone or the plain jump (the usual timings)" % (i + 1), not no_dash and not no_double and not none)
	print("MEASURE|real player crossings|%s" % " | ".join(results))
	# Sanity of the model: the old 285 px gap was a jump + dash gap and is crossed with it.
	var old_with_dash: bool = await _cross(285.0, -1, 14)
	_check("crossing: the old 285 px gap is still crossable with jump + dash (the model matches the real player)", old_with_dash)
