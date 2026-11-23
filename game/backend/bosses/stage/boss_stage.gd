class_name BossStage
extends Node
## Everything physical in boss 3's arena (Phase 15j), as one place: the four player platforms and the boss-only perch that rise and sink, the
## floor that trembles, crumbles and returns, the void under it (a soft hazard), the ducklings the boss summons and the shield they give it, the
## platform barrage and the red eye. It is a child of the level's Content node beside the boss. The boss patterns ask it for things
## (SummonerCyclePattern drives the phase-2 cycle, the possession hooks below set up phases 2 and 3) and it never decides what the boss does.
##
## ROBUSTNESS: cancel_all() puts the arena back in a state that is right for the next phase from ANY moment: ducklings gone (no soul), shield down,
## barrage and bolts cleared, the floor solid again (a player under it is lifted on top), the boss released from the air. A phase change calls it
## (before the possession sequence), a retry, a player death, the boss's death and leaving the level call it for good (platforms hidden too).
## The floor is only ever swapped for two parts (the corridor and the arena) during a collapse; the level's own floor node comes back after.
## It reads and moves; the drawing is BossStageFx.

signal platforms_changed(state: StringName)
signal floor_changed(state: StringName)
signal ducklings_changed(alive: int)
signal player_fell
signal cleared

@export var config: StageConfig
@export var boss: BossBase
## The floor the arena stands on (level 3: FloorD), the gate that closes behind the player, the right wall and the ceiling.
@export var floor_node: Node2D
@export var gate: Node2D
@export var wall: Node2D
@export var ceiling: Node2D
@export var platform_scene: PackedScene
@export var duckling_scene: PackedScene

# Measured from the level nodes in _ready().
var arena_left: float = 5645.0
var arena_right: float = 6675.0
var arena_center: float = 6160.0
var floor_top: float = 600.0
var ceiling_bottom: float = 160.0

## down, rising, up, sinking.
var platforms_state: StringName = &"down"
## solid, trembling, crumbling, gone, shimmering.
var floor_state: StringName = &"solid"
var floor_state_time: float = 0.0
## 0 (down) to 1 (risen), for the drawing.
var rise_progress: float = 0.0
var platforms: Array[PlaceholderPlatform] = []
var perch: BossPerch = null
var barrage: PlatformBarrage = null
var eye: StormEye = null
var ducklings: Array[Duckling] = []
## Ducklings summoned in the wave in progress, and whether a wave is in progress (the shield depends on it).
var summoned: int = 0
var wave_active: bool = false
var reduced: bool = false
var falls: int = 0
## Times the arena was cleared (the tests read it).
var clears: int = 0

var _guard: BossShield = null
var _tween: Tween = null
var _tail_part: PlaceholderPlatform = null
var _arena_part: PlaceholderPlatform = null
var _void: Area2D = null
var _void_shape: CollisionShape2D = null
var _spawn_turn: int = 0


func _ready() -> void:
	if config == null:
		config = StageConfig.get_default()
	reduced = not GameSettings.is_corruption_effects_enabled()
	measure()
	barrage = PlatformBarrage.new()
	barrage.name = "Barrage"
	add_child(barrage)
	barrage.setup(self, config)
	eye = StormEye.new()
	eye.name = "Eye"
	add_child(eye)
	eye.setup(self, config)
	_build_void()
	if boss != null:
		boss.set_meta(&"stage", self)
		_guard = boss.get_node_or_null(^"Shield") as BossShield
		boss.phase_transition_started.connect(_on_transition_started)
		boss.phase_changed.connect(_on_phase_changed)
		boss.encounter_reset.connect(func() -> void: cancel_all(true))
		boss.defeated.connect(func(_b: BossBase) -> void: cancel_all(true))


func _exit_tree() -> void:
	if floor_state != &"solid":
		_swap_back()


## Reads the arena from the level nodes (so no number of the level is typed here).
func measure() -> void:
	if floor_node != null:
		floor_top = floor_node.position.y - float(floor_node.get("size").y) * 0.5
	if gate != null:
		arena_left = gate.position.x + float(gate.get("size").x) * 0.5
	if wall != null:
		arena_right = wall.position.x - float(wall.get("size").x) * 0.5
	if ceiling != null:
		ceiling_bottom = ceiling.position.y + float(ceiling.get("size").y) * 0.5
	arena_center = (arena_left + arena_right) * 0.5


