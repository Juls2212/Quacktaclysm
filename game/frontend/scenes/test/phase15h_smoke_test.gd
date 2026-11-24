extends Node
## Smoke test for Phase 15h: the two endings, «Estrellas que suben» (kept) and «El acantilado» (released). The selection rule by the
## majority of the three decisions, the reel advanced only with the confirm action, the scenes drawn by code (and static in reduced mode),
## the sensitive handling of the released ending (no method, no romanticizing, the grandfather's regret, the support line, the content
## notice) and the six epilogues. Development only.
## Run (alone, a few minutes): <godot> --headless --path game res://frontend/scenes/test/phase15h_smoke_test.tscn
## Uses a redirected save path and a throwaway settings file; the real save, settings and controls are never touched. Times are real time.

const TEST_SAVE: String = "user://test_save_phase15h.json"
const TEST_SETTINGS: String = "user://test_settings_phase15h.cfg"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const ENDING_SCENE: PackedScene = preload("res://frontend/ui/ending.tscn")
const PANEL_SCENE: PackedScene = preload("res://frontend/ui/decision_panel.tscn")
const FRAGMENT_SCENE: PackedScene = preload("res://backend/decisions/soul_fragment.tscn")
const FRAGMENTS: Array[SoulFragmentData] = [
	preload("res://backend/decisions/data/fragment_level_1.tres"),
	preload("res://backend/decisions/data/fragment_level_2.tres"),
	preload("res://backend/decisions/data/fragment_level_3.tres"),
]
const KEPT: String = "ending_kept"
const RELEASED: String = "ending_released"
const SUPPORT_LINE: String = "Si tú o alguien que conoces está pasando por algo así, habla con alguien de confianza o con un servicio de salud mental de tu país. No estás solo."

var failures: int = 0
var real_save_before: String = ""
var real_settings_before: String = ""
var real_controls_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig
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


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _until(condition: Callable, max_seconds: float = 8.0) -> bool:
	var waited: float = 0.0
	while waited < max_seconds:
		if condition.call():
			return true
		await get_tree().process_frame
		waited += get_process_delta_time()
	return condition.call()


func _clean_state() -> void:
	Engine.time_scale = 1.0
	PauseLock.reset(get_tree())
	get_tree().paused = false
	InputMap.load_from_project_settings()
	for action in [&"ui_accept"]:
		Input.action_release(action)
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.director.clear_overrides()
	GameState.autosave_enabled = false
	AbilityCard.forget_all()
	BossDialogue.forget_all()
	GameSettings.save_settings(GameSettings.DEFAULTS.duplicate())


func _run() -> void:
	_clean_state()
	_test_guards()
	await _test_selection_rule()
	await _test_released_and_kept_texts()
	await _test_manual_advance(KEPT)
	await _test_manual_advance(RELEASED)
	await _test_hold_skip_remap_and_pause()
	await _test_final_card_and_notice()
	await _test_epilogues()
	await _test_new_game_and_leaks()
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

## Decides the three fragments through the real DecisionFlow (the level-3 flow included).
func _decide(choices: Array) -> void:
	var panel := PANEL_SCENE.instantiate() as DecisionPanel
	add_child(panel)
	var flow := DecisionFlow.new()
	flow.panel = panel
	add_child(flow)
	for i in choices.size():
		var fragment := FRAGMENT_SCENE.instantiate() as SoulFragment
		fragment.data = FRAGMENTS[i]
		add_child(fragment)
		flow._on_fragment_collected(fragment)
		(panel.release_button if choices[i] == GameState.CHOICE_RELEASED else panel.keep_button).pressed.emit()
	panel.free()
	flow.free()


func _ending(headless_card: bool = true) -> EndingController:
	var ending := ENDING_SCENE.instantiate() as EndingController
	ending.skip_reel_when_headless = headless_card
	add_child(ending)
	await _frames(3)
	return ending


func _accept() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	return event


func _plain_padded(text: String) -> String:
	var plain: String = GrandfatherLineValidator.plain(text)
	var letters: String = ""
	for i in plain.length():
		var character: String = plain[i]
		letters += character if (character >= "a" and character <= "z") else " "
	return " " + " ".join(letters.split(" ", false)) + " "


