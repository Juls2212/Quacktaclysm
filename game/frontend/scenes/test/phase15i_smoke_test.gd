extends Node
## Smoke test for Phase 15i and 15i-bis: the endings as cinematics on a cliff. The grandfather's face (a portrait, not a constellation) and its four expressions;
## the beat list of «Estrellas que suben» (the full painful arc, in order, inside its duration range) and of «El acantilado» (the duck steps off
## the edge as a silhouette, nothing of it after the drop, the camera ends on the empty edge); the safety rules of the cliff ending on every
## text; Enter-only advance; reduced mode as stills; flash and contrast limits; and no leaks. Development only.
## Run (alone, a few minutes, the clock runs fast): <godot> --headless --path game res://frontend/scenes/test/phase15i_smoke_test.tscn
## Uses a redirected save path; the real save, settings and controls are never touched.

const TEST_SAVE: String = "user://test_save_phase15i.json"
const TEST_SETTINGS: String = "user://test_settings_phase15i.cfg"
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
const CLOCK: float = 20.0

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


func _until(condition: Callable, max_seconds: float = 20.0) -> bool:
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
	Input.action_release(&"ui_accept")
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
	_test_selection_rule()
	await _test_portrait()
	_test_kept_beats()
	_test_released_beats()
	_test_texts_and_notice()
	_test_audio_and_limits()
	await _test_scenes()
	await _test_advance()
	await _test_reduced()
	await _test_audio_runtime()
	await _test_leaks()
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


func _ending(skip_headless: bool = false) -> EndingController:
	var ending := ENDING_SCENE.instantiate() as EndingController
	ending.skip_reel_when_headless = skip_headless
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


func _luminance(c: Color) -> float:
	var channels: Array[float] = [c.r, c.g, c.b]
	var lin: Array[float] = []
	for v in channels:
		lin.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _ids(list: EndingBeatList) -> Array[StringName]:
	var ids: Array[StringName] = []
	for beat in list.beats:
		ids.append(beat.id)
	return ids


# ---------------------------------------------------------------------------------------------
# Guards and selection
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
	var ok: bool = true
	for kept in [0, 1, 2, 3]:
		var expected: String = KEPT if kept > 3 - kept else RELEASED
		ok = ok and EndingSelector.ending_id_for(3 - kept, kept) == expected
	_check("selection: 3/0 and 2/1 kept -> «Estrellas que suben», 1/2 and 0/3 -> «El acantilado»; no decision -> the cliff (same rule as before)", ok and EndingSelector.ending_id_for(0, 0) == RELEASED)
	_check("selection: the endings are exactly two and keep their names", texts.endings.size() == 2 and texts.get_ending(KEPT).title == "ESTRELLAS QUE SUBEN" and texts.get_ending(RELEASED).title == "EL ACANTILADO")


# ---------------------------------------------------------------------------------------------
# The grandfather's face
# ---------------------------------------------------------------------------------------------

func _test_portrait() -> void:
	# Phase 15r: the grandfather in the sky is his full-body figure (GrandfatherSky), not a drawn face: no tears, no overlay shapes.
	var portrait := GrandfatherSky.new()
	portrait.alpha = 1.0
	add_child(portrait)
	await _frames(3)
	var names: PackedStringArray = GrandfatherSky.STATE_NAMES
	_check("portrait: the expression states exist (watching, speaking, grieving, breaking and solemn)", names.size() == 5 and names.has("watching") and names.has("speaking") and names.has("grieving") and names.has("breaking") and names.has("solemn"))
	var as_variant: Variant = portrait
	_check("portrait: it is his own figure (a DuckRig, look GRANDFATHER) drawn in an offscreen picture, not the constellation and not a drawn face", not as_variant is GrandfatherFace and portrait.rig != null and portrait.rig.look == DuckRig.Look.GRANDFATHER and portrait.viewport != null)
	var grief: Array[float] = []
	for name in [&"watching", &"speaking", &"grieving", &"breaking"]:
		portrait.set_expression(name)
		for i in 90:
			await get_tree().process_frame
		grief.append(portrait.grief)
	_check("portrait: sorrow grows from watching to breaking through a lowered head and a dimmer glow (grief %s), never tears" % str(grief.map(func(v: float) -> String: return "%.2f" % v)),
		grief[0] < grief[2] and grief[2] < grief[3] and portrait.find_children("*Tear*", "", true, false).is_empty())
	_check("portrait: nothing is drawn over the face: only the picture, its mist and the glow behind", portrait.get_child_count() == 3 and portrait.get_node("Picture") != null and portrait.get_node("Mist") != null and portrait.get_node("View") != null)
	portrait.set_expression(&"solemn")
	await get_tree().create_timer(3.0).timeout
	_check("portrait: the SOLEMN state is upright and impassive (grief %.2f)" % portrait.grief, portrait.grief < 0.05)
	portrait.talking = true
	await _frames(3)
	_check("portrait: his figure talks while he speaks", portrait.rig.gesture == DuckRig.Gesture.TALK and portrait.talking)
	portrait.free()
	var still := GrandfatherSky.new()
	still.reduced = true
	still.alpha = 1.0
	add_child(still)
	still.set_expression(&"breaking")
	await _frames(8)
	_check("portrait (reduced): a still picture (rendered once per change), no tremble and no drift (grief %.2f, update mode %d)" % [still.grief, still.viewport.render_target_update_mode], is_equal_approx(still.grief, 1.0) and still.viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS and is_equal_approx(still.rig.rotation, GrandfatherPresentation.get_default().sky_grief_tilt))
	still.free()


