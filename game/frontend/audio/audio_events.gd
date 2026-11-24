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
	&"possession_start", &"possession_roar", &"possession_slam", &"grandfather_voice",
	&"duck_cry_weak", &"duck_cry_pain", &"duck_cry_resist", &"duck_cry_lonely",
]

@export var events: Array = []
## The music of each ending, processed by code and replaceable by real files (Phase 15i-bis).
@export var ending_kept_music: EndingMusicSlot = null
@export var ending_released_music: EndingMusicSlot = null
## Level number -> [music file in frontend/audio/music, pitch multiplier of that track].
@export var boss_music: Dictionary = {}
@export_group("Ambient (Phase 15t)")
## The ambient sounds (AmbientSlot): untyped on purpose, like `events`. Change one slot's `file` to swap its sound.
@export var ambient_slots: Array = []
@export_group("Cries on hits (Phase 15n)")
## Every hit that LANDS on a duck enemy makes one of these cries (files of frontend/audio/sfx/ducks); blocked hits make none.
@export var hit_cry_files: PackedStringArray = PackedStringArray(["quack_hurt.wav", "quack_1.wav", "quack_2.wav", "quack_3.wav"])
@export var boss_cry_files: PackedStringArray = PackedStringArray(["quack_boss.wav", "quack_boss.wav", "quack_hurt.wav"])
@export_range(0.0, 3.0, 0.05, "suffix:s") var hit_cry_target_cooldown: float = 0.35
@export_range(1, 20, 1) var hit_cry_global_per_second: int = 4
@export_range(-30.0, 6.0, 0.5, "suffix:dB") var hit_cry_volume_db: float = -5.0
@export_range(-30.0, 6.0, 0.5, "suffix:dB") var boss_cry_volume_db: float = -3.0
@export_range(0.3, 2.0, 0.01) var hit_cry_pitch_min: float = 0.85
@export_range(0.3, 2.0, 0.01) var hit_cry_pitch_max: float = 1.15
@export_range(0.5, 2.0, 0.01) var duckling_pitch_factor: float = 1.3
@export_range(0.5, 2.0, 0.01) var boss_pitch_factor: float = 0.85
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


## The ambient slot with this id, or null.
func get_ambient(ambient_id: StringName) -> AmbientSlot:
	for entry: Variant in ambient_slots:
		var slot := entry as AmbientSlot
		if slot != null and slot.id == ambient_id:
			return slot
	return null
