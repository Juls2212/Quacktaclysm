extends Node
## Phase 14g balance MEASUREMENT (not part of the suite: the name has no "_test"). It changes nothing in
## the game; it only reads and runs it. Three parts, each printing "ROW|..." lines:
##   1. DPS: damage per second of every player attack against each boss, from the stats resources.
##   2. LEVELS (static): enemies, health, soul wisps, length and checkpoints of each level under each profile.
##   3. DUELS: each boss fought in a flat arena by a simple bot, per adaptive profile (boss aggression)
##      and per player health (8 and 11), with deaths, HP lost, heals used, soul gathered and wasted at the cap, and kill time.
##   5. BOSS2 (Phase 15c): the swamp guardian fought in the REAL level 2 arena (platforms, lily pads, leap, floor spikes).
##      The bot takes refuge on a low platform while the spikes warn or are out and climbs under a boss that is on a
##      platform; it never uses the lily pads on purpose and has no double jump (boss 2's decision comes after the fight).
##   4. RUNS: a naive run-through bot walks each real level (jumps at walls and gaps, swings at close
##      enemies, then fights the boss) per profile and health. The bot is crude: a level it cannot clear
##      says as much about the bot as about the level.
## Run (sequentially, never with the suite):
##   <godot> --headless --fixed-fps 60 --path game res://frontend/scenes/test/balance_measure.tscn [-- --only=dps|levels|duels|runs --seeds=N]
## Uses a redirected save path; the AI service stays disabled; SceneManager.dry_run is on.

const TEST_SAVE: String = "user://test_save_balance_measure.json"
const LEVEL_PATHS: Dictionary = {
	1: "res://frontend/levels/level_1.tscn", 2: "res://frontend/levels/level_2.tscn", 3: "res://frontend/levels/level_3.tscn",
}
const BOSSES: Dictionary = {
	1: preload("res://backend/bosses/placeholder_boss.tscn"),
	2: preload("res://backend/bosses/boss_two.tscn"),
	3: preload("res://backend/bosses/boss_three.tscn"),
}
const PROFILES: Array[String] = ["compassionate", "neutral", "corrupt"]
const FLOOR_Y: float = 300.0
const DUEL_TIMEOUT: float = 240.0
const RUN_TIMEOUT: float = 420.0
const STUCK_FRAMES: int = 1500

var only: String = ""
var seed_count: int = 2
var run_profile: String = ""
var run_hearts: int = 0
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig
var real_save_before: String = ""
var rng := RandomNumberGenerator.new()
var held: Dictionary = {}
## Frames until the walking bot dashes (after jumping a wide gap); -1 = none.
var dash_in: int = -1
## Frames since the jump at a gap edge (Phase 15e-2): the gaps of level 3 need jump, double jump (~0.6 s) and dash (~1.15 s). -1 = none.
var cross_frames: int = -1


func _ready() -> void:
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	real_save_before = FileAccess.get_file_as_string(SaveSystem.DEFAULT_PATH) if FileAccess.file_exists(SaveSystem.DEFAULT_PATH) else "<missing>"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
		elif argument.begins_with("--profile="):
			run_profile = argument.trim_prefix("--profile=")
		elif argument.begins_with("--hearts="):
			run_hearts = int(argument.trim_prefix("--hearts="))
		elif argument.begins_with("--seeds="):
			seed_count = int(argument.trim_prefix("--seeds="))
	_run.call_deferred()


func _run() -> void:
	SceneManager.dry_run = true
	if only.is_empty() or only == "dps":
		_dps()
	if only.is_empty() or only == "levels":
		await _levels_static()
	if only.is_empty() or only == "duels":
		await _duels()
	if only.is_empty() or only == "runs":
		await _runs()
	if only == "boss2":
		await _boss2_duels()
	_clean()
	SceneManager.dry_run = false
	SaveSystem.purge()
	var after: String = FileAccess.get_file_as_string(SaveSystem.DEFAULT_PATH) if FileAccess.file_exists(SaveSystem.DEFAULT_PATH) else "<missing>"
	print("REAL SAVE UNTOUCHED: %s" % str(after == real_save_before))
	get_tree().quit(0)


