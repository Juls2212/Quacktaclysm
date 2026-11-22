extends Node
## Headless smoke test for Phase 15a (Soul meter and focus healing, which replace the health orbs): soul per
## attack type and target, the 0..99 clamp, the resets, wisp absorption, the heal cost for 0..3 kept, the
## focus (success, cancel on damage or release or dash, full health, not enough soul, airborne, locked, dead,
## movement lock, max health 8..11), no orbs left anywhere, the HUD layout with 11 hearts, the consequence
## line, the ability card (live keys, remap, once per event, pause) and its use after keeping a fragment,
## the tutorial's heal step, the reassignable action and the guards. Development only. Run:
##   <godot> --headless --path game res://frontend/scenes/test/phase15a_smoke_test.tscn
## Uses a redirected save path and a throwaway controls file; the real save and the real controls are never touched.

const TEST_SAVE: String = "user://test_save_phase15a.json"
const TEST_CONTROLS: String = "user://test_controls_phase15a.cfg"
const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://frontend/ui/player_health_hud.tscn")
const BOSS_BAR_SCENE: PackedScene = preload("res://frontend/ui/boss_health_bar.tscn")
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const FLOOR_Y: float = 300.0

var failures: int = 0
var real_save_before: String = ""
var real_controls_before: String = ""
var config: SoulConfig = null
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig


func _ready() -> void:
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
	real_controls_before = _read_file(ControlsConfig.DEFAULT_PATH)
	config = SoulConfig.get_default()
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
	AbilityCard.forget_all()
	for action in [&"heal", &"dash", &"move_right", &"jump", &"attack"]:
		Input.action_release(action)


func _free(node: Variant) -> void:
	if is_instance_valid(node):
		(node as Node).queue_free()


