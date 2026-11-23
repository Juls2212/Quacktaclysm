extends Node
## Headless smoke test for Phase 15k (stylized combat blood and the "Sangre" option). Checks the option (default on, stored in the
## settings file and never in the save), the rule per victim (a landed hit bleeds; a blocked hit, the guard shell, the shield and a
## spirit do not; ducklings bleed less; bosses and the player), the caps and the fade, the layer order, the contrast of every warning
## over a stained floor, the reduced count, the cleanup, the endings without any blood and that blood never changes damage.
## Development only. Run:
##   <godot> --headless --path game res://frontend/scenes/test/phase15k_smoke_test.tscn
## Uses a redirected save path and a temporary settings file; the AI service stays disabled; the real files are never touched.

const TEST_SAVE: String = "user://test_save_phase15k.json"
const TEST_SETTINGS: String = "user://test_settings_phase15k.cfg"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const BIOME_DIR: String = "res://frontend/levels/biome/"
const MIN_CONTRAST: float = 2.5
const MELEE: String = "res://backend/enemies/melee_enemy.tscn"
const DUCKLING: String = "res://backend/enemies/duckling.tscn"
const BOSS: String = "res://backend/bosses/boss_two.tscn"
const PLAYER: String = "res://backend/player/player.tscn"
const LEVEL: String = "res://frontend/levels/level_1.tscn"

var failures: int = 0
var real_save_before: String = ""
var real_settings_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig
var arena: Node2D = null
var blood: BloodFx = null


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


func _set_options(values: Dictionary) -> void:
	var all: Dictionary = GameSettings.DEFAULTS.duplicate()
	all.merge(values, true)
	GameSettings.save_settings(all)


## A fresh arena with its own BloodFx (the settings are read when it enters the tree).
func _new_arena(values: Dictionary = {}) -> void:
	if arena != null:
		arena.free()
	_set_options(values)
	arena = Node2D.new()
	add_child(arena)
	blood = BloodFx.new()
	arena.add_child(blood)


func _enemy(path: String) -> EnemyBase:
	var enemy := (load(path) as PackedScene).instantiate() as EnemyBase
	arena.add_child(enemy)
	return enemy


func _hit(hurtbox: Hurtbox, amount: int = 1, team: CombatLayers.Team = CombatLayers.Team.PLAYER) -> bool:
	return hurtbox.receive_hit(DamageInfo.create(amount, Vector2(180.0, -60.0), null, team, &"light"))


func _run() -> void:
	SaveSystem.purge()
	GameState.autosave_enabled = false
	_test_option_and_guards()
	await _test_rules()
	await _test_caps_fade_reduced()
	await _test_layer_and_contrast()
	await _test_cleanup()
	await _test_endings()
	await _test_leaks_and_neutrality()
	if arena != null:
		arena.free()
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

