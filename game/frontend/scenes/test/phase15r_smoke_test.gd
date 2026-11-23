extends Node
## Headless smoke test for Phase 15r: the grandfather shown from his own full-body figure (only the face clear, no drawn face, no tears), the silhouette
## beats of both endings (flat dark shapes over the white, no contact, no blood, no fall), and the soul spirit of each guardian (it says the last words, then
## dissolves into the fragment). Development only. Run:
##   <godot> --headless --path game res://frontend/scenes/test/phase15r_smoke_test.tscn
## Uses a redirected save path and a temporary settings file; the AI service stays disabled; the real files are never touched.

const TEST_SAVE: String = "user://test_save_phase15r.json"
const TEST_SETTINGS: String = "user://test_settings_phase15r.cfg"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const LEVELS: Array[String] = ["res://frontend/levels/level_1.tscn", "res://frontend/levels/level_2.tscn", "res://frontend/levels/level_3.tscn"]
const ENDING_SCENE: PackedScene = preload("res://frontend/ui/ending.tscn")
const SUPPORT_LINE: String = "Si tú o alguien que conoces está pasando por algo así, habla con alguien de confianza o con un servicio de salud mental de tu país. No estás solo."
const BANNED_IN_CODE: Array[String] = ["blood", "wound", "stab", "impact", "pierce", "gore", "sangre", "herida"]
const SPEAKERS: Array[String] = ["Alma del Leñador", "Alma de la Cosa del Pantano", "Alma del Ojo de la Tormenta"]

var failures: int = 0
var real_save_before: String = ""
var real_settings_before: String = ""
var real_controls_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig
var texts: StoryTexts = null


func _ready() -> void:
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	GameSettings.path_override = TEST_SETTINGS
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
	real_settings_before = _read_file(GameSettings.PATH)
	real_controls_before = _read_file(ControlsConfig.DEFAULT_PATH)
	texts = StoryTexts.get_default()
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


## Real seconds (the clock is never sped up here).
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


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


func _run() -> void:
	_clean_state()
	var nodes_before: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_test_guards()
	await _test_grandfather()
	await _test_silhouettes()
	await _test_ending_wiring()
	await _test_spirit_flow(0, false)
	await _test_spirit_flow(1, true)
	await _test_spirit_flow(2, true)
	await _test_spirit_reduced()
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
	var classes: PackedStringArray = PackedStringArray()
	for entry in ProjectSettings.get_global_class_list():
		classes.append(String(entry["class"]))
	_check("the drawn face is retired: no GrandfatherPortrait class or file, and nothing in the game code still names it",
		not classes.has("GrandfatherPortrait") and not FileAccess.file_exists("res://frontend/story/grandfather_portrait.gd") and not _any_source_mentions("res://frontend", "GrandfatherPortrait") and not _any_source_mentions("res://backend", "GrandfatherPortrait"))
	_check("the new classes exist (GrandfatherSky, EndingSilhouette, GuardianSpirit)", classes.has("GrandfatherSky") and classes.has("EndingSilhouette") and classes.has("GuardianSpirit"))


func _any_source_mentions(dir_path: String, word: String) -> bool:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return false
	for file in dir.get_files():
		if file.ends_with(".gd") and FileAccess.get_file_as_string(dir_path + "/" + file).contains(word):
			return true
	for sub in dir.get_directories():
		if sub == "test":
			continue
		if _any_source_mentions(dir_path + "/" + sub, word):
			return true
	return false


# ---------------------------------------------------------------------------------------------
# 1. The grandfather from his full-body figure
# ---------------------------------------------------------------------------------------------

