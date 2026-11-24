extends Node
## Headless smoke test for Phase 14e (enemy readability and feel, presentation only): the telegraph
## resource (one style per enemy type and boss pattern), the telegraph shown exactly during the windup,
## the windup sounds, the hit flash / pop, the recovery cue and the death wisp, the explicit check that
## NO timing or stat changed (windup / active / recovery of every enemy type and boss pattern, and
## the stats that matter, are compared with the values recorded in Phase 14e's audit), the colour
## contrast against the three profile looks, no leaked nodes after repeated spawn / kill cycles, the
## three story text patches, and the guards (7 save keys, 3 autoloads). Development only. Run:
##   <godot> --headless --path game res://frontend/scenes/test/phase14e_smoke_test.tscn
## Uses a redirected save path; the AI service stays disabled; the real save is never touched.

const TEST_SAVE: String = "user://test_save_phase14e.json"
const ENEMY_SCENES: Dictionary = {
	"melee": "res://backend/enemies/melee_enemy.tscn",
	"fast": "res://backend/enemies/fast_enemy.tscn",
	"ranged": "res://backend/enemies/ranged_enemy.tscn",
}
const TOUGH_STATS: String = "res://backend/enemies/stats/melee_tough_stats.tres"
const BOSS_SCENES: Dictionary = {
	"placeholder": "res://backend/bosses/placeholder_boss.tscn",
	"two": "res://backend/bosses/boss_two.tscn",
	"three": "res://backend/bosses/boss_three.tscn",
}
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const BIOME_DIR: String = "res://frontend/levels/biome/"
const MIN_CONTRAST: float = 2.5

## Recorded in the Phase 14e audit (before any change): [startup, active, recovery] seconds of the
## attack of every enemy type, and the stats that give them their feel.
const ENEMY_TIMES: Dictionary = {
	"melee": [0.35, 0.15, 0.4],
	"melee_tough": [0.5, 0.15, 0.5],
	"fast": [0.4, 0.25, 0.7],
	"ranged": [0.5, 0.05, 0.4],
}
## [max_health, move_speed, attack_damage, attack_range, attack_cooldown, contact_damage, hurt_stun_time,
##  knockback_multiplier, detection_range, death_fade_time]  (the orb count was removed in Phase 15a)
const ENEMY_STATS: Dictionary = {
	"melee": [3, 90.0, 1, 48.0, 0.8, 1, 0.3, 1.0, 260.0, 0.5],
	"melee_tough": [8, 60.0, 2, 48.0, 1.2, 1, 0.15, 0.5, 260.0, 0.5],
	"fast": [2, 210.0, 1, 90.0, 0.6, 1, 0.25, 1.0, 200.0, 0.5],
	"ranged": [2, 70.0, 1, 300.0, 1.5, 1, 0.3, 1.0, 320.0, 0.5],
}
const ENEMY_KNOCKBACK: Dictionary = {
	"melee": Vector2(250, -150), "melee_tough": Vector2(350, -180), "fast": Vector2(200, -120), "ranged": Vector2(250, -150),
}
## Per boss scene and pattern id: [telegraph, active, recovery] seconds.
const BOSS_TIMES: Dictionary = {
	"placeholder": {"swipe": [0.6, 0.2, 0.6], "charge": [0.8, 0.7, 0.9], "volley": [0.7, 0.48, 0.8]},
	"two": {"swipe": [0.7, 0.25, 0.7], "charge": [0.7, 0.8, 0.8], "volley": [0.8, 0.36, 0.9]},
	"three": {"swipe": [0.5, 0.2, 0.5], "charge": [0.7, 0.7, 0.8]},
}
## [max_health, phase_2_health_ratio, phase_transition_time, phase_2_speed_multiplier, phase_2_pattern_gap_multiplier, pattern_gap_time]
const BOSS_STATS: Dictionary = {
	"placeholder": [40, 0.5, 1.5, 1.3, 0.6, 1.2],
	"two": [50, 0.55, 1.5, 1.35, 0.55, 1.1],
	"three": [102, 0.451, 1.2, 1.0, 0.7, 0.9],
}
## The shape each kind must have (they differ so the player learns them).
const SHAPES: Dictionary = {
	"melee": TelegraphStyle.Shape.ARC,
	"melee_tough": TelegraphStyle.Shape.ARC,
	"fast": TelegraphStyle.Shape.LANE,
	"ranged": TelegraphStyle.Shape.AIM_LINE,
	"boss_swipe": TelegraphStyle.Shape.ARC,
	"boss_charge": TelegraphStyle.Shape.LANE,
	"boss_volley": TelegraphStyle.Shape.AIM_FAN,
	"boss_leap": TelegraphStyle.Shape.MARKER,
	"boss_beam": TelegraphStyle.Shape.BEAM,
	"boss_columns": TelegraphStyle.Shape.COLUMNS,
}

