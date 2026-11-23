class_name EndingSilhouette
extends Node2D
## The silhouette beats of the endings (Phase 15r), shown OVER the white of the cut: flat dark shapes generated from the duck's own rig (the hero DuckRig,
## tinted nearly black, no veins, no weapon: the wing pose never draws one) over a flat dark ground. The act itself is never shown. Only three stills exist:
##   KNEEL_SWORD (kept ending): the duck kneels with the head bowed and the sword planted upright in the ground BESIDE it, with a clear gap (no contact).
##   LYING_SWORD (kept ending, the beat after): the same dark shape lying still on the ground, far from the planted sword. Nothing else is drawn.
##   EDGE_SKY (cliff ending): the duck standing at the very edge looking up at the sky; it fades out. It is never shown jumping or falling.
## Drawing only: it reads nothing but what it is told (`kind`, `alpha`, `reduced`). In reduced mode it is the same still, with no sway and no fade of its own.

const KNEEL_SWORD: StringName = &"kneel_sword"
const LYING_SWORD: StringName = &"lying_sword"
const EDGE_SKY: StringName = &"edge_sky"
const KINDS: Array[StringName] = [KNEEL_SWORD, LYING_SWORD, EDGE_SKY]
const SIZE := Vector2(1280.0, 720.0)
const FLAT_SHADER: String = """
shader_type canvas_item;
uniform float opacity = 1.0;
void fragment() {
	COLOR = vec4(0.045, 0.04, 0.06, step(0.45, COLOR.a) * opacity);
}
"""
const DARK := Color(0.045, 0.04, 0.06)
const GROUND_Y: float = 560.0
const CLIFF_X: float = 780.0
const RIG_SCALE: float = 5.0
## Gap (px) kept between the planted sword and the duck's body: the blade never touches it (the tests read it).
const SWORD_GAP: float = 90.0
const SWORD_HEIGHT: float = 270.0
const DUCK_X: float = 470.0

var kind: StringName = &"":
	set(value):
		kind = value
		_place()
		queue_redraw()
var alpha: float = 0.0:
	set(value):
		alpha = clampf(value, 0.0, 1.0)
		visible = alpha > 0.001 and kind != &""
		if figure != null and figure.material != null:
			(figure.material as ShaderMaterial).set_shader_parameter("opacity", alpha)
		queue_redraw()
var reduced: bool = false

var actor: Node2D = null
var figure: DuckRig = null
var _time: float = 0.0


func _ready() -> void:
	actor = Node2D.new()
	actor.name = "Duck"
	add_child(actor)
	figure = DuckRig.new()
	figure.look = DuckRig.Look.HERO
	figure.corruption_stage = 0
	figure.position = Vector2(0.0, -26.0)
	figure.modulate = DARK
	figure.wing_angle = 1.3
	# One flat colour: every pixel the rig draws becomes the same dark, and the soft translucent parts (rim light, shadow, glow) are dropped.
	var shader := Shader.new()
	shader.code = FLAT_SHADER
	var flat := ShaderMaterial.new()
	flat.shader = shader
	flat.set_shader_parameter("opacity", alpha)
	figure.material = flat
	actor.add_child(figure)
	_place()
	visible = false


func _process(delta: float) -> void:
	_time += delta
	_place()


## Where the duck's feet are and the swept rectangle of the planted sword, in screen space (the safety tests read these).
func duck_feet() -> Vector2:
	match kind:
		KNEEL_SWORD:
			return Vector2(DUCK_X, GROUND_Y)
		LYING_SWORD:
			return Vector2(DUCK_X + 300.0, GROUND_Y - 38.0)
		EDGE_SKY:
			return Vector2(CLIFF_X - 40.0, GROUND_Y)
	return Vector2(DUCK_X, GROUND_Y)


## The planted sword as a rectangle (screen space); an empty rectangle when this still has none.
func sword_rect() -> Rect2:
	if kind == KNEEL_SWORD:
		return Rect2(DUCK_X + 80.0 + SWORD_GAP, GROUND_Y - SWORD_HEIGHT, 12.0, SWORD_HEIGHT + 14.0)
	if kind == LYING_SWORD:
		return Rect2(DUCK_X + 280.0 + 40.0 + SWORD_GAP, GROUND_Y - SWORD_HEIGHT, 12.0, SWORD_HEIGHT + 14.0)
	return Rect2()


