extends Node
## Headless smoke test for Phase 15t: the grandfather's last line («Se ha sellado la profecía.») in both endings with no crying, the single credits
## resource shared by the menu and the end (names only, no roles, the content notice), the credits and statistics sequence (night sky, rolling credits,
## counting statistics, then the final card with the line of support), and the tuned ambient sound. Development only. Run:
##   <godot> --headless --path game res://frontend/scenes/test/phase15t_smoke_test.tscn
## Uses a redirected save path and a temporary settings file; the AI service stays disabled; the real files are never touched.

const TEST_SAVE: String = "user://test_save_phase15t.json"
const TEST_SETTINGS: String = "user://test_settings_phase15t.cfg"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const ENDING_SCENE: PackedScene = preload("res://frontend/ui/ending.tscn")
const MENU_SCENE: PackedScene = preload("res://frontend/ui/main_menu.tscn")
const PANEL_SCENE: PackedScene = preload("res://frontend/ui/decision_panel.tscn")
const FRAGMENT_SCENE: PackedScene = preload("res://backend/decisions/soul_fragment.tscn")
const FRAGMENTS: Array[SoulFragmentData] = [
	preload("res://backend/decisions/data/fragment_level_1.tres"),
	preload("res://backend/decisions/data/fragment_level_2.tres"),
	preload("res://backend/decisions/data/fragment_level_3.tres"),
]
const KEPT: String = "ending_kept"
const RELEASED: String = "ending_released"
const LAST_LINE: String = "Abuelo: Se ha sellado la profecía."
const SUPPORT_LINE: String = "Si tú o alguien que conoces está pasando por algo así, habla con alguien de confianza o con un servicio de salud mental de tu país. No estás solo."
const ROLE_WORDS: Array[String] = ["diseño", "programación", "programacion", "desarrollo", "sistemas", "interfaces", "escenarios", "visual", "arte ", "código", "codigo", "animación", "guion", "guión"]
const CLOCK: float = 20.0

var failures: int = 0
var real_save_before: String = ""
var real_settings_before: String = ""
var real_controls_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig
var texts: StoryTexts = null
var content: CreditsContent = null
var config: EndingCreditsConfig = null


func _ready() -> void:
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	GameSettings.path_override = TEST_SETTINGS
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
	real_settings_before = _read_file(GameSettings.PATH)
	real_controls_before = _read_file(ControlsConfig.DEFAULT_PATH)
	texts = StoryTexts.get_default()
	content = CreditsContent.get_default()
	config = EndingCreditsConfig.get_default()
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


func _until(condition: Callable, max_seconds: float = 20.0) -> bool:
	var waited: float = 0.0
	while waited < max_seconds:
		if condition.call():
			return true
		await get_tree().process_frame
		waited += get_process_delta_time()
	return condition.call()


func _set_options(values: Dictionary) -> void:
	var all: Dictionary = GameSettings.DEFAULTS.duplicate()
	all.merge(values, true)
	GameSettings.save_settings(all)


func _clean_state() -> void:
	Engine.time_scale = 1.0
	PauseLock.reset(get_tree())
	get_tree().paused = false
	SaveSystem.purge()
	GameSettings.save_settings(GameSettings.DEFAULTS.duplicate())
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.autosave_enabled = false
	AbilityCard.forget_all()
	BossDialogue.forget_all()


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
		fragment.free()
	panel.free()
	flow.free()


func _accept() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	return event


func _norm(text: String) -> String:
	return text.to_lower().replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").replace("ñ", "n").replace("ü", "u")


func _contains_term(text: String, term: String) -> bool:
	var regex := RegEx.new()
	regex.compile("(?<![a-z])" + _norm(term) + "(?![a-z])")
	return regex.search(_norm(text)) != null


