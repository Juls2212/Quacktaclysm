extends Node
## Headless smoke test for Phase 14f (missing audio and projectile readability). Audio is silent in
## headless runs, so this checks wiring and state, not audibility: every file of the audio table
## exists and imports, every event is wired to its signal, cooldowns and the cap of simultaneous
## voices hold, nothing plays for a dead or freed source, footsteps are paced by distance and only
## count while running on the floor, each boss has its own music and the level's comes back, the
## corrupt-profile pitch and filter survive a boss and are given back when the level closes, the music
## ducks and un-ducks, the windup sounds stay clearly louder than every new sound, the enemy
## projectile outline reads on every background and differs from the sword wave, and nothing in
## the gameplay values changed. Development only. Run:
##   <godot> --headless --path game res://frontend/scenes/test/phase14f_smoke_test.tscn
## Uses a redirected save path; the AI service stays disabled; the real save is never touched.

const TEST_SAVE: String = "user://test_save_phase14f.json"
const SFX_DIR: String = "res://frontend/audio/sfx/"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const LEVEL_PATHS: Dictionary = {
	1: "res://frontend/levels/level_1.tscn",
	2: "res://frontend/levels/level_2.tscn",
	3: "res://frontend/levels/level_3.tscn",
}
const BIOME_DIR: String = "res://frontend/levels/biome/"
const MIN_CONTRAST: float = 2.5
const WINDUP_MARGIN_DB: float = 3.0
## Gameplay values recorded in Phase 14e (this phase must not change any of them).
const ENEMY_TIMES: Dictionary = {
	"melee": [0.35, 0.15, 0.4], "fast": [0.4, 0.25, 0.7], "ranged": [0.5, 0.05, 0.4],
}
const ENEMY_SCENES: Dictionary = {
	"melee": "res://backend/enemies/melee_enemy.tscn", "fast": "res://backend/enemies/fast_enemy.tscn", "ranged": "res://backend/enemies/ranged_enemy.tscn",
}
const BOSS_TIMES: Dictionary = {
	"res://backend/bosses/boss_two.tscn": {"swipe": [0.7, 0.25, 0.7], "charge": [0.7, 0.8, 0.8], "volley": [0.8, 0.36, 0.9]},
	"res://backend/bosses/boss_three.tscn": {"swipe": [0.5, 0.2, 0.5], "charge": [0.7, 0.7, 0.8]},
}

var failures: int = 0
var real_save_before: String = ""
var events: AudioEvents = null
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig


func _ready() -> void:
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
	events = load(AudioEvents.DEFAULT_PATH) as AudioEvents
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
	AudioDirector.clear_music_profile()
	AudioDirector._event_ready.clear()
	AudioDirector._event_active.clear()
	AudioDirector._duck_owners.clear()
	AudioDirector._duck_db = 0.0
	AudioDirector.events_played.clear()
	AudioDirector.events_blocked.clear()


func _played(event_id: StringName) -> int:
	return int(AudioDirector.events_played.get(event_id, 0))


func _make_level(number: int) -> LevelBase:
	var level := (load(LEVEL_PATHS[number]) as PackedScene).instantiate() as LevelBase
	add_child(level)
	return level


func _free(node: Variant) -> void:
	if is_instance_valid(node):
		(node as Node).queue_free()


