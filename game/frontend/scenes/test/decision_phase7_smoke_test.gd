extends Node
## Headless smoke test for Phase 7: GameState, soul fragment drop/pickup, decision flow. Development only.
## Run: <godot> --headless --path game res://frontend/scenes/test/decision_phase7_smoke_test.tscn
## The "rejected decision" check intentionally makes GameState print a warning.

const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const BOSS_SCENE: PackedScene = preload("res://backend/bosses/placeholder_boss.tscn")
const ENCOUNTER_SCENE: PackedScene = preload("res://backend/bosses/boss_encounter.tscn")
const FRAGMENT_SCENE: PackedScene = preload("res://backend/decisions/soul_fragment.tscn")
const PANEL_SCENE: PackedScene = preload("res://frontend/ui/decision_panel.tscn")
const BOSS_TEST_SCENE: PackedScene = preload("res://frontend/scenes/test/boss_test.tscn")
const DATA_1: SoulFragmentData = preload("res://backend/decisions/data/fragment_level_1.tres")
const DATA_2: SoulFragmentData = preload("res://backend/decisions/data/fragment_level_2.tres")
const DATA_3: SoulFragmentData = preload("res://backend/decisions/data/fragment_level_3.tres")
const FLOOR_Y: float = 300.0
const BOSS_POS: Vector2 = Vector2(800.0, FLOOR_Y - 44.0)
const PLAYER_START: Vector2 = Vector2(-2000.0, FLOOR_Y - 30.0)
const DROP_DELAY: float = 0.3
const EXPECTED_KEYS: Array[String] = [
	"save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile",
]

var failures: int = 0
var player: Player
var spawned: Array[SoulFragment] = []


func _ready() -> void:
	# Never touch the real save file.
	SaveSystem.set_save_path("user://test_save_phase7.json")
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	floor_body.collision_mask = 0
	floor_body.position = Vector2(0.0, FLOOR_Y + 20.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6000.0, 40.0)
	shape.shape = rect
	floor_body.add_child(shape)
	add_child(floor_body)
	child_entered_tree.connect(func(node: Node) -> void:
		if node is SoulFragment:
			spawned.append(node as SoulFragment))
	player = PLAYER_SCENE.instantiate() as Player
	player.position = PLAYER_START
	add_child(player)
	_run.call_deferred()


