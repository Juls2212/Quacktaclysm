extends Node
## Headless smoke test for Phase 15n: shorter guardian dialogues (one short line at first sight, 2 to 3 last words before the fragment), blue
## soul fragments from regular enemies, cries on every landed hit, the sound of the story prologue, the grandfather's face at level start and no
## ability card after the last boss. Development only. Run:
##   <godot> --headless --path game res://frontend/scenes/test/phase15n_smoke_test.tscn
## Uses a redirected save path and a temporary settings file; the AI service stays disabled; the real files are never touched.

const TEST_SAVE: String = "user://test_save_phase15n.json"
const TEST_SETTINGS: String = "user://test_settings_phase15n.cfg"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const LEVELS: Dictionary = {
	1: "res://frontend/levels/level_1.tscn",
	2: "res://frontend/levels/level_2.tscn",
	3: "res://frontend/levels/level_3.tscn",
}
const MELEE: String = "res://backend/enemies/melee_enemy.tscn"
const DUCKLING: String = "res://backend/enemies/duckling.tscn"
const BOSS: String = "res://backend/bosses/boss_two.tscn"
const PLAYER: String = "res://backend/player/player.tscn"
const TUTORIAL: PackedScene = preload("res://frontend/levels/tutorial.tscn")
const EXORCISM: PackedScene = preload("res://frontend/fx/exorcism_cutscene.tscn")
const FLOOR_Y: float = 620.0

var failures: int = 0
var real_save_before: String = ""
var real_settings_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig
var texts: StoryTexts = StoryTexts.get_default()


func _ready() -> void:
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	GameSettings.path_override = TEST_SETTINGS
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
	real_settings_before = _read_file(GameSettings.PATH)
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


func _wait(seconds: float) -> void:
	var waited: float = 0.0
	while waited < seconds:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _set_options(values: Dictionary) -> void:
	var all: Dictionary = GameSettings.DEFAULTS.duplicate()
	all.merge(values, true)
	GameSettings.save_settings(all)


func _clean_state() -> void:
	Engine.time_scale = 1.0
	PauseLock.reset(get_tree())
	get_tree().paused = false
	InputMap.load_from_project_settings()
	Input.action_release(&"ui_accept")
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.director.clear_overrides()
	GameState.autosave_enabled = false
	AbilityCard.forget_all()
	BossDialogue.forget_all()
	_set_options({})
	SceneManager.dry_run = true
	var registry := SceneRegistry.new()
	registry.scenes = (load("res://backend/progression/default_scene_registry.tres") as SceneRegistry).scenes.duplicate()
	registry.fade_out_time = 0.0
	registry.fade_in_time = 0.0
	SceneManager.set_registry(registry)
	SceneManager.last_requested_scene_id = ""


func _level(number: int, intro: bool = false) -> LevelBase:
	var level := (load(LEVELS[number]) as PackedScene).instantiate() as LevelBase
	(level.get_node("BossIntro") as BossIntro).play_when_headless = intro
	add_child(level)
	await _frames(8)
	return level


func _free_node(node: Node) -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	if is_instance_valid(node):
		node.free()


func _accept() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	return event


