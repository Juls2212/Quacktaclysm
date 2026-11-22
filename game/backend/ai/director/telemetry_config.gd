class_name TelemetryConfig
extends Resource
## Every number of the local AI Director (Phase 16a): the low / mid / high thresholds of the telemetry, the theme rules, the
## behavior of the planner and the caps of a plan. Default instance: res://backend/ai/director/default_telemetry_config.tres.

const DEFAULT_PATH: String = "res://backend/ai/director/default_telemetry_config.tres"

const LOW: String = "low"
const MID: String = "mid"
const HIGH: String = "high"

@export_group("Telemetry")
## Metric -> Vector2(mid_from, high_from): below x is low, from x up to y is mid, from y up is high.
@export var thresholds: Dictionary = {}
## The player counts as "low on hearts" at or below this many hearts (time spent there is measured).
@export_range(1, 20, 1) var low_health_hearts: int = 3

@export_group("Themes")
@export var themes: PackedStringArray = PackedStringArray(["calma", "paciencia", "distancia", "ritmo", "recursos", "valor", "equilibrio"])
@export var default_theme: String = "equilibrio"
@export var theme_rules: Array[ThemeRule] = []

@export_group("Planner")
## The Director is active from this level on (level 1 and loads without telemetry use the neutral plan).
@export_range(1, 3, 1) var active_from_level: int = 2
@export_range(-5, 0, 1) var struggle_delta_mid: int = -1
@export_range(-5, 0, 1) var struggle_delta_high: int = -2
@export_range(0.1, 1.0, 0.05) var struggle_weight_mid: float = 0.8
@export_range(0.1, 1.0, 0.05) var struggle_weight_high: float = 0.6
@export_range(0, 5, 1) var comfort_delta: int = 1
@export_range(1.0, 3.0, 0.05) var comfort_weight: float = 1.4
@export_range(0, 2, 1) var epilogue_neutral: int = 0
@export_range(0, 2, 1) var epilogue_comfortable: int = 1
@export_range(0, 2, 1) var epilogue_struggle: int = 2

@export_group("Plan caps")
@export_range(-5, 0, 1) var extras_delta_min: int = -2
@export_range(0, 5, 1) var extras_delta_max: int = 1
## The final number of extra enemies of a level (profile extras + plan delta) is clamped to 0..this.
@export_range(0, 9, 1) var extras_total_cap: int = 3
@export_range(0.1, 1.0, 0.05) var weight_min: float = 0.6
@export_range(1.0, 3.0, 0.05) var weight_max: float = 1.5
@export_range(0, 2, 1) var epilogue_max: int = 2
## Keys that make the whole plan rejected when present (a plan can never carry them).
@export var forbidden_keys: PackedStringArray = PackedStringArray(["profile", "adaptive_profile", "boss_hp", "max_health", "hp", "damage", "aggression", "boss_aggression", "cooldown", "cooldowns", "telegraph", "telegraph_time"])

@export_group("Remote plan (Phase 16b)")
## Level -> boss scene, to learn the rotation pattern ids a remote plan may weight before that level is loaded.
@export var boss_scenes: Dictionary = {}

@export_group("Extra enemy slots")
## An extra enemy ADDED by a plan never stands within this many px of the edge of a floor gap.
@export_range(0.0, 1000.0, 10.0, "suffix:px") var slot_min_gap_edge_distance: float = 150.0
## A hole between two floors counts as a gap from this width on.
@export_range(1.0, 500.0, 1.0, "suffix:px") var gap_min_width: float = 40.0


static func get_default() -> TelemetryConfig:
	var config := load(DEFAULT_PATH) as TelemetryConfig
	return config if config != null else TelemetryConfig.new()


## low / mid / high of a metric value; a metric without thresholds is always low.
func categorize(metric: String, value: float) -> String:
	var limits: Variant = thresholds.get(metric)
	if not limits is Vector2:
		return LOW
	var pair: Vector2 = limits
	if value >= pair.y:
		return HIGH
	if value >= pair.x:
		return MID
	return LOW
