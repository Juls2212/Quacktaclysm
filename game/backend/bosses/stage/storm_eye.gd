class_name StormEye
extends Node
## The giant red eye of phase 3 (Phase 15j). It hangs in the sky above the arena, invulnerable (it is not a body: every hit on the boss goes
## through the duck), and fires RED LIGHTNING in volleys: vertical columns from the ceiling and diagonal bolts from the eye to the floor. A volley
## announces its bolts for `bolt_telegraph` s (outlined shapes with a rising stripe, at least 1.0 s: shape and pulse, not color alone), strikes
## for `bolt_active` s (1 heart each, the dash is invulnerable) and rests `bolt_rest` s. The plan ALWAYS LEAVES A SAFE LANE (StageMath.bolt_plan):
## a gap of at least `min_lane_width` px, at most `max_lane_offset` px from the player, which phase15j_smoke_test checks against the real walk
## speed. Child of the stage; it only exists while `active`, and stop() switches every hitbox off at once.

signal volley_announced(plan: Dictionary)
signal volley_struck(plan: Dictionary)

enum Phase { HIDDEN, APPEARING, REST, TELEGRAPH, STRIKE }

var config: StageConfig = null
var stage: BossStage = null
var phase: Phase = Phase.HIDDEN
var clock: float = 0.0
## The plan of the volley in progress (see StageMath.bolt_plan) and the eye's center.
var plan: Dictionary = {}
var center: Vector2 = Vector2.ZERO
var volleys_fired: int = 0

var _hitboxes: Array[Hitbox] = []
var _rng := RandomNumberGenerator.new()


func setup(new_stage: BossStage, new_config: StageConfig, seed_value: int = 0) -> void:
	stage = new_stage
	config = new_config
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value


func is_active() -> bool:
	return phase != Phase.HIDDEN


## 0 (not there) to 1 (fully appeared).
func appear_amount() -> float:
	match phase:
		Phase.HIDDEN:
			return 0.0
		Phase.APPEARING:
			return clampf(clock / maxf(config.eye_appear_time, 0.01), 0.0, 1.0)
	return 1.0


func activate() -> void:
	if phase != Phase.HIDDEN:
		return
	center = Vector2(stage.arena_center, stage.floor_top - config.eye_height)
	phase = Phase.APPEARING
	clock = 0.0
	volleys_fired = 0


## Everything off at once: no bolt, no eye.
func stop() -> void:
	phase = Phase.HIDDEN
	clock = 0.0
	plan = {}
	_switch_off()


func _physics_process(delta: float) -> void:
	if phase == Phase.HIDDEN:
		return
	clock += delta
	match phase:
		Phase.APPEARING:
			if clock >= config.eye_appear_time:
				_enter(Phase.REST)
		Phase.REST:
			if clock >= config.bolt_rest:
				_announce()
		Phase.TELEGRAPH:
			if clock >= config.bolt_telegraph:
				_strike()
		Phase.STRIKE:
			if clock >= config.bolt_active:
				_switch_off()
				_enter(Phase.REST)


func _enter(next: Phase) -> void:
	phase = next
	clock = 0.0


## Plans a volley around the player and starts the telegraph (the tests call plan_for directly).
func _announce() -> void:
	var player_x: float = stage.boss.target.global_position.x if stage.boss.is_target_valid() else stage.arena_center
	plan = plan_for(player_x, _rng.randf(), _rng.randf())
	_enter(Phase.TELEGRAPH)
	volley_announced.emit(plan)


func plan_for(player_x: float, roll_a: float, roll_b: float) -> Dictionary:
	return StageMath.bolt_plan(config, stage.arena_left, stage.arena_right, center, stage.floor_top, player_x, roll_a, roll_b)


func _strike() -> void:
	_enter(Phase.STRIKE)
	volleys_fired += 1
	var verticals: PackedFloat32Array = plan["verticals"]
	var radials: PackedFloat32Array = plan["radials"]
	var needed: int = verticals.size() + radials.size()
	_ensure_hitboxes(needed)
	var top: float = stage.ceiling_bottom
	var height: float = maxf(stage.floor_top - top, 40.0)
	var index: int = 0
	for x in verticals:
		var box: Hitbox = _hitboxes[index]
		index += 1
		_shape_of(box, Vector2(config.bolt_width, height))
		box.rotation = 0.0
		box.global_position = Vector2(x, top + height * 0.5)
		box.activate()
	for x in radials:
		var box: Hitbox = _hitboxes[index]
		index += 1
		var foot := Vector2(x, stage.floor_top)
		var length: float = center.distance_to(foot)
		_shape_of(box, Vector2(length, config.bolt_width * 0.7))
		box.rotation = (foot - center).angle()
		box.global_position = center.lerp(foot, 0.5)
		box.activate()
	volley_struck.emit(plan)


func _shape_of(box: Hitbox, size: Vector2) -> void:
	var shape_node := box.get_node("CollisionShape2D") as CollisionShape2D
	var rect := RectangleShape2D.new()
	rect.size = size
	shape_node.shape = rect
	box.damage = config.bolt_damage
	box.knockback = config.bolt_knockback


func _switch_off() -> void:
	for box in _hitboxes:
		if is_instance_valid(box):
			box.deactivate()


func _ensure_hitboxes(count: int) -> void:
	while _hitboxes.size() < count:
		var box := Hitbox.new()
		box.team = CombatLayers.Team.ENEMY
		box.damage = config.bolt_damage
		box.rehit_interval = 0.3
		box.owner_body = stage.boss
		box.top_level = true
		var shape_node := CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		shape_node.shape = RectangleShape2D.new()
		box.add_child(shape_node)
		stage.boss.attack_pivot.add_child(box)
		_hitboxes.append(box)


## True while any bolt hurts.
func is_striking() -> bool:
	return phase == Phase.STRIKE


## What the stage fx draws.
func get_draw_state() -> Dictionary:
	var progress: float = 0.0
	match phase:
		Phase.TELEGRAPH:
			progress = clampf(clock / config.bolt_telegraph, 0.0, 1.0)
		Phase.STRIKE:
			progress = clampf(clock / config.bolt_active, 0.0, 1.0)
	return {"kind": &"eye", "center": center, "radius": config.eye_radius, "appear": appear_amount(), "phase": phase, "progress": progress, "plan": plan,
		"floor": stage.floor_top if stage != null else 0.0, "top": stage.ceiling_bottom if stage != null else 0.0, "width": config.bolt_width}