func _run() -> void:
	_clean_state()
	_test_guards()
	_test_texts()
	await _test_first_sight_and_defeat()
	await _test_fragments()
	await _test_cries()
	await _test_prologue_audio()
	await _test_face()
	await _test_no_card_after_last_boss()
	await _test_leaks()
	SceneManager.dry_run = false
	_clean_state()
	SaveSystem.purge()
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	GameSettings.path_override = ""
	GameState.autosave_enabled = true
	_check("the real save file was not touched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	_check("the real settings file was not touched", _read_file(GameSettings.PATH) == real_settings_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


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


func _test_texts() -> void:
	var ok: bool = true
	var detail: PackedStringArray = PackedStringArray()
	for level in [1, 2, 3]:
		var story: BossStory = texts.get_boss(level)
		ok = ok and story.pre_lines.size() == 1 and story.pre_lines[0].length() <= 80 and story.duck_lines.size() == 1 and story.duck_lines[0].length() <= 80
		ok = ok and story.defeat_lines.size() >= 2 and story.defeat_lines.size() <= 3
		for line in story.defeat_lines:
			ok = ok and line.length() <= 120
		detail.append("%d: %d/%d, last words %d lines (longest %d)" % [level, story.pre_lines[0].length(), story.duck_lines[0].length(), story.defeat_lines.size(), story.defeat_lines.map(func(l: String) -> int: return l.length()).max()])
	_check("dialogue: each guardian says ONE line of at most 80 characters at first sight, the duck at most one short line, and 2 to 3 last words of at most 120 (%s)" % ", ".join(detail), ok)
	var quiet: bool = true
	for level in [1, 2]:
		var story: BossStory = texts.get_boss(level)
		var joined: String = " ".join(story.pre_lines + story.duck_lines + story.defeat_lines).to_lower()
		quiet = quiet and not joined.contains("abuelo")
	_check("dialogue: nobody mentions the grandfather before level 3", quiet)
	var joined_three: String = " ".join(texts.get_boss(3).defeat_lines).to_lower()
	_check("dialogue: boss 3 keeps the prophecy hint", joined_three.contains("profecía"))


## A level where the boss is defeated for real (a lethal hit through its hurtbox).
func _defeat(level: LevelBase) -> void:
	level.player.global_position = level.encounter.global_position
	await _physics(10)
	var boss: BossBase = level.boss
	boss.hurtbox.receive_hit(DamageInfo.create(boss.health.max_health, Vector2.ZERO, level.player, CombatLayers.Team.PLAYER))
	if boss.state != BossBase.State.DEAD:
		boss.health.kill(level.player)
	await _physics(3)


func _test_first_sight_and_defeat() -> void:
	for number in [1, 2, 3]:
		_clean_state()
		var level: LevelBase = await _level(number, true)
		var intro := level.get_node("BossIntro") as BossIntro
		var dialogue := level.get_node("BossDialogue") as BossDialogue
		var story: BossStory = texts.get_boss(number)
		level.player.global_position = level.encounter.global_position
		await _physics(10)
		_check("first sight %d: the intro starts with the player locked and safe" % number, intro.active and level.player.is_input_locked() and level.player.story_invulnerable)
		_check("first sight %d: the guardian says its one line" % number, dialogue.is_speaking() and dialogue.current_text().ends_with(story.pre_lines[0]))
		# Enter only: nothing advances by itself.
		Engine.time_scale = 8.0
		await _wait(20.0)
		Engine.time_scale = 1.0
		_check("first sight %d: no timer advanced it (still line 1 after 20 s)" % number, dialogue.lines_shown == 1 and intro.active)
		dialogue._grace_left = 0.0
		var presses: int = 0
		while intro.active and presses < 12:
			dialogue._input(_accept())
			presses += 1
			await _frames(1)
		_check("first sight %d: two lines in all (the guardian and the duck), then the fight starts (%d presses)" % [number, presses], not intro.active and dialogue.lines_shown == 2 and not level.player.is_input_locked())
		# A retry never plays it again.
		_check("first sight %d: a retry skips the first-sight line" % number, BossDialogue.was_spoken(level.scene_file_path) and not intro.should_play())
		_free_node(level)
		await _frames(2)
	# The last words, before the fragment.
	for number in [1, 2, 3]:
		_clean_state()
		var level: LevelBase = await _level(number)
		var dialogue := level.get_node("BossDialogue") as BossDialogue
		var story: BossStory = texts.get_boss(number)
		await _defeat(level)
		_check("last words %d: the fragment waits (held) from the defeat" % number, level.fragment_drop.is_held())
		Engine.time_scale = 4.0
		await _wait(texts.defeat_dialogue_delay + 0.5)
		Engine.time_scale = 1.0
		_check("last words %d: the guardian speaks %d lines and the player is locked and safe" % [number, story.defeat_lines.size()], dialogue.is_speaking() and dialogue.defeat_sequences == 1 and level.player.is_input_locked() and level.player.story_invulnerable)
		_check("last words %d: the fragment has NOT appeared yet" % number, not level.fragment_drop._spawned)
		dialogue._grace_left = 0.0
		var seen: int = 0
		var presses: int = 0
		while dialogue.is_speaking() and presses < 20:
			if dialogue.current_text().ends_with(story.defeat_lines[mini(seen, story.defeat_lines.size() - 1)]):
				seen = mini(seen + 1, story.defeat_lines.size())
			dialogue._input(_accept())
			presses += 1
			await _frames(1)
		_check("last words %d: only the confirm action advanced them (%d presses) and they ended" % [number, presses], not dialogue.is_speaking() and presses >= story.defeat_lines.size())
		# Phase 15r: the spirit of the guardian dissolves into the fragment (about 1.5 s) before everything is given back.
		var dissolve_wait: float = 0.0
		while level.fragment_drop.is_held() and dissolve_wait < 5.0:
			await get_tree().process_frame
			dissolve_wait += get_process_delta_time()
		_check("last words %d: the player is free again and the fragment is released" % number, not level.player.is_input_locked() and not level.player.story_invulnerable and not level.fragment_drop.is_held())
		Engine.time_scale = 6.0
		await _until_spawned(level)
		Engine.time_scale = 1.0
		_check("last words %d: the fragment appears afterwards, so the decision still follows" % number, level.fragment_drop._spawned)
		var before: int = dialogue.defeat_sequences
		dialogue._on_boss_defeated(null)
		await _frames(3)
		_check("last words %d: they never play twice for the same defeat" % number, dialogue.defeat_sequences == before)
		_free_node(level)
		await _frames(2)
	# Skip with the hold: the player and the fragment are released too.
	_clean_state()
	var skip_level: LevelBase = await _level(1)
	var skipper := skip_level.get_node("BossDialogue") as BossDialogue
	await _defeat(skip_level)
	Engine.time_scale = 4.0
	await _wait(texts.defeat_dialogue_delay + 0.5)
	Engine.time_scale = 1.0
	skipper.skip()
	await _frames(2)
	_check("last words: skipping (hold) frees the player and the fragment and breaks nothing", not skipper.is_speaking() and not skip_level.player.is_input_locked() and not skip_level.fragment_drop.is_held())
	_free_node(skip_level)
	await _frames(2)


func _until_spawned(level: LevelBase) -> void:
	var waited: float = 0.0
	while not level.fragment_drop._spawned and waited < 6.0:
		await get_tree().process_frame
		waited += get_process_delta_time()


# ---------------------------------------------------------------------------------------------

func _world() -> Dictionary:
	var world := Node2D.new()
	add_child(world)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000.0, 40.0)
	shape.shape = rect
	floor_body.add_child(shape)
	floor_body.position = Vector2(600.0, FLOOR_Y)
	world.add_child(floor_body)
	var player := (load(PLAYER) as PackedScene).instantiate() as Player
	player.position = Vector2(200.0, FLOOR_Y - 40.0)
	world.add_child(player)
	await _physics(5)
	return {"world": world, "player": player}


