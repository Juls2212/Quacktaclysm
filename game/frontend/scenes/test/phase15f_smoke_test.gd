extends Node
## Smoke test for Phase 15f: boss 3's guard as a visible armor layer broken in ONE hit, the guardians' stories advanced only with the
## confirm action, and the developer tools group. Development only.
## Run (alone, a few minutes): <godot> --headless --path game res://frontend/scenes/test/phase15f_smoke_test.tscn
## Uses a redirected save path and a throwaway settings file. Times are real game time.

const TEST_SAVE: String = "user://test_save_phase15f.json"
const TEST_SETTINGS: String = "user://test_settings_phase15f.cfg"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const BOSS_THREE: PackedScene = preload("res://backend/bosses/boss_three.tscn")
const LEVELS: Dictionary = {
	1: "res://frontend/levels/level_1.tscn",
	2: "res://frontend/levels/level_2.tscn",
	3: "res://frontend/levels/level_3.tscn",
}
const BIOME_DIR: String = "res://frontend/levels/biome/"
const FLOOR_Y: float = 300.0
const MIN_CONTRAST: float = 2.5
const OLD_HINT: String = "Rompe la guardia con golpe pesado o tajo de dash"
const NEW_HINT: String = "Rompe la capa con golpe pesado o tajo de dash"

var failures: int = 0
var real_save_before: String = ""
var real_settings_before: String = ""
var real_controls_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig
var player_stats: PlayerStats = PlayerStats.new()
var texts: StoryTexts = StoryTexts.get_default()


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
	InputMap.load_from_project_settings()
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.director.clear_overrides()
	GameState.autosave_enabled = false
	AbilityCard.forget_all()
	BossDialogue.forget_all()
	DeveloperShortcut.simulate_release_build = false
	GameSettings.save_settings(GameSettings.DEFAULTS.duplicate())


func _run() -> void:
	_clean_state()
	_test_guards()
	await _test_no_shell()
	_test_guardian_story_texts()
	await _test_intro_only_with_enter()
	await _test_remapped_confirm_pause_and_skip()
	await _test_retry_and_arena_checkpoint()
	await _test_developer_tools_basic()
	await _test_developer_in_situations()
	await _test_developer_other_bosses()
	await _test_developer_hidden_and_gated()
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


func _threshold_hp(boss: BossBase, index: int) -> float:
	return float(boss.health.max_health) * boss.stats.get_phase_thresholds()[index]


## Boss 3 in phase 2 (Kenzo with the guard up) in a flat arena, with no level around it.
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
	# Phase 1 is the shell's phase (Phase 15j): nothing to cross.
	await _physics(5)
	return {"world": world, "boss": boss, "player": player, "guard": boss.get_node("Shield"), "fx": boss.get_node("ShieldFx")}


func _hit(boss: BossBase, kind: StringName, amount: int = 1) -> bool:
	return boss.hurtbox.receive_hit(DamageInfo.create(amount, Vector2.ZERO, null, CombatLayers.Team.PLAYER, kind))


func _level_three(play_possession: bool = true) -> LevelBase:
	var level := (load(LEVELS[3]) as PackedScene).instantiate() as LevelBase
	(level.get_node("PossessionDirector") as PossessionDirector).play_when_headless = play_possession
	return level


func _fight(vulnerable: bool = false) -> LevelBase:
	var level: LevelBase = _level_three()
	add_child(level)
	await _frames(8)
	level.player.story_invulnerable = not vulnerable
	level.player.global_position = level.encounter.global_position
	await _physics(12)
	return level


func _hurt_to(level: LevelBase, remaining: int) -> void:
	var amount: int = level.boss.health.current_health - remaining
	if amount > 0:
		level.boss.health.apply_damage(DamageInfo.create(amount, Vector2.ZERO, level.player, CombatLayers.Team.PLAYER))


func _skip_possession(director: PossessionDirector) -> void:
	var guard: int = 0
	while director.active and guard < 60 * 8:
		director.elapsed = maxf(director.elapsed, director.duration - 0.02)
		await get_tree().process_frame
		guard += 1
	await _physics(100)


func _accept_event() -> InputEventAction:
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	return accept


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
# Part A: the guard
# ---------------------------------------------------------------------------------------------