# ---------------------------------------------------------------------------------------------
# Positions the boss moves between
# ---------------------------------------------------------------------------------------------

func perch_top() -> float:
	return floor_top - config.perch_height


## Where the boss' center is when it stands on the perch.
func perch_position() -> Vector2:
	return Vector2(arena_center + config.perch_offset, perch_top() - 44.0)


## Where the boss hovers while the floor is gone: over the bare floor on `side` (-1 or 1) of the platforms, so it lands on the floor.
func aloft_position(side: int = 1) -> Vector2:
	return Vector2(arena_center + float(side) * config.aloft_offset, floor_top - config.aloft_height)


func floor_position(x: float) -> Vector2:
	return Vector2(x, floor_top - 44.0)


## Where the player reappears after falling: standing on the lowest platform.
func rescue_position() -> Vector2:
	var span: Vector2 = StageMath.platform_span(config, arena_center, 0)
	return Vector2((span.x + span.y) * 0.5, StageMath.platform_top(config, floor_top, 0) - 30.0)


# ---------------------------------------------------------------------------------------------
# Platforms and perch
# ---------------------------------------------------------------------------------------------

func _ensure_platforms() -> void:
	if not platforms.is_empty() or platform_scene == null:
		return
	var container: Node = get_parent()
	for i in config.platform_heights.size():
		var plat := platform_scene.instantiate() as PlaceholderPlatform
		plat.name = "StagePlatform%d" % (i + 1)
		plat.size = Vector2(config.platform_width, config.platform_thickness)
		plat.one_way = true
		plat.color = config.platform_color
		plat.skin = config.platform_skin as TerrainSkin.Kind
		plat.position = _platform_rest(i)
		plat.visible = false
		container.add_child(plat)
		_set_solid(plat, false)
		platforms.append(plat)
	perch = BossPerch.new()
	perch.name = "BossPerch"
	perch.size = Vector2(config.perch_width, 22.0)
	perch.chain_height = maxf(perch_top() - ceiling_bottom, 20.0)
	perch.position = Vector2(arena_center + config.perch_offset, perch_top() + 11.0)
	perch.visible = false
	container.add_child(perch)
	perch.set_solid(false)


func _platform_rest(index: int) -> Vector2:
	var span: Vector2 = StageMath.platform_span(config, arena_center, index)
	return Vector2((span.x + span.y) * 0.5, StageMath.platform_top(config, floor_top, index) + config.platform_thickness * 0.5)


func _set_solid(plat: PlaceholderPlatform, solid: bool) -> void:
	var shape := plat.get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.set_deferred(&"disabled", not solid)


func platform_count() -> int:
	return platforms.size()


