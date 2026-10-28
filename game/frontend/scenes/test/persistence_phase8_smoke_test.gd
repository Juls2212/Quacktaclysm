extends Node
## Headless smoke test for Phase 8: SaveSystem, GameState loading/validation, autosave triggers.
## Development only. All file work happens on a redirected user:// test path, never on the real save.
## Run: <godot> --headless --path game res://frontend/scenes/test/persistence_phase8_smoke_test.tscn
## Expect GameState/SaveSystem warnings in the output: the rejection paths are exercised on purpose.

const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const CHECKPOINT_SCENE: PackedScene = preload("res://backend/progression/checkpoint.tscn")
const FRAGMENT_SCENE: PackedScene = preload("res://backend/decisions/soul_fragment.tscn")
const PANEL_SCENE: PackedScene = preload("res://frontend/ui/decision_panel.tscn")
const DATA_1: SoulFragmentData = preload("res://backend/decisions/data/fragment_level_1.tres")
const DATA_2: SoulFragmentData = preload("res://backend/decisions/data/fragment_level_2.tres")
const TEST_PATH: String = "user://test_save_phase8.json"
const FLOOR_Y: float = 300.0
const PLAYER_START: Vector2 = Vector2(-2000.0, FLOOR_Y - 30.0)
const CHECKPOINT_A_POS: Vector2 = Vector2(-1500.0, FLOOR_Y)
const CHECKPOINT_B_POS: Vector2 = Vector2(-1000.0, FLOOR_Y)
const EXPECTED_KEYS: Array[String] = [
	"save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile",
]

var failures: int = 0
var player: Player
var real_file_existed: bool = false
var real_file_time: int = 0


func _ready() -> void:
	SaveSystem.set_save_path(TEST_PATH)
	real_file_existed = FileAccess.file_exists(SaveSystem.DEFAULT_PATH)
	if real_file_existed:
		real_file_time = FileAccess.get_modified_time(SaveSystem.DEFAULT_PATH)
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


func _fresh() -> void:
	SaveSystem.purge()
	GameState.autosave_enabled = true
	GameState.start_new_game()