func _contains_term(text: String, term: String) -> bool:
	return _plain_padded(text).contains(" " + _plain_padded(term).strip_edges() + " ")


# ---------------------------------------------------------------------------------------------
# Part A: the selection rule
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


func _test_selection_rule() -> void:
	var table: Array = [[0, 3, RELEASED], [1, 2, RELEASED], [2, 1, KEPT], [3, 0, KEPT]]
	for entry in table:
		_check("rule: %d kept / %d released -> %s" % [entry[0], entry[1], entry[2]], EndingSelector.ending_id_for(entry[1], entry[0]) == entry[2])
	_check("rule: the edge case of no decision (0 / 0) is the released ending", EndingSelector.ending_id_for(0, 0) == RELEASED)
	_check("rule: a tie goes to the released ending", EndingSelector.ending_id_for(1, 1) == RELEASED)
	# Through the real flow and the real scene, for every combination of the three decisions.
	var rel: String = GameState.CHOICE_RELEASED
	var kep: String = GameState.CHOICE_KEPT
	var all_ok: bool = true
	for mask in 8:
		var choices: Array[String] = []
		var kept: int = 0
		for i in 3:
			var released_here: bool = (mask >> i) & 1 == 1
			choices.append(rel if released_here else kep)
			kept += 0 if released_here else 1
		_clean_state()
		_decide(choices)
		var ending: EndingController = await _ending()
		var expected: String = KEPT if kept > 3 - kept else RELEASED
		all_ok = all_ok and ending.shown_variant == expected and ending.title_label.text == texts.get_ending(expected).title and GameState.souls_kept == kept
		ending.free()
		await _frames(2)
	_check("rule: all 8 combinations of the three decisions through the real decision flow play the right ending", all_ok)
	# From a loaded save at the ending checkpoint.
	_clean_state()
	_decide([kep, kep, rel])
	GameState.set_current_level(3)
	GameState.set_checkpoint(GameState.CHECKPOINT_ENDING)
	var snapshot: Dictionary = GameState.to_dict()
	GameState.start_new_game()
	var loaded: Dictionary = GameState.load_from_dict(snapshot)
	var from_disk: EndingController = await _ending()
	_check("rule: a game loaded at the ending checkpoint plays the right ending (kept)", loaded["ok"] and GameState.checkpoint == GameState.CHECKPOINT_ENDING and from_disk.shown_variant == KEPT)
	from_disk.free()
	await _frames(2)
	# The old four endings are gone.
	var gone: bool = texts.endings.size() == 2
	for old_id in ["ending_full", "ending_scar", "ending_doubt", "ending_corrupt"]:
		gone = gone and texts.get_ending(old_id) == null
	_check("rule: there are exactly two endings; the old four and their texts are gone", gone and texts.get_ending(KEPT).title == "ESTRELLAS QUE SUBEN" and texts.get_ending(RELEASED).title == "EL ACANTILADO")


# ---------------------------------------------------------------------------------------------
# Texts: both endings and the sensitive handling
# ---------------------------------------------------------------------------------------------

