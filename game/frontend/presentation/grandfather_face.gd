class_name GrandfatherFace
extends CanvasLayer
## The grandfather in the sky while his level-start line is shown (Phase 15n; Phase 15r: his full-body figure, only the face clear, see GrandfatherSky).
## It is shown on its own canvas layer between the sky (layer -6) and the play field (layer 0): behind the
## parallax ridges, the play field and the UI, in the sky area. Levels 1 and 2: a faded MEMORY (reduced opacity and a soft wide glow); level 3:
## SOLID and sharp (high opacity, a thin glow). Only the calm (watching) and speaking states: never tears. It fades in, stays while the line is
## shown and fades out (all times in GrandfatherPresentation). With "Efectos de corrupcion" off (reduced) it is a plain fade: no glow pulse and
## a still portrait. Presentation only: it never touches gameplay and is never shown during a fight, a boss intro or an ability card.

signal faded_out

enum Phase { FADE_IN, HOLD, FADE_OUT, DONE }

var presentation: GrandfatherPresentation = null
var sharp: bool = false
var reduced: bool = false
var phase: Phase = Phase.FADE_IN
## Current opacity of the whole face (0 to `target_alpha`).
var alpha: float = 0.0
var portrait: GrandfatherSky = null

var _time: float = 0.0
var _phase_time: float = 0.0
var _alpha_at_fade_out: float = 0.0
var _screen: Vector2 = Vector2(1280.0, 720.0)


## `level` decides memory or solid. Call before adding to the tree.
func setup(p_presentation: GrandfatherPresentation, level: int, p_reduced: bool) -> void:
	presentation = p_presentation
	sharp = presentation.is_sharp(level)
	reduced = p_reduced
	layer = presentation.reflection_layer


## The opacity the face reaches: a faded memory at levels 1 and 2, solid at level 3.
func target_alpha() -> float:
	return presentation.face_solid_alpha if sharp else presentation.face_memory_alpha


func _ready() -> void:
	if presentation == null:
		setup(GrandfatherPresentation.get_default(), 1, not GameSettings.is_corruption_effects_enabled())
	portrait = GrandfatherSky.new()
	portrait.presentation = presentation
	portrait.reduced = reduced
	portrait.alpha = 0.0
	portrait.scale = Vector2.ONE * presentation.face_scale
	add_child(portrait)
	portrait.set_expression(&"watching")
	portrait.gaze = Vector2(0.0, 0.7)
	_place()


func fade_out() -> void:
	if phase == Phase.FADE_OUT or phase == Phase.DONE:
		return
	phase = Phase.FADE_OUT
	_phase_time = 0.0
	_alpha_at_fade_out = alpha
	if portrait != null:
		portrait.talking = false
		portrait.set_expression(&"watching")


## Where the face hangs: inside the sky area of the screen.
func face_position(screen_size: Vector2) -> Vector2:
	var y: float = minf(screen_size.y * presentation.face_anchor_y, screen_size.y * presentation.sky_bottom_ratio)
	return Vector2(screen_size.x * presentation.anchor_x_ratio, y)


func _place() -> void:
	if portrait != null:
		var size: Vector2 = get_viewport().get_visible_rect().size if is_inside_tree() else _screen
		_screen = size
		portrait.position = face_position(size)


func _process(delta: float) -> void:
	_time += delta
	_phase_time += delta
	match phase:
		Phase.FADE_IN:
			alpha = target_alpha() * clampf(_phase_time / presentation.fade_in_time, 0.0, 1.0)
			if _phase_time >= presentation.fade_in_time:
				phase = Phase.HOLD
				_phase_time = 0.0
				if portrait != null:
					# He speaks while the line is shown: the speaking state, never a sad one.
					portrait.set_expression(&"speaking")
					portrait.talking = true
		Phase.HOLD:
			alpha = target_alpha()
		Phase.FADE_OUT:
			alpha = _alpha_at_fade_out * (1.0 - clampf(_phase_time / presentation.fade_out_time, 0.0, 1.0))
			if _phase_time >= presentation.fade_out_time:
				phase = Phase.DONE
				alpha = 0.0
				faded_out.emit()
				queue_free()
				return
	if portrait != null:
		portrait.alpha = alpha
	_place()
