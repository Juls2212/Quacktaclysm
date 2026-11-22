class_name ProfileLook
extends Resource
## How one adaptive profile (compassionate / neutral / corrupt) looks and sounds. Presentation only:
## nothing here touches a gameplay stat. Colors named "tint", "color" or "glow" use their ALPHA as the
## intensity (alpha 0 = effect off), except `background_tint`, which multiplies the background layers
## (white = unchanged). The neutral entry is the identity: it leaves the game exactly as it was.

## Neutral value of the music filter: fully open (= no filter).
const FILTER_OPEN_HZ: float = 20500.0

@export_group("World")
## Multiplies the sky and the parallax layers behind the play field (never the play field itself).
@export var background_tint: Color = Color(1, 1, 1, 1)
## Screen-edge vignette: rgb = color, alpha = strength at the corners (0 = none).
@export var vignette_color: Color = Color(0, 0, 0, 0)
@export_group("Hud")
## Tint laid over the corruption plaque in the HUD (alpha = strength).
@export var plaque_tint: Color = Color(1, 1, 1, 0)
@export_group("Duck and enemies")
## Soft light around the hero (alpha = strength).
@export var aura_color: Color = Color(1, 1, 1, 0)
## Tint over the hero's eye (alpha = strength).
@export var eye_color: Color = Color(1, 1, 1, 0)
## Glow around the head and eye of every enemy and boss (alpha = strength).
@export var enemy_glow_color: Color = Color(1, 1, 1, 0)
@export_group("Music")
## Pitch (and speed) of the music; 1.0 = unchanged.
@export_range(0.5, 1.5, 0.01) var music_pitch: float = 1.0
## Low-pass cutoff of the music in Hz; FILTER_OPEN_HZ (or more) = no filter.
@export_range(500.0, 20500.0, 10.0) var music_lowpass_hz: float = 20500.0
@export_group("Decision pulse")
## Screen tint and plaque flash when a decision changes the profile (rgb = color, alpha = peak).
@export var pulse_color: Color = Color(1, 1, 1, 0.15)
@export_range(0.1, 3.0, 0.05, "suffix:s") var pulse_duration: float = 0.8


## Copies every value of `other` into this look.
func copy_from(other: ProfileLook) -> void:
	background_tint = other.background_tint
	vignette_color = other.vignette_color
	plaque_tint = other.plaque_tint
	aura_color = other.aura_color
	eye_color = other.eye_color
	enemy_glow_color = other.enemy_glow_color
	music_pitch = other.music_pitch
	music_lowpass_hz = other.music_lowpass_hz
	pulse_color = other.pulse_color
	pulse_duration = other.pulse_duration


## Resets the world, duck, enemy and music values to neutral (the plaque tint is kept).
func make_world_neutral() -> void:
	background_tint = Color(1, 1, 1, 1)
	vignette_color = Color(0, 0, 0, 0)
	aura_color = Color(1, 1, 1, 0)
	eye_color = Color(1, 1, 1, 0)
	enemy_glow_color = Color(1, 1, 1, 0)
	music_pitch = 1.0
	music_lowpass_hz = FILTER_OPEN_HZ


## True if this look changes nothing (the neutral look).
func is_identity() -> bool:
	return background_tint.is_equal_approx(Color(1, 1, 1, 1)) \
			and vignette_color.a <= 0.0 and plaque_tint.a <= 0.0 and aura_color.a <= 0.0 \
			and eye_color.a <= 0.0 and enemy_glow_color.a <= 0.0 \
			and is_equal_approx(music_pitch, 1.0) and music_lowpass_hz >= FILTER_OPEN_HZ


## Writes the blend of `a` toward `b` (t = 0..1) into `into`, without allocating. The pulse fields
## come from `b`.
static func blend(a: ProfileLook, b: ProfileLook, t: float, into: ProfileLook) -> void:
	into.background_tint = a.background_tint.lerp(b.background_tint, t)
	into.vignette_color = _lerp_tint(a.vignette_color, b.vignette_color, t)
	into.plaque_tint = _lerp_tint(a.plaque_tint, b.plaque_tint, t)
	into.aura_color = _lerp_tint(a.aura_color, b.aura_color, t)
	into.eye_color = _lerp_tint(a.eye_color, b.eye_color, t)
	into.enemy_glow_color = _lerp_tint(a.enemy_glow_color, b.enemy_glow_color, t)
	into.music_pitch = lerpf(a.music_pitch, b.music_pitch, t)
	# Cutoffs blend in log space (how the ear hears them).
	into.music_lowpass_hz = exp(lerpf(log(a.music_lowpass_hz), log(b.music_lowpass_hz), t))
	into.pulse_color = b.pulse_color
	into.pulse_duration = b.pulse_duration


## Blends two tints whose alpha is an intensity: a faded-out side lends its hue to the other, so a
## tint fading in never passes through a wrong color.
static func _lerp_tint(a: Color, b: Color, t: float) -> Color:
	var rgb: Color = a.lerp(b, t)
	if a.a <= 0.001:
		rgb = b
	elif b.a <= 0.001:
		rgb = a
	return Color(rgb.r, rgb.g, rgb.b, lerpf(a.a, b.a, t))
