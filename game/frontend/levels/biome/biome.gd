@tool
class_name Biome
extends Resource
## Look of a level: sky, the parallax layers behind the play field, the ground skin and the
## floating particles. Visual only. Each level picks one (LevelBase.biome).
## Layers fade toward `haze` with distance, the way air flattens far shapes.

enum Kind { MEADOW, FOREST, SWAMP, STORM }
enum Particles { NONE, POLLEN, LEAVES, FIREFLIES, RAIN }

@export var kind: Kind = Kind.MEADOW
## Seed for the scenery shapes (trees, rocks, tufts). Change it to reshuffle a biome.
@export var scenery_seed: int = 1

@export_group("Sky")
@export var sky_top: Color = Color(0.56, 0.79, 0.85)
@export var sky_bottom: Color = Color(0.96, 0.89, 0.72)
## Horizon glow and the color distant layers dissolve into.
@export var haze: Color = Color(0.97, 0.92, 0.82)
@export var sun: Color = Color(1.0, 0.95, 0.75)
## Where the sun or moon sits on screen, 0..1 (also the origin of the light shafts).
@export var sun_position: Vector2 = Vector2(0.78, 0.22)
@export var light_shafts: bool = true
## Storm biomes flash the sky now and then.
@export var lightning: bool = false

@export_group("Layers")
@export var far_color: Color = Color(0.73, 0.81, 0.79)
@export var mid_color: Color = Color(0.5, 0.68, 0.58)
@export var near_color: Color = Color(0.31, 0.54, 0.42)
## Silhouettes in front of the play field (kept to the screen edges).
@export var foreground_color: Color = Color(0.12, 0.23, 0.19)
## 0..1: how much each layer melts into the haze (far, mid, near).
@export var haze_amount: Vector3 = Vector3(0.55, 0.3, 0.12)

@export_group("Ground")
@export var grass: Color = Color(0.49, 0.76, 0.35)
@export var grass_dark: Color = Color(0.3, 0.58, 0.25)
@export var soil: Color = Color(0.6, 0.42, 0.27)
@export var soil_dark: Color = Color(0.37, 0.25, 0.17)
@export var rock: Color = Color(0.64, 0.61, 0.57)
@export var rock_dark: Color = Color(0.43, 0.4, 0.37)
## Flowers, berries, glowing mushrooms: small spots of accent on the ground.
@export var accent: Color = Color(0.96, 0.83, 0.29)

@export_group("Particles")
@export var particles: Particles = Particles.POLLEN
@export var particle_color: Color = Color(1.0, 0.96, 0.78)
@export_range(0, 200, 1) var particle_count: int = 40
