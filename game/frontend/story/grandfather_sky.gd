class_name GrandfatherSky
extends Node2D
## The grandfather in the sky (Phase 15r). It replaces the drawn face of Phase 15i: it is his own FULL-BODY figure (DuckRig, Look.GRANDFATHER, the same
## one that stands in the tutorial and the level 3 entry scene), drawn small in an offscreen picture and shown big, so the upscale blurs it. A soft
## vertical mask hides the body in mist and leaves only the face clear; a warm glow sits behind it and a few pale wisps of cloud drift over the
## lower part. Nothing is drawn over the face (no tears, no extra shapes): sorrow is a lowered head and a dimmer glow. Used by the endings and by the
## level start (GrandfatherFace). Presentation only: it reads nothing but what it is told (`alpha`, the expression, `talking`).
## Reduced mode ("Efectos de corrupción" off): a still picture (the offscreen render runs once per change), no drift, no glow pulse, no tremble.

## Expressions: watching (calm), speaking (the figure talks), grieving (head lowered, dim glow), breaking (lowered more, a faint tremble), solemn (upright).
const STATE_NAMES: PackedStringArray = ["watching", "speaking", "grieving", "breaking", "solemn"]
const SHADER_CODE: String = """
shader_type canvas_item;
uniform float fade_from = 0.5;
uniform float fade_to = 0.82;
uniform float blur = 1.4;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur;
	vec4 c = texture(TEXTURE, UV) * 0.36;
	c += texture(TEXTURE, UV + vec2(px.x, 0.0)) * 0.16;
	c += texture(TEXTURE, UV - vec2(px.x, 0.0)) * 0.16;
	c += texture(TEXTURE, UV + vec2(0.0, px.y)) * 0.16;
	c += texture(TEXTURE, UV - vec2(0.0, px.y)) * 0.16;
	float mist = 1.0 - smoothstep(fade_from, fade_to, UV.y);
	float side = smoothstep(0.0, 0.16, UV.x) * (1.0 - smoothstep(0.84, 1.0, UV.x));
	float top = smoothstep(0.0, 0.1, UV.y);
	COLOR = vec4(c.rgb, c.a * mist * side * top) * COLOR;
}
"""

var presentation: GrandfatherPresentation = null
var reduced: bool = false
## Final opacity of the whole figure (0 hidden to 1), set by whoever shows it.
var alpha: float = 0.0
## Whether he talks (his figure's talking gesture).
var talking: bool = false:
	set(value):
		talking = value
		_apply_gesture()
## Where he looks, as a direction on screen (kept for the callers; the figure always faces the duck's side).
var gaze: Vector2 = Vector2(0.0, 0.6)
var expression: StringName = &"watching"
## 0 (calm) to 1: how bowed the head is and how dim the glow.
var grief: float = 0.0

var rig: DuckRig = null
var viewport: SubViewport = null
var sprite: Sprite2D = null
var mist: _Mist = null

var _time: float = 0.0
var _grief_target: float = 0.0
var _dirty_frames: int = 4


class _Mist extends Node2D:
	var sky: GrandfatherSky = null

	func _draw() -> void:
		sky._draw_mist(self)


func _ready() -> void:
	if presentation == null:
		presentation = GrandfatherPresentation.get_default()
	var size: Vector2i = presentation.sky_view_size
	viewport = SubViewport.new()
	viewport.name = "View"
	viewport.size = size
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	rig = DuckRig.new()
	rig.look = DuckRig.Look.GRANDFATHER
	rig.name = "Figure"
	rig.scale = Vector2.ONE * presentation.sky_rig_scale
	# The head of the figure sits at `sky_head_at` of the picture.
	var head: Vector2 = presentation.sky_head_rig
	rig.position = Vector2(size) * presentation.sky_head_at - head * presentation.sky_rig_scale
	viewport.add_child(rig)
	sprite = Sprite2D.new()
	sprite.name = "Picture"
	sprite.texture = viewport.get_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shader := Shader.new()
	shader.code = SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("fade_from", presentation.sky_fade_from)
	material.set_shader_parameter("fade_to", presentation.sky_fade_to)
	material.set_shader_parameter("blur", presentation.sky_blur)
	sprite.material = material
	add_child(sprite)
	mist = _Mist.new()
	mist.name = "Mist"
	mist.sky = self
	add_child(mist)
	_apply_gesture()
	_update_view()