var failures: int = 0
var real_save_before: String = ""
var set_resource: TelegraphSet = null
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig


func _ready() -> void:
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
	set_resource = load(TelegraphSet.DEFAULT_PATH) as TelegraphSet
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


func _physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _clean_state() -> void:
	PauseLock.reset(get_tree())
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.autosave_enabled = false


func _run() -> void:
	_clean_state()
	_test_guards()
	_test_resource()
	_test_contrast()
	_test_story_patches()
	await _test_recorded_times()
	await _test_enemy_telegraphs()
	await _test_boss_telegraphs()
	await _test_windup_sounds()
	await _test_hit_feel()
	await _test_death_and_leaks()
	_clean_state()
	SaveSystem.purge()
	GameState.autosave_enabled = true
	_check("the real save file was not touched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------

func _make_enemy(kind: String) -> EnemyBase:
	var scene_key: String = "melee" if kind == "melee_tough" else kind
	var enemy := (load(ENEMY_SCENES[scene_key]) as PackedScene).instantiate() as EnemyBase
	if kind == "melee_tough":
		enemy.stats = load(TOUGH_STATS) as EnemyStats
	return enemy


func _free(node: Variant) -> void:
	if is_instance_valid(node):
		(node as Node).queue_free()


func _telegraph_of(attacker: Node) -> TelegraphDrawer:
	return attacker.get_node_or_null("Telegraph") as TelegraphDrawer


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
	_check("autoloads: exactly GameState, SceneManager and AudioDirector",
		autoloads == PackedStringArray(["AudioDirector", "GameState", "SceneManager"]), str(autoloads))


# ---------------------------------------------------------------------------------------------
# 1. The resource
# ---------------------------------------------------------------------------------------------

func _test_resource() -> void:
	_check("telegraphs: an entry for every enemy type and boss pattern", set_resource.has_all_kinds() and set_resource.entries.size() == 10)
	var shapes_ok: bool = true
	var sounds_ok: bool = true
	var signatures: Dictionary = {}
	var colors: Array[Color] = []
	for kind in TelegraphSet.KINDS:
		var style: TelegraphStyle = set_resource.get_style(kind)
		shapes_ok = shapes_ok and style != null and style.shape == SHAPES[String(kind)] and style.size > 0.0 and style.width > 0.0
		sounds_ok = sounds_ok and style != null and style.windup_sounds.size() >= 2
		var signature: String = ""
		for entry: Variant in style.windup_sounds:
			var sound: Array = entry as Array
			sounds_ok = sounds_ok and ResourceLoader.exists("res://frontend/audio/sfx/" + String(sound[0]))
			signature += "%s|%s|%s;" % [str(sound[0]), str(sound[2]), str(sound[3])]
		signatures[signature] = true
		colors.append(style.color)
	_check("telegraphs: shapes match the design (melee arc, fast lane, ranged line, boss arc / lane / fan)", shapes_ok)
	_check("telegraphs: every windup sound file exists and every kind has its own sound set", sounds_ok and signatures.size() == 10)
	var distinct: bool = true
	for i in colors.size():
		for j in range(i + 1, colors.size()):
			distinct = distinct and (colors[i].r != colors[j].r or colors[i].g != colors[j].g or colors[i].b != colors[j].b)
	_check("telegraphs: every kind has its own colour", distinct)
	_check("telegraphs: kind rules", TelegraphSet.kind_of_pattern(&"swipe") == TelegraphSet.KIND_BOSS_SWIPE
		and TelegraphSet.kind_of_pattern(&"charge") == TelegraphSet.KIND_BOSS_CHARGE
		and TelegraphSet.kind_of_pattern(&"volley_heavy") == TelegraphSet.KIND_BOSS_VOLLEY
		and TelegraphSet.kind_of_pattern(&"volley_light") == TelegraphSet.KIND_BOSS_VOLLEY)


# ---------------------------------------------------------------------------------------------
# 2. Contrast
# ---------------------------------------------------------------------------------------------

static func _channel(c: float) -> float:
	return c / 12.92 if c <= 0.03928 else pow((c + 0.055) / 1.055, 2.4)


static func _luminance(color: Color) -> float:
	return 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b)


