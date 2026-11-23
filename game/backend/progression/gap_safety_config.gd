class_name GapSafetyConfig
extends Resource
## The numbers of the gap rules of level 3 (Phase 15h-bis): how far ground enemies keep from a floor edge, the tolerance every gap
## must give a real player, and the stuck-player assist. Data only; GapGuard applies it and phase15h2_smoke_test measures it.

const DEFAULT_PATH: String = "res://backend/progression/default_gap_safety_config.tres"

@export_group("Enemies at the edges")
## Ground enemies never walk closer than this to a missing floor (their ledge probe looks this far ahead), so none can reach or push
## a player standing on the last pixels of a floor. Placed enemies also keep this distance from every gap edge.
@export_range(0.0, 600.0, 10.0, "suffix:px") var enemy_edge_keepout: float = 250.0
## Only enemies standing at least this low (y) get the keep-out: the ones on raised platforms have their own short floors.
@export_range(0.0, 2000.0, 10.0, "suffix:px") var ground_enemy_min_y: float = 560.0

@export_group("Tolerance targets")
## Per gap: the width of the timing window of the second action (the three-action chain from gap 2 on), in seconds.
@export var target_timing_seconds: PackedFloat32Array = PackedFloat32Array([0.15, 0.10, 0.06])
## Per gap: the width of the takeoff-position window, in px (0 = measured and printed, not required).
@export var target_offset_px: PackedFloat32Array = PackedFloat32Array([20.0, 0.0, 0.0])
## The first gap is never narrower than this (the single jump reaches less than that).
@export_range(100.0, 600.0, 1.0, "suffix:px") var gap_one_min_width: float = 290.0

@export_group("Stuck-player assist")
## Falls into the same gap in a session that make a wreck platform appear in the middle of it.
@export_range(1, 20, 1) var assist_falls: int = 4
@export_range(40.0, 400.0, 1.0, "suffix:px") var assist_width: float = 140.0
@export_range(8.0, 80.0, 1.0, "suffix:px") var assist_thickness: float = 24.0
## World y of the top of the wreck platform (the floor height).
@export_range(0.0, 2000.0, 1.0, "suffix:px") var assist_top_y: float = 600.0
@export var assist_color: Color = Color(0.3, 0.3, 0.3, 1.0)
@export var assist_skin: int = 15
## A death below this y counts as a fall (the kill zone is far under it).
@export_range(0.0, 3000.0, 10.0, "suffix:px") var fall_y: float = 800.0


static func get_default() -> GapSafetyConfig:
	return load(DEFAULT_PATH) as GapSafetyConfig