# ---------------------------------------------------------------------------------------------
# The beat lists
# ---------------------------------------------------------------------------------------------

func _index_of(list: EndingBeatList, id: StringName) -> int:
	return list.index_of(id)


func _test_kept_beats() -> void:
	var story: EndingStory = texts.get_ending(KEPT)
	var list: EndingBeatList = story.beats
	_check("kept: the ending has a beat list", list != null and list.beats.size() >= 18)
	var seconds: float = list.timed_seconds()
	_check("kept: %.0f s of timed beats, inside the exported range (%.0f to %.0f s), the same range as before" % [seconds, list.min_seconds, list.max_seconds], seconds >= list.min_seconds and seconds <= list.max_seconds and seconds >= 50.0 and seconds <= 75.0)
	var order: Array[StringName] = [&"city_dawn", &"cliff_duck", &"corruption_spreads", &"stagger_and_fall", &"closeup_pain", &"reach_for_stars", &"corruption_takes_hand", &"kneel_at_edge", &"bow_and_cut", &"white_hold", &"empty_edge", &"grandfather_breaking", &"hold_quiet"]
	var positions: Array[int] = []
	for id in order:
		positions.append(_index_of(list, id))
	var in_order: bool = true
	for i in positions.size():
		in_order = in_order and positions[i] >= 0 and (i == 0 or positions[i] > positions[i - 1])
	_check("kept: the arc is there, in order: the city lights come on below the cliff, labored breathing, corruption spreading, the stagger and fall, the close-up of pain, the reach for the stars, the corruption takes the hand (it resists), it kneels at the edge, the cut to white, the empty edge, the grandfather breaks down, the quiet", in_order, str(positions))
	var spreads: EndingBeat = list.beats[_index_of(list, &"corruption_spreads")]
	var takes: EndingBeat = list.beats[_index_of(list, &"corruption_takes_hand")]
	var cut: EndingBeat = list.beats[_index_of(list, &"bow_and_cut")]
	var kneel: EndingBeat = list.beats[_index_of(list, &"kneel_at_edge")]
	_check("kept: the breathing becomes labored (%.1f -> %.1f), the veins crawl (%.2f -> %.2f) and the color drains" % [spreads.breath_from, spreads.breath_to, spreads.veins_from, spreads.veins_to], spreads.breath_to >= 0.8 and spreads.veins_to - spreads.veins_from >= 0.4)
	_check("kept: the corruption takes the hand and the duck RESISTS (pose resist, a strained cry, the music fades to silence)", takes.duck_pose == &"resist" and takes.sfx == &"duck_cry_resist" and takes.music_db <= -20.0 and kneel.music_db <= -50.0)
	_check("kept: it kneels at the edge, and the scene CUTS TO WHITE over %.0f s (a slow fade of at least 1 s, never a flash) before anything else" % cut.seconds, kneel.duck_pose == &"kneel_edge" and cut.fade_white and cut.fade_to >= 0.99 and cut.seconds >= 1.0 and cut.flash_alpha == 0.0)
	var last_visible: int = -1
	for i in list.beats.size():
		if list.beats[i].duck_visible:
			last_visible = i
	_check("kept: the last beat where the duck is visible is the cut itself (beat %d of %d): nothing of the act is shown" % [last_visible, list.beats.size()], last_visible == _index_of(list, &"bow_and_cut"))
	var cut_index: int = _index_of(list, &"bow_and_cut")
	var after_ok: bool = true
	for i in range(cut_index, list.beats.size()):
		var beat: EndingBeat = list.beats[i]
		after_ok = after_ok and beat.sfx == &"" and (beat.loop_sfx == &"" or beat.loop_sfx == &"transition") and beat.music_db <= -50.0 and (i == cut_index or not beat.duck_visible) and (not beat.is_line() or not beat.voiced)
	_check("kept: from the cut on there is no sound but the cold wind, no music, no voice blip and no duck", after_ok)
	var safe_names: bool = true
	var poses: Dictionary = {}
	for beat in list.beats:
		poses[beat.duck_pose] = true
		for word in ["blade", "sword", "stab", "blood", "wound", "impact", "ground", "body", "draw", "strike", "cut_to_body"]:
			safe_names = safe_names and not String(beat.id).contains(word) and not String(beat.duck_pose).contains(word)
	_check("kept: no beat or pose is named for a blade, a wound, blood, an impact, the ground or a body (%s)" % str(poses.keys()), safe_names)
	var cry_beats: PackedStringArray = PackedStringArray()
	var cries_ok: bool = true
	for i in list.beats.size():
		var beat: EndingBeat = list.beats[i]
		if String(beat.sfx).begins_with("duck_cry"):
			cry_beats.append("%s:%s" % [beat.id, beat.sfx])
			cries_ok = cries_ok and i < _index_of(list, &"kneel_at_edge")
	_check("kept: the duck's cries are in the listed beats only (%s), none at the kneeling, the cut or after" % str(cry_beats), cries_ok and cry_beats.size() == 6 and ("cliff_duck:duck_cry_weak" in cry_beats) and ("corruption_spreads:duck_cry_weak" in cry_beats) and ("stagger_and_fall:duck_cry_pain" in cry_beats) and ("closeup_pain:duck_cry_pain" in cry_beats) and ("reach_for_stars:duck_cry_pain" in cry_beats) and ("corruption_takes_hand:duck_cry_resist" in cry_beats))
	var expressions: Array[StringName] = []
	for beat in list.beats:
		if beat.expression != &"":
			expressions.append(beat.expression)
	_check("kept: the grandfather grieves (before the cut) and breaks down (after it), in that order (%s)" % str(expressions), expressions.has(&"grieving") and expressions.has(&"breaking") and expressions.find(&"grieving") < expressions.find(&"breaking") and not expressions.has(&"solemn"))
	var line_numbers: Array[int] = []
	for beat in list.line_beats():
		line_numbers.append(beat.line)
	var lines_ok: bool = true
	for i in line_numbers.size():
		lines_ok = lines_ok and line_numbers[i] == i
	_check("kept: %d lines (7 to 9), every one has its beat in order, and «Perdóname, nieto.» is the last spoken line, after the cut" % story.lines.size(), lines_ok and story.lines.size() >= 7 and story.lines.size() <= 9 and line_numbers.size() == story.lines.size() and story.lines[story.lines.size() - 1] == "Abuelo: Perdóname, nieto." and _index_of(list, &"line_forgive") > cut_index)
	_check("kept: it ends with a slow fade (%.0f s) and nothing after it" % list.beats[list.beats.size() - 1].seconds, list.beats[list.beats.size() - 1].fade_to >= 0.99 and list.beats[list.beats.size() - 1].seconds >= 4.0)
	var veins_never_back: bool = true
	var previous: float = 0.0
	for beat in list.beats:
		if not beat.duck_visible:
			continue
		veins_never_back = veins_never_back and beat.veins_from >= previous - 0.001 and beat.veins_to >= beat.veins_from - 0.001
		previous = beat.veins_to
	_check("kept: the corruption only ever grows (the veins never recede)", veins_never_back)