func _channel(value: float) -> float:
	return value / 12.92 if value <= 0.03928 else pow((value + 0.055) / 1.055, 2.4)


func _luminance(color: Color) -> float:
	return 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b)


func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


# ---------------------------------------------------------------------------------------------
# Part B: the guardians' stories
# ---------------------------------------------------------------------------------------------

func _test_no_shell() -> void:
	# Phase 15o: boss 3 has no armor shell any more (no block, no stagger, no regeneration, no shell visual or style).
	var parts: Dictionary = await _kenzo_arena()
	var boss: BossBase = parts["boss"]
	var guard := boss.get_node("Shield") as BossShield
	var before: int = boss.health.current_health
	var all_land: bool = _hit(boss, &"light") and _hit(boss, &"wave") and _hit(boss, &"heavy", 3)
	_check("shell: with no shell every attack hurts at full damage in phase 1 (%d to %d)" % [before, boss.health.current_health], all_land and boss.health.current_health == before - 5 and not guard.shield_up)
	_check("shell: the shell style, its resource and the stagger texts are gone", not ResourceLoader.exists("res://frontend/fx/default_guard_shell.tres") and not ResourceLoader.exists("res://frontend/fx/guard_shell_style.gd") and not "guard_hint" in StoryTexts.get_default())
	_check("shell: BossShield keeps only the summoner stage's shield (no states, no stagger time)", not "state" in guard and not "stagger_time" in guard and not "regen_delay" in guard)
	(parts["world"] as Node).free()
	await _frames(2)


func _test_guardian_story_texts() -> void:
	var cap_ok: bool = true
	var count_ok: bool = true
	var no_spoilers: bool = true
	var longest: int = 0
	var summary: PackedStringArray = PackedStringArray()
	for level in [1, 2, 3]:
		var story: BossStory = texts.get_boss(level)
		count_ok = count_ok and story.pre_lines.size() == 1 and story.defeat_lines.size() >= 2 and story.defeat_lines.size() <= 3
		summary.append("%d lines" % story.pre_lines.size())
		for line in story.lines_for("neutral") + story.lines_for("corrupt") + story.lines_for("compassionate"):
			longest = maxi(longest, line.length())
			cap_ok = cap_ok and line.length() <= 80
		var joined: String = " ".join(story.pre_lines).to_lower()
		# No endings, no statistics; the grandfather is not named by the first two guardians (he is only remembered in levels 1 and 2).
		for forbidden in ["final", "epílogo", "liberarás", "conservarás", "porcentaje"]:
			no_spoilers = no_spoilers and not joined.contains(forbidden)
		for i in joined.length():
			no_spoilers = no_spoilers and not (joined[i] >= "0" and joined[i] <= "9")
		if level < 3:
			no_spoilers = no_spoilers and not joined.contains("abuelo") and not joined.contains("kenzo")
	_check("stories: each guardian has ONE first-sight line and 2 to 3 last words (%s) (Phase 15n)" % ", ".join(summary), count_ok)
	_check("stories: every first-sight line is at most 80 characters (longest %d)" % longest, cap_ok)
	_check("stories: no ending spoiler, no numbers, and the grandfather is not named before level 3", no_spoilers)
	var voices_differ: bool = texts.get_boss(1).pre_lines[0] != texts.get_boss(2).pre_lines[0] and texts.get_boss(2).pre_lines[0] != texts.get_boss(3).pre_lines[0]
	_check("stories: each guardian has its own voice", voices_differ)

func _boss_level(level_number: int) -> LevelBase:
	var level := (load(LEVELS[level_number]) as PackedScene).instantiate() as LevelBase
	(level.get_node("BossIntro") as BossIntro).play_when_headless = true
	add_child(level)
	return level


func _enter_arena(level: LevelBase) -> void:
	level.player.global_position = level.encounter.global_position
	level.player.velocity = Vector2.ZERO