func _test_released_and_kept_texts() -> void:
	var kept: EndingStory = texts.get_ending(KEPT)
	var released: EndingStory = texts.get_ending(RELEASED)
	_check("kept: 7 to 9 lines (Phase 15i-bis) and the last one is the grandfather's «Se ha sellado la profecía.» (Phase 15t)", kept.lines.size() >= 7 and kept.lines.size() <= 9 and kept.lines[kept.lines.size() - 1] == "Abuelo: Se ha sellado la profecía.")
	_check("released: 5 to 8 lines and the grandfather says «Bien hecho, nieto.»", released.lines.size() >= 5 and released.lines.size() <= 8 and released.lines.has("Abuelo: Bien hecho, nieto."))
	var words: String = " ".join(released.lines)
	_check("released: the duck realizes it only served for that moment and does not know who it is without the mission", words.contains("Eso era todo") and words.contains("No sé quién soy sin ella"))
	_check("released: the duck's regrets are in its lines (things never said or lived) and it is never the only outcome shown", words.contains("Nunca te dije que tenía miedo") and words.contains("Me arrepiento de no haber pedido ayuda"))
	_check("released: the last spoken line is exactly «Abuelo: Se ha sellado la profecía.» (Phase 15i-bis)", released.lines[released.lines.size() - 1] == "Abuelo: Se ha sellado la profecía.")
	_check("the names are editable: titles and styles are in the resource", kept.style == "kept" and released.style == "released" and not kept.title.is_empty() and not released.title.is_empty())
	# Banned lists: no method, no romanticizing.
	_check("sensitive: the banned lists exist in the resource (methods %d, romanticizing %d)" % [texts.ending_banned_terms.size(), texts.ending_romanticizing_terms.size()], texts.ending_banned_terms.size() >= 15 and texts.ending_romanticizing_terms.size() >= 15)
	var everything: Array[String] = []
	everything.append_array(released.lines)
	everything.append_array(released.epilogues)
	everything.append(released.summary_line)
	everything.append(released.support_line)
	var method_hit: String = ""
	var romantic_hit: String = ""
	for text in everything:
		for term in texts.ending_banned_terms:
			if _contains_term(text, term):
				method_hit = "%s in «%s»" % [term, text]
		for term in texts.ending_romanticizing_terms:
			if _contains_term(text, term):
				romantic_hit = "%s in «%s»" % [term, text]
	_check("sensitive: no text of the released ending names or describes a method (jumping, falling, hanging, weapons, pills...)", method_hit.is_empty(), method_hit)
	_check("sensitive: nothing presents it as a solution, a rest, a reunion or something heroic or beautiful (rest, peace, reunite, star, hero...)", romantic_hit.is_empty(), romantic_hit)
	# The check really works: the lists catch bad sentences.
	_check("sensitive: the lists catch a method and a romanticized sentence (sanity of the test)", _contains_term("Quiero saltar desde allí.", "saltar") and _contains_term("Por fin voy a descansar en paz.", "descansar")
		and texts.ending_banned_terms.has("saltar") and texts.ending_romanticizing_terms.has("descansar") and texts.ending_romanticizing_terms.has("reunirme"))
	var regret_ok: bool = true
	for epilogue in released.epilogues:
		regret_ok = regret_ok and epilogue.begins_with("Abuelo:") and epilogue.contains("nieto") and (epilogue.contains("Perdóname") or epilogue.contains("Nunca debiste") or epilogue.contains("Pregunta siempre") or epilogue.contains("nadie debería") or epilogue.contains("Nadie debería"))
	_check("sensitive: the three epilogues of the cliff ending are neutral lines about the world (no grandfather, no regret, no consolation)", released.epilogues.size() == 3 and not " ".join(released.epilogues).contains("Abuelo") and not " ".join(released.epilogues).contains("Perdóname"))
	_check("sensitive: both endings have the support line (Phase 15i-bis)", released.support_line == SUPPORT_LINE and kept.support_line == SUPPORT_LINE and not released.support_line.contains("0") and not released.support_line.contains("1"))
	_check("sensitive: the support line has no phone number", not _has_digit(released.support_line))


func _has_digit(text: String) -> bool:
	for i in text.length():
		if text[i] >= "0" and text[i] <= "9":
			return true
	return false


# ---------------------------------------------------------------------------------------------
# Part E: the reel advanced only with the confirm action
# ---------------------------------------------------------------------------------------------