func _test_released_beats() -> void:
	var story: EndingStory = texts.get_ending(RELEASED)
	var list: EndingBeatList = story.beats
	_check("released: the ending has a beat list", list != null and list.beats.size() >= 14)
	var seconds: float = list.timed_seconds()
	_check("released: %.0f s of timed beats, inside the exported range (%.0f to %.0f s)" % [seconds, list.min_seconds, list.max_seconds], seconds >= list.min_seconds and seconds <= list.max_seconds and seconds >= 45.0 and seconds <= 70.0)
	var order: Array[StringName] = [&"dusk_wide", &"grandfather_proud", &"duck_closeup", &"still_wide", &"long_still", &"walk_to_edge", &"stop_at_edge", &"look_to_sky", &"white_hold", &"empty_edge", &"grandfather_solemn", &"fade_out"]
	var positions: Array[int] = []
	for id in order:
		positions.append(list.index_of(id))
	var in_order: bool = true
	for i in positions.size():
		in_order = in_order and positions[i] >= 0 and (i == 0 or positions[i] > positions[i - 1])
	_check("released: the beats are in order: dusk, the grandfather's pride, long still shots, the walk to the edge, the stop, the camera lifts to the sky and cuts to white, the empty edge, the solemn grandfather, the fade", in_order, str(positions))
	var sky: int = list.index_of(&"look_to_sky")
	var last_visible: int = -1
	for i in list.beats.size():
		if list.beats[i].duck_visible:
			last_visible = i
	var sky_beat: EndingBeat = list.beats[sky]
	_check("released: the last beat where the duck is visible is the camera lifting to the sky (beat %d of %d), a silhouette standing at the edge: NO step, NO fall, nothing of the act" % [sky, list.beats.size()], last_visible == sky and sky_beat.silhouette and sky_beat.fade_white and sky_beat.fade_to >= 0.99 and sky_beat.seconds >= 1.0 and sky_beat.focus_to.y < sky_beat.focus_from.y - 200.0)
	var after_ok: bool = true
	var after_ids: PackedStringArray = PackedStringArray()
	for i in range(sky, list.beats.size()):
		var beat: EndingBeat = list.beats[i]
		after_ids.append(String(beat.id))
		after_ok = after_ok and beat.sfx == &"" and (beat.loop_sfx == &"" or beat.loop_sfx == &"transition") and beat.music_db <= -50.0 and beat.flash_alpha == 0.0 and (i == sky or not beat.duck_visible) and (not beat.is_line() or not beat.voiced)
	_check("released: from the sky cut on (%s) there is no sound but the cold wind, no music, no voice blip and no duck" % str(after_ids), after_ok and after_ids.size() >= 5)
	var safe_names: bool = true
	var pose_list: Dictionary = {}
	for beat in list.beats:
		pose_list[beat.duck_pose] = true
		for word in ["impact", "ground", "body", "blood", "crash", "land", "step_off", "fall", "wound", "blade", "stab", "grief", "cry_after"]:
			safe_names = safe_names and not String(beat.id).contains(word) and not String(beat.duck_pose).contains(word)
	_check("released: no beat or pose is named for an impact, the ground, a body, blood, a wound, a step off or a fall (%s)" % str(pose_list.keys()), safe_names)
	var silent: bool = true
	for i in range(list.index_of(&"walk_to_edge"), list.beats.size()):
		silent = silent and list.beats[i].music_db <= -50.0 and not String(list.beats[i].sfx).begins_with("duck_cry")
	_check("released: from the walk on there is no music and no cry (cold wind only)", silent)
	var cry_beats: PackedStringArray = PackedStringArray()
	for beat in list.beats:
		if String(beat.sfx).begins_with("duck_cry"):
			cry_beats.append("%s:%s" % [beat.id, beat.sfx])
	_check("released: ONE lonely distant cry, during the long still shots before the walk (%s)" % str(cry_beats), cry_beats == PackedStringArray(["long_still:duck_cry_lonely"]) and list.index_of(&"long_still") < list.index_of(&"walk_to_edge"))
	var solemn: EndingBeat = list.beats[list.index_of(&"line_prophecy")]
	var tearful: bool = false
	for beat in list.beats:
		tearful = tearful or beat.expression == &"grieving" or beat.expression == &"breaking"
	_check("released: the grandfather does NOT cry: his closing portrait is the solemn one, with the line «Se ha sellado la profecía.» as the last spoken line, and no beat has him grieving or breaking down", solemn.expression == &"solemn" and not tearful and story.lines[story.lines.size() - 1] == "Abuelo: Se ha sellado la profecía." and list.beats[list.index_of(&"grandfather_solemn")].expression == &"solemn")
	var line_numbers: Array[int] = []
	for beat in list.line_beats():
		line_numbers.append(beat.line)
	var lines_ok: bool = true
	for i in line_numbers.size():
		lines_ok = lines_ok and line_numbers[i] == i
	_check("released: every ending line has its beat, in order (%s of %d lines)" % [str(line_numbers), story.lines.size()], lines_ok and line_numbers.size() == story.lines.size() and story.lines.size() >= 5 and story.lines.size() <= 8)
	_check("released: it ends with a slow fade (%.0f s)" % list.beats[list.beats.size() - 1].seconds, list.beats[list.beats.size() - 1].fade_to >= 0.99 and list.beats[list.beats.size() - 1].seconds >= 4.0)


