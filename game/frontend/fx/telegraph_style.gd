class_name TelegraphStyle
extends Resource
## How one attack announces itself while it winds up: a shape drawn in code (never an asset), its
## colors, its size and the sounds that play when the windup starts. Presentation only: it never
## changes a time, a range or a hitbox. Edited in default_telegraphs.tres.

enum Shape {
	## A short arc in front of the attacker (melee swipes); the sector fills as the windup runs out.
	ARC,
	## A lane on the floor in front of the attacker (lunges and charges); it fills toward its end.
	LANE,
	## One thin aim line toward the target (ranged shots).
	AIM_LINE,
	## Several aim lines fanned toward the target (boss volleys).
	AIM_FAN,
	## A ring and a cross on the floor spot where a leaping boss will land (drawn by LeapMarker; `size` is the radius).
	MARKER,
}

@export var kind: StringName = &""
@export var shape: Shape = Shape.ARC
## Bright color of the shape; a dark outline is always drawn under it so it reads on any background.
@export var color: Color = Color(1.0, 0.5, 0.1, 0.85)
@export var outline_color: Color = Color(0.106, 0.098, 0.122, 0.9)
## Arc radius, lane length or aim-line length, in pixels (a lane may take the real reach instead).
@export_range(10.0, 800.0, 1.0, "suffix:px") var size: float = 60.0
## Lane height or line width, in pixels.
@export_range(1.0, 120.0, 0.5, "suffix:px") var width: float = 6.0
@export_range(10.0, 360.0, 1.0, "suffix:°") var arc_degrees: float = 80.0
## Also draw an exclamation mark above the head.
@export var exclamation: bool = false
## Windup sounds: entries [file in frontend/audio/sfx, pitch_jitter, volume_db, pitch].
@export var windup_sounds: Array = []