static func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _test_contrast() -> void:
	var presentation := load("res://frontend/presentation/default_profile_presentation.tres") as ProfilePresentation
	var backgrounds: Array[Color] = []
	var ground: Array[Color] = []
	for file in DirAccess.get_files_at(BIOME_DIR):
		if not file.ends_with("_biome.tres"):
			continue
		var biome := load(BIOME_DIR + file) as Biome
		var scenery: Array[Color] = [biome.sky_top, biome.sky_bottom, biome.haze, biome.far_color, biome.mid_color, biome.near_color]
		# The profile looks multiply the backdrop only.
		for profile in ["neutral", "compassionate", "corrupt"]:
			var tint: Color = presentation.get_look(profile).background_tint
			for color in scenery:
				backgrounds.append(Color(clampf(color.r * tint.r, 0.0, 1.0), clampf(color.g * tint.g, 0.0, 1.0), clampf(color.b * tint.b, 0.0, 1.0)))
		# The gameplay layer (ground) never gets a profile tint.
		ground.append_array([biome.grass, biome.grass_dark, biome.soil, biome.soil_dark, biome.rock, biome.rock_dark])
	_check("contrast: %d background colours checked (7 biomes x 3 looks) plus %d ground colours" % [backgrounds.size(), ground.size()], backgrounds.size() >= 100 and ground.size() >= 40)
	var worst: float = 99.0
	var separation: float = 99.0
	for kind in TelegraphSet.KINDS:
		var style: TelegraphStyle = set_resource.get_style(kind)
		separation = minf(separation, _contrast(style.color, style.outline_color))
		for bg in backgrounds + ground:
			# The shape is drawn over a dark outline, so it reads if either tone stands out from the background.
			worst = minf(worst, maxf(_contrast(style.color, bg), _contrast(style.outline_color, bg)))
	print("CONTRAST: worst best-of-two contrast %.2f (threshold %.1f), colour vs outline %.2f" % [worst, MIN_CONTRAST, separation])
	_check("contrast: every telegraph reads against every background and ground colour (>= %.1f)" % MIN_CONTRAST, worst >= MIN_CONTRAST, "%.2f" % worst)
	_check("contrast: each telegraph colour stands out from its own outline (>= 4.5)", separation >= 4.5, "%.2f" % separation)


# ---------------------------------------------------------------------------------------------
# 3. Story patches
# ---------------------------------------------------------------------------------------------

func _test_story_patches() -> void:
	var texts := load(StoryTexts.DEFAULT_PATH) as StoryTexts
	var kept_ending: String = " ".join(texts.get_ending("ending_kept").lines)
	_check("story (b): the kept ending (Phase 15h) ends with the grandfather's «Se ha sellado la profecía.» (Phase 15t)", kept_ending.contains("Abuelo: Se ha sellado la profecía.") and not kept_ending.contains("daba igual lo que decidieras"))
	_check("story (c): the grandfather scene line has plain guillemets", texts.elder_lines.has("«Quien la empuñe decidirá cada alma: liberarla o cargarla.»")
		and not " ".join(texts.elder_lines).contains("««") and not " ".join(texts.elder_lines).contains("»»"))
	var storm: BossStory = texts.get_boss(3)
	_check("story (a): the storm has one first-sight line and its last words (Phase 15n)", storm.pre_lines.size() == 1 and storm.defeat_lines.size() >= 2)
	var no_duplicates: bool = true
	for entry: Variant in texts.bosses:
		var boss := entry as BossStory
		var said: Array[String] = []
		said.append_array(boss.pre_lines)
		for variant: Variant in boss.variant_lines.values():
			said.append(String(variant))
		said.append_array(boss.defeat_lines)
		no_duplicates = no_duplicates and _unique(said)
	for entry: Variant in texts.endings:
		no_duplicates = no_duplicates and _unique((entry as EndingStory).lines)
	var elder: Array[String] = []
	elder.append_array(texts.elder_lines)
	elder.append_array(texts.elder_mood_lines)
	no_duplicates = no_duplicates and _unique(elder)
	_check("story: no duplicated line in any speaker's list", no_duplicates)
	var short: bool = true
	for entry: Variant in texts.endings:
		for line in (entry as EndingStory).lines:
			short = short and line.length() <= 110
	_check("story: the patched lines keep the 110-character limit", short)