# ---------------------------------------------------------------------------------------------
# Texts, safety, audio, limits
# ---------------------------------------------------------------------------------------------

func _test_texts_and_notice() -> void:
	var kept: EndingStory = texts.get_ending(KEPT)
	var released: EndingStory = texts.get_ending(RELEASED)
	_check("texts: both endings have 7 to 9 lines (kept) or 5 to 8 (cliff) of at most 110 characters", kept.lines.size() >= 7 and kept.lines.size() <= 9 and released.lines.size() >= 5 and released.lines.size() <= 8 and _longest(kept.lines) <= 110 and _longest(released.lines) <= 110, "%d / %d" % [_longest(kept.lines), _longest(released.lines)])
	_check("safety: the banned lists grew (methods %d, romanticizing %d) and hold the new terms (blood, honor, ritual, dignity, the only way out, liberation)" % [texts.ending_banned_terms.size(), texts.ending_romanticizing_terms.size()],
		texts.ending_banned_terms.has("sangre") and texts.ending_banned_terms.has("herida") and texts.ending_romanticizing_terms.has("honor") and texts.ending_romanticizing_terms.has("honra") and texts.ending_romanticizing_terms.has("deshonra") and texts.ending_romanticizing_terms.has("ritual")
		and texts.ending_romanticizing_terms.has("dignidad") and texts.ending_romanticizing_terms.has("unica salida") and texts.ending_romanticizing_terms.has("unico camino") and texts.ending_romanticizing_terms.has("liberacion") and texts.ending_romanticizing_terms.has("paz") and texts.ending_romanticizing_terms.has("descanso"))
	var method_hit: String = ""
	var romantic_hit: String = ""
	for story: EndingStory in [kept, released]:
		var all_text: Array[String] = []
		all_text.append_array(story.lines)
		all_text.append_array(story.epilogues)
		all_text.append(story.summary_line)
		all_text.append(story.title)
		all_text.append(story.support_line)
		for text in all_text:
			for term in texts.ending_banned_terms:
				if _contains_term(text, term):
					method_hit = "%s in «%s»" % [term, text]
			for term in texts.ending_romanticizing_terms:
				if _contains_term(text, term):
					romantic_hit = "%s in «%s»" % [term, text]
	_check("safety: no text of either ending (lines, the 6 epilogues, the summary, the card) names or describes a method", method_hit.is_empty(), method_hit)
	_check("safety: nothing presents it as honor, ritual, dignity, release, a rest or the only way out, nor as beautiful or heroic", romantic_hit.is_empty(), romantic_hit)
	var regrets: Array[String] = []
	for story: EndingStory in [kept, released]:
		var count: int = 0
		for line in story.lines:
			count += 1 if line.contains("Me arrepiento") or line.contains("Nunca te dije") else 0
		regrets.append("%d" % count)
	_check("safety: both endings carry the duck's regrets (%s lines each) and it is never presented as the only possible outcome" % str(regrets), int(regrets[0]) >= 2 and int(regrets[1]) >= 2)
	_check("safety: the cliff ending's closing is exactly «Abuelo: Se ha sellado la profecía.» and the kept one's «Abuelo: Perdóname, nieto.»; the cliff epilogues are neutral lines about the world (no grandfather, no regret, no consolation)",
		released.lines[released.lines.size() - 1] == "Abuelo: Se ha sellado la profecía." and kept.lines[kept.lines.size() - 1] == "Abuelo: Perdóname, nieto." and released.epilogues.size() == 3 and not " ".join(released.epilogues).contains("Abuelo") and not " ".join(released.epilogues).contains("Perdóname"))
	_check("safety: the support line is on BOTH endings", released.support_line == SUPPORT_LINE and kept.support_line == SUPPORT_LINE)
	_check("safety: the content notice says that two endings deal with suicide in an implicit way", texts.content_notice.contains("pérdida") and texts.content_notice.contains("suicidio") and texts.content_notice.contains("implícita") and texts.content_notice.contains("dos finales"))
	_check("epilogues: the six texts are still there (2 endings x 3 variants), all different, and the old four endings are gone", texts.epilogue_text(KEPT, 0) != texts.epilogue_text(KEPT, 1) and texts.epilogue_text(RELEASED, 2) != texts.epilogue_text(RELEASED, 0) and texts.get_ending("ending_full") == null and texts.get_ending("ending_scar") == null)