func _run() -> void:
	_clean_state()
	_test_guards()
	_test_table()
	_test_mix_margin()
	_test_projectile_outline()
	await _test_wiring()
	await _test_cooldown_and_voices()
	await _test_footsteps()
	await _test_boss_music()
	await _test_ducking()
	await _test_gameplay_unchanged()
	_clean_state()
	SaveSystem.purge()
	GameState.autosave_enabled = true
	_check("the real save file was not touched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------------------------------------
# Guards and the table
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
	_check("autoloads: exactly GameState, SceneManager and AudioDirector",
		autoloads == PackedStringArray(["AudioDirector", "GameState", "SceneManager"]), str(autoloads))


func _test_table() -> void:
	_check("table: an entry for each of the %d events" % AudioEvents.EVENT_IDS.size(), events.events.size() == AudioEvents.EVENT_IDS.size())
	var all_ok: bool = true
	var files_ok: bool = true
	for event_id in AudioEvents.EVENT_IDS:
		var event: AudioEvent = events.get_event(event_id)
		var ok: bool = event != null and not event.files.is_empty() and event.volume_db <= 0.0 and event.pitch_min > 0.0 \
				and event.pitch_min <= event.pitch_max and event.cooldown >= 0.0 and event.max_voices >= 1 and not event.note.is_empty()
		all_ok = all_ok and ok
		if event == null:
			continue
		for file in event.files:
			var path: String = SFX_DIR + file
			var good: bool = ResourceLoader.exists(path) and FileAccess.file_exists(path + ".import") and load(path) is AudioStream
			files_ok = files_ok and good
			if not good:
				print("MISSING: %s" % path)
	_check("table: every event has files, a volume, a pitch range, a cooldown and 1+ voices", all_ok)
	_check("table: every referenced audio file exists, has its .import and loads as an AudioStream", files_ok)
	var music_ok: bool = true
	for level in [1, 2, 3]:
		var choice: Array = events.get_boss_music(level)
		music_ok = music_ok and choice.size() == 2 and ResourceLoader.exists("res://frontend/audio/music/" + String(choice[0])) \
				and float(choice[1]) > 0.5 and float(choice[1]) < 1.5
	_check("table: every boss has an existing music file and a sane pitch", music_ok)
	_check("table: ducking values are negative dB", events.duck_dialogue_db < 0.0 and events.duck_story_db < 0.0 and events.duck_presentation_db < 0.0)


## Windup sounds must stay clearly louder than every sound added in this phase.
func _test_mix_margin() -> void:
	var telegraphs: TelegraphSet = TelegraphSet.get_default()
	var quietest_loud: float = 99.0
	for kind in TelegraphSet.KINDS:
		var loudest: float = -99.0
		for entry: Variant in telegraphs.get_style(kind).windup_sounds:
			loudest = maxf(loudest, float((entry as Array)[2]))
		quietest_loud = minf(quietest_loud, loudest)
	var loudest_new: float = -99.0
	for entry: Variant in events.events:
		loudest_new = maxf(loudest_new, (entry as AudioEvent).volume_db)
	var margin: float = quietest_loud - loudest_new
	print("MIX: quietest windup peak %.1f dB, loudest new event %.1f dB, margin %.1f dB (needs %.1f)" % [quietest_loud, loudest_new, margin, WINDUP_MARGIN_DB])
	_check("mix: every windup sound stays at least %.0f dB above the loudest new sound (%.1f dB)" % [WINDUP_MARGIN_DB, margin], margin >= WINDUP_MARGIN_DB)
	var footstep: AudioEvent = events.get_event(&"footstep")
	_check("mix: footsteps are the quietest sounds and are rate-limited", footstep.volume_db <= -14.0 and footstep.cooldown >= 0.1)


# ---------------------------------------------------------------------------------------------
# Projectile outline
# ---------------------------------------------------------------------------------------------

static func _channel(c: float) -> float:
	return c / 12.92 if c <= 0.03928 else pow((c + 0.055) / 1.055, 2.4)


static func _luminance(color: Color) -> float:
	return 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b)


