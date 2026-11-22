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
## Levels where the silhouette is sharp; every other level shows it blurred.
@export var sharp_levels: PackedInt32Array = PackedInt32Array([3])
@export_range(8, 200, 1) var sharp_star_count: int = 72
@export_range(4, 100, 1) var blurred_star_count: int = 24
@export_range(2.0, 30.0, 1.0, "suffix:px") var sharp_glow_radius: float = 9.0
@export_range(10.0, 90.0, 1.0, "suffix:px") var blurred_glow_radius: float = 34.0
@export_range(0.1, 0.8, 0.01) var figure_height_ratio: float = 0.44
@export_range(0.0, 1.0, 0.01) var anchor_x_ratio: float = 0.8
@export_range(0.0, 0.5, 0.01) var anchor_top_ratio: float = 0.09
## The silhouette never goes lower than this fraction of the screen height (the sky area).
@export_range(0.2, 0.9, 0.01) var sky_bottom_ratio: float = 0.62
@export_range(0.1, 3.0, 0.1, "suffix:Hz") var twinkle_hz: float = 0.7
@export var star_color: Color = Color(0.86, 0.93, 1.0)
@export var sound_event: StringName = &"grandfather_voice"


static func get_default() -> GrandfatherPresentation:
	var presentation := load(DEFAULT_PATH) as GrandfatherPresentation
	return presentation if presentation != null else GrandfatherPresentation.new()


func is_sharp(level: int) -> bool:
	return sharp_levels.has(level)
