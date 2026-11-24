class_name EndingCreditsConfig
extends Resource
## Numbers of the credits and statistics sequence at the end of both endings (Phase 15t): how long the veil takes to clear into the night
## sky, how fast the credits roll, how the statistics appear and count, how many stars rise, the colors of each sky and how quiet the music sits.
## default_ending_credits_config.tres holds the values; nothing here moves faster than a slow drift (no flashes).

const DEFAULT_PATH: String = "res://frontend/story/default_ending_credits_config.tres"

@export_group("Sequence")
## Seconds the white (or black after a skip) veil takes to clear into the night sky.
@export_range(1.0, 10.0, 0.1, "suffix:s") var veil_seconds: float = 4.0
## Seconds before the credits start rolling once the veil begins to clear.
@export_range(0.0, 6.0, 0.1, "suffix:s") var credits_lead_seconds: float = 2.0
## Seconds of calm sky after the last credit has gone by.
@export_range(0.0, 6.0, 0.1, "suffix:s") var credits_tail_seconds: float = 1.5
## Reduced mode: seconds each static credits page stays (a press of the confirm action moves on sooner).
@export_range(1.0, 15.0, 0.5, "suffix:s") var page_seconds: float = 5.0
@export_range(0.1, 3.0, 0.05, "suffix:s") var closing_fade_seconds: float = 1.2
@export_range(0.1, 2.0, 0.05, "suffix:s") var skip_fade_seconds: float = 0.4
@export_range(0.0, 2.0, 0.05, "suffix:s") var input_grace: float = 0.5
@export_range(0.3, 5.0, 0.1, "suffix:s") var hold_seconds: float = 1.2
@export_group("Statistics")
@export_range(0.1, 3.0, 0.05, "suffix:s") var stat_fade_seconds: float = 0.9
@export_range(0.0, 3.0, 0.05, "suffix:s") var stat_gap_seconds: float = 0.7
## Seconds a counter takes to count up from 0 to its value.
@export_range(0.2, 4.0, 0.05, "suffix:s") var count_seconds: float = 1.4
## Seconds the finished summary card stays before the final card (a press of the confirm action moves on sooner).
@export_range(1.0, 20.0, 0.5, "suffix:s") var stats_hold_seconds: float = 6.0
@export_group("Sky")
@export_range(10.0, 60.0, 1.0, "suffix:Hz") var redraw_hz: float = 30.0
@export var kept_sky_top: Color = Color(0.03, 0.04, 0.1)
@export var kept_sky_bottom: Color = Color(0.2, 0.15, 0.24)
@export var released_sky_top: Color = Color(0.03, 0.05, 0.09)
@export var released_sky_bottom: Color = Color(0.11, 0.14, 0.2)
## Kept: stars that rise from the freed city (count, pixels per second range, how large).
@export_range(0, 200, 1) var rising_star_count: int = 70
@export_range(2.0, 60.0, 1.0, "suffix:px/s") var rising_speed_min: float = 7.0
@export_range(2.0, 60.0, 1.0, "suffix:px/s") var rising_speed_max: float = 20.0
@export_range(0.5, 6.0, 0.1, "suffix:px") var star_size: float = 2.2
## Kept: the city silhouette drifts slowly (pixels per second of the far and of the near layer).
@export_range(0.0, 30.0, 0.5, "suffix:px/s") var city_far_speed: float = 4.0
@export_range(0.0, 30.0, 0.5, "suffix:px/s") var city_near_speed: float = 9.0
## Cliff: a few distant stars that barely twinkle and a thin mist (pixels per second, opacity).
@export_range(0, 60, 1) var still_star_count: int = 14
@export_range(0.0, 20.0, 0.5, "suffix:px/s") var mist_speed: float = 5.0
@export_range(0.0, 0.3, 0.005) var mist_alpha: float = 0.07
## Twinkle depth of the distant stars (0 to 0.5) and its slow rate.
@export_range(0.0, 0.5, 0.01) var twinkle_depth: float = 0.18
@export_range(0.02, 0.5, 0.01, "suffix:Hz") var twinkle_hz: float = 0.12
@export_group("Music")
## Level of the ending's music under the credits (dB relative to the music bus, negative) and the seconds it takes to come up (a slow fade, never a swell).
@export_range(-40.0, 0.0, 0.5, "suffix:dB") var kept_music_db: float = -12.0
@export_range(-40.0, 0.0, 0.5, "suffix:dB") var released_music_db: float = -20.0
@export_range(2.0, 20.0, 0.5, "suffix:s") var music_fade_seconds: float = 9.0


static func get_default() -> EndingCreditsConfig:
	return load(DEFAULT_PATH) as EndingCreditsConfig