func _test_grandfather() -> void:
	var presentation: GrandfatherPresentation = GrandfatherPresentation.get_default()
	_check("grandfather: opacity about 0.4 at levels 1 and 2 (%.2f), about 0.6 at level 3 (%.2f), about 0.7 in the endings (%.2f)" % [presentation.face_memory_alpha, presentation.face_solid_alpha, presentation.face_ending_alpha],
		absf(presentation.face_memory_alpha - 0.4) < 0.02 and absf(presentation.face_solid_alpha - 0.6) < 0.02 and absf(presentation.face_ending_alpha - 0.7) < 0.02)
	var alphas: Array[float] = []
	var clean: bool = true
	var own_figure: bool = true
	for number in [1, 2, 3]:
		var face := GrandfatherFace.new()
		face.setup(presentation, number, false)
		add_child(face)
		await _wait(presentation.fade_in_time + 0.4)
		alphas.append(face.portrait.alpha)
		var sky: GrandfatherSky = face.portrait
		own_figure = own_figure and sky != null and sky.rig != null and sky.rig.look == DuckRig.Look.GRANDFATHER and sky.viewport != null
		clean = clean and sky.get_child_count() == 3 and sky.find_children("*Tear*", "", true, false).is_empty() and face.find_children("*Tear*", "", true, false).is_empty()
		face.free()
	_check("grandfather: the level start uses his own full-body figure (DuckRig, look GRANDFATHER) at every level, with no tear or overlay nodes (%s)" % str(alphas), own_figure and clean)
	_check("grandfather: the opacity reached at levels 1, 2 and 3 is the one of the context (%.2f, %.2f, %.2f)" % [alphas[0], alphas[1], alphas[2]],
		absf(alphas[0] - 0.4) < 0.03 and absf(alphas[1] - 0.4) < 0.03 and absf(alphas[2] - 0.6) < 0.03)
	var sky := GrandfatherSky.new()
	sky.alpha = 0.7
	add_child(sky)
	await _frames(3)
	var shader_code: String = ((sky.get_node("Picture") as Sprite2D).material as ShaderMaterial).shader.code
	_check("grandfather: the body is hidden by a soft mask and the face is blurred by a low-resolution picture (mask and blur in the shader, picture %s)" % str(sky.viewport.size),
		shader_code.contains("smoothstep") and shader_code.contains("blur") and sky.viewport.size.x <= 256 and sky.viewport.transparent_bg)
	sky.set_expression(&"grieving")
	await _wait(1.2)
	var grief: float = sky.grief
	sky.set_expression(&"watching")
	await _wait(1.2)
	_check("grandfather: grief is a lowered head and a dimmer glow (grief %.2f, then %.2f), not drawn tears" % [grief, sky.grief], grief > 0.4 and sky.grief < 0.1 and sky.rig.rotation < grief * presentation.sky_grief_tilt + 0.01)
	sky.free()


# ---------------------------------------------------------------------------------------------
# 2. Silhouette beats
# ---------------------------------------------------------------------------------------------

