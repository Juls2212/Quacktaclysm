@tool
class_name Backdrop
extends Node2D
## Depth for a level: painted sky, four parallax layers behind the play field (far ridges to
## the near bank), a foreground layer of dark silhouettes in front of it, drifting particles and
## the biome's optional effects (smoke columns, eyes in the dark, vignette).
## Visual only. The biome comes from `biome` or, when empty, from the nearest ancestor that
## exports one (LevelBase). `auto_scroll` drifts the layers on their own (menus without a camera).
## `show_biome()` swaps to another biome with a cross-fade (used by BiomeZone).

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

## The biome on screen (or fading in).
var _shown: Biome = null
## The set of nodes drawing `_shown`, and the sets fading out: { "root": Node2D, "sky": SkyPainter }.
var _current: Dictionary = {}
var _leaving: Array[Dictionary] = []
var _fade_time: float = 0.0
var _fade_left: float = 0.0


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	if _fade_left <= 0.0:
		return
	_fade_left = maxf(_fade_left - delta, 0.0)
	var t: float = 1.0 - _fade_left / maxf(_fade_time, 0.001)
	# The new set comes in a little ahead of the old one leaving, so the sky never shows through.
	_set_alpha(_current, smoothstep(0.0, 0.75, t))
	for biome_set in _leaving:
		# The old sky stays opaque under the new one; only its layers and effects fade.
		_set_alpha(biome_set, 1.0 - smoothstep(0.3, 1.0, t), false)
	if _fade_left <= 0.0:
		_drop_leaving()


## The biome currently on screen (the target while a fade runs).
func get_shown_biome() -> Biome:
	return _shown


## Shows `b`, cross-fading over `duration` seconds (0 = at once). Same biome: nothing happens.
func show_biome(b: Biome, duration: float = 0.0) -> void:
	if b == null or b == _shown:
		return
	if duration <= 0.0 or _current.is_empty() or not is_inside_tree():
		_drop_leaving()
		_free_set(_current)
		_current = _make_set(b)
		_shown = b
		_fade_left = 0.0
		return
	# A fade already running: whatever was coming in leaves too, from where it is.
	_leaving.append(_current)
	for biome_set in _leaving:
		# Leaving skies drop one layer back so the incoming sky always paints over them.
		var sky: SkyPainter = biome_set["sky"]
		if is_instance_valid(sky):
			(sky.get_parent() as CanvasLayer).layer = -6
	_current = _make_set(b)
	_shown = b
	_set_alpha(_current, 0.0)
	_fade_time = duration
	_fade_left = duration


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_current = {}
	_leaving.clear()
	_shown = null
	_fade_left = 0.0
	var b: Biome = biome if biome != null else _find_biome()
	if b == null:
		return
	_current = _make_set(b)
	_shown = b


## Builds every node that draws `b` under one root, so a whole biome can fade as a block.
func _make_set(b: Biome) -> Dictionary:
	var root := Node2D.new()
	root.name = "Biome%d" % get_child_count()
	add_child(root)
	var sky_layer := CanvasLayer.new()
	sky_layer.name = "Sky"
	# Above the level's flat BackgroundLayer (-10), below the play field.
	sky_layer.layer = -5
	root.add_child(sky_layer)
	var sky := SkyPainter.new()
	sky.biome = b
	sky_layer.add_child(sky)
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	var depths: Array = [BackdropLayer.Depth.FAR, BackdropLayer.Depth.MIDFAR, BackdropLayer.Depth.MID, BackdropLayer.Depth.NEAR]
	if show_foreground:
		depths.append(BackdropLayer.Depth.FORE)
	for d in depths:
		var parallax := _parallax(root, "Parallax%s" % BackdropLayer.Depth.keys()[d].capitalize(), d)
		parallax.z_index = 40 if d == BackdropLayer.Depth.FORE else -50 + int(d) * 10
		var layer := BackdropLayer.new()
		layer.biome = b
		layer.depth = d
		parallax.add_child(layer)
	if b.smoke_columns:
		# Same scroll as the far silhouettes the smoke rises from, drawn just in front of them.
		var smoke := _parallax(root, "Smoke", BackdropLayer.Depth.MIDFAR)
		smoke.z_index = -35
		_fx(smoke, b, BackdropFx.Mode.SMOKE)
	if b.blinking_eyes:
		# Between the middle silhouettes and the near bank.
		var eyes := _parallax(root, "Eyes", BackdropLayer.Depth.MID)
		eyes.z_index = -25
		_fx(eyes, b, BackdropFx.Mode.EYES)
	if show_particles and not Engine.is_editor_hint():
		if b.particles != Biome.Particles.NONE:
			_particles(root, b, b.particles, b.particle_color, b.particle_count, 7)
		if b.ash and b.particles != Biome.Particles.ASH:
			_particles(root, b, Biome.Particles.ASH, b.ash_color, 45, 19)
		if b.feathers and b.particles != Biome.Particles.FEATHERS:
			_particles(root, b, Biome.Particles.FEATHERS, b.feather_color, 14, 23)
	if b.vignette:
		_fx(root, b, BackdropFx.Mode.VIGNETTE).z_index = 60
	return {"root": root, "sky": sky}


func _parallax(root: Node2D, node_name: String, d: BackdropLayer.Depth) -> Parallax2D:
	var parallax := Parallax2D.new()
	parallax.name = node_name
	var factor: float = SCROLL[d]
	parallax.scroll_scale = Vector2(factor, 1.0)
	parallax.repeat_size = Vector2(BackdropLayer.WIDTH, 0.0)
	parallax.repeat_times = 3
	parallax.autoscroll = Vector2(-auto_scroll * factor, 0.0)
	root.add_child(parallax)
	return parallax


func _fx(parent: Node2D, b: Biome, mode: BackdropFx.Mode) -> BackdropFx:
	var fx := BackdropFx.new()
	fx.name = BackdropFx.Mode.keys()[mode].capitalize()
	fx.biome = b
	fx.mode = mode
	parent.add_child(fx)
	return fx


func _particles(root: Node2D, b: Biome, kind: Biome.Particles, color: Color, count: int, salt: int) -> void:
	var air := AmbientParticles.new()
	air.name = "Particles%s" % Biome.Particles.keys()[kind].capitalize()
	air.biome = b
	air.setup(kind, color, count, salt)
	air.z_index = 35
	root.add_child(air)


func _set_alpha(biome_set: Dictionary, alpha: float, with_sky: bool = true) -> void:
	if biome_set.is_empty():
		return
	var root: Node2D = biome_set["root"]
	var sky: SkyPainter = biome_set["sky"]
	if is_instance_valid(root):
		root.modulate.a = alpha
	# The sky sits under a CanvasLayer, which does not pass the root's modulate down.
	if with_sky and is_instance_valid(sky):
		sky.modulate.a = alpha


func _free_set(biome_set: Dictionary) -> void:
	if biome_set.is_empty():
		return
	var root: Node2D = biome_set["root"]
	if is_instance_valid(root):
		root.queue_free()


func _drop_leaving() -> void:
	for biome_set in _leaving:
		_free_set(biome_set)
	_leaving.clear()
	_set_alpha(_current, 1.0)


func _find_biome() -> Biome:
	var node: Node = get_parent()
	while node != null:
		var value: Variant = node.get(&"biome")
		if value is Biome:
			return value
		node = node.get_parent()
	return null