func _test_manual_advance(ending_id: String) -> void:
	_clean_state()
	var kept_count: int = 3 if ending_id == KEPT else 0
	_decide([GameState.CHOICE_KEPT, GameState.CHOICE_KEPT, GameState.CHOICE_KEPT] if kept_count == 3 else [GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED])
	var ending: EndingController = await _ending(false)
	var reel: EndingCinematic = ending.reel
	var story: EndingStory = texts.get_ending(ending_id)
	_check("%s: the scene plays the reel (manual advance, hold to skip) and the card waits" % ending_id, reel != null and is_equal_approx(reel.hold_seconds, 1.2) and not ending.card_visible and reel.lines.size() == story.lines.size())
	Engine.time_scale = 20.0
	await _until(func() -> bool: return reel.line_index >= 0, 20.0)
	Engine.time_scale = 1.0
	_check("%s: the first line appears and is being typed" % ending_id, reel.line_index == 0 and not reel.typed_done and reel._subtitle.visible_characters < reel._subtitle.text.length())
	await _wait(0.6)
	var first_text: String = reel.current_line_text()
	reel._input(_accept())
	_check("%s: the first press completes the line (it stays on it)" % ending_id, reel.typed_done and reel.line_index == 0 and reel.current_line_text() == first_text and reel._subtitle.visible_characters == -1)
	_check("%s: the prompt «%s» shows" % [ending_id, reel._prompt.text], reel._prompt.visible and reel._prompt.text.ends_with("▸"))
	# NO timer advances anything.
	Engine.time_scale = 8.0
	var waited: float = 0.0
	var frames: int = 0
	while waited < 90.0 and frames < 4000:
		await get_tree().process_frame
		waited += get_process_delta_time()
		frames += 1
	Engine.time_scale = 1.0
	_check("%s: a long time later it is still on the same line (%d frames of game time at x8) and the card has not appeared" % [ending_id, frames], reel.line_index == 0 and reel.current_line_text() == first_text and not ending.card_visible and reel.typed_done and not reel._ending)
	# Enter advances line by line: two presses per line (complete, then next beat); the timed beats between lines run by themselves.
	var seen: Array[String] = [first_text]
	Engine.time_scale = 20.0
	var guard_loops: int = 0
	while seen.size() < story.lines.size() and guard_loops < 400:
		guard_loops += 1
		if reel.typed_done:
			reel._input(_accept())
		elif reel.current_line_text() == seen[seen.size() - 1] and reel.line_index >= 0 and not reel.typed_done:
			reel._input(_accept())
		await get_tree().process_frame
		if not reel.current_line_text().is_empty() and reel.current_line_text() != seen[seen.size() - 1]:
			seen.append(reel.current_line_text())
	Engine.time_scale = 1.0
	_check("%s: every one of the %d lines was reached with presses only, in order (%d seen)" % [ending_id, story.lines.size(), seen.size()], seen == story.lines)
	reel._input(_accept())
	reel._input(_accept())
	Engine.time_scale = 20.0
	# Phase 15t: after the last line come the credits and the animated statistics (about 100 game seconds), then the final card.
	await _until(func() -> bool: return ending.card_visible, 240.0)
	Engine.time_scale = 1.0
	_check("%s: after the last line the ending closes by itself and the final card appears" % ending_id, ending.card_visible)
	ending.free()
	await _frames(2)


