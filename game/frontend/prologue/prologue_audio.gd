class_name PrologueAudio
extends Resource
## The sound of the story prologue (Phase 15n), all from existing files: an existing music track, processed by code (lower pitch, low-pass,
## ducked), and effects for the key beats taken from the audio table (the falling star, the impacts, wind, the cave). Data only:
## PrologueCutscene plays it, obeying the music and sfx settings, and stops it cleanly on skip, pause and exit.

const DEFAULT_PATH: String = "res://frontend/prologue/default_prologue_audio.tres"

@export var music_file: String = "the_evil_one.ogg"
@export_range(0.5, 1.5, 0.01) var music_pitch: float = 0.8
@export_range(500.0, 20000.0, 50.0, "suffix:Hz") var music_cutoff_hz: float = 2200.0
## How far the music sits under the cinematic (dB, negative).
@export_range(-30.0, 0.0, 0.5, "suffix:dB") var music_duck_db: float = -7.0
## One dictionary per effect: shot (PrologueShots.Shot index), at (seconds into the shot), event (id in the audio table), pitch, db.
@export var effects: Array[Dictionary] = []


static func get_default() -> PrologueAudio:
	return load(DEFAULT_PATH) as PrologueAudio


## The effects of one shot, in time order.
func effects_of(shot: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for effect in effects:
		if int(effect.get("shot", -1)) == shot:
			out.append(effect)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out