func _test_intro_only_with_enter() -> void:
	for level_number in [1, 2, 3]:
		_clean_state()
		var level: LevelBase = _boss_level(level_number)
		await _frames(8)
		var intro := level.get_node("BossIntro") as BossIntro
		var dialogue := level.get_node("BossDialogue") as BossDialogue
		var story: BossStory = texts.get_boss(level_number)
		var expected_lines: int = story.lines_for(GameState.adaptive_profile).size() + story.duck_lines.size()
		_enter_arena(level)
		await _physics(10)
		_check("intro %d: the intro starts, the boss waits and the player is locked and invulnerable" % level_number, intro.active and level.boss.state == BossBase.State.INACTIVE and level.player.is_input_locked() and level.player.story_invulnerable)
		_check("intro %d: the guardian speaks first" % level_number, dialogue.is_speaking() and dialogue.lines_shown == 1)
		# The typewriter: the first press completes the line, it does not advance.
		dialogue._grace_left = 0.0
		var label: Label = dialogue._label
		var typing: bool = label.visible_characters < label.text.length() and label.visible_characters >= 0
		var first_text: String = dialogue.current_text()
		dialogue._input(_accept_event())
		_check("intro %d: the first press completes the typed line and stays on it" % level_number, typing and dialogue.current_text() == first_text and dialogue.lines_shown == 1 and label.visible_characters == -1 and dialogue._prompt_label.visible)
		_check("intro %d: the prompt «%s» shows when the line is complete" % [level_number, dialogue._prompt_label.text], dialogue._prompt_label.text == "Enter ▸" or dialogue._prompt_label.text.ends_with("▸"))
		# NO timer advances anything: a long game time later it is still on the same line.
		Engine.time_scale = 8.0
		var waited: float = 0.0
		var frames: int = 0
		while waited < 90.0 and frames < 4000:
			await get_tree().physics_frame
			waited += get_physics_process_delta_time()
			frames += 1
		Engine.time_scale = 1.0
		_check("intro %d: after %.0f s of game time nothing advanced by itself (still line 1, intro on, boss asleep)" % [level_number, waited], intro.active and dialogue.lines_shown == 1 and dialogue.current_text() == first_text and level.boss.state == BossBase.State.INACTIVE and waited >= 60.0)
		# Enter advances line by line (two presses per line: complete, then next).
		var seen: Array[String] = [first_text]
		var presses: int = 0
		while intro.active and presses < 80:
			dialogue._input(_accept_event())
			presses += 1
			if dialogue.is_speaking() and dialogue.current_text() != seen[seen.size() - 1]:
				seen.append(dialogue.current_text())
		await _physics(6)
		_check("intro %d: every one of the %d lines was shown, each moved on only by presses (%d lines seen)" % [level_number, expected_lines, seen.size()], seen.size() == expected_lines and not intro.active)
		_check("intro %d: the fight starts only after the last line, and the player is free and vulnerable afterwards" % level_number, level.boss.state != BossBase.State.INACTIVE and not level.player.is_input_locked() and not level.player.story_invulnerable and intro.order.back() == "fight")
		_check("intro %d: the duck's monologue is advanced the same way (lines of the duck were among the seen lines)" % level_number, seen.any(func(text: String) -> bool: return text.begins_with("Pato:")))
		level.free()
		await _frames(2)


