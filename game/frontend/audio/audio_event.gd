class_name AudioEvent
extends Resource
## One sound event of the game: which file(s) it plays and how loud, how high, how often. Edited in
## default_audio_events.tres, so sounds can be retuned or replaced without touching code.

@export var id: StringName = &""
## Files in frontend/audio/sfx (with extension, e.g. "swords/clash_3.ogg"). One is picked at random.
@export var files: Array[String] = []
## Volume relative to AudioDirector.SFX_DB (negative = quieter).
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var volume_db: float = -8.0
@export_range(0.25, 4.0, 0.01) var pitch_min: float = 1.0
@export_range(0.25, 4.0, 0.01) var pitch_max: float = 1.0
## Seconds before the same event may play again (high-frequency sounds need it).
@export_range(0.0, 10.0, 0.01, "suffix:s") var cooldown: float = 0.0
## How many copies of this event may sound at once.
@export_range(1, 8, 1) var max_voices: int = 1
@export_multiline var note: String = ""


## A random file of the event ("" if it has none).
func pick_file(rng: RandomNumberGenerator) -> String:
	if files.is_empty():
		return ""
	return files[rng.randi_range(0, files.size() - 1)]
