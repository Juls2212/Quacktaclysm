extends Node
## Headless smoke test for Phase 6: boss system. Development only.
## Run: <godot> --headless --path game res://frontend/scenes/test/boss_phase6_smoke_test.tscn

const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const BOSS_BASE_SCENE: PackedScene = preload("res://backend/bosses/boss_base.tscn")
const PLACEHOLDER_SCENE: PackedScene = preload("res://backend/bosses/placeholder_boss.tscn")
const ENCOUNTER_SCENE: PackedScene = preload("res://backend/bosses/boss_encounter.tscn")
const BAR_SCENE: PackedScene = preload("res://frontend/ui/boss_health_bar.tscn")
const PLACEHOLDER_STATS: BossStats = preload("res://backend/bosses/stats/placeholder_boss_stats.tres")
const PROJECTILE_STATS: ProjectileStats = preload("res://backend/combat/stats/enemy_projectile_stats.tres")
const FLOOR_Y: float = 300.0
const BOSS_Y: float = FLOOR_Y - 44.0
const PLAYER_START: Vector2 = Vector2(-2000.0, FLOOR_Y - 30.0)
const WALL_LEFT: float = 1000.0
const SEED: int = 12345

var failures: int = 0
var player: Player
var base_player_stats: PlayerStats
var spawned_projectiles: Array[Projectile] = []


func _ready() -> void:
	# Never touch the real save file.
	SaveSystem.set_save_path("user://test_save_phase6.json")
	_add_static(Vector2(0.0, FLOOR_Y + 20.0), Vector2(6000.0, 40.0))
	_add_static(Vector2(WALL_LEFT + 20.0, FLOOR_Y - 50.0), Vector2(40.0, 100.0))
	child_entered_tree.connect(func(node: Node) -> void:
		if node is Projectile:
			spawned_projectiles.append(node as Projectile))
	player = PLAYER_SCENE.instantiate() as Player
	player.position = PLAYER_START
	add_child(player)
	base_player_stats = player.stats
	_run.call_deferred()


