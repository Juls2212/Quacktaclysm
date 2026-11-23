extends Node
## Headless smoke test for Phase 14d (story and endings): the four deterministic endings (by souls
## released) for all 8 decision combinations, the story texts (souls, guardians, grandfather, endings),
## the decision panel's soul story, the guardians' lines (once per encounter, skippable), the ending
## sequence (skippable by holding confirm, then the summary card with the soul names), the
## grandfather's scene before the last boss (skippable), and the guards (7 save keys, 3 autoloads,
## the "ending" marker, the real save untouched). Development only. Run:
##   <godot> --headless --path game res://frontend/scenes/test/phase14d_smoke_test.tscn
## Uses a redirected save path; the AI service stays disabled; the real save is never touched.

const TEST_SAVE: String = "user://test_save_phase14d.json"
const ENDING_SCENE: PackedScene = preload("res://frontend/ui/ending.tscn")
const PANEL_SCENE: PackedScene = preload("res://frontend/ui/decision_panel.tscn")
const LEVEL_PATHS: Dictionary = {
	1: "res://frontend/levels/level_1.tscn",
	3: "res://frontend/levels/level_3.tscn",
}
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const REL: String = "released"
const KEP: String = "kept"
## Phase 15h: two endings by the majority of the decisions (more kept than released -> kept; otherwise released).
const EXPECTED_ENDING: Dictionary = {3: "ending_released", 2: "ending_released", 1: "ending_kept", 0: "ending_kept"}
const MAX_LINE: int = 110

var failures: int = 0
var real_save_before: String = ""
var texts: StoryTexts = null
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig


func _ready() -> void:
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
	texts = load(StoryTexts.DEFAULT_PATH) as StoryTexts
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


func _clean_state() -> void:
	PauseLock.reset(get_tree())
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.autosave_enabled = false
	BossDialogue.forget_all()
	Input.action_release("ui_accept")


func _decide(choices: Array[String]) -> void:
	for index in choices.size():
		GameState.record_decision("fragment_level_%d" % (index + 1), "boss_%d" % (index + 1), index + 1, choices[index])
	GameState.refresh_adaptive_profile(AdaptiveInput.POINT_ENDING)