func _test_hold_skip_remap_and_pause() -> void:
	# Holding the confirm action skips the whole scene.
	_clean_state()
	_decide([GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED])
	var ending: EndingController = await _ending(false)
	var reel: EndingCinematic = ending.reel
	var hold_needed: float = reel.hold_seconds
	await _until(func() -> bool: return reel.line_index >= 0, 20.0)
	Input.action_press(&"ui_accept")
	var held: float = 0.0
	while not ending.card_visible and held < 8.0:
		await get_tree().process_frame
		held += get_process_delta_time()
	Input.action_release(&"ui_accept")
	_check("skip: holding the confirm action (about %.1f s) skips the scene and the card appears (%.2f s held)" % [hold_needed, held], ending.card_visible and held >= hold_needed - 0.2)
	ending.free()
	await _frames(2)
	# A remapped confirm action: only the new key advances.
	_clean_state()
	_decide([GameState.CHOICE_KEPT, GameState.CHOICE_KEPT, GameState.CHOICE_KEPT])
	var remapped: EndingController = await _ending(false)
	var remap_reel: EndingCinematic = remapped.reel
	Engine.time_scale = 20.0
	await _until(func() -> bool: return remap_reel.line_index >= 0, 20.0)
	Engine.time_scale = 1.0
	await _wait(0.6)
	InputMap.action_erase_events(&"ui_accept")
	var other := InputEventKey.new()
	other.physical_keycode = KEY_J
	other.keycode = KEY_J
	InputMap.action_add_event(&"ui_accept", other)
	var old_key := InputEventKey.new()
	old_key.physical_keycode = KEY_ENTER
	old_key.keycode = KEY_ENTER
	old_key.pressed = true
	remap_reel._input(old_key)
	var untouched: bool = not remap_reel.typed_done
	var new_key := InputEventKey.new()
	new_key.physical_keycode = KEY_J
	new_key.keycode = KEY_J
	new_key.pressed = true
	remap_reel._input(new_key)
	_check("remap: the old key does nothing once the action is remapped and the new key completes the line (prompt names %s)" % BossDialogue.confirm_key_name(), untouched and remap_reel.typed_done and BossDialogue.confirm_key_name() == "J")
	var beat_before: int = remap_reel.beat_index
	remap_reel._input(new_key)
	_check("remap: and the second press moves on to the next beat", remap_reel.beat_index == beat_before + 1)
	InputMap.load_from_project_settings()
	# Pause: nothing types or advances while the tree is paused.
	var line_before: int = remap_reel.beat_index
	var typed_before: int = remap_reel._subtitle.visible_characters
	var time_before: float = remap_reel.elapsed
	get_tree().paused = true
	await get_tree().create_timer(0.6, true).timeout
	var frozen: bool = remap_reel.beat_index == line_before and is_equal_approx(remap_reel.elapsed, time_before) and remap_reel._subtitle.visible_characters == typed_before
	get_tree().paused = false
	await _wait(0.3)
	_check("pause: the pause freezes the scene and it goes on afterwards", frozen and remap_reel.elapsed > time_before)
	remapped.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# Final card, support line and content notice
# ---------------------------------------------------------------------------------------------