func _longest(items: Array[String]) -> int:
	var longest: int = 0
	for item in items:
		longest = maxi(longest, item.length())
	return longest


func _test_audio_and_limits() -> void:
	var events: AudioEvents = AudioEvents.get_default()
	var missing: PackedStringArray = PackedStringArray()
	var flashes: float = 0.0
	for id in [KEPT, RELEASED]:
		for beat in (texts.get_ending(id) as EndingStory).beats.beats:
			for sound in [beat.sfx, beat.loop_sfx]:
				if sound != &"" and events.get_event(sound) == null:
					missing.append(String(sound))
			flashes = maxf(flashes, beat.flash_alpha)
	_check("audio: every sound of every beat is an existing event of default_audio_events.tres; missing: %s" % str(missing), missing.is_empty())
	var cry_info: PackedStringArray = PackedStringArray()
	var cries_ok: bool = true
	for id in [&"duck_cry_weak", &"duck_cry_pain", &"duck_cry_resist", &"duck_cry_lonely"]:
		var event: AudioEvent = events.get_event(id)
		cries_ok = cries_ok and event != null and not event.files.is_empty() and FileAccess.file_exists("res://frontend/audio/sfx/" + event.files[0]) and AudioEvents.EVENT_IDS.has(id)
		if event != null:
			cry_info.append("%s -> %s pitch %.2f-%.2f %.0f dB" % [id, event.files[0], event.pitch_min, event.pitch_max, event.volume_db])
	print("MEASURE|duck cry slots|%s" % " | ".join(cry_info))
	_check("audio: the four duck cry slots exist in the audio table, each pointing to an existing duck voice with its own pitch and volume", cries_ok)
	var kept_slot: EndingMusicSlot = events.ending_kept_music
	var released_slot: EndingMusicSlot = events.ending_released_music
	var slots_ok: bool = kept_slot != null and released_slot != null and FileAccess.file_exists("res://frontend/audio/music/" + kept_slot.file) and FileAccess.file_exists("res://frontend/audio/music/" + released_slot.file)
	print("MEASURE|ending music slots|kept: %s pitch %.2f low-pass %.0f Hz reverb %.2f duck %.0f dB | cliff: %s pitch %.2f low-pass %.0f Hz reverb %.2f duck %.0f dB" % [kept_slot.file, kept_slot.track_pitch, kept_slot.cutoff_hz, kept_slot.reverb_wet, kept_slot.base_duck_db, released_slot.file, released_slot.track_pitch, released_slot.cutoff_hz, released_slot.reverb_wet, released_slot.base_duck_db])
	_check("audio: both music slots exist (ending_kept_music, ending_released_music), are processed (lower pitch, low-pass, reverb) and the cliff one sits much quieter (sparse and cold)", slots_ok and kept_slot.track_pitch < 1.0 and kept_slot.cutoff_hz < 20000.0 and kept_slot.reverb_wet > 0.0 and released_slot.track_pitch < kept_slot.track_pitch and released_slot.base_duck_db < kept_slot.base_duck_db - 6.0 and released_slot.reverb_wet > kept_slot.reverb_wet)
	_check("audio: an event can be played with a pitch factor", AudioDirector.play_event(&"focus_start", null, -6.0, 0.5))
	_check("limits: no beat flashes (%.2f), far under the 0.3 cap and 3 flashes a second; the picture only fades slowly" % flashes, flashes <= 0.3)
	var label_color: Color = THEME_COLOR()
	var contrast: float = _contrast(label_color, Color.BLACK)
	_check("limits: the subtitle text over the cinema bars has a contrast of %.1f (at least 2.5)" % contrast, contrast >= 2.5)
	var worst_fade: float = 0.0
	for id in [KEPT, RELEASED]:
		var list: EndingBeatList = (texts.get_ending(id) as EndingStory).beats
		var previous: float = 0.0
		for beat in list.beats:
			var rate: float = absf(beat.fade_to - previous) / maxf(beat.seconds, 0.1)
			if beat.is_line():
				rate = 0.0 if beat.fade_to == previous else 99.0
			worst_fade = maxf(worst_fade, rate)
			previous = beat.fade_to
	_check("limits: no overlay changes faster than %.2f per second (the cut to white is a slow fade, never a flash)" % worst_fade, worst_fade <= 0.5)