## The platforms and the perch rise (about 1.2 s): from below the floor line, or just fading in with «Efectos de corrupción» off.
func raise_platforms() -> void:
	if platforms_state == &"up" or platforms_state == &"rising":
		return
	_ensure_platforms()
	if platforms.is_empty():
		return
	_kill_tween()
	platforms_state = &"rising"
	platforms_changed.emit(platforms_state)
	var drop: float = 0.0 if reduced else config.rise_depth
	for i in platforms.size():
		platforms[i].position = _platform_rest(i) + Vector2(0.0, drop)
		platforms[i].modulate.a = 0.0
		platforms[i].visible = true
		_set_solid(platforms[i], false)
	perch.position = Vector2(arena_center + config.perch_offset, perch_top() + 11.0 + drop)
	perch.modulate.a = 0.0
	perch.visible = true
	perch.set_solid(false)
	_tween = create_tween().set_parallel(true)
	for i in platforms.size():
		_tween.tween_property(platforms[i], "position", _platform_rest(i), config.rise_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_tween.tween_property(platforms[i], "modulate:a", 1.0, config.rise_time * 0.6)
	_tween.tween_property(perch, "position", Vector2(arena_center + config.perch_offset, perch_top() + 11.0), config.rise_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(perch, "modulate:a", 1.0, config.rise_time * 0.6)
	_tween.tween_property(self, "rise_progress", 1.0, config.rise_time)
	_tween.chain().tween_callback(_on_risen)


func _on_risen() -> void:
	platforms_state = &"up"
	for plat in platforms:
		_set_solid(plat, true)
	perch.set_solid(true)
	platforms_changed.emit(platforms_state)


## The platforms and the perch sink away (animated); nothing can stand on them from the first frame.
func sink_platforms() -> void:
	if platforms_state == &"down" or platforms_state == &"sinking":
		return
	_kill_tween()
	platforms_state = &"sinking"
	platforms_changed.emit(platforms_state)
	for plat in platforms:
		_set_solid(plat, false)
	if perch != null:
		perch.set_solid(false)
	var drop: float = 0.0 if reduced else config.rise_depth
	_tween = create_tween().set_parallel(true)
	for i in platforms.size():
		_tween.tween_property(platforms[i], "position", _platform_rest(i) + Vector2(0.0, drop), config.sink_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		_tween.tween_property(platforms[i], "modulate:a", 0.0, config.sink_time)
	_tween.tween_property(perch, "position", Vector2(arena_center + config.perch_offset, perch_top() + 11.0 + drop), config.sink_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(perch, "modulate:a", 0.0, config.sink_time)
	_tween.tween_property(self, "rise_progress", 0.0, config.sink_time)
	_tween.chain().tween_callback(hide_platforms_now)


## Platforms and perch gone at once (a retry, the end of the fight).
func hide_platforms_now() -> void:
	_kill_tween()
	for plat in platforms:
		plat.visible = false
		_set_solid(plat, false)
	if perch != null:
		perch.visible = false
		perch.set_solid(false)
	rise_progress = 0.0
	if platforms_state != &"down":
		platforms_state = &"down"
		platforms_changed.emit(platforms_state)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


# ---------------------------------------------------------------------------------------------
# The floor
# ---------------------------------------------------------------------------------------------

func _set_floor_state(state: StringName) -> void:
	floor_state = state
	floor_state_time = 0.0
	if _void != null:
		_void.set_deferred(&"monitoring", state == &"gone" or state == &"shimmering")
	floor_changed.emit(state)


## The floor starts to shake (cracks appear; the camera shakes unless reduced).
func begin_tremble() -> void:
	if floor_state == &"solid":
		_set_floor_state(&"trembling")


## The floor crumbles (`crumble_time`) and is gone: only the arena part, the corridor behind the gate stays.
func collapse_floor() -> void:
	if floor_state == &"gone" or floor_state == &"crumbling" or floor_node == null or platform_scene == null:
		return
	_swap_to_parts()
	_set_floor_state(&"crumbling")


## The floor's outlines shimmer: it is about to return.
func begin_shimmer() -> void:
	if floor_state == &"gone":
		_set_floor_state(&"shimmering")


## The floor comes back. A player who was below it is lifted onto it.
func restore_floor() -> void:
	if floor_state == &"solid":
		return
	_swap_back()
	_rescue_below_floor()
	_set_floor_state(&"solid")


func _process(delta: float) -> void:
	floor_state_time += delta
	if floor_state == &"crumbling" and floor_state_time >= config.crumble_time:
		if is_instance_valid(_arena_part):
			_arena_part.queue_free()
			_arena_part = null
		_set_floor_state(&"gone")
	_update_ducklings()


func _swap_to_parts() -> void:
	var container: Node = get_parent()
	var left: float = floor_node.position.x - float(floor_node.get("size").x) * 0.5
	var right: float = floor_node.position.x + float(floor_node.get("size").x) * 0.5
	var thickness: float = float(floor_node.get("size").y)
	_set_solid(floor_node as PlaceholderPlatform, false)
	floor_node.visible = false
	_tail_part = _make_floor_part(container, left, arena_left, thickness)
	_arena_part = _make_floor_part(container, arena_left, right, thickness)


func _make_floor_part(container: Node, from_x: float, to_x: float, thickness: float) -> PlaceholderPlatform:
	var part := platform_scene.instantiate() as PlaceholderPlatform
	part.size = Vector2(to_x - from_x, thickness)
	part.color = floor_node.get("color")
	part.skin = floor_node.get("skin")
	part.position = Vector2((from_x + to_x) * 0.5, floor_node.position.y)
	container.add_child(part)
	return part


func _swap_back() -> void:
	if is_instance_valid(_tail_part):
		_tail_part.queue_free()
	if is_instance_valid(_arena_part):
		_arena_part.queue_free()
	_tail_part = null
	_arena_part = null
	if floor_node != null:
		floor_node.visible = true
		_set_solid(floor_node as PlaceholderPlatform, true)


func _build_void() -> void:
	_void = Area2D.new()
	_void.name = "VoidHazard"
	_void.collision_layer = 0
	_void.collision_mask = CombatLayers.layer_bit(CombatLayers.LAYER_PLAYER)
	_void.monitoring = false
	_void_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(arena_right - arena_left, 400.0)
	_void_shape.shape = rect
	_void.add_child(_void_shape)
	_void.position = Vector2(arena_center, floor_top + config.void_depth + 200.0)
	_void.body_entered.connect(_on_void_entered)
	add_child(_void)


## Falling into the void costs 1 heart and puts the player back on the lowest platform with a moment of invulnerability: never a checkpoint,
## never a softlock. If the heart was the last one, the usual death flow applies.
func _on_void_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null or player.is_dead:
		return
	falls += 1
	player_fell.emit()
	if config.void_damage > 0:
		player.health.apply_damage(DamageInfo.create(config.void_damage, Vector2.ZERO, boss, CombatLayers.Team.ENEMY, &"void"))
	if player.is_dead or player.health.is_dead:
		return
	player.global_position = rescue_position()
	player.velocity = Vector2.ZERO
	player.health.grant_invulnerability(config.void_invulnerability)


func _rescue_below_floor() -> void:
	var player: Player = _player()
	if player != null and not player.is_dead and player.global_position.y > floor_top - 8.0 and player.global_position.x > arena_left - 40.0 and player.global_position.x < arena_right + 40.0:
		player.global_position = Vector2(clampf(player.global_position.x, arena_left + 30.0, arena_right - 30.0), floor_top - 30.0)
		player.velocity = Vector2.ZERO


func _player() -> Player:
	if boss != null and is_instance_valid(boss.target) and boss.target is Player:
		return boss.target as Player
	return get_tree().get_first_node_in_group(&"player") as Player if is_inside_tree() else null


# ---------------------------------------------------------------------------------------------
# Ducklings and the shield
# ---------------------------------------------------------------------------------------------

func begin_wave() -> void:
	summoned = 0
	wave_active = true
	_spawn_turn = 0


func end_wave() -> void:
	wave_active = false
	summoned = 0
	_update_shield()


func alive_count() -> int:
	var count: int = 0
	for index in ducklings.size():
		var duckling: Variant = ducklings[index]
		if duckling != null and is_instance_valid(duckling) and duckling.state != EnemyBase.State.DEAD and not duckling.is_queued_for_deletion():
			count += 1
	return count


## True when the whole wave was summoned and none is left.
func wave_cleared() -> bool:
	return wave_active and summoned >= config.wave_size and alive_count() == 0


## Summons up to `count` ducklings (never more than the wave size, never more than `max_alive` alive). Returns how many.
func summon(count: int) -> int:
	if duckling_scene == null:
		return 0
	var made: int = 0
	for i in count:
		if summoned >= config.wave_size or alive_count() >= config.max_alive:
			break
		_spawn_one()
		made += 1
	_update_shield()
	ducklings_changed.emit(alive_count())
	return made


func _slot_position(turn: int) -> Vector2:
	var slots: Array[Vector2] = [
		Vector2(arena_left + config.spawn_edge_margin, floor_top - 20.0),
		Vector2(arena_right - config.spawn_edge_margin, floor_top - 20.0),
	]
	for index in [0, 3, 1, 2]:
		var span: Vector2 = StageMath.platform_span(config, arena_center, index)
		slots.append(Vector2((span.x + span.y) * 0.5, StageMath.platform_top(config, floor_top, index) - 20.0))
	var pos: Vector2 = slots[turn % slots.size()]
	var player: Player = _player()
	if player != null and absf(player.global_position.x - pos.x) < config.spawn_clear_of_player and absf(player.global_position.y - pos.y) < 90.0:
		# Not on top of the player: the other end of the floor.
		pos = slots[(turn + 1) % 2]
	return pos


func _spawn_one() -> void:
	var duckling := duckling_scene.instantiate() as Duckling
	duckling.soul_gain = config.duckling_soul_gain
	get_parent().add_child(duckling)
	duckling.global_position = _slot_position(_spawn_turn)
	_spawn_turn += 1
	summoned += 1
	ducklings.append(duckling)
	duckling.died.connect(func(_e: EnemyBase) -> void:
		_update_shield()
		ducklings_changed.emit(alive_count()))
	if not reduced:
		duckling.modulate.a = 0.0
		var puff := duckling.create_tween()
		puff.tween_property(duckling, "modulate:a", 1.0, config.spawn_puff_time)


func _update_ducklings() -> void:
	var changed: bool = false
	# Phase 15q: never erase() or assign a FREED instance through the typed array (that printed an engine error every frame); walk it by index as a
	# Variant, keep only the valid ones and rebuild the list.
	var kept: Array[Duckling] = []
	for index in ducklings.size():
		var candidate: Variant = ducklings[index]
		if candidate == null or not is_instance_valid(candidate):
			changed = true
			continue
		var duckling: Duckling = candidate as Duckling
		if duckling.global_position.y > floor_top + config.duckling_fall_limit and duckling.state != EnemyBase.State.DEAD:
			# Fell into the void: removed, counted as dead, no soul.
			duckling.vanish()
			changed = true
		else:
			kept.append(duckling)
	if changed:
		ducklings = kept
	if changed:
		_update_shield()
		ducklings_changed.emit(alive_count())


func _update_shield() -> void:
	if _guard != null:
		_guard.set_shield(wave_active and alive_count() > 0)


func shield_is_up() -> bool:
	return _guard != null and _guard.shield_up


func vanish_ducklings() -> void:
	for index in ducklings.size():
		var duckling: Variant = ducklings[index]
		if duckling != null and is_instance_valid(duckling):
			duckling.vanish()
	ducklings.clear()
	ducklings_changed.emit(0)


# ---------------------------------------------------------------------------------------------
# Phases and the clean state
# ---------------------------------------------------------------------------------------------

func _on_transition_started(_next_phase: int) -> void:
	# The pattern was cancelled by the boss; the arena goes to a state that is right for what comes next.
	cancel_all(false)


func _on_phase_changed(phase: int) -> void:
	if phase == 3:
		sink_platforms()
		eye.activate()


## Puts the arena back in order from any moment (see the class doc). `for_good` also hides the platforms and the perch.
func cancel_all(for_good: bool) -> void:
	barrage.stop()
	eye.stop()
	vanish_ducklings()
	wave_active = false
	summoned = 0
	_update_shield()
	if floor_state != &"solid":
		restore_floor()
	if boss != null:
		boss.gravity_scale = 1.0
		boss.exhausted = false
		if not for_good:
			_release_boss()
	if for_good:
		hide_platforms_now()
	clears += 1
	cleared.emit()


## A boss left on the perch or in the air by a cancelled mechanic goes back down to the bare floor (the next phase starts there).
func _release_boss() -> void:
	if boss.state == BossBase.State.DEAD or boss.global_position.y > floor_top - 90.0:
		return
	var side: int = 1 if boss.global_position.x >= arena_center else -1
	boss.global_position = floor_position(arena_center + float(side) * config.aloft_offset)
	boss.velocity = Vector2.ZERO


## What the stage fx draws about the floor and the platforms.
func get_draw_state() -> Dictionary:
	return {"floor": floor_state, "floor_time": floor_state_time, "left": arena_left, "right": arena_right, "top": floor_top, "crumble_time": config.crumble_time,
		"shimmer_time": config.shimmer_time, "platforms": platforms_state, "rise": rise_progress}