func _clean() -> void:
	PauseLock.reset(get_tree())
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.autosave_enabled = false
	for action in held.keys():
		Input.action_release(action)
	held.clear()


func _physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


# ---------------------------------------------------------------------------------------------
# 1. DPS from the stats resources
# ---------------------------------------------------------------------------------------------

func _dps() -> void:
	var stats := load("res://backend/player/default_player_stats.tres") as PlayerStats
	var wave := load("res://backend/player/default_sword_wave_config.tres") as SwordWaveConfig
	var sword_cycle: float = stats.attack_startup_time + stats.attack_active_time + stats.attack_recovery_time + stats.attack_cooldown
	var heavy_cycle: float = stats.heavy_startup_time + stats.heavy_active_time + stats.heavy_recovery_time + stats.heavy_cooldown
	var dash_slash_cycle: float = stats.dash_cooldown + stats.dash_duration + stats.dash_slash_extra_active_time + stats.dash_slash_extra_recovery_time
	var attacks: Array = [
		["sword", float(stats.attack_damage) / sword_cycle, stats.attack_damage, sword_cycle],
		["heavy", float(stats.heavy_damage) / heavy_cycle, stats.heavy_damage, heavy_cycle],
		["dash slash", float(stats.dash_slash_damage) / dash_slash_cycle, stats.dash_slash_damage, dash_slash_cycle],
	]
	for tier in 3:
		var t: SwordWaveTier = wave.get_tier(tier)
		var cycle: float = maxf(t.cooldown, wave.startup_time + wave.recovery_time)
		attacks.append(["wave tier %d" % tier, float(t.damage) / cycle, t.damage, cycle])
	for attack: Array in attacks:
		print("ROW|DPS|%s|damage %d|cycle %.2fs|dps %.2f" % [attack[0], attack[2], attack[3], attack[1]])
	for level in [1, 2, 3]:
		var boss := (BOSSES[level] as PackedScene).instantiate() as BossBase
		var hp: int = boss.stats.max_health
		var line: String = "ROW|BOSSDPS|boss %d|hp %d" % [level, hp]
		for attack: Array in attacks:
			var seconds: float = float(hp) / maxf(attack[1], 0.001)
			line += "|%s %.0fs" % [attack[0], seconds]
		print(line)
		boss.free()


# ---------------------------------------------------------------------------------------------
# 2. Levels, static
# ---------------------------------------------------------------------------------------------

func _levels_static() -> void:
	for number in [1, 2, 3]:
		for profile in PROFILES:
			_clean()
			GameState.adaptive_profile = profile
			var level := (load(LEVEL_PATHS[number]) as PackedScene).instantiate() as LevelBase
			add_child(level)
			await _physics(2)
			var counts: Dictionary = {}
			var total_hp: int = 0
			var soul_total: int = 0
			var enemy_damage: int = 0
			for node in level.find_children("*", "EnemyBase", true, false):
				var enemy := node as EnemyBase
				var kind: String = String(TelegraphSet.kind_of_enemy(enemy))
				counts[kind] = int(counts.get(kind, 0)) + 1
				total_hp += enemy.stats.max_health
				soul_total += SoulConfig.get_default().wisp_enemy
				enemy_damage += enemy.stats.attack_damage
			var boss: BossBase = level.boss
			var checkpoints: int = level.get_level_checkpoints().size()
			print("ROW|LEVEL|level %d|%s|enemies %d %s|enemy hp %d|soul from enemy wisps %d|boss wisp %d|length %d px|min run %.1fs|checkpoints %d|aggression %.2f" % [
				number, profile, level.find_children("*", "EnemyBase", true, false).size(), str(counts), total_hp, soul_total,
				SoulConfig.get_default().wisp_boss, level.camera_limits.size.x,
				float(level.camera_limits.size.x) / 300.0, checkpoints, boss.aggression_multiplier])
			level.free()
			await _physics(2)


# ---------------------------------------------------------------------------------------------
# 3. Boss duels
# ---------------------------------------------------------------------------------------------

