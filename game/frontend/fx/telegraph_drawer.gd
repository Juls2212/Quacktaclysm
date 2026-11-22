class_name TelegraphDrawer
extends Node2D
## Draws the telegraph of one attacker while its attack winds up: an arc, a floor lane, an aim line
## or a fan of aim lines (shape and colors come from a TelegraphStyle), plus an optional exclamation
## mark above the head. The shape fills as the windup runs out, so the time left can be read.
## Everything is drawn in code from preset members (no allocation per frame). Presentation only:
## the visual that owns it shows, updates and hides it from the attacker's existing signals; nothing
## here reads or changes a gameplay value. It is a child of the attacker (not of its Visual), so the
## hit flash and tints do not recolor it; `facing` mirrors it.

var style: TelegraphStyle = null
var active: bool = false
## 0..1 through the windup.
var progress: float = 0.0
## Where the aim lines start, the arc is centered and the exclamation mark floats (attacker space, facing +x).
var muzzle: Vector2 = Vector2(28.0, -4.0)
var center: Vector2 = Vector2(0.0, -12.0)
var head_point: Vector2 = Vector2(2.0, -52.0)
## Y of the floor under the attacker (lane position).
var ground_y: float = 26.0
## Real reach in pixels (a lunge or a charge); 0 uses the style's size.
var reach: float = 0.0
## Fan of aim lines (boss volleys): how many and across how many degrees.
var fan_count: int = 1
var fan_degrees: float = 0.0
## Whom the aim lines point at (may be null: they point forward).
var aim_target: Node2D = null

var _clock: float = 0.0


func _ready() -> void:
	# Under the attacker's own drawing, over the floor.
	z_index = -1
	visible = false


## Starts showing `new_style`.
func show_telegraph(new_style: TelegraphStyle) -> void:
	style = new_style
	active = new_style != null
	progress = 0.0
	visible = active
	queue_redraw()


func hide_telegraph() -> void:
	active = false
	progress = 0.0
	visible = false
	aim_target = null


## Called every frame by the owning visual while the windup runs.
func update_windup(new_progress: float, facing: int, delta: float) -> void:
	if not active:
		return
	progress = clampf(new_progress, 0.0, 1.0)
	scale.x = 1.0 if facing >= 0 else -1.0
	_clock += delta
	queue_redraw()


func _draw() -> void:
	if not active or style == null:
		return
	var length: float = reach if reach > 0.0 else style.size
	match style.shape:
		TelegraphStyle.Shape.ARC:
			_draw_arc(length)
		TelegraphStyle.Shape.LANE:
			_draw_lane(length)
		TelegraphStyle.Shape.AIM_LINE:
			_draw_aim(1, 0.0, length)
		TelegraphStyle.Shape.AIM_FAN:
			_draw_aim(maxi(fan_count, 1), fan_degrees, length)
	if style.exclamation:
		_draw_exclamation()


func _draw_arc(length: float) -> void:
	var half: float = deg_to_rad(style.arc_degrees * 0.5)
	var bright: Color = style.color
	var fill_radius: float = length * progress
	if fill_radius > 1.0:
		# A thick arc from the center out to fill_radius is a filled sector.
		draw_arc(center, fill_radius * 0.5, -half, half, 20, Color(bright, bright.a * 0.45), fill_radius, false)
	draw_arc(center, length, -half, half, 28, style.outline_color, style.width + 3.0, true)
	draw_arc(center, length, -half, half, 28, bright, style.width, true)
	var upper: Vector2 = center + Vector2.from_angle(half) * length
	var lower: Vector2 = center + Vector2.from_angle(-half) * length
	draw_line(center, upper, style.outline_color, 3.0, true)
	draw_line(center, lower, style.outline_color, 3.0, true)
	draw_line(center, upper, Color(bright, bright.a * 0.8), 1.5, true)
	draw_line(center, lower, Color(bright, bright.a * 0.8), 1.5, true)


func _draw_lane(length: float) -> void:
	var start_x: float = 24.0
	var lane := Rect2(start_x, ground_y - style.width, length, style.width)
	draw_rect(lane, Color(style.color, style.color.a * 0.18))
	draw_rect(Rect2(start_x, lane.position.y, length * progress, style.width), Color(style.color, style.color.a * 0.75))
	draw_rect(lane.grow(2.0), style.outline_color, false, 3.0)
	draw_rect(lane.grow(0.5), style.color, false, 1.5)
	# A chevron at the far end points the way.
	var tip := Vector2(start_x + length + 8.0, lane.position.y + style.width * 0.5)
	var arm: float = maxf(style.width * 0.5, 6.0)
	draw_line(tip, tip + Vector2(-arm, arm), style.outline_color, 4.5, true)
	draw_line(tip, tip + Vector2(-arm, -arm), style.outline_color, 4.5, true)
	draw_line(tip, tip + Vector2(-arm, arm), style.color, 2.5, true)
	draw_line(tip, tip + Vector2(-arm, -arm), style.color, 2.5, true)


func _draw_aim(count: int, spread_degrees: float, length: float) -> void:
	var direction := Vector2.RIGHT
	if aim_target != null and is_instance_valid(aim_target):
		var aim: Vector2 = to_local(aim_target.global_position) - muzzle
		if aim.x > 1.0:
			direction = aim.normalized()
	for i in count:
		var offset: float = 0.0
		if count > 1:
			offset = deg_to_rad(-spread_degrees * 0.5 + float(i) * spread_degrees / float(count - 1))
		var end: Vector2 = muzzle + direction.rotated(offset) * length
		draw_line(muzzle, end, style.outline_color, style.width + 3.0, true)
		draw_line(muzzle, end, Color(style.color, style.color.a * 0.55), style.width, true)
		var reached: Vector2 = muzzle + (end - muzzle) * progress
		draw_line(muzzle, reached, style.outline_color, style.width + 4.0, true)
		draw_line(muzzle, reached, style.color, style.width + 1.0, true)
	draw_circle(muzzle, 5.0 + 6.0 * progress, style.outline_color)
	draw_circle(muzzle, 3.0 + 5.0 * progress, style.color)


func _draw_exclamation() -> void:
	var bob: float = sin(_clock * 14.0) * 2.0
	var top: Vector2 = head_point + Vector2(0.0, -16.0 + bob)
	var bottom: Vector2 = head_point + Vector2(0.0, -5.0 + bob)
	var dot: Vector2 = bottom + Vector2(0.0, 7.0)
	draw_line(top, bottom, style.outline_color, 8.0, true)
	draw_circle(dot, 5.0, style.outline_color)
	draw_line(top, bottom, style.color, 4.5, true)
	draw_circle(dot, 3.2, style.color)