func _test_silhouettes() -> void:
	var kept: EndingBeatList = texts.get_ending("ending_kept").beats
	var released: EndingBeatList = texts.get_ending("ending_released").beats
	var kept_cut: EndingBeat = kept.beats[kept.index_of(&"bow_and_cut")]
	var kept_white: EndingBeat = kept.beats[kept.index_of(&"white_hold")]
	var kept_after: EndingBeat = kept.beats[kept.index_of(&"empty_edge")]
	var cliff_cut: EndingBeat = released.beats[released.index_of(&"look_to_sky")]
	var cliff_white: EndingBeat = released.beats[released.index_of(&"white_hold")]
	var cliff_after: EndingBeat = released.beats[released.index_of(&"empty_edge")]
	_check("kept ending: the cut to white is slow (%.1f s) and the white hold shows the kneeling silhouette with the sword planted beside it (%s), then the lying one (%s)" % [kept_cut.seconds, kept_white.white_silhouette, kept_after.white_silhouette],
		kept_cut.fade_white and kept_cut.fade_to >= 1.0 and kept_cut.seconds >= 1.0 and kept_white.white_silhouette == EndingSilhouette.KNEEL_SWORD and kept_after.white_silhouette == EndingSilhouette.LYING_SWORD and kept_white.seconds >= 2.0)
	_check("cliff ending: the cut to white is slow (%.1f s) and the white hold shows the duck standing at the edge looking at the sky, which fades out (%s %.1f to %.1f); after the white the edge is empty with the sword and the hat (%s)" % [cliff_cut.seconds, cliff_white.white_silhouette, cliff_white.white_silhouette_from, cliff_white.white_silhouette_to, str(cliff_after.leave_items)],
		cliff_cut.fade_white and cliff_cut.fade_to >= 1.0 and cliff_cut.seconds >= 1.0 and cliff_white.white_silhouette == EndingSilhouette.EDGE_SKY and cliff_white.white_silhouette_to < cliff_white.white_silhouette_from and cliff_after.leave_items and not cliff_after.duck_visible)
	_check("cliff ending: the beats keep their sounds cold (no cry or music swell at or after the cut)", _quiet_after_cut(released, &"white_hold") and _quiet_after_cut(kept, &"white_hold"))
	var bad_pose: bool = false
	for list in [kept, released]:
		for beat in list.beats:
			var pose: String = String(beat.duck_pose)
			bad_pose = bad_pose or pose.contains("jump") or pose.contains("fall") or pose.contains("step_off") or pose.contains("leap")
	_check("safety: no beat of either ending has the duck jumping, falling or stepping off", not bad_pose)
	_check("safety: only three silhouette stills exist (kneel with the sword planted, lying, standing at the edge)", EndingSilhouette.KINDS.size() == 3)
	for kind in EndingSilhouette.KINDS:
		var sil := EndingSilhouette.new()
		add_child(sil)
		sil.kind = kind
		sil.alpha = 1.0
		await _frames(3)
		var shader_code: String = (sil.figure.material as ShaderMaterial).shader.code
		var flat: bool = shader_code.contains("step(") and not shader_code.contains("texture(")
		var sword: Rect2 = sil.sword_rect()
		var body: Rect2 = sil.body_rect()
		var apart: bool = sword.size == Vector2.ZERO or (sword.position.x - body.end.x >= 40.0 or body.position.x - sword.end.x >= 40.0)
		var upright: bool = sword.size == Vector2.ZERO or sword.size.y > sword.size.x * 8.0
		var pose_ok: bool = sil.figure.pose_name in [&"kneel_edge", &"lie", &"stand"]
		var grounded: bool = sil.duck_feet().y <= EndingSilhouette.GROUND_Y + 1.0
		var no_wing_weapon: bool = sil.figure.wing_angle == sil.figure.wing_angle
		_check("silhouette %s: a flat dark shape of the duck's own rig (one colour, no weapon in the rig), the sword stands apart from the body (gap %.0f px) and the duck never leaves the ground" % [kind, (sword.position.x - body.end.x) if sword.size != Vector2.ZERO else 0.0],
			flat and apart and upright and pose_ok and grounded and no_wing_weapon and sil.figure.corruption_stage == 0)
		sil.free()
	var sil_source: String = FileAccess.get_file_as_string("res://frontend/story/ending_silhouette.gd").to_lower()
	var scene_source: String = FileAccess.get_file_as_string("res://frontend/story/ending_scene.gd")
	var items_start: int = scene_source.find("func _left_items(")
	var items_source: String = scene_source.substr(items_start, scene_source.find("\n\n\n", items_start) - items_start).to_lower()
	var banned_hit: String = ""
	for word in BANNED_IN_CODE:
		if sil_source.contains(word) or items_source.contains(word):
			banned_hit = word
	_check("safety: nothing in the silhouette code or the left items names blood, a wound, a stab or an impact (%s)" % banned_hit, banned_hit.is_empty())
	var kept_story: EndingStory = texts.get_ending("ending_kept")
	var released_story: EndingStory = texts.get_ending("ending_released")
	var text_hit: String = ""
	for story: EndingStory in [kept_story, released_story]:
		var all_text: Array[String] = []
		all_text.append_array(story.lines)
		all_text.append_array(story.epilogues)
		all_text.append(story.summary_line)
		for text in all_text:
			for term in texts.ending_banned_terms:
				if text.to_lower().contains(String(term).to_lower()):
					text_hit = String(term)
	_check("safety: no ending text names a method, the support line is on BOTH final cards and the content notice stays (%s)" % text_hit, text_hit.is_empty() and kept_story.support_line == SUPPORT_LINE and released_story.support_line == SUPPORT_LINE and texts.content_notice.contains("suicidio"))


## True when no beat from `from_id` on has a cry or a swell: its sounds are the cold wind only.
func _quiet_after_cut(list: EndingBeatList, from_id: StringName) -> bool:
	var seen: bool = false
	for beat in list.beats:
		if beat.id == from_id:
			seen = true
		if seen:
			var sound: String = String(beat.sfx)
			if sound.begins_with("duck_cry") or sound == "soul_gain":
				return false
	return true


# ---------------------------------------------------------------------------------------------
# 3. The cinematic wiring (silhouette above the white, items at the edge, reduced mode)
# ---------------------------------------------------------------------------------------------