func _test_option_and_guards() -> void:
	_check("option: «Sangre» exists and is ON by default", GameSettings.DEFAULTS.has("blood") and GameSettings.DEFAULTS["blood"] == true)
	_set_options({"blood": false})
	var cfg := ConfigFile.new()
	cfg.load(TEST_SETTINGS)
	_check("option: it is stored in the settings file (off)", cfg.has_section_key(GameSettings.SECTION, "blood") and not bool(cfg.get_value(GameSettings.SECTION, "blood")) and not GameSettings.is_blood_enabled())
	_set_options({})
	_check("option: back on", GameSettings.is_blood_enabled())
	var keys: Array = GameState.to_dict().keys()
	keys.sort()
	var expected: Array = SAVE_KEYS.duplicate()
	expected.sort()
	_check("save: still exactly the seven keys and none is about blood", keys == expected, str(keys))
	var autoloads: PackedStringArray = PackedStringArray()
	for property in ProjectSettings.get_property_list():
		var property_name: String = property["name"]
		if property_name.begins_with("autoload/"):
			autoloads.append(property_name.trim_prefix("autoload/"))
	autoloads.sort()
	_check("autoloads: exactly GameState, SceneManager and AudioDirector", autoloads == PackedStringArray(["AudioDirector", "GameState", "SceneManager"]), str(autoloads))
	var presentation := load("res://frontend/presentation/default_profile_presentation.tres") as ProfilePresentation
	_check("option: its Spanish label is «Sangre»", presentation.blood_toggle_text == "Sangre")
	var board := OptionsBoard.new()
	add_child(board)
	_check("option: the options board (main menu and pause menu) has the checkbox, on, with the label", board.blood_check != null and board.blood_check.button_pressed and board.blood_check.text == "Sangre")
	board.blood_check.button_pressed = false
	_check("option: toggling it writes the settings file, not the save", not GameSettings.is_blood_enabled())
	board.free()
	_set_options({})
	_check("credits: the content notice mentions stylized violence with blood in combat", StoryTexts.get_default().content_notice.contains("violencia estilizada con sangre"))
	var source: String = FileAccess.get_file_as_string("res://frontend/fx/blood_fx.gd")
	var neutral: bool = true
	for word in ["apply_damage", "collision_layer", "collision_mask", "monitorable =", "telemetry", "RunTelemetry", "GameState", "queue_free"]:
		neutral = neutral and not source.contains(word)
	_check("neutral: the blood code never touches damage, collision, telemetry or game state (it only listens to signals)", neutral)


