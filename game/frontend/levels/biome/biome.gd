@tool
class_name Biome
extends Resource
## Look of a level: sky, the parallax layers behind the play field, the ground skin and the
## floating particles. Visual only. Each level picks one (LevelBase.biome); a BiomeZone can swap
## the backdrop to another one halfway through a level.
## Layers fade toward `haze` with distance, the way smog flattens far shapes.

enum Kind { MEADOW, FOREST, SWAMP, STORM, RUINED_CITY, FLOODED_SUBURB, INDUSTRIAL }
enum Particles { NONE, POLLEN, LEAVES, FIREFLIES, RAIN, ASH, FEATHERS, EMBERS, EYES }

@export var kind: Kind = Kind.MEADOW
## Seed for the scenery shapes (trees, ruins, rocks, tufts). Change it to reshuffle a biome.
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
## 0..1: flat bands of dirty smog drifting across the sky.
@export_range(0.0, 1.0, 0.01) var smog: float = 0.0

@export_group("Layers")
@export var far_color: Color = Color(0.73, 0.81, 0.79)
@export var mid_color: Color = Color(0.5, 0.68, 0.58)
@export var near_color: Color = Color(0.31, 0.54, 0.42)
## Silhouettes in front of the play field (kept to the screen edges).
@export var foreground_color: Color = Color(0.12, 0.23, 0.19)
## 0..1: how much each layer melts into the haze (far, mid, near).
@export var haze_amount: Vector3 = Vector3(0.55, 0.3, 0.12)
## 0..1: darkens the layers behind the play field so players, enemies and platforms stand out.
@export_range(0.0, 1.0, 0.01) var backdrop_dim: float = 0.0
## 0..1: pulls the layers behind the play field toward gray (stronger the farther they are).
@export_range(0.0, 1.0, 0.01) var backdrop_desaturation: float = 0.0

@export_group("Ground")
@export var grass: Color = Color(0.49, 0.76, 0.35)
@export var grass_dark: Color = Color(0.3, 0.58, 0.25)
@export var soil: Color = Color(0.6, 0.42, 0.27)
@export var soil_dark: Color = Color(0.37, 0.25, 0.17)
@export var rock: Color = Color(0.64, 0.61, 0.57)
@export var rock_dark: Color = Color(0.43, 0.4, 0.37)
## Flowers, berries, glowing shards: small spots of accent on the ground.
@export var accent: Color = Color(0.96, 0.83, 0.29)
## Parched look: cracks in the earth, withered drooping tufts, shards of fallen stars for flowers.
@export var dry_ground: bool = false
## 0..1: bricks, concrete chunks and junk lying on the walkable tops and buried in the soil.
@export_range(0.0, 1.0, 0.01) var rubble: float = 0.0

@export_group("Particles")
@export var particles: Particles = Particles.POLLEN
@export var particle_color: Color = Color(1.0, 0.96, 0.78)
@export_range(0, 200, 1) var particle_count: int = 40

## Optional scenery and effects of the fallen-star world. All of them start switched off.
@export_group("Apocalypse extras")
## Corrupted stars streaking down the sky with a glowing trail.
@export var falling_stars: bool = false
## Streaks per second (on average).
@export_range(0.05, 6.0, 0.05) var falling_star_rate: float = 0.5
## Color of the corrupted stars (falling ones, the omen star, the sky cracks).
@export var star_color: Color = Color(1.0, 0.36, 0.16)
## One red star hanging in the sky, far too bright: the omen.
@export var omen_star: bool = false
@export var omen_star_position: Vector2 = Vector2(0.3, 0.16)
## Glowing fractures across the sky where time broke.
@export var sky_cracks: bool = false
## The moon (the sun disc) drawn split in pieces.
@export var broken_moon: bool = false
## Broken concrete buildings with empty windows on the far layers.
@export var ruin_silhouettes: bool = false
## Bare dead trees on the middle layer.
@export var dead_trees: bool = false
## Pairs of eyes blinking in the dark of the background.
@export var blinking_eyes: bool = false
@export var eye_color: Color = Color(1.0, 0.86, 0.3)
## Thick columns of smoke rising behind the ruins.
@export var smoke_columns: bool = false
@export var smoke_color: Color = Color(0.25, 0.23, 0.2)
## Extra flakes of ash in the air (on top of `particles`).
@export var ash: bool = false
@export var ash_color: Color = Color(0.62, 0.6, 0.56)
## Extra feathers drifting down like leaves (on top of `particles`).
@export var feathers: bool = false
@export var feather_color: Color = Color(0.86, 0.82, 0.72)
## Dark vignette on the screen edges.
@export var vignette: bool = false
@export_range(0.0, 1.0, 0.01) var vignette_strength: float = 0.55