func _unique(lines: Array[String]) -> bool:
	var seen: Dictionary = {}
	for line in lines:
		if seen.has(line):
			return false
		seen[line] = true
	return true


# ---------------------------------------------------------------------------------------------
# 4. Nothing changed: recorded times and stats
# ---------------------------------------------------------------------------------------------

func _test_recorded_times() -> void:
	for kind in ENEMY_TIMES.keys():
		var enemy: EnemyBase = _make_enemy(kind)
		add_child(enemy)
		await _frames(2)
		var times: Array = ENEMY_TIMES[kind]
		var got: Array[float] = [enemy._attack_phase_duration(EnemyBase.AttackPhase.STARTUP),
			enemy._attack_phase_duration(EnemyBase.AttackPhase.ACTIVE), enemy._attack_phase_duration(EnemyBase.AttackPhase.RECOVERY)]
		_check("times: %s windup / active / recovery are exactly %s" % [kind, str(times)],
			is_equal_approx(got[0], times[0]) and is_equal_approx(got[1], times[1]) and is_equal_approx(got[2], times[2]), str(got))
		var s: EnemyStats = enemy.stats
		var expected: Array = ENEMY_STATS[kind]
		var stats_ok: bool = s.max_health == expected[0] and is_equal_approx(s.move_speed, expected[1]) and s.attack_damage == expected[2] \
				and is_equal_approx(s.attack_range, expected[3]) and is_equal_approx(s.attack_cooldown, expected[4]) and s.contact_damage == expected[5] \
				and is_equal_approx(s.hurt_stun_time, expected[6]) and is_equal_approx(s.knockback_multiplier, expected[7]) \
				and is_equal_approx(s.detection_range, expected[8]) and is_equal_approx(s.death_fade_time, expected[9]) \
				and s.attack_knockback.is_equal_approx(ENEMY_KNOCKBACK[kind])
		_check("stats: %s keeps every gameplay value of the audit" % kind, stats_ok)
		_free(enemy)
		await _frames(2)
	for scene_key in BOSS_SCENES.keys():
		var boss := (load(BOSS_SCENES[scene_key]) as PackedScene).instantiate() as BossBase
		add_child(boss)
		await _frames(2)
		var bs: BossStats = boss.stats
		var expected_stats: Array = BOSS_STATS[scene_key]
		_check("stats: boss %s keeps its health, phase 2 and gap values" % scene_key, bs.max_health == expected_stats[0]
			and is_equal_approx(bs.phase_2_health_ratio, expected_stats[1]) and is_equal_approx(bs.phase_transition_time, expected_stats[2])
			and is_equal_approx(bs.phase_2_speed_multiplier, expected_stats[3]) and is_equal_approx(bs.phase_2_pattern_gap_multiplier, expected_stats[4])
			and is_equal_approx(bs.pattern_gap_time, expected_stats[5]))
		var table: Dictionary = BOSS_TIMES[scene_key]
		# Phase 15c added the leap patterns of boss two on purpose: the recorded patterns are the other ones.
		var recorded: Array[BossPattern] = []
		for candidate in boss.patterns:
			if candidate.fallback_priority == 0 and not (candidate is LeapPattern or candidate is SummonerCyclePattern or candidate is StompPattern) and String(candidate.pattern_id) != "volley_leap" and not (scene_key == "three" and String(candidate.pattern_id) == "volley"):
				recorded.append(candidate)
		var patterns_ok: bool = recorded.size() == table.size()
		for pattern in recorded:
			var id: String = String(pattern.pattern_id)
			patterns_ok = patterns_ok and table.has(id)
			if not table.has(id):
				continue
			var want: Array = table[id]
			var times_ok: bool = is_equal_approx(pattern._phase_duration(BossPattern.PHASE_TELEGRAPH), want[0]) \
					and is_equal_approx(pattern._phase_duration(BossPattern.PHASE_ACTIVE), want[1]) \
					and is_equal_approx(pattern._phase_duration(BossPattern.PHASE_RECOVERY), want[2])
			_check("times: boss %s / %s telegraph, active, recovery are exactly %s" % [scene_key, id, str(want)], times_ok,
				"%s %s %s" % [pattern._phase_duration(BossPattern.PHASE_TELEGRAPH), pattern._phase_duration(BossPattern.PHASE_ACTIVE), pattern._phase_duration(BossPattern.PHASE_RECOVERY)])
		_check("times: boss %s has exactly the recorded patterns" % scene_key, patterns_ok)
		_free(boss)
		await _frames(2)


