extends Node
## Smoke test for Phase 16c: the player-visible Director. The grandfather line (validator, local bank, remote line, where and when it
## shows), the sky reflection (blurred vs sharp, reduced mode, fades, sky area, layer) and the epilogues (12 texts, chosen by the plan
## variant, the ending itself never changes). NO network: the DirectorClient transport is faked. Development only.
## Run (alone, a minute or two): <godot> --headless --path game res://frontend/scenes/test/phase16c_smoke_test.tscn
## Uses a redirected save path and a throwaway settings file. Times are real game time.

const TEST_SAVE: String = "user://test_save_phase16c.json"
const TEST_SETTINGS: String = "user://test_settings_phase16c.cfg"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const LEVELS: Dictionary = {
	1: "res://frontend/levels/level_1.tscn",
	2: "res://frontend/levels/level_2.tscn",
	3: "res://frontend/levels/level_3.tscn",
}
const ENDING_SCENE: PackedScene = preload("res://frontend/ui/ending.tscn")
const BIOME_DIR: String = "res://frontend/levels/biome/"
const GOOD_LINE: String = "Respira, nieto. La cabeza fría esquiva lo que la prisa no ve."
const MIN_CONTRAST: float = 2.5

var failures: int = 0
var real_save_before: String = ""
var real_settings_before: String = ""
var real_controls_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig
var config: TelemetryConfig = TelemetryConfig.get_default()
var lines: GrandfatherLines = GrandfatherLines.get_default()
var presentation: GrandfatherPresentation = GrandfatherPresentation.get_default()
var texts: StoryTexts = StoryTexts.get_default()

var sent: Array[Dictionary] = []
var mode: String = "ok"
var reply: Variant = {}
var shown_lines_seen: Array[String] = []


func _ready() -> void:
	ai_config.enabled = true
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


## Waits (real time) until the condition holds or `max_seconds` passed. Returns whether it held.
func _until(condition: Callable, max_seconds: float = 4.0) -> bool:
	var waited: float = 0.0
	while waited < max_seconds:
		if condition.call():
			return true
		await get_tree().process_frame
		waited += get_process_delta_time()
	return condition.call()


func _transport(_request_id: int, url: String, _headers: PackedStringArray, body: String, on_done: Callable) -> void:
	sent.append({"url": url, "body": body})
	match mode:
		"ok":
			on_done.call({"result": HTTPRequest.RESULT_SUCCESS, "code": 200, "body": JSON.stringify(reply).to_utf8_buffer()})
		"timeout":
			on_done.call({"result": HTTPRequest.RESULT_TIMEOUT, "code": 0, "body": PackedByteArray()})
		"offline":
			on_done.call({"result": HTTPRequest.RESULT_CANT_CONNECT, "code": 0, "body": PackedByteArray()})


func _clean_state() -> void:
	Engine.time_scale = 1.0
	PauseLock.reset(get_tree())
	get_tree().paused = false
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.director.clear_overrides()
	GameState.director.simulate_release = false
	GameState.director.clear_voice_memory()
	GameState.autosave_enabled = false
	AbilityCard.forget_all()
	BossDialogue.forget_all()
	GameSettings.save_settings(GameSettings.DEFAULTS.duplicate())
	sent.clear()
	mode = "ok"
	var client: DirectorClient = GameState.get_director_client()
	client.ai.cancel()
	client.ai.transport = _transport
	client.in_flight = false
	client.last_status = "idle"


func _run() -> void:
	GrandfatherVoice.play_when_headless = true
	_clean_state()
	_test_guards()
	_test_validator()
	_test_bank()
	_test_selector()
	await _test_remote_and_fallback_lines()
	await _test_when_and_where()
	await _test_reflection()
	_test_contrast()
	await _test_epilogues()
	await _test_no_leaks()
	_check("no statistics ever reached the screen: no digit and no metric word in any of the %d lines shown" % shown_lines_seen.size(), _no_statistics())
	GrandfatherVoice.play_when_headless = false
	_clean_state()
	SaveSystem.purge()
	ai_config.enabled = false
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

func _no_statistics() -> bool:
	var banned_words: PackedStringArray = ["deaths", "damage", "low", "mid", "high", "kills", "heals"]
	for line in shown_lines_seen:
		for i in line.length():
			if line[i] >= "0" and line[i] <= "9":
				return false
		var plain: String = " " + GrandfatherLineValidator.plain(line).replace(",", " ").replace(".", " ") + " "
		for word in banned_words:
			if plain.contains(" " + word + " "):
				return false
	return true


func _seed_level(level_number: int, metrics: Dictionary = {"time_in_level": 150, "kills": 6}) -> void:
	for metric: Variant in metrics.keys():
		GameState.director.telemetry.add(level_number, String(metric), float(metrics[metric]))


func _remote_reply(line: Variant, epilogue: int = 1, source: String = "openai") -> Dictionary:
	return {"theme": "calma", "extras_delta": 0, "boss_pattern_weights": {}, "epilogue_variant": epilogue, "grandfather_line": line, "source": source}


## Loads a level with the voice enabled and the intro shortened. The caller frees it.
func _load_level(level_number: int, profile: String = "neutral") -> LevelBase:
	GameState.set_adaptive_profile(profile)
	var level := (load(LEVELS[level_number]) as PackedScene).instantiate() as LevelBase
	add_child(level)
	await _frames(2)
	if level._intro_left > 0.3:
		level._intro_left = 0.3
	level.grandfather_voice.line_started.connect(func(text: String, _memory: bool) -> void: shown_lines_seen.append(text))
	return level