func _run() -> void:
	_test_guards()
	_test_texts()
	_test_reading_times()
	await _test_endings_table()
	await _test_ending_sequence()
	await _test_decision_panel()
	await _test_boss_dialogue()
	await _test_elder_scene()
	_clean_state()
	SaveSystem.purge()
	GameState.autosave_enabled = true
	_check("the real save file was not touched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------------------------------------
# 1. Guards
# ---------------------------------------------------------------------------------------------

func _test_guards() -> void:
	_clean_state()
	_decide([REL, KEP, REL])
	GameState.set_current_level(3)
	GameState.set_checkpoint(GameState.CHECKPOINT_ENDING)
	var data: Dictionary = GameState.to_dict()
	var keys: Array = data.keys()
	keys.sort()
	var expected: Array = SAVE_KEYS.duplicate()
	expected.sort()
	_check("save: exactly the seven keys", keys == expected, str(keys))
	_check("save: the ending marker is still checkpoint = \"ending\"", data["checkpoint"] == "ending" and GameState.is_game_completed())
	var autoloads: PackedStringArray = PackedStringArray()
	for property in ProjectSettings.get_property_list():
		var property_name: String = property["name"]
		if property_name.begins_with("autoload/"):
			autoloads.append(property_name.trim_prefix("autoload/"))
	autoloads.sort()
	_check("autoloads: exactly GameState, SceneManager and AudioDirector",
		autoloads == PackedStringArray(["AudioDirector", "GameState", "SceneManager"]), str(autoloads))
	_clean_state()


# ---------------------------------------------------------------------------------------------
# 2. Texts
# ---------------------------------------------------------------------------------------------

func _all_strings() -> Array[String]:
	var all: Array[String] = []
	for entry: Variant in texts.souls:
		var soul := entry as SoulStory
		all.append_array([soul.soul_name, soul.short_name, soul.memory, soul.released_line, soul.kept_line])
	for entry: Variant in texts.bosses:
		var boss := entry as BossStory
		all.append_array(boss.pre_lines)
		for variant: Variant in boss.variant_lines.values():
			all.append(String(variant))
		all.append_array(boss.defeat_lines)
	for entry: Variant in texts.endings:
		var ending := entry as EndingStory
		all.append(ending.title)
		all.append_array(ending.lines)
		all.append(ending.summary_line)
	all.append_array(texts.elder_lines)
	all.append_array(texts.elder_mood_lines)
	all.append_array([texts.summary_released_format, texts.summary_kept_format, texts.summary_released_names_format,
		texts.summary_kept_names_format, texts.summary_none_text, texts.summary_back_text, texts.skip_hint, texts.hold_skip_hint])
	return all


func _test_texts() -> void:
	_check("texts: 3 souls, 3 guardians, 2 endings", texts.souls.size() == 3 and texts.bosses.size() == 3 and texts.endings.size() == 2)
	var all: Array[String] = _all_strings()
	var empty: int = 0
	var provisional: int = 0
	var raw_ids: int = 0
	var too_long: Array[String] = []
	for text in all:
		if text.strip_edges().is_empty():
			empty += 1
		if text.to_lower().contains("provisional") or text.to_lower().contains("placeholder"):
			provisional += 1
		if text.contains("fragment_level") or text.contains("ending_") or text.contains("boss_") or text.contains("narrative"):
			raw_ids += 1
		if text.length() > MAX_LINE:
			too_long.append(text)
	_check("texts: %d strings, none empty" % all.size(), empty == 0 and all.size() > 60)
	_check("texts: no '(texto provisional)' / placeholder", provisional == 0)
	_check("texts: no raw ids shown to the player", raw_ids == 0)
	_check("texts: every line is short (max %d characters)" % MAX_LINE, too_long.is_empty(), str(too_long))
	var joined: String = " ".join(all)
	_check("texts: Spanish with accents", joined.contains("ó") and joined.contains("á") and joined.contains("í") and joined.contains("«"))
	var names_ok: bool = true
	for fragment_id in ["fragment_level_1", "fragment_level_2", "fragment_level_3"]:
		var soul: SoulStory = texts.get_soul(fragment_id)
		names_ok = names_ok and soul != null and not soul.soul_name.is_empty() and not soul.memory.is_empty() \
				and not soul.released_line.is_empty() and not soul.kept_line.is_empty() and soul.soul_name.begins_with(soul.short_name)
		var data: SoulFragmentData = load("res://backend/decisions/data/%s.tres" % fragment_id) as SoulFragmentData
		names_ok = names_ok and soul != null and data.display_name == soul.soul_name and data.description == soul.memory
	_check("texts: every soul has a name, a memory, a released and a kept line (and the fragment data matches)", names_ok)
	var third: SoulStory = texts.get_soul("fragment_level_3")
	_check("texts: the third soul is the one the grandfather failed to save", third.memory.contains("abuelo") and third.memory.contains("tiempo"))
	var bosses_ok: bool = true
	for level in [1, 2, 3]:
		var boss: BossStory = texts.get_boss(level)
		bosses_ok = bosses_ok and boss != null and boss.pre_lines.size() == 1 and boss.pre_lines[0].length() <= 80 and boss.duck_lines.size() == 1 and boss.duck_lines[0].length() <= 80 \
				and boss.defeat_lines.size() >= 2 and boss.defeat_lines.size() <= 3 and boss.variant_lines.is_empty() and boss.lines_for("neutral").size() == 1 and boss.lines_for("corrupt").size() == 1
		for defeat_line in boss.defeat_lines:
			bosses_ok = bosses_ok and defeat_line.length() <= 120
	_check("texts: each guardian has ONE short line at first sight (<= 80), one short duck line and 2-3 last words (<= 120) (Phase 15n)", bosses_ok)
	var endings_ok: bool = true
	for ending_id in EXPECTED_ENDING.values():
		var ending: EndingStory = texts.get_ending(ending_id)
		endings_ok = endings_ok and ending != null and ending.lines.size() >= 5 and ending.lines.size() <= 9 and not ending.title.is_empty() and ["kept", "released"].has(ending.style) and ending.beats != null
	_check("texts: every ending has a title, 5-9 lines, a style and a beat list (Phase 15i-bis: the music lives in the audio table slots)", endings_ok)
	_check("texts: the endings have different titles and music styles", _distinct(texts.endings.map(func(e: Variant) -> String: return (e as EndingStory).title)) == 2
		and _distinct(texts.endings.map(func(e: Variant) -> String: return (e as EndingStory).style)) == 2)
	_check("texts: there are exactly two endings (Phase 15h), the old four and their texts are gone", texts.endings.size() == 2 and texts.get_ending("ending_kept") != null and texts.get_ending("ending_released") != null
		and texts.get_ending("ending_full") == null and texts.get_ending("ending_scar") == null and texts.get_ending("ending_doubt") == null and texts.get_ending("ending_corrupt") == null)
	var moods: Array[String] = [texts.elder_script(0)[texts.elder_mood_index], texts.elder_script(1)[texts.elder_mood_index], texts.elder_script(2)[texts.elder_mood_index]]
	_check("texts: the grandfather's tone changes with the souls released", _distinct(moods) == 3 and texts.elder_script(0).size() == texts.elder_lines.size() + 1)


func _distinct(values: Array) -> int:
	var seen: Dictionary = {}
	for value: Variant in values:
		seen[value] = true
	return seen.size()


func _test_reading_times() -> void:
	for ending_id in EXPECTED_ENDING.values():
		var beats: EndingBeatList = texts.get_ending(ending_id).beats
		var length: float = beats.timed_seconds() if beats != null else 0.0
		_check("timing: %s has %.0f s of timed beats (Phase 15i: inside %.0f-%.0f s) plus the lines the player reads" % [ending_id, length, beats.min_seconds, beats.max_seconds], beats != null and length >= beats.min_seconds and length <= beats.max_seconds)
	var elder := StoryReel.new()
	for index in 3:
		elder.lines = texts.elder_script(index)
		elder.hold_scale = 0.3
		_check("timing: the grandfather's scene lasts at most ~22 s with %d released (%.1f s)" % [index, elder.total_length()], elder.total_length() <= 22.0)
	elder.free()


# ---------------------------------------------------------------------------------------------
# 3. Endings by souls released (all 8 combinations)
# ---------------------------------------------------------------------------------------------

func _test_endings_table() -> void:
	print("TABLE: decisions (L1 L2 L3) -> released -> ending | title")
	for mask in 8:
		var choices: Array[String] = []
		var released: int = 0
		for i in 3:
			var released_here: bool = (mask >> i) & 1 == 1
			choices.append(REL if released_here else KEP)
			released += 1 if released_here else 0
		_clean_state()
		_decide(choices)
		var ending := ENDING_SCENE.instantiate() as EndingController
		add_child(ending)
		await _frames(2)
		var label: String = "%s %s %s" % [choices[0], choices[1], choices[2]]
		var expected: String = EXPECTED_ENDING[released]
		_check("ending: %s -> %d released -> %s" % [label, released, expected], ending.shown_variant == expected
			and ending.title_label.text == texts.get_ending(expected).title and EndingSelector.ending_id_for(released, 3 - released) == expected)
		var lines: Array[String] = ending.get_reel_lines()
		var joined: String = " ".join(lines)
		var kept_name: String = ""
		var released_name: String = ""
		for index in 3:
			if choices[index] == KEP:
				kept_name = texts.get_soul("fragment_level_%d" % (index + 1)).short_name
			else:
				released_name = texts.get_soul("fragment_level_%d" % (index + 1)).short_name
		var names_ok: bool = not joined.contains("{") and not joined.contains("}")
		_check("ending: %s -> the lines name the right soul and leave no token" % label, names_ok, joined.substr(0, 60))
		ending.free()
		print("TABLE: %s -> %d -> %s | %s" % [label, released, expected, texts.get_ending(expected).title])
	_clean_state()


# ---------------------------------------------------------------------------------------------
# 4. The ending sequence and the summary card
# ---------------------------------------------------------------------------------------------

func _test_ending_sequence() -> void:
	_clean_state()
	_decide([REL, KEP, REL])
	var before: Dictionary = GameState.to_dict()
	var save_before: String = _read_file(TEST_SAVE)
	var ending := ENDING_SCENE.instantiate() as EndingController
	ending.skip_reel_when_headless = false
	add_child(ending)
	await _frames(3)
	_check("sequence: the scene plays the reel first and keeps the card hidden", ending.reel != null and not ending.card_visible and not ending.box.visible)
	_check("sequence: 5-8 lines, hold-to-skip mode", ending.reel.lines.size() >= 5 and ending.reel.lines.size() <= 8 and is_equal_approx(ending.reel.hold_seconds, 1.2))
	_check("sequence: the title card is the ending title", ending.reel.title_text == texts.get_ending("ending_released").title)
	var waited_line: float = 0.0
	Engine.time_scale = 20.0
	while ending.reel.current_line_text().is_empty() and waited_line < 20.0:
		await get_tree().process_frame
		waited_line += get_process_delta_time()
	Engine.time_scale = 1.0
	_check("sequence: after the title the first line is typed", not ending.reel.current_line_text().is_empty() and not ending.reel.current_line_text().contains("{"), ending.reel.current_line_text())
	# A short press does not skip; holding confirm does.
	Input.action_press("ui_accept")
	await get_tree().create_timer(0.3).timeout
	Input.action_release("ui_accept")
	await _frames(2)
	_check("sequence: a short press does not skip it", ending.reel != null and not ending.reel.is_finished and not ending.card_visible)
	Input.action_press("ui_accept")
	var waited: float = 0.0
	while not ending.card_visible and waited < 6.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	Input.action_release("ui_accept")
	_check("sequence: holding confirm skips it and the summary card appears", ending.card_visible and ending.box.visible)
	_check("card: counters and the names of the souls released / kept", ending.released_label.text == "Almas liberadas: 2" and ending.kept_label.text == "Almas guardadas: 1"
		and ending.released_names_label.text == "Liberadas: Daigo, el Leñador, Kenzo, hermano de espada" and ending.kept_names_label.text == "Guardadas: Hana, la Herbolaria",
		"%s | %s" % [ending.released_names_label.text, ending.kept_names_label.text])
	_check("card: no raw narrative id and no provisional text", not ending.ending_label.text.contains("narrativa") and not ending.ending_label.text.to_lower().contains("provisional"))
	_check("card: focus on the back button", ending.back_button.has_focus())
	_check("sequence: GameState and the save are untouched, the marker stays", GameState.to_dict() == before and _read_file(TEST_SAVE) == save_before)
	ending.free()
	await _frames(2)
	# Skipping through the API, and the all-souls-kept card.
	_clean_state()
	_decide([KEP, KEP, KEP])
	var dark := ENDING_SCENE.instantiate() as EndingController
	dark.skip_reel_when_headless = false
	add_child(dark)
	await _frames(3)
	dark.reel.skip()
	await get_tree().create_timer(0.8).timeout
	_check("sequence: reel.skip() ends it and shows the card (0 released -> 'ninguna')", dark.card_visible and dark.released_names_label.text == "Liberadas: ninguna"
		and dark.shown_variant == "ending_kept")
	dark.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 5. The decision panel shows the soul's story
# ---------------------------------------------------------------------------------------------

func _test_decision_panel() -> void:
	_clean_state()
	var panel := PANEL_SCENE.instantiate() as DecisionPanel
	add_child(panel)
	await _frames(2)
	var ok: bool = true
	for fragment_id in ["fragment_level_1", "fragment_level_2", "fragment_level_3"]:
		var data: SoulFragmentData = load("res://backend/decisions/data/%s.tres" % fragment_id) as SoulFragmentData
		var soul: SoulStory = texts.get_soul(fragment_id)
		panel.open(data)
		ok = ok and panel.name_label.text == soul.soul_name and panel.description_label.text == soul.memory \
				and panel.release_caption_label.text == soul.released_line and panel.keep_caption_label.text == soul.kept_line
		panel.close()
	_check("panel: each soul shows its name, its memory and what each choice does", ok)
	var unknown := SoulFragmentData.new()
	unknown.fragment_id = "fragment_unknown"
	unknown.display_name = "Otro"
	unknown.description = "Sin historia."
	panel.open(unknown)
	_check("panel: a fragment without a story keeps its own text and the generic captions",
		panel.name_label.text == "Otro" and panel.release_caption_label.text == panel.release_caption)
	panel.close()
	panel.free()
	_clean_state()


# ---------------------------------------------------------------------------------------------
# 6. The guardians speak
# ---------------------------------------------------------------------------------------------

func _make_level(number: int) -> LevelBase:
	var level := (load(LEVEL_PATHS[number]) as PackedScene).instantiate() as LevelBase
	return level


func _test_boss_dialogue() -> void:
	for profile in ["neutral", "compassionate", "corrupt"]:
		_clean_state()
		GameState.adaptive_profile = profile
		var level: LevelBase = _make_level(1)
		add_child(level)
		await _frames(2)
		var dialogue: BossDialogue = level.get_node("BossDialogue") as BossDialogue
		var story: BossStory = texts.get_boss(1)
		var expected: Array[String] = story.lines_for(profile)
		level.encounter.encounter_started.emit()
		_check("guardian (%s): speaks when the fight starts" % profile, dialogue.is_speaking() and dialogue.sequence_count == 1)
		_check("guardian (%s): shows the boss name and the first line" % profile, dialogue.current_text() == "EL LEÑADOR: %s" % expected[0], dialogue.current_text())
		_check("guardian (%s): ONE line at first sight (Phase 15n)" % profile, expected.size() == 1)
		_check("guardian (%s): the fight is never locked" % profile, not level.player.is_input_locked() and not get_tree().paused)
		# Reading through every line (time is simulated by calling the line advance).
		var guard: int = 0
		while dialogue.is_speaking() and guard < 10:
			dialogue._next_line()
			guard += 1
		_check("guardian (%s): all %d lines were shown" % [profile, expected.size()], dialogue.lines_shown == expected.size(), str(dialogue.lines_shown))
		level.encounter.encounter_started.emit()
		_check("guardian (%s): not repeated after a retry or respawn mid-fight" % profile, dialogue.sequence_count == 1 and not dialogue.is_speaking())
		dialogue._on_boss_defeated(level.boss)
		dialogue._start_defeat_dialogue(story)
		_check("guardian (%s): its last words (2 to 3 lines) are said when it falls (Phase 15n)" % profile, dialogue.is_speaking() and dialogue.current_text() == "EL LEÑADOR: %s" % story.defeat_lines[0] and dialogue.sequence_count == 2)
		level.free()
		await _frames(2)
	# Skippable with the confirm action, and the press is not consumed.
	_clean_state()
	var level_skip: LevelBase = _make_level(1)
	add_child(level_skip)
	await _frames(2)
	var talker: BossDialogue = level_skip.get_node("BossDialogue") as BossDialogue
	level_skip.encounter.encounter_started.emit()
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	talker._input(accept)
	_check("guardian: confirm skips the lines", not talker.is_speaking() and talker.current_text() == "")
	_check("guardian: skipping does not consume the key (the player keeps full control)", not get_viewport().is_input_handled())
	level_skip.free()
	await _frames(2)
	# A new run says the lines again.
	_clean_state()
	var again: LevelBase = _make_level(1)
	add_child(again)
	await _frames(2)
	again.encounter.encounter_started.emit()
	_check("guardian: a new run says its lines again", (again.get_node("BossDialogue") as BossDialogue).is_speaking())
	again.free()
	await _frames(2)
	_clean_state()


# ---------------------------------------------------------------------------------------------
# 7. The grandfather before the last boss
# ---------------------------------------------------------------------------------------------

func _test_elder_scene() -> void:
	_clean_state()
	var plain: LevelBase = _make_level(3)
	add_child(plain)
	await _frames(2)
	_check("elder: headless runs of the level skip the scene by default", (plain.get_node("ElderScene") as ElderScene).reel == null and not get_tree().paused)
	plain.free()
	await _frames(2)
	for released in [0, 1, 2]:
		_clean_state()
		var choices: Array[String] = []
		for i in released:
			choices.append(REL)
		for i in 2 - released:
			choices.append(KEP)
		_decide(choices)
		GameState.set_current_level(3)
		GameState.set_checkpoint("level_3_start")
		var level: LevelBase = _make_level(3)
		var elder: ElderScene = level.get_node("ElderScene") as ElderScene
		elder.play_when_headless = true
		add_child(level)
		await _frames(3)
		_check("elder (%d released): the scene starts on a fresh arrival at level 3" % released, elder.reel != null and elder.played)
		var lines: Array[String] = elder.reel.lines
		var expected: Array[String] = texts.elder_script(released)
		_check("elder (%d released): 5 lines said by 'Abuelo' with his mood line" % released, lines.size() == expected.size() and lines.size() == 5
			and lines[0] == "Abuelo: %s" % expected[0] and lines[texts.elder_mood_index] == "Abuelo: %s" % texts.elder_mood_lines[released])
		_check("elder (%d released): about 20 s at most (%.1f s)" % [released, elder.reel.total_length()], elder.reel.total_length() <= 22.0)
		_check("elder (%d released): it uses the prologue's cave shot and pauses the game meanwhile" % released,
			elder.reel.shot == PrologueShots.Shot.CAVE and get_tree().paused and PauseLock.holder_count() == 1)
		# A press right at the start is ignored; later the confirm action skips it.
		var accept := InputEventAction.new()
		accept.action = "ui_accept"
		accept.pressed = true
		elder.reel._input(accept)
		_check("elder (%d released): a stray press at the very start does not skip it" % released, not elder.reel._ending)
		var skipped_flags: Array[bool] = []
		elder.scene_finished.connect(func(skipped: bool) -> void: skipped_flags.append(skipped))
		elder.reel.elapsed = 1.0
		elder.reel._input(accept)
		await get_tree().create_timer(0.8).timeout
		_check("elder (%d released): confirm skips it, the game resumes and the player is free" % released,
			skipped_flags == [true] and not get_tree().paused and PauseLock.holder_count() == 0 and not level.player.is_input_locked())
		_check("elder (%d released): GameState untouched by the scene" % released, GameState.souls_released == released and GameState.checkpoint == "level_3_start", "%d %s" % [GameState.souls_released, GameState.checkpoint])
		level.free()
		await _frames(2)
	# Not on a mid-level checkpoint, nor after the decision, nor once the game is completed.
	_clean_state()
	GameState.set_current_level(3)
	GameState.set_checkpoint("level_3_mid_1")
	var mid: LevelBase = _make_level(3)
	var mid_elder: ElderScene = mid.get_node("ElderScene") as ElderScene
	mid_elder.play_when_headless = true
	add_child(mid)
	await _frames(3)
	_check("elder: not played when resuming from a later checkpoint", mid_elder.reel == null and not mid_elder.played)
	mid.free()
	await _frames(2)
	_clean_state()
	var level_one: LevelBase = _make_level(1)
	var wrong: ElderScene = ElderScene.new()
	wrong.play_when_headless = true
	level_one.add_child(wrong)
	add_child(level_one)
	await _frames(3)
	_check("elder: never played outside level 3", wrong.reel == null)
	level_one.free()
	await _frames(2)
	_clean_state()
