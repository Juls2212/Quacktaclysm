class_name GuardianSpiritConfig
extends Resource
## Numbers of the guardian soul spirit (Phase 15r): the translucent blue figure that appears where a guardian fell, speaks its last words and then
## dissolves into the fragment. Presentation only.

const DEFAULT_PATH: String = "res://frontend/fx/default_guardian_spirit.tres"

## Opacity of the figure and the tint that makes it blue.
@export_range(0.1, 1.0, 0.01) var opacity: float = 0.55
@export var tint: Color = Color(0.55, 0.78, 1.0)
@export var glow_color: Color = Color(0.5, 0.78, 1.0)
@export_range(20.0, 300.0, 1.0, "suffix:px") var glow_radius: float = 140.0
## Seconds the spirit takes to appear (the body fades in about the same time).
@export_range(0.2, 3.0, 0.05, "suffix:s") var fade_in_seconds: float = 1.0
## How far it hovers up and down, and how fast.
@export_range(0.0, 30.0, 0.5, "suffix:px") var hover_amplitude: float = 6.0
@export_range(0.1, 2.0, 0.05, "suffix:Hz") var hover_hz: float = 0.5
## How far it rises while appearing.
@export_range(0.0, 80.0, 1.0, "suffix:px") var rise_pixels: float = 22.0
## A slow flicker of its opacity (kept under the photosensitivity limit of 3 per second).
@export_range(0.0, 0.3, 0.01) var flicker_amount: float = 0.07
@export_range(0.1, 3.0, 0.05, "suffix:Hz") var flicker_hz: float = 1.3
## Wisps that rise from it while it hovers.
@export_range(0, 24, 1) var wisp_count: int = 9
## The dissolve into the fragment: how long, and how many particles stream into it.
@export_range(0.3, 4.0, 0.05, "suffix:s") var dissolve_seconds: float = 1.5
@export_range(10, 240, 1) var dissolve_particles: int = 90
## In reduced mode the spirit is a still figure and only fades.
@export_range(0.1, 2.0, 0.05, "suffix:s") var reduced_fade_seconds: float = 0.6
## How long the fragment takes to condense once the particles have arrived.
@export_range(0.0, 2.0, 0.05, "suffix:s") var fragment_condense_seconds: float = 0.5


static func get_default() -> GuardianSpiritConfig:
	var config := load(DEFAULT_PATH) as GuardianSpiritConfig
	return config if config != null else GuardianSpiritConfig.new()