func _test_remapped_confirm_pause_and_skip() -> void:
	_clean_state()
	var level: LevelBase = _boss_level(1)
	await _frames(8)
	var intro := level.get_node("BossIntro") as BossIntro
	var dialogue := level.get_node("BossDialogue") as BossDialogue
	_enter_arena(level)
	await _physics(10)
	dialogue._grace_left = 0.0
	# Remap the confirm action to another key: only that key advances.
	InputMap.action_erase_events(&"ui_accept")
	var other := InputEventKey.new()
	other.physical_keycode = KEY_J
	other.keycode = KEY_J
	InputMap.action_add_event(&"ui_accept", other)
	_check("remap: the prompt names the key the player has bound (%s)" % BossDialogue.confirm_key_name(), BossDialogue.confirm_key_name() == "J")
	var old_key := InputEventKey.new()
	old_key.physical_keycode = KEY_ENTER
	old_key.keycode = KEY_ENTER
	old_key.pressed = true
	dialogue._input(old_key)
	var before: int = dialogue.lines_shown
	var completed: bool = dialogue._typed_done
	dialogue._label.visible_characters = 0
	dialogue._typed_done = false
	dialogue._input(old_key)
	_check("remap: the old key does nothing once the action is remapped", dialogue.lines_shown == before and not dialogue._typed_done and not completed or dialogue.lines_shown == before)
	var new_key := InputEventKey.new()
	new_key.physical_keycode = KEY_J
	new_key.keycode = KEY_J
	new_key.pressed = true
	dialogue._input(new_key)
	_check("remap: the remapped key completes the line", dialogue._typed_done and dialogue._label.visible_characters == -1)
	dialogue._input(new_key)
	_check("remap: and moves on to the next line", dialogue.lines_shown == before + 1)
	InputMap.load_from_project_settings()
	# Pause works: while the tree is paused the line does not type or advance.
	var paused_text: String = dialogue.current_text()
	var typed_before: int = dialogue._label.visible_characters
	get_tree().paused = true
	await get_tree().create_timer(0.6).timeout
	var still: bool = dialogue.current_text() == paused_text and dialogue._label.visible_characters == typed_before and intro.active
	get_tree().paused = false
	_check("pause: the pause stops the intro (nothing typed or advanced while paused) and it goes on afterwards", still and intro.active)
	# Holding the confirm action skips the whole intro; a press only advances.
	dialogue._grace_left = 0.0
	Input.action_press(&"ui_accept")
	var held: float = 0.0
	while intro.active and held < texts.intro_skip_hold_seconds + 2.0:
		await get_tree().process_frame
		held += get_process_delta_time()
	Input.action_release(&"ui_accept")
	await _physics(6)
	_check("skip: holding the confirm action for about %.1f s skips the whole intro (%.2f s held) and the fight begins" % [texts.intro_skip_hold_seconds, held], not intro.active and intro.skipped and held >= texts.intro_skip_hold_seconds - 0.1 and held < texts.intro_skip_hold_seconds + 1.0
		and not level.player.is_input_locked() and level.boss.state != BossBase.State.INACTIVE)
	level.free()
	await _frames(2)


func _test_retry_and_arena_checkpoint() -> void:
	_clean_state()
	var level: LevelBase = _boss_level(1)
	await _frames(8)
	var intro := level.get_node("BossIntro") as BossIntro
	var dialogue := level.get_node("BossDialogue") as BossDialogue
	_enter_arena(level)
	await _physics(10)
	dialogue.skip()
	await _physics(8)
	var sequences: int = dialogue.sequence_count
	level.player.health.kill()
	await _physics(4)
	level.player.respawn()
	await _physics(20)
	_enter_arena(level)
	await _physics(8)
	_check("retry: after dying the intro is not repeated and the boss wakes at once", not intro.active and level.boss.state != BossBase.State.INACTIVE and dialogue.sequence_count == sequences)
	level.free()
	await _frames(2)
	# A level continued from its arena checkpoint never plays the intro.
	_clean_state()
	var probe := (load(LEVELS[2]) as PackedScene).instantiate() as LevelBase
	add_child(probe)
	await _frames(3)
	var arena_id: String = ""
	var arena_order: int = -1
	for checkpoint in probe.get_level_checkpoints():
		if checkpoint.order > arena_order:
			arena_order = checkpoint.order
			arena_id = String(checkpoint.checkpoint_id)
	probe.free()
	await _frames(2)
	_clean_state()
	GameState.current_level = 2
	GameState.checkpoint = arena_id
	var arena_level: LevelBase = _boss_level(2)
	await _frames(8)
	_check("arena checkpoint: continuing from the arena skips the intro (the boss was already met)", BossDialogue.was_spoken(arena_level.scene_file_path) and not (arena_level.get_node("BossIntro") as BossIntro).should_play())
	arena_level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# Part C: the developer tools group (neutral names)
# ---------------------------------------------------------------------------------------------