func _enemy(world: Node, path: String, at: Vector2) -> EnemyBase:
	var enemy := (load(path) as PackedScene).instantiate() as EnemyBase
	enemy.position = at
	world.add_child(enemy)
	return enemy


func _test_fragments() -> void:
	_clean_state()
	var setup: Dictionary = await _world()
	var world: Node2D = setup["world"]
	var player: Player = setup["player"]
	var config: SoulConfig = SoulConfig.get_default()
	var enemy := _enemy(world, MELEE, Vector2(900.0, FLOOR_Y - 40.0))
	await _physics(5)
	var hp: int = player.health.current_health
	enemy.health.kill()
	await _physics(3)
	var fragments: Array[Node] = get_tree().get_nodes_in_group(SoulPickup.GROUP)
	var fragment: SoulPickup = fragments[0] as SoulPickup if not fragments.is_empty() else null
	_check("fragment: a regular enemy leaves ONE small blue fragment when it dies", fragments.size() == 1 and fragment != null and fragment.style == SoulPickup.Style.FRAGMENT and fragment.amount == config.wisp_enemy)
	_check("fragment: nothing is absorbed at the instant of death (no instant gain, so it cannot be counted twice)", player.soul.soul == 0)
	var start_distance: float = fragment.global_position.distance_to(player.global_position)
	await _wait(config.fragment_float_seconds + 0.12)
	var mid_distance: float = fragment.global_position.distance_to(player.global_position) if is_instance_valid(fragment) else 0.0
	_check("fragment: it floats up first and then homes toward the player (%.0f px -> %.0f px)" % [start_distance, mid_distance], mid_distance < start_distance + 5.0)
	await _wait(1.2)
	_check("fragment: it is always collected: +%d soul exactly once (soul %d) and no hearts (%d -> %d)" % [config.wisp_enemy, player.soul.soul, hp, player.health.current_health], player.soul.soul == config.wisp_enemy and player.health.current_health == hp and get_tree().get_nodes_in_group(SoulPickup.GROUP).is_empty())
	# Cap: past the limit the value merges, nothing piles up and nothing is lost.
	var spawned_total: int = 0
	for i in config.fragment_max_active + 20:
		SoulPickup.spawn(world, Vector2(900.0 + i, 300.0), 1, SoulPickup.Style.FRAGMENT)
		spawned_total += 1
	var active: Array[Node] = get_tree().get_nodes_in_group(SoulPickup.GROUP)
	var sum: int = 0
	for node in active:
		sum += (node as SoulPickup).amount
	_check("fragment: at most %d fragments at once (%d) and the value of the extra ones is merged, not lost (%d of %d)" % [config.fragment_max_active, active.size(), sum, spawned_total], active.size() <= config.fragment_max_active and sum == spawned_total)
	for node in active:
		node.free()
	# Ducklings: a smaller fragment with their own value, and the killing hit pays nothing by itself.
	player.soul.reset()
	var duckling := _enemy(world, DUCKLING, Vector2(950.0, FLOOR_Y - 20.0)) as Duckling
	duckling.soul_gain = 5
	await _physics(5)
	_check("fragment: the hit that kills a duckling pays nothing by itself", duckling.soul_gain_override() == 0)
	duckling.health.kill()
	await _physics(3)
	var small: Array[Node] = get_tree().get_nodes_in_group(SoulPickup.GROUP)
	_check("fragment: a duckling drops a SMALLER fragment with its own value (%d)" % duckling.soul_gain, small.size() == 1 and (small[0] as SoulPickup).style == SoulPickup.Style.SMALL and (small[0] as SoulPickup).amount == 5)
	await _wait(1.6)
	_check("fragment: its value arrives once (%d)" % player.soul.soul, player.soul.soul == 5)
	# A boss does not drop the blue fragment (its big wisp is the same as before).
	player.soul.reset()
	var boss := (load(BOSS) as PackedScene).instantiate() as BossBase
	boss.position = Vector2(1100.0, FLOOR_Y - 44.0)
	world.add_child(boss)
	await _physics(5)
	boss.health.kill()
	await _physics(4)
	_check("fragment: a boss leaves no blue fragment (only its big wisp)", get_tree().get_nodes_in_group(SoulPickup.GROUP).is_empty() and not world.find_children("SoulPickup*", "Node2D", true, false).is_empty())
	await _wait(1.3)
	# Reload: a level cleans every fragment.
	SoulPickup.spawn(world, Vector2(700.0, 300.0), 3, SoulPickup.Style.FRAGMENT)
	world.free()
	await _frames(2)
	_check("fragment: nothing is left after the scene goes away", get_tree().get_nodes_in_group(SoulPickup.GROUP).is_empty())