func _test_rules() -> void:
	_new_arena()
	# A living enemy: a landed hit bleeds.
	var melee := _enemy(MELEE)
	await _frames(2)
	var before: int = blood.droplets.size()
	var landed: bool = _hit(melee.hurtbox)
	var hit_count: int = blood.droplets.size() - before
	_check("rules: a landed hit on a living enemy makes a spurt in the hit direction (%d droplets)" % hit_count, landed and hit_count == blood.config.hit_droplets)
	var average_x: float = 0.0
	for d in blood.droplets:
		average_x += (d["v"] as Vector2).x
	_check("rules: the spurt goes the way of the hit (average speed x %.0f)" % (average_x / maxf(1.0, blood.droplets.size())), average_x > 0.0)
	# The kill: a larger burst.
	blood.clear()
	var killed: bool = _hit(melee.hurtbox, 99)
	await _frames(3)
	_check("rules: a kill makes a larger burst (%d droplets, more than a hit's %d)" % [blood.droplets.size(), hit_count], killed and blood.droplets.size() > hit_count + blood.config.hit_droplets)
	# Ducklings bleed less.
	blood.clear()
	var duckling := _enemy(DUCKLING)
	await _frames(2)
	duckling.health.max_health = 50
	duckling.health.current_health = 50
	_hit(duckling.hurtbox)
	var duckling_count: int = blood.droplets.size()
	_check("rules: a duckling bleeds less (%d droplets against %d)" % [duckling_count, hit_count], duckling_count > 0 and duckling_count < hit_count)
	# Blocked hit (armor / guard / shield): sparks only, no blood.
	blood.clear()
	var brute := _enemy(MELEE)
	await _frames(2)
	var blocker := Node.new()
	var script := GDScript.new()
	script.source_code = "extends Node\nvar blocking: bool = true\nfunc filter_hit(_info) -> bool:\n\treturn blocking\n"
	script.reload()
	blocker.set_script(script)
	arena.add_child(blocker)
	brute.hurtbox.hit_filter = blocker
	var blocked_applied: bool = _hit(brute.hurtbox)
	_check("rules: a hit that the armor or the shield blocks makes NO blood (sparks and the clash sound only)", not blocked_applied and blood.droplets.is_empty())
	blocker.set("blocking", false)
	_hit(brute.hurtbox)
	_check("rules: the same brute bleeds as soon as its armor is not blocking", blood.droplets.size() == hit_count)
	# A non-living victim (spirit, guard shell).
	blood.clear()
	var spirit := _enemy(MELEE)
	spirit.set_meta(&"no_blood", true)
	await _frames(2)
	_hit(spirit.hurtbox)
	_check("rules: a spirit-like victim (meta no_blood) makes no blood on a hit or a kill", blood.droplets.is_empty())
	_hit(spirit.hurtbox, 99)
	await _frames(3)
	_check("rules: ... nor when it dies", blood.droplets.is_empty())
	# The sword wave and every attack kind use the same rule.
	blood.clear()
	var wave_target := _enemy(MELEE)
	await _frames(2)
	for kind in [&"light", &"heavy", &"dash_slash", &"wave"]:
		blood.clear()
		wave_target.hurtbox.receive_hit(DamageInfo.create(0, Vector2.ZERO, null, CombatLayers.Team.PLAYER, kind))
		var zero_damage: int = blood.droplets.size()
		wave_target.hurtbox.receive_hit(DamageInfo.create(1, Vector2(100.0, 0.0), null, CombatLayers.Team.PLAYER, kind))
		_check("rules: attack kind %s uses the same rule (no blood for a hit that does nothing, a spurt for one that lands)" % kind, zero_damage == 0 and blood.droplets.size() == hit_count)
		wave_target.health.current_health = wave_target.health.max_health
		wave_target.health._invulnerable_left = 0.0
	# Bosses: a small spurt on hits and a big burst on defeat.
	blood.clear()
	var boss := (load(BOSS) as PackedScene).instantiate() as BossBase
	arena.add_child(boss)
	await _frames(2)
	boss.get_node(^"Hurtbox").hit_received.emit(DamageInfo.create(1, Vector2(100.0, 0.0), null, CombatLayers.Team.PLAYER, &"light"), true)
	var boss_hit: int = blood.droplets.size()
	blood.clear()
	boss.get_node(^"Hurtbox").hit_received.emit(DamageInfo.create(1, Vector2(100.0, 0.0), null, CombatLayers.Team.PLAYER, &"light"), false)
	_check("rules: a boss spurts on a landed hit (%d) and not on a blocked one (guard shell, shield bubble)" % boss_hit, boss_hit == blood.config.boss_hit_droplets and blood.droplets.is_empty())
	boss.defeated.emit(boss)
	_check("rules: a boss defeat is the biggest burst (%d droplets, the cap is %d)" % [blood.droplets.size(), blood.config.max_droplets], blood.droplets.size() >= blood.config.boss_defeat_droplets * blood.config.reduced_scale and blood.droplets.size() > boss_hit)
	# The player: a small spurt when damage lands, none during dash i-frames.
	blood.clear()
	var player := (load(PLAYER) as PackedScene).instantiate() as Player
	arena.add_child(player)
	await _frames(2)
	var player_applied: bool = _hit(player.hurtbox, 1, CombatLayers.Team.ENEMY)
	var player_count: int = blood.droplets.size()
	_check("rules: the player gets a small spurt when damaged (%d droplets, fewer than the enemy's kill)" % player_count, player_applied and player_count == blood.config.player_hit_droplets)
	blood.clear()
	player.health._invulnerable_left = 0.0
	player._set_state(Player.State.DASH)
	var dash_applied: bool = _hit(player.hurtbox, 1, CombatLayers.Team.ENEMY)
	player._set_state(Player.State.IDLE)
	_check("rules: no blood during dash invulnerability (no damage lands) %s %d" % [str(dash_applied), blood.droplets.size()], not dash_applied and blood.droplets.is_empty())
	# OFF: nothing at all.
	_new_arena({"blood": false})
	var off_enemy := _enemy(MELEE)
	await _frames(2)
	_hit(off_enemy.hurtbox)
	_hit(off_enemy.hurtbox, 99)
	await _frames(3)
	var children: int = blood.get_child_count()
	_check("option off: no droplets, no stains and no blood nodes at all, only the existing sparks (%d / %d / %d children)" % [blood.droplets.size(), blood.stains.size(), children], blood.droplets.is_empty() and blood.stains.is_empty() and children == 0 and not blood.enabled)