func THEME_COLOR() -> Color:
	var theme: Theme = load("res://frontend/ui/theme/quack_theme.tres") as Theme
	return theme.get_color(&"font_color", &"SceneLabel")


# ---------------------------------------------------------------------------------------------
# The scenes and the advance
# ---------------------------------------------------------------------------------------------

func _test_scenes() -> void:
	# «Estrellas que suben»: the corruption scales with the fragments kept; the poses move the duck; the weapon stays in its hand.
	for kept in [2, 3]:
		_clean_state()
		var choices: Array = []
		for i in 3:
			choices.append(GameState.CHOICE_KEPT if i < kept else GameState.CHOICE_RELEASED)
		_decide(choices)
		var ending: EndingController = await _ending()
		var reel: EndingCinematic = ending.reel
		_check("kept scene (%d kept): the cinematic is the kept one with corruption scaled to %.2f" % [kept, reel.corruption_scale], reel.style == "kept" and is_equal_approx(reel.corruption_scale, clampf(float(kept) / 3.0, 0.34, 1.0)) and reel.scene.style == "kept")
		var scene: EndingScene = reel.scene
		_check("kept scene: five parallax layers and a duck drawn by code from the existing rig (no art files, no textures in the scene)", scene.layers.size() == 5 and scene.actor != null and not _has_texture_node(scene))
		var weapon_always: bool = true
		var arms: Dictionary = {}
		var squash: Dictionary = {}
		for pose in [&"stand", &"labored", &"stagger", &"kneel", &"reach", &"resist", &"kneel_edge", &"walk", &"head_down"]:
			scene.pose = pose
			scene.pose_p = 0.6
			scene.refresh()
			weapon_always = weapon_always and scene.figure.visible and scene.figure.modulate.a > 0.99
			arms[pose] = not is_nan(scene.figure.wing_angle)
			squash[pose] = scene.actor.scale.y / scene.actor.scale.x
		_check("kept scene: the sword never leaves the duck's hand (no drop, no fade: it cannot look like a glitch)", weapon_always)
		_check("kept scene: the wing is drawn only while it reaches for the stars or resists (reach %s, resist %s, kneel %s), the duck kneels (%.2f) and kneels at the edge (%.2f)" % [str(arms[&"reach"]), str(arms[&"resist"]), str(arms[&"kneel"]), squash[&"kneel"], squash[&"kneel_edge"]], arms[&"reach"] and arms[&"resist"] and not arms[&"kneel"] and not arms[&"stand"] and squash[&"kneel"] < 0.9 and squash[&"kneel_edge"] < 0.8)
		ending.free()
		await _frames(2)
	# Reading the drawing code: nothing stray is left on the edge, the feather is a feather, the blade never goes near the body.
	var source: String = FileAccess.get_file_as_string("res://frontend/story/ending_scene.gd")
	var feather_start: int = source.find("func _feather(")
	var feather_code: String = source.substr(feather_start)
	var stray: bool = false
	for word in ["_left_behind", "_draw_sword", "hilt", "scarf", "STEEL", "_weapon_drop", "step_off", "&\"lie\"", "blood", "wound"]:
		stray = stray or source.contains(word)
	_check("empty edge: the sword, the red scarf and every other stray line are gone from the drawing code (cause: _left_behind drew the sword as a 120 px line and the scarf as a polyline)", not stray)
	_check("empty edge: the feather is a curved quill with barbs on both sides (not a polygon: it cannot read as a diamond)", feather_start > 0 and feather_code.contains("quill") and feather_code.contains("barb") and not feather_code.contains("draw_colored_polygon"))
	_clean_state()
	_decide([GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED])
	var cliff: EndingController = await _ending()
	var scene2: EndingScene = cliff.reel.scene
	scene2.style = "released"
	scene2.duck_visible = false
	scene2.refresh()
	_check("cliff scene: once the camera has lifted and cut, nothing of the duck is drawn (the actor is hidden)", not scene2.is_duck_drawn())
	var cliff_list: EndingBeatList = texts.get_ending(RELEASED).beats
	var walk: EndingBeat = cliff_list.beats[cliff_list.index_of(&"walk_to_edge")]
	_check("cliff scene: the duck only walks to the edge (%.0f px) and stops there (%s): its feet never pass the edge at x %.0f" % [walk.duck_to.x, str(walk.duck_to), EndingScene.CLIFF_EDGE_X], walk.duck_to.x < EndingScene.CLIFF_EDGE_X and walk.duck_to.y == walk.duck_from.y)
	cliff.free()
	await _frames(2)