## The rectangle the duck's body covers (feet, rotation and squash applied roughly): used to check it never touches the sword.
func body_rect() -> Rect2:
	var feet: Vector2 = duck_feet()
	match kind:
		KNEEL_SWORD:
			return Rect2(feet.x - 110.0, feet.y - 235.0, 200.0, 235.0)
		LYING_SWORD:
			return Rect2(feet.x - 300.0, feet.y - 70.0, 320.0, 140.0)
		EDGE_SKY:
			return Rect2(feet.x - 80.0, feet.y - 300.0, 160.0, 300.0)
	return Rect2()


func _place() -> void:
	if actor == null or figure == null:
		return
	var sway: float = 0.0 if reduced else sin(_time * 1.3) * 0.004
	var feet: Vector2 = duck_feet()
	actor.visible = kind != &""
	actor.position = feet
	figure.modulate = DARK
	figure.corruption_stage = 0
	figure.corruption_growth = 0.0
	figure.hurt = false
	figure.wear = 0.0
	match kind:
		KNEEL_SWORD:
			actor.scale = Vector2(RIG_SCALE, RIG_SCALE * 0.66)
			actor.rotation = 0.3 + sway
			figure.head_bow = 0.7
			figure.pose_name = &"kneel_edge"
		LYING_SWORD:
			# Lying on its side: the thickness (x) is squashed, the long axis lies along the ground.
			actor.scale = Vector2(RIG_SCALE * 0.55, RIG_SCALE * 0.95)
			actor.rotation = -PI * 0.5
			figure.head_bow = 0.2
			figure.pose_name = &"lie"
		EDGE_SKY:
			actor.scale = Vector2(RIG_SCALE, RIG_SCALE)
			actor.rotation = sway
			figure.head_bow = -0.55
			figure.pose_name = &"stand"


## The one dark colour, at the current opacity.
func _ink() -> Color:
	return Color(DARK, alpha)


func _draw() -> void:
	if kind == &"":
		return
	# The ground: one flat dark slab; at the cliff it ends in an edge with nothing beyond.
	if kind == EDGE_SKY:
		draw_colored_polygon(PackedVector2Array([Vector2(-40.0, GROUND_Y), Vector2(CLIFF_X, GROUND_Y + 6.0), Vector2(CLIFF_X + 14.0, GROUND_Y + 80.0), Vector2(CLIFF_X - 26.0, GROUND_Y + 200.0), Vector2(CLIFF_X + 6.0, SIZE.y + 40.0), Vector2(-40.0, SIZE.y + 40.0)]), _ink())
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-40.0, GROUND_Y), Vector2(SIZE.x + 40.0, GROUND_Y + 4.0), Vector2(SIZE.x + 40.0, SIZE.y + 40.0), Vector2(-40.0, SIZE.y + 40.0)]), _ink())
	var sword: Rect2 = sword_rect()
	if sword.size != Vector2.ZERO:
		_draw_planted_sword(sword)


## The sword planted upright in the ground: a long blade, a guard and a grip above it, the tip buried. Flat, the same dark as everything else.
func _draw_planted_sword(r: Rect2) -> void:
	var x: float = r.position.x + r.size.x * 0.5
	var tip_y: float = r.end.y
	var top_y: float = r.position.y
	var blade := PackedVector2Array([Vector2(x - 5.0, top_y + 52.0), Vector2(x + 5.0, top_y + 52.0), Vector2(x + 3.0, tip_y - 4.0), Vector2(x, tip_y), Vector2(x - 3.0, tip_y - 4.0)])
	draw_colored_polygon(blade, _ink())
	draw_rect(Rect2(x - 15.0, top_y + 44.0, 30.0, 8.0), _ink())
	draw_rect(Rect2(x - 4.0, top_y, 8.0, 46.0), _ink())
	draw_circle(Vector2(x, top_y - 2.0), 6.0, _ink())