# ---------------------------------------------------------------------------------------------
# 5. Enemy telegraphs
# ---------------------------------------------------------------------------------------------

func _test_enemy_telegraphs() -> void:
	for kind in ["melee", "melee_tough", "fast", "ranged"]:
		_clean_state()
		var enemy: EnemyBase = _make_enemy(kind)
		add_child(enemy)
		await _frames(3)
		_check("telegraph (%s): nothing is built until the first windup" % kind, _telegraph_of(enemy) == null)
		var seen: Array = []
		enemy.attack_phase_changed.connect(func(phase: int) -> void:
			var d: TelegraphDrawer = _telegraph_of(enemy)
			seen.append([phase, d != null and d.active, d != null and d.visible]))
		enemy._start_attack()
		await _frames(2)
		var drawer: TelegraphDrawer = _telegraph_of(enemy)
		_check("telegraph (%s): shown the moment the windup starts" % kind, drawer.active and drawer.visible and seen.size() >= 1 and seen[0][1] == true)
		var style: TelegraphStyle = set_resource.get_style(TelegraphSet.kind_of_enemy(enemy))
		_check("telegraph (%s): uses the %s style" % [kind, str(style.kind)], drawer.style == style)
		await _physics(8)
		var early: float = drawer.progress
		await _physics(8)
		_check("telegraph (%s): it fills as the windup runs (%.2f -> %.2f)" % [kind, early, drawer.progress], drawer.progress > early and drawer.progress <= 1.0)
		var guard: int = 0
		while enemy._attack_phase == EnemyBase.AttackPhase.STARTUP and guard < 200:
			await get_tree().physics_frame
			guard += 1
		await _frames(1)
		var active_seen: bool = false
		var recovery_seen: bool = false
		for entry: Array in seen:
			if entry[0] == EnemyBase.AttackPhase.ACTIVE:
				active_seen = true
				_check("telegraph (%s): gone exactly when the active phase begins" % kind, entry[1] == false and entry[2] == false)
			if entry[0] == EnemyBase.AttackPhase.RECOVERY:
				recovery_seen = true
				_check("telegraph (%s): still gone in recovery" % kind, entry[1] == false)
		_check("telegraph (%s): the attack went through active%s" % [kind, " and recovery" if recovery_seen else ""], active_seen)
		guard = 0
		while enemy.state == EnemyBase.State.ATTACK and guard < 400:
			await get_tree().physics_frame
			guard += 1
		_check("telegraph (%s): hidden after the attack ends" % kind, not drawer.active and not drawer.visible)
		# Cancelled by a hit.
		enemy._start_attack()
		await _physics(5)
		var shown: bool = drawer.active
		enemy.health.apply_damage(DamageInfo.create(1, Vector2(100, -50), null, CombatLayers.Team.PLAYER))
		await _frames(2)
		_check("telegraph (%s): gone when a hit cancels the windup" % kind, shown and not drawer.active and not drawer.visible)
		await get_tree().create_timer(enemy.stats.hurt_stun_time + 0.3).timeout
		# Killed during the windup.
		enemy._start_attack()
		await _physics(5)
		shown = drawer.active
		enemy.health.kill()
		await _frames(2)
		_check("telegraph (%s): gone when it dies mid-windup" % kind, shown and not drawer.active and not drawer.visible)
		_free(enemy)
		await _frames(2)
	_clean_state()


# ---------------------------------------------------------------------------------------------
# 6. Boss telegraphs
# ---------------------------------------------------------------------------------------------