static func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _test_projectile_outline() -> void:
	var presentation := load("res://frontend/presentation/default_profile_presentation.tres") as ProfilePresentation
	var backgrounds: Array[Color] = []
	for file in DirAccess.get_files_at(BIOME_DIR):
		if not file.ends_with("_biome.tres"):
			continue
		var biome := load(BIOME_DIR + file) as Biome
		var scenery: Array[Color] = [biome.sky_top, biome.sky_bottom, biome.haze, biome.far_color, biome.mid_color, biome.near_color]
		for profile in ["neutral", "compassionate", "corrupt"]:
			var tint: Color = presentation.get_look(profile).background_tint
			for color in scenery:
				backgrounds.append(Color(clampf(color.r * tint.r, 0.0, 1.0), clampf(color.g * tint.g, 0.0, 1.0), clampf(color.b * tint.b, 0.0, 1.0)))
		backgrounds.append_array([biome.grass, biome.grass_dark, biome.soil, biome.soil_dark, biome.rock, biome.rock_dark])
	var worst: float = 99.0
	for bg in backgrounds:
		worst = minf(worst, maxf(_contrast(DangerOutline.HALO, bg), _contrast(DangerOutline.INK, bg)))
	print("CONTRAST: enemy projectile outline worst %.2f over %d backgrounds (threshold %.1f)" % [worst, backgrounds.size(), MIN_CONTRAST])
	_check("outline: reads against every background of the three looks and the ground (worst %.2f >= %.1f)" % [worst, MIN_CONTRAST], worst >= MIN_CONTRAST)
	_check("outline: the halo stands out from its dark outline (>= 4.5)", _contrast(DangerOutline.HALO, DangerOutline.INK) >= 4.5)
	var enemy_scene := (load("res://backend/combat/projectile.tscn") as PackedScene).instantiate() as Projectile
	var wave_scene := (load("res://backend/combat/sword_wave_projectile.tscn") as PackedScene).instantiate() as Projectile
	_check("outline: the enemy projectile scene carries the danger outline, the sword wave does not",
		enemy_scene.get_node_or_null("DangerOutline") is DangerOutline and wave_scene.get_node_or_null("DangerOutline") == null)
	var config := load("res://backend/player/default_sword_wave_config.tres") as SwordWaveConfig
	var far_enough: bool = true
	for tier in 3:
		var tint: Color = config.get_tier(tier).tint
		far_enough = far_enough and absf(tint.h - DangerOutline.HALO.h) > 0.08 and absf(tint.h - DangerOutline.HALO.h) < 0.92
	_check("outline: its warm hue is far from every sword wave tint (blue, cyan, violet)", far_enough)
	# Visual only: nothing that matters for gameplay changed.
	var stats := load("res://backend/combat/stats/enemy_projectile_stats.tres") as ProjectileStats
	var heavy := load("res://backend/bosses/stats/boss_heavy_projectile_stats.tres") as ProjectileStats
	_check("outline: enemy projectile speed, damage and size are untouched", is_equal_approx(stats.speed, 400.0) and stats.damage == 1 and is_equal_approx(stats.size_scale, 1.0)
		and is_equal_approx(heavy.speed, 520.0) and heavy.damage == 1)
	var shape: CircleShape2D = enemy_scene.get_node("CollisionShape2D").shape as CircleShape2D
	var hit_shape: CircleShape2D = enemy_scene.get_node("Hitbox/CollisionShape2D").shape as CircleShape2D
	_check("outline: the hitbox shapes of the enemy projectile are untouched (radius 6)", is_equal_approx(shape.radius, 6.0) and is_equal_approx(hit_shape.radius, 6.0))
	enemy_scene.free()
	wave_scene.free()


# ---------------------------------------------------------------------------------------------
# Wiring: every event is hooked to its signal
# ---------------------------------------------------------------------------------------------

