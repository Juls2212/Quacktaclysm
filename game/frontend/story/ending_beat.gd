class_name EndingBeat
extends Resource
## One beat of an ending (Phase 15i): a stretch of the cinematic with its camera move, the pose of the duck, the expression of the
## grandfather's portrait, the sounds and the music. A TIMED beat lasts `seconds`; a LINE beat (line >= 0) shows that ending line and
## waits for the confirm action (the camera keeps moving over `seconds` and then holds). Everything the scene draws comes from the beat
## and how far into it we are (0 to 1), so a beat list is the whole script of an ending. Data only.

@export var id: StringName = &""
@export_range(0.0, 30.0, 0.1, "suffix:s") var seconds: float = 4.0
## Index into the ending's lines for a LINE beat; -1 for a timed beat.
@export var line: int = -1

@export_group("Camera")
## World point at the center of the screen, and the zoom, at the start and at the end of the beat.
@export var focus_from: Vector2 = Vector2(640.0, 360.0)
@export var focus_to: Vector2 = Vector2(640.0, 360.0)
@export_range(0.5, 4.0, 0.01) var zoom_from: float = 1.0
@export_range(0.5, 4.0, 0.01) var zoom_to: float = 1.0

@export_group("Duck")
## stand, labored, stagger, kneel, reach, lie, still (the kept ending); walk, head_down, step_off (the cliff ending).
@export var duck_pose: StringName = &"stand"
## False once the duck has left the picture: nothing of it may be drawn from then on.
@export var duck_visible: bool = true
## How far into its pose the duck is at the start and at the end of the beat (0 to 1): a hold keeps both at 1.
@export_range(0.0, 1.0, 0.01) var pose_p_from: float = 0.0
@export_range(0.0, 1.0, 0.01) var pose_p_to: float = 1.0
## Where the duck's feet are at the start and at the end of the beat (walking and the step off the edge).
@export var duck_from: Vector2 = Vector2(640.0, 600.0)
@export var duck_to: Vector2 = Vector2(640.0, 600.0)
## The duck as a dark silhouette (the cliff ending, from the walk on).
@export var silhouette: bool = false
## How labored the breathing is (0 calm, 1 heaving and shaking), at the start and at the end.
@export_range(0.0, 1.0, 0.01) var breath_from: float = 0.0
@export_range(0.0, 1.0, 0.01) var breath_to: float = 0.0
## How far the dark veins have crept over the body (0 none, 1 everywhere; scaled by the fragments kept) and how much color is drained.
@export_range(0.0, 1.0, 0.01) var veins_from: float = 0.0
@export_range(0.0, 1.0, 0.01) var veins_to: float = 0.0
@export_range(0.0, 1.0, 0.01) var drain_from: float = 0.0
@export_range(0.0, 1.0, 0.01) var drain_to: float = 0.0
## The scene's light (windows, color, rising stars), 0 dark city, 1 full.
@export_range(0.0, 1.0, 0.01) var light_from: float = 1.0
@export_range(0.0, 1.0, 0.01) var light_to: float = 1.0
## Wind: sways the grass and the scarf, drifts the feather.
@export_range(0.0, 1.0, 0.01) var wind: float = 0.0

@export_group("Grandfather")
## watching, speaking, grieving, breaking; empty = no portrait.
@export var expression: StringName = &""
## Where the portrait is (as a fraction of the screen) and how big (1 = about 300 px of face).
@export var portrait_at: Vector2 = Vector2(0.5, 0.3)
@export_range(0.3, 3.0, 0.01) var portrait_scale: float = 1.0
@export_range(0.0, 1.0, 0.01) var portrait_alpha: float = 0.7

@export_group("Silhouette (Phase 15r)")
## A flat dark silhouette shown OVER the white of the cut (see EndingSilhouette): kneel_sword, lying_sword or edge_sky; empty = none. Its opacity runs
## from the first value to the second over the beat.
@export var white_silhouette: StringName = &""
@export_range(0.0, 1.0, 0.01) var white_silhouette_from: float = 1.0
@export_range(0.0, 1.0, 0.01) var white_silhouette_to: float = 1.0
## The cliff ending: the duck's sword and hat are left at the edge (drawn in the scene once the duck is gone).
@export var leave_items: bool = false

@export_group("Sound")
## One sound at `sfx_at` of the beat (an event of default_audio_events.tres) with a pitch factor and a volume offset.
@export var sfx: StringName = &""
@export_range(0.0, 1.0, 0.01) var sfx_at: float = 0.0
@export_range(0.25, 4.0, 0.01) var sfx_pitch: float = 1.0
@export_range(-30.0, 12.0, 0.5, "suffix:dB") var sfx_volume_db: float = 0.0
## A repeating sound (a heartbeat, a cold wind): its rate and pitch glide from the first value to the second, and it stops at
## `loop_until` of the beat.
@export var loop_sfx: StringName = &""
@export_range(0.05, 4.0, 0.01, "suffix:Hz") var loop_hz_from: float = 1.0
@export_range(0.05, 4.0, 0.01, "suffix:Hz") var loop_hz_to: float = 1.0
@export_range(0.25, 4.0, 0.01) var loop_pitch_from: float = 1.0
@export_range(0.25, 4.0, 0.01) var loop_pitch_to: float = 1.0
@export_range(-30.0, 12.0, 0.5, "suffix:dB") var loop_volume_db: float = 0.0
@export_range(0.0, 1.0, 0.01) var loop_until: float = 1.0
## How far the music is ducked during the beat (0 = the usual story level, -60 = silence).
@export_range(-60.0, 0.0, 0.5, "suffix:dB") var music_db: float = 0.0

@export_group("Closing")
## The overlay of this beat is white instead of the list's color (the slow cut to white; never a flash).
@export var fade_white: bool = false
## A line beat whose line makes the usual voice blip (false after the cut: nothing but wind is heard then).
@export var voiced: bool = true
## The black (or white) overlay at the end of the beat (0 clear, 1 covers the picture); it blends from the previous value.
@export_range(0.0, 1.0, 0.01) var fade_to: float = 0.0
## The still of this beat in reduced mode (how far into the beat it is drawn, 0 to 1).
@export_range(0.0, 1.0, 0.01) var reduced_progress: float = 1.0
## The most any flash of this beat may reach (always at most the 0.3 cap of the possession effect).
@export_range(0.0, 0.3, 0.01) var flash_alpha: float = 0.0


func is_line() -> bool:
	return line >= 0
