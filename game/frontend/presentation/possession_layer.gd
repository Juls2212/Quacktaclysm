class_name PossessionLayer
extends CanvasLayer
## The screen overlay of the possession sequence (Phase 15d): a red vignette and a capped red light flash, drawn by a
## small shader over a full-screen rect (it never blocks the mouse). The PossessionDirector sets the two numbers every
## frame. Presentation only.

const SHADER: Shader = preload("res://frontend/presentation/possession_overlay.gdshader")

var vignette: float = 0.0
var flash: float = 0.0

var _rect: ColorRect = null
var _material: ShaderMaterial = null


func _ready() -> void:
	layer = 57
	_rect = ColorRect.new()
	_rect.name = "Overlay"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color(1, 1, 1, 1)
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect.material = _material
	_apply()


func set_look(vignette_color: Color, flash_color: Color) -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"vignette_color", vignette_color)
	_material.set_shader_parameter(&"flash_color", flash_color)


func set_amounts(new_vignette: float, new_flash: float) -> void:
	vignette = new_vignette
	flash = new_flash
	_apply()


func _apply() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"vignette_strength", clampf(vignette, 0.0, 1.0))
	_material.set_shader_parameter(&"flash_amount", clampf(flash, 0.0, 1.0))
	_rect.visible = vignette > 0.001 or flash > 0.001