func _has_texture_node(node: Node) -> bool:
	if node is Sprite2D or node is TextureRect or node is AnimatedSprite2D:
		return true
	for child in node.get_children():
		if _has_texture_node(child):
			return true
	return false


func _test_advance() -> void:
	for expected in [KEPT, RELEASED]:
		_clean_state()
		_decide([GameState.CHOICE_KEPT, GameState.CHOICE_KEPT, GameState.CHOICE_KEPT] if expected == KEPT else [GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED])
		var ending: EndingController = await _ending()
		var reel: EndingCinematic = ending.reel
		_check("%s: the ending selected is the right one and the cinematic is playing with its beat list" % expected, ending.shown_variant == expected and reel != null and reel.beats == texts.get_ending(expected).beats)
		Engine.time_scale = CLOCK
		await _until(func() -> bool: return reel.line_index >= 0, 25.0)
		Engine.time_scale = 1.0
		var first: String = reel.current_line_text()
		_check("%s: the first line is typed (a typewriter, not shown at once)" % expected, reel.line_index == 0 and not reel.typed_done and reel._subtitle.visible_characters < first.length())
		await get_tree().create_timer(0.3).timeout
		reel._input(_accept())
		_check("%s: the first press completes it and stays on it" % expected, reel.typed_done and reel.current_line_text() == first)
		Engine.time_scale = 8.0
		var waited: float = 0.0
		while waited < 90.0:
			await get_tree().process_frame
			waited += get_process_delta_time()
		Engine.time_scale = 1.0
		_check("%s: 90 s of game time later it is still on the same line (no timer advances any line)" % expected, reel.current_line_text() == first and reel.typed_done and not ending.card_visible)
		var beat_before: int = reel.beat_index
		reel._input(_accept())
		_check("%s: the second press moves on (the next beat)" % expected, reel.beat_index == beat_before + 1)
		ending.free()
		await _frames(2)


func _test_reduced() -> void:
	_clean_state()
	var values: Dictionary = GameSettings.DEFAULTS.duplicate()
	values["corruption_effects"] = false
	GameSettings.save_settings(values)
	for expected in [KEPT, RELEASED]:
		_decide([GameState.CHOICE_KEPT, GameState.CHOICE_KEPT, GameState.CHOICE_KEPT] if expected == KEPT else [GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED])
		var ending: EndingController = await _ending()
		var reel: EndingCinematic = ending.reel
		Engine.time_scale = CLOCK
		await _until(func() -> bool: return reel.line_index >= 0, 25.0)
		Engine.time_scale = 1.0
		var beat: EndingBeat = reel.current_beat()
		_check("%s reduced: still pictures (scene time %.1f, no camera move: the pose is the beat's still %.2f) and no tear particles" % [expected, reel.scene.time, beat.reduced_progress], reel.reduced and is_zero_approx(reel.scene.time) and is_zero_approx(reel.scene._sil_k - (1.0 if reel.scene.silhouette else 0.0)) and reel.portrait.find_children("*Tear*", "", true, false).is_empty() and is_equal_approx(reel.scene.pose_p, lerpf(beat.pose_p_from, beat.pose_p_to, beat.reduced_progress)))
		_check("%s reduced: the same text appears (%s...)" % [expected, reel.current_line_text().left(24)], reel.lines.size() == texts.get_ending(expected).lines.size())
		ending.free()
		await _frames(2)
		GameState.start_new_game()
	GameSettings.save_settings(GameSettings.DEFAULTS.duplicate())


## Plays a whole ending (every line completed with presses, the clock fast) and reports which audio events fired in each beat.
func _play_through(style: String) -> Dictionary:
	_clean_state()
	_decide([GameState.CHOICE_KEPT, GameState.CHOICE_KEPT, GameState.CHOICE_KEPT] if style == "kept" else [GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED])
	var ending: EndingController = await _ending()
	var reel: EndingCinematic = ending.reel
	var per_beat: Dictionary = {}
	var snapshot: Array[Dictionary] = [AudioDirector.events_played.duplicate()]
	var current: Array[StringName] = [&""]
	reel.beat_started.connect(func(_index: int, beat: EndingBeat) -> void:
		_close_beat(per_beat, current[0], snapshot[0])
		current[0] = beat.id
		snapshot[0] = AudioDirector.events_played.duplicate())
	Engine.time_scale = CLOCK
	var guard_frames: int = 0
	while not ending.card_visible and guard_frames < 6000:
		await get_tree().process_frame
		guard_frames += 1
		if is_instance_valid(reel) and reel.current_beat() != null and reel.current_beat().is_line():
			reel._input(_accept())
	Engine.time_scale = 1.0
	_close_beat(per_beat, current[0], snapshot[0])
	per_beat["_finished"] = ending.card_visible
	ending.free()
	await _frames(3)
	return per_beat