# ---------------------------------------------------------------------------------------------

func _cries() -> int:
	return int(AudioDirector.events_played.get(&"hit_cry", 0))


func _test_cries() -> void:
	_clean_state()
	var setup: Dictionary = await _world()
	var world: Node2D = setup["world"]
	var player: Player = setup["player"]
	var table: AudioEvents = AudioEvents.get_default()
	var enemy := _enemy(world, MELEE, Vector2(900.0, FLOOR_Y - 40.0))
	_wire(enemy.hurtbox)
	await _physics(5)
	var before: int = _cries()
	var landed: bool = enemy.hurtbox.receive_hit(DamageInfo.create(1, Vector2.ZERO, player, CombatLayers.Team.PLAYER, &"light"))
	_check("cries: a landed hit on a regular enemy makes a cry", landed and _cries() == before + 1)
	before = _cries()
	AudioDirector._hit_cry(enemy)
	_check("cries: the same target cannot cry again right away (cooldown %.2f s)" % table.hit_cry_target_cooldown, _cries() == before)
	var duckling := _enemy(world, DUCKLING, Vector2(950.0, FLOOR_Y - 20.0))
	duckling.health.max_health = 30
	duckling.health.current_health = 30
	_wire(duckling.hurtbox)
	await _physics(3)
	await _wait(1.1)
	before = _cries()
	duckling.hurtbox.receive_hit(DamageInfo.create(1, Vector2.ZERO, player, CombatLayers.Team.PLAYER, &"light"))
	_check("cries: a landed hit on a duckling makes a cry too", _cries() == before + 1)
	await _wait(1.1)
	var boss := (load(BOSS) as PackedScene).instantiate() as BossBase
	boss.position = Vector2(1100.0, FLOOR_Y - 44.0)
	world.add_child(boss)
	_wire(boss.hurtbox)
	await _physics(5)
	before = _cries()
	boss.hurtbox.hit_received.emit(DamageInfo.create(1, Vector2.ZERO, player, CombatLayers.Team.PLAYER, &"light"), true)
	_check("cries: a landed hit on a boss makes its cry", _cries() == before + 1)
	await _wait(1.1)
	# A blocked hit (a shell, a shield, armor) makes no cry.
	var blocked_enemy := _enemy(world, MELEE, Vector2(1000.0, FLOOR_Y - 40.0))
	await _physics(3)
	var blocker := Node.new()
	var script := GDScript.new()
	script.source_code = "extends Node\nfunc filter_hit(_info) -> bool:\n\treturn true\n"
	script.reload()
	blocker.set_script(script)
	world.add_child(blocker)
	blocked_enemy.hurtbox.hit_filter = blocker
	_wire(blocked_enemy.hurtbox)
	before = _cries()
	var applied: bool = blocked_enemy.hurtbox.receive_hit(DamageInfo.create(1, Vector2.ZERO, player, CombatLayers.Team.PLAYER, &"light"))
	_check("cries: a blocked hit (shell, shield, armor) makes no cry", not applied and _cries() == before)
	# The global limit: a crowd of hits in a second never becomes noise.
	await _wait(1.1)
	before = _cries()
	var crowd: Array[EnemyBase] = []
	for i in 14:
		var e := _enemy(world, MELEE, Vector2(1200.0 + float(i) * 30.0, FLOOR_Y - 40.0))
		e.health.max_health = 30
		e.health.current_health = 30
		_wire(e.hurtbox)
		crowd.append(e)
	await _physics(3)
	for e in crowd:
		e.hurtbox.receive_hit(DamageInfo.create(1, Vector2.ZERO, player, CombatLayers.Team.PLAYER, &"light"))
	var made: int = _cries() - before
	_check("cries: fourteen hits in the same instant make at most %d cries (%d)" % [table.hit_cry_global_per_second, made], made <= table.hit_cry_global_per_second and made >= 1)
	_check("cries: the cry files exist and the pitch and volume are in the audio table", _cry_files_exist(table) and table.hit_cry_pitch_min < table.hit_cry_pitch_max and table.hit_cry_volume_db < 0.0)
	world.free()
	await _frames(2)


