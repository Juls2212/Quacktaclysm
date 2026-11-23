class_name AbsorptionConfig
extends Resource
## Every number of the absorption sequence that plays when the player KEEPS a fragment (Phase 15o, restoring the dark background with RED touches and the
## emblem at the bottom and adding much more animation): how long it lasts, the colors, the red lightning, the particles, the emblem, the convulsion,
## the heartbeat and how the music ducks. The photosensitivity limits live here too: no full-screen tint above `flare_cap` opacity and never more than
## `max_flashes_per_second` pulses a second (the heartbeat is the only full-screen pulse; lightning is drawn as thin bolts). Data only.

const DEFAULT_PATH: String = "res://frontend/fx/default_absorption_config.tres"

## Seconds of the sequence before the power card (3 to 4).
@export_range(3.0, 4.0, 0.05, "suffix:s") var length: float = 3.6
@export_group("Colors")
@export var background_color: Color = Color(0.025, 0.006, 0.01)
@export var haze_color: Color = Color(0.5, 0.06, 0.05)
@export var edge_glow_color: Color = Color(0.62, 0.07, 0.05)
@export var ember_color: Color = Color(1.0, 0.3, 0.12)
@export var gem_color: Color = Color(0.75, 0.12, 0.1)
@export var gem_dark_color: Color = Color(0.2, 0.02, 0.03, 0.85)
@export var tendril_color: Color = Color(0.6, 0.08, 0.07)
@export var hero_tint: Color = Color(0.85, 0.55, 0.55)
@export var bolt_color: Color = Color(1.0, 0.18, 0.12)
@export var bolt_core_color: Color = Color(1.0, 0.82, 0.74)
@export_group("Lightning")
## Bolts alive at once from each source at full strength (they all end in the duck's chest).
@export_range(0, 12, 1) var bolts_from_emblem: int = 3
@export_range(0, 12, 1) var bolts_from_fragment: int = 2
@export_range(0, 12, 1) var bolts_from_edges: int = 4
## Bolts drawn in reduced mode (static, from the emblem).
@export_range(0, 8, 1) var static_bolts: int = 3
@export_range(2.0, 20.0, 0.5, "suffix:Hz") var bolt_refresh_hz: float = 10.0
@export_range(0.5, 6.0, 0.1, "suffix:px") var bolt_width: float = 2.2
@export_range(0.02, 0.4, 0.01) var bolt_jaggedness: float = 0.12
@export_range(0.0, 1.0, 0.05) var bolt_branch_chance: float = 0.6
@export_group("Particles and emblem")
@export_range(0, 200, 1) var particle_count: int = 70
@export_range(0, 120, 1) var edge_ember_count: int = 46
@export_range(1, 10, 1) var tendrils: int = 4
@export_range(40.0, 140.0, 1.0, "suffix:px") var emblem_radius: float = 84.0
## How far above the bottom edge of the screen the middle of the emblem sits.
@export_range(60.0, 240.0, 1.0, "suffix:px") var emblem_lift: float = 128.0
@export_group("Duck")
@export_range(0.0, 20.0, 0.5, "suffix:px") var convulsion_px: float = 7.0
@export_range(0.0, 0.3, 0.01, "suffix:rad") var convulsion_tilt: float = 0.07
@export_group("Heartbeat")
@export_range(0.4, 2.0, 0.05, "suffix:Hz") var heartbeat_hz: float = 1.1
@export_range(0.05, 0.5, 0.01, "suffix:s") var second_thump_delay: float = 0.2
@export var heartbeat_event: StringName = &"projectile_impact_world"
@export_range(0.3, 1.2, 0.01) var heartbeat_pitch: float = 0.35
@export_range(-24.0, 6.0, 0.5, "suffix:dB") var heartbeat_db: float = -2.0
@export_range(-30.0, 0.0, 0.5, "suffix:dB") var music_duck_db: float = -10.0
## Fragments after which NO power card opens: the sequence goes straight on (the last boss: the game ends right after).
@export var no_card_fragments: PackedStringArray = PackedStringArray(["fragment_level_3"])
@export_group("Limits")
@export_range(0.0, 0.3, 0.01) var flare_cap: float = 0.28
@export_range(1, 3, 1) var max_flashes_per_second: int = 3
@export_range(0.1, 1.0, 0.05, "suffix:s") var reduced_fade: float = 0.5


static func get_default() -> AbsorptionConfig:
	return load(DEFAULT_PATH) as AbsorptionConfig