func _hold(action: StringName, frames: int) -> void:
	if held.has(action):
		return
	Input.action_press(action)
	held[action] = frames


func _tick_held() -> void:
	for action: Variant in held.keys():
		held[action] -= 1
		if held[action] <= 0:
			Input.action_release(action)
			held.erase(action)


func _duels() -> void:
	var config := load(GameState.DEFAULT_ADAPTIVE_CONFIG_PATH) as AdaptiveConfig
	for level in [1, 2, 3]:
		for profile in PROFILES:
			var aggression: float = config.get_params(profile).boss_aggression
			for hearts in [8, 11]:
				var times: Array[float] = []
				var deaths: Array[int] = []
				var lost: Array[int] = []
				var heals: Array[int] = []
				var gathered: Array[int] = []
				var wasted: Array[int] = []
				var phase_two_times: Array[float] = []
				var defeated_count: int = 0
				for seed_index in seed_count:
					var result: Dictionary = await _duel(level, aggression, hearts, 1301 + seed_index * 1301)
					times.append(result["seconds"])
					deaths.append(result["deaths"])
					lost.append(result["hp_lost"])
					heals.append(result["heals"])
					gathered.append(result["gathered"])
					wasted.append(result["wasted"])
					defeated_count += 1 if result["defeated"] else 0
				print("ROW|DUEL|boss %d|%s (aggr %.2f)|hearts %d|kill %s s|deaths %s|hp lost %s|heals %s|soul gathered %s|soul wasted %s|defeated %d/%d" % [
					level, profile, aggression, hearts, str(times.map(func(v: float) -> float: return snappedf(v, 0.1))), str(deaths), str(lost), str(heals), str(gathered), str(wasted), defeated_count, seed_count])


func _duel(level: int, aggression: float, hearts: int, seed_value: int) -> Dictionary:
	_clean()
	rng.seed = seed_value
	var world := Node2D.new()
	add_child(world)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	floor_body.position = Vector2(400.0, FLOOR_Y + 20.0)
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(2000.0, 40.0)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	for wall_x in [-560.0, 1360.0]:
		var wall := StaticBody2D.new()
		wall.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
		wall.position = Vector2(wall_x, FLOOR_Y - 300.0)
		var wall_shape := CollisionShape2D.new()
		var wall_rect := RectangleShape2D.new()
		wall_rect.size = Vector2(40.0, 800.0)
		wall_shape.shape = wall_rect
		wall.add_child(wall_shape)
		world.add_child(wall)
	GameState.souls_released = hearts - 8
	var player := (load("res://backend/player/player.tscn") as PackedScene).instantiate() as Player
	player.position = Vector2(0.0, FLOOR_Y - 26.0)
	world.add_child(player)
	player.set_auto_respawn(true)
	var boss := (BOSSES[level] as PackedScene).instantiate() as BossBase
	boss.rng_seed = seed_value
	boss.position = Vector2(700.0, FLOOR_Y - 44.0)
	world.add_child(boss)
	await _physics(5)
	player.set_respawn_point(player.global_position)
	boss.set_aggression(aggression)
	var stats := {"deaths": 0, "hp_lost": 0, "heals": 0, "defeated": false}
	player.health.damaged.connect(func(info: DamageInfo) -> void: stats["hp_lost"] = int(stats["hp_lost"]) + info.amount)
	player.died.connect(func() -> void: stats["deaths"] = int(stats["deaths"]) + 1)
	boss.defeated.connect(func(_b: BossBase) -> void: stats["defeated"] = true)
	player.focus_completed.connect(func(healed: int) -> void: stats["heals"] = int(stats["heals"]) + (1 if healed > 0 else 0))
	boss.activate(player)
	var frame: int = 0
	var max_frames: int = int(DUEL_TIMEOUT * 60.0)
	while frame < max_frames and not bool(stats["defeated"]):
		await get_tree().physics_frame
		frame += 1
		_tick_held()
		if player.is_dead:
			continue
		_fight_step(player, boss)
	var gathered: int = player.soul.gained_total
	var wasted: int = player.soul.wasted_total
	var seconds: float = float(frame) / 60.0
	_clean()
	world.free()
	for child in get_children():
		if child is Projectile or child is SoulFragment or child is SoulPickup:
			child.free()
	return {"seconds": seconds, "deaths": stats["deaths"], "hp_lost": stats["hp_lost"], "heals": stats["heals"], "gathered": gathered, "wasted": wasted, "defeated": stats["defeated"]}


