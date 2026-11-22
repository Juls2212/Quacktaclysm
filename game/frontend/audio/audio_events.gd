class_name AudioEvents
extends Resource
## The audio table of Phase 14f (default_audio_events.tres): every added sound event, the music of
## each boss and how much the music ducks while somebody talks. `events` is an untyped Array on
## purpose (typed arrays of script classes make Godot leak at exit). Windup sounds live in the
## telegraph styles (default_telegraphs.tres); the older sounds are still wired in audio_director.gd.

const DEFAULT_PATH: String = "res://frontend/audio/default_audio_events.tres"
## Every event a level may fire (the tests check each one has an entry).
const EVENT_IDS: Array[StringName] = [
	&"footstep", &"exorcism", &"boss_vs_sting", &"title_card", &"transition", &"portal_lit", &"portal_enter",
	&"projectile_impact_world", &"projectile_impact_player", &"projectile_impact_enemy",
	&"wave_impact", &"wave_impact_world", &"game_over",
	&"soul_gain", &"focus_start", &"heal_done", &"heal_denied", &"soul_full",
	&"pad_bounce", &"double_jump", &"spike_warning", &"spike_rise", &"boss_leap", &"leap_land",
	&"possession_start", &"possession_roar", &"possession_slam",
]

@export var events: Array = []
## Level number -> [music file in frontend/audio/music, pitch multiplier of that track].
@export var boss_music: Dictionary = {}
@export_group("Music ducking")
## Music volume drop (dB, negative) while a guardian speaks, a story scene plays or the boss presentation runs.
@export_range(-24.0, 0.0, 0.5, "suffix:dB") var duck_dialogue_db: float = -6.0
@export_range(-24.0, 0.0, 0.5, "suffix:dB") var duck_story_db: float = -8.0
@export_range(-24.0, 0.0, 0.5, "suffix:dB") var duck_presentation_db: float = -8.0
@export_range(0.05, 2.0, 0.05, "suffix:s") var duck_fade: float = 0.3


static func get_default() -> AudioEvents:
	return load(DEFAULT_PATH) as AudioEvents


func get_event(event_id: StringName) -> AudioEvent:
	for entry: Variant in events:
		var event := entry as AudioEvent
		if event != null and event.id == event_id:
			return event
	return null


## [file, pitch] of the boss of `level`, or an empty array.
func get_boss_music(level: int) -> Array:
	var entry: Variant = boss_music.get(level, [])
	return entry as Array if entry is Array else []