func _free_level(level: LevelBase) -> void:
	level.free()
	await _frames(3)


func _request_plan_for_level_two() -> String:
	var client: DirectorClient = GameState.get_director_client()
	var started: bool = client.request_plan(1)
	await _until(func() -> bool: return not client.in_flight, 2.0)
	return client.last_status if started else client.last_status


func _guard(level: LevelBase) -> GrandfatherVoice:
	return level.grandfather_voice


# ---------------------------------------------------------------------------------------------
# Guards
# ---------------------------------------------------------------------------------------------

func _test_guards() -> void:
	var keys: Array = GameState.to_dict().keys()
	keys.sort()
	var expected: Array = SAVE_KEYS.duplicate()
	expected.sort()
	_check("save: still exactly the seven keys (no line, no variant saved)", keys == expected, str(keys))
	var autoloads: PackedStringArray = PackedStringArray()
	for property in ProjectSettings.get_property_list():
		var property_name: String = property["name"]
		if property_name.begins_with("autoload/"):
			autoloads.append(property_name.trim_prefix("autoload/"))
	autoloads.sort()
	_check("autoloads: exactly GameState, SceneManager and AudioDirector", autoloads == PackedStringArray(["AudioDirector", "GameState", "SceneManager"]), str(autoloads))
	_check("audio: the voice sound is in the event table and reuses an existing file", AudioEvents.EVENT_IDS.has(&"grandfather_voice") and AudioEvents.get_default().get_event(&"grandfather_voice") != null
		and FileAccess.file_exists("res://frontend/audio/sfx/" + AudioEvents.get_default().get_event(&"grandfather_voice").files[0]))


# ---------------------------------------------------------------------------------------------
# 1 and 2. Validator and bank
# ---------------------------------------------------------------------------------------------

func _ok(value: Variant) -> bool:
	return bool(GrandfatherLineValidator.validate(value, lines)["ok"])