## The director does not wire hurtboxes in headless runs (it listens to nodes only in a window): the test does it as the real hook would.
func _wire(hurtbox: Hurtbox) -> void:
	if not hurtbox.hit_received.is_connected(AudioDirector._on_hit_received):
		hurtbox.hit_received.connect(AudioDirector._on_hit_received.bind(hurtbox))


func _cry_files_exist(table: AudioEvents) -> bool:
	for file in table.hit_cry_files + table.boss_cry_files:
		if not FileAccess.file_exists("res://frontend/audio/sfx/ducks/" + file):
			return false
	return true


# ---------------------------------------------------------------------------------------------

func _test_prologue_audio() -> void:
	_clean_state()
	var audio: PrologueAudio = PrologueAudio.get_default()
	_check("prologue: the sound is an existing track and effects from the audio table (%s, %d effects)" % [audio.music_file, audio.effects.size()], FileAccess.file_exists("res://frontend/audio/music/" + audio.music_file) and audio.effects.size() >= 6)
	var table: AudioEvents = AudioEvents.get_default()
	var known: bool = true
	for effect in audio.effects:
		known = known and table.get_event(StringName(effect["event"])) != null
	_check("prologue: every effect is an existing event of the audio table", known)
	var level := TUTORIAL.instantiate() as LevelBase
	var prologue := level.get_node("PrologueCutscene") as PrologueCutscene
	prologue.skip_when_headless = false
	add_child(level)
	var waited: float = 0.0
	while not prologue.music_playing and waited < 5.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	var state: Dictionary = AudioDirector.get_music_state()
	_check("prologue: its music plays processed (track %s, pitch %.2f, low-pass on: %s)" % [state["requested_track"], state["requested_pitch"], str(AudioDirector.get_music_profile()["filter_on_bus"])], prologue.music_playing and state["requested_track"] == audio.music_file and bool(AudioDirector.get_music_profile()["filter_on_bus"]))
	Engine.time_scale = 8.0
	waited = 0.0
	while prologue.effects_played < 2 and waited < 120.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	Engine.time_scale = 1.0
	_check("prologue: effects for the key beats play (%d so far)" % prologue.effects_played, prologue.effects_played >= 2)
	# Pause: the music goes quiet with the game and comes back.
	get_tree().paused = true
	await _wait(0.3)
	var paused_duck: float = float(AudioDirector.get_music_state()["duck_db"])
	var played_paused: int = prologue.effects_played
	await _wait(0.5)
	get_tree().paused = false
	await _frames(3)
	_check("prologue: on pause the music ducks to silence (%.0f dB), no effect plays meanwhile and it comes back" % paused_duck, paused_duck <= -20.0 and prologue.effects_played == played_paused and float(AudioDirector.get_music_state()["duck_db"]) > -20.0)
	# Skip: it stops cleanly.
	prologue.skip()
	await _wait(1.2)
	var after: Dictionary = AudioDirector.get_music_state()
	_check("prologue: after a skip the music, its filter and its duck are given back (music playing %s, duck %.0f dB, filter on: %s)" % [str(prologue.is_inside_tree() and prologue.music_playing), after["duck_db"], str(AudioDirector.get_music_profile()["filter_on_bus"])], not (is_instance_valid(prologue) and prologue.music_playing) and float(after["duck_db"]) > -20.0 and not bool(AudioDirector.get_music_profile()["filter_on_bus"]))
	_free_node(level)
	await _frames(2)
	# Exit while it plays: everything is given back too.
	var level2 := TUTORIAL.instantiate() as LevelBase
	var prologue2 := level2.get_node("PrologueCutscene") as PrologueCutscene
	prologue2.skip_when_headless = false
	add_child(level2)
	waited = 0.0
	while not prologue2.music_playing and waited < 5.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_free_node(level2)
	await _frames(3)
	_check("prologue: leaving the scene while it plays stops its music cleanly (filter off, duck back)", float(AudioDirector.get_music_state()["duck_db"]) > -20.0 and not bool(AudioDirector.get_music_profile()["filter_on_bus"]))