func _test_boss_telegraphs() -> void:
	for scene_key in BOSS_SCENES.keys():
		_clean_state()
		var boss := (load(BOSS_SCENES[scene_key]) as PackedScene).instantiate() as BossBase
		add_child(boss)
		var dummy := Node2D.new()
		add_child(dummy)
		dummy.global_position = boss.global_position + Vector2(200, 0)
		await _frames(3)
		boss.activate(dummy)
		var drawer: TelegraphDrawer = null
		for pattern in boss.patterns:
			var id: String = String(pattern.pattern_id)
			if pattern is SummonerCyclePattern and (pattern as SummonerCyclePattern).stage_of(boss) == null:
				# Phase 15q: the summon cycle needs the level's BossStage (the pattern is never eligible without it); its telegraph is covered by phase15d/15j.
				print("MEASURE|boss %s / %s: skipped here (no BossStage in this bare scene)" % [scene_key, id])
				continue
			if boss.state != BossBase.State.IDLE:
				boss._cancel_current_pattern()
				boss._set_state(BossBase.State.IDLE)
			# The boss must not pick patterns by itself while one is driven by hand.
			boss._gap_left = 99.0
			boss._start_pattern(pattern)
			await _frames(2)
			drawer = _telegraph_of(boss)
			var kind: StringName = TelegraphSet.kind_of_pattern(pattern.pattern_id)
			_check("boss %s / %s: telegraph shown at the start of the telegraph phase" % [scene_key, id], drawer != null and drawer.active
				and drawer.style == set_resource.get_style(kind))
			if pattern is ProjectileVolleyPattern:
				_check("boss %s / %s: the fan shows every projectile" % [scene_key, id], drawer.fan_count == (pattern as ProjectileVolleyPattern).projectile_count
					and is_equal_approx(drawer.fan_degrees, (pattern as ProjectileVolleyPattern).spread_angle_degrees))
			if pattern is ChargePattern:
				_check("boss %s / %s: the lane is the real charge distance" % [scene_key, id], is_equal_approx(drawer.reach,
					maxf((pattern as ChargePattern).planned_lane, 1.0)) and drawer.reach <= (pattern as ChargePattern).charge_speed * (pattern as ChargePattern).charge_duration + 0.01)
			var guard: int = 0
			var peak: float = 0.0
			while pattern.phase_name == BossPattern.PHASE_TELEGRAPH and guard < 300:
				await get_tree().physics_frame
				peak = maxf(peak, drawer.progress)
				guard += 1
			await _frames(1)
			_check("boss %s / %s: it filled during the telegraph (%.2f)" % [scene_key, id, peak], peak > 0.4)
			_check("boss %s / %s: gone when the active phase begins" % [scene_key, id], not drawer.active and not drawer.visible)
			# Cancelled mid-telegraph (a phase change, a reset or a kill do this).
			boss._cancel_current_pattern()
			boss._set_state(BossBase.State.IDLE)
			boss._start_pattern(pattern)
			await _frames(2)
			var shown: bool = drawer.active
			boss._cancel_current_pattern()
			boss._set_state(BossBase.State.IDLE)
			await _frames(2)
			_check("boss %s / %s: gone when the pattern is cancelled" % [scene_key, id], shown and not drawer.active and not drawer.visible)
		# Phase 2 and the kill never leave it on.
		boss._set_state(BossBase.State.IDLE)
		boss._start_pattern(boss.patterns[0])
		await _frames(2)
		boss.health.apply_damage(DamageInfo.create(boss.health.max_health, Vector2.ZERO, null, CombatLayers.Team.PLAYER))
		await _frames(3)
		_check("boss %s: no telegraph left after phase 2 or the kill" % scene_key, drawer != null and not drawer.active and not drawer.visible)
		_free(boss)
		_free(dummy)
		await _frames(2)
	_clean_state()


# ---------------------------------------------------------------------------------------------
# 7. Windup sounds
# ---------------------------------------------------------------------------------------------