func _test_caps_fade_reduced() -> void:
	_new_arena()
	var created: int = blood.spurt(Vector2.ZERO, Vector2.UP, 1000, 1.0)
	_check("caps: a thousand droplets ask for room and only %d exist (cap %d)" % [blood.droplets.size(), blood.config.max_droplets], blood.droplets.size() <= blood.config.max_droplets and created <= blood.config.max_droplets)
	for i in 600:
		blood._add_stain(Vector2(i, 0), 3.0)
	_check("caps: the stains never exceed the cap (%d of %d)" % [blood.stains.size(), blood.config.max_stains], blood.stains.size() <= blood.config.max_stains and blood.stains.size() > 0)
	_check("fade: the default stain time is about 8 s and it lives in the exported resource", is_equal_approx(blood.config.stain_fade_seconds, 8.0))
	blood.clear()
	blood.config = blood.config.duplicate() as BloodConfig
	blood.config.stain_fade_seconds = 1.0
	for i in 60:
		blood._add_stain(Vector2(i, 0), 3.0)
	var started: int = Time.get_ticks_msec()
	blood.set_process(true)
	var gone: bool = false
	while Time.get_ticks_msec() - started < 3000:
		await get_tree().process_frame
		if blood.stains.is_empty():
			gone = true
			break
	var seconds: float = (Time.get_ticks_msec() - started) / 1000.0
	print("MEASURE|stain fade set to 1.0 s: all stains gone after %.2f s of real time" % seconds)
	_check("fade: the stains fade out in the exported time (%.2f s for 1.0 s)" % seconds, gone and seconds >= 0.9 and seconds <= 1.6)
	# Reduced effects keep blood with the reduced count.
	_new_arena()
	var full: int = blood.spurt(Vector2.ZERO, Vector2.UP, 10, blood.scale_for(null))
	_new_arena({"corruption_effects": false})
	var reduced: int = blood.spurt(Vector2.ZERO, Vector2.UP, 10, blood.scale_for(null))
	_check("reduced: with corruption effects off blood stays ON with the reduced count (%d against %d)" % [reduced, full], blood.enabled and blood.reduced and reduced == roundi(10 * blood.config.reduced_scale) and reduced < full)


