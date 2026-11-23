class_name TutorialConfig
extends Resource
## The numbers of the tutorial (Phase 15m): when the dummy comes back, how long the skip hold takes, how far "move" asks the player to go and
## how often the dummy speaks. Data only.

const DEFAULT_PATH: String = "res://backend/progression/default_tutorial_config.tres"

## The dummy never stays dead: it respawns this long after dying.
@export_range(0.2, 5.0, 0.1, "suffix:s") var respawn_seconds: float = 1.0
## Holding the confirm action this long opens the gate at any time (for returning players).
@export_range(0.5, 6.0, 0.1, "suffix:s") var skip_hold_seconds: float = 2.0
@export_range(20.0, 600.0, 10.0, "suffix:px") var move_distance: float = 150.0
@export_range(0.2, 3.0, 0.1, "suffix:s") var feedback_time: float = 0.8
@export_range(0.5, 8.0, 0.1, "suffix:s") var speech_seconds: float = 2.6
## The dummy does not comment on hits more often than this.
@export_range(0.5, 10.0, 0.1, "suffix:s") var hit_line_interval: float = 2.5
## The dummy encourages the player after this long without progress.
@export_range(4.0, 60.0, 1.0, "suffix:s") var idle_line_after: float = 14.0
## A player teleport (a respawn) bigger than this many pixels in one physics frame is not walking.
@export_range(20.0, 400.0, 5.0, "suffix:px") var max_step_px: float = 60.0


static func get_default() -> TutorialConfig:
	return load(DEFAULT_PATH) as TutorialConfig