func _test_ending_wiring() -> void:
	for expected in ["ending_kept", "ending_released"]:
		for reduced in [false, true]:
			_clean_state()
			_set_options({"corruption_effects": not reduced})
			var decision: String = GameState.CHOICE_KEPT if expected == "ending_kept" else GameState.CHOICE_RELEASED
			for i in 3:
				GameState.record_decision("fragment_wiring_%d" % i, "boss", i + 1, decision)
			var ending := ENDING_SCENE.instantiate() as EndingController
			ending.skip_reel_when_headless = false
			add_child(ending)
			await _frames(4)
			var reel: EndingCinematic = ending.reel
			var list: EndingBeatList = reel.beats
			var white_index: int = list.index_of(&"white_hold")
			var after_index: int = list.index_of(&"empty_edge")
			reel._enter_beat(white_index)
			reel._update_scene(list.beats[white_index])
			var in_white: String = String(reel.white_silhouette.kind)
			var alpha_white: float = reel.white_silhouette.alpha
			var above: bool = reel.white_silhouette.get_index() > reel._fade.get_index()
			reel._enter_beat(after_index)
			reel._update_scene(list.beats[after_index])
			var items: bool = reel.scene.items_left
			_check("%s%s: the silhouette is drawn above the white (%s, opacity %.2f) and, after the white, the items at the edge are %s" % [expected, " (reduced)" if reduced else "", in_white, alpha_white, str(items)],
				reel.reduced == reduced and above and in_white == String(list.beats[white_index].white_silhouette) and alpha_white > 0.9 and items == (expected == "ending_released") and reel.white_silhouette.reduced == reduced)
			ending.free()
			await _frames(2)
	_clean_state()


# ---------------------------------------------------------------------------------------------
# 4. The guardian soul spirit
# ---------------------------------------------------------------------------------------------

func _level(number: int) -> LevelBase:
	var level := (load(LEVELS[number]) as PackedScene).instantiate() as LevelBase
	for junk in ["LevelTitleCard", "ElderScene"]:
		if level.get_node_or_null(junk) != null:
			level.get_node(junk).free()
	add_child(level)
	return level


func _find_fragment() -> SoulFragment:
	for root in [get_tree().current_scene, self]:
		if root == null:
			continue
		for child in root.get_children():
			if child is SoulFragment:
				return child as SoulFragment
	return null


func _spirits_of(level: Node) -> Array[Node]:
	return level.find_children("*", "GuardianSpirit", true, false)


func _dialogue_of(level: Node) -> BossDialogue:
	for node in level.find_children("*", "BossDialogue", true, false):
		return node as BossDialogue
	return null


