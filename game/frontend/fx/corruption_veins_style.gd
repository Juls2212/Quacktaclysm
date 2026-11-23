class_name CorruptionVeinsStyle
extends Resource
## Every number of the purple corruption veins (Phase 15l): where the branches start (roots), how they wander and split, their widths, colors,
## glow and pulse, and the silhouette they must stay inside. Data only: CorruptionVeins grows the branches from it (the same seed always
## grows the same veins) and draws them; the ending scene and the player's rig share the same style.

const DEFAULT_PATH: String = "res://frontend/fx/default_corruption_veins.tres"

@export_group("Roots")
## One entry per root, the four arrays have the same size. Positions are in duck units (the rig's own: the head's center is at (5, -36)).
@export var root_points: PackedVector2Array = PackedVector2Array()
@export var root_directions: PackedVector2Array = PackedVector2Array()
## From how many kept fragments this root shows (1 = arm and neck, 2 = chest and the edge of the face, 3 = widespread).
@export var root_tiers: PackedInt32Array = PackedInt32Array()
## Length of the main branch of each root, in duck units.
@export var root_lengths: PackedFloat32Array = PackedFloat32Array()
## Y above which a root belongs to the head (it follows the head when the duck bows).
@export_range(-60.0, 0.0, 0.5) var head_line_y: float = -28.0

@export_group("Growth")
@export_range(3, 20, 1) var trunk_steps: int = 8
@export_range(0.0, 1.0, 0.01) var twig_chance: float = 0.42
@export_range(1, 8, 1) var twig_steps: int = 3
@export_range(0.0, 1.5, 0.01, "suffix:rad") var wiggle: float = 0.42
@export_range(0.0, 1.5, 0.01, "suffix:rad") var twig_angle: float = 0.8
@export_range(0.0, 1.0, 0.01) var twig_scale: float = 0.55
@export var random_seed: int = 7
## Seconds a full growth would take when the owner animates it by itself (the scenes feed `growth` directly).
@export_range(0.5, 20.0, 0.1, "suffix:s") var grow_seconds: float = 6.0
## Share of the growth where the last branches start (the first start at 0): veins grow outward from the roots.
@export_range(0.0, 0.9, 0.01) var max_delay: float = 0.6

@export_group("Look")
@export_range(0.5, 6.0, 0.1, "suffix:px") var trunk_width: float = 2.1
@export_range(0.2, 1.0, 0.05) var twig_width_scale: float = 0.6
@export_range(0.0, 3.0, 0.1, "suffix:px") var outline_extra: float = 1.5
@export_range(0.0, 10.0, 0.1, "suffix:px") var glow_extra: float = 4.5
@export var core_color: Color = Color(0.5, 0.18, 0.72, 0.95)
@export var highlight_color: Color = Color(0.82, 0.55, 1.0, 0.8)
@export var outline_color: Color = Color(0.1, 0.03, 0.16, 0.95)
@export var glow_color: Color = Color(0.62, 0.25, 0.95, 0.22)
## Opacity of the first, second and third tier (the first kept fragment shows faint veins).
@export var tier_alpha: PackedFloat32Array = PackedFloat32Array([0.55, 0.8, 1.0])

@export_group("Pulse")
@export_range(0.0, 3.0, 0.05, "suffix:Hz") var pulse_hz: float = 0.55
@export_range(0.0, 0.6, 0.01) var pulse_depth: float = 0.22
## Reduced mode: static veins this much thinner.
@export_range(0.2, 1.0, 0.05) var reduced_width_scale: float = 0.65

@export_group("Clipping")
## The veins are clipped to the outline of the part shrunk by this much, so they never touch the ink edge (Phase 15o).
@export_range(0.0, 4.0, 0.1, "suffix:px") var clip_margin: float = 1.4

@export_group("Silhouette")
## The veins never leave these ellipses (center, radii) of the duck: body, head, neck and the wing at its side.
@export var silhouette_centers: PackedVector2Array = PackedVector2Array()
@export var silhouette_radii: PackedVector2Array = PackedVector2Array()


static func get_default() -> CorruptionVeinsStyle:
	return load(DEFAULT_PATH) as CorruptionVeinsStyle