func _test_layer_and_contrast() -> void:
	var drawer_z: int = int(FileAccess.get_file_as_string("res://frontend/fx/telegraph_drawer.gd").contains("z_index = -1"))
	_check("layer: blood is drawn at z %d, BELOW the telegraphs (z -1), the hazards, the plates and the boss platforms (z 2) and the UI (canvas layers)" % BloodFx.LAYER_Z, drawer_z == 1 and BloodFx.LAYER_Z < -1 and BloodFx.LAYER_Z < 2)
	var level := (load(LEVEL) as PackedScene).instantiate() as LevelBase
	add_child(level)
	await _frames(2)
	var in_level: BloodFx = level.get_node_or_null(^"BloodFx") as BloodFx
	_check("layer: the level has its BloodFx and it is on the dedicated layer", in_level != null and in_level.z_index == BloodFx.LAYER_Z)
	level.free()
	var config: BloodConfig = BloodConfig.get_default()
	var set_resource: TelegraphSet = TelegraphSet.get_default()
	var floors: Array[Color] = []
	for file in DirAccess.get_files_at(BIOME_DIR):
		if file.ends_with("_biome.tres"):
			var biome := load(BIOME_DIR + file) as Biome
			floors.append_array([biome.grass, biome.grass_dark, biome.soil, biome.soil_dark, biome.rock, biome.rock_dark])
	var warnings: Array[Color] = []
	var names: Array[String] = []
	for kind in TelegraphSet.KINDS:
		var style: TelegraphStyle = set_resource.get_style(kind)
		warnings.append(style.color)
		names.append("telegraph %s" % kind)
	warnings.append_array([Color(1.0, 0.93, 0.8), Color(0.78, 0.92, 1.0), Color(1.0, 0.97, 0.62), Color(1.0, 0.56, 0.36)])
	names.append_array(["spikes", "electric plate warning", "electric plate shock", "floor hazard glow"])
	var projectile := (load("res://backend/combat/projectile.tscn") as PackedScene).instantiate() as Projectile
	if projectile.visual is Polygon2D:
		warnings.append((projectile.visual as Polygon2D).color)
		names.append("enemy projectile")
	projectile.free()
	var stain: Color = Color(config.blood_color, config.stain_opacity)
	var possession_red: Color = Color(0.95, 0.12, 0.08)
	var worst: float = 99.0
	var worst_name: String = ""
	var worst_possession: float = 99.0
	for i in warnings.size():
		for ground in floors:
			var stained: Color = ground.lerp(Color(config.blood_color.r, config.blood_color.g, config.blood_color.b), stain.a)
			var outline: Color = Color(0.106, 0.098, 0.122)
			var reads: float = maxf(_contrast(warnings[i], stained), _contrast(outline, stained))
			if i < TelegraphSet.KINDS.size():
				reads = maxf(reads, _contrast(warnings[i], stained))
			if reads < worst:
				worst = reads
				worst_name = names[i]
		var over_red: Color = possession_red.lerp(Color(config.blood_color.r, config.blood_color.g, config.blood_color.b), stain.a)
		worst_possession = minf(worst_possession, maxf(_contrast(warnings[i], over_red), _contrast(Color(0.106, 0.098, 0.122), over_red)))
	print("MEASURE|contrast with stains (opacity %.2f): worst %.2f (%s), worst over the possession red %.2f, threshold %.1f" % [stain.a, worst, worst_name, worst_possession, MIN_CONTRAST])
	_check("contrast: every telegraph, the spikes, the electric plates and the enemy projectiles keep >= 2.5 against the floor WITH stains (worst %.2f: %s)" % [worst, worst_name], worst >= MIN_CONTRAST)
	_check("contrast: ... and against the persistent possession red with a stain on it (worst %.2f)" % worst_possession, worst_possession >= MIN_CONTRAST)


func _test_cleanup() -> void:
	_new_arena()
	blood.spurt(Vector2.ZERO, Vector2.UP, 30, 1.0)
	for i in 20:
		blood._add_stain(Vector2(i, 0), 3.0)
	var player := (load(PLAYER) as PackedScene).instantiate() as Player
	arena.add_child(player)
	await _frames(2)
	player.respawned.emit()
	_check("cleanup: a retry (the player respawning) clears every droplet and stain", blood.droplets.is_empty() and blood.stains.is_empty())
	blood.spurt(Vector2.ZERO, Vector2.UP, 30, 1.0)
	blood._add_stain(Vector2.ZERO, 3.0)
	_set_options({"blood": false})
	blood.refresh_settings()
	_check("cleanup: turning the option off (also from the pause menu) clears everything at once", blood.droplets.is_empty() and blood.stains.is_empty())
	_set_options({})
	blood.refresh_settings()
	blood.spurt(Vector2.ZERO, Vector2.UP, 30, 1.0)
	var first: float = (blood.droplets[0]["p"] as Vector2).y
	get_tree().paused = true
	await get_tree().create_timer(0.4, true).timeout
	var frozen: bool = is_equal_approx((blood.droplets[0]["p"] as Vector2).y, first)
	get_tree().paused = false
	_check("cleanup: while the game is paused the blood stands still and resumes after", frozen)
	var level := (load(LEVEL) as PackedScene).instantiate() as LevelBase
	add_child(level)
	await _frames(2)
	var level_blood: BloodFx = level.get_node(^"BloodFx") as BloodFx
	level_blood.spurt(Vector2.ZERO, Vector2.UP, 30, 1.0)
	level.free()
	await _frames(2)
	_check("cleanup: reloading the level frees its blood (no BloodFx node outlives it, blood never persists across levels)", not is_instance_valid(level_blood) and get_tree().root.find_children("*", "BloodFx", true, false).size() <= 1)