func _words(count: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for i in count:
		parts.append("alba")
	return " ".join(parts)


func _test_validator() -> void:
	_check("validator: a good line passes (and is trimmed)", _ok(GOOD_LINE) and GrandfatherLineValidator.validate("  " + GOOD_LINE + " ", lines)["line"] == GOOD_LINE)
	_check("validator: the word count must be 8 to 18 (7 and 19 fail, 8 and 18 pass)", not _ok(_words(7)) and _ok(_words(8)) and _ok(_words(18)) and not _ok(_words(19)))
	_check("validator: at most 110 characters", not _ok(GOOD_LINE + " " + "a".repeat(60)) and not _ok("a ".repeat(9) + "b".repeat(120)))
	_check("validator: no digits (statistics) at all", not _ok("Respira, nieto. Has caído 5 veces y la calma siempre vuelve."))
	_check("validator: no links or markup", not _ok("Mira http://calma.com y respira hondo, nieto, con calma ahora.") and not _ok("Visita www.calma.net y respira hondo, nieto, con calma ahora.")
		and not _ok("Respira, nieto. <b>La cabeza fría</b> esquiva lo que la prisa no ve.") and not _ok("Respira, nieto. [La cabeza fría] esquiva lo que la prisa no ve.")
		and not _ok("Respira, nieto. *La cabeza fría* esquiva lo que la prisa no ve.") and not _ok("Respira, nieto. La cabeza fría esquiva lo que la prisa no ve #calma"))
	_check("validator: no line breaks or tabs", not _ok("Respira, nieto." + char(10) + "La cabeza fría esquiva lo que la prisa no ve.") and not _ok("Respira, nieto." + char(9) + "La cabeza fría esquiva lo que la prisa no ve.")
		and not _ok("Respira, nieto." + char(13) + "La cabeza fría esquiva lo que la prisa no ve."))
	_check("validator: no emojis or symbols", not _ok("Respira, nieto. La cabeza fría esquiva lo que la prisa no ve 😀") and not _ok("Respira, nieto. La cabeza fría esquiva lo que la prisa no ve ★"))
	var reproach_ok: bool = true
	for sentence in ["Moriste, nieto, pero la cabeza fría esquiva lo que la prisa no ve.", "MURIÓ otra vez, nieto, pero la cabeza fría esquiva lo que la prisa no ve.", "Fallaste, nieto, pero la cabeza fría esquiva lo que la prisa no ve.",
			"Tantos errores, nieto, pero la cabeza fría esquiva lo que la prisa no ve.", "Eres débil, nieto, pero la cabeza fría esquiva lo que la prisa no ve.", "No esquivaste nada, nieto, pero la cabeza fría ayuda a ver.",
			"Ha sido un fracaso, nieto, pero la cabeza fría esquiva lo que la prisa no ve.", "La culpa no es tuya, nieto, pero la cabeza fría esquiva lo que la prisa no ve."]:
		reproach_ok = reproach_ok and not _ok(sentence)
	_check("validator: reproach words are banned (moriste, murió, fallaste, errores, débil, esquivaste, fracaso, culpa), with or without accents or capitals", reproach_ok)
	_check("validator: game mechanics are not named (doble salto, dash, jefe, nivel, guardia)", not _ok("Usa el doble salto con calma, nieto, y respira antes de cada decisión.") and not _ok("Con el dash llegarás lejos, nieto, si respiras antes de cada decisión.")
		and not _ok("Ese jefe también respira, nieto, y tú puedes aprender de su calma.") and not _ok("En cada nivel hay una calma esperando a quien sepa respirar, nieto."))
	_check("validator: only text is accepted (null, numbers, arrays, empty and blank fail)", not _ok(null) and not _ok(42) and not _ok([GOOD_LINE]) and not _ok({"a": GOOD_LINE}) and not _ok("") and not _ok("   "))
	_check("validator: accents, ñ, ¿¡ and « » are fine", _ok("¡Respira, nieto! La niebla pasa y el camino siempre vuelve a verse, «con calma»."))
	_check("validator: the rules come from the resource (8 to 18 words, 110 characters, at least 30 banned words)", lines.min_words == 8 and lines.max_words == 18 and lines.max_chars == 110 and lines.banned_words.size() >= 30)


func _test_bank() -> void:
	var themes: PackedStringArray = config.themes
	var every_theme: bool = themes.size() == 7
	var all_pass: bool = true
	var seen: Dictionary = {}
	var duplicates: bool = false
	var total: int = 0
	for theme in themes:
		var bank: Array = lines.lines_for(theme)
		every_theme = every_theme and bank.size() >= 3
		for line in bank:
			total += 1
			all_pass = all_pass and _ok(line)
			if not _ok(line):
				print("bank line fails: %s | %s" % [theme, line])
			duplicates = duplicates or seen.has(line)
			seen[line] = true
	_check("bank: the 7 themes have at least 3 lines each (%d lines)" % total, every_theme)
	_check("bank: every line passes the validator", all_pass)
	_check("bank: no line is repeated between themes", not duplicates)
	var memory_ok: bool = lines.memory_lines.size() >= 3
	for line in lines.memory_lines:
		memory_ok = memory_ok and _ok(line)
	_check("bank: the level-1 memory set has at least 3 lines and all pass (%d)" % lines.memory_lines.size(), memory_ok)
	var addressed: int = 0
	for theme in themes:
		for line in lines.lines_for(theme):
			addressed += 1 if String(line).contains("nieto") else 0
	_check("bank: the grandfather calls the duck nieto in most lines (%d of %d)" % [addressed, total], addressed * 2 > total)


func _test_selector() -> void:
	_clean_state()
	var decisions: Array = [{"fragment_id": "fragment_level_1", "boss_id": "x", "level": 1, "choice": "released"}]
	var first: Dictionary = GameState.director.choose_line(2, "calma", decisions)
	GameState.director.clear_voice_memory()
	var again: Dictionary = GameState.director.choose_line(2, "calma", decisions)
	_check("selector: the same theme, level and saved data start at the same line (deterministic)", first["text"] == again["text"] and first["source"] == "bank" and lines.lines_for("calma").has(first["text"]))
	GameState.director.clear_voice_memory()
	var picked: Array[String] = []
	for i in 4:
		picked.append(String(GameState.director.choose_line(2, "calma", decisions)["text"]))
	var unique: Dictionary = {}
	for line in picked:
		unique[line] = true
	_check("selector: no line repeats in a session while others of the theme remain (4 picks, %d different)" % unique.size(), unique.size() == 4)
	var fifth: String = String(GameState.director.choose_line(2, "calma", decisions)["text"])
	_check("selector: when the set is used up it starts over", picked.has(fifth) and not fifth.is_empty())
	GameState.record_decision("fragment_level_1", "boss_one", 1, GameState.CHOICE_RELEASED)
	var saved_decisions: Array = GameState.to_dict()["decisions"].duplicate(true)
	var seed_a: int = GrandfatherLineSelector.seed_for("valor", 3, GameState.decisions)
	var roundtrip: Array = saved_decisions
	decisions = saved_decisions
	_check("selector: the seed uses only data the save holds (stable after a save round trip)", GrandfatherLineSelector.seed_for("valor", 3, roundtrip) == GrandfatherLineSelector.seed_for("valor", 3, decisions) and seed_a == GrandfatherLineSelector.seed_for("valor", 3, decisions))
	var memory: Dictionary = GameState.director.choose_line(1, "calma", [])
	_check("selector: level 1 takes a remembered saying, whatever the theme", memory["source"] == "memory" and lines.memory_lines.has(memory["text"]))
	var unknown: Dictionary = GameState.director.choose_line(2, "venganza", [])
	_check("selector: an unknown theme still gives a bank line", unknown["source"] == "bank" and _ok(unknown["text"]))


# ---------------------------------------------------------------------------------------------
# 3. Remote line and fallbacks
# ---------------------------------------------------------------------------------------------

func _line_of_level_two(setup: Callable) -> Dictionary:
	_clean_state()
	_seed_level(1)
	await setup.call()
	var level: LevelBase = await _load_level(2)
	var voice: GrandfatherVoice = _guard(level)
	await _until(func() -> bool: return voice.shown_count > 0, 4.0)
	var result: Dictionary = {"text": voice.shown_text, "source": voice.shown_source, "memory": voice.shown_memory, "sent": sent.size()}
	await _free_level(level)
	return result


func _test_remote_and_fallback_lines() -> void:
	var good: Dictionary = await _line_of_level_two(func() -> void:
		reply = _remote_reply(GOOD_LINE)
		await _request_plan_for_level_two())
	_check("remote: a valid line from the service is shown (source %s)" % good["source"], good["source"] == "remote" and good["text"] == GOOD_LINE and good["sent"] == 1)
	var invalid_lines: Array = ["Moriste 5 veces, nieto, y la calma sigue esperando aquí.", "Corto.", "Respira, nieto." + char(10) + "Calma la cabeza y mira el camino otra vez con paz.", 42, ["x"]]
	var all_banked: bool = true
	for invalid in invalid_lines:
		var result: Dictionary = await _line_of_level_two(func() -> void:
			reply = _remote_reply(invalid)
			await _request_plan_for_level_two())
		all_banked = all_banked and result["source"] == "bank" and _ok(result["text"]) and result["text"] != str(invalid)
	_check("remote: an invalid line (digits, banned word, too short, line break, wrong type) is never shown: the bank line is", all_banked)
	var absent: Dictionary = await _line_of_level_two(func() -> void:
		reply = _remote_reply(null)
		await _request_plan_for_level_two())
	_check("remote: no line in the answer -> bank line", absent["source"] == "bank" and _ok(absent["text"]))
	var off: Dictionary = await _line_of_level_two(func() -> void:
		var values: Dictionary = GameSettings.DEFAULTS.duplicate()
		values["ai_adaptation"] = false
		GameSettings.save_settings(values)
		reply = _remote_reply(GOOD_LINE)
		await _request_plan_for_level_two())
	_check("fallback: with «Adaptación con IA» off nothing is sent and the bank line is shown", off["source"] == "bank" and off["sent"] == 0 and off["text"] != GOOD_LINE)
	for failure in ["offline", "timeout"]:
		var failed: Dictionary = await _line_of_level_two(func() -> void:
			mode = failure
			reply = _remote_reply(GOOD_LINE)
			await _request_plan_for_level_two())
		_check("fallback: %s -> bank line, nothing breaks" % failure, failed["source"] == "bank" and failed["text"] != GOOD_LINE)
	var mock: Dictionary = await _line_of_level_two(func() -> void:
		reply = _remote_reply(GOOD_LINE, 1, "mock")
		await _request_plan_for_level_two())
	_check("fallback: a service in mock mode gives no remote line -> bank line", mock["source"] == "bank" and mock["text"] != GOOD_LINE)
	var fallback_source: Dictionary = await _line_of_level_two(func() -> void:
		reply = _remote_reply(GOOD_LINE, 1, "fallback")
		await _request_plan_for_level_two())
	_check("fallback: a service in fallback mode gives no remote line -> bank line", fallback_source["source"] == "bank")
	# The remote line belongs to the plan: when the plan is not the remote one (a forced debug plan) the bank line is shown.
	var forced: Dictionary = await _line_of_level_two(func() -> void:
		reply = _remote_reply(GOOD_LINE)
		await _request_plan_for_level_two()
		GameState.director.set_forced_plan({"theme": "valor"}))
	_check("remote: a forced debug plan wins and its line is the bank one", forced["source"] == "bank")
	# A line already shown is not shown again in the session.
	_clean_state()
	_seed_level(1)
	reply = _remote_reply(GOOD_LINE)
	await _request_plan_for_level_two()
	GameState.director.shown_lines.append(GOOD_LINE)
	var repeat_level: LevelBase = await _load_level(2)
	await _until(func() -> bool: return _guard(repeat_level).shown_count > 0, 4.0)
	_check("remote: a remote line already shown in the session is replaced by a new bank line", _guard(repeat_level).shown_source == "bank" and _guard(repeat_level).shown_text != GOOD_LINE)
	await _free_level(repeat_level)


# ---------------------------------------------------------------------------------------------
# 4. When and where the line shows
# ---------------------------------------------------------------------------------------------

func _test_when_and_where() -> void:
	# Level 1: a remembered saying; level 2: a memory with the theme of the plan; level 3: direct voice.
	for entry in [[1, true, "memory"], [2, true, "bank"], [3, false, "bank"]]:
		_clean_state()
		_seed_level(1)
		_seed_level(2)
		var level: LevelBase = await _load_level(entry[0])
		var voice: GrandfatherVoice = _guard(level)
		var started: bool = await _until(func() -> bool: return voice.shown_count > 0, 4.0)
		var label: Label = null
		if voice.panel_layer != null:
			label = voice.panel_layer.find_children("*", "Label", true, false)[0] as Label if not voice.panel_layer.find_children("*", "Label", true, false).is_empty() else null
		var expected_prefix: String = "Recuerdas su voz" if entry[1] else "Abuelo:"
		_check("level %d: the line shows once the title and intro are gone (%s, %s)" % [entry[0], voice.shown_source, "memory style" if voice.shown_memory else "direct voice"],
			started and not level.is_intro_visible() and voice.shown_memory == entry[1] and voice.shown_source == entry[2] and label != null and label.text.begins_with(expected_prefix)
			and label.text.contains(voice.shown_text))
		var mood: String = String(texts.elder_speaker)
		_check("level %d: it shows the line as a memory (levels 1 and 2) or in his direct voice (level 3), distinct wording" % entry[0], (label.text.begins_with(presentation.memory_format.split("%s")[0])) == entry[1] and mood == "Abuelo")
		await _free_level(level)
	# Level 3: after his entry scene.
	_clean_state()
	_seed_level(2)
	var level_three: LevelBase = await _load_level(3)
	var elder: ElderScene = level_three.get_node("ElderScene") as ElderScene
	elder.played = true
	var voice_three: GrandfatherVoice = _guard(level_three)
	await _wait(1.6)
	_check("level 3: the line waits for his entry scene (nothing shown while it plays)", voice_three.shown_count == 0 and not voice_three.active)
	elder.scene_finished.emit(false)
	var after_scene: bool = await _until(func() -> bool: return voice_three.shown_count > 0, 4.0)
	_check("level 3: after the scene the line shows, as direct voice", after_scene and not voice_three.shown_memory)
	await _free_level(level_three)
	# Never during a fight, never at the arena checkpoint.
	_clean_state()
	_seed_level(1)
	var fight: LevelBase = await _load_level(2)
	fight.boss.activate(fight.player)
	await _wait(1.6)
	_check("never during a fight: with the boss awake no line is enqueued", _guard(fight).shown_count == 0 and not _guard(fight).active)
	await _free_level(fight)
	_clean_state()
	_seed_level(1)
	var probe: LevelBase = await _load_level(2)
	var arena_id: String = ""
	var arena_order: int = -1
	for checkpoint in probe.get_level_checkpoints():
		if checkpoint.order > arena_order:
			arena_order = checkpoint.order
			arena_id = String(checkpoint.checkpoint_id)
	await _free_level(probe)
	_clean_state()
	GameState.current_level = 2
	GameState.checkpoint = arena_id
	var arena: LevelBase = await _load_level(2)
	await _wait(1.6)
	_check("never at the arena checkpoint: a level continued from its arena shows no line", _guard(arena).shown_count == 0)
	await _free_level(arena)
	# It is dismissed the moment the encounter starts, and the queue is free for the boss intro.
	_clean_state()
	_seed_level(1)
	var encounter_level: LevelBase = await _load_level(2)
	var encounter_voice: GrandfatherVoice = _guard(encounter_level)
	await _until(func() -> bool: return encounter_voice.active, 4.0)
	var finished_flags: Array[bool] = []
	encounter_voice.line_finished.connect(func(skipped: bool) -> void: finished_flags.append(skipped))
	var queue: PresentationQueue = encounter_level.get_node("PresentationQueue") as PresentationQueue
	var order: Array[String] = []
	encounter_voice.line_finished.connect(func(_s: bool) -> void: order.append("line_finished"))
	queue.step_started.connect(func(id: String) -> void: order.append("start:" + id))
	queue.enqueue("ability_card_probe", func() -> Variant: return null)
	await _frames(2)
	_check("never over an ability card or the boss intro: a step queued while the line shows waits for it (order %s)" % str(order), not order.has("start:ability_card_probe") or order.find("line_finished") < order.find("start:ability_card_probe"))
	encounter_level.encounter.encounter_started.emit()
	await _frames(3)
	_check("the encounter starting dismisses the line at once and frees the queue", finished_flags.size() == 1 and not queue.is_busy() or (finished_flags.size() == 1 and order.has("start:ability_card_probe")))
	await _free_level(encounter_level)
	# Death dismisses it too; the confirm action skips it; it never locks the player.
	_clean_state()
	_seed_level(1)
	var skip_level: LevelBase = await _load_level(2)
	var skip_voice: GrandfatherVoice = _guard(skip_level)
	await _until(func() -> bool: return skip_voice.active, 4.0)
	var skipped_flags: Array[bool] = []
	skip_voice.line_finished.connect(func(skipped: bool) -> void: skipped_flags.append(skipped))
	_check("input: the line never locks the player's input (max lock %.1f s)" % presentation.max_input_lock, not skip_level.player.is_input_locked() and presentation.max_input_lock == 0.0)
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	skip_voice._unhandled_input(accept)
	await _frames(2)
	_check("skip: the confirm action dismisses the line (skipped = %s)" % str(skipped_flags), skipped_flags == [true])
	await _until(func() -> bool: return not skip_voice.active, 2.0)
	_check("skip: the panel is gone shortly after", not skip_voice.active and skip_voice.panel_layer == null)
	await _free_level(skip_level)
	# Auto-dismiss in the configured time (real game time).
	_clean_state()
	_seed_level(1)
	var timed: LevelBase = await _load_level(2)
	var timed_voice: GrandfatherVoice = _guard(timed)
	await _until(func() -> bool: return timed_voice.active, 4.0)
	var shown_at: int = Time.get_ticks_msec()
	var timed_flags: Array[bool] = []
	timed_voice.line_finished.connect(func(skipped: bool) -> void: timed_flags.append(skipped))
	await _until(func() -> bool: return not timed_flags.is_empty(), presentation.show_time + 2.0)
	var shown_for: float = float(Time.get_ticks_msec() - shown_at) / 1000.0
	_check("auto-dismiss: the line goes away by itself after about %.1f s (%.2f s measured)" % [presentation.show_time, shown_for], timed_flags == [false] and absf(shown_for - presentation.show_time) < 0.8)
	await _free_level(timed)
	# Once per level and session: a retry does not repeat it.
	_clean_state()
	_seed_level(1)
	var first: LevelBase = await _load_level(2)
	await _until(func() -> bool: return _guard(first).shown_count > 0, 4.0)
	await _free_level(first)
	var retry: LevelBase = await _load_level(2)
	await _wait(1.6)
	_check("retry: the line is not repeated when the level is loaded again in the same session", _guard(retry).shown_count == 0)
	await _free_level(retry)
	# The tutorial (level 0) has no voice and headless runs stay silent unless switched on.
	var tutorial := (load("res://frontend/levels/tutorial.tscn") as PackedScene).instantiate() as LevelBase
	add_child(tutorial)
	await _frames(3)
	_check("the tutorial has no grandfather voice", tutorial.grandfather_voice == null)
	await _free_level(tutorial)
	GrandfatherVoice.play_when_headless = false
	_clean_state()
	_seed_level(1)
	var quiet: LevelBase = await _load_level(2)
	await _wait(1.6)
	_check("headless: nothing is shown unless the switch is on", _guard(quiet).shown_count == 0)
	await _free_level(quiet)
	GrandfatherVoice.play_when_headless = true


# ---------------------------------------------------------------------------------------------
# 5. The reflection
# ---------------------------------------------------------------------------------------------

func _make_reflection(level_number: int, reduced: bool) -> GrandfatherFace:
	var reflection := GrandfatherFace.new()
	reflection.setup(presentation, level_number, reduced)
	return reflection


func _test_reflection() -> void:
	var blurred_one: GrandfatherFace = _make_reflection(1, false)
	var blurred_two: GrandfatherFace = _make_reflection(2, false)
	var sharp: GrandfatherFace = _make_reflection(3, false)
	_check("face (Phase 15n): levels 1 and 2 are a faded memory (opacity %.2f), level 3 is solid and sharp (%.2f)" % [presentation.face_memory_alpha, presentation.face_solid_alpha],
		not blurred_one.sharp and not blurred_two.sharp and sharp.sharp and is_equal_approx(blurred_one.target_alpha(), presentation.face_memory_alpha) and is_equal_approx(sharp.target_alpha(), presentation.face_solid_alpha)
		and sharp.target_alpha() > blurred_one.target_alpha() * 1.3)
	# It stays in the sky area, in several screen sizes.
	var inside: bool = true
	for screen in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(1024, 600), Vector2(1600, 900)]:
		var at: Vector2 = sharp.face_position(screen)
		inside = inside and at.x >= 0.0 and at.x <= screen.x and at.y >= 0.0 and at.y <= screen.y * presentation.sky_bottom_ratio + 0.5
	_check("face: it hangs inside the sky area (above %.0f%% of the screen height) on every screen size" % (presentation.sky_bottom_ratio * 100.0), inside)
	_check("face: its layer (%d) is above the sky (-6) and below the play field (0) and the UI" % sharp.layer, sharp.layer > -6 and sharp.layer < 0 and presentation.panel_layer > 0)
	# Reduced mode: a plain fade, a still portrait.
	var reduced: GrandfatherFace = _make_reflection(3, true)
	add_child(reduced)
	await _frames(3)
	_check("face (reduced): a still portrait and a plain fade (no glow pulse)", reduced.reduced and reduced.portrait != null and reduced.portrait.reduced)
	reduced.free()
	# Fades, in real game time.
	var fading: GrandfatherFace = _make_reflection(3, false)
	add_child(fading)
	var elapsed: float = 0.0
	var reached: float = -1.0
	var half_alpha_at: float = -1.0
	while elapsed < presentation.fade_in_time + 1.0 and reached < 0.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if half_alpha_at < 0.0 and fading.alpha >= fading.target_alpha() * 0.5:
			half_alpha_at = elapsed
		if fading.alpha >= fading.target_alpha() - 0.001:
			reached = elapsed
	_check("reflection: it fades in about %.1f s (%.2f s measured, half way at %.2f s) up to %.2f" % [presentation.fade_in_time, reached, half_alpha_at, fading.target_alpha()], reached > 0.0 and absf(reached - presentation.fade_in_time) < 0.25 and fading.alpha <= fading.target_alpha() + 0.001)
	await _wait(0.4)
	_check("reflection: it stays while the line is shown", is_equal_approx(fading.alpha, fading.target_alpha()) and fading.phase == GrandfatherFace.Phase.HOLD)
	var gone: Array[bool] = [false]
	fading.faded_out.connect(func() -> void: gone[0] = true)
	fading.fade_out()
	var out_elapsed: float = 0.0
	while not gone[0] and out_elapsed < presentation.fade_out_time + 1.0:
		await get_tree().process_frame
		out_elapsed += get_process_delta_time()
	await _frames(2)
	_check("reflection: it fades out about %.1f s (%.2f s measured) and removes itself" % [presentation.fade_out_time, out_elapsed], gone[0] and absf(out_elapsed - presentation.fade_out_time) < 0.25 and not is_instance_valid(fading))
	# Reduced mode fades the same way (a plain fade).
	var plain: GrandfatherFace = _make_reflection(2, true)
	add_child(plain)
	await _wait(presentation.fade_in_time * 0.5)
	_check("reflection: in reduced mode it is a plain fade (half way at half the time: alpha %.2f)" % plain.alpha, plain.alpha > plain.target_alpha() * 0.3 and plain.alpha < plain.target_alpha() * 0.8)
	plain.free()
	for node in [blurred_one, blurred_two, sharp]:
		node.free()
	# In a level: it is a child of the voice (not of Backdrop or ProfilePresenter) and it fades out and is freed with the line.
	_clean_state()
	_seed_level(1)
	var level: LevelBase = await _load_level(3)
	var voice: GrandfatherVoice = _guard(level)
	_check("reflection: the reflection node exists only while the line shows", voice.reflection == null)
	voice.dismiss(false)
	level.get_node("ElderScene").played = false
	await _until(func() -> bool: return voice.active, 4.0)
	var in_level: GrandfatherFace = voice.reflection
	await _frames(3)
	_check("reflection: in level 3 it is sharp, a child of the voice (not inside Backdrop or ProfilePresenter) and in the sky layer range",
		in_level != null and in_level.sharp and in_level.get_parent() == voice and not in_level.is_ancestor_of(level.get_node("Backdrop")) and in_level.layer == presentation.reflection_layer)
	voice.dismiss(false)
	await _wait(presentation.fade_out_time + 0.5)
	_check("reflection: it is gone after the line (no node left behind)", not is_instance_valid(in_level))
	await _free_level(level)
	# Levels 1 and 2 show it blurred, in a level too.
	for level_number in [1, 2]:
		_clean_state()
		_seed_level(1)
		var small: LevelBase = await _load_level(level_number)
		var small_voice: GrandfatherVoice = _guard(small)
		await _until(func() -> bool: return small_voice.active, 4.0)
		_check("face: level %d shows the faded memory, calm or speaking, never with tears" % level_number, small_voice.reflection != null and not small_voice.reflection.sharp and small_voice.reflection.portrait.find_child("Tears*", true, false) == null and (small_voice.reflection.portrait.expression == &"watching" or small_voice.reflection.portrait.expression == &"speaking"))
		await _free_level(small)
	# Reduced mode through the option: the voice builds a reduced reflection.
	_clean_state()
	var values: Dictionary = GameSettings.DEFAULTS.duplicate()
	values["corruption_effects"] = false
	GameSettings.save_settings(values)
	_seed_level(1)
	var reduced_level: LevelBase = await _load_level(2)
	var reduced_voice: GrandfatherVoice = _guard(reduced_level)
	await _until(func() -> bool: return reduced_voice.active, 4.0)
	_check("reflection: with «Efectos de corrupción» off the reflection is reduced (static fade)", reduced_voice.reflection != null and reduced_voice.reflection.reduced)
	await _free_level(reduced_level)
	GameSettings.save_settings(GameSettings.DEFAULTS.duplicate())


