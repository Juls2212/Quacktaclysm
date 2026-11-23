class_name GrandfatherPresentation
extends Resource
## Every number, color and wording of what the player SEES of the grandfather (Phase 16c): the line panel and the sky reflection.
## Default instance: res://frontend/presentation/default_grandfather_presentation.tres. Presentation only.

const DEFAULT_PATH: String = "res://frontend/presentation/default_grandfather_presentation.tres"

@export_group("Texts")
## Levels 1 and 2: his voice is a memory of the duck. Level 3: direct speech. `%s` is the line.
@export var memory_format: String = "Recuerdas su voz… «%s»"
@export var direct_format: String = "Abuelo: «%s»"

@export_group("Timing")
## Seconds the line stays up before it dismisses itself (the confirm action skips it).
@export_range(1.0, 20.0, 0.5, "suffix:s") var show_time: float = 6.5
@export_range(0.05, 2.0, 0.05, "suffix:s") var panel_fade_time: float = 0.4
## Pause after the level title and intro before the line appears.
@export_range(0.0, 5.0, 0.1, "suffix:s") var start_delay: float = 0.6
## The line never locks the player's input (0 = no lock; a cutscene would use a few seconds).
@export_range(0.0, 5.0, 0.1, "suffix:s") var max_input_lock: float = 0.0
@export_range(0.5, 20.0, 0.5, "suffix:s") var queue_timeout_margin: float = 5.0

@export_group("Panel")
@export var panel_color: Color = Color(0.05, 0.05, 0.09, 0.84)
@export var text_color: Color = Color(0.98, 0.93, 0.8)
@export var outline_color: Color = Color(0.106, 0.098, 0.122)
@export_range(10, 48, 1) var font_size: int = 22
@export_range(200.0, 1200.0, 10.0, "suffix:px") var panel_width: float = 760.0
@export_range(0.0, 0.9, 0.01) var panel_top_ratio: float = 0.2
@export_range(0, 6, 1) var panel_layer: int = 56

@export_group("Reflection")
## Between the sky (layer -6) and the play field (layer 0): behind the parallax ridges, the play field and the UI.
@export_range(-9, -1, 1) var reflection_layer: int = -5
@export_range(0.1, 5.0, 0.1, "suffix:s") var fade_in_time: float = 1.0
@export_range(0.1, 5.0, 0.1, "suffix:s") var fade_out_time: float = 1.5
@export_range(0.05, 1.0, 0.01) var max_alpha: float = 0.55
## Levels where the face is solid and sharp; every other level shows it as a faded memory.
@export var sharp_levels: PackedInt32Array = PackedInt32Array([3])
## The face in the sky (Phase 15n): its opacity as a memory (levels 1 and 2) and as a solid face (level 3), its scale, where it hangs and its glow.
@export_range(0.05, 1.0, 0.01) var face_memory_alpha: float = 0.4
@export_range(0.05, 1.0, 0.01) var face_solid_alpha: float = 0.6
@export_range(0.2, 4.0, 0.05) var face_scale: float = 1.4
@export_range(0.0, 1.0, 0.01) var anchor_x_ratio: float = 0.8
@export_range(0.0, 0.6, 0.01) var face_anchor_y: float = 0.3
## The face never hangs lower than this fraction of the screen height (the sky area).
@export_range(0.2, 0.9, 0.01) var sky_bottom_ratio: float = 0.62
@export_range(10.0, 400.0, 5.0, "suffix:px") var face_glow_radius_memory: float = 240.0
@export_range(10.0, 400.0, 5.0, "suffix:px") var face_glow_radius_solid: float = 150.0
@export var face_glow_color: Color = Color(0.86, 0.93, 1.0)
@export var sound_event: StringName = &"grandfather_voice"
@export_group("Sky face (Phase 15r)")
## The grandfather in the sky is his full-body rig (DuckRig, GRANDFATHER) rendered small and shown big, so it is soft; the body fades into mist.
## Opacity of the face in the endings.
@export_range(0.05, 1.0, 0.01) var face_ending_alpha: float = 0.7
## The offscreen picture is this small (pixels) and the rig is drawn this big inside it: the upscale is the blur.
@export var sky_view_size: Vector2i = Vector2i(192, 224)
@export_range(1.0, 8.0, 0.1) var sky_rig_scale: float = 5.2
## Where the head sits in the offscreen picture (as a fraction of its size).
@export var sky_head_at: Vector2 = Vector2(0.5, 0.42)
## The head of the grandfather's figure in the rig's own space (the rig's origin is its body center).
@export var sky_head_rig: Vector2 = Vector2(14.0, -8.0)
## The picture fades out between these two heights (0 top, 1 bottom): the body is hidden by mist, only the face stays clear.
@export_range(0.0, 1.0, 0.01) var sky_fade_from: float = 0.62
@export_range(0.0, 1.0, 0.01) var sky_fade_to: float = 0.9
## Blur strength in offscreen pixels (the upscale blurs it as well).
@export_range(0.0, 4.0, 0.1) var sky_blur: float = 1.2
@export var sky_mist_color: Color = Color(0.82, 0.88, 0.98)
@export_range(0.0, 1.0, 0.01) var sky_mist_alpha: float = 0.5
@export_range(0.0, 1.0, 0.01) var sky_grief_glow: float = 0.55
@export_range(0.0, 0.5, 0.01) var sky_grief_tilt: float = 0.14


static func get_default() -> GrandfatherPresentation:
	var presentation := load(DEFAULT_PATH) as GrandfatherPresentation
	return presentation if presentation != null else GrandfatherPresentation.new()


func is_sharp(level: int) -> bool:
	return sharp_levels.has(level)