func _add_static(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	body.collision_mask = 0
	body.position = pos
	body.add_child(_rect_shape(size))
	add_child(body)


func _rect_shape(size: Vector2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	return shape


func _check(check_name: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("PASS: %s %s" % [check_name, detail])
	else:
		failures += 1
		print("FAIL: %s %s" % [check_name, detail])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _wait_until(condition: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _reset_player(pos: Vector2 = PLAYER_START) -> void:
	player.stats = base_player_stats
	player.health.invulnerability_time = 0.0
	player.revive()
	player.global_position = pos
	player.velocity = Vector2.ZERO
	player.facing_direction = 1
	await _frames(40)


# --- Builders ---

func _swipe(id: StringName, overrides: Dictionary = {}) -> SwipePattern:
	var pattern := SwipePattern.new()
	pattern.pattern_id = id
	pattern.telegraph_time = 0.1
	pattern.active_time = 0.1
	pattern.recovery_time = 0.1
	_configure(pattern, overrides)
	return pattern


func _charge(id: StringName, overrides: Dictionary = {}) -> ChargePattern:
	var pattern := ChargePattern.new()
	pattern.pattern_id = id
	pattern.telegraph_time = 0.1
	pattern.recovery_time = 0.1
	pattern.charge_duration = 0.2
	_configure(pattern, overrides)
	return pattern


func _volley(id: StringName, overrides: Dictionary = {}) -> ProjectileVolleyPattern:
	var pattern := ProjectileVolleyPattern.new()
	pattern.pattern_id = id
	pattern.telegraph_time = 0.1
	pattern.recovery_time = 0.1
	_configure(pattern, overrides)
	return pattern


func _configure(object: Object, overrides: Dictionary) -> void:
	for key in overrides:
		object.set(key, overrides[key])


## A boss built from boss_base.tscn with only data (stats and pattern nodes).
func _make_boss(patterns: Array, stat_overrides: Dictionary, x: float) -> BossBase:
	var boss := BOSS_BASE_SCENE.instantiate() as BossBase
	var stats := BossStats.new()
	stats.pattern_gap_time = 0.3
	stats.death_fade_time = 0.3
	stats.phase_transition_time = 0.5
	# Phase 13c: these tests measure the patterns, not body contact.
	stats.contact_damage = 0
	_configure(stats, stat_overrides)
	boss.stats = stats
	boss.rng_seed = SEED
	var hitbox: Hitbox = boss.get_node("AttackPivot/Hitbox")
	for pattern in patterns:
		if "hitbox" in pattern:
			pattern.hitbox = hitbox
		boss.get_node("Patterns").add_child(pattern)
	boss.position = Vector2(x, BOSS_Y)
	add_child(boss)
	return boss


func _track(boss: BossBase) -> Dictionary:
	var log: Dictionary = {"started": [], "finished": [], "cancelled": [], "phases": [], "defeated": 0, "activated": 0, "resets": 0}
	boss.pattern_started.connect(func(id: StringName) -> void:
		log["started"].append({"id": id, "frame": Engine.get_physics_frames(), "phase": boss.current_phase}))
	boss.pattern_finished.connect(func(id: StringName) -> void:
		log["finished"].append({"id": id, "frame": Engine.get_physics_frames()}))
	boss.pattern_cancelled.connect(func(id: StringName) -> void: log["cancelled"].append(id))
	boss.phase_changed.connect(func(phase: int) -> void: log["phases"].append(phase))
	boss.defeated.connect(func(_b: BossBase) -> void: log["defeated"] += 1)
	boss.activated.connect(func() -> void: log["activated"] += 1)
	boss.encounter_reset.connect(func() -> void: log["resets"] += 1)
	return log


func _remove(node: Node) -> void:
	if is_instance_valid(node):
		if node is BossBase:
			for child in (node as BossBase).attack_pivot.get_children():
				if child is Hitbox:
					(child as Hitbox).deactivate()
		node.queue_free()
	await _frames(2)


func _clear_projectiles() -> void:
	for projectile in spawned_projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	await _frames(2)
	spawned_projectiles.clear()


func _hit_boss(boss: BossBase, amount: int = 1) -> bool:
	return boss.hurtbox.receive_hit(DamageInfo.create(amount, Vector2.ZERO, player, CombatLayers.Team.PLAYER))


func _all_hitboxes_off(boss: BossBase) -> bool:
	for child in boss.attack_pivot.get_children():
		if child is Hitbox and (child as Hitbox).is_active:
			return false
	return true


## Records (phase, hitbox active) for every frame a pattern runs.
func _record_pattern(boss: BossBase, hitbox: Hitbox, max_frames: int) -> Array[Dictionary]:
	var frames: Array[Dictionary] = []
	var seen: bool = false
	for i in max_frames:
		await get_tree().physics_frame
		if boss.current_pattern != null:
			seen = true
			frames.append({"phase": boss.current_pattern.phase_name, "active": hitbox.is_active})
		elif seen:
			break
	return frames


func _hitbox_follows_phase(frames: Array[Dictionary]) -> bool:
	for frame in frames:
		if frame["active"] != (frame["phase"] == BossPattern.PHASE_ACTIVE):
			return false
	return not frames.is_empty()


func _run() -> void:
	await _test_stats_and_activation()
	await _test_encounter_trigger()
	await _test_pattern_selection()
	await _test_swipe()
	await _test_charge()
	await _test_volley()
	await _test_armor()
	await _test_phases()
	await _test_death()
	await _test_reset()
	await _test_health_bar()
	await _test_reuse()
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	SaveSystem.purge()
	SaveSystem.set_save_path(SaveSystem.DEFAULT_PATH)
	get_tree().quit(1 if failures > 0 else 0)


func _test_stats_and_activation() -> void:
	await _reset_player()
	var boss := PLACEHOLDER_SCENE.instantiate() as BossBase
	boss.position = Vector2(PLAYER_START.x + 700.0, BOSS_Y)
	add_child(boss)
	var start: Vector2 = boss.global_position
	var log: Dictionary = _track(boss)
	await _frames(60)
	_check("boss: stats applied", boss.health.max_health == PLACEHOLDER_STATS.max_health and boss.stats.display_name == "Placeholder Boss",
		"hp=%d" % boss.health.max_health)
	_check("boss: placeholder has its three patterns", boss.patterns.size() == 3 and boss.patterns[2].min_phase == 2)
	_check("boss: does nothing while INACTIVE", boss.state == BossBase.State.INACTIVE and log["started"].is_empty()
		and boss.global_position.is_equal_approx(start))
	boss.activate(player)
	boss.activate(player)
	_check("boss: activate() starts it (once)", boss.state == BossBase.State.IDLE and log["activated"] == 1)
	await _frames(20)
	await _remove(boss)


func _test_encounter_trigger() -> void:
	await _reset_player()
	var boss := _make_boss([_swipe(&"a")], {}, PLAYER_START.x + 700.0)
	var log: Dictionary = _track(boss)
	var encounter := ENCOUNTER_SCENE.instantiate() as BossEncounter
	encounter.boss = boss
	encounter.position = PLAYER_START
	var started: Array[int] = [0]
	add_child(encounter)
	encounter.encounter_started.connect(func() -> void: started[0] += 1)
	await _frames(10)
	_check("encounter: trigger activates the boss", log["activated"] == 1 and boss.state != BossBase.State.INACTIVE and started[0] == 1)
	player.global_position = PLAYER_START + Vector2(0.0, -500.0)
	await _frames(5)
	player.global_position = PLAYER_START
	await _frames(10)
	_check("encounter: activates only once", log["activated"] == 1 and started[0] == 1)
	encounter.queue_free()
	await _remove(boss)


func _test_pattern_selection() -> void:
	await _reset_player()
	var boss := _make_boss([_swipe(&"a"), _swipe(&"b"), _swipe(&"c", {"min_phase": 2})], {}, PLAYER_START.x + 600.0)
	var log: Dictionary = _track(boss)
	boss.activate(player)
	await _wait_until(func() -> bool: return log["finished"].size() >= 8, 1200)
	var ids: Array = []
	for entry in log["started"]:
		ids.append(entry["id"])
	var repeated: bool = false
	for i in range(1, ids.size()):
		if ids[i] == ids[i - 1]:
			repeated = true
	_check("select: phase-2 pattern is never chosen in phase 1", ids.size() >= 6 and not ids.has(&"c"), "ids=%s" % [ids])
	_check("select: no immediate repeat when alternatives exist", not repeated, "ids=%s" % [ids])
	var gap_frames: int = int(boss.stats.pattern_gap_time * 60.0)
	var gaps_ok: bool = true
	for i in range(1, log["started"].size()):
		if log["finished"].size() >= i and log["started"][i]["frame"] - log["finished"][i - 1]["frame"] < gap_frames - 2:
			gaps_ok = false
	_check("select: pattern gap time respected", gaps_ok, "gap=%d frames" % gap_frames)
	await _remove(boss)

	await _reset_player()
	var solo := _make_boss([_swipe(&"a", {"cooldown": 1.0})], {"pattern_gap_time": 0.1}, PLAYER_START.x + 600.0)
	var solo_log: Dictionary = _track(solo)
	solo.activate(player)
	await _wait_until(func() -> bool: return solo_log["finished"].size() >= 3, 900)
	var cooldown_frames: int = 60
	var cooldown_ok: bool = solo_log["started"].size() >= 3
	for i in range(1, solo_log["started"].size()):
		if solo_log["started"][i]["frame"] - solo_log["finished"][i - 1]["frame"] < cooldown_frames - 2:
			cooldown_ok = false
	_check("select: pattern cooldown respected", cooldown_ok)
	var all_a: bool = true
	for entry in solo_log["started"]:
		if entry["id"] != &"a":
			all_a = false
	_check("select: a single valid pattern may repeat", all_a and solo_log["started"].size() >= 3)
	await _remove(solo)


func _test_swipe() -> void:
	await _reset_player()
	var boss := _make_boss([_swipe(&"swipe", {"telegraph_time": 0.3, "active_time": 0.2, "recovery_time": 0.3})], {}, PLAYER_START.x + 85.0)
	var hitbox: Hitbox = boss.get_node("AttackPivot/Hitbox")
	var max_hp: int = player.health.max_health
	boss.activate(player)
	await _wait_until(func() -> bool: return boss.current_pattern != null, 120)
	var frames: Array[Dictionary] = await _record_pattern(boss, hitbox, 120)
	var active_frames: int = 0
	for frame in frames:
		if frame["active"]:
			active_frames += 1
	_check("swipe: hitbox inactive in telegraph and recovery, active only in its window", _hitbox_follows_phase(frames) and active_frames > 0,
		"frames=%d active=%d" % [frames.size(), active_frames])
	_check("swipe: exactly one hit on the player", player.health.current_health == max_hp - hitbox.damage, "hp=%d" % player.health.current_health)
	_check("swipe: boss faces the target", boss.facing_direction == -1)
	await _remove(boss)


func _test_charge() -> void:
	await _reset_player()
	var spec: Dictionary = {"telegraph_time": 0.3, "charge_speed": 400.0, "charge_duration": 0.5, "recovery_time": 0.3}
	var boss := _make_boss([_charge(&"charge", spec)], {}, PLAYER_START.x + 150.0)
	var hitbox: Hitbox = boss.get_node("AttackPivot/Hitbox")
	var start_x: float = boss.global_position.x
	var max_hp: int = player.health.max_health
	boss.activate(player)
	await _wait_until(func() -> bool: return boss.current_pattern != null, 120)
	var frames: Array[Dictionary] = await _record_pattern(boss, hitbox, 180)
	_check("charge: hitbox inactive in telegraph and recovery, active during the charge", _hitbox_follows_phase(frames))
	_check("charge: exactly one hit on the player", player.health.current_health == max_hp - hitbox.damage, "hp=%d" % player.health.current_health)
	_check("charge: moves toward the target", start_x - boss.global_position.x > 100.0, "moved=%.1f" % (start_x - boss.global_position.x))
	await _remove(boss)

	await _reset_player(Vector2(900.0, FLOOR_Y - 30.0))
	var wall_boss := _make_boss([_charge(&"charge", {"telegraph_time": 0.2, "charge_speed": 600.0, "charge_duration": 0.6})], {}, WALL_LEFT - 250.0)
	wall_boss.activate(player)
	var max_x: float = wall_boss.global_position.x
	for i in 150:
		await get_tree().physics_frame
		max_x = maxf(max_x, wall_boss.global_position.x)
	_check("charge: stops at a wall", max_x <= WALL_LEFT - 28.0 + 0.5 and max_x > WALL_LEFT - 80.0, "max_x=%.1f" % max_x)
	await _remove(wall_boss)


func _test_volley() -> void:
	await _reset_player()
	await _clear_projectiles()
	var slow: ProjectileStats = PROJECTILE_STATS.duplicate() as ProjectileStats
	slow.speed = 100.0
	slow.lifetime = 5.0
	var spec: Dictionary = {"projectile_count": 5, "spread_angle_degrees": 40.0, "shot_interval": 0.05,
		"aim_at_target": false, "projectile_stats": slow, "telegraph_time": 0.2}
	var boss := _make_boss([_volley(&"volley", spec)], {}, PLAYER_START.x + 300.0)
	var log: Dictionary = _track(boss)
	boss.activate(player)
	var snapshots: Dictionary = {}
	var first_seen: Array[int] = []
	for i in 150:
		await get_tree().physics_frame
		for projectile in spawned_projectiles:
			if is_instance_valid(projectile) and not snapshots.has(projectile):
				snapshots[projectile] = projectile.velocity
				first_seen.append(Engine.get_physics_frames())
		if log["finished"].size() >= 1:
			break
	var angles: Array[float] = []
	var speeds_ok: bool = true
	for velocity in snapshots.values():
		angles.append(snappedf(rad_to_deg((velocity as Vector2).angle_to(Vector2.LEFT)), 0.1))
		if not is_equal_approx((velocity as Vector2).length(), slow.speed):
			speeds_ok = false
	angles.sort()
	var expected: Array[float] = [-20.0, -10.0, 0.0, 10.0, 20.0]
	var angles_ok: bool = angles.size() == expected.size()
	if angles_ok:
		for i in expected.size():
			if absf(angles[i] - expected[i]) > 0.6:
				angles_ok = false
	_check("volley: fires the configured number of projectiles with the configured spread", angles_ok and speeds_ok, "angles=%s" % [angles])
	var span: int = first_seen[first_seen.size() - 1] - first_seen[0] if first_seen.size() > 1 else -1
	_check("volley: shots are spaced by shot_interval", absi(span - 12) <= 3, "span=%d frames" % span)

	await _reset_player()
	await _clear_projectiles()
	boss.hurtbox.set_enabled(true)
	var survivor := _make_boss([_volley(&"volley", spec)], {}, PLAYER_START.x + 300.0)
	var survivor_log: Dictionary = _track(survivor)
	survivor.activate(player)
	await _wait_until(func() -> bool: return spawned_projectiles.size() >= 2, 120)
	survivor.health.kill()
	await _frames(3)
	var alive: int = 0
	for projectile in spawned_projectiles:
		if is_instance_valid(projectile):
			alive += 1
	_check("volley: projectiles survive the boss's death", survivor_log["defeated"] == 1 and alive == spawned_projectiles.size() and alive >= 2,
		"alive=%d" % alive)
	await _clear_projectiles()
	await _remove(boss)


func _test_armor() -> void:
	await _reset_player()
	var boss := _make_boss([_swipe(&"slow", {"telegraph_time": 0.8, "active_time": 0.2, "recovery_time": 0.2})], {"max_health": 20}, PLAYER_START.x + 500.0)
	var log: Dictionary = _track(boss)
	boss.activate(player)
	await _wait_until(func() -> bool: return boss.current_pattern != null, 120)
	var pattern: BossPattern = boss.current_pattern
	await _frames(5)
	var hp_before: int = boss.health.current_health
	_hit_boss(boss, 1)
	await _frames(3)
	_check("armor: sword damage lowers health", boss.health.current_health == hp_before - 1)
	_check("armor: damage does not interrupt the pattern",
		boss.state == BossBase.State.PATTERN and boss.current_pattern == pattern and not pattern.is_finished() and log["cancelled"].is_empty())
	await _wait_until(func() -> bool: return log["finished"].size() >= 1, 120)
	_check("armor: the pattern still completes", log["finished"].size() == 1)
	await _remove(boss)


func _test_phases() -> void:
	await _reset_player()
	var stats: Dictionary = {"max_health": 20, "phase_2_health_ratio": 0.5, "phase_transition_time": 0.5,
		"phase_2_speed_multiplier": 2.0, "phase_2_pattern_gap_multiplier": 0.5, "pattern_gap_time": 0.4}
	var boss := _make_boss([_swipe(&"a", {"telegraph_time": 0.2, "active_time": 0.1, "recovery_time": 0.2}),
		_swipe(&"c", {"min_phase": 2, "telegraph_time": 0.2, "active_time": 0.1, "recovery_time": 0.2})], stats, PLAYER_START.x + 600.0)
	var log: Dictionary = _track(boss)
	boss.activate(player)
	await _wait_until(func() -> bool: return log["finished"].size() >= 2, 400)
	var phase_1_length: int = log["finished"][0]["frame"] - log["started"][0]["frame"]
	await _wait_until(func() -> bool: return boss.state == BossBase.State.PATTERN, 200)
	_hit_boss(boss, 15)
	await _frames(2)
	_check("phase: transition starts at the threshold, cancelling the pattern",
		boss.state == BossBase.State.PHASE_TRANSITION and boss.current_pattern == null and log["cancelled"].size() == 1 and _all_hitboxes_off(boss),
		"state=%s hp=%d" % [BossBase.State.keys()[boss.state], boss.health.current_health])
	var hp_in_transition: int = boss.health.current_health
	var applied: bool = _hit_boss(boss, 1)
	_check("phase: damage during the transition is ignored", not applied and boss.health.current_health == hp_in_transition)
	await _frames(int(ceil(boss.stats.phase_transition_time * 60.0)) + 2)
	_check("phase: phase 2 starts once with the speed multiplier",
		boss.current_phase == 2 and log["phases"] == [2] and is_equal_approx(boss.speed_multiplier, 2.0) and boss.state != BossBase.State.PHASE_TRANSITION)
	_hit_boss(boss, 1)
	await _frames(5)
	_check("phase: the transition does not repeat", log["phases"].size() == 1)
	var phase_2_start: int = log["started"].size()
	await _wait_until(func() -> bool: return log["finished"].size() >= phase_2_start + 3, 600)
	var phase_2_ids: Array = []
	var phase_2_length: int = -1
	for i in range(phase_2_start, log["started"].size()):
		phase_2_ids.append(log["started"][i]["id"])
	for i in range(phase_2_start, log["started"].size()):
		if log["started"][i]["id"] != &"a":
			continue
		# The cancelled pattern has no "finished" entry, so match by frame, not by index.
		for finished in log["finished"]:
			if finished["frame"] > log["started"][i]["frame"]:
				phase_2_length = finished["frame"] - log["started"][i]["frame"]
				break
		break
	_check("phase: phase-2-only pattern becomes available", phase_2_ids.has(&"c"), "ids=%s" % [phase_2_ids])
	_check("phase: speed multiplier shortens patterns", phase_2_length > 0 and phase_2_length < phase_1_length * 0.7,
		"phase1=%d phase2=%d" % [phase_1_length, phase_2_length])
	await _remove(boss)

	await _reset_player()
	var lethal := _make_boss([_swipe(&"a")], stats, PLAYER_START.x + 600.0)
	var lethal_log: Dictionary = _track(lethal)
	lethal.activate(player)
	await _frames(5)
	_hit_boss(lethal, 20)
	await _frames(2)
	_check("phase: a lethal hit skips the transition", lethal.state == BossBase.State.DEAD and lethal_log["phases"].is_empty()
		and lethal.current_phase == 1 and lethal_log["defeated"] == 1)
	await _remove(lethal)


func _test_death() -> void:
	for moment in ["telegraph", "active"]:
		await _reset_player()
		var boss := _make_boss([_swipe(&"slow", {"telegraph_time": 0.6, "active_time": 0.6, "recovery_time": 0.3})], {}, PLAYER_START.x + 85.0)
		var log: Dictionary = _track(boss)
		var hitbox: Hitbox = boss.get_node("AttackPivot/Hitbox")
		var max_hp: int = player.health.max_health
		boss.activate(player)
		var ready_to_kill: bool
		if moment == "telegraph":
			ready_to_kill = await _wait_until(func() -> bool: return boss.current_pattern != null and boss.current_pattern.phase_name == &"telegraph", 120)
		else:
			ready_to_kill = await _wait_until(func() -> bool: return hitbox.is_active, 180)
		var hp_at_kill: int = player.health.current_health
		boss.health.kill()
		await _frames(2)
		_check("death (%s): defeated once, pattern cancelled, DEAD" % moment,
			ready_to_kill and log["defeated"] == 1 and log["cancelled"].size() == 1 and boss.state == BossBase.State.DEAD and boss.current_pattern == null)
		_check("death (%s): no active hitbox and hurtbox disabled" % moment, _all_hitboxes_off(boss) and not boss.hurtbox.enabled)
		await _frames(3)
		_check("death (%s): hitbox not monitoring" % moment, not hitbox.monitoring)
		var starts_at_death: int = log["started"].size()
		await _frames(int(ceil(boss.stats.death_fade_time * 60.0)) + 10)
		_check("death (%s): boss freed after the fade" % moment, not is_instance_valid(boss))
		# Health may only go up afterwards: the defeat drops health orbs that heal the player.
		_check("death (%s): dead boss never attacks again" % moment, log["started"].size() == starts_at_death
			and log["defeated"] == 1 and player.health.current_health >= hp_at_kill and hp_at_kill <= max_hp)


func _test_reset() -> void:
	await _reset_player()
	var stats: Dictionary = {"max_health": 20, "phase_2_health_ratio": 0.5, "phase_transition_time": 0.3, "phase_2_speed_multiplier": 2.0}
	var boss := _make_boss([_swipe(&"a")], stats, PLAYER_START.x + 600.0)
	var spawn: Vector2 = boss.global_position
	var log: Dictionary = _track(boss)
	var encounter := ENCOUNTER_SCENE.instantiate() as BossEncounter
	encounter.boss = boss
	encounter.position = PLAYER_START
	add_child(encounter)
	await _wait_until(func() -> bool: return log["activated"] == 1, 30)
	_hit_boss(boss, 15)
	await _frames(30)
	boss.global_position += Vector2(80.0, 0.0)
	_check("reset: boss is in phase 2 before the reset", boss.current_phase == 2)
	player.health.kill()
	await _frames(3)
	_check("reset: player death resets the encounter",
		boss.state == BossBase.State.INACTIVE and boss.health.current_health == boss.health.max_health and boss.current_phase == 1
		and is_equal_approx(boss.speed_multiplier, 1.0) and _all_hitboxes_off(boss) and boss.global_position.is_equal_approx(spawn)
		and log["resets"] == 1, "state=%s hp=%d" % [BossBase.State.keys()[boss.state], boss.health.current_health])
	await _wait_until(func() -> bool: return log["activated"] >= 2, 240)
	_check("reset: the encounter can be triggered again after respawn", log["activated"] == 2 and boss.state != BossBase.State.INACTIVE,
		"activated=%d" % log["activated"])
	encounter.queue_free()
	await _remove(boss)

	# A dead player is never attacked.
	await _reset_player()
	var copy: PlayerStats = base_player_stats.duplicate() as PlayerStats
	copy.auto_respawn = false
	player.stats = copy
	player.health.kill()
	await _frames(3)
	var bystander := _make_boss([_swipe(&"a")], {}, PLAYER_START.x + 85.0)
	var bystander_log: Dictionary = _track(bystander)
	bystander.activate(player)
	await _frames(150)
	_check("reset: the boss never attacks a dead player", bystander_log["started"].is_empty() and bystander.state == BossBase.State.IDLE)
	await _remove(bystander)

	# Player dying mid-pattern stops it.
	await _reset_player()
	player.stats = copy
	var mid := _make_boss([_swipe(&"slow", {"telegraph_time": 0.6})], {}, PLAYER_START.x + 300.0)
	var mid_log: Dictionary = _track(mid)
	mid.activate(player)
	await _wait_until(func() -> bool: return mid.current_pattern != null, 120)
	player.health.kill()
	await _frames(3)
	_check("reset: player death cancels the running pattern", mid.current_pattern == null and mid.state == BossBase.State.IDLE
		and mid_log["cancelled"].size() == 1 and _all_hitboxes_off(mid))
	await _remove(mid)
	await _reset_player()


func _test_health_bar() -> void:
	await _reset_player()
	var boss := _make_boss([_swipe(&"a")], {"max_health": 20, "display_name": "Test Boss", "phase_2_health_ratio": 0.4}, PLAYER_START.x + 600.0)
	var bar := BAR_SCENE.instantiate() as BossHealthBar
	add_child(bar)
	bar.bind(boss)
	_check("bar: hidden before the encounter", not bar.visible)
	boss.activate(player)
	_check("bar: shown on activation with the boss name", bar.visible and bar.displayed_name == "Test Boss" and bar.name_label.text == "Test Boss")
	_check("bar: phase 2 marker at the threshold", is_equal_approx(bar.marker_ratio, 0.4) and is_equal_approx(bar.marker.anchor_left, 0.4))
	_hit_boss(boss, 5)
	_check("bar: updates with damage", is_equal_approx(bar.displayed_ratio, 0.75) and is_equal_approx(bar.fill.anchor_right, 0.75),
		"ratio=%.2f" % bar.displayed_ratio)
	boss.reset_encounter()
	_check("bar: hidden on reset and refilled", not bar.visible and is_equal_approx(bar.displayed_ratio, 1.0))
	boss.activate(player)
	_check("bar: shown again on re-activation", bar.visible)
	boss.health.kill()
	_check("bar: hidden on defeat", not bar.visible)
	bar.queue_free()
	await _remove(boss)


func _test_reuse() -> void:
	await _reset_player()
	await _clear_projectiles()
	var volley := _volley(&"only_volley", {"projectile_count": 3, "shot_interval": 0.05})
	var other := _make_boss([volley], {"max_health": 7, "boss_id": &"other_boss", "display_name": "Other"}, PLAYER_START.x + 400.0)
	other.activate(player)
	await _wait_until(func() -> bool: return spawned_projectiles.size() >= 3, 180)
	_check("reuse: a second boss works with only different stats and patterns",
		other.health.max_health == 7 and other.stats.boss_id == &"other_boss" and spawned_projectiles.size() >= 3,
		"shots=%d" % spawned_projectiles.size())
	await _remove(other)
	await _clear_projectiles()

	await _reset_player()
	player.health.grant_invulnerability(100.0)
	var placeholder := PLACEHOLDER_SCENE.instantiate() as BossBase
	placeholder.rng_seed = SEED
	placeholder.position = Vector2(PLAYER_START.x + 100.0, BOSS_Y)
	add_child(placeholder)
	var log: Dictionary = _track(placeholder)
	placeholder.activate(player)
	await _frames(400)
	_check("reuse: the placeholder boss runs its patterns", log["started"].size() >= 1, "patterns=%d" % log["started"].size())
	await _remove(placeholder)
	await _clear_projectiles()
	await _reset_player()