func _run() -> void:
	_clean_state()
	_test_config_and_guards()
	await _test_soul_gain()
	await _test_clamp_and_resets()
	await _test_wisps()
	await _test_focus()
	await _test_no_orbs()
	await _test_hud()
	_test_consequence_line()
	await _test_ability_card()
	await _test_controls()
	_clean_state()
	SaveSystem.purge()
	GameState.autosave_enabled = true
	_check("the real save file was not touched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	_check("the real controls file was not touched", _read_file(ControlsConfig.DEFAULT_PATH) == real_controls_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------------------------------------
# Helpers: a flat arena with a real player
# ---------------------------------------------------------------------------------------------

func _arena() -> Node2D:
	var world := Node2D.new()
	add_child(world)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	floor_body.position = Vector2(400.0, FLOOR_Y + 20.0)
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(3000.0, 40.0)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	return world


func _player_in(world: Node2D) -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(0.0, FLOOR_Y - 26.0)
	world.add_child(player)
	return player


func _grounded_player(world: Node2D) -> Player:
	var player: Player = _player_in(world)
	await _physics(30)
	return player


func _hurt(player: Player, amount: int = 1) -> void:
	player.health.apply_damage(DamageInfo.create(amount, Vector2.ZERO, null, CombatLayers.Team.ENEMY))


# ---------------------------------------------------------------------------------------------
# Config and guards
# ---------------------------------------------------------------------------------------------

func _test_config_and_guards() -> void:
	_check("config: meter max 99 and the soul per hit (11 / 22 / 16 / 8)", config.max_soul == 99 and config.gain_light == 11 and config.gain_heavy == 22
		and config.gain_dash_slash == 16 and config.gain_wave == 8)
	_check("config: wisps give 11 (enemy) and 33 (boss); the focus lasts 0.9 s and heals 1 heart",
		config.wisp_enemy == 11 and config.wisp_boss == 33 and is_equal_approx(config.focus_time, 0.9) and config.heal_hearts == 1)
	var costs: Array[int] = []
	for kept in 4:
		costs.append(config.heal_cost(kept))
	_check("heal cost: 33 + 5 per kept fragment gives 33, 38, 43, 48", costs == [33, 38, 43, 48], str(costs))
	_check("heal cost: never negative or above the meter", config.heal_cost(-5) == 33 and config.heal_cost(500) == 99)
	_check("config: sword kinds map to their amounts", config.gain_for_sword(0) == 11 and config.gain_for_sword(1) == 22 and config.gain_for_sword(2) == 16)
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
	_check("config: the soul meter is runtime only (no soul key in the save dictionary)", not GameState.to_dict().has("soul"))


# ---------------------------------------------------------------------------------------------
# Soul gained per attack type and target
# ---------------------------------------------------------------------------------------------

func _test_soul_gain() -> void:
	_clean_state()
	var world: Node2D = _arena()
	var player: Player = await _grounded_player(world)
	var enemy := (load("res://backend/enemies/melee_enemy.tscn") as PackedScene).instantiate() as EnemyBase
	enemy.position = Vector2(1500.0, FLOOR_Y - 30.0)
	world.add_child(enemy)
	# Sturdy enough to survive every hit of this test.
	enemy.health.max_health = 9999
	enemy.health.reset()
	var boss := (load("res://backend/bosses/boss_two.tscn") as PackedScene).instantiate() as BossBase
	boss.position = Vector2(1700.0, FLOOR_Y - 44.0)
	world.add_child(boss)
	var dummy := (load("res://frontend/scenes/test/training_dummy.tscn") as PackedScene).instantiate()
	dummy.position = Vector2(1300.0, FLOOR_Y - 30.0)
	world.add_child(dummy)
	await _physics(5)
	var soul: SoulComponent = player.soul
	var targets: Dictionary = {"enemy": enemy.hurtbox, "boss": boss.hurtbox, "dummy": dummy.get_node("Hurtbox") as Hurtbox}
	var kinds: Dictionary = {Player.SwordKind.LIGHT: 11, Player.SwordKind.HEAVY: 22, Player.SwordKind.DASH_SLASH: 16}
	for target_name: String in targets:
		for kind: int in kinds:
			soul.reset()
			player.current_sword_kind = kind as Player.SwordKind
			player.attack_hitbox.activate()
			player.attack_hitbox._hit_times.clear()
			player.attack_hitbox._try_hit(targets[target_name])
			player.attack_hitbox.deactivate()
			_check("soul: a %s hit on the %s gives %d" % [Player.SwordKind.keys()[kind], target_name, kinds[kind]], soul.soul == kinds[kind], str(soul.soul))
	# The sword wave: a real wave fired by the caster, landing on an enemy.
	soul.reset()
	var caster: SwordWaveCaster = player.wave_caster
	var wave: Projectile = caster.fire(player, 1)
	_check("soul: the sword wave was fired", wave != null)
	if wave != null:
		var wave_hitbox := wave.get_node("Hitbox") as Hitbox
		wave_hitbox._try_hit(enemy.hurtbox)
		_check("soul: a sword wave hit on an enemy gives 8", soul.soul == 8, str(soul.soul))
		soul.reset()
		wave_hitbox._hit_times.clear()
		wave_hitbox._try_hit(boss.hurtbox)
		_check("soul: a sword wave hit on a boss gives 8", soul.soul == 8, str(soul.soul))
		wave.queue_free()
	# A hit that is not applied (invulnerable target) gives nothing.
	soul.reset()
	enemy.health.grant_invulnerability(5.0)
	player.current_sword_kind = Player.SwordKind.LIGHT
	player.attack_hitbox.activate()
	player.attack_hitbox._hit_times.clear()
	player.attack_hitbox._try_hit(enemy.hurtbox)
	_check("soul: a hit that does not land (invulnerable target) gives nothing", soul.soul == 0)
	world.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# Clamp and resets
# ---------------------------------------------------------------------------------------------

func _test_clamp_and_resets() -> void:
	_clean_state()
	var world: Node2D = _arena()
	var player: Player = await _grounded_player(world)
	var soul: SoulComponent = player.soul
	var gained: Array[int] = []
	soul.soul_gained.connect(func(amount: int) -> void: gained.append(amount))
	var full: Array[bool] = [false]
	soul.soul_full.connect(func() -> void: full[0] = true)
	_check("clamp: a new player starts with 0 soul (the meter resets when a level loads)", soul.soul == 0)
	_check("clamp: adding 500 stops at 99 and the extra is counted as wasted", soul.add_soul(500) == 99 and soul.soul == 99 and soul.wasted_total == 401 and full[0])
	_check("clamp: nothing more fits at the cap", soul.add_soul(11) == 0 and soul.soul == 99 and gained == [99])
	_check("clamp: spending more than there is changes nothing and soul never goes negative", not soul.spend(150) and soul.soul == 99)
	_check("clamp: a negative or zero amount adds nothing", soul.add_soul(-20) == 0 and soul.add_soul(0) == 0 and soul.soul == 99)
	_check("clamp: spending the exact cost leaves the rest", soul.spend(33) and soul.soul == 66)
	soul.reset()
	_check("clamp: reset gives 0", soul.soul == 0)
	soul.add_soul(60)
	player.health.kill()
	await _physics(2)
	player.respawn()
	_check("respawn: dying and respawning at the checkpoint empties the meter", soul.soul == 0)
	soul.add_soul(40)
	player.revive()
	_check("respawn: revive also empties it", soul.soul == 0)
	world.free()
	await _frames(2)
	# A level loads with an empty meter.
	GameState.start_new_game()
	var level := (load("res://frontend/levels/level_1.tscn") as PackedScene).instantiate() as LevelBase
	add_child(level)
	await _frames(3)
	_check("level load: the meter starts at 0", level.player.soul.soul == 0 and level.hud.soul == 0)
	level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# Wisps
# ---------------------------------------------------------------------------------------------

func _test_wisps() -> void:
	_clean_state()
	var world: Node2D = _arena()
	var player: Player = await _grounded_player(world)
	var soul: SoulComponent = player.soul
	var enemy := (load("res://backend/enemies/melee_enemy.tscn") as PackedScene).instantiate() as EnemyBase
	enemy.position = Vector2(600.0, FLOOR_Y - 30.0)
	world.add_child(enemy)
	await _physics(5)
	enemy.health.kill()
	await _physics(3)
	var pickups: Array[Node] = world.find_children("SoulPickup*", "Node2D", true, false)
	_check("wisp: killing an enemy releases a soul wisp (with the wisp effect)", pickups.size() == 1 and pickups[0].find_children("SoulWisp*", "Node2D", true, false).size() == 1)
	_check("wisp: nothing is absorbed at the instant of death", soul.soul == 0)
	await get_tree().create_timer(1.0).timeout
	_check("wisp: the player absorbs +11 from an enemy", soul.soul == 11, str(soul.soul))
	_check("wisp: the wisp is gone afterwards", world.find_children("SoulPickup*", "Node2D", true, false).is_empty())
	# A boss gives 33.
	var boss := (load("res://backend/bosses/boss_two.tscn") as PackedScene).instantiate() as BossBase
	boss.position = Vector2(900.0, FLOOR_Y - 44.0)
	world.add_child(boss)
	await _physics(5)
	soul.reset()
	boss.health.kill()
	await get_tree().create_timer(1.2).timeout
	_check("wisp: the player absorbs +33 when a boss is defeated", soul.soul == 33, str(soul.soul))
	# Phase 2 no longer drops anything.
	_check("wisp: no health orb scene or drop exists any more", not FileAccess.file_exists("res://backend/combat/health_orb.gd"))
	# No player: the wisp just fades. A dead player absorbs nothing.
	soul.reset()
	player.health.kill()
	await _physics(2)
	var enemy_two := (load("res://backend/enemies/melee_enemy.tscn") as PackedScene).instantiate() as EnemyBase
	enemy_two.position = Vector2(700.0, FLOOR_Y - 30.0)
	world.add_child(enemy_two)
	await _physics(5)
	enemy_two.health.kill()
	await get_tree().create_timer(1.1).timeout
	_check("wisp: a dead player absorbs nothing and the wisp fades by itself", soul.soul == 0 and world.find_children("SoulPickup*", "Node2D", true, false).is_empty())
	world.free()
	await _frames(2)
	var empty_world := Node2D.new()
	add_child(empty_world)
	var lonely := (load("res://backend/enemies/melee_enemy.tscn") as PackedScene).instantiate() as EnemyBase
	empty_world.add_child(lonely)
	await _physics(3)
	lonely.health.kill()
	await get_tree().create_timer(1.1).timeout
	_check("wisp: with no player at all it fades without error", empty_world.find_children("SoulPickup*", "Node2D", true, false).is_empty())
	empty_world.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# The focus heal
# ---------------------------------------------------------------------------------------------

func _hold_heal() -> void:
	Input.action_press(&"heal")


func _release_heal() -> void:
	Input.action_release(&"heal")


func _test_focus() -> void:
	_clean_state()
	var world: Node2D = _arena()
	var player: Player = await _grounded_player(world)
	var soul: SoulComponent = player.soul
	var events: Array[String] = []
	player.focus_started.connect(func() -> void: events.append("started"))
	player.focus_cancelled.connect(func() -> void: events.append("cancelled"))
	player.focus_completed.connect(func(healed: int) -> void: events.append("completed:%d" % healed))
	var denied: Array[StringName] = []
	soul.heal_denied.connect(func(reason: StringName) -> void: denied.append(reason))
	# --- success ---
	player.health.max_health = 8
	player.health.reset()
	_hurt(player, 3)
	await _physics(70)
	soul.reset()
	soul.add_soul(60)
	var before: int = player.health.current_health
	_hold_heal()
	await _physics(5)
	_check("focus: holding the heal action starts the focus", player.state == Player.State.FOCUS and events == ["started"], str(events))
	var progress_early: float = player.get_focus_progress()
	await _physics(20)
	_check("focus: the progress grows while it is held (%.2f -> %.2f)" % [progress_early, player.get_focus_progress()], player.get_focus_progress() > progress_early)
	await _physics(45)
	_release_heal()
	await _physics(3)
	_check("focus: it heals exactly 1 heart and spends exactly the cost (33)", player.health.current_health == before + 1 and soul.soul == 60 - 33 and events == ["started", "completed:1"],
		"%d -> %d, soul %d %s" % [before, player.health.current_health, soul.soul, str(events)])
	_check("focus: it ends back in a normal state", player.state != Player.State.FOCUS)
	# --- the cost rises with the fragments kept ---
	for kept in [1, 2, 3]:
		GameState.souls_kept = kept
		_check("focus: with %d kept the cost is %d" % [kept, 33 + 5 * kept], soul.heal_cost() == 33 + 5 * kept)
	GameState.souls_kept = 2
	soul.reset()
	soul.add_soul(42)
	events.clear()
	_hold_heal()
	await _physics(70)
	_release_heal()
	await _physics(3)
	_check("focus: with 2 kept (cost 43) 42 soul is not enough: it never started", "started" not in events and soul.soul == 42 and denied.has(&"not_enough_soul"), str(events))
	denied.clear()
	soul.add_soul(1)
	events.clear()
	var hp: int = player.health.current_health
	_hold_heal()
	await _physics(70)
	_release_heal()
	await _physics(3)
	_check("focus: with 43 soul and 2 kept it heals and spends exactly 43", player.health.current_health == hp + 1 and soul.soul == 0, "%d, soul %d" % [player.health.current_health, soul.soul])
	GameState.souls_kept = 0
	# --- release early cancels without spending ---
	soul.reset()
	soul.add_soul(60)
	events.clear()
	hp = player.health.current_health
	_hold_heal()
	await _physics(20)
	_release_heal()
	await _physics(3)
	_check("focus: releasing early cancels it and spends nothing", events == ["started", "cancelled"] and soul.soul == 60 and player.health.current_health == hp, str(events))
	await _physics(5)
	# --- damage cancels ---
	events.clear()
	_hold_heal()
	await _physics(20)
	_hurt(player, 1)
	await _physics(3)
	_release_heal()
	_check("focus: taking damage cancels it, spends nothing and only the damage is lost", events == ["started", "cancelled"] and soul.soul == 60
		and player.health.current_health == hp - 1 and player.state == Player.State.HURT, str(events))
	await _physics(90)
	# --- dash cancels ---
	player.health.reset()
	_hurt(player, 4)
	await _physics(70)
	events.clear()
	_hold_heal()
	await _physics(20)
	Input.action_press(&"dash")
	await _physics(3)
	Input.action_release(&"dash")
	_release_heal()
	_check("focus: a dash cancels it (and dashes) without spending", events == ["started", "cancelled"] and soul.soul == 60 and player.state != Player.State.FOCUS, str(events))
	await _physics(40)
	# --- movement is locked while focusing ---
	player.health.reset()
	_hurt(player, 2)
	await _physics(70)
	events.clear()
	var x_before: float = player.global_position.x
	_hold_heal()
	await _physics(5)
	Input.action_press(&"move_right")
	Input.action_press(&"jump")
	await _physics(25)
	_check("focus: the player is rooted (no move, no jump)", player.state == Player.State.FOCUS and absf(player.global_position.x - x_before) < 2.0 and player.is_on_floor(),
		"dx %.1f state %d" % [player.global_position.x - x_before, player.state])
	Input.action_release(&"move_right")
	Input.action_release(&"jump")
	_release_heal()
	await _physics(40)
	# --- full health spends nothing ---
	player.health.reset()
	soul.reset()
	soul.add_soul(60)
	events.clear()
	denied.clear()
	_hold_heal()
	await _physics(70)
	_release_heal()
	await _physics(3)
	_check("focus: at full health it does nothing and spends nothing", "started" not in events and soul.soul == 60 and denied == [&"full_health"], str(denied))
	# --- not enough soul ---
	_hurt(player, 2)
	await _physics(70)
	soul.reset()
	soul.add_soul(10)
	denied.clear()
	events.clear()
	_hold_heal()
	await _physics(70)
	_release_heal()
	await _physics(3)
	_check("focus: with too little soul it does nothing and spends nothing", "started" not in events and soul.soul == 10 and denied == [&"not_enough_soul"], str(denied))
	# --- locked, dead ---
	soul.add_soul(50)
	events.clear()
	player.set_input_locked(true)
	_hold_heal()
	await _physics(70)
	_release_heal()
	player.set_input_locked(false)
	_check("focus: it cannot start while the player is input-locked (a cutscene)", "started" not in events and soul.soul == 60)
	# A lock that arrives mid-focus ends it.
	await _physics(5)
	events.clear()
	_hold_heal()
	await _physics(15)
	player.set_input_locked(true)
	await _physics(3)
	player.set_input_locked(false)
	_release_heal()
	_check("focus: a lock that arrives mid-focus cancels it without spending", events == ["started", "cancelled"] and soul.soul == 60, str(events))
	await _physics(5)
	# --- airborne ---
	events.clear()
	player.global_position = Vector2(player.global_position.x, FLOOR_Y - 400.0)
	player.velocity = Vector2.ZERO
	await _physics(3)
	_hold_heal()
	await _physics(10)
	_check("focus: it cannot start in the air", "started" not in events and not player.is_on_floor())
	_release_heal()
	await _physics(80)
	# --- dead ---
	events.clear()
	player.health.kill()
	await _physics(2)
	_hold_heal()
	await _physics(10)
	_release_heal()
	_check("focus: it cannot start while dead", "started" not in events and player.is_dead)
	world.free()
	await _frames(2)
	# --- paused ---
	var pause_world: Node2D = _arena()
	var pause_player: Player = await _grounded_player(pause_world)
	pause_player.soul.add_soul(60)
	_hurt(pause_player, 2)
	await _physics(70)
	get_tree().paused = true
	_hold_heal()
	await get_tree().create_timer(0.3, true, false, true).timeout
	_release_heal()
	get_tree().paused = false
	_check("focus: nothing starts while the game is paused", pause_player.state != Player.State.FOCUS and pause_player.soul.soul == 60)
	pause_world.free()
	await _frames(2)
	# --- max health 8..11 ---
	for max_health in [8, 9, 10, 11]:
		var w: Node2D = _arena()
		var p: Player = await _grounded_player(w)
		p.health.max_health = max_health
		p.health.reset()
		_hurt(p, 1)
		await _physics(70)
		p.soul.add_soul(60)
		_hold_heal()
		await _physics(70)
		_release_heal()
		await _physics(3)
		_check("focus: with %d max hearts one focus heals back to exactly %d" % [max_health, max_health], p.health.current_health == max_health and p.soul.soul == 27, "%d, soul %d" % [p.health.current_health, p.soul.soul])
		p.soul.add_soul(60)
		var soul_full_health: int = p.soul.soul
		_hold_heal()
		await _physics(70)
		_release_heal()
		await _physics(3)
		_check("focus: at %d/%d it never goes above max and spends nothing" % [max_health, max_health], p.health.current_health == max_health and p.soul.soul == soul_full_health)
		w.free()
		await _frames(2)
	# --- the tutorial practice: focus at full health spends the soul and heals nothing ---
	var practice_world: Node2D = _arena()
	var practice: Player = await _grounded_player(practice_world)
	practice.focus_practice = true
	practice.soul.add_soul(60)
	var completed: Array[int] = []
	practice.focus_completed.connect(func(healed: int) -> void: completed.append(healed))
	_hold_heal()
	await _physics(70)
	_release_heal()
	await _physics(3)
	_check("focus: the tutorial practice completes at full health, spends the soul and heals nothing", completed == [0] and practice.soul.soul == 27
		and practice.health.current_health == practice.health.max_health, str(completed))
	practice_world.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# No orbs
# ---------------------------------------------------------------------------------------------

func _test_no_orbs() -> void:
	_clean_state()
	for path in ["health_orb.gd", "health_orb.tscn", "health_orb_drop.gd", "health_orb_stats.gd", "default_health_orb_stats.tres"]:
		_check("orbs: %s is deleted" % path, not FileAccess.file_exists("res://backend/combat/" + path))
	var stats := EnemyStats.new()
	var boss_stats := BossStats.new()
	_check("orbs: the enemy and boss stats have no orb fields", not ("health_orb_count" in stats) and not ("health_orbs_on_phase_2" in boss_stats) and not ("health_orbs_on_defeat" in boss_stats))
	var classes: Array[String] = []
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		classes.append(String(entry["class"]))
	_check("orbs: no HealthOrb class is registered", not classes.has("HealthOrb") and not classes.has("HealthOrbDrop") and not classes.has("HealthOrbStats"))
	var world: Node2D = _arena()
	var player: Player = await _grounded_player(world)
	var enemy := (load("res://backend/enemies/melee_enemy.tscn") as PackedScene).instantiate() as EnemyBase
	enemy.position = Vector2(600.0, FLOOR_Y - 30.0)
	world.add_child(enemy)
	var boss := (load("res://backend/bosses/boss_two.tscn") as PackedScene).instantiate() as BossBase
	boss.position = Vector2(900.0, FLOOR_Y - 44.0)
	world.add_child(boss)
	await _physics(5)
	enemy.health.kill()
	boss.activate(player)
	boss.health.apply_damage(DamageInfo.create(boss.health.max_health * 6 / 10, Vector2.ZERO, null, CombatLayers.Team.PLAYER))
	await _physics(90)
	boss.health.kill()
	await get_tree().create_timer(1.4).timeout
	var orb_nodes: int = 0
	for node in get_tree().root.find_children("*", "", true, false):
		var script: Script = node.get_script() as Script
		if script != null and script.resource_path.contains("health_orb"):
			orb_nodes += 1
	_check("orbs: killing an enemy, reaching phase 2 and killing a boss spawn no orb at all", orb_nodes == 0)
	world.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# HUD
# ---------------------------------------------------------------------------------------------

func _test_hud() -> void:
	_clean_state()
	var world: Node2D = _arena()
	var player: Player = await _grounded_player(world)
	var hud := HUD_SCENE.instantiate() as PlayerHealthHud
	add_child(hud)
	await _frames(2)
	player.health.max_health = 11
	player.health.reset()
	hud.bind(player)
	await _frames(4)
	var pips: Rect2 = hud.pips.get_global_rect()
	var wave: Rect2 = hud.wave_bar.get_global_rect()
	var plaque: Rect2 = hud.get_plaque_rect()
	var meter: Rect2 = hud.get_soul_rect()
	_check("hud: 11 hearts are drawn", hud.pips.get_child_count() == 11)
	_check("hud: the soul meter does not overlap the health row, the wave bar or the corruption plaque",
		not meter.intersects(pips) and not meter.intersects(wave) and not meter.intersects(plaque), "%s | %s %s %s" % [str(meter), str(pips), str(wave), str(plaque)])
	var screen: Vector2 = hud._drawer.size
	_check("hud: the soul meter is inside the screen", Rect2(Vector2.ZERO, screen).encloses(meter))
	var bar := BOSS_BAR_SCENE.instantiate() as BossHealthBar
	add_child(bar)
	await _frames(2)
	var bar_rect: Rect2 = (bar.get_node("Root") as Control).get_global_rect()
	_check("hud: the soul meter does not overlap the boss bar", not meter.intersects(bar_rect), str(bar_rect))
	# The tick follows the heal cost, the glow follows the soul.
	GameState.souls_kept = 0
	hud._on_game_state_changed()
	var tick_zero: float = meter.position.x + meter.size.x * float(hud.heal_cost) / float(hud.soul_max)
	GameState.souls_kept = 3
	hud._on_game_state_changed()
	var tick_three: float = meter.position.x + meter.size.x * float(hud.heal_cost) / float(hud.soul_max)
	_check("hud: the cost mark moves right as fragments are kept (cost %d -> %d)" % [33, hud.heal_cost], hud.heal_cost == 48 and tick_three > tick_zero)
	player.soul.reset()
	_check("hud: the meter does not glow without enough soul", not hud.is_heal_affordable() and hud.soul == 0)
	player.soul.add_soul(48)
	_check("hud: it glows when the cost can be paid, and shows the soul", hud.is_heal_affordable() and hud.soul == 48)
	GameState.souls_kept = 0
	hud.free()
	bar.free()
	world.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# The consequence line
# ---------------------------------------------------------------------------------------------

func _test_consequence_line() -> void:
	var texts := load("res://backend/decisions/default_decision_texts.tres") as DecisionTexts
	var line: String = texts.build_level_line(1, 2, 1, 1, "corrupt", 43)
	_check("line: it states the heal cost (curarse cuesta 43 de alma)", line.contains("curarse cuesta 43 de alma"), line)
	_check("line: without decisions it still states the cost", texts.build_level_line(0, 0, 0, 0, "neutral", 33).contains("curarse cuesta 33 de alma"))
	_check("line: the old call without a cost is unchanged", not texts.build_level_line(1, 0, 1, 0, "compassionate").contains("curarse"))
	_check("line: the text is Spanish and editable data", texts.heal_cost_line == "curarse cuesta %d de alma" and texts.heal_cost_line.contains("%d"))


# ---------------------------------------------------------------------------------------------
# The ability card
# ---------------------------------------------------------------------------------------------

func _test_ability_card() -> void:
	_clean_state()
	var host := Node.new()
	add_child(host)
	var card: AbilityCard = AbilityCard.present(host, "test_heal", "Curarse", "Una descripción.", PackedStringArray(["heal"]))
	await _frames(2)
	_check("card: it shows with the live keys from the InputMap (Tecla: E o Q)", card != null and card.is_open and card.key_text == "Tecla: E o Q", card.key_text if card != null else "null")
	_check("card: it pauses the game while shown", get_tree().paused and PauseLock.is_locked())
	_check("card: the same event is never shown twice", AbilityCard.present(host, "test_heal", "Curarse", "x", PackedStringArray(["heal"])) == null)
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	card._input(accept)
	_check("card: a press right at the start is ignored", card.is_open)
	card._elapsed = 1.0
	var closed: Array[bool] = [false]
	card.dismissed.connect(func() -> void: closed[0] = true)
	card._input(accept)
	await _frames(2)
	_check("card: the confirm action dismisses it, the game resumes and nothing stays locked", closed[0] and not get_tree().paused and not PauseLock.is_locked())
	# A remap shows up on the next card.
	InputMap.action_erase_events(&"heal")
	var remapped := InputEventKey.new()
	remapped.physical_keycode = KEY_F
	InputMap.action_add_event(&"heal", remapped)
	var card_two: AbilityCard = AbilityCard.present(host, "test_remap", "Curarse", "x", PackedStringArray(["heal"]))
	await _frames(2)
	_check("card: after remapping the heal action to F it reads \"Tecla: F\"", card_two != null and card_two.key_text == "Tecla: F", card_two.key_text if card_two != null else "null")
	card_two.dismiss()
	await _frames(2)
	ControlsConfig.restore_input_map_defaults()
	_check("card: the defaults are restored afterwards", ControlsConfig.input_map_hint(&"heal") == "E o Q")
	var texts := AbilityTexts.get_default()
	_check("card: its texts are Spanish with accents and point to the controls", texts.card_title == "Nueva habilidad" and texts.footer.contains("Opciones → Controles")
		and texts.heal_description.contains("recuperar") and texts.wave_description_format.contains("curarte"))
	host.free()
	await _frames(2)
	# After keeping a fragment: the improved wave and the new heal cost.
	_clean_state()
	var level := (load("res://frontend/levels/level_1.tscn") as PackedScene).instantiate() as LevelBase
	var intro := level.get_node("AbilityIntro") as AbilityIntro
	intro.play_when_headless = true
	add_child(level)
	await _frames(3)
	_check("intro: in headless runs it stays quiet unless allowed (default off)", not (load("res://frontend/ui/ability_intro.gd") as Script).get_property_default_value(&"play_when_headless"))
	GameState.record_decision("fragment_level_1", "placeholder_boss", 1, GameState.CHOICE_KEPT)
	await _frames(2)
	level.decision_flow.decision_made.emit("fragment_level_1", GameState.CHOICE_KEPT)
	await _frames(3)
	var shown: AbilityCard = intro.card
	_check("intro: keeping a fragment shows the card for the improved wave and names the level and the new cost",
		shown != null and shown.is_open and shown.ability_name == "Onda de espada: nivel 1" and shown.description.contains("38"), shown.description if shown != null else "null")
	_check("intro: the card shows the wave and heal keys", shown != null and shown.key_text.contains("U") and shown.key_text.contains("E"), shown.key_text if shown != null else "null")
	_check("intro: the game is paused while it is shown", get_tree().paused)
	if shown != null:
		shown._elapsed = 1.0
		shown._input(accept)
	await _frames(3)
	_check("intro: dismissed, the game resumes", not get_tree().paused and not PauseLock.is_locked())
	level.decision_flow.decision_made.emit("fragment_level_1", GameState.CHOICE_KEPT)
	await _frames(3)
	_check("intro: the same decision never shows it twice", not get_tree().paused)
	GameState.record_decision("fragment_level_3", "boss_three", 3, GameState.CHOICE_RELEASED)
	level.decision_flow.decision_made.emit("fragment_level_3", GameState.CHOICE_RELEASED)
	await _frames(3)
	_check("intro: releasing a fragment shows no card (Phase 15c: boss 2 is the one whose decision opens the double jump card, so a level 3 fragment is used)", not get_tree().paused)
	level.free()
	await _frames(2)
	_clean_state()
	# The tutorial card.
	var tutorial := (load("res://frontend/levels/tutorial.tscn") as PackedScene).instantiate() as LevelBase
	add_child(tutorial)
	await _frames(3)
	var controller := tutorial.get_node("TutorialController") as TutorialController
	_check("tutorial: the heal step is the ninth and last", controller.steps.size() == 9 and String(controller.steps[8]["id"]) == "heal")
	_check("tutorial: the heal text resolves its key from the InputMap", controller.build_text(String(controller.steps[8]["text"])).contains("E o Q") and not controller.build_text(String(controller.steps[8]["text"])).contains("{"))
	_check("tutorial: the player may practice the focus at full health", tutorial.player.focus_practice)
	controller.current_index = 8
	controller.show_card_when_headless = true
	controller._show_current_prompt()
	await _frames(2)
	var tutorial_card: AbilityCard = null
	for child in controller.get_children():
		if child is AbilityCard:
			tutorial_card = child as AbilityCard
	_check("tutorial: when the heal step begins the card appears with the live keys and pauses the game",
		tutorial_card != null and tutorial_card.is_open and tutorial_card.key_text == "Tecla: E o Q" and get_tree().paused)
	controller._show_current_prompt()
	_check("tutorial: the card is shown once per tutorial", controller.get_children().filter(func(n: Node) -> bool: return n is AbilityCard).size() == 1)
	if tutorial_card != null:
		tutorial_card._elapsed = 1.0
		tutorial_card._input(accept)
	await _frames(3)
	_check("tutorial: after dismissing the card the game resumes", not get_tree().paused)
	controller.player.focus_completed.emit(0)
	_check("tutorial: completing a focus finishes the heal step and the tutorial", controller.is_completed)
	tutorial.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# Controls: the new action is reassignable and the conflict rules still hold
# ---------------------------------------------------------------------------------------------

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event


func _test_controls() -> void:
	var catalog := load(ControlsConfig.CATALOG_PATH) as ControlsCatalog
	_check("controls: the heal action is in the catalog with a Spanish name", catalog.action_ids.has("heal") and catalog.get_action_name("heal") == "Curarse (enfocar)")
	var controls := ControlsConfig.new(TEST_CONTROLS, catalog)
	controls.load_file()
	_check("controls: heal defaults to E and Q, and they do not collide with any other action or debug key",
		controls.get_binding("heal", 0) != null and controls.get_binding("heal", 1) != null
		and ControlsConfig.event_token(controls.get_binding("heal", 0)) == "k:%d" % KEY_E and ControlsConfig.event_token(controls.get_binding("heal", 1)) == "k:%d" % KEY_Q)
	var debug_keys: Array[int] = [KEY_F2, KEY_F3, KEY_F4, KEY_H]
	var clash: bool = false
	for action in controls.get_actions():
		if action == "heal":
			continue
		for slot in 2:
			var event: InputEvent = controls.get_binding(action, slot)
			if event != null and (ControlsConfig.event_token(event) in ["k:%d" % KEY_E, "k:%d" % KEY_Q]):
				clash = true
	for code in debug_keys:
		clash = clash or code == KEY_E or code == KEY_Q
	_check("controls: no other action nor debug key uses E or Q", not clash)
	var result: Dictionary = controls.try_bind("heal", 0, _key(KEY_F))
	_check("controls: the heal action can be reassigned", result["result"] == ControlsConfig.Result.OK and ControlsConfig.event_token(controls.get_binding("heal", 0)) == "k:%d" % KEY_F)
	var conflict: Dictionary = controls.try_bind("heal", 0, _key(KEY_J))
	_check("controls: binding heal to a key another action uses asks to swap (conflict rules intact)", conflict["result"] != ControlsConfig.Result.OK)
	var esc: Dictionary = controls.try_bind("heal", 0, _key(KEY_ESCAPE))
	_check("controls: Esc is still reserved", esc["result"] == ControlsConfig.Result.RESERVED)
	controls.reset_to_defaults()
	_check("controls: the defaults come back", ControlsConfig.event_token(controls.get_binding("heal", 0)) == "k:%d" % KEY_E)
	if FileAccess.file_exists(TEST_CONTROLS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CONTROLS))
	ControlsConfig.restore_input_map_defaults()
