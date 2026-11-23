extends Node
## Headless smoke test for Phase 14b (decisions with consequences): the immediate adaptive rule for
## all 8 decision combinations, the max-health reward for released souls (and respawn), the health
## HUD layout at 8 and 11 points, the corruption indicator, the level intro / consequence lines per
## profile (level 1 included), the decision and phase-2 sounds, the debug keys and the prologue's
## headless path. Development only. Run:
##   <godot> --headless --path game res://frontend/scenes/test/phase14b_smoke_test.tscn
## Uses a redirected save path; the AI service stays disabled; the real save is never touched.

const TEST_SAVE: String = "user://test_save_phase14b.json"
const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://frontend/ui/player_health_hud.tscn")
const BOSS_TWO: PackedScene = preload("res://backend/bosses/boss_two.tscn")
const PROLOGUE_SCENE: PackedScene = preload("res://frontend/prologue/prologue_cutscene.tscn")
const TEXTS: DecisionTexts = preload("res://backend/decisions/default_decision_texts.tres")
const LEVEL_PATHS: Dictionary = {
	0: "res://frontend/levels/tutorial.tscn",
	1: "res://frontend/levels/level_1.tscn",
	2: "res://frontend/levels/level_2.tscn",
	3: "res://frontend/levels/level_3.tscn",
}
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const COMP: String = "compassionate"
const NEUT: String = "neutral"
const CORR: String = "corrupt"
const REL: String = "released"
const KEP: String = "kept"

var failures: int = 0
var real_save_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig


func _ready() -> void:
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
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