func _test_windup_sounds() -> void:
	for kind in ["melee", "melee_tough", "fast", "ranged"]:
		_clean_state()
		var enemy: EnemyBase = _make_enemy(kind)
		add_child(enemy)
		await _frames(3)
		enemy.attack_phase_changed.connect(AudioDirector._on_enemy_attack_phase.bind(enemy))
		var before: int = AudioDirector.windup_count
		enemy._start_attack()
		await _frames(2)
		_check("windup sound (%s): played once for one windup" % kind, AudioDirector.windup_count == before + 1
			and AudioDirector.last_windup_kind == TelegraphSet.kind_of_enemy(enemy), str(AudioDirector.last_windup_kind))
		var guard: int = 0
		while enemy.state == EnemyBase.State.ATTACK and guard < 400:
			await get_tree().physics_frame
			guard += 1
		_check("windup sound (%s): the active and recovery phases add none" % kind, AudioDirector.windup_count == before + 1)
		enemy.health.kill()
		await _frames(2)
		var after_death: int = AudioDirector.windup_count
		AudioDirector._on_enemy_attack_phase(EnemyBase.AttackPhase.STARTUP, enemy)
		_check("windup sound (%s): never for an enemy that is already dead" % kind, AudioDirector.windup_count == after_death)
		_free(enemy)
		await _frames(2)
	for scene_key in BOSS_SCENES.keys():
		var boss := (load(BOSS_SCENES[scene_key]) as PackedScene).instantiate() as BossBase
		add_child(boss)
		await _frames(3)
		var kinds: Array[StringName] = []
		for pattern in boss.patterns:
			var before: int = AudioDirector.windup_count
			AudioDirector._on_boss_pattern(pattern.pattern_id, boss)
			var kind: StringName = TelegraphSet.kind_of_pattern(pattern.pattern_id)
			_check("windup sound: boss %s / %s plays its own sound once" % [scene_key, pattern.pattern_id], AudioDirector.windup_count == before + 1
				and AudioDirector.last_windup_kind == kind)
			kinds.append(kind)
		boss.health.kill()
		await _frames(2)
		var count: int = AudioDirector.windup_count
		AudioDirector._on_boss_pattern(&"charge", boss)
		_check("windup sound: boss %s says nothing once defeated" % scene_key, AudioDirector.windup_count == count)
		_free(boss)
		await _frames(2)


# ---------------------------------------------------------------------------------------------
# 8. Hit flash, pop and the recovery cue
# ---------------------------------------------------------------------------------------------

func _find_visual(attacker: Node) -> Node2D:
	return attacker.get_node("Visual") as Node2D


func _test_hit_feel() -> void:
	for kind in ["melee", "fast", "ranged"]:
		_clean_state()
		var enemy: EnemyBase = _make_enemy(kind)
		add_child(enemy)
		await _frames(3)
		var visual: Node2D = _find_visual(enemy)
		var rig: DuckRig = visual.get("rig") as DuckRig
		var base_scale: Vector2 = rig.scale
		var stats_before: Array = [enemy.stats.hurt_stun_time, enemy.stats.knockback_multiplier, enemy.stats.attack_startup_time, enemy.stats.attack_recovery_time]
		var push := Vector2(180, -90)
		enemy.health.apply_damage(DamageInfo.create(1, push, null, CombatLayers.Team.PLAYER))
		# Read at once, before any physics frame: the hit's own numbers.
		_check("hit (%s): the flash does not change the knockback or the hitstun" % kind, enemy.state == EnemyBase.State.HURT
			and enemy.velocity.is_equal_approx(push * enemy.stats.knockback_multiplier) and is_equal_approx(enemy._state_time_left, enemy.stats.hurt_stun_time),
			"%s %s" % [str(enemy.velocity), str(enemy._state_time_left)])
		await _frames(1)
		_check("hit (%s): a white-hot flash (every channel above 1)" % kind, visual.modulate.r > 1.5 and visual.modulate.g > 1.5 and visual.modulate.b > 1.5, str(visual.modulate))
		_check("hit (%s): a small pop on the rig" % kind, not rig.scale.is_equal_approx(base_scale))
		await get_tree().create_timer(0.35).timeout
		_check("hit (%s): flash and pop are over and the stats are untouched" % kind, visual.modulate.r < 1.5 and rig.scale.is_equal_approx(base_scale)
			and stats_before == [enemy.stats.hurt_stun_time, enemy.stats.knockback_multiplier, enemy.stats.attack_startup_time, enemy.stats.attack_recovery_time])
		_free(enemy)
		await _frames(2)
	# The recovery cue (a faint dim) on a melee enemy, then back to normal.
	var melee: EnemyBase = _make_enemy("melee")
	add_child(melee)
	await _frames(3)
	var melee_visual: Node2D = _find_visual(melee)
	var recovery_color: Color = melee_visual.get("recovery_color") as Color
	melee._start_attack()
	var guard: int = 0
	while melee._attack_phase != EnemyBase.AttackPhase.RECOVERY and guard < 200:
		await get_tree().physics_frame
		guard += 1
	await _frames(1)
	_check("recovery: the punish window is dimmed", melee_visual.modulate.is_equal_approx(recovery_color) and recovery_color.r < 0.9)
	var recovery_time: float = melee.stats.attack_recovery_time
	_check("recovery: its duration is untouched", is_equal_approx(recovery_time, 0.4))
	guard = 0
	while melee.state == EnemyBase.State.ATTACK and guard < 200:
		await get_tree().physics_frame
		guard += 1
	await _frames(2)
	_check("recovery: back to the normal colour afterwards", melee_visual.modulate.is_equal_approx(Color.WHITE))
	_free(melee)
	await _frames(2)
	# Bosses flash a little stronger than enemies.
	var boss := (load(BOSS_SCENES["two"]) as PackedScene).instantiate() as BossBase
	add_child(boss)
	await _frames(3)
	var boss_visual: Node2D = _find_visual(boss)
	var probe: Node = (load("res://backend/enemies/melee_enemy.tscn") as PackedScene).instantiate()
	var enemy_flash: float = probe.get_node("Visual").get("flash_color").r
	probe.free()
	boss.health.apply_damage(DamageInfo.create(1, Vector2.ZERO, null, CombatLayers.Team.PLAYER))
	await _frames(1)
	_check("hit (boss): a white-hot flash a little stronger than an enemy's", boss_visual.modulate.r > enemy_flash and boss_visual.modulate.r > 1.5)
	_free(boss)
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 9. Death effect and leaks
# ---------------------------------------------------------------------------------------------