# ---------------------------------------------------------------------------------------------

func _test_face() -> void:
	_clean_state()
	var presentation: GrandfatherPresentation = GrandfatherPresentation.get_default()
	var alphas: Array[float] = []
	var tears: int = 0
	var calm: bool = true
	for number in [1, 2, 3]:
		var face := GrandfatherFace.new()
		face.setup(presentation, number, false)
		add_child(face)
		await _wait(presentation.fade_in_time + 0.4)
		alphas.append(face.portrait.alpha)
		# Phase 15r: the face is his full-body figure; there are no tear particles or overlay nodes at all.
		tears += face.portrait.find_children("*Tear*", "", true, false).size()
		calm = calm and (face.portrait.expression == &"watching" or face.portrait.expression == &"speaking")
		face.free()
	print("MEASURE|face opacity at levels 1, 2 and 3|%s" % str(alphas))
	_check("face: levels 1 and 2 are a faded memory (%.2f, %.2f) and level 3 is solid (%.2f)" % [alphas[0], alphas[1], alphas[2]], absf(alphas[0] - presentation.face_memory_alpha) < 0.02 and absf(alphas[1] - presentation.face_memory_alpha) < 0.02 and absf(alphas[2] - presentation.face_solid_alpha) < 0.02)
	_check("face: only calm and speaking states, never tears (%d tears)" % tears, calm and tears == 0)
	var still := GrandfatherFace.new()
	still.setup(presentation, 2, true)
	add_child(still)
	await _frames(5)
	_check("face (reduced): a still portrait with a plain fade", still.reduced and still.portrait.reduced)
	still.free()
	_check("face: the star silhouette code is retired (no GrandfatherReflection class or file)", not FileAccess.file_exists("res://frontend/presentation/grandfather_reflection.gd") and not _class_exists("GrandfatherReflection"))
	var voice_source: String = FileAccess.get_file_as_string("res://frontend/presentation/grandfather_voice.gd")
	_check("face: the level-start line uses the face and keeps its rules (never in a fight, a boss intro or after a death)", voice_source.contains("GrandfatherFace.new()") and voice_source.contains("_fight_active()") and voice_source.contains("dismiss(false)"))