func set_expression(name: StringName) -> void:
	if not STATE_NAMES.has(String(name)):
		return
	expression = name
	match name:
		&"grieving":
			_grief_target = 0.6
		&"breaking":
			_grief_target = 1.0
		_:
			_grief_target = 0.0
	if reduced:
		grief = _grief_target
		_dirty_frames = 3
	_apply_gesture()


func _apply_gesture() -> void:
	if rig == null:
		return
	rig.gesture = DuckRig.Gesture.TALK if talking or expression == &"speaking" else DuckRig.Gesture.IDLE
	_dirty_frames = 3


func _process(delta: float) -> void:
	_time += delta
	if reduced:
		grief = _grief_target
	else:
		grief = move_toward(grief, _grief_target, delta * 0.9)
	_update_view()
	if mist != null:
		mist.queue_redraw()
	queue_redraw()


func _update_view() -> void:
	if rig == null or presentation == null:
		return
	# Sorrow: the figure tips forward a little; the breaking state adds a faint tremble.
	var tremble: float = 0.0 if reduced or expression != &"breaking" else sin(_time * 31.0) * 0.012
	var tilt: float = presentation.sky_grief_tilt * grief + tremble
	if not is_equal_approx(tilt, rig.rotation):
		rig.rotation = tilt
		_dirty_frames = 3
	if sprite != null:
		sprite.modulate = Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))
	if viewport != null:
		if not reduced:
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		elif _dirty_frames > 0:
			# Reduced: the picture is rendered again only after a change (the engine goes back to disabled by itself).
			_dirty_frames -= 1
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## The glow behind the face: warm, wide, dimmer with sorrow; it breathes slowly unless reduced.
func _draw() -> void:
	if presentation == null or alpha <= 0.001:
		return
	var pulse: float = 1.0 if reduced else 0.88 + 0.12 * sin(_time * TAU * 0.35)
	var dim: float = 1.0 - (1.0 - presentation.sky_grief_glow) * grief
	var warm: Color = Color(1.0, 0.86, 0.6)
	var cool: Color = presentation.face_glow_color
	var center: Vector2 = _face_center()
	var radius: float = float(presentation.sky_view_size.x) * 0.5
	for step in range(14, 0, -1):
		var k: float = float(step) / 14.0
		var color: Color = cool.lerp(warm, 1.0 - k)
		draw_circle(center, radius * (0.55 + 0.75 * k), Color(color, alpha * pulse * dim * 0.032))


## The face's center relative to this node's origin (the picture is centered on it).
func _face_center() -> Vector2:
	var size: Vector2 = Vector2(presentation.sky_view_size)
	return (presentation.sky_head_at - Vector2(0.5, 0.5)) * size


## Wisps of cloud over the lower part of the picture: the body is behind them. Soft, wide, slow.
func _draw_mist(c: Node2D) -> void:
	if presentation == null or alpha <= 0.001:
		return
	var size: Vector2 = Vector2(presentation.sky_view_size)
	var base_y: float = (presentation.sky_fade_from - 0.5) * size.y
	var drift: float = 0.0 if reduced else _time * 6.0
	for i in 7:
		var k: float = float(i) / 6.0
		var x: float = (k - 0.5) * size.x * 0.95 + sin(drift * 0.05 + float(i) * 1.7) * 8.0
		var y: float = base_y + (0.12 + 0.18 * fposmod(float(i) * 0.37, 1.0)) * size.y
		var rx: float = size.x * (0.22 + 0.1 * fposmod(float(i) * 0.53, 1.0))
		var ry: float = rx * 0.34
		for layer in 3:
			var f: float = 1.0 - float(layer) * 0.3
			c.draw_set_transform(Vector2(x, y), 0.0, Vector2(1.0, ry / rx))
			c.draw_circle(Vector2.ZERO, rx * f, Color(presentation.sky_mist_color, alpha * presentation.sky_mist_alpha * 0.2))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