## The bots heal when two hearts or more are missing and the soul pays the cost.
func _wants_heal(player: Player) -> bool:
	return player.is_on_floor() and player.health.current_health <= player.health.max_health - 2 and player.soul.can_afford()


## One frame of the duel bot: walk to the boss, swing when close, cast waves from afar, jump and dash now
## and then.
func _fight_step(player: Player, boss: BossBase) -> void:
	var dx: float = boss.global_position.x - player.global_position.x
	# Heal when hurt and the soul is there: far from the boss, or when nearly dead. Held while it focuses.
	if player.state == Player.State.FOCUS:
		Input.action_press(&"heal")
		Input.action_release(&"move_left")
		Input.action_release(&"move_right")
		return
	Input.action_release(&"heal")
	if _wants_heal(player) and (absf(dx) > 220.0 or player.health.current_health <= 2):
		_hold(&"heal", 3)
		return
	var direction: StringName = &"move_right" if dx > 0.0 else &"move_left"
	var other: StringName = &"move_left" if dx > 0.0 else &"move_right"
	Input.action_release(other)
	if absf(dx) > 70.0 or rng.randf() < 0.3:
		Input.action_press(direction)
	else:
		Input.action_release(direction)
	if absf(dx) <= 110.0 and rng.randf() < 0.08:
		_hold(&"heavy_attack", 2)
	elif absf(dx) <= 110.0 and rng.randf() < 0.35:
		_hold(&"attack", 2)
	elif absf(dx) > 110.0 and rng.randf() < 0.3:
		_hold(&"wave", 2)
	if rng.randf() < 0.02:
		_hold(&"jump", rng.randi_range(4, 18))
	if rng.randf() < 0.01:
		_hold(&"dash", 2)


# ---------------------------------------------------------------------------------------------
# 5. Boss 2 in the real arena (Phase 15c)
# ---------------------------------------------------------------------------------------------

func _boss2_duels() -> void:
	var config := load(GameState.DEFAULT_ADAPTIVE_CONFIG_PATH) as AdaptiveConfig
	for profile in PROFILES:
		if not run_profile.is_empty() and profile != run_profile:
			continue
		var aggression: float = config.get_params(profile).boss_aggression
		for hearts in [8, 11]:
			var times: Array[float] = []
			var boss_left: Array[int] = []
			var airborne: Array[int] = []
			var deaths: Array[int] = []
			var lost: Array[int] = []
			var spikes: Array[int] = []
			var leaps: Array[int] = []
			var heals: Array[int] = []
			var defeated_count: int = 0
			for seed_index in seed_count:
				var result: Dictionary = await _duel_boss2(aggression, hearts, 1301 + seed_index * 1301)
				times.append(snappedf(result["seconds"], 0.1))
				boss_left.append(result["boss_hp_left"])
				airborne.append(result["boss_up_percent"])
				deaths.append(result["deaths"])
				lost.append(result["hp_lost"])
				spikes.append(result["spike_hits"])
				leaps.append(result["leaps"])
				heals.append(result["heals"])
				defeated_count += 1 if result["defeated"] else 0
			print("ROW|BOSS2|%s (aggr %.2f)|hearts %d|kill %s s|boss hp left %s of 60|boss on platforms %s %%|deaths %s|hp lost %s|spike hits %s|leaps %s|heals %s|defeated %d/%d" % [
				profile, aggression, hearts, str(times), str(boss_left), str(airborne), str(deaths), str(lost), str(spikes), str(leaps), str(heals), defeated_count, seed_count])