func _test_wiring() -> void:
	_clean_state()
	# Footsteps: the player's Visual signal.
	var player := (load("res://backend/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(player)
	await _frames(2)
	AudioDirector._on_node_added(player)
	var visual: Node = player.get_node("Visual")
	_check("wiring: footstep is connected to the player's visual", visual.get_signal_connection_list(&"footstep").size() >= 1)
	visual.footstep.emit()
	_check("wiring: a footstep signal plays the footstep event", _played(&"footstep") == 1)
	# Landing, jump, dash, death, orb, checkpoint, buttons: the older hooks still exist.
	var old_handlers: Array[String] = ["_on_player_state_changed", "_on_player_died", "_on_soul_gained", "_on_checkpoint", "_on_fragment_collected",
		"_on_button_hover", "_on_button_focus", "_on_hit_received", "_on_enemy_died", "_on_boss_defeated"]
	var old_ok: bool = true
	for handler in old_handlers:
		old_ok = old_ok and AudioDirector.has_method(handler)
	_check("wiring: landing, death, soul, checkpoint, fragment and menu sounds are still wired", old_ok)
	var button := Button.new()
	AudioDirector._on_node_added(button)
	_check("wiring: menu buttons are connected (confirm and navigation)", button.pressed.get_connections().size() >= 1 and button.mouse_entered.get_connections().size() >= 1
		and button.focus_entered.get_connections().size() >= 1)
	button.free()
	# Projectiles: world, player, enemy, and the sword wave.
	var enemy := (load(("res://backend/enemies/melee_enemy.tscn")) as PackedScene).instantiate() as EnemyBase
	add_child(enemy)
	await _frames(2)
	var projectile_scene := load("res://backend/combat/projectile.tscn") as PackedScene
	var wave_scene := load("res://backend/combat/sword_wave_projectile.tscn") as PackedScene
	var enemy_shot := projectile_scene.instantiate() as Projectile
	AudioDirector._on_node_added(enemy_shot)
	enemy_shot.source = enemy
	enemy_shot.despawned.emit(Projectile.REASON_WORLD)
	_check("wiring: an enemy projectile hitting the world plays projectile_impact_world", _played(&"projectile_impact_world") == 1)
	(enemy_shot.get_node("Hitbox") as Hitbox).hit_landed.emit(player.get_node("Hurtbox"), null)
	_check("wiring: an enemy projectile hitting the player plays projectile_impact_player", _played(&"projectile_impact_player") == 1)
	(enemy_shot.get_node("Hitbox") as Hitbox).hit_landed.emit(enemy.get_node("Hurtbox"), null)
	_check("wiring: a projectile hitting an enemy plays projectile_impact_enemy", _played(&"projectile_impact_enemy") == 1)
	var wave := wave_scene.instantiate() as Projectile
	AudioDirector._on_node_added(wave)
	wave.source = player
	(wave.get_node("Hitbox") as Hitbox).hit_landed.emit(enemy.get_node("Hurtbox"), null)
	wave.despawned.emit(Projectile.REASON_WORLD)
	_check("wiring: the sword wave has its own impact sounds (enemy and world)", _played(&"wave_impact") == 1 and _played(&"wave_impact_world") == 1
		and _played(&"projectile_impact_enemy") == 1)
	enemy_shot.free()
	wave.free()
	# Exorcism, title card, boss VS sting, game over, portal, transition.
	var exorcism := ExorcismCutscene.new()
	AudioDirector._on_node_added(exorcism)
	_check("wiring: the exorcism plays its sound when it starts", _played(&"exorcism") == 1)
	exorcism.free()
	var card := LevelTitleCard.new()
	AudioDirector._on_node_added(card)
	_check("wiring: the level title card plays its sound", _played(&"title_card") == 1)
	card.free()
	var encounter := BossEncounter.new()
	AudioDirector._on_node_added(encounter)
	encounter.encounter_started.emit()
	_check("wiring: the boss presentation plays its sting when the encounter starts", _played(&"boss_vs_sting") == 1)
	encounter.free()
	var panel := (load("res://frontend/ui/game_over_panel.tscn") as PackedScene).instantiate() as GameOverPanel
	add_child(panel)
	await _frames(2)
	AudioDirector._on_node_added(panel)
	panel.open()
	_check("wiring: Game Over plays its sound when the panel opens", _played(&"game_over") == 1)
	PauseLock.reset(get_tree())
	panel.free()
	var portal := (load("res://frontend/levels/blocks/star_portal.tscn") as PackedScene).instantiate() as StarPortal
	add_child(portal)
	await _frames(2)
	AudioDirector._on_node_added(portal)
	portal.portal_lit.emit()
	portal.portal_entered.emit()
	_check("wiring: the portal lighting up and being entered each play a sound", _played(&"portal_lit") == 1 and _played(&"portal_enter") == 1)
	portal.free()
	SceneManager.transition_started.emit("level_1")
	_check("wiring: a scene transition plays its sound", _played(&"transition") == 1)
	# The Soul events (Phase 15a): the soul meter and the focus signals of the player.
	var soul_component: SoulComponent = player.soul
	soul_component.soul_gained.emit(5)
	soul_component.soul_full.emit()
	soul_component.heal_denied.emit(&"not_enough_soul")
	player.focus_started.emit()
	player.focus_completed.emit(1)
	_check("wiring: soul gain, soul full, heal denied, focus start and heal done each play a sound", _played(&"soul_gain") == 1 and _played(&"soul_full") == 1
		and _played(&"heal_denied") == 1 and _played(&"focus_start") == 1 and _played(&"heal_done") == 1)
	# The Phase 15c events: a lily pad, the floor spikes, the guardian's leap and the double jump.
	var pad := (load("res://backend/arena/bounce_pad.tscn") as PackedScene).instantiate() as BouncePad
	AudioDirector._on_node_added(pad)
	pad.launched.emit(player)
	var spikes := (load("res://backend/arena/floor_hazard.tscn") as PackedScene).instantiate() as FloorHazard
	AudioDirector._on_node_added(spikes)
	spikes.state_changed.emit(FloorHazard.State.WARNING)
	spikes.state_changed.emit(FloorHazard.State.ACTIVE)
	var leap := LeapPattern.new()
	AudioDirector._on_node_added(leap)
	leap.leap_started.emit(Vector2.ZERO, Vector2(10.0, 0.0))
	leap.landed.emit(Vector2(10.0, 0.0))
	player.double_jumped.emit()
	_check("wiring: a pad bounce, the spikes warning and rising, the leap and its landing, and the double jump each play a sound",
		_played(&"pad_bounce") == 1 and _played(&"spike_warning") == 1 and _played(&"spike_rise") == 1 and _played(&"boss_leap") == 1
		and _played(&"leap_land") == 1 and _played(&"double_jump") == 1)
	pad.free()
	spikes.free()
	leap.free()
	# The possession sequence of a boss phase change (Phase 15d): its three sounds, from the real director.
	var possession_level: LevelBase = _make_level(2)
	await _frames(3)
	var possession := possession_level.get_node("PossessionDirector") as PossessionDirector
	possession.begin(2)
	possession.elapsed = possession.duration
	possession._fire_events()
	_check("wiring: the possession start, roar and slam each play a sound", _played(&"possession_start") == 1 and _played(&"possession_roar") == 1 and _played(&"possession_slam") == 1)
	_check("wiring: the possession sequence has its own sounds, so the phase 2 sting is not played on top of them",
		possession_level.boss.has_meta(&"possession_played"))
	possession._cancel()
	possession_level.free()
	await _frames(2)
	# Every id of the table was exercised above.
	var missing: Array[StringName] = []
	# The grandfather's voice is exercised by phase16c and the duck cries only exist in the ending cinematics (phase15i).
	var elsewhere: Array[StringName] = [&"grandfather_voice", &"duck_cry_weak", &"duck_cry_pain", &"duck_cry_resist", &"duck_cry_lonely"]
	for event_id in AudioEvents.EVENT_IDS:
		if _played(event_id) < 1 and not elsewhere.has(event_id):
			missing.append(event_id)
	_check("wiring: every event of the table fired from its real hook", missing.is_empty(), str(missing))
	_free(player)
	_free(enemy)
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# Cooldowns, voices, dead sources
# ---------------------------------------------------------------------------------------------

func _test_cooldown_and_voices() -> void:
	_clean_state()
	_check("cooldown: a footstep plays", AudioDirector.play_event(&"footstep"))
	_check("cooldown: the next one right away is blocked", not AudioDirector.play_event(&"footstep") and int(AudioDirector.events_blocked.get(&"footstep", 0)) == 1)
	await get_tree().create_timer(0.25).timeout
	_check("cooldown: it plays again after the cooldown", AudioDirector.play_event(&"footstep"))
	_clean_state()
	var plays: int = 0
	for i in 3:
		AudioDirector._event_ready.clear()
		plays += 1 if AudioDirector.play_event(&"projectile_impact_world") else 0
	AudioDirector._event_ready.clear()
	_check("voices: the world impact sounds 3 times at once and a 4th is refused (max_voices 3)", plays == 3 and not AudioDirector.play_event(&"projectile_impact_world"))
	_clean_state()
	AudioDirector.play_event(&"game_over")
	AudioDirector._event_ready.clear()
	_check("voices: an event with 1 voice cannot overlap itself", not AudioDirector.play_event(&"game_over"))
	_check("events: an unknown event plays nothing", not AudioDirector.play_event(&"no_such_event"))
	# Dead or freed sources.
	_clean_state()
	var player := (load("res://backend/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(player)
	await _frames(2)
	_check("source: a living player's footstep plays", AudioDirector.play_event(&"footstep", player))
	AudioDirector._event_ready.clear()
	player.is_dead = true
	_check("source: nothing plays for a dead player", not AudioDirector.play_event(&"footstep", player))
	player.is_dead = false
	player.free()
	_check("source: nothing plays for a freed source", not AudioDirector.play_event(&"footstep", player))
	var enemy := (load("res://backend/enemies/melee_enemy.tscn") as PackedScene).instantiate() as EnemyBase
	add_child(enemy)
	await _frames(2)
	enemy.health.kill()
	await _frames(2)
	_check("source: nothing plays for a dead enemy", not AudioDirector.play_event(&"footstep", enemy))
	_free(enemy)
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# Footsteps
# ---------------------------------------------------------------------------------------------

func _test_footsteps() -> void:
	_clean_state()
	var player := (load("res://backend/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(player)
	await _frames(3)
	var visual: Node = player.get_node("Visual")
	var distance: float = float(visual.get("step_distance"))
	var counter: Array[int] = [0]
	visual.connect(&"footstep", func() -> void: counter[0] += 1)
	_check("footsteps: nothing while not running on the floor", int(visual.call(&"advance_steps", 500.0, false)) == 0 and counter[0] == 0)
	_check("footsteps: less than a step of floor walked makes no sound", int(visual.call(&"advance_steps", distance * 0.4, true)) == 0)
	_check("footsteps: a step is taken once the distance is covered", int(visual.call(&"advance_steps", distance * 0.7, true)) == 1 and counter[0] == 1)
	_check("footsteps: running farther gives more steps in proportion (2.5 steps of distance -> 2 or 3)", int(visual.call(&"advance_steps", distance * 2.5, true)) >= 2)
	var before: int = counter[0]
	visual.call(&"advance_steps", distance, false)
	_check("footsteps: leaving the floor stops them and restarts the count", counter[0] == before)
	# From the real state: idle, not running -> no steps; dead -> no steps.
	var idle_before: int = counter[0]
	player.velocity = Vector2(300, 0)
	visual.call(&"_update_footsteps", 1.0)
	_check("footsteps: a player that is not in the run state makes none (idle)", counter[0] == idle_before)
	player.is_dead = true
	visual.call(&"_update_footsteps", 1.0)
	_check("footsteps: none for a dead player", counter[0] == idle_before)
	player.is_dead = false
	# Paced by distance: the faster the run, the more steps for the same time.
	var slow: int = 0
	var fast: int = 0
	var slow_visual: Node = visual
	slow_visual.call(&"advance_steps", 0.0, false)
	for i in 60:
		slow += int(slow_visual.call(&"advance_steps", 100.0 / 60.0, true))
	slow_visual.call(&"advance_steps", 0.0, false)
	for i in 60:
		fast += int(slow_visual.call(&"advance_steps", 300.0 / 60.0, true))
	_check("footsteps: paced by distance (100 px/s -> %d steps, 300 px/s -> %d steps in one second)" % [slow, fast], fast > slow and slow >= 1 and fast <= int(300.0 / distance) + 1)
	player.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# Music per boss
# ---------------------------------------------------------------------------------------------

func _test_boss_music() -> void:
	var choices: Array = []
	var level_tracks: Dictionary = {1: "castle_on_the_mountain.ogg", 2: "castle_on_the_mountain.ogg", 3: "dungeon.ogg"}
	for number in [1, 2, 3]:
		_clean_state()
		var level: LevelBase = _make_level(number)
		await _frames(3)
		AudioDirector._level_track = level_tracks[number]
		AudioDirector.play_music(level_tracks[number])
		var boss: BossBase = level.boss
		var expected: Array = events.get_boss_music(number)
		AudioDirector._on_boss_activated(boss)
		var state: Dictionary = AudioDirector.get_music_state()
		_check("boss music (level %d): the fight asks for %s at pitch %.2f" % [number, expected[0], expected[1]],
			state["requested_track"] == expected[0] and is_equal_approx(float(state["requested_pitch"]), float(expected[1])) and state["boss_music"] == true)
		_check("boss music (level %d): it is not the level's own track" % number, state["requested_track"] != level_tracks[number])
		choices.append("%s@%s" % [expected[0], expected[1]])
		AudioDirector._on_boss_defeated(boss)
		await _frames(2)
		state = AudioDirector.get_music_state()
		_check("boss music (level %d): the level track comes back at normal pitch when the boss falls" % number,
			state["requested_track"] == level_tracks[number] and is_equal_approx(float(state["requested_pitch"]), 1.0) and state["boss_music"] == false)
		AudioDirector._on_boss_activated(boss)
		AudioDirector._on_player_respawned()
		state = AudioDirector.get_music_state()
		_check("boss music (level %d): after a death and respawn the level track is back" % number, state["requested_track"] == level_tracks[number] and state["boss_music"] == false)
		level.free()
		await _frames(2)
	var distinct: Dictionary = {}
	for choice in choices:
		distinct[choice] = true
	_check("boss music: the three bosses have three different choices (%s)" % str(choices), distinct.size() == 3)
	# The corrupt-profile treatment stays on top of a boss track and is given back with the level.
	_clean_state()
	GameState.adaptive_profile = AdaptiveIds.PROFILE_CORRUPT
	var corrupt_level: LevelBase = _make_level(2)
	await _frames(3)
	var look: ProfileLook = (load("res://frontend/presentation/default_profile_presentation.tres") as ProfilePresentation).get_look(AdaptiveIds.PROFILE_CORRUPT)
	AudioDirector._on_boss_activated(corrupt_level.boss)
	var profile: Dictionary = AudioDirector.get_music_profile()
	_check("corrupt profile: pitch %.2f and the low-pass stay while the boss track plays" % look.music_pitch,
		is_equal_approx(float(profile["pitch"]), look.music_pitch) and bool(profile["filter_on_bus"]))
	AudioDirector._on_boss_defeated(corrupt_level.boss)
	await _frames(2)
	profile = AudioDirector.get_music_profile()
	_check("corrupt profile: still applied after the boss falls", is_equal_approx(float(profile["pitch"]), look.music_pitch) and bool(profile["filter_on_bus"]))
	var bus: int = AudioServer.get_bus_index(GameSettings.MUSIC_BUS)
	var effects_inside: int = AudioServer.get_bus_effect_count(bus)
	corrupt_level.free()
	await _frames(2)
	profile = AudioDirector.get_music_profile()
	_check("corrupt profile: given back when the level closes (no filter, pitch 1.0, one effect less on the bus)",
		not bool(profile["filter_on_bus"]) and is_equal_approx(float(profile["pitch"]), 1.0) and AudioServer.get_bus_effect_count(bus) == effects_inside - 1)
	# Menu, prologue and ending never keep a boss track or an effect.
	AudioDirector._boss_music_active = true
	AudioDirector.set_music_profile(0.9, 1500.0, 0.0, self)
	AudioDirector._on_scene_changed()
	var state_after: Dictionary = AudioDirector.get_music_state()
	_check("scenes: outside a level (menu, prologue, ending) there is no boss music, no filter and no duck",
		state_after["boss_music"] == false and not bool(AudioDirector.get_music_profile()["filter_on_bus"]) and is_equal_approx(float(state_after["duck_db"]), 0.0))


# ---------------------------------------------------------------------------------------------
# Ducking
# ---------------------------------------------------------------------------------------------

func _test_ducking() -> void:
	_clean_state()
	var a := Node.new()
	var b := Node.new()
	AudioDirector.set_music_duck(a, -6.0)
	_check("duck: one owner ducks the music", is_equal_approx(float(AudioDirector.get_music_state()["duck_db"]), -6.0)
		and is_equal_approx(AudioDirector._music_target_db(), AudioDirector.MUSIC_DB - 6.0))
	AudioDirector.set_music_duck(b, -8.0)
	_check("duck: the strongest owner wins", is_equal_approx(float(AudioDirector.get_music_state()["duck_db"]), -8.0))
	AudioDirector.release_music_duck(b)
	_check("duck: releasing it falls back to the other owner", is_equal_approx(float(AudioDirector.get_music_state()["duck_db"]), -6.0))
	AudioDirector.release_music_duck(a)
	_check("duck: everyone released, the music is back to full", is_equal_approx(float(AudioDirector.get_music_state()["duck_db"]), 0.0))
	AudioDirector.set_music_duck(a, -99.0)
	_check("duck: never lower than the limit", float(AudioDirector.get_music_state()["duck_db"]) >= AudioDirector.MAX_DUCK_DB)
	AudioDirector._on_scene_changed()
	_check("duck: a scene change releases every duck", is_equal_approx(float(AudioDirector.get_music_state()["duck_db"]), 0.0))
	a.free()
	b.free()
	# A guardian talking ducks the music and skipping gives it back.
	var level: LevelBase = _make_level(1)
	await _frames(3)
	var dialogue: BossDialogue = level.get_node("BossDialogue") as BossDialogue
	level.encounter.encounter_started.emit()
	_check("duck: the guardian's lines duck the music by the table's amount", is_equal_approx(float(AudioDirector.get_music_state()["duck_db"]), events.duck_dialogue_db))
	dialogue.skip()
	_check("duck: skipping the lines gives the music back", is_equal_approx(float(AudioDirector.get_music_state()["duck_db"]), 0.0))
	level.free()
	await _frames(2)
	_check("duck: closing the level never leaves the music ducked", is_equal_approx(float(AudioDirector.get_music_state()["duck_db"]), 0.0))
	# A story reel ducks while it plays.
	var reel := StoryReel.new()
	reel.lines = ["Una línea de prueba."] as Array[String]
	add_child(reel)
	await _frames(4)
	_check("duck: a story scene ducks the music by the table's amount", is_equal_approx(float(AudioDirector.get_music_state()["duck_db"]), events.duck_story_db))
	reel.free()
	await _frames(2)
	_check("duck: freeing the scene gives it back", is_equal_approx(float(AudioDirector.get_music_state()["duck_db"]), 0.0))


# ---------------------------------------------------------------------------------------------
# Gameplay values (recorded in Phase 14e) are untouched
# ---------------------------------------------------------------------------------------------

func _test_gameplay_unchanged() -> void:
	for kind in ENEMY_TIMES.keys():
		var enemy := (load(ENEMY_SCENES[kind]) as PackedScene).instantiate() as EnemyBase
		add_child(enemy)
		await _frames(2)
		var want: Array = ENEMY_TIMES[kind]
		_check("gameplay: %s windup / active / recovery still %s" % [kind, str(want)],
			is_equal_approx(enemy._attack_phase_duration(EnemyBase.AttackPhase.STARTUP), want[0])
			and is_equal_approx(enemy._attack_phase_duration(EnemyBase.AttackPhase.ACTIVE), want[1])
			and is_equal_approx(enemy._attack_phase_duration(EnemyBase.AttackPhase.RECOVERY), want[2]))
		_free(enemy)
		await _frames(2)
	for scene_path in BOSS_TIMES.keys():
		var boss := (load(scene_path) as PackedScene).instantiate() as BossBase
		add_child(boss)
		await _frames(2)
		var table: Dictionary = BOSS_TIMES[scene_path]
		# Phase 15c added the leap patterns of boss two on purpose: the recorded patterns are the other ones.
		var recorded: Array[BossPattern] = []
		for candidate in boss.patterns:
			if candidate.fallback_priority == 0 and not (candidate is LeapPattern or candidate is SummonerCyclePattern or candidate is StompPattern) and String(candidate.pattern_id) != "volley_leap" and not (scene_path.ends_with("boss_three.tscn") and String(candidate.pattern_id) == "volley"):
				recorded.append(candidate)
		var ok: bool = recorded.size() == table.size()
		for pattern in recorded:
			var want: Array = table.get(String(pattern.pattern_id), [])
			ok = ok and want.size() == 3 and is_equal_approx(pattern._phase_duration(BossPattern.PHASE_TELEGRAPH), want[0]) \
					and is_equal_approx(pattern._phase_duration(BossPattern.PHASE_ACTIVE), want[1]) \
					and is_equal_approx(pattern._phase_duration(BossPattern.PHASE_RECOVERY), want[2])
		_check("gameplay: %s pattern times are exactly the recorded ones" % scene_path.get_file(), ok)
		_free(boss)
		await _frames(2)
	var stats := load("res://backend/player/default_player_stats.tres") as PlayerStats
	_check("gameplay: player max health and speed untouched", stats.max_health == 8 and is_equal_approx(stats.max_speed, 300.0))