func _class_exists(name: String) -> bool:
	for entry in ProjectSettings.get_global_class_list():
		if String(entry["class"]) == name:
			return true
	return false


# ---------------------------------------------------------------------------------------------

func _test_no_card_after_last_boss() -> void:
	var config: AbsorptionConfig = AbsorptionConfig.get_default()
	_check("no card: the last fragment is listed as one with no power card (%s)" % str(config.no_card_fragments), config.no_card_fragments.has("fragment_level_3") and not config.no_card_fragments.has("fragment_level_1") and not config.no_card_fragments.has("fragment_level_2"))
	# KEPT, level 3: the dark sequence, then it finishes by itself: no card.
	_clean_state()
	var cut := EXORCISM.instantiate() as ExorcismCutscene
	cut.fragment_id = "fragment_level_3"
	var finished: Array[bool] = [false]
	cut.finished.connect(func() -> void: finished[0] = true)
	add_child(cut)
	Engine.time_scale = 4.0
	await _wait(config.length + 0.6)
	Engine.time_scale = 1.0
	await _frames(3)
	_check("no card: after the dark sequence of the last fragment it ends by itself, with no power card (finished %s)" % str(finished[0]), finished[0] and not is_instance_valid(cut))
	# Levels 1 and 2 keep their card: the sequence goes on to it.
	for fragment in ["fragment_level_1", "fragment_level_2"]:
		var other := EXORCISM.instantiate() as ExorcismCutscene
		other.fragment_id = fragment
		add_child(other)
		Engine.time_scale = 4.0
		await _wait(config.length + 0.5)
		Engine.time_scale = 1.0
		_check("no card: %s still goes on to its power card" % fragment, is_instance_valid(other) and other._card_t >= 0.0)
		other._finish()
		await _frames(2)
	# AbilityIntro: the last decision opens no card in either path; levels 1 and 2 are untouched.
	for choice in [GameState.CHOICE_KEPT, GameState.CHOICE_RELEASED]:
		_clean_state()
		var level: LevelBase = await _level(3)
		var intro := level.get_node("AbilityIntro") as AbilityIntro
		intro.play_when_headless = true
		var queue: PresentationQueue = intro.get_queue()
		var enqueued: Array[int] = [queue.finished_ids.size()]
		intro._on_decision_made("fragment_level_3", choice)
		await _frames(4)
		_check("no card: after boss 3 (%s) the ability intro enqueues nothing and no card opens" % choice, intro.card == null and queue.current_id.is_empty() and queue.finished_ids.size() == enqueued[0])
		_free_node(level)
		await _frames(2)
	_clean_state()
	var level_one: LevelBase = await _level(1)
	var intro_one := level_one.get_node("AbilityIntro") as AbilityIntro
	intro_one.play_when_headless = true
	GameState.record_decision("fragment_level_1", "boss_one", 1, GameState.CHOICE_KEPT)
	level_one.player.wave_caster.current_tier = 1
	intro_one._on_decision_made("fragment_level_1", GameState.CHOICE_KEPT)
	await _frames(4)
	var queue_one: PresentationQueue = intro_one.get_queue()
	_check("no card: level 1 still queues its corruption step and its wave card", queue_one.current_id.begins_with("corruption_") or queue_one.finished_ids.size() > 0 or queue_one.current_id.begins_with("card_"), queue_one.current_id)
	_free_node(level_one)
	await _frames(2)
	_clean_state()
	var level_two: LevelBase = await _level(2)
	var intro_two := level_two.get_node("AbilityIntro") as AbilityIntro
	intro_two.play_when_headless = true
	intro_two._on_decision_made("fragment_level_2", GameState.CHOICE_RELEASED)
	await _frames(4)
	var queue_two: PresentationQueue = intro_two.get_queue()
	_check("no card: level 2 still gives its double jump card (even released)", queue_two.current_id.begins_with("corruption_") or queue_two.current_id.begins_with("card_") or queue_two.finished_ids.size() > 0, queue_two.current_id)
	_free_node(level_two)
	await _frames(2)
	# The ending is reached in both paths: the level moves on to it after the decision, with no card in between.
	for choice in [GameState.CHOICE_KEPT, GameState.CHOICE_RELEASED]:
		_clean_state()
		var level: LevelBase = await _level(3)
		await _defeat(level)
		(level.get_node("BossDialogue") as BossDialogue).skip()
		Engine.time_scale = 6.0
		await _until_spawned(level)
		GameState.record_decision("fragment_level_3", "boss_three", 3, choice)
		level.decision_flow.decision_made.emit("fragment_level_3", choice)
		var waited: float = 0.0
		while SceneManager.last_requested_scene_id.is_empty() and waited < 30.0:
			await get_tree().process_frame
			waited += get_process_delta_time()
		Engine.time_scale = 1.0
		_check("no card: boss 3 %s -> the level goes on to the ending (%s) with no card in between" % [choice, SceneManager.last_requested_scene_id], SceneManager.last_requested_scene_id == level.next_scene_id and not level.next_scene_id.is_empty())
		_free_node(level)
		await _frames(2)


func _test_leaks() -> void:
	_clean_state()
	var counts: Array[int] = []
	for round in 4:
		var setup: Dictionary = await _world()
		var world: Node2D = setup["world"]
		for i in 4:
			var enemy := _enemy(world, MELEE, Vector2(800.0 + float(i) * 40.0, FLOOR_Y - 40.0))
			await _physics(3)
			enemy.hurtbox.receive_hit(DamageInfo.create(1, Vector2.ZERO, setup["player"], CombatLayers.Team.PLAYER, &"light"))
			enemy.health.kill()
		await _wait(1.4)
		world.free()
		var face := GrandfatherFace.new()
		face.setup(GrandfatherPresentation.get_default(), 1, false)
		add_child(face)
		await _frames(10)
		face.free()
		await _frames(3)
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	print("MEASURE|node counts after four rounds of fights and faces|%s" % str(counts))
	_check("leaks: no nodes are left behind after repeating fights with fragments and faces (%s)" % str(counts), counts[3] <= counts[1] + 4 and not get_tree().paused)
	var keys: Array = GameState.to_dict().keys()
	keys.sort()
	var expected: Array = SAVE_KEYS.duplicate()
	expected.sort()
	_check("save: after all of it still the seven keys", keys == expected)