func _run() -> void:
	_test_rule_table()
	_test_config_and_save()
	_test_texts()
	await _test_player_health()
	await _test_hud()
	await _test_level_lines()
	await _test_audio_wiring()
	await _test_debug_keys()
	await _test_prologue_headless()
	_clean_state()
	SaveSystem.purge()
	GameState.autosave_enabled = true
	var real_save_after: String = _read_file(SaveSystem.DEFAULT_PATH)
	_check("the real save file was not touched", real_save_after == real_save_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------------------------------------
# 1. The immediate rule, all 8 combinations
# ---------------------------------------------------------------------------------------------

func _expected_profile(score: int) -> String:
	if score >= 1:
		return COMP
	if score <= -1:
		return CORR
	return NEUT


func _test_rule_table() -> void:
	var config: AdaptiveConfig = GameState.get_adaptive_config()
	_check("config: threshold is 1.0 and the remote may not move the profile",
		is_equal_approx(config.decision_margin_threshold, 1.0) and config.max_profile_distance == 0)
	print("TABLE: decisions (L1 L2 L3) -> profile for L2 | profile for L3 | ending variant")
	for mask in 8:
		var choices: Array[String] = []
		for i in 3:
			choices.append(REL if (mask >> i) & 1 == 1 else KEP)
		_clean_state()
		var profiles: Array[String] = []
		var score: int = 0
		var ok: bool = true
		for i in 3:
			GameState.record_decision("p14b_%d" % i, "boss", i + 1, choices[i])
			GameState.refresh_adaptive_profile()
			score += 1 if choices[i] == REL else -1
			profiles.append(GameState.adaptive_profile)
			ok = ok and GameState.adaptive_profile == _expected_profile(score) and is_equal_approx(GameState.get_adaptive_score(), float(score))
		var label: String = "%s %s %s" % [choices[0], choices[1], choices[2]]
		_check("rule: %s -> L2 %s, L3 %s, ending %s" % [label, profiles[0], profiles[1], profiles[2]], ok)
		print("TABLE: %s -> %s | %s | %s" % [label, profiles[0], profiles[1], GameState.get_adaptive_result().ending_variant])
	_clean_state()


func _test_config_and_save() -> void:
	_clean_state()
	GameState.record_decision("p14b_a", "boss", 1, REL)
	GameState.refresh_adaptive_profile()
	var keys: Array = GameState.to_dict().keys()
	keys.sort()
	var expected: Array = SAVE_KEYS.duplicate()
	expected.sort()
	_check("save: exactly the seven keys", keys == expected, str(keys))
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

func _test_texts() -> void:
	_check("texts: no decisions yet", TEXTS.build_level_line(0, 0, 0, 0, NEUT) == TEXTS.no_decisions_line and not TEXTS.no_decisions_line.is_empty())
	var one: String = TEXTS.build_level_line(1, 0, 1, 0, COMP)
	_check("texts: one released soul -> singular heart line and the profile", one.begins_with("+1 corazón máximo por alma liberada") and one.contains("piedad"), one)
	var many: String = TEXTS.build_level_line(3, 0, 3, 2, COMP)
	_check("texts: three released souls -> plural, wave tier and profile", many.contains("+3 corazones máximos") and many.contains("onda de espada nivel 2"), many)
	var kept: String = TEXTS.build_level_line(0, 2, 0, 2, CORR)
	_check("texts: kept souls -> no heart line, wave tier, corruption cost",
		not kept.contains("corazón") and kept.contains("nivel 2") and kept.contains("corrupción") and kept.begins_with("Onda"), kept)
	var neutral: String = TEXTS.build_level_line(1, 1, 1, 1, NEUT)
	_check("texts: mixed decisions -> neutral profile line", neutral.contains("ningún lado"), neutral)
	_check("texts: signed scores", DecisionTexts.format_score(2.0) == "+2" and DecisionTexts.format_score(-1.0) == "−1" and DecisionTexts.format_score(0.0) == "0")
	var all_text: String = " ".join([TEXTS.no_decisions_line, TEXTS.health_bonus_one, TEXTS.health_bonus_many, TEXTS.wave_line,
		String(TEXTS.profile_lines[COMP]), String(TEXTS.profile_lines[NEUT]), String(TEXTS.profile_lines[CORR])])
	_check("texts: no placeholder marker", not all_text.contains("provisional"))


# ---------------------------------------------------------------------------------------------
# 3. Max health for released souls
# ---------------------------------------------------------------------------------------------

func _test_player_health() -> void:
	var stats: PlayerStats = load("res://backend/player/default_player_stats.tres") as PlayerStats
	_check("stats: base 8, +1 per released soul, up to 3", stats.max_health == 8 and stats.health_per_released_soul == 1 and stats.released_souls_cap == 3)
	for released in [0, 1, 2, 3, 7]:
		_clean_state()
		GameState.souls_released = released
		var spawned := PLAYER_SCENE.instantiate() as Player
		add_child(spawned)
		var expected: int = 8 + mini(released, 3)
		_check("health: %d released -> max %d, full" % [released, expected],
			spawned.health.max_health == expected and spawned.health.current_health == expected)
		spawned.free()
	_clean_state()
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	_check("respawn: starts at 8", player.health.max_health == 8)
	GameState.souls_released = 3
	player.health.kill()
	await _frames(2)
	player.respawn()
	_check("respawn: restores to the new maximum (11)", player.health.max_health == 11 and player.health.current_health == 11 and not player.is_dead)
	player.health.heal(1)
	_check("orbs: a full-health player stays at 11", player.health.current_health == 11)
	player.health.current_health = 9
	player.health.heal(1)
	_check("orbs: still heal exactly one heart", player.health.current_health == 10)
	player.free()
	_clean_state()


# ---------------------------------------------------------------------------------------------
# 4. HUD
# ---------------------------------------------------------------------------------------------

func _test_hud() -> void:
	_clean_state()
	var hud := HUD_SCENE.instantiate() as PlayerHealthHud
	add_child(hud)
	await _frames(3)
	var screen: Vector2 = get_viewport().get_visible_rect().size
	for maximum in [8, 11]:
		hud._on_health_changed(maximum, maximum)
		await _frames(3)
		var first: Rect2 = (hud.pips.get_child(0) as Control).get_global_rect()
		var last: Rect2 = (hud.pips.get_child(hud.pips.get_child_count() - 1) as Control).get_global_rect()
		var wave: Rect2 = hud.wave_bar.get_global_rect()
		var width: float = last.end.x - first.position.x
		_check("hud %d: one segment per point" % maximum, hud.pips.get_child_count() == maximum and hud.filled_pips() == maximum)
		_check("hud %d: bar no wider than %d px and inside the screen" % [maximum, int(hud.bar_width)],
			width <= hud.bar_width + 0.5 and last.end.x <= screen.x - 28.0 + 0.5 and first.position.x >= screen.x - 204.0 - 0.5,
			"width %.1f right edge %.1f of %.0f" % [width, last.end.x, screen.x])
		_check("hud %d: segments do not overlap each other" % maximum, _segments_disjoint(hud))
		_check("hud %d: bar stays above the wave bar" % maximum, last.end.y <= wave.position.y)
	var width_11: float = (hud.pips.get_child(0) as Control).size.x
	_check("hud: segments shrink to fit at 11 points", width_11 < 22.0 and width_11 >= 15.9, "%.1f px" % width_11)
	# The corruption indicator follows the game state.
	GameState.record_decision("p14b_h1", "boss", 1, KEP)
	GameState.refresh_adaptive_profile()
	_check("hud: indicator after one kept soul", hud.get_indicator_text() == "Corrupto −1" and hud.profile == CORR, hud.get_indicator_text())
	GameState.record_decision("p14b_h2", "boss", 2, REL)
	GameState.refresh_adaptive_profile()
	_check("hud: indicator back to neutral at score 0", hud.get_indicator_text() == "Neutral 0" and hud.profile == NEUT, hud.get_indicator_text())
	GameState.record_decision("p14b_h3", "boss", 3, REL)
	GameState.refresh_adaptive_profile()
	_check("hud: indicator compassionate at +1", hud.get_indicator_text() == "Compasivo +1", hud.get_indicator_text())
	hud.free()
	_clean_state()


func _segments_disjoint(hud: PlayerHealthHud) -> bool:
	var previous_end: float = -INF
	for child in hud.pips.get_children():
		var rect: Rect2 = (child as Control).get_global_rect()
		if rect.position.x < previous_end - 0.01:
			return false
		previous_end = rect.end.x
	return true


# ---------------------------------------------------------------------------------------------
# 5. Level lines
# ---------------------------------------------------------------------------------------------

func _make_level(number: int) -> LevelBase:
	var level := (load(LEVEL_PATHS[number]) as PackedScene).instantiate() as LevelBase
	add_child(level)
	return level


func _test_level_lines() -> void:
	# Level 1 of a new game: an intro line and the "no decisions yet" line.
	_clean_state()
	var level_1: LevelBase = _make_level(1)
	_check("level 1: has an intro line", level_1.is_intro_visible() and not level_1.intro_label.text.is_empty(), level_1.intro_label.text)
	_check("level 1: consequence line says no decisions yet and the heal cost (Phase 15a)", level_1.consequence_label.visible and level_1.consequence_line == TEXTS.no_decisions_line + TEXTS.line_separator + TEXTS.heal_cost_line % 33)
	level_1.free()
	var scenarios: Array = [
		[COMP, 2, 0, "piedad", "mercy"],
		[NEUT, 1, 1, "ningún lado", "balanced"],
		[CORR, 0, 2, "corrupción", "burden"],
	]
	for scenario: Array in scenarios:
		for number in [1, 2, 3]:
			_clean_state()
			GameState.souls_released = scenario[1]
			GameState.souls_kept = scenario[2]
			GameState.adaptive_profile = scenario[0]
			var level: LevelBase = _make_level(number)
			var expected_intro: String = String(level.intro_lines.get(scenario[4], ""))
			_check("level %d / %s: intro line from its narrative variant" % [number, scenario[0]],
				not expected_intro.is_empty() and level.intro_label.visible and level.intro_label.text == expected_intro, level.intro_label.text)
			_check("level %d / %s: consequence line mentions the profile" % [number, scenario[0]],
				level.consequence_label.visible and level.consequence_label.text == level.consequence_line and level.consequence_line.contains(String(scenario[3])), level.consequence_line)
			if scenario[1] > 0:
				_check("level %d / %s: consequence line mentions the extra hearts" % [number, scenario[0]], level.consequence_line.contains("corazón") or level.consequence_line.contains("corazones"), level.consequence_line)
			level.free()
	var accents: String = ""
	for number in [1, 2, 3]:
		_clean_state()
		var level: LevelBase = _make_level(number)
		for line: Variant in level.intro_lines.values():
			accents += String(line) + " "
		level.free()
	_check("intro lines: accents fixed", accents.contains("aún queda") and accents.contains("quizá") and accents.contains("decisión final")
		and not accents.contains(" aun ") and not accents.contains("quiza") and not accents.contains("decision "))
	_check("intro lines: no placeholder marker", not accents.contains("provisional"))
	_clean_state()
	var tutorial: LevelBase = _make_level(0)
	_check("tutorial: no consequence line", tutorial.consequence_line.is_empty() and not tutorial.consequence_label.visible)
	tutorial.free()
	_clean_state()


# ---------------------------------------------------------------------------------------------
# 6. Sounds, debug keys, prologue
# ---------------------------------------------------------------------------------------------

func _test_audio_wiring() -> void:
	var all_sets: Array = AudioDirector.DECISION_SFX[REL] + AudioDirector.DECISION_SFX[KEP] + AudioDirector.PHASE_TWO_SFX
	var missing: Array[String] = []
	for entry: Array in all_sets:
		if not ResourceLoader.exists(AudioDirector.SFX_DIR + String(entry[0])):
			missing.append(String(entry[0]))
	_check("audio: every reused file exists", missing.is_empty(), str(missing))
	_check("audio: release and keep sound different", AudioDirector.DECISION_SFX[REL] != AudioDirector.DECISION_SFX[KEP])
	var flow := DecisionFlow.new()
	add_child(flow)
	AudioDirector._on_node_added(flow)
	_check("audio: decision_made is hooked", flow.decision_made.is_connected(AudioDirector._on_decision_made))
	flow.free()
	var boss := BOSS_TWO.instantiate() as BossBase
	add_child(boss)
	AudioDirector._on_node_added(boss)
	_check("audio: boss phase_changed is hooked", boss.phase_changed.is_connected(AudioDirector._on_boss_phase_changed))
	boss.free()
	await _frames(1)


func _test_debug_keys() -> void:
	_clean_state()
	var level: LevelBase = _make_level(1)
	var debug_node: LevelDebug = null
	for child in level.get_children():
		if child is LevelDebug:
			debug_node = child
	_check("debug: LevelDebug exists in a debug build", debug_node != null)
	if debug_node != null and level.boss != null:
		debug_node._unhandled_key_input(_key_event(KEY_K))
		_check("debug: K (a dash key) no longer kills the boss", level.boss.state != BossBase.State.DEAD)
		debug_node._unhandled_key_input(_key_event(KEY_F4))
		await _frames(2)
		_check("debug: F4 kills the boss", level.boss.state == BossBase.State.DEAD)
	var colliding: Array[String] = []
	for action in ["move_left", "move_right", "jump", "dash", "attack", "wave", "heavy_attack", "pause"]:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and [KEY_F4, KEY_H, KEY_F2, KEY_F3].has(int((event as InputEventKey).physical_keycode)):
				colliding.append(action)
	_check("debug: no gameplay action uses F4, H, F2 or F3", colliding.is_empty(), str(colliding))
	level.free()
	_clean_state()


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _test_prologue_headless() -> void:
	var prologue := PROLOGUE_SCENE.instantiate()
	add_child(prologue)
	_check("prologue: headless path stops processing and frees itself", not prologue.is_processing() and prologue.is_queued_for_deletion())
	await _frames(3)
	_check("prologue: gone after a few frames", not is_instance_valid(prologue))
	_clean_state()
	var tutorial: LevelBase = _make_level(0)
	await _frames(5)
	tutorial.free()
	_clean_state()