func _write_raw(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _read_json(path: String) -> Variant:
	return JSON.parse_string(_read_text(path))


func _populate() -> Dictionary:
	GameState.record_decision("fragment_level_1", "placeholder_boss", 1, "released")
	GameState.record_decision("fragment_level_2", "boss_two", 2, "kept")
	GameState.record_decision("fragment_level_3", "boss_three", 3, "kept")
	GameState.set_current_level(2)
	GameState.set_checkpoint("level_1_arena")
	GameState.adaptive_profile = GameState.PROFILE_COMPASSIONATE
	return GameState.to_dict()


func _valid_dict() -> Dictionary:
	return {
		"save_version": 1, "current_level": 2, "checkpoint": "cp", "souls_released": 1, "souls_kept": 0,
		"decisions": [{"fragment_id": "a", "boss_id": "b", "level": 1, "choice": "released"}],
		"adaptive_profile": "corrupt",
	}


func _run() -> void:
	await _test_round_trip()
	await _test_atomic()
	_test_no_save()
	_test_corrupt()
	_test_validation()
	_test_versions()
	await _test_autosave_triggers()
	await _test_restore()
	_test_isolation()
	SaveSystem.purge()
	SaveSystem.set_save_path(SaveSystem.DEFAULT_PATH)
	GameState.autosave_enabled = true
	GameState.start_new_game()
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


# --- Round trip ---

func _test_round_trip() -> void:
	_fresh()
	var snapshot: Dictionary = _populate()
	var saved: Dictionary = SaveSystem.save(snapshot)
	_check("round trip: save ok", saved["ok"], str(saved))
	var text: String = _read_text(TEST_PATH)
	print("saved file:\n", text)
	var parsed: Variant = JSON.parse_string(text)
	var keys: Array = (parsed as Dictionary).keys() if parsed is Dictionary else []
	keys.sort()
	var expected: Array = EXPECTED_KEYS.duplicate()
	expected.sort()
	_check("file is valid JSON with exactly the seven keys", keys == expected, str(keys))
	_check("file is human-readable (indented, multi-line)", text.count("\n") > 8 and text.contains("\t"))
	GameState.reset_run()
	var loaded: Dictionary = GameState.load_from_disk()
	_check("round trip: load ok", loaded["ok"] and loaded["status"] == "ok", str(loaded))
	_check("round trip: state identical", GameState.to_dict() == snapshot, str(GameState.to_dict()))
	_check("round trip: ints stay ints", typeof(GameState.current_level) == TYPE_INT
		and typeof(GameState.decisions[0]["level"]) == TYPE_INT)
	await _frames(1)


# --- Atomic save ---

func _test_atomic() -> void:
	_fresh()
	var first: Dictionary = _populate()
	SaveSystem.save(first)
	GameState.record_decision("extra", "b", 1, "released")
	var second: Dictionary = GameState.to_dict()
	_check("second save ok", SaveSystem.save(second)["ok"])
	_check("main holds the new version", SaveSystem.json_equal(_read_json(TEST_PATH), second))
	_check("backup holds the previous version", SaveSystem.json_equal(_read_json(SaveSystem.backup_path()), first))
	_check("no .tmp left", not FileAccess.file_exists(SaveSystem.temp_path()))

	# Failure: the temp path is occupied by a directory, so the temp file cannot be opened.
	DirAccess.make_dir_absolute(SaveSystem.temp_path())
	var failed: Dictionary = SaveSystem.save(first)
	_check("blocked temp file -> ok=false, no crash", not failed["ok"] and not String(failed["error"]).is_empty(), str(failed))
	_check("failed save leaves the main file intact", SaveSystem.json_equal(_read_json(TEST_PATH), second))
	_check("failed save leaves the backup intact", SaveSystem.json_equal(_read_json(SaveSystem.backup_path()), first))
	DirAccess.remove_absolute(SaveSystem.temp_path())

	# Failure: target folder does not exist.
	SaveSystem.set_save_path("user://missing_folder_phase8/save.json")
	var missing: Dictionary = SaveSystem.save(first)
	_check("missing folder -> ok=false", not missing["ok"], str(missing))
	SaveSystem.set_save_path("C:/not_allowed.json")
	_check("absolute path rejected", SaveSystem.get_save_path() == "user://missing_folder_phase8/save.json")
	SaveSystem.set_save_path(TEST_PATH)
	_check("path restored", SaveSystem.get_save_path() == TEST_PATH)
	_check("derived paths", SaveSystem.backup_path() == TEST_PATH + ".bak" and SaveSystem.temp_path() == TEST_PATH + ".tmp"
		and SaveSystem.corrupt_path() == TEST_PATH + ".corrupt")
	_check("delete_save removes main, backup and temp", SaveSystem.delete_save() and not SaveSystem.has_save())
	await _frames(1)


# --- No save ---

func _test_no_save() -> void:
	_fresh()
	var snapshot: Dictionary = _populate()
	SaveSystem.purge()
	var result: Dictionary = GameState.load_from_disk()
	_check("no save -> no_save", not result["ok"] and result["status"] == "no_save", str(result))
	_check("no save leaves the state unchanged", GameState.to_dict() == snapshot)


# --- Corrupt files ---

func _test_corrupt() -> void:
	var variants: Dictionary = {"garbage": "this is not json {{{", "empty": "", "array root": "[1, 2, 3]", "number root": "42"}
	for label in variants:
		# With a valid backup.
		_fresh()
		var first: Dictionary = _populate()
		SaveSystem.save(first)
		GameState.record_decision("later", "b", 1, "kept")
		SaveSystem.save(GameState.to_dict())
		GameState.reset_run()
		_write_raw(TEST_PATH, variants[label])
		var recovered: Dictionary = GameState.load_from_disk()
		_check("[%s] corrupt main + backup -> recovered" % label, recovered["ok"] and recovered["status"] == "recovered_from_backup", str(recovered))
		_check("[%s] state restored from the backup" % label, GameState.to_dict() == first)
		_check("[%s] corrupt file quarantined" % label, _read_text(SaveSystem.corrupt_path()) == variants[label]
			and FileAccess.file_exists(SaveSystem.corrupt_path()))
		_check("[%s] main restored and valid" % label, SaveSystem.json_equal(_read_json(TEST_PATH), first))

		# Without a backup.
		_fresh()
		var snapshot: Dictionary = _populate()
		_write_raw(TEST_PATH, variants[label])
		var corrupt: Dictionary = GameState.load_from_disk()
		_check("[%s] corrupt main, no backup -> corrupt" % label, not corrupt["ok"] and corrupt["status"] == "corrupt", str(corrupt))
		_check("[%s] state unchanged" % label, GameState.to_dict() == snapshot)
		_check("[%s] quarantined, not deleted" % label, FileAccess.file_exists(SaveSystem.corrupt_path())
			and not FileAccess.file_exists(TEST_PATH))
	SaveSystem.purge()


# --- Semantic validation ---

func _test_validation() -> void:
	_fresh()
	var result: Dictionary = GameState.load_from_dict({
		"save_version": 1.0, "current_level": 2.0, "checkpoint": "cp", "souls_released": 1.0, "souls_kept": 0.0,
		"decisions": [{"fragment_id": "a", "boss_id": "b", "level": 1.0, "choice": "released"}],
		"adaptive_profile": "corrupt"})
	_check("float-valued integers accepted", result["ok"] and result["warnings"].is_empty(), str(result))
	_check("converted to real ints", typeof(GameState.current_level) == TYPE_INT and typeof(GameState.save_version) == TYPE_INT
		and typeof(GameState.decisions[0]["level"]) == TYPE_INT and GameState.current_level == 2
		and GameState.adaptive_profile == "corrupt" and GameState.souls_released == 1)

	var before: Dictionary = GameState.to_dict()
	var bad_inputs: Dictionary = {
		"non-integer version": {"save_version": 1.5},
		"string version": {"save_version": "1"},
		"missing version": {"current_level": 1},
		"bool version": {"save_version": true},
		"decisions not array": {"save_version": 1, "decisions": "nope"},
		"array root": [1, 2],
		"null root": null,
		"string root": "text",
	}
	for label in bad_inputs:
		var rejected: Dictionary = GameState.load_from_dict(bad_inputs[label])
		_check("rejected: %s" % label, not rejected["ok"] and not String(rejected["error"]).is_empty(), str(rejected))
	_check("rejections leave the state unchanged", GameState.to_dict() == before)

	var minimal: Dictionary = GameState.load_from_dict({"save_version": 1})
	_check("missing keys -> defaults with warnings", minimal["ok"] and minimal["warnings"].size() >= 4
		and GameState.current_level == 1 and GameState.checkpoint == "start" and GameState.decisions.is_empty()
		and GameState.adaptive_profile == "neutral", str(minimal["warnings"]))

	var data: Dictionary = _valid_dict()
	data["current_level"] = 9
	_check("level above max clamped", GameState.load_from_dict(data)["ok"] and GameState.current_level == GameState.MAX_LEVEL)
	data["current_level"] = -4
	GameState.load_from_dict(data)
	_check("level below min clamped", GameState.current_level == GameState.MIN_LEVEL)
	data["current_level"] = 2.5
	var fractional: Dictionary = GameState.load_from_dict(data)
	_check("fractional level -> default + warning", fractional["ok"] and GameState.current_level == 1 and fractional["warnings"].size() > 0)
	data["current_level"] = "two"
	GameState.load_from_dict(data)
	_check("string level -> default", GameState.current_level == 1)

	data = _valid_dict()
	data["adaptive_profile"] = "evil"
	GameState.load_from_dict(data)
	_check("unknown profile -> neutral", GameState.adaptive_profile == "neutral")
	data["adaptive_profile"] = 7
	GameState.load_from_dict(data)
	_check("non-string profile -> neutral", GameState.adaptive_profile == "neutral")
	_check("profile helper", GameState.is_valid_profile("compassionate") and GameState.is_valid_profile("neutral")
		and GameState.is_valid_profile("corrupt") and not GameState.is_valid_profile("Neutral"))
	data = _valid_dict()
	data["checkpoint"] = ""
	GameState.load_from_dict(data)
	_check("empty checkpoint -> start", GameState.checkpoint == "start")
	data["checkpoint"] = 5
	GameState.load_from_dict(data)
	_check("non-string checkpoint -> start", GameState.checkpoint == "start")

	data = _valid_dict()
	data["souls_released"] = 99
	data["souls_kept"] = -3
	data["decisions"] = [
		{"fragment_id": "a", "boss_id": "b", "level": 1, "choice": "released"},
		{"fragment_id": "a", "boss_id": "other", "level": 2, "choice": "kept"},
		{"fragment_id": "", "boss_id": "b", "level": 1, "choice": "kept"},
		{"fragment_id": 5, "boss_id": "b", "level": 1, "choice": "kept"},
		{"fragment_id": "c", "boss_id": "b", "level": 1, "choice": "destroyed"},
		{"fragment_id": "d", "boss_id": 3, "level": 1, "choice": "kept"},
		{"fragment_id": "e", "boss_id": "b", "level": "one", "choice": "kept"},
		{"fragment_id": "f", "boss_id": "b", "level": 1.5, "choice": "kept"},
		"not a dictionary",
		{"fragment_id": "g", "boss_id": "b", "level": 3.0, "choice": "kept"},
	]
	var sanitized: Dictionary = GameState.load_from_dict(data)
	var ids: Array = []
	for entry: Dictionary in GameState.decisions:
		ids.append(entry["fragment_id"])
	_check("invalid entries dropped, duplicates deduplicated (first kept)", ids == ["a", "g"] and GameState.decisions[0]["choice"] == "released", str(ids))
	_check("counters recomputed from decisions", GameState.souls_released == 1 and GameState.souls_kept == 1
		and sanitized["warnings"].size() >= 8, "warnings=%d" % sanitized["warnings"].size())
	var recount: Dictionary = GameState.load_from_dict(_valid_dict())
	_check("matching counters produce no warning", recount["warnings"].is_empty(), str(recount["warnings"]))

	var original: Dictionary = _valid_dict()
	var keep: Dictionary = original.duplicate(true)
	GameState.load_from_dict(original)
	_check("input dictionary not mutated", original == keep)


# --- Versions ---

func _test_versions() -> void:
	_fresh()
	var snapshot: Dictionary = _populate()
	var newer: Dictionary = _valid_dict()
	newer["save_version"] = GameState.SAVE_VERSION + 1
	var rejected: Dictionary = GameState.load_from_dict(newer)
	_check("newer version rejected by load_from_dict", not rejected["ok"] and String(rejected["error"]).contains("newer"), str(rejected))

	# A newer file on disk is never modified, overwritten or quarantined by loading/autosave.
	_write_raw(TEST_PATH, JSON.stringify(newer, "\t"))
	var bytes_before: PackedByteArray = FileAccess.get_file_as_bytes(TEST_PATH)
	var loaded: Dictionary = GameState.load_from_disk()
	_check("newer file -> unsupported_version", not loaded["ok"] and loaded["status"] == "unsupported_version", str(loaded))
	_check("state unchanged", GameState.to_dict() == snapshot)
	_check("saves are blocked", not GameState.save_blocked_reason.is_empty())
	_check("autosave refuses to overwrite", not GameState.autosave())
	_check("manual save refuses by default", not GameState.save_to_disk())
	_check("file byte-identical", FileAccess.get_file_as_bytes(TEST_PATH) == bytes_before)
	_check("no backup or quarantine created", not FileAccess.file_exists(SaveSystem.backup_path())
		and not FileAccess.file_exists(SaveSystem.corrupt_path()) and not FileAccess.file_exists(SaveSystem.temp_path()))
	_check("explicit overwrite works", GameState.save_to_disk(true) and SaveSystem.json_equal(_read_json(TEST_PATH), snapshot))
	_check("block lifted after overwrite", GameState.save_blocked_reason.is_empty())

	_write_raw(TEST_PATH, JSON.stringify(newer, "\t"))
	GameState.load_from_disk()
	GameState.start_new_game()
	_check("start_new_game lifts the block and resets", GameState.save_blocked_reason.is_empty() and GameState.decisions.is_empty())

	GameState.autosave_enabled = true
	var older: Dictionary = _valid_dict()
	older["save_version"] = 0
	GameState.last_migrated_from = -1
	var migrated: Dictionary = GameState.load_from_dict(older)
	_check("older version goes through _migrate", migrated["ok"] and GameState.last_migrated_from == 0
		and GameState.save_version == GameState.SAVE_VERSION, str(migrated))
	var current: Dictionary = GameState.load_from_dict(_valid_dict())
	_check("current version skips migration", current["ok"] and GameState.last_migrated_from == -1)
	SaveSystem.purge()


# --- Autosave triggers ---

func _fragment_flow() -> Dictionary:
	var drop := SoulFragmentDrop.new()
	add_child(drop)
	var panel := PANEL_SCENE.instantiate() as DecisionPanel
	add_child(panel)
	var flow := DecisionFlow.new()
	flow.drop = drop
	flow.panel = panel
	add_child(flow)
	return {"drop": drop, "panel": panel, "flow": flow}


func _free_flow(rig: Dictionary) -> void:
	for key in rig:
		(rig[key] as Node).free()
	get_tree().paused = false
	await _frames(2)


func _decide(rig: Dictionary, data: SoulFragmentData, choice: String) -> void:
	player.revive()
	player.global_position = PLAYER_START
	player.velocity = Vector2.ZERO
	await _frames(30)
	var fragment := FRAGMENT_SCENE.instantiate() as SoulFragment
	fragment.data = data
	add_child(fragment)
	fragment.global_position = player.global_position + Vector2(0.0, -4.0)
	(rig["drop"] as SoulFragmentDrop).fragment_spawned.emit(fragment)
	var panel: DecisionPanel = rig["panel"]
	await _wait_until(func() -> bool: return panel.is_open(), 30)
	(panel.release_button if choice == "released" else panel.keep_button).pressed.emit()
	await _frames(2)
	if is_instance_valid(fragment):
		fragment.free()


func _test_autosave_triggers() -> void:
	_fresh()
	var rig := _fragment_flow()
	await _decide(rig, DATA_1, "released")
	_check("accepted decision writes the file", FileAccess.file_exists(TEST_PATH))
	var saved: Variant = _read_json(TEST_PATH)
	_check("saved file contains the decision", saved is Dictionary and saved["souls_released"] == 1
		and saved["decisions"].size() == 1 and saved["decisions"][0]["fragment_id"] == "fragment_level_1", str(saved))

	# Rejected decision (already recorded): no save.
	SaveSystem.delete_save()
	await _decide(rig, DATA_1, "kept")
	_check("rejected decision does not save", not FileAccess.file_exists(TEST_PATH) and GameState.souls_kept == 0)

	# Autosave disabled: automatic triggers skip, manual save still works.
	GameState.autosave_enabled = false
	await _decide(rig, DATA_2, "kept")
	_check("autosave disabled: decision recorded but not saved", GameState.souls_kept == 1 and not FileAccess.file_exists(TEST_PATH))
	_check("autosave() returns false when disabled", not GameState.autosave())
	_check("manual save_to_disk still works", GameState.save_to_disk() and FileAccess.file_exists(TEST_PATH))
	await _free_flow(rig)

	# Checkpoints.
	_fresh()
	var checkpoint_a := _add_checkpoint(&"cp_a", CHECKPOINT_A_POS, 1)
	var checkpoint_b := _add_checkpoint(&"cp_b", CHECKPOINT_B_POS, 2)
	_check("checkpoints join the group", checkpoint_a.is_in_group("checkpoints") and checkpoint_b.is_in_group("checkpoints")
		and checkpoint_b.order == 2)
	_check("find_checkpoint", Checkpoint.find_checkpoint(get_tree(), "cp_b") == checkpoint_b
		and Checkpoint.find_checkpoint(get_tree(), "cp_a") == checkpoint_a
		and Checkpoint.find_checkpoint(get_tree(), "missing") == null)
	await _touch(checkpoint_a)
	_check("first activation sets respawn", player.get_respawn_point() == checkpoint_a.get_respawn_position())
	_check("first activation writes the file with the id", _saved_checkpoint() == "cp_a" and GameState.checkpoint == "cp_a",
		_saved_checkpoint())
	await _touch(checkpoint_b)
	_check("second checkpoint saves its id", _saved_checkpoint() == "cp_b")
	_check("respawn moved to the newest checkpoint", player.get_respawn_point() == checkpoint_b.get_respawn_position())
	SaveSystem.delete_save()
	await _touch(checkpoint_a)
	_check("re-touching an activated checkpoint does not save", not FileAccess.file_exists(TEST_PATH))
	_check("re-touching does not move the respawn point back", player.get_respawn_point() == checkpoint_b.get_respawn_position())
	_check("GameState checkpoint not regressed", GameState.checkpoint == "cp_b")
	# Leave a save with cp_b for the restore test.
	GameState.save_to_disk()
	checkpoint_a.free()
	checkpoint_b.free()
	await _frames(2)


func _add_checkpoint(id: StringName, pos: Vector2, order_hint: int) -> Checkpoint:
	var checkpoint := CHECKPOINT_SCENE.instantiate() as Checkpoint
	checkpoint.checkpoint_id = id
	checkpoint.order = order_hint
	checkpoint.position = pos
	add_child(checkpoint)
	return checkpoint


func _touch(checkpoint: Checkpoint) -> void:
	player.revive()
	player.global_position = PLAYER_START
	player.velocity = Vector2.ZERO
	await _frames(5)
	player.global_position = checkpoint.global_position + Vector2(0.0, -30.0)
	player.velocity = Vector2.ZERO
	await _frames(6)


func _saved_checkpoint() -> String:
	var data: Variant = _read_json(TEST_PATH)
	return String(data["checkpoint"]) if data is Dictionary else ""


# --- Restore ---

func _test_restore() -> void:
	var checkpoint_b := _add_checkpoint(&"cp_b", CHECKPOINT_B_POS, 2)
	GameState.start_new_game()
	var loaded: Dictionary = GameState.load_from_disk()
	_check("restore: load ok", loaded["ok"] and GameState.checkpoint == "cp_b", str(loaded))
	var found: Checkpoint = Checkpoint.find_checkpoint(get_tree(), GameState.checkpoint)
	_check("restore: saved checkpoint found", found == checkpoint_b)
	if found != null:
		_restore_player_at(found)
		await _frames(2)
		_check("restore: player placed and respawn point set",
			player.global_position.distance_to(found.get_respawn_position()) < 40.0
			and player.get_respawn_point() == found.get_respawn_position(), str(player.global_position))
	checkpoint_b.free()
	await _frames(2)


func _restore_player_at(checkpoint: Checkpoint) -> void:
	player.revive()
	player.set_respawn_point(checkpoint.get_respawn_position())
	player.global_position = checkpoint.get_respawn_position()
	player.velocity = Vector2.ZERO


# --- Isolation ---

func _test_isolation() -> void:
	_check("test used only the redirected path", SaveSystem.get_save_path() == TEST_PATH)
	var untouched: bool = FileAccess.file_exists(SaveSystem.DEFAULT_PATH) == real_file_existed
	if real_file_existed:
		untouched = untouched and FileAccess.get_modified_time(SaveSystem.DEFAULT_PATH) == real_file_time
	_check("real save file untouched", untouched, "existed_before=%s" % real_file_existed)
