class_name StormDecor
extends Node2D
## The reactive scenery of level 3 (Phase 15g), drawn in code with no assets: puddles that splash when the player lands or dashes through
## them, hanging lamps that flicker when the player passes (at most `flash_hz` flickers a second and never brighter than
## `max_flash_alpha`, the 0.3 cap of the possession), chains that sway when the player passes, and dark broken-tower silhouettes in the
## background. A hard cap on the particles alive at once and on the nodes (three drawing layers). With "Efectos de corrupción" off
## (reduced) there is no splash, no flicker and no sway: the decor stays static. It only READS the player; it never changes gameplay.
## The positions are data of the level scene: x of each puddle (on the floor surface `floor_y`), x of each lamp and chain, and
## (x, height) of each background tower.

@export var config: StormDecorConfig
@export var puddles: PackedFloat32Array = PackedFloat32Array()
@export var lamps: PackedFloat32Array = PackedFloat32Array()
@export var chains: PackedFloat32Array = PackedFloat32Array()
@export var towers: PackedVector2Array = PackedVector2Array()
@export var floor_y: float = 600.0
## Where the lamps and chains hang from.
@export var hang_y: float = 150.0
@export var lamp_drop: float = 190.0
@export var chain_drop: float = 150.0

var reduced: bool = false
var particles: Array[Dictionary] = []
var splash_count: int = 0
var layers: Array[Node2D] = []
## Per chain: swing amplitude (radians) left. Per lamp: seconds left of its flicker.
var sway: Array[float] = []
var flicker_left: Array[float] = []

var _player: Player = null
var _time: float = 0.0
var _was_on_floor: bool = true
var _splash_cooldown: Array[float] = []


func _ready() -> void:
	if config == null:
		config = StormDecorConfig.get_default()
	reduced = not GameSettings.is_corruption_effects_enabled()
	sway.resize(chains.size())
	flicker_left.resize(lamps.size())
	_splash_cooldown.resize(puddles.size())
	for kind in 3:
		var layer := _DecorLayer.new()
		layer.owner_decor = self
		layer.kind = kind
		layer.z_index = [-30, -6, 1][kind]
		add_child(layer)
		layers.append(layer)


## The level player is ready after its children, so it is looked up on the first frame.
func _resolve_player() -> void:
	var level: Node = get_parent()
	if level != null and level.get("player") is Player:
		_player = level.get("player") as Player
		_player.dash_started.connect(_on_player_dash)


func node_count() -> int:
	return 1 + layers.size()


func _process(delta: float) -> void:
	_time += delta
	if _player == null:
		_resolve_player()
	if _player == null or not is_instance_valid(_player):
		return
	if reduced:
		return
	for i in _splash_cooldown.size():
		_splash_cooldown[i] = maxf(_splash_cooldown[i] - delta, 0.0)
	var on_floor: bool = _player.is_on_floor()
	if on_floor and not _was_on_floor:
		_splash_near(_player.global_position.x)
	_was_on_floor = on_floor
	for i in lamps.size():
		flicker_left[i] = maxf(flicker_left[i] - delta, 0.0)
		if absf(_player.global_position.x - lamps[i]) < config.lamp_range and flicker_left[i] <= 0.0:
			flicker_left[i] = 1.0 / config.flash_hz * 2.0
	for i in chains.size():
		if absf(_player.global_position.x - chains[i]) < config.chain_range and sway[i] < config.sway_amount * 0.5 and _player.velocity.length() > 20.0:
			sway[i] = config.sway_amount
		sway[i] = maxf(sway[i] - config.sway_decay * config.sway_amount * delta, 0.0)
	for particle in particles:
		particle["life"] = float(particle["life"]) - delta
		particle["vel"] = (particle["vel"] as Vector2) + Vector2(0.0, 520.0) * delta
		particle["pos"] = (particle["pos"] as Vector2) + (particle["vel"] as Vector2) * delta
	particles = particles.filter(func(p: Dictionary) -> bool: return float(p["life"]) > 0.0)
	for layer in layers:
		layer.queue_redraw()


func _on_player_dash() -> void:
	if reduced or _player == null:
		return
	# A dash through a puddle splashes it too.
	for i in puddles.size():
		if absf(_player.global_position.x - puddles[i]) < config.puddle_width * 0.5 + 60.0:
			_splash_puddle(i)


