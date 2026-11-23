class_name PossessionConfig
extends Resource
## Every number of the possession sequence that plays when a boss changes phase (Phase 15d), in one editable resource
## (default_possession_config.tres). `overrides` holds optional PossessionOverride entries per boss (an untyped Array on
## purpose: typed arrays of script classes make Godot leak at exit). Presentation only: nothing here changes a gameplay
## value; the boss stays inactive and invulnerable for `duration` seconds.

const DEFAULT_PATH: String = "res://frontend/presentation/default_possession_config.tres"
## The longest and the shortest a sequence may last (the editor range and the clamp of `duration_for`).
const MIN_DURATION: float = 2.5
const MAX_DURATION: float = 4.0
## Photosensitivity: no more than this many flashes in any second, and no flash brighter than the cap.
const MAX_FLASHES_PER_SECOND: int = 3

@export_group("Timing")
## Length of the full sequence (seconds).
@export_range(2.5, 4.0, 0.1, "suffix:s") var duration: float = 3.0
## With the "Efectos de corrupción" option off: a short freeze with the pose change and the sound.
@export_range(0.5, 2.0, 0.1, "suffix:s") var reduced_freeze: float = 1.0
## Seconds the persistent look takes to fade out when the boss dies or the fight is cancelled.
@export_range(0.1, 3.0, 0.1, "suffix:s") var fade_out_time: float = 1.0
@export_group("The boss")
@export var color: Color = Color(0.95, 0.12, 0.08)
## How far the boss lifts off the ground (px) and how long the rise takes.
@export_range(0.0, 120.0, 1.0, "suffix:px") var rise_height: float = 38.0
@export_range(0.2, 3.0, 0.1, "suffix:s") var rise_time: float = 1.2
## Trembling of the boss while it is possessed (px, Hz).
@export_range(0.0, 8.0, 0.1, "suffix:px") var tremble: float = 2.5
@export_range(1.0, 30.0, 0.5, "suffix:Hz") var tremble_hz: float = 22.0
## Glow of the eyes and outline pulses at this rate (kept well under the flash limit).
@export_range(0.2, 2.5, 0.1, "suffix:Hz") var pulse_hz: float = 1.5
## Strength of the persistent red glow after the sequence (0-1).
@export_range(0.0, 1.0, 0.05) var persistent_glow: float = 0.55
@export_group("The world")
## The backdrop is multiplied by this color at the peak (white = unchanged).
@export var sky_tint: Color = Color(1.0, 0.36, 0.32)
## How much of `sky_tint` stays after the sequence (0-1).
@export_range(0.0, 1.0, 0.05) var persistent_sky: float = 0.4
## Red vignette at the peak and after the sequence (0-1), and its pulse rate.
@export_range(0.0, 1.0, 0.05) var vignette_peak: float = 0.55
@export_range(0.0, 1.0, 0.05) var persistent_vignette: float = 0.18
@export_range(0.2, 2.5, 0.1, "suffix:Hz") var vignette_pulse_hz: float = 1.2
@export_group("Shake and flash")
## Camera shake power (kicks at the times in `shake_times`); 0 = none.
@export_range(0.0, 12.0, 0.5) var shake_power: float = 4.0
@export var shake_times: PackedFloat32Array = PackedFloat32Array([0.2, 1.0, 1.9])
## Red light flashes: when they start (seconds into the sequence), how long each lasts, and the alpha cap.
@export var flash_times: PackedFloat32Array = PackedFloat32Array([0.15, 1.7])
@export_range(0.05, 0.6, 0.05, "suffix:s") var flash_length: float = 0.25
@export var flash_color: Color = Color(1.0, 0.2, 0.15)
@export_range(0.0, 0.5, 0.05) var flash_alpha_cap: float = 0.3
@export_group("Per boss")
@export var overrides: Array = []


static func get_default() -> PossessionConfig:
	return load(DEFAULT_PATH) as PossessionConfig


func get_override(boss_id: StringName) -> PossessionOverride:
	for entry: Variant in overrides:
		var override := entry as PossessionOverride
		if override != null and override.boss_id == boss_id:
			return override
	return null


## The length of the full sequence for `boss_id` (its override, else the default), within the allowed range.
func duration_for(boss_id: StringName) -> float:
	var override: PossessionOverride = get_override(boss_id)
	var value: float = override.duration if override != null and override.duration > 0.0 else duration
	return clampf(value, MIN_DURATION, MAX_DURATION)


## The possession color for `boss_id`.
func color_for(boss_id: StringName) -> Color:
	var override: PossessionOverride = get_override(boss_id)
	if override != null and override.color.a > 0.001:
		return Color(override.color, 1.0)
	return Color(color, 1.0)


## The most flashes that fall inside any one second of the sequence (the photosensitivity test reads it).
func max_flashes_in_a_second() -> int:
	var worst: int = 0
	for i in flash_times.size():
		var count: int = 0
		for time in flash_times:
			if time >= flash_times[i] and time < flash_times[i] + 1.0:
				count += 1
		worst = maxi(worst, count)
	return worst