func _duel_boss2(aggression: float, hearts: int, seed_value: int) -> Dictionary:
	_clean()
	rng.seed = seed_value
	GameState.souls_released = hearts - 8
	GameState.record_decision("fragment_level_1", "placeholder_boss", 1, GameState.CHOICE_RELEASED)
	var level := (load(LEVEL_PATHS[2]) as PackedScene).instantiate() as LevelBase
	add_child(level)
	await _physics(5)
	for enemy in level.find_children("*", "EnemyBase", true, false):
		enemy.free()
	level.game_over_controller.show_game_over = false
	var player: Player = level.player
	player.set_auto_respawn(true)
	var boss: BossBase = level.boss
	boss.rng_seed = seed_value
	boss.set_rng_seed(seed_value)
	boss.set_aggression(aggression)
	var hazard := level.get_node("Content/FloorHazard") as FloorHazard
	var stats := {"deaths": 0, "hp_lost": 0, "heals": 0, "spike_hits": 0, "leaps": 0, "defeated": false, "up_frames": 0}
	player.health.damaged.connect(func(info: DamageInfo) -> void:
		stats["hp_lost"] = int(stats["hp_lost"]) + info.amount
		if info.source != null and info.source.get_parent() is FloorHazard:
			stats["spike_hits"] = int(stats["spike_hits"]) + 1)
	player.died.connect(func() -> void: stats["deaths"] = int(stats["deaths"]) + 1)
	boss.defeated.connect(func(_b: BossBase) -> void: stats["defeated"] = true)
	player.focus_completed.connect(func(healed: int) -> void: stats["heals"] = int(stats["heals"]) + (1 if healed > 0 else 0))
	for pattern in boss.patterns:
		if pattern is LeapPattern:
			(pattern as LeapPattern).leap_started.connect(func(_from: Vector2, _to: Vector2) -> void: stats["leaps"] = int(stats["leaps"]) + 1)
	player.global_position = level.encounter.global_position
	player.set_respawn_point(level.encounter.global_position)
	var frame: int = 0
	var max_frames: int = int(DUEL_TIMEOUT * 60.0)
	while frame < max_frames and not bool(stats["defeated"]):
		await get_tree().physics_frame
		frame += 1
		_tick_held()
		if is_instance_valid(boss) and boss.global_position.y < 520.0:
			stats["up_frames"] = int(stats["up_frames"]) + 1
		if player.is_dead:
			continue
		_boss2_step(player, boss, hazard, level)
	var seconds: float = float(frame) / 60.0
	var boss_hp_left: int = boss.health.current_health if is_instance_valid(boss) else 0
	var result := {"seconds": seconds, "boss_hp_left": boss_hp_left, "boss_up_percent": int(round(100.0 * float(stats["up_frames"]) / maxf(float(frame), 1.0))), "deaths": stats["deaths"], "hp_lost": stats["hp_lost"], "heals": stats["heals"], "spike_hits": stats["spike_hits"], "leaps": int(stats["leaps"]) / 2, "defeated": stats["defeated"]}
	_clean()
	level.free()
	for child in get_children():
		if child is Projectile or child is SoulFragment or child is SoulPickup:
			child.free()
	await _physics(2)
	return result


## The duel bot of the real arena: refuge from the spikes, climb under a boss on a platform, otherwise the old bot.
func _boss2_step(player: Player, boss: BossBase, hazard: FloorHazard, level: LevelBase) -> void:
	var on_floor_level: bool = player.global_position.y > 540.0
	var spikes_near: bool = hazard.state == FloorHazard.State.WARNING or hazard.state == FloorHazard.State.ACTIVE
	if spikes_near and on_floor_level and player.is_on_floor() and player.state != Player.State.FOCUS:
		# Walk under the nearest low platform and jump up onto it.
		var best_x: float = 0.0
		var best_distance: float = INF
		for node in level.find_children("ArenaLow*", "StaticBody2D", true, false):
			var distance: float = absf((node as Node2D).global_position.x - player.global_position.x)
			if distance < best_distance:
				best_distance = distance
				best_x = (node as Node2D).global_position.x
		var toward: float = best_x - player.global_position.x
		Input.action_release(&"move_left" if toward > 0.0 else &"move_right")
		if absf(toward) > 40.0:
			Input.action_press(&"move_right" if toward > 0.0 else &"move_left")
		else:
			Input.action_release(&"move_left")
			Input.action_release(&"move_right")
			_hold(&"jump", 16)
		return
	if spikes_near and not on_floor_level:
		# Safe on a platform: wait there (swing if the boss is close), do not fall back onto the spikes.
		Input.action_release(&"move_left")
		Input.action_release(&"move_right")
		if boss.global_position.distance_to(player.global_position) < 130.0:
			_hold(&"attack", 2)
		return
	var boss_above: bool = boss.global_position.y < player.global_position.y - 70.0
	if boss_above and player.state != Player.State.FOCUS:
		var dx: float = boss.global_position.x - player.global_position.x
		Input.action_release(&"move_left" if dx > 0.0 else &"move_right")
		if absf(dx) > 50.0:
			Input.action_press(&"move_right" if dx > 0.0 else &"move_left")
		else:
			Input.action_release(&"move_left")
			Input.action_release(&"move_right")
			if player.is_on_floor():
				_hold(&"jump", 16)
			_hold(&"attack", 2)
		return
	_fight_step(player, boss)


