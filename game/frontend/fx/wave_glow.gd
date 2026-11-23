class_name WaveGlow
extends Node2D
## The glow of the player's sword wave (Phase 15d-bis), drawn in code and different for each power tier (the colors come from
## the tier through ProjectileStats: rim_color, core_color, glow_color, glow_strength, trail_length). Two instances per wave:
## BEHIND draws the trail and the halo (and puts a burst of the tier color where the wave hits something); FRONT draws the
## light rim and, for the violet tier, the dark core over the wave body. A wave with no glow (an enemy projectile, or
## glow_strength 0) draws nothing. Presentation only: it reads the projectile and changes no hitbox, speed or damage;
## the halo is kept inside the height of the hitbox so a stronger glow never suggests a bigger hit area.

enum Layer { BEHIND, FRONT }

## The outline of the wave body (the Visual polygon of sword_wave_projectile.tscn) and its dark heart.
const BODY: PackedVector2Array = [Vector2(-2, -22), Vector2(8, -14), Vector2(12, 0), Vector2(8, 14), Vector2(-2, 22), Vector2(2, 12), Vector2(5, 0), Vector2(2, -12), Vector2(-2, -22)]
const HEART: PackedVector2Array = [Vector2(2, -13), Vector2(7, -6), Vector2(9, 0), Vector2(7, 6), Vector2(2, 13), Vector2(4, 0)]
const INK := Color(0.106, 0.098, 0.122)

@export var layer: Layer = Layer.BEHIND

var _projectile: Projectile = null
var _clock: float = 0.0


func _ready() -> void:
	_projectile = get_parent() as Projectile
	if layer == Layer.BEHIND:
		show_behind_parent = true
		z_index = -1
		if _projectile != null:
			_projectile.despawned.connect(_on_despawned)
			var hit_box := _projectile.get_node_or_null(^"Hitbox") as Hitbox
			if hit_box != null:
				hit_box.hit_landed.connect(_on_hit_landed)
	else:
		z_index = 1


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _stats() -> ProjectileStats:
	if _projectile == null or _projectile.stats == null:
		return null
	var stats: ProjectileStats = _projectile.stats
	return stats if stats.glow_strength > 0.0 else null


func _draw() -> void:
	var stats: ProjectileStats = _stats()
	if stats == null:
		return
	var k: float = stats.size_scale
	var dir: float = -1.0 if _projectile.velocity.x < 0.0 else 1.0
	if layer == Layer.BEHIND:
		_draw_trail(stats, k, dir)
		_draw_halo(stats, k)
	else:
		_draw_rim_and_core(stats, k, dir)


## A tapered trail behind the wave: soft discs that shrink and fade along `trail_length`.
func _draw_trail(stats: ProjectileStats, k: float, dir: float) -> void:
	var length: float = stats.trail_length * k
	var count: int = 9
	for i in count:
		var t: float = float(i) / float(count)
		var radius: float = 15.0 * k * (1.0 - 0.75 * t)
		var alpha: float = stats.glow_strength * 0.75 * (1.0 - t)
		draw_circle(Vector2(-dir * t * length, 0.0), radius, Color(stats.glow_color, alpha))


## The halo: it breathes a little and stays inside the height of the hitbox (22 px of half-height, times the size scale).
func _draw_halo(stats: ProjectileStats, k: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_clock * 14.0)
	var radius: float = (17.0 + 2.0 * pulse) * k
	draw_circle(Vector2.ZERO, radius, Color(stats.glow_color, stats.glow_strength * (0.4 + 0.25 * pulse)))
	draw_circle(Vector2.ZERO, radius * 0.6, Color(stats.glow_color, stats.glow_strength * 0.55))


func _draw_rim_and_core(stats: ProjectileStats, k: float, dir: float) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(dir * k, k))
	if stats.core_color.a > 0.0:
		draw_colored_polygon(HEART, stats.core_color)
	draw_polyline(BODY, Color(INK, 0.9), 3.4, true)
	draw_polyline(BODY, stats.rim_color, 1.8, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The wave hurt something: a burst in the colors of its tier where it is.
func _on_hit_landed(_hurtbox: Hurtbox, _info: DamageInfo) -> void:
	_spawn_burst()


## The wave ran into the scenery (a hit already made its own burst, running out of life makes none).
func _on_despawned(reason: StringName) -> void:
	if reason == Projectile.REASON_WORLD:
		_spawn_burst()


func _spawn_burst() -> void:
	var stats: ProjectileStats = _stats()
	if stats == null or _projectile == null:
		return
	var holder: Node = _projectile.get_parent()
	if holder == null:
		return
	var burst := WaveBurst.new()
	burst.glow_color = stats.glow_color
	burst.rim_color = stats.rim_color
	burst.core_color = stats.core_color
	burst.scale_factor = stats.size_scale * stats.impact_scale
	holder.add_child(burst)
	burst.global_position = _projectile.global_position
