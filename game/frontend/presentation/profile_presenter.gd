class_name ProfilePresenter
extends Node
## Makes the adaptive profile (compassionate / neutral / corrupt) visible and audible in a level.
## PRESENTATION ONLY: it never reads or writes a gameplay stat. It applies a ProfileLook
## (default_profile_presentation.tres) to:
##   - the backdrop (sky and parallax layers behind the play field, never the play field itself),
##   - a light vignette / tint-pulse overlay,
##   - the HUD corruption plaque,
##   - the hero's DuckRig (aura, eye tint) and every enemy's and boss's DuckRig (glow),
##   - the music (pitch and low-pass, through AudioDirector).
## It blends in when the level loads and again when a decision changes the profile (the pulse plays
## only then). The "Efectos de corrupción" option (GameSettings) switches it all off except the plaque
## and the consequence line; OptionsBoard calls `refresh_settings()` when it changes.

const GROUP: StringName = &"profile_presenter"
const OVERLAY_SHADER: Shader = preload("res://frontend/presentation/profile_overlay.gdshader")

@export var presentation: ProfilePresentation = preload("res://frontend/presentation/default_profile_presentation.tres")
@export var backdrop: Backdrop
@export var hud: PlayerHealthHud
@export var player: Player
@export var decision_flow: DecisionFlow

## Whether the effects are on (the option); false = world, duck, enemies and music stay neutral.
var enabled: bool = true
## The profile the presentation is showing (or blending to).
var shown_profile: String = AdaptiveIds.PROFILE_NEUTRAL
## How many decision pulses have played (the tests read it).
var pulses_fired: int = 0

var _current := ProfileLook.new()
var _start := ProfileLook.new()
var _target := ProfileLook.new()
var _tween: Tween = null
var _pulse_tween: Tween = null
var _overlay: ColorRect = null
var _material: ShaderMaterial = null
var _pulse_amount: float = 0.0
var _player_rigs: Array[DuckRig] = []
var _enemy_rigs: Array[DuckRig] = []
## The level's flat BackgroundLayer color (usually hidden); the level's own @onready is not set yet here.
var _flat_background: ColorRect = null


func _enter_tree() -> void:
	# In the group before any sibling's _ready, so enemies can find this node as they load.
	add_to_group(GROUP)


func _ready() -> void:
	_build_overlay()
	_flat_background = get_parent().get_node_or_null("BackgroundLayer/Background") as ColorRect
	enabled = GameSettings.is_corruption_effects_enabled()
	shown_profile = GameState.adaptive_profile
	if player != null:
		for node in player.find_children("*", "DuckRig", true, false):
			_player_rigs.append(node as DuckRig)
	_rebuild_target()
	# The look blends in from neutral when the level loads; the music starts at its value at once.
	_apply(_current)
	_begin_transition(presentation.fade_time)
	_set_music(0.0)
	if decision_flow != null:
		decision_flow.decision_made.connect(_on_decision_made)


func _exit_tree() -> void:
	# A level that closes never leaves its filter or pitch on the music.
	if is_instance_valid(AudioDirector):
		AudioDirector.release_music_profile(self)


## An enemy's or boss's rig asks to be dressed (called through the group by EnemyVisual / BossVisual;
## its glow follows the profile from now on).
func register_enemy_rig(rig: DuckRig) -> void:
	if not _enemy_rigs.has(rig):
		_enemy_rigs.append(rig)
	rig.glow_color = _current.enemy_glow_color


## The values being shown right now (mid-blend or settled).
func get_current_look() -> ProfileLook:
	return _current


## The values the presentation is heading to (what `get_current_look` becomes once the blend ends).
func get_target_look() -> ProfileLook:
	return _target


func is_blending() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


## Settles the blend at once (used by tests and when the options change while paused).
func finish_transition() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_on_blend(1.0)
	_set_music(0.0)


## Re-reads the "Efectos de corrupción" option; called by the options menus when it changes.
func refresh_settings() -> void:
	var now: bool = GameSettings.is_corruption_effects_enabled()
	if now == enabled:
		return
	enabled = now
	if not enabled:
		_stop_pulse()
	_rebuild_target()
	_begin_transition(presentation.fade_time)
	_set_music(presentation.fade_time)


## A decision was made: if it moved the profile, blend to the new look and play the pulse.
func _on_decision_made(_fragment_id: String, _choice: String) -> void:
	var profile: String = GameState.adaptive_profile
	if profile == shown_profile:
		return
	shown_profile = profile
	_rebuild_target()
	_begin_transition(presentation.fade_time)
	_set_music(presentation.fade_time)
	if enabled:
		_fire_pulse(presentation.get_look(profile))


func _rebuild_target() -> void:
	_target.copy_from(presentation.get_look(shown_profile))
	if not enabled:
		# The plaque keeps its tint; everything else in the world stays as it was.
		_target.make_world_neutral()


func _set_music(fade: float) -> void:
	AudioDirector.set_music_profile(_target.music_pitch, _target.music_lowpass_hz, fade, self)


func _begin_transition(duration: float) -> void:
	_start.copy_from(_current)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if duration <= 0.0 or not is_inside_tree():
		_on_blend(1.0)
		return
	_tween = create_tween()
	_tween.tween_method(_on_blend, 0.0, 1.0, duration)


func _on_blend(t: float) -> void:
	ProfileLook.blend(_start, _target, smoothstep(0.0, 1.0, t), _current)
	_apply(_current)


func _apply(look: ProfileLook) -> void:
	if backdrop != null:
		backdrop.set_grade(look.background_tint)
	if _flat_background != null:
		_flat_background.modulate = Color(look.background_tint.r, look.background_tint.g, look.background_tint.b, 1.0)
	_material.set_shader_parameter(&"vignette_color", look.vignette_color)
	_update_overlay_visibility(look)
	if hud != null:
		hud.plaque_tint = look.plaque_tint
	for rig in _player_rigs:
		if is_instance_valid(rig):
			rig.aura_color = look.aura_color
			rig.eye_tint = look.eye_color
	for i in range(_enemy_rigs.size() - 1, -1, -1):
		if is_instance_valid(_enemy_rigs[i]):
			_enemy_rigs[i].glow_color = look.enemy_glow_color
		else:
			_enemy_rigs.remove_at(i)


func _fire_pulse(look: ProfileLook) -> void:
	pulses_fired += 1
	if hud != null:
		hud.pulse_plaque(look.pulse_color, look.pulse_duration)
	_material.set_shader_parameter(&"pulse_color", look.pulse_color)
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.tween_method(_set_pulse, 0.0, 1.0, look.pulse_duration * 0.3)
	_pulse_tween.tween_method(_set_pulse, 1.0, 0.0, look.pulse_duration * 0.7)


func _stop_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	_set_pulse(0.0)
	if hud != null:
		hud.pulse_plaque(Color(1, 1, 1, 0), 0.05)


func _set_pulse(value: float) -> void:
	_pulse_amount = value
	_material.set_shader_parameter(&"pulse", value)
	_update_overlay_visibility(_current)


func _update_overlay_visibility(look: ProfileLook) -> void:
	_overlay.visible = look.vignette_color.a > 0.001 or _pulse_amount > 0.001


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ProfileOverlayLayer"
	# Same layer as the HUD but earlier in the tree: under the plaque, over the play field.
	layer.layer = 1
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.name = "ProfileOverlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = OVERLAY_SHADER
	_overlay.material = _material
	_overlay.visible = false
	layer.add_child(_overlay)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