# ---------------------------------------------------------------------------------------------
# Contrast
# ---------------------------------------------------------------------------------------------

func _channel(value: float) -> float:
	return value / 12.92 if value <= 0.03928 else pow((value + 0.055) / 1.055, 2.4)


func _luminance(color: Color) -> float:
	return 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b)


func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _test_contrast() -> void:
	var profiles := load("res://frontend/presentation/default_profile_presentation.tres") as ProfilePresentation
	var possession := PossessionConfig.get_default()
	var backgrounds: Array[Color] = []
	var directory: DirAccess = DirAccess.open(BIOME_DIR)
	for file in directory.get_files():
		if not file.ends_with(".tres"):
			continue
		var biome := load(BIOME_DIR + file) as Biome
		if biome == null:
			continue
		for property in ["sky_top", "sky_bottom", "haze", "far_color", "mid_color", "near_color", "grass", "grass_dark", "soil", "soil_dark", "rock", "rock_dark"]:
			var value: Variant = biome.get(property)
			if value is Color:
				backgrounds.append(value)
	var worst: float = 99.0
	var worst_with_outline: float = 99.0
	var count: int = 0
	for profile in ["neutral", "compassionate", "corrupt"]:
		var tint: Color = profiles.get_look(profile).background_tint
		for amount in [0.0, possession.persistent_sky, 1.0]:
			var red: Color = Color.WHITE.lerp(possession.sky_tint, amount)
			for color in backgrounds:
				var shown := Color(clampf(color.r * tint.r * red.r, 0.0, 1.0), clampf(color.g * tint.g * red.g, 0.0, 1.0), clampf(color.b * tint.b * red.b, 0.0, 1.0))
				# The panel sits over the scene: its color blended over the background, then the text over that.
				var panel := Color(presentation.panel_color.r * presentation.panel_color.a + shown.r * (1.0 - presentation.panel_color.a),
					presentation.panel_color.g * presentation.panel_color.a + shown.g * (1.0 - presentation.panel_color.a),
					presentation.panel_color.b * presentation.panel_color.a + shown.b * (1.0 - presentation.panel_color.a))
				worst = minf(worst, _contrast(presentation.text_color, panel))
				worst_with_outline = minf(worst_with_outline, maxf(_contrast(presentation.text_color, panel), _contrast(presentation.text_color, presentation.outline_color)))
				count += 1
	print("MEASURE|grandfather line contrast|worst %.2f over %d scenery colors x 3 profiles x 3 sky tints (with the ink outline %.2f)" % [worst, count, worst_with_outline])
	_check("contrast: the line text reads over its panel on every scenery color, all three profiles and the possession red (worst %.2f, needs %.1f)" % [worst, MIN_CONTRAST], worst >= MIN_CONTRAST and count > 100)