func _check(check_name: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("PASS: %s %s" % [check_name, detail])
	else:
		failures += 1
		print("FAIL: %s %s" % [check_name, detail])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _wait_until(condition: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


## Condition that stays valid after the object is freed (captures only its id).
func _freed(object: Object) -> Callable:
	var id: int = object.get_instance_id()
	return func() -> bool: return not is_instance_valid(instance_from_id(id))


func _live_fragments() -> Array[SoulFragment]:
	var result: Array[SoulFragment] = []
	for fragment in spawned:
		if is_instance_valid(fragment) and not fragment.is_queued_for_deletion():
			result.append(fragment)
	return result


func _reset_player() -> void:
	get_tree().paused = false
	player.health.invulnerability_time = 0.0
	player.revive()
	player.global_position = PLAYER_START
	player.velocity = Vector2.ZERO
	await _frames(40)


## Boss + drop + panel + flow (+ optional encounter on the player's start position).
func _make_rig(delay: float, with_encounter: bool = false, data: SoulFragmentData = DATA_1) -> Dictionary:
	var rig: Dictionary = {}
	var boss := BOSS_SCENE.instantiate() as BossBase
	boss.position = BOSS_POS
	add_child(boss)
	var drop := SoulFragmentDrop.new()
	drop.boss = boss
	drop.fragment_data = data
	drop.fragment_scene = FRAGMENT_SCENE
	drop.spawn_delay = delay
	add_child(drop)
	var panel := PANEL_SCENE.instantiate() as DecisionPanel
	add_child(panel)
	var flow := DecisionFlow.new()
	flow.drop = drop
	flow.panel = panel
	add_child(flow)
	rig = {"boss": boss, "drop": drop, "panel": panel, "flow": flow}
	if with_encounter:
		var encounter := ENCOUNTER_SCENE.instantiate() as BossEncounter
		encounter.boss = boss
		encounter.position = PLAYER_START
		add_child(encounter)
		rig["encounter"] = encounter
	return rig


func _free_rig(rig: Dictionary) -> void:
	for key in rig:
		var node: Variant = rig[key]
		if is_instance_valid(node):
			(node as Node).free()
	for fragment in _live_fragments():
		fragment.free()
	get_tree().paused = false
	await _frames(2)


func _move_player_onto(fragment: SoulFragment) -> void:
	player.global_position = fragment.global_position
	player.velocity = Vector2.ZERO


func _json_equal(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not _json_equal(a[key], b[key]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _json_equal(a[i], b[i]):
				return false
		return true
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	return a == b


func _run() -> void:
	_check("test node is current scene", get_tree().current_scene == self)
	GameState.reset_run()
	_test_game_state()
	await _test_drop()
	await _test_pickup()
	await _test_flow()
	await _test_integration()
	GameState.reset_run()
	get_tree().paused = false
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	SaveSystem.purge()
	SaveSystem.set_save_path(SaveSystem.DEFAULT_PATH)
	get_tree().quit(1 if failures > 0 else 0)


# --- GameState ---

func _test_game_state() -> void:
	GameState.reset_run()
	var fresh: Dictionary = GameState.to_dict()
	print("fresh to_dict: ", JSON.stringify(fresh))
	_check("GameState autoload in root", get_node_or_null("/root/GameState") == GameState)
	_check("defaults",
		GameState.save_version == 1 and GameState.current_level == 1 and GameState.checkpoint == "start"
		and GameState.souls_released == 0 and GameState.souls_kept == 0 and GameState.decisions.is_empty()
		and GameState.adaptive_profile == "neutral")
	var keys: Array = fresh.keys()
	keys.sort()
	var expected: Array = EXPECTED_KEYS.duplicate()
	expected.sort()
	_check("to_dict has exactly the seven keys", keys == expected, str(keys))
	_check("choice helper", GameState.is_valid_choice("released") and GameState.is_valid_choice("kept")
		and not GameState.is_valid_choice("") and not GameState.is_valid_choice("Released"))

	var emitted: Array[Dictionary] = []
	var state_changes: Array[int] = [0]
	GameState.decision_recorded.connect(func(entry: Dictionary) -> void: emitted.append(entry))
	GameState.state_changed.connect(func() -> void: state_changes[0] += 1)
	_check("valid released accepted", GameState.record_decision("f1", "b1", 1, "released"))
	_check("valid kept accepted", GameState.record_decision("f2", "b2", 2, "kept"))
	_check("counters updated", GameState.souls_released == 1 and GameState.souls_kept == 1
		and GameState.decisions.size() == 2)
	_check("entry format", GameState.get_decision("f1") == {
		"fragment_id": "f1", "boss_id": "b1", "level": 1, "choice": "released"}, str(GameState.get_decision("f1")))
	_check("has_decision", GameState.has_decision("f1") and not GameState.has_decision("zzz")
		and GameState.get_decision("zzz").is_empty())
	_check("decision_recorded once per accepted", emitted.size() == 2, "count=%d" % emitted.size())
	_check("state_changed emitted on accepted", state_changes[0] == 2, "count=%d" % state_changes[0])

	var before: Dictionary = GameState.to_dict()
	_check("invalid choice rejected", not GameState.record_decision("f3", "b3", 3, "destroyed"))
	_check("empty id rejected", not GameState.record_decision("", "b3", 3, "kept"))
	_check("duplicate rejected", not GameState.record_decision("f1", "b1", 1, "kept"))
	_check("rejections change nothing", _json_equal(before, GameState.to_dict()) and emitted.size() == 2)

	var copy: Dictionary = GameState.to_dict()
	copy["decisions"][0]["choice"] = "kept"
	copy["decisions"].append({"x": 1})
	copy["souls_kept"] = 99
	_check("to_dict is a deep copy", GameState.decisions.size() == 2 and GameState.decisions[0]["choice"] == "released"
		and GameState.souls_kept == 1)
	var parsed: Variant = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	_check("JSON round trip", parsed is Dictionary and _json_equal(parsed, GameState.to_dict()))

	for i in 5:
		GameState.record_decision("g%d" % i, "b", 1, "released" if i % 2 == 0 else "kept")
	var released := 0
	var kept := 0
	for entry: Dictionary in GameState.decisions:
		if entry["choice"] == "released":
			released += 1
		else:
			kept += 1
	_check("counters equal matching decisions", released == GameState.souls_released and kept == GameState.souls_kept,
		"released=%d kept=%d" % [released, kept])

	GameState.set_current_level(3)
	GameState.set_checkpoint("cp")
	_check("level/checkpoint setters", GameState.current_level == 3 and GameState.checkpoint == "cp")
	GameState.reset_run()
	_check("reset_run restores defaults", _json_equal(GameState.to_dict(), fresh))


# --- Drop ---

func _test_drop() -> void:
	GameState.reset_run()
	await _reset_player()

	# Boss killed: exactly one fragment after the delay, at the stored position, outside the boss.
	spawned.clear()
	var rig := _make_rig(DROP_DELAY)
	var boss: BossBase = rig["boss"]
	var drop: SoulFragmentDrop = rig["drop"]
	var drop_events: Array[SoulFragment] = []
	drop.fragment_spawned.connect(func(fragment: SoulFragment) -> void: drop_events.append(fragment))
	await _frames(5)
	var death_position: Vector2 = boss.global_position
	boss.health.kill()
	await _frames(5)
	_check("no fragment before the delay", _live_fragments().is_empty())
	await _wait_until(func() -> bool: return not _live_fragments().is_empty(), 60)
	var fragments: Array[SoulFragment] = _live_fragments()
	_check("exactly one fragment after delay", fragments.size() == 1 and drop_events.size() == 1)
	if fragments.size() == 1:
		var fragment: SoulFragment = fragments[0]
		_check("fragment position", fragment.global_position.distance_to(death_position + drop.spawn_offset) < 1.0,
			str(fragment.global_position))
		_check("fragment outside the boss", fragment.get_parent() == get_tree().current_scene and not boss.is_ancestor_of(fragment))
		_check("fragment data assigned", fragment.data == DATA_1)
		# A second defeated emission never spawns again.
		boss.defeated.emit(boss)
		await _wait_until(_freed(boss), 120)
		_check("fragment survives boss free", not is_instance_valid(boss) and is_instance_valid(fragment))
		await _frames(40)
		_check("never spawned twice", _live_fragments().size() == 1 and drop_events.size() == 1)
	await _free_rig(rig)

	# Boss freed before the delay finishes: position stored at defeat time.
	GameState.reset_run()
	spawned.clear()
	rig = _make_rig(1.6)
	boss = rig["boss"]
	await _frames(5)
	death_position = boss.global_position
	boss.health.kill()
	await _wait_until(_freed(boss), 140)
	_check("boss freed before the delay", not is_instance_valid(boss) and _live_fragments().is_empty())
	await _wait_until(func() -> bool: return not _live_fragments().is_empty(), 120)
	var late: Array[SoulFragment] = _live_fragments()
	_check("fragment spawns after boss was freed",
		late.size() == 1 and late[0].global_position.distance_to(death_position + (rig["drop"] as SoulFragmentDrop).spawn_offset) < 1.0)
	await _free_rig(rig)

	# Encounter reset (player dies before the boss dies): nothing spawns; later kill still drops.
	GameState.reset_run()
	spawned.clear()
	await _reset_player()
	rig = _make_rig(DROP_DELAY, true)
	boss = rig["boss"]
	await _wait_until(func() -> bool: return boss.state != BossBase.State.INACTIVE, 30)
	_check("encounter activated the boss", boss.state != BossBase.State.INACTIVE)
	var resets: Array[int] = [0]
	boss.encounter_reset.connect(func() -> void: resets[0] += 1)
	player.health.kill()
	await _frames(DROP_DELAY_FRAMES * 3)
	# The player respawns inside the trigger, so the boss may be active again afterwards.
	_check("player death reset the encounter", resets[0] >= 1, "resets=%d" % resets[0])
	_check("reset spawns nothing", _live_fragments().is_empty())
	boss.reset_encounter()
	await _frames(DROP_DELAY_FRAMES * 2)
	_check("manual reset spawns nothing", _live_fragments().is_empty())
	await _free_rig(rig)
	await _reset_player()

	# Decision already exists: boss defeat spawns nothing.
	GameState.reset_run()
	GameState.record_decision(DATA_1.fragment_id, DATA_1.boss_id, DATA_1.level, "kept")
	spawned.clear()
	rig = _make_rig(DROP_DELAY)
	boss = rig["boss"]
	await _frames(5)
	boss.health.kill()
	await _frames(DROP_DELAY_FRAMES * 3)
	_check("existing decision -> no fragment", _live_fragments().is_empty())
	await _free_rig(rig)
	GameState.reset_run()


const DROP_DELAY_FRAMES: int = 20


# --- Pickup ---

func _test_pickup() -> void:
	GameState.reset_run()
	await _reset_player()
	spawned.clear()
	var fragment := FRAGMENT_SCENE.instantiate() as SoulFragment
	fragment.data = DATA_1
	var collected_count: Array[int] = [0]
	fragment.collected.connect(func(_f: SoulFragment) -> void: collected_count[0] += 1)
	add_child(fragment)
	fragment.global_position = player.global_position
	await _frames(6)
	_check("collected emitted once", collected_count[0] == 1, "count=%d" % collected_count[0])
	_check("fragment marked consumed", fragment.is_consumed())
	player.global_position = PLAYER_START + Vector2(600.0, 0.0)
	await _frames(6)
	player.global_position = fragment.global_position
	player.velocity = Vector2.ZERO
	await _frames(6)
	_check("re-entering does nothing", collected_count[0] == 1, "count=%d" % collected_count[0])
	_check("monitoring disabled", not fragment.monitoring)
	fragment.free()


# --- Decision flow ---

func _manual_fragment(rig: Dictionary, data: SoulFragmentData) -> SoulFragment:
	var fragment := FRAGMENT_SCENE.instantiate() as SoulFragment
	fragment.data = data
	add_child(fragment)
	fragment.global_position = player.global_position + Vector2(0.0, -4.0)
	(rig["drop"] as SoulFragmentDrop).fragment_spawned.emit(fragment)
	return fragment


func _collect_with_panel(rig: Dictionary, data: SoulFragmentData) -> SoulFragment:
	await _reset_player()
	var fragment := _manual_fragment(rig, data)
	var panel: DecisionPanel = rig["panel"]
	await _wait_until(func() -> bool: return panel.is_open(), 30)
	return fragment


func _test_flow() -> void:
	for case in [["released", DATA_1], ["kept", DATA_2]]:
		var choice: String = case[0]
		var data: SoulFragmentData = case[1]
		GameState.reset_run()
		spawned.clear()
		var rig := _make_rig(DROP_DELAY, false, data)
		var panel: DecisionPanel = rig["panel"]
		var flow: DecisionFlow = rig["flow"]
		var made: Array[String] = []
		flow.decision_made.connect(func(id: String, c: String) -> void: made.append("%s:%s" % [id, c]))
		var fragment := await _collect_with_panel(rig, data)
		_check("[%s] collecting opens panel and pauses" % choice, panel.is_open() and get_tree().paused)
		_check("[%s] panel texts" % choice, panel.name_label.text == data.display_name
			and panel.release_button.text == "Liberar" and panel.keep_button.text == "Conservar")
		var button: Button = panel.release_button if choice == "released" else panel.keep_button
		button.pressed.emit()
		_check("[%s] decision recorded" % choice, GameState.get_decision(data.fragment_id) == {
			"fragment_id": data.fragment_id, "boss_id": data.boss_id, "level": data.level, "choice": choice},
			str(GameState.decisions))
		_check("[%s] counter" % choice, (GameState.souls_released if choice == "released" else GameState.souls_kept) == 1)
		_check("[%s] panel closed and unpaused" % choice, not panel.is_open() and not get_tree().paused)
		_check("[%s] decision_made emitted once" % choice, made == ["%s:%s" % [data.fragment_id, choice]], str(made))
		await _wait_until(_freed(fragment), 120)
		_check("[%s] fragment freed after effect" % choice, not is_instance_valid(fragment))
		await _free_rig(rig)

	# Double input: a second press and the other button record only once.
	GameState.reset_run()
	var rig := _make_rig(DROP_DELAY)
	var panel: DecisionPanel = rig["panel"]
	var fragment := await _collect_with_panel(rig, DATA_1)
	panel.release_button.pressed.emit()
	panel.release_button.pressed.emit()
	panel.keep_button.pressed.emit()
	_check("double input records once", GameState.decisions.size() == 1 and GameState.souls_released == 1
		and GameState.souls_kept == 0, str(GameState.decisions))
	await _wait_until(_freed(fragment), 120)
	await _free_rig(rig)

	# Rejected decision (already recorded): still unpauses and cleans up.
	GameState.reset_run()
	rig = _make_rig(DROP_DELAY)
	panel = rig["panel"]
	GameState.record_decision(DATA_1.fragment_id, DATA_1.boss_id, DATA_1.level, "kept")
	fragment = await _collect_with_panel(rig, DATA_1)
	_check("panel opened for existing decision", panel.is_open() and get_tree().paused)
	panel.release_button.pressed.emit()
	_check("rejected: unpaused and closed", not get_tree().paused and not panel.is_open())
	_check("rejected: state unchanged", GameState.decisions.size() == 1 and GameState.souls_kept == 1
		and GameState.souls_released == 0)
	await _frames(3)
	_check("rejected: fragment cleaned up", not is_instance_valid(fragment))
	await _free_rig(rig)

	# Panel freed while open: the tree is unpaused.
	var lone_panel := PANEL_SCENE.instantiate() as DecisionPanel
	add_child(lone_panel)
	lone_panel.open(DATA_3)
	_check("lone panel pauses", get_tree().paused and lone_panel.is_open())
	lone_panel.free()
	_check("freeing the open panel unpauses", not get_tree().paused)
	await _frames(2)


# --- Integration ---

func _test_integration() -> void:
	GameState.reset_run()
	spawned.clear()
	await _reset_player()
	var rig := _make_rig(DROP_DELAY)
	var boss: BossBase = rig["boss"]
	var panel: DecisionPanel = rig["panel"]
	await _frames(5)
	boss.health.kill()
	await _wait_until(func() -> bool: return not _live_fragments().is_empty(), 60)
	var fragments: Array[SoulFragment] = _live_fragments()
	_check("integration: fragment dropped", fragments.size() == 1)
	if fragments.size() == 1:
		var fragment: SoulFragment = fragments[0]
		_move_player_onto(fragment)
		await _wait_until(func() -> bool: return panel.is_open(), 30)
		_check("integration: panel open and paused", panel.is_open() and get_tree().paused)
		panel.keep_button.pressed.emit()
		_check("integration: kept recorded", GameState.souls_kept == 1 and GameState.has_decision(DATA_1.fragment_id)
			and not get_tree().paused)
		await _wait_until(_freed(fragment), 120)
		_check("integration: fragment gone", not is_instance_valid(fragment))
	await _free_rig(rig)

	# The autoload outlives scenes: instantiate and free the real test scene.
	var snapshot: Dictionary = GameState.to_dict()
	var level_scene := BOSS_TEST_SCENE.instantiate()
	add_child(level_scene)
	await _frames(5)
	level_scene.free()
	await _frames(3)
	_check("GameState persists across scene lifetimes", _json_equal(snapshot, GameState.to_dict())
		and get_node("/root/GameState") == GameState)
	_check("tree not left paused", not get_tree().paused)
	GameState.reset_run()