func _run() -> void:
	_clean_state()
	var nodes_before: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_test_guards()
	_test_last_line()
	_test_credits_content()
	await _test_menu_and_end_share_content()
	print("MEASURE|nodes after _test_menu_and_end_share_content()|%d" % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	await _test_no_clipping()
	print("MEASURE|nodes after _test_no_clipping()|%d" % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	await _test_sequence_normal("kept")
	print("MEASURE|nodes after _test_sequence_normal('kept')|%d" % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	await _test_sequence_normal("released")
	print("MEASURE|nodes after _test_sequence_normal('released')|%d" % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	await _test_sequence_skip_and_pause()
	print("MEASURE|nodes after _test_sequence_skip_and_pause()|%d" % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	await _test_sequence_reduced()
	print("MEASURE|nodes after _test_sequence_reduced()|%d" % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	await _test_flow("kept")
	print("MEASURE|nodes after _test_flow('kept')|%d" % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	await _test_flow("released")
	print("MEASURE|nodes after _test_flow('released')|%d" % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	await _test_skip_goes_to_card()
	print("MEASURE|nodes after _test_skip_goes_to_card()|%d" % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	_test_ambient()
	await _frames(4)
	var nodes_after: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("MEASURE|node counts before and after|%d, %d" % [nodes_before, nodes_after])
	_check("leaks: no nodes are left behind (%d before, %d after)" % [nodes_before, nodes_after], nodes_after <= nodes_before + 6 and not get_tree().paused)
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
# 1. The last line and the calm grandfather
# ---------------------------------------------------------------------------------------------

func _test_last_line() -> void:
	for id in [KEPT, RELEASED]:
		var story: EndingStory = texts.get_ending(id)
		var list: EndingBeatList = story.beats
		_check("%s: the last line is exactly «%s»" % [id, LAST_LINE], story.lines[story.lines.size() - 1] == LAST_LINE)
		_check("%s: the old apology «Perdóname, nieto.» is gone from the ending" % id, not " ".join(story.lines).contains("Perdóname, nieto"))
		var hits: String = ""
		for term in texts.ending_banned_terms:
			if _contains_term(LAST_LINE, term):
				hits += "banned:%s " % term
		for term in texts.ending_romanticizing_terms:
			if _contains_term(LAST_LINE, term):
				hits += "romantic:%s " % term
		_check("%s: the final line passes the banned-term and the romanticizing lists" % id, hits.is_empty(), hits)
		var states: Array[StringName] = []
		var lowered: bool = false
		for beat in list.beats:
			if beat.expression != &"":
				states.append(beat.expression)
		for state in states:
			lowered = lowered or state == &"grieving" or state == &"breaking" or state == &"solemn"
		var line_beats: Array = list.line_beats()
		var last_beat: EndingBeat = line_beats[line_beats.size() - 1]
		_check("%s: the grandfather is calm (%s): no grieving, no breaking down, no lowered head, no dimmed state" % [id, str(states)], not lowered and states.has(&"speaking"))
		_check("%s: the last line beat is his and his portrait is the calm speaking one" % id, last_beat.line == story.lines.size() - 1 and last_beat.expression == &"speaking")
		var tail: EndingBeat = list.beats[list.beats.size() - 1]
		_check("%s: after the last line there is one slow fade to white (%.0f s) and nothing else: it hands over to the credits" % [id, tail.seconds], tail.fade_white and tail.fade_to >= 0.99 and tail.seconds >= 4.0 and tail.expression == &"" and not tail.is_line())
	_check("the support line is on both endings' final card (still)", texts.get_ending(KEPT).support_line == SUPPORT_LINE and texts.get_ending(RELEASED).support_line == SUPPORT_LINE)


# ---------------------------------------------------------------------------------------------
# 2. The credits resource
# ---------------------------------------------------------------------------------------------

func _test_credits_content() -> void:
	_check("credits: the resource loads and is the default of the class", content != null and CreditsContent.DEFAULT_PATH.ends_with("default_credits_content.tres"))
	var names: PackedStringArray = content.developers
	_check("credits: the developers are named (%s)" % str(names), names.has("Juliana Peñafiel") and names.has("Laura Escobar") and names.size() == 2)
	var all: PackedStringArray = content.all_texts(texts.content_notice)
	var role_hit: String = ""
	for text in all:
		for word in ROLE_WORDS:
			if _norm(text).contains(_norm(word)):
				role_hit = "%s in «%s»" % [word, text]
	_check("credits: names only: no role (design, programming, systems...) appears anywhere", role_hit.is_empty(), role_hit)
	var joined: String = " ".join(all)
	_check("credits: the game title and tagline are there", joined.contains("QUACKTACLYSM") and not content.tagline.is_empty())
	_check("credits: technology lists Godot, Python/FastAPI and OpenAI with the «Adaptación con IA» note", joined.contains("Godot") and joined.contains("FastAPI") and joined.contains("OpenAI") and joined.contains("Adaptación con IA"))
	_check("credits: music and sound effects list their authors and licenses where the repository documents them", joined.contains("Juhani Junkala") and joined.contains("Kenney") and joined.contains("StarNinjas") and joined.contains("artisticdude") and joined.contains("CC0"))
	_check("credits: the audio that has no documented author says so neutrally", joined.contains("autoría sin documentar"))
	_check("credits: the thanks section has the editable line for the person who helped with the ambient sounds and a general thanks", content.thanks_lines.size() >= 2 and joined.contains("sonidos ambientales") and joined.contains("juegue hasta el final"))
	_check("credits: the content notice is part of them (stylized blood violence in combat and suicide implicit in both endings)", joined.contains(texts.content_notice) and texts.content_notice.contains("violencia estilizada con sangre") and texts.content_notice.contains("suicidio"))
	_check("credits: the line of support is NOT repeated in them (it stays on the final card)", not joined.contains(SUPPORT_LINE) and not joined.contains("No estás solo"))
	_check("credits: more content than before (title, team, technology, audio, fonts, thanks, notice: 7 sections)", content.sections(texts.content_notice, true).size() == 7)


func _roll_texts(box: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for label in box.find_children("*", "Label", true, false):
		out.append((label as Label).text)
	return out


func _test_menu_and_end_share_content() -> void:
	var menu := MENU_SCENE.instantiate()
	add_child(menu)
	await _frames(4)
	var menu_content: Variant = menu.get("credits_content")
	var menu_roll := menu.get("credits_roll") as VBoxContainer
	var menu_texts: PackedStringArray = _roll_texts(menu_roll)
	_check("menu: it reads the ONE credits resource (the same instance as the end)", menu_content == content)
	var menu_missing: String = ""
	for section: Dictionary in content.sections(texts.content_notice, false):
		for line in section["lines"] as PackedStringArray:
			if not menu_texts.has(line):
				menu_missing = line
	_check("menu: its roll shows every section line of the resource", menu_missing.is_empty() and menu_texts.has("Juliana Peñafiel") and menu_texts.has("Laura Escobar"), menu_missing)
	var credits_label := menu.get("credits_label") as Label
	_check("menu: the content notice stays visible above the roll (a label, not a pop-up)", credits_label != null and credits_label.text.contains(texts.content_notice))
	menu.free()
	var sequence := _sequence("kept")
	add_child(sequence)
	await _frames(3)
	var end_texts: PackedStringArray = _roll_texts(sequence.roll)
	var end_missing: String = ""
	for text in content.all_texts(texts.content_notice):
		if not end_texts.has(text):
			end_missing = text
	_check("end: its roll shows EVERY text of the same resource, the notice included", end_missing.is_empty(), end_missing)
	var menu_set: Dictionary = {}
	for text in menu_texts:
		menu_set[text] = true
	var shared: bool = true
	for text in menu_set.keys():
		shared = shared and end_texts.has(text)
	_check("end: everything the menu shows is also in the end credits (one source)", shared)
	sequence.free()
	await _frames(2)


func _sequence(style: String) -> EndingCredits:
	var sequence := EndingCredits.new()
	sequence.style = style
	sequence.stats_title = "Título"
	sequence.stat_rows = [
		{"format": "Almas liberadas: %d", "value": 3},
		{"format": "Almas guardadas: %d", "value": 2},
		{"text": "Liberadas: A, B"},
		{"text": "Guardadas: C"},
	]
	return sequence


func _test_no_clipping() -> void:
	var sequence := _sequence("kept")
	add_child(sequence)
	await _frames(4)
	var clipped: int = 0
	var too_wide: int = 0
	var labels: Array = sequence.roll.find_children("*", "Label", true, false)
	for label_node in labels:
		var label := label_node as Label
		if label.get_line_count() != label.get_visible_line_count():
			clipped += 1
		if label.size.x > EndingCredits.COLUMN_WIDTH + 0.5:
			too_wide += 1
	var height: float = CreditsRoll.column_height(sequence.roll)
	var seconds: float = (height + EndingCredits.VIEW_SIZE.y) / content.ending_speed
	_check("fit: the end credits wrap inside the %.0f px column, nothing clipped or too wide (%d labels, %d clipped, %d too wide)" % [EndingCredits.COLUMN_WIDTH, labels.size(), clipped, too_wide], clipped == 0 and too_wide == 0 and labels.size() >= 20)
	_check("fit: the column is %.0f px tall and rolls by in %.0f s (within 30 to 150 s)" % [height, seconds], height > 800.0 and seconds >= 30.0 and seconds <= 150.0)
	var page_ok: bool = true
	for page in sequence.pages:
		page_ok = page_ok and page.get_combined_minimum_size().y <= EndingCredits.VIEW_SIZE.y - 40.0
	_check("fit: every static page of the reduced mode fits the screen (%d pages)" % sequence.pages.size(), page_ok and sequence.pages.size() == 7)
	sequence.free()
	var menu := MENU_SCENE.instantiate()
	add_child(menu)
	await _frames(4)
	var menu_roll := menu.get("credits_roll") as VBoxContainer
	var scroll := menu.get("credits_scroll") as Control
	var menu_clipped: int = 0
	for label_node in menu_roll.find_children("*", "Label", true, false):
		var label := label_node as Label
		if label.get_line_count() != label.get_visible_line_count() or label.size.x > scroll.custom_minimum_size.x + 0.5:
			menu_clipped += 1
	_check("fit: the menu credits wrap in their scroll too, nothing clipped (%d bad labels, column %.0f px)" % [menu_clipped, menu_roll.get_combined_minimum_size().y], menu_clipped == 0)
	menu.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 3. The sequence
# ---------------------------------------------------------------------------------------------

func _test_sequence_normal(style: String) -> void:
	_clean_state()
	var sequence := _sequence(style)
	var phases: Array[int] = []
	var finished: Array = []
	sequence.phase_changed.connect(func(phase: int) -> void: phases.append(phase))
	sequence.finished.connect(func(skipped: bool) -> void: finished.append(skipped))
	add_child(sequence)
	await _frames(2)
	_check("%s sequence: it opens on pure white (the white of the cut) and clears slowly into the sky" % style, sequence._veil.color.r > 0.99 and sequence._veil.color.g > 0.99 and sequence._veil.color.a > 0.9 and not sequence.reduced)
	var last_veil: float = 1.0
	var veil_rises: int = 0
	var biggest_step: float = 0.0
	var stats_texts: Array[String] = []
	var previous_alpha: float = 1.0
	var credits_seen: bool = false
	var stat_label: Label = null
	Engine.time_scale = CLOCK
	var guard: int = 0
	while not sequence.is_finished and guard < 9000:
		await get_tree().process_frame
		guard += 1
		var alpha: float = sequence._veil.color.a
		if sequence.phase != EndingCredits.Phase.DONE:
			if alpha > last_veil + 0.0001:
				veil_rises += 1
			biggest_step = maxf(biggest_step, absf(alpha - previous_alpha) / maxf(get_process_delta_time(), 0.0001))
		previous_alpha = alpha
		last_veil = minf(last_veil, alpha) if sequence.phase != EndingCredits.Phase.DONE else last_veil
		if sequence.phase == EndingCredits.Phase.CREDITS and sequence.roll.visible:
			credits_seen = true
		if sequence.phase == EndingCredits.Phase.STATS and not sequence.stat_labels.is_empty():
			stat_label = sequence.stat_labels[0]
			if stats_texts.is_empty() or stats_texts[stats_texts.size() - 1] != stat_label.text:
				stats_texts.append(stat_label.text)
	Engine.time_scale = 1.0
	_check("%s sequence: sky, then credits, then statistics, then done, in that order (%s) and it finished by itself" % [style, str(phases)], phases == [EndingCredits.Phase.CREDITS, EndingCredits.Phase.STATS, EndingCredits.Phase.DONE] and finished == [false] and credits_seen)
	_check("%s sequence: the veil only clears (it never comes back: %d rises) and moves slowly (steepest %.2f per game second)" % [style, veil_rises, biggest_step], veil_rises == 0 and biggest_step < 0.9)
	_check("%s sequence: the first counter COUNTS UP smoothly through intermediate values (%s)" % [style, str(stats_texts)], stats_texts.size() >= 3 and stats_texts[0] == "Almas liberadas: 0" and stats_texts[stats_texts.size() - 1] == "Almas liberadas: 3")
	var all_visible: bool = true
	for label in sequence.stat_labels:
		all_visible = all_visible and label.modulate.a > 0.99
	_check("%s sequence: every statistic ended up fully visible, each appearing in turn" % style, all_visible and sequence.stat_labels.size() == 4)
	var sky_moved: bool = sequence.sky.time > 20.0 and sequence.sky.redraws > 20
	_check("%s sequence: the sky moved the whole time (%.0f s, %d redraws)" % [style, sequence.sky.time, sequence.sky.redraws], sky_moved)
	sequence.free()
	await _frames(2)


func _test_sequence_skip_and_pause() -> void:
	_clean_state()
	var sequence := _sequence("kept")
	var finished: Array = []
	sequence.finished.connect(func(skipped: bool) -> void: finished.append(skipped))
	add_child(sequence)
	Engine.time_scale = 10.0
	await _until(func() -> bool: return sequence.phase == EndingCredits.Phase.CREDITS, 10.0)
	Engine.time_scale = 1.0
	await _frames(3)
	sequence.press_confirm()
	_check("skip: a single press during the credits does nothing (only a hold skips)", sequence.phase == EndingCredits.Phase.CREDITS and not sequence.was_skipped)
	get_tree().paused = true
	var before: float = sequence.elapsed
	var sky_before: float = sequence.sky.time
	await get_tree().create_timer(0.4, true).timeout
	_check("pause: the sequence and its sky stand still while the game is paused (%.2f -> %.2f)" % [before, sequence.elapsed], is_equal_approx(before, sequence.elapsed) and is_equal_approx(sky_before, sequence.sky.time))
	get_tree().paused = false
	await _frames(10)
	_check("pause: it goes on when the game does", sequence.elapsed > before)
	sequence.held = sequence.config.hold_seconds + 1.0
	await _frames(2)
	await _until(func() -> bool: return sequence.is_finished, 3.0)
	_check("skip: holding the confirm action skips everything and ends the sequence (skipped = %s)" % str(finished), finished == [true] and sequence.was_skipped)
	sequence.free()
	await _frames(2)


func _test_sequence_reduced() -> void:
	_clean_state()
	_set_options({"corruption_effects": false})
	var sequence := _sequence("released")
	var finished: Array = []
	sequence.finished.connect(func(skipped: bool) -> void: finished.append(skipped))
	add_child(sequence)
	await _frames(3)
	_check("reduced: the sky is a still picture and the stars do not move (time %.2f)" % sequence.sky.time, sequence.reduced and sequence.sky.reduced and is_zero_approx(sequence.sky.time))
	Engine.time_scale = CLOCK
	await _until(func() -> bool: return sequence.phase == EndingCredits.Phase.CREDITS, 20.0)
	Engine.time_scale = 1.0
	await _frames(3)
	var visible_pages: int = 0
	for page in sequence.pages:
		visible_pages += 1 if page.visible else 0
	_check("reduced: the credits are simple static pages (one at a time: %d visible, the rolling column hidden)" % visible_pages, visible_pages == 1 and not sequence.roll.visible and is_zero_approx(sequence.sky.time))
	var first_page: int = sequence.page_index
	sequence.elapsed = 5.0
	sequence.press_confirm()
	await _frames(2)
	_check("reduced: a press moves to the next page (%d -> %d)" % [first_page, sequence.page_index], sequence.page_index == first_page + 1)
	for i in sequence.pages.size() + 1:
		if sequence.phase != EndingCredits.Phase.CREDITS:
			break
		sequence.press_confirm()
		await _frames(1)
	await _frames(3)
	var text_now: String = sequence.stat_labels[0].text
	_check("reduced: the statistics appear at once, without counting (%s, alpha %.2f)" % [text_now, sequence.stat_labels[0].modulate.a], sequence.phase == EndingCredits.Phase.STATS and text_now == "Almas liberadas: 3" and sequence.stat_labels[0].modulate.a > 0.99 and sequence.stat_labels[3].modulate.a > 0.99 and is_zero_approx(sequence.sky.time))
	sequence.elapsed = 5.0
	sequence.press_confirm()
	await _until(func() -> bool: return sequence.is_finished, 3.0)
	_check("reduced: a press on the finished statistics goes on to the final card", finished == [false])
	sequence.free()
	_clean_state()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# The whole flow in the ending scene
# ---------------------------------------------------------------------------------------------

func _test_flow(style: String) -> void:
	_clean_state()
	var kept: bool = style == "kept"
	_decide([GameState.CHOICE_KEPT, GameState.CHOICE_KEPT, GameState.CHOICE_KEPT] if kept else [GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED])
	var ending := ENDING_SCENE.instantiate() as EndingController
	ending.skip_reel_when_headless = false
	add_child(ending)
	await _frames(3)
	var order: Array[String] = []
	var reel: EndingCinematic = ending.reel
	reel.line_changed.connect(func(index: int, _text: String) -> void:
		if index == reel.lines.size() - 1:
			order.append("last_line"))
	ending.reel_finished.connect(func() -> void: order.append("reel_finished"))
	ending.credits_started.connect(func() -> void: order.append("credits"))
	ending.credits_finished.connect(func() -> void: order.append("stats_done"))
	ending.card_shown.connect(func() -> void: order.append("final_card"))
	var wind_started: bool = false
	var ambient_before_cut: bool = false
	Engine.time_scale = CLOCK
	var guard: int = 0
	while not ending.card_visible and guard < 12000:
		await get_tree().process_frame
		guard += 1
		if is_instance_valid(reel) and reel.current_beat() != null:
			if reel.current_beat().is_line():
				reel._input(_accept())
			if AudioDirector.is_ambient_active():
				wind_started = true
	Engine.time_scale = 1.0
	_check("%s flow: last line -> credits animation -> statistics done -> final card (%s)" % [style, str(order)], order == ["last_line", "reel_finished", "credits", "stats_done", "final_card"])
	_check("%s flow: the cold wind played as the ambient slot during the ending (not a repeated sample)" % style, wind_started)
	_check("%s flow: the final card shows the line of support and the way back to the menu" % style, ending.support_label.visible and ending.support_label.text == SUPPORT_LINE and ending.back_button.visible and ending.card_visible)
	_check("%s flow: the statistics are not shown twice (hidden on the final card)" % style, not ending.released_label.visible and not ending.kept_label.visible and not ending.released_names_label.visible and not ending.kept_names_label.visible)
	_check("%s flow: the credits used the right sky (%s) and the stats carried the real counters" % [style, ending.credits.style], ending.credits.style == style and ending.credits.stat_rows[1]["value"] == (3 if kept else 0) and ending.credits.stat_rows[0]["value"] == (0 if kept else 3))
	ending.free()
	await _frames(4)
	_check("%s flow: the ambient is released after the ending (no bus left, nothing sounding on)" % style, not AudioDirector.is_ambient_active() and AudioServer.get_bus_index(AudioDirector.AMBIENT_BUS) == -1)


func _test_skip_goes_to_card() -> void:
	_clean_state()
	_decide([GameState.CHOICE_KEPT, GameState.CHOICE_KEPT, GameState.CHOICE_KEPT])
	var ending := ENDING_SCENE.instantiate() as EndingController
	ending.skip_reel_when_headless = false
	add_child(ending)
	await _frames(3)
	ending.reel.skip()
	await _until(func() -> bool: return ending.card_visible, 6.0)
	_check("skip: skipping the ending goes straight to the final card (no credits), with the support line", ending.card_visible and ending.credits == null and not ending.credits_played and ending.support_label.visible and ending.released_label.visible)
	ending.free()
	await _frames(3)


# ---------------------------------------------------------------------------------------------
# 4. Ambient
# ---------------------------------------------------------------------------------------------

func _test_ambient() -> void:
	var audio: AudioEvents = AudioEvents.get_default()
	var slot: AmbientSlot = audio.get_ambient(&"wind")
	_check("ambient: the wind slot exists in the audio table and points to one file field (empty = generated by code)", slot != null and slot.file == "" and audio.get_ambient(&"nothing") == null)
	if slot == null:
		return
	var quietest_event: float = 0.0
	for entry: Variant in audio.events:
		quietest_event = minf(quietest_event, (entry as AudioEvent).volume_db)
	var loudest_gust: float = slot.volume_db + slot.volume_jitter_db + AudioDirector.SFX_DB
	var music_floor: float = AudioDirector.MUSIC_DB + minf(audio.ending_kept_music.base_duck_db, audio.ending_released_music.base_duck_db)
	_check("ambient: volume %.0f dB (loudest gust %.1f) is lower than before and sits under the music (%.1f), the voices (%.1f) and the effects (SFX %.0f dB)" % [slot.volume_db, loudest_gust, music_floor, AudioDirector.SFX_DB + audio.get_event(&"grandfather_voice").volume_db, AudioDirector.SFX_DB], slot.volume_db <= -24.0 and slot.volume_db >= -40.0 and loudest_gust < music_floor and loudest_gust < AudioDirector.SFX_DB + audio.get_event(&"grandfather_voice").volume_db and slot.volume_db + slot.volume_jitter_db < quietest_event)
	_check("ambient: it is softened (low-pass %.0f Hz) with long fades (%.1f s in, %.1f s out)" % [slot.lowpass_hz, slot.fade_in_seconds, slot.fade_out_seconds], slot.lowpass_hz <= 1500.0 and slot.fade_in_seconds >= 2.5 and slot.fade_out_seconds >= 2.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var pitches: Dictionary = {}
	var offsets_ok: bool = true
	var gaps_ok: bool = true
	var volumes_ok: bool = true
	for i in 60:
		var plan: Dictionary = slot.plan(rng)
		pitches[snappedf(float(plan["pitch"]), 0.001)] = true
		offsets_ok = offsets_ok and float(plan["offset"]) >= 0.0 and float(plan["offset"]) <= slot.start_offset_max_seconds
		gaps_ok = gaps_ok and float(plan["gap"]) >= slot.interval_min_seconds and float(plan["gap"]) <= slot.interval_max_seconds
		volumes_ok = volumes_ok and absf(float(plan["volume_db"]) - slot.volume_db) <= slot.volume_jitter_db + 0.001
	_check("ambient: gusts do not repeat: random pitch (%d different of 60, %.2f to %.2f), random start offset (up to %.1f s), random gaps (%.0f to %.0f s), volume jitter" % [pitches.size(), slot.pitch_min, slot.pitch_max, slot.start_offset_max_seconds, slot.interval_min_seconds, slot.interval_max_seconds], pitches.size() >= 50 and offsets_ok and gaps_ok and volumes_ok and slot.pitch_max - slot.pitch_min >= 0.15 and slot.start_offset_max_seconds >= 1.0 and slot.interval_max_seconds > slot.interval_min_seconds)
	_check("ambient: a gust rises and dies away smoothly (envelope %.2f at 0 s, %.2f at 1 s, %.2f mid, %.2f at the end)" % [slot.envelope(0.0, slot.gust_seconds), slot.envelope(1.0, slot.gust_seconds), slot.envelope(slot.gust_seconds * 0.5, slot.gust_seconds), slot.envelope(slot.gust_seconds, slot.gust_seconds)], is_zero_approx(slot.envelope(0.0, slot.gust_seconds)) and slot.envelope(1.0, slot.gust_seconds) < 0.5 and slot.envelope(slot.gust_seconds * 0.5, slot.gust_seconds) > 0.99 and is_zero_approx(slot.envelope(slot.gust_seconds, slot.gust_seconds)))
	var stream: AudioStreamWAV = slot.generate_wind()
	var data: PackedByteArray = stream.data
	var count: int = data.size() / 2
	var peak: float = 0.0
	var mean_abs: float = 0.0
	var mean_step: float = 0.0
	var previous: float = data.decode_s16(0) / 32768.0
	for i in count:
		var v: float = data.decode_s16(i * 2) / 32768.0
		peak = maxf(peak, absf(v))
		mean_abs += absf(v)
		mean_step += absf(v - previous)
		previous = v
	mean_abs /= count
	mean_step /= count
	var seam: float = absf(data.decode_s16(0) / 32768.0 - data.decode_s16((count - 1) * 2) / 32768.0)
	_check("ambient: the generated wind is a soft loop (%d samples at %d Hz, peak %.2f, smoothness %.3f, seam jump %.4f)" % [count, stream.mix_rate, peak, mean_step / maxf(mean_abs, 0.0001), seam], stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and peak <= 0.81 and peak >= 0.5 and mean_step / maxf(mean_abs, 0.0001) < 0.5 and seam <= mean_step * 6.0 + 0.002 and count > 30000)
	var started: bool = AudioDirector.start_ambient(&"wind", 0.5)
	var stopped_state: bool = AudioDirector.is_ambient_active() and AudioDirector.ambient_id == &"wind" and AudioDirector.ambient_intensity == 0.5
	AudioDirector.stop_ambient(true)
	_check("ambient: it starts and stops cleanly through the director (no new autoload)", started and stopped_state and not AudioDirector.is_ambient_active() and AudioDirector.ambient_voice_count() == 0)
	var cry: AudioEvent = audio.get_event(&"duck_cry_lonely")
	_check("ambient: the far lonely cry of the cliff ending is quieter too (%.0f dB)" % cry.volume_db, cry.volume_db <= -22.0)