func _key(code: int, pressed: bool, alt: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	event.alt_pressed = alt
	return event


## Presses the key sequence the way a keyboard would: the modifier, the held key, then the trigger.
func _press_all(tool: DeveloperShortcut) -> void:
	tool._input(_key(DeveloperShortcut.MODIFIER, true, true))
	tool._input(_key(DeveloperShortcut.HOLD_KEY, true, true))
	tool._input(_key(DeveloperShortcut.TRIGGER_KEY, true, true))
	tool._input(_key(DeveloperShortcut.TRIGGER_KEY, false, true))
	tool._input(_key(DeveloperShortcut.HOLD_KEY, false, true))
	tool._input(_key(DeveloperShortcut.MODIFIER, false, false))


func _tool_of(level: LevelBase) -> DeveloperShortcut:
	return level.get_node_or_null(^"DeveloperShortcut") as DeveloperShortcut


func _test_developer_tools_basic() -> void:
	_clean_state()
	var level: LevelBase = await _fight()
	var tool: DeveloperShortcut = _tool_of(level)
	_check("tools: the node exists in a debug build", tool != null and OS.is_debug_build())
	var boss: BossBase = level.boss
	# Single keys and partial sequences do nothing.
	var partials: Array = [
		[[DeveloperShortcut.TRIGGER_KEY]],
		[[DeveloperShortcut.MODIFIER, DeveloperShortcut.HOLD_KEY]],
		[[DeveloperShortcut.MODIFIER, DeveloperShortcut.TRIGGER_KEY]],
		[[DeveloperShortcut.HOLD_KEY, DeveloperShortcut.TRIGGER_KEY]],
		[[DeveloperShortcut.HOLD_KEY]],
		[[DeveloperShortcut.MODIFIER]],
	]
	for case in partials:
		for code: int in case[0]:
			tool._input(_key(code, true, code == int(DeveloperShortcut.MODIFIER) or case[0].has(int(DeveloperShortcut.MODIFIER))))
		for code: int in case[0]:
			tool._input(_key(code, false))
	_check("tools: a single key or a partial sequence does nothing (runs %d, boss %s)" % [tool.runs, BossBase.State.keys()[boss.state]], tool.runs == 0 and boss.state != BossBase.State.DEAD)
	# Trigger first, then the others: nothing. A released key stops counting.
	tool._input(_key(DeveloperShortcut.TRIGGER_KEY, true))
	tool._input(_key(DeveloperShortcut.TRIGGER_KEY, false))
	tool._input(_key(DeveloperShortcut.MODIFIER, true, true))
	tool._input(_key(DeveloperShortcut.HOLD_KEY, true, true))
	tool._input(_key(DeveloperShortcut.HOLD_KEY, false, true))
	tool._input(_key(DeveloperShortcut.TRIGGER_KEY, true, true))
	tool._input(_key(DeveloperShortcut.TRIGGER_KEY, false, true))
	tool._input(_key(DeveloperShortcut.MODIFIER, false))
	_check("tools: a wrong order or a released key does nothing", tool.runs == 0 and boss.state != BossBase.State.DEAD)
	var defeated: Array[bool] = [false]
	boss.defeated.connect(func(_b: BossBase) -> void: defeated[0] = true)
	var save_before: String = _read_file(TEST_SAVE)
	_press_all(tool)
	await _physics(10)
	var next_ok: bool = tool.runs == 1 and boss.state == BossBase.State.PHASE_TRANSITION and not defeated[0] and boss.health.current_health > 0 \
			and boss.health.current_health <= int(floor(_threshold_hp(boss, 0)))
	_check("tools: the first full sequence sends the boss to its NEXT corruption state, it does not kill it (state %s, health %d)" % [BossBase.State.keys()[boss.state], boss.health.current_health], next_ok)
	_press_all(tool)
	await _physics(3)
	_check("tools: during a transition the sequence does nothing (health %d, state %s)" % [boss.health.current_health, BossBase.State.keys()[boss.state]], boss.state == BossBase.State.PHASE_TRANSITION and not defeated[0] and boss.health.current_health > 0)
	var director := level.get_node("PossessionDirector") as PossessionDirector
	await _skip_possession(director)
	var walked: Array[int] = [boss.current_phase]
	_press_all(tool)
	await _physics(3)
	await _skip_possession(director)
	walked.append(boss.current_phase)
	_press_all(tool)
	await _physics(10)
	walked.append(3 if boss.state == BossBase.State.DEAD else boss.current_phase)
	_check("tools: pressing it again walks the phases of boss 3: 1 -> 2 -> 3 -> defeat through the normal flow (%s, defeated signal %s)" % [str(walked), str(defeated[0])], walked == [2, 3, 3] and boss.state == BossBase.State.DEAD and defeated[0] and tool.runs == 4)

	_check("tools: the save file is unchanged by it", _read_file(TEST_SAVE) == save_before)
	level.free()
	await _frames(2)
	# With no encounter it kills every regular enemy.
	_clean_state()
	var level_two := (load(LEVELS[2]) as PackedScene).instantiate() as LevelBase
	add_child(level_two)
	await _frames(3)
	var enemies: Array[Node] = level_two.find_children("*", "EnemyBase", true, false)
	var tool_two: DeveloperShortcut = _tool_of(level_two)
	_press_all(tool_two)
	await _physics(4)
	var all_dead: bool = not enemies.is_empty()
	for enemy in enemies:
		all_dead = all_dead and (enemy as EnemyBase).state == EnemyBase.State.DEAD
	_check("tools: with no boss encounter it kills every regular enemy alive (%d) and leaves the boss alone" % enemies.size(), all_dead and level_two.boss.state != BossBase.State.DEAD)
	_check("tools: the AI Director telemetry does not record those kills (kills %.0f, suppressed %d)" % [GameState.director.telemetry.get_value(2, "kills"), GameState.director.telemetry.suppressed],
		GameState.director.telemetry.get_value(2, "kills") == 0.0 and GameState.director.telemetry.suppressed == 0)
	level_two.free()
	await _frames(2)


## Phase 15q: a defeated boss is freed by its own flow; never touch it (or capture it in a lambda) without asking first.
func _boss_gone(boss: Variant) -> bool:
	return boss == null or not is_instance_valid(boss) or boss.state == BossBase.State.DEAD


func _test_developer_other_bosses() -> void:
	for level_number in [1, 2]:
		_clean_state()
		var level: LevelBase = _boss_level(level_number)
		await _frames(8)
		_enter_arena(level)
		await _physics(10)
		var tool: DeveloperShortcut = _tool_of(level)
		var director := level.get_node("PossessionDirector") as PossessionDirector
		var seen: Array[int] = []
		var presses: int = 0
		var boss: BossBase = level.boss
		while not _boss_gone(boss) and presses < 6:
			_press_all(tool)
			presses += 1
			await _physics(6)
			await _skip_possession(director)
			seen.append(99 if _boss_gone(boss) else boss.current_phase)
		_check("tools: boss %d is walked through its phases by the sequence (phases after each press %s) and then defeated through the normal flow" % [level_number, str(seen)], _boss_gone(boss) and seen.has(2) and seen.find(2) < seen.find(99) and presses <= 5)
		level.free()
		await _frames(2)


func _test_developer_in_situations() -> void:
	# During the boss intro.
	_clean_state()
	var intro_level: LevelBase = _boss_level(1)
	await _frames(8)
	var intro := intro_level.get_node("BossIntro") as BossIntro
	_enter_arena(intro_level)
	await _physics(10)
	var intro_active: bool = intro.active
	_press_all(_tool_of(intro_level))
	await _physics(12)
	var intro_boss: BossBase = intro_level.boss
	_check("situations: during the boss intro the sequence ends it (the boss is not killed); the player is free and the game is not paused", intro_active and not intro.active and intro_boss.state != BossBase.State.DEAD \
		and not intro_level.player.is_input_locked() and not intro_level.player.story_invulnerable and not get_tree().paused)
	intro_level.free()
	await _frames(2)
	# During a possession transition.
	_clean_state()
	var level: LevelBase = await _fight()
	var director := level.get_node("PossessionDirector") as PossessionDirector
	_hurt_to(level, int(floor(_threshold_hp(level.boss, 0))))
	await _physics(4)
	var possessed: bool = director.active
	_press_all(_tool_of(level))
	await _physics(12)
	_check("situations: during a possession transition the sequence does nothing: the transition keeps running and the boss lives", possessed and director.active and level.boss.state == BossBase.State.PHASE_TRANSITION and level.boss.state != BossBase.State.DEAD)
	level.free()
	await _frames(2)
	# Hit in phase 1 (Phase 15o: there is no shell and no stagger any more).
	_clean_state()
	var stagger_level: LevelBase = await _fight()
	stagger_level.player.story_invulnerable = true
	_hit(stagger_level.boss, &"heavy", 3)
	var staggered: bool = stagger_level.boss.current_phase == 1
	_press_all(_tool_of(stagger_level))
	await _physics(10)
	_check("situations: right after a heavy hit in phase 1 the sequence sends the boss to its next corruption state", staggered and stagger_level.boss.state == BossBase.State.PHASE_TRANSITION and stagger_level.boss.state != BossBase.State.DEAD)
	stagger_level.free()
	await _frames(2)
	# In phase 3.
	_clean_state()
	var phase_level: LevelBase = await _fight()
	var phase_director := phase_level.get_node("PossessionDirector") as PossessionDirector
	_hurt_to(phase_level, int(floor(_threshold_hp(phase_level.boss, 0))))
	await _physics(3)
	await _skip_possession(phase_director)
	phase_level.player.story_invulnerable = true
	_hurt_to(phase_level, int(floor(_threshold_hp(phase_level.boss, 1))))
	await _physics(3)
	await _skip_possession(phase_director)
	var in_three: bool = phase_level.boss.current_phase == 3
	var three_boss: Variant = phase_level.boss
	_press_all(_tool_of(phase_level))
	await _physics(10)
	# Phase 15p: the guardian's last words (Phase 15n) hold the player, safely, until they end (confirm or hold to skip); then nothing stays locked.
	await _physics(70)
	var held_by_words: bool = phase_level.player.is_input_locked() and phase_level.player.story_invulnerable
	for node in phase_level.find_children("*", "BossDialogue", true, false):
		(node as BossDialogue).skip()
	await _physics(10)
	_check("situations: in phase 3 the key sequence defeats the boss; the last words hold the player and, once over, nothing is left locked", in_three and _boss_gone(three_boss) and held_by_words and not phase_level.player.is_input_locked() and not phase_level.player.story_invulnerable and not get_tree().paused)
	phase_level.free()
	await _frames(2)


func _test_developer_hidden_and_gated() -> void:
	var catalog := load(ControlsConfig.CATALOG_PATH) as ControlsCatalog
	var catalog_text: String = " ".join(catalog.action_ids) + " " + " ".join(catalog.action_names)
	var in_input_map: bool = false
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key != null:
				for code in [DeveloperShortcut.HOLD_KEY, DeveloperShortcut.TRIGGER_KEY]:
					in_input_map = in_input_map or key.physical_keycode == code or key.keycode == code
	_check("tools: it is not in the controls catalog (%d rebindable actions) and no InputMap action uses its keys, so it cannot be remapped" % catalog.action_ids.size(),
		catalog.action_ids.size() == 9 and not catalog_text.to_lower().contains("developer") and not in_input_map)
	var script_source: String = FileAccess.get_file_as_string("res://backend/progression/developer_shortcut.gd")
	_check("tools: it never touches the save (the script does not mention saving)", not script_source.to_lower().contains("save") and not script_source.contains("SaveSystem"))
	_check("tools: the release switch is one constant and it is off", DeveloperShortcut.ENABLE_IN_RELEASE == false)
	# As a release build it does not exist and does nothing.
	_clean_state()
	DeveloperShortcut.simulate_release_build = true
	_check("tools: with a release build and the constant off it is disabled", not DeveloperShortcut.is_enabled())
	var release_level := (load(LEVELS[2]) as PackedScene).instantiate() as LevelBase
	add_child(release_level)
	await _frames(3)
	_check("tools: in a release build the level has no such node and the enemies are untouched", _tool_of(release_level) == null)
	var loose := DeveloperShortcut.new()
	release_level.add_child(loose)
	await _frames(2)
	_check("tools: a loose instance frees itself in a release build", not is_instance_valid(loose) or loose.is_queued_for_deletion())
	release_level.free()
	DeveloperShortcut.simulate_release_build = false
	await _frames(2)


func _test_no_leaks() -> void:
	_clean_state()
	var counts: Array[int] = []
	for round in 4:
		_clean_state()
		var level: LevelBase = _boss_level(1)
		await _frames(8)
		_enter_arena(level)
		await _physics(10)
		_press_all(_tool_of(level))
		await _physics(10)
		level.free()
		await _frames(3)
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	print("MEASURE|node counts after repeated intros and developer kills|%s" % str(counts))
	_check("leaks: no nodes are left behind after repeated intros and kills (%s) and nothing is paused or locked" % str(counts), counts[3] <= counts[1] + 4 and not get_tree().paused and not PauseLock.is_locked())