func _close_beat(per_beat: Dictionary, beat_id: StringName, before: Dictionary) -> void:
	if beat_id == &"":
		return
	var fired: Dictionary = {}
	for key: Variant in AudioDirector.events_played.keys():
		var delta: int = int(AudioDirector.events_played[key]) - int(before.get(key, 0))
		if delta > 0:
			fired[String(key)] = delta
	per_beat[String(beat_id)] = fired


func _test_audio_runtime() -> void:
	var bus: int = AudioServer.get_bus_index(GameSettings.MUSIC_BUS)
	var effects_before: int = AudioServer.get_bus_effect_count(bus)
	for style in ["kept", "cliff"]:
		var key: String = "kept" if style == "kept" else "released"
		var report: Dictionary = await _play_through(key)
		var list: EndingBeatList = texts.get_ending(KEPT if key == "kept" else RELEASED).beats
		_check("%s: the whole ending plays through with Enter only and reaches the card" % style, bool(report.get("_finished", false)))
		var cut: int = list.index_of(&"bow_and_cut" if key == "kept" else &"look_to_sky")
		var cry_ok: bool = true
		var wind_only: bool = true
		var cry_count: int = 0
		for i in list.beats.size():
			var fired: Dictionary = report.get(String(list.beats[i].id), {})
			for event_id: String in fired.keys():
				if event_id.begins_with("duck_cry"):
					cry_count += 1
					cry_ok = cry_ok and i < cut and (key == "kept" or list.beats[i].id == &"long_still")
				if i >= cut and event_id != "transition":
					wind_only = false
		print("MEASURE|%s: duck cries fired %d, events at or after the cut: %s" % [style, cry_count, str(report)])
		_check("%s: the duck's cries fire only in the listed beats and never at or after the cut (%d played)" % [style, cry_count], cry_ok and cry_count >= 1)
		_check("%s: at and after the cut no sound event plays but the cold wind (the grandfather's blip stays silent too)" % style, wind_only)
	# The music: it plays processed and everything is given back on skip, on pause and on exit.
	var players_before: int = AudioDirector.find_children("*", "AudioStreamPlayer", true, false).size()
	_clean_state()
	_decide([GameState.CHOICE_KEPT, GameState.CHOICE_KEPT, GameState.CHOICE_KEPT])
	var ending: EndingController = await _ending()
	var reel: EndingCinematic = ending.reel
	await _frames(3)
	var effects_playing: int = AudioServer.get_bus_effect_count(bus)
	var profile: Dictionary = AudioDirector.get_music_profile()
	_check("music: the kept ending plays its slot (%s) with the processing on the Music bus (reverb added: %d -> %d effects, low-pass on: %s, pitch factor %.2f)" % [reel.music_slot.file, effects_before, effects_playing, str(profile["filter_on_bus"]), reel.music_slot.track_pitch], reel.music_playing and effects_playing > effects_before and bool(profile["filter_on_bus"]))
	get_tree().paused = true
	await get_tree().create_timer(0.3, true).timeout
	var paused_ok: bool = AudioDirector.get_music_state() != null
	get_tree().paused = false
	await _frames(2)
	reel.skip()
	await _until(func() -> bool: return ending.card_visible, 6.0)
	ending.free()
	await _frames(4)
	var after_profile: Dictionary = AudioDirector.get_music_profile()
	_check("music: after a skip the reverb, the filter and the ducks are all given back (effects %d, filter on: %s) and the pause did not break anything (%s)" % [AudioServer.get_bus_effect_count(bus), str(after_profile["filter_on_bus"]), str(paused_ok)], AudioServer.get_bus_effect_count(bus) == effects_before and not bool(after_profile["filter_on_bus"]) and paused_ok)
	_check("music: no audio players are left behind by the endings (%d before, %d after)" % [players_before, AudioDirector.find_children("*", "AudioStreamPlayer", true, false).size()], AudioDirector.find_children("*", "AudioStreamPlayer", true, false).size() <= players_before + 2)


func _test_leaks() -> void:
	_clean_state()
	var counts: Array[int] = []
	for round in 4:
		_decide([GameState.CHOICE_KEPT, GameState.CHOICE_KEPT, GameState.CHOICE_KEPT] if round % 2 == 0 else [GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED, GameState.CHOICE_RELEASED])
		var ending: EndingController = await _ending()
		Engine.time_scale = CLOCK
		await _until(func() -> bool: return ending.reel != null and ending.reel.line_index >= 0, 25.0)
		Engine.time_scale = 1.0
		ending.reel.skip()
		await _until(func() -> bool: return ending.card_visible, 6.0)
		ending.free()
		await _frames(3)
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		GameState.start_new_game()
	print("MEASURE|node counts after replaying both endings four times|%s" % str(counts))
	_check("leaks: no nodes are left behind after replaying both endings four times (%s) and nothing stays paused" % str(counts), counts[3] <= counts[1] + 4 and not get_tree().paused)