## The defeat of guardian `number` (0, 1, 2): the spirit, the words, then either every line read (`skip` false) or a skip.
func _test_spirit_flow(number: int, skip: bool) -> void:
	_clean_state()
	var tag: String = "guardian %d" % (number + 1)
	var level: LevelBase = _level(number)
	await _frames(6)
	level.advance_delay = 60.0
	var dialogue: BossDialogue = _dialogue_of(level)
	var visual: Node = level.boss.get_node("Visual")
	var expected_look: int = int(visual.get(&"look"))
	level.boss.hurtbox.receive_hit(DamageInfo.create(9999, Vector2.ZERO, level.player, CombatLayers.Team.PLAYER))
	await _frames(4)
	var spirits: Array[Node] = _spirits_of(level)
	var spirit: GuardianSpirit = spirits[0] as GuardianSpirit if not spirits.is_empty() else null
	_check("%s: its soul spirit appears where it fell, once (%d), as the same figure (look %d)" % [tag, spirits.size(), expected_look], spirits.size() == 1 and spirit != null and int(spirit.look) == expected_look and dialogue.spirits_spawned == 1)
	if spirit == null:
		level.free()
		return
	var spirit_target: Vector2 = spirit.target
	_check("%s: the spirit is translucent blue with a slow flicker under the photosensitivity limit and has no hitbox, hurtbox or damage" % tag,
		spirit.config.opacity > 0.45 and spirit.config.opacity < 0.65 and spirit.config.tint.b > spirit.config.tint.r and spirit.config.flicker_hz <= 3.0 and spirit.find_children("*", "CollisionObject2D", true, false).is_empty())
	var waited: float = 0.0
	while not dialogue.is_speaking() and waited < 5.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check("%s: the last words are SPOKEN BY THE SPIRIT («%s»), the player is locked and safe and the fragment waits" % [tag, dialogue.current_text().left(34)],
		dialogue.is_speaking() and dialogue.current_text().begins_with(SPEAKERS[number] + ":") and level.player.is_input_locked() and level.player.story_invulnerable and level.fragment_drop.is_held() and _find_fragment() == null and spirit.state != GuardianSpirit.State.DONE)
	await _wait(1.3)
	_check("%s: after its fade-in the spirit hovers at its opacity (%.2f) and wisps are drawn" % [tag, spirit.strength], spirit.state == GuardianSpirit.State.HOLD and spirit.strength > spirit.config.opacity - 0.02 and spirit.rig.position != Vector2.ZERO)
	if skip:
		dialogue.skip()
		await _frames(2)
		_check("%s: a skip goes straight to the crystal: the spirit is gone at once" % tag, not is_instance_valid(spirit) or spirit.is_done())
	else:
		var guard: int = 0
		while dialogue.is_speaking() and guard < 40:
			dialogue.advance()
			await _frames(2)
			guard += 1
		await _frames(2)
		_check("%s: after the last line the spirit dissolves into particles that stream to the fragment spot (state %d, %d particles) and the fragment still waits" % [tag, spirit.state if is_instance_valid(spirit) else -1, spirit.particles.size() if is_instance_valid(spirit) else -1],
			is_instance_valid(spirit) and spirit.state == GuardianSpirit.State.DISSOLVING and level.fragment_drop.is_held() and _find_fragment() == null and level.player.is_input_locked())
		await _wait(0.5)
		_check("%s: particles are in flight (%d) and the body is fading (%.2f)" % [tag, spirit.particles.size() if is_instance_valid(spirit) else 0, spirit.strength if is_instance_valid(spirit) else 0.0], not is_instance_valid(spirit) or (spirit.particles.size() > 10 and spirit.strength < spirit.config.opacity))
	var fragment_wait: float = 0.0
	while _find_fragment() == null and fragment_wait < 4.0:
		await get_tree().process_frame
		fragment_wait += get_process_delta_time()
	var fragment: SoulFragment = _find_fragment()
	_check("%s: the fragment condenses where the particles went (%.1f s after the last line)" % [tag, fragment_wait], fragment != null and fragment.global_position.distance_to(spirit_target) < 3.0 and fragment_wait < 3.0)
	await _frames(3)
	_check("%s: the player is free and vulnerable afterwards, nothing is paused, and the spirit is gone for good" % tag, not level.player.is_input_locked() and not level.player.story_invulnerable and not get_tree().paused and _spirits_of(level).is_empty() and dialogue.spirits_spawned == 1 and dialogue.defeat_sequences == 1)
	if not skip and fragment != null:
		level.player.global_position = fragment.global_position
		var panel := level.get_node("DecisionPanel") as DecisionPanel
		var opened_wait: float = 0.0
		while not panel.is_open() and opened_wait < 3.0:
			await get_tree().process_frame
			opened_wait += get_process_delta_time()
		_check("%s: the fragment decision follows (the panel opens)" % tag, panel.is_open())
	_clean_state()
	level.free()
	if is_instance_valid(fragment):
		fragment.free()
	await _frames(3)


func _test_spirit_reduced() -> void:
	_clean_state()
	var live := GuardianSpirit.new()
	live.setup(DuckRig.Look.BOSS_SWAMP, Vector2(300.0, 300.0), Vector2.ONE * DuckRig.BOSS_SCALE, false, Vector2(500.0, 240.0))
	add_child(live)
	var still := GuardianSpirit.new()
	still.setup(DuckRig.Look.BOSS_WOODCUTTER, Vector2(700.0, 300.0), Vector2.ONE * DuckRig.BOSS_SCALE, true, Vector2(900.0, 240.0))
	add_child(still)
	await _wait(1.4)
	_check("spirit (normal): it hovers and rises (offset %.1f)" % live.rig.position.y, live.rig.position.y < -1.0)
	_check("spirit (reduced): a still figure at its opacity: no hover, no rise, no flicker (offset %.1f, strength %.2f)" % [still.rig.position.y, still.strength], is_zero_approx(still.rig.position.y) and is_equal_approx(still.strength, still.config.opacity) and is_equal_approx(still.rig.modulate.a, still.config.opacity))
	var arrived: Array[bool] = [false]
	still.dissolved.connect(func() -> void: arrived[0] = true)
	still.dissolve()
	var peak: int = 0
	var waited: float = 0.0
	while is_instance_valid(still) and not arrived[0] and waited < 3.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if is_instance_valid(still):
			peak = maxi(peak, still.particles.size())
	_check("spirit (reduced): a plain fade of %.1f s with no particles (%d) and the fragment is released after it (%.2f s)" % [still.config.reduced_fade_seconds if is_instance_valid(still) else 0.6, peak, waited], arrived[0] and peak == 0 and waited < 1.5)
	live.vanish_now()
	await _frames(3)
	_check("spirit: vanishing is immediate and the node frees itself (no leak)", not is_instance_valid(live))
	_clean_state()