func _splash_near(player_x: float) -> void:
	for i in puddles.size():
		if absf(player_x - puddles[i]) < config.puddle_width * 0.5:
			_splash_puddle(i)


func _splash_puddle(index: int) -> void:
	if _splash_cooldown[index] > 0.0:
		return
	_splash_cooldown[index] = config.splash_gap
	splash_count += 1
	for k in config.splash_particles:
		if particles.size() >= config.max_particles:
			return
		var side: float = randf_range(-1.0, 1.0)
		particles.append({"pos": Vector2(puddles[index] + side * config.puddle_width * 0.3, floor_y - 2.0), "vel": Vector2(side * config.splash_speed * 0.5, -randf_range(0.5, 1.0) * config.splash_speed), "life": config.splash_life})


## The flicker of a lamp now: a square wave at `flash_hz` times the cap on top of the steady glow, so it never goes over `max_flash_alpha`.
func lamp_alpha(index: int) -> float:
	var steady: float = config.lamp_base_alpha
	if reduced or flicker_left[index] <= 0.0:
		return steady
	var on: bool = int(floor(_time * config.flash_hz * 2.0)) % 2 == 0
	return config.max_flash_alpha if on else steady


## One drawing layer of the decor (the debris far behind, the lamps and chains behind the play field, the puddles on the floor).
class _DecorLayer extends Node2D:
	var owner_decor: StormDecor = null
	var kind: int = 0

	func _draw() -> void:
		if owner_decor == null:
			return
		match kind:
			0:
				owner_decor._draw_debris(self)
			1:
				owner_decor._draw_hanging(self)
			2:
				owner_decor._draw_puddles(self)


func _draw_debris(canvas: Node2D) -> void:
	for tower in towers:
		var base := Vector2(tower.x, floor_y)
		var height: float = tower.y
		var points := PackedVector2Array([base + Vector2(-50.0, 0.0), base + Vector2(-46.0, -height * 0.7), base + Vector2(-20.0, -height), base + Vector2(-8.0, -height * 0.82), base + Vector2(22.0, -height * 0.9),
			base + Vector2(40.0, -height * 0.45), base + Vector2(54.0, 0.0)])
		canvas.draw_colored_polygon(points, config.debris)


func _draw_hanging(canvas: Node2D) -> void:
	for i in chains.size():
		var angle: float = sway[i] * sin(_time * TAU * config.sway_hz) if not reduced else 0.0
		var previous := Vector2(chains[i], hang_y)
		for link in 8:
			var next := previous + Vector2(sin(angle * (1.0 + float(link) * 0.15)), cos(angle)) * (chain_drop / 8.0)
			canvas.draw_line(previous, next, config.metal, 4.0)
			canvas.draw_circle(next, 3.0, config.metal)
			previous = next
	for i in lamps.size():
		var top := Vector2(lamps[i], hang_y)
		var lamp_at := Vector2(lamps[i], hang_y + lamp_drop)
		canvas.draw_line(top, lamp_at, config.metal, 3.0)
		var glow: float = lamp_alpha(i)
		for step in range(4, 0, -1):
			canvas.draw_circle(lamp_at, config.lamp_glow_radius * float(step) / 4.0, Color(config.lamp, glow * 0.3))
		canvas.draw_rect(Rect2(lamp_at + Vector2(-9.0, -4.0), Vector2(18.0, 14.0)), config.metal)
		canvas.draw_rect(Rect2(lamp_at + Vector2(-6.0, 4.0), Vector2(12.0, 8.0)), Color(config.lamp, 0.9))


func _draw_puddles(canvas: Node2D) -> void:
	for x in puddles:
		canvas.draw_rect(Rect2(x - config.puddle_width * 0.5, floor_y - 3.0, config.puddle_width, 3.0), config.water)
		canvas.draw_line(Vector2(x - config.puddle_width * 0.35, floor_y - 1.5), Vector2(x + config.puddle_width * 0.2, floor_y - 1.5), Color(1.0, 1.0, 1.0, 0.35), 1.0)
	for particle in particles:
		canvas.draw_circle(particle["pos"], 2.2, Color(config.water, clampf(float(particle["life"]) * 3.0, 0.0, 1.0)))