# ---------------------------------------------------------------------------------------------
# 4. Naive run-throughs of the real levels
# ---------------------------------------------------------------------------------------------

func _runs() -> void:
	for level_number in [1, 2, 3]:
		for profile in PROFILES:
			for hearts in [8, 11]:
				if (not run_profile.is_empty() and profile != run_profile) or (run_hearts != 0 and hearts != run_hearts):
					continue
				var result: Dictionary = await _run_level(level_number, profile, hearts, 4242 + level_number)
				print("ROW|RUN|level %d|%s|hearts %d|reached boss door %s at %s s|boss killed %s at %s s|deaths %d|hp lost %d|heals %d|soul gathered %d|soul wasted %d|progress %d%%|hp at door %s|%s" % [
					level_number, profile, hearts, str(result["door"]), str(result["door_time"]), str(result["boss"]), str(result["boss_time"]),
					result["deaths"], result["hp_lost"], result["heals"], result["gathered"], result["wasted"], result["progress"], str(result["hp_at_door"]), result["note"]])


func _run_level(number: int, profile: String, hearts: int, seed_value: int) -> Dictionary:
	_clean()
	rng.seed = seed_value
	GameState.adaptive_profile = profile
	GameState.souls_released = hearts - 8
	var level := (load(LEVEL_PATHS[number]) as PackedScene).instantiate() as LevelBase
	add_child(level)
	await _physics(5)
	level.game_over_controller.show_game_over = false
	var player: Player = level.player
	player.set_auto_respawn(true)
	var stats := {"deaths": 0, "hp_lost": 0, "heals": 0, "door": false, "door_time": -1.0, "boss": false, "boss_time": -1.0, "hp_at_door": -1}
	player.health.damaged.connect(func(info: DamageInfo) -> void: stats["hp_lost"] = int(stats["hp_lost"]) + info.amount)
	player.died.connect(func() -> void: stats["deaths"] = int(stats["deaths"]) + 1)
	var frame_ref: Array[int] = [0]
	level.encounter.encounter_started.connect(func() -> void:
		stats["door"] = true
		stats["door_time"] = snappedf(float(frame_ref[0]) / 60.0, 0.1)
		stats["hp_at_door"] = player.health.current_health)
	level.boss.defeated.connect(func(_b: BossBase) -> void:
		stats["boss"] = true
		stats["boss_time"] = snappedf(float(frame_ref[0]) / 60.0, 0.1))
	player.focus_completed.connect(func(healed: int) -> void: stats["heals"] = int(stats["heals"]) + (1 if healed > 0 else 0))
	var length: float = float(level.camera_limits.size.x)
	var best_x: float = player.global_position.x
	var last_progress_frame: int = 0
	var note: String = "ok"
	var max_frames: int = int(RUN_TIMEOUT * 60.0)
	var enemies: Array[Node] = []
	while frame_ref[0] < max_frames and not bool(stats["boss"]):
		await get_tree().physics_frame
		frame_ref[0] += 1
		_tick_held()
		if frame_ref[0] % 20 == 1:
			enemies = level.find_children("*", "EnemyBase", true, false)
		if player.is_dead or get_tree().paused:
			continue
		if bool(stats["door"]) and level.boss.state != BossBase.State.DEAD:
			_fight_step(player, level.boss)
		else:
			_walk_step(player, enemies)
		if player.global_position.x > best_x + 8.0:
			best_x = player.global_position.x
			last_progress_frame = frame_ref[0]
		if frame_ref[0] - last_progress_frame > STUCK_FRAMES and not bool(stats["door"]):
			note = "bot stuck at x=%d" % int(best_x)
			break
	if not bool(stats["boss"]) and note == "ok":
		note = "timeout"
	var gathered: int = player.soul.gained_total
	var wasted: int = player.soul.wasted_total
	var progress: int = int(clampf(best_x / maxf(length, 1.0), 0.0, 1.0) * 100.0)
	_clean()
	level.free()
	for child in get_children():
		if child is Projectile or child is SoulFragment or child is SoulPickup:
			child.free()
	await _physics(2)
	return {"door": stats["door"], "door_time": stats["door_time"], "boss": stats["boss"], "boss_time": stats["boss_time"],
		"deaths": stats["deaths"], "hp_lost": stats["hp_lost"], "heals": stats["heals"], "gathered": gathered, "wasted": wasted, "progress": progress, "hp_at_door": stats["hp_at_door"], "note": note}


