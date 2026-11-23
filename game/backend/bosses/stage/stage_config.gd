class_name StageConfig
extends Resource
## Every number of boss 3's stage (Phase 15j): the platforms and the perch, the summon waves, the collapse and the barrage, the
## vulnerable window and the red eye. Data only: BossStage, PlatformBarrage, StormEye and SummonerCyclePattern read it and
## phase15j_smoke_test checks it against the real player's numbers (the platform chain by single jumps, the barrage and bolt margins).

const DEFAULT_PATH: String = "res://backend/bosses/stage/default_stage_config.tres"

@export_group("Platforms")
## Heights of the four player platforms above the floor surface (px), lowest first. Each step is a single jump (the jump rises
## 106.8 px, so a step of 62 px leaves a wide margin) and the highest leaves room under the arena ceiling.
@export var platform_heights: PackedFloat32Array = PackedFloat32Array([62.0, 124.0, 186.0, 248.0])
## Center of each platform relative to the arena center (px): at least 150 px between neighbours, edges overlapping a little.
@export var platform_offsets: PackedFloat32Array = PackedFloat32Array([-225.0, -75.0, 75.0, 225.0])
@export_range(80.0, 400.0, 1.0, "suffix:px") var platform_width: float = 150.0
@export_range(8.0, 60.0, 1.0, "suffix:px") var platform_thickness: float = 24.0
## The perch above them where only the boss stands (the player passes through it).
@export_range(100.0, 440.0, 1.0, "suffix:px") var perch_height: float = 310.0
@export_range(60.0, 400.0, 1.0, "suffix:px") var perch_width: float = 170.0
@export_range(-600.0, 600.0, 1.0, "suffix:px") var perch_offset: float = 0.0
@export_range(0.2, 4.0, 0.05, "suffix:s") var rise_time: float = 1.2
@export_range(0.2, 4.0, 0.05, "suffix:s") var sink_time: float = 1.0
@export_range(20.0, 400.0, 1.0, "suffix:px") var rise_depth: float = 150.0
## The platforms' look (the same terrain skin as the level's platforms).
@export var platform_color: Color = Color(0.3, 0.3, 0.3, 1.0)
@export var platform_skin: int = 14

@export_group("Summoning")
@export_range(1, 6, 1) var batch_size: int = 2
@export_range(0.5, 10.0, 0.1, "suffix:s") var batch_interval: float = 2.5
## The boss waits this long on the perch before the first batch.
@export_range(0.0, 5.0, 0.1, "suffix:s") var first_batch_delay: float = 0.8
@export_range(1, 12, 1) var wave_size: int = 6
@export_range(1, 12, 1) var max_alive: int = 6
@export_range(0, 99, 1) var duckling_soul_gain: int = 5
## A duckling that falls under this much below the floor is removed (counted as dead, no soul).
@export_range(0.0, 1000.0, 10.0, "suffix:px") var duckling_fall_limit: float = 200.0
@export_range(0.0, 600.0, 10.0, "suffix:px") var spawn_edge_margin: float = 70.0
@export_range(0.0, 600.0, 10.0, "suffix:px") var spawn_clear_of_player: float = 140.0
@export_range(0.1, 3.0, 0.05, "suffix:s") var spawn_puff_time: float = 0.5

@export_group("Collapse")
@export_range(0.2, 5.0, 0.1, "suffix:s") var tremble_time: float = 1.5
@export_range(0.1, 3.0, 0.05, "suffix:s") var crumble_time: float = 0.7
## How long the projectiles keep crossing while the floor is gone.
@export_range(1.0, 15.0, 0.1, "suffix:s") var barrage_time: float = 5.0
@export_range(0.2, 3.0, 0.05, "suffix:s") var shimmer_time: float = 1.0
## How long the boss takes to leap up to where it hovers, and how high above the floor it hovers.
@export_range(0.2, 3.0, 0.05, "suffix:s") var leap_up_time: float = 0.6
@export_range(100.0, 440.0, 1.0, "suffix:px") var aloft_height: float = 280.0
## The boss hovers this far to one side of the arena center, over the bare floor (the platforms cover the middle), so it lands on the floor.
@export_range(0.0, 600.0, 1.0, "suffix:px") var aloft_offset: float = 400.0
@export_range(0.1, 3.0, 0.05, "suffix:s") var land_time: float = 0.5
@export_range(0.2, 3.0, 0.05, "suffix:s") var perch_leap_time: float = 0.9
@export_range(0.0, 400.0, 1.0, "suffix:px") var perch_leap_arc: float = 140.0
## The void below the floor while it is gone: a soft hazard.
@export_range(0, 3, 1) var void_damage: int = 1
@export_range(0.2, 5.0, 0.1, "suffix:s") var void_invulnerability: float = 1.5
@export_range(20.0, 600.0, 10.0, "suffix:px") var void_depth: float = 90.0

@export_group("Vulnerable window")
@export_range(4.0, 8.0, 0.1, "suffix:s") var window_seconds: float = 6.0
@export_range(1.0, 10.0, 0.1, "suffix:s") var window_min: float = 4.0
@export_range(1.0, 12.0, 0.1, "suffix:s") var window_max: float = 8.0

@export_group("Barrage")
## Seconds a lane marker shows before its projectile crosses.
@export_range(0.3, 3.0, 0.05, "suffix:s") var lane_telegraph: float = 0.8
## Seconds between two lane starts.
@export_range(0.3, 3.0, 0.05, "suffix:s") var lane_gap: float = 0.9
@export_range(1, 12, 1) var lane_events: int = 5
## The worst case to reach a safe spot must leave at least this much of the telegraph.
@export_range(0.0, 1.0, 0.05, "suffix:s") var safe_margin: float = 0.3
## Height of the projectile above the platform top (a standing duck's torso).
@export_range(0.0, 80.0, 1.0, "suffix:px") var lane_torso: float = 28.0
@export var barrage_projectile_scene: PackedScene = null
@export var barrage_projectile_stats: ProjectileStats = null

@export_group("Red eye")
## Where the eye hangs, above the arena center (px over the floor) and how big it is.
@export_range(100.0, 600.0, 1.0, "suffix:px") var eye_height: float = 340.0
@export_range(40.0, 300.0, 1.0, "suffix:px") var eye_radius: float = 120.0
@export_range(0.2, 5.0, 0.1, "suffix:s") var eye_appear_time: float = 1.5
@export_range(0.5, 5.0, 0.1, "suffix:s") var bolt_telegraph: float = 1.0
@export_range(0.1, 2.0, 0.05, "suffix:s") var bolt_active: float = 0.4
## Seconds from the end of one volley to the start of the next telegraph.
@export_range(0.2, 6.0, 0.1, "suffix:s") var bolt_rest: float = 1.2
@export_range(0, 8, 1) var vertical_bolts: int = 2
@export_range(0, 8, 1) var radial_bolts: int = 2
@export_range(10.0, 120.0, 1.0, "suffix:px") var bolt_width: float = 44.0
@export_range(80.0, 400.0, 1.0, "suffix:px") var min_lane_width: float = 130.0
@export_range(0.0, 400.0, 1.0, "suffix:px") var max_lane_offset: float = 110.0
@export_range(1, 3, 1) var bolt_damage: int = 1
@export var bolt_knockback: Vector2 = Vector2(220.0, -300.0)


static func get_default() -> StageConfig:
	return load(DEFAULT_PATH) as StageConfig