func _test_endings() -> void:
	# Blood belongs to gameplay combat only: no ending, intro or story scene has it, in the files or at run time.
	var offenders: PackedStringArray = PackedStringArray()
	for dir in ["res://frontend/story/", "res://frontend/prologue/", "res://frontend/ui/", "res://frontend/presentation/"]:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".tscn") or file.ends_with(".tres"):
				var text: String = FileAccess.get_file_as_string(dir + file)
				if text.contains("blood_fx") or text.contains("BloodFx"):
					offenders.append(dir + file)
	_check("scope: no ending, prologue, story or UI scene contains the blood node (%s)" % str(offenders), offenders.is_empty())
	_set_options({})
	GameState.start_new_game()
	for kept in [3, 0]:
		GameState.souls_kept = kept
		GameState.souls_released = 3 - kept
		var ending := (load("res://frontend/ui/ending.tscn") as PackedScene).instantiate() as EndingController
		ending.skip_reel_when_headless = false
		add_child(ending)
		await _frames(30)
		var found: Array[Node] = ending.find_children("*", "BloodFx", true, false)
		var drawn: bool = false
		for node in get_tree().root.find_children("*", "BloodFx", true, false):
			drawn = drawn or ending.is_ancestor_of(node)
		_check("scope: while an ending plays there is no blood node (%d found)" % found.size(), found.is_empty() and not drawn)
		ending.free()
		await _frames(2)


func _test_leaks_and_neutrality() -> void:
	_new_arena()
	var enemy_a := _enemy(MELEE)
	var enemy_b := _enemy(MELEE)
	await _frames(2)
	blood.enabled = false
	var hp_off: int = 0
	_hit(enemy_a.hurtbox, 2)
	hp_off = enemy_a.health.current_health
	blood.enabled = true
	_hit(enemy_b.hurtbox, 2)
	var layers_equal: bool = enemy_a.hurtbox.collision_layer == enemy_b.hurtbox.collision_layer and enemy_a.hurtbox.collision_mask == enemy_b.hurtbox.collision_mask and enemy_a.hurtbox.monitorable == enemy_b.hurtbox.monitorable
	_check("neutral: the same hit does the same damage with blood on and off (%d / %d) and the hitboxes are identical" % [hp_off, enemy_b.health.current_health], hp_off == enemy_b.health.current_health and layers_equal)
	var nodes_before: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var biggest: int = 0
	var peak_stains: int = 0
	var target := _enemy(MELEE)
	await _frames(2)
	var nodes_with_target: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for i in 200:
		target.health.current_health = target.health.max_health
		target.health._invulnerable_left = 0.0
		target.health.is_dead = false
		_hit(target.hurtbox)
		biggest = maxi(biggest, blood.droplets.size())
		peak_stains = maxi(peak_stains, blood.stains.size())
		if i % 20 == 0:
			await get_tree().process_frame
	await _frames(5)
	var nodes_after: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("MEASURE|200 hits: node count %d -> %d (with the target %d), most droplets at once %d (cap %d), most stains %d (cap %d)" % [nodes_before, nodes_after, nodes_with_target, biggest, blood.config.max_droplets, peak_stains, blood.config.max_stains])
	_check("leaks: 200 hits create no nodes (%d before, %d after) and the caps held (%d droplets, %d stains)" % [nodes_with_target, nodes_after, biggest, peak_stains], nodes_after <= nodes_with_target + 2 and biggest <= blood.config.max_droplets and peak_stains <= blood.config.max_stains)
	var keys: Array = GameState.to_dict().keys()
	keys.sort()
	var expected: Array = SAVE_KEYS.duplicate()
	expected.sort()
	_check("save: after the fights it is still the seven keys", keys == expected)


# ---------------------------------------------------------------------------------------------

static func _channel(value: float) -> float:
	return value / 12.92 if value <= 0.03928 else pow((value + 0.055) / 1.055, 2.4)


static func _luminance(color: Color) -> float:
	return 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b)


static func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