# ---------------------------------------------------------------------------------------------
# 6. Epilogues
# ---------------------------------------------------------------------------------------------

func _test_epilogues() -> void:
	var ids: Array[String] = ["ending_kept", "ending_released"]
	var all_there: bool = true
	var seen: Dictionary = {}
	var duplicates: bool = false
	var total: int = 0
	var short_enough: bool = true
	for ending_id in ids:
		var story: EndingStory = texts.get_ending(ending_id)
		all_there = all_there and story != null and story.epilogues.size() == 3
		for variant in 3:
			var text: String = texts.epilogue_text(ending_id, variant)
			all_there = all_there and not text.is_empty()
			duplicates = duplicates or seen.has(text)
			seen[text] = true
			short_enough = short_enough and text.length() <= 120
			total += 1
	_check("epilogues: 2 endings x 3 variants = %d texts (Phase 15h), none empty, none repeated, each short" % total, all_there and total == 6 and not duplicates and short_enough)
	_check("epilogues: a variant out of range is clamped and an unknown ending has none", texts.epilogue_text("ending_kept", 9) == texts.epilogue_text("ending_kept", 2) and texts.epilogue_text("ending_kept", -3) == texts.epilogue_text("ending_kept", 0) and texts.epilogue_text("nope", 0).is_empty())
	# The ending is decided only by the souls released, for every variant.
	var ending_ok: bool = true
	var text_ok: bool = true
	for released in 4:
		for variant in 3:
			_clean_state()
			GameState.director.set_forced_plan({"theme": "calma", "epilogue_variant": variant})
			GameState.souls_released = released
			GameState.souls_kept = 3 - released
			var ending := ENDING_SCENE.instantiate() as EndingController
			add_child(ending)
			await _frames(2)
			var expected_id: String = EndingSelector.ending_id_for(released, 3 - released)
			ending_ok = ending_ok and ending.shown_variant == expected_id and ending.shown_text == texts.get_ending(expected_id).summary_line
			text_ok = text_ok and ending.shown_epilogue == texts.epilogue_text(expected_id, variant) and ending.shown_epilogue_variant == variant and ending.epilogue_label != null and ending.epilogue_label.text == ending.shown_epilogue and ending.epilogue_label.visible
			ending.free()
			await _frames(2)
	_check("epilogues: the ending chosen by the souls released is the same for every variant (2 endings x 3 variants, every kept/released split)", ending_ok)
	_check("epilogues: the card shows the epilogue text of the plan variant (2 endings x 3 variants, every kept/released split)", text_ok)
	# The variant comes from the plan: local without telemetry, local from the telemetry, remote when it arrives.
	_clean_state()
	_check("epilogues: continuing from disk (no telemetry) uses variant 0", GameState.director.epilogue_variant() == 0)
	_clean_state()
	_seed_level(3, {"time_in_level": 150})
	_check("epilogues: a comfortable level 3 gives variant 1 (local plan)", GameState.director.epilogue_variant() == 1)
	_clean_state()
	_seed_level(3, {"deaths": 6, "damage_taken": 20})
	_check("epilogues: a struggling level 3 gives variant 2 (local plan)", GameState.director.epilogue_variant() == 2)
	# Prefetched at the level-3 fragment decision (next level 4 = the ending), with the usual fallback.
	_clean_state()
	_seed_level(3, {"time_in_level": 150})
	reply = _remote_reply(null, 2)
	var client: DirectorClient = GameState.get_director_client()
	var started: bool = client.request_plan(3)
	await _until(func() -> bool: return not client.in_flight, 2.0)
	var payload: Dictionary = JSON.parse_string(sent[0]["body"]) if not sent.is_empty() else {}
	_check("ending request: the level-3 decision asks for next_level 4 with no pattern ids (%s)" % client.last_status, started and payload.get("next_level", 0) == 4 and (payload.get("allowed_pattern_ids", [1]) as Array).is_empty())
	_check("ending request: the remote variant (2) beats the local one (1) and reaches the ending", client.last_status == "applied" and GameState.director.epilogue_variant() == 2)
	var remote_ending := ENDING_SCENE.instantiate() as EndingController
	GameState.souls_released = 3
	add_child(remote_ending)
	await _frames(2)
	_check("ending request: the card shows the remote variant text", remote_ending.shown_epilogue == texts.epilogue_text(remote_ending.shown_variant, 2))
	remote_ending.free()
	await _frames(2)
	_check("ending request: an answer after the ending was decided is discarded", not GameState.director.set_remote_plan(4, DirectorPlan.neutral()))
	for failure in ["offline", "timeout"]:
		_clean_state()
		_seed_level(3, {"time_in_level": 150})
		mode = failure
		client = GameState.get_director_client()
		client.request_plan(3)
		await _until(func() -> bool: return not client.in_flight, 2.0)
		_check("ending request: %s falls back to the local variant (1) with no error" % failure, client.last_status != "applied" and GameState.director.epilogue_variant() == 1)
	_clean_state()
	var values: Dictionary = GameSettings.DEFAULTS.duplicate()
	values["ai_adaptation"] = false
	GameSettings.save_settings(values)
	_seed_level(3, {"time_in_level": 150})
	client = GameState.get_director_client()
	_check("ending request: with «Adaptación con IA» off nothing is sent and the local variant is used", not client.request_plan(3) and sent.is_empty() and GameState.director.epilogue_variant() == 1)
	GameSettings.save_settings(GameSettings.DEFAULTS.duplicate())
	_clean_state()
	_seed_level(3, {"deaths": 6, "damage_taken": 20})
	GameState.load_from_dict(GameState.to_dict())
	_check("epilogues: after loading a save the variant is 0 again (nothing was saved)", GameState.director.epilogue_variant() == 0)


func _test_no_leaks() -> void:
	_clean_state()
	var counts: Array[int] = []
	for round in 5:
		_clean_state()
		_seed_level(1)
		var level: LevelBase = await _load_level(2)
		await _until(func() -> bool: return _guard(level).active, 4.0)
		_guard(level).dismiss(false)
		await _wait(presentation.fade_out_time + 0.4)
		await _free_level(level)
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	print("MEASURE|node counts after repeated levels with the grandfather line|%s" % str(counts))
	_check("leaks: no nodes are left behind after repeated levels with the line and the reflection (%s) and nothing is paused" % str(counts), counts[4] <= counts[1] + 4 and not get_tree().paused)