func _count_wisps() -> int:
	return get_tree().root.find_children("SoulWisp*", "Node2D", true, false).size()


func _test_death_and_leaks() -> void:
	_clean_state()
	var enemy: EnemyBase = _make_enemy("melee")
	add_child(enemy)
	await _frames(3)
	enemy.health.kill()
	await _frames(3)
	_check("death: a soul wisp rises where the enemy fell", _count_wisps() == 1)
	await get_tree().create_timer(SoulWisp.LIFETIME + 0.4).timeout
	_check("death: the wisp frees itself", _count_wisps() == 0)
	_free(enemy)
	await _frames(3)
	# Repeated spawn / kill cycles must not leave nodes behind.
	var kinds: Array[String] = ["melee", "melee_tough", "fast", "ranged"]
	var counts: Array[int] = []
	for cycle in 8:
		for kind in kinds:
			var e: EnemyBase = _make_enemy(kind)
			add_child(e)
			await _frames(2)
			e._start_attack()
			await _physics(6)
			e.health.kill()
			await _frames(2)
			_free(e)
		await get_tree().create_timer(SoulWisp.LIFETIME + 0.3).timeout
		await _frames(2)
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	var growth: int = counts[counts.size() - 1] - counts[2]
	print("LEAK: node counts per cycle %s (growth after warm-up %d)" % [str(counts), growth])
	_check("leaks: no nodes left after 8 spawn / attack / kill cycles of every enemy type (growth %d)" % growth, growth <= 6)
	_check("leaks: no wisp or telegraph left in the tree", _count_wisps() == 0 and get_tree().root.find_children("Telegraph", "TelegraphDrawer", true, false).is_empty())
	# A boss killed and freed leaves nothing either.
	var boss := (load(BOSS_SCENES["three"]) as PackedScene).instantiate() as BossBase
	add_child(boss)
	var dummy := Node2D.new()
	add_child(dummy)
	await _frames(3)
	boss.activate(dummy)
	boss._start_pattern(boss.patterns[1])
	await _physics(6)
	boss.health.kill()
	await _frames(3)
	_free(boss)
	_free(dummy)
	await _frames(3)
	_check("leaks: a boss killed mid-telegraph leaves no telegraph behind", get_tree().root.find_children("Telegraph", "TelegraphDrawer", true, false).is_empty())
	_clean_state()