## True if a living enemy is within `distance` pixels.
func _enemy_near(player: Player, enemies: Array[Node], distance: float) -> bool:
	for node in enemies:
		if not is_instance_valid(node):
			continue
		var enemy := node as EnemyBase
		if enemy != null and enemy.state != EnemyBase.State.DEAD and enemy.global_position.distance_to(player.global_position) < distance:
			return true
	return false


## One frame of the walking bot: always right, jump at walls and gaps, swing at close enemies.
func _walk_step(player: Player, enemies: Array[Node]) -> void:
	if player.state == Player.State.FOCUS:
		Input.action_press(&"heal")
		Input.action_release(&"move_right")
		return
	Input.action_release(&"heal")
	if _wants_heal(player) and not _enemy_near(player, enemies, 260.0):
		_hold(&"heal", 3)
		Input.action_release(&"move_right")
		return
	Input.action_release(&"move_left")
	Input.action_press(&"move_right")
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var world_mask: int = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	var ahead := PhysicsRayQueryParameters2D.create(player.global_position, player.global_position + Vector2(34.0, 0.0), world_mask)
	var gap := PhysicsRayQueryParameters2D.create(player.global_position + Vector2(14.0, 0.0), player.global_position + Vector2(14.0, 90.0), world_mask)
	if player.is_on_floor() and not space.intersect_ray(gap).is_empty() and not space.intersect_ray(ahead).is_empty():
		_hold(&"jump", 22)
	elif player.is_on_floor() and space.intersect_ray(gap).is_empty():
		# A gap: jump at the very edge and dash in the air (the wide gaps need both).
		_hold(&"jump", 26)
		cross_frames = 0
		dash_in = -1
	if cross_frames >= 0:
		cross_frames += 1
		if cross_frames == 36 and player.has_double_jump():
			_hold(&"jump", 20)
		elif cross_frames == 69 or (cross_frames == 14 and not player.has_double_jump()):
			_hold(&"dash", 2)
		if cross_frames > 120:
			cross_frames = -1
	if dash_in >= 0:
		dash_in -= 1
	for node in enemies:
		if not is_instance_valid(node):
			continue
		var enemy := node as EnemyBase
		if enemy == null or enemy.state == EnemyBase.State.DEAD:
			continue
		var dx: float = enemy.global_position.x - player.global_position.x
		if dx > -20.0 and dx < 90.0 and absf(enemy.global_position.y - player.global_position.y) < 60.0:
			_hold(&"attack", 2)
			break
		if dx > 90.0 and dx < 260.0 and absf(enemy.global_position.y - player.global_position.y) < 60.0 and rng.randf() < 0.03:
			_hold(&"wave", 2)
			break
	if rng.randf() < 0.004:
		_hold(&"dash", 2)
