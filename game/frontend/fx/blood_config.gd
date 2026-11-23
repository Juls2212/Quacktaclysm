class_name BloodConfig
extends Resource
## Every number of the stylized combat blood (Phase 15k): how many droplets a hit, a kill, a boss hit and a boss defeat throw, the
## smaller share of a duckling and of the reduced mode, the hard caps on droplets and floor stains, how long a stain lasts and how
## opaque it is, and the colors (semi-transparent dark red with a dark outline). Data only: BloodFx reads it and phase15k_smoke_test
## checks the caps, the fade and the contrast of every warning over a stained floor.

const DEFAULT_PATH: String = "res://frontend/fx/default_blood_config.tres"

@export_group("Amounts")
@export_range(0, 60, 1) var hit_droplets: int = 6
@export_range(0, 120, 1) var kill_droplets: int = 22
@export_range(0, 60, 1) var boss_hit_droplets: int = 10
@export_range(0, 200, 1) var boss_defeat_droplets: int = 60
@export_range(0, 60, 1) var player_hit_droplets: int = 5
@export_range(0, 60, 1) var player_death_droplets: int = 8
## Share of a duckling (it bleeds less) and of the reduced mode («Efectos de corrupción» off keeps blood with fewer droplets).
@export_range(0.0, 1.0, 0.05) var duckling_scale: float = 0.5
@export_range(0.1, 1.0, 0.05) var reduced_scale: float = 0.5

@export_group("Caps and fade")
@export_range(10, 600, 1) var max_droplets: int = 140
@export_range(1, 200, 1) var max_stains: int = 36
@export_range(1.0, 60.0, 0.5, "suffix:s") var stain_fade_seconds: float = 8.0
@export_range(0.05, 1.0, 0.01) var stain_opacity: float = 0.45

@export_group("Droplets")
@export_range(10.0, 800.0, 1.0, "suffix:px/s") var speed_min: float = 110.0
@export_range(10.0, 800.0, 1.0, "suffix:px/s") var speed_max: float = 330.0
@export_range(0.0, 3.0, 0.05, "suffix:rad") var spread: float = 0.7
@export_range(0.0, 3000.0, 10.0, "suffix:px/s²") var gravity: float = 950.0
@export_range(0.1, 3.0, 0.05, "suffix:s") var life_min: float = 0.5
@export_range(0.1, 3.0, 0.05, "suffix:s") var life_max: float = 0.9
@export_range(0.5, 10.0, 0.1, "suffix:px") var size_min: float = 2.0
@export_range(0.5, 10.0, 0.1, "suffix:px") var size_max: float = 4.2

@export_group("Colors")
@export var blood_color: Color = Color(0.55, 0.04, 0.06, 0.85)
@export var outline_color: Color = Color(0.12, 0.02, 0.03, 0.9)


static func get_default() -> BloodConfig:
	return load(DEFAULT_PATH) as BloodConfig
