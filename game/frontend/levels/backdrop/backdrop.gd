@tool
class_name Backdrop
extends Node2D
## Depth for a level: painted sky, four parallax layers behind the play field (far ridges to
## the near bank), a foreground layer of dark silhouettes in front of it, and drifting particles.
## Visual only. The biome comes from `biome` or, when empty, from the nearest ancestor that
## exports one (LevelBase). `auto_scroll` drifts the layers on their own (menus without a camera).

## Scroll factor of each depth: smaller is farther.
const SCROLL := {
	BackdropLayer.Depth.FAR: 0.1,
	BackdropLayer.Depth.MIDFAR: 0.25,
	BackdropLayer.Depth.MID: 0.45,
	BackdropLayer.Depth.NEAR: 0.7,
	BackdropLayer.Depth.FORE: 1.3,
}

@export var biome: Biome:
	set(value):
		biome = value
		if is_node_ready():
			_build()
## Pixels per second the nearest layer drifts by itself; other layers follow their scroll factor.
@export var auto_scroll: float = 0.0
@export var show_foreground: bool = true
@export var show_particles: bool = true


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	var b: Biome = biome if biome != null else _find_biome()
	if b == null:
		return
	var sky_layer := CanvasLayer.new()
	sky_layer.name = "Sky"
	# Above the level's flat BackgroundLayer (-10), below the play field.
	sky_layer.layer = -5
	add_child(sky_layer)
	var sky := SkyPainter.new()
	sky.biome = b
	sky_layer.add_child(sky)
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	var depths: Array = [BackdropLayer.Depth.FAR, BackdropLayer.Depth.MIDFAR, BackdropLayer.Depth.MID, BackdropLayer.Depth.NEAR]
	if show_foreground:
		depths.append(BackdropLayer.Depth.FORE)
	for d in depths:
		var parallax := Parallax2D.new()
		parallax.name = "Parallax%s" % BackdropLayer.Depth.keys()[d].capitalize()
		var factor: float = SCROLL[d]
		parallax.scroll_scale = Vector2(factor, 1.0)
		parallax.repeat_size = Vector2(BackdropLayer.WIDTH, 0.0)
		parallax.repeat_times = 3
		parallax.autoscroll = Vector2(-auto_scroll * factor, 0.0)
		parallax.z_index = 40 if d == BackdropLayer.Depth.FORE else -50 + int(d) * 10
		add_child(parallax)
		var layer := BackdropLayer.new()
		layer.biome = b
		layer.depth = d
		parallax.add_child(layer)
	if show_particles and b.particles != Biome.Particles.NONE and not Engine.is_editor_hint():
		var air := AmbientParticles.new()
		air.name = "Particles"
		air.biome = b
		air.z_index = 35
		add_child(air)


func _find_biome() -> Biome:
	var node: Node = get_parent()
	while node != null:
		var value: Variant = node.get(&"biome")
		if value is Biome:
			return value
		node = node.get_parent()
	return null