func _test_final_card_and_notice() -> void:
	_clean_state()
	_decide([GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED, GameState.CHOICE_KEPT])
	var released: EndingController = await _ending()
	_check("card: the released ending shows the support line under the epilogue (%s)" % released.support_label.text.left(40), released.shown_variant == RELEASED and released.support_label.visible and released.support_label.text == SUPPORT_LINE)
	_check("card: the epilogue of the released ending is on the card", released.epilogue_label.visible and released.epilogue_label.text == texts.epilogue_text(RELEASED, 0))
	released.free()
	await _frames(2)
	_clean_state()
	_decide([GameState.CHOICE_KEPT, GameState.CHOICE_KEPT, GameState.CHOICE_RELEASED])
	var kept: EndingController = await _ending()
	_check("card: the kept ending shows its epilogue and the support line too (Phase 15i-bis)", kept.shown_variant == KEPT and kept.epilogue_label.visible and kept.support_label.visible and kept.support_label.text == SUPPORT_LINE)
	kept.free()
	await _frames(2)
	# The content notice in the credits («Acerca de»).
	_clean_state()
	var notice: String = texts.content_notice
	_check("notice: the content notice exists and speaks of loss, grief and death, with suicide implicit in one ending", notice.contains("pérdida") and notice.contains("duelo") and notice.contains("muerte") and notice.contains("suicidio") and notice.contains("implícita"))
	var menu := (load("res://frontend/ui/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await _frames(4)
	var credits_label := menu.get("credits_label") as Label
	_check("notice: the credits screen of the main menu shows it (a label, not a pop-up)", credits_label != null and credits_label.text.contains(notice))
	menu.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# Part F: the six epilogues
# ---------------------------------------------------------------------------------------------

func _test_epilogues() -> void:
	var count: int = 0
	var seen: Dictionary = {}
	var unique: bool = true
	var short_enough: bool = true
	for ending_id in [KEPT, RELEASED]:
		for variant in 3:
			var text: String = texts.epilogue_text(ending_id, variant)
			count += 1 if not text.is_empty() else 0
			unique = unique and not seen.has(text)
			seen[text] = true
			short_enough = short_enough and text.length() <= 140
	_check("epilogues: 6 texts (2 endings x 3 variants), none empty, none repeated, each short", count == 6 and unique and short_enough)
	var combos: int = 0
	var same_ending: bool = true
	var right_text: bool = true
	for released_count in [0, 1, 2, 3]:
		for variant in 3:
			_clean_state()
			var choices: Array[String] = []
			for i in 3:
				choices.append(GameState.CHOICE_RELEASED if i < released_count else GameState.CHOICE_KEPT)
			_decide(choices)
			GameState.director.set_forced_plan({"theme": "calma", "epilogue_variant": variant})
			var ending: EndingController = await _ending()
			var expected: String = RELEASED if released_count >= 3 - released_count else KEPT
			same_ending = same_ending and ending.shown_variant == expected
			right_text = right_text and ending.shown_epilogue == texts.epilogue_text(expected, variant) and ending.shown_epilogue_variant == variant and ending.epilogue_label.text == ending.shown_epilogue
			combos += 1
			ending.free()
			await _frames(2)
	_check("epilogues: the ending never depends on the variant (%d combinations of kept/released x variant)" % combos, same_ending and combos == 12)
	_check("epilogues: the card shows the text of the plan variant for the right ending", right_text)
	_clean_state()
	_decide([GameState.CHOICE_KEPT, GameState.CHOICE_KEPT, GameState.CHOICE_RELEASED])
	_check("epilogues: continuing from disk (no telemetry) uses variant 0", GameState.director.epilogue_variant() == 0)
	_clean_state()
	GameState.director.telemetry.add(3, "time_in_level", 150.0)
	var comfortable: int = GameState.director.epilogue_variant()
	_clean_state()
	GameState.director.telemetry.add(3, "deaths", 6.0)
	GameState.director.telemetry.add(3, "damage_taken", 20.0)
	_check("epilogues: a comfortable level 3 gives variant 1 and a struggling one variant 2 (local plan, as in Phase 16c)", comfortable == 1 and GameState.director.epilogue_variant() == 2)
	var payload_client := DirectorClient.new()
	var decisions_payload: Dictionary = payload_client.build_payload(3, 4, PackedStringArray())
	payload_client.free()
	_check("epilogues: the request for the ending is next_level 4 with no pattern ids (prefetched at the level-3 decision)", decisions_payload["next_level"] == 4 and (decisions_payload["allowed_pattern_ids"] as Array).is_empty())


# ---------------------------------------------------------------------------------------------
# New game and leaks
# ---------------------------------------------------------------------------------------------

func _test_new_game_and_leaks() -> void:
	_clean_state()
	_decide([GameState.CHOICE_KEPT, GameState.CHOICE_KEPT, GameState.CHOICE_KEPT])
	GameState.set_current_level(3)
	GameState.set_checkpoint(GameState.CHECKPOINT_ENDING)
	_check("new game: after an ending the game is marked completed", GameState.is_game_completed())
	GameState.start_new_game()
	_check("new game: a new game after an ending resets everything (no decisions, 0 / 0, first level, start checkpoint)", not GameState.is_game_completed() and GameState.decisions.is_empty() and GameState.souls_kept == 0 and GameState.souls_released == 0
		and GameState.current_level == 1 and GameState.checkpoint == GameState.DEFAULT_CHECKPOINT and GameState.director.epilogue_variant() == 0)
	var counts: Array[int] = []
	for round in 4:
		_clean_state()
		_decide([GameState.CHOICE_KEPT, GameState.CHOICE_KEPT, GameState.CHOICE_KEPT] if round % 2 == 0 else [GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED])
		var ending: EndingController = await _ending(false)
		await _until(func() -> bool: return ending.reel != null and ending.reel.line_index >= 0, 20.0)
		ending.reel.skip()
		await _until(func() -> bool: return ending.card_visible, 5.0)
		ending.free()
		await _frames(3)
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	print("MEASURE|node counts after replaying both endings|%s" % str(counts))
	_check("leaks: no nodes are left behind after replaying both endings (%s) and nothing is paused" % str(counts), counts[3] <= counts[1] + 4 and not get_tree().paused and not PauseLock.is_locked())
