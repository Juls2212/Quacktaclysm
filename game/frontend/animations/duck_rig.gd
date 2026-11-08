@tool
class_name DuckRig
extends Node2D
## Hand-drawn duck drawn in code: thick ink outline, flat fills, procedural animation.
## Visual only. A controller (player_visual.gd / enemy_visual.gd / boss_visual.gd) writes the
## pose inputs below every frame; the rig turns them into a run cycle, squash, weapon arcs, hair...
## Origin is the body center of the owner; `foot_y` is where the feet touch the floor.
## Facing is handled by the parent (Visual.scale.x); the rig always draws facing +x.
## `part` draws a single piece (body, head or weapon): DuckRagdoll uses it for the death ragdoll.
## Every duck is a worn-out survivor of the fallen stars: a common layer of wear (`wear`: eye bags,
## dust, soot, greasy ruffled feathers, hatching, a shaky hand-drawn outline) and, for the corrupted
## ones, mutations (extra eyes, twisted beak, bald stitched patches, glowing cracks, drool, a dead
## wing, a gas mask, absurd survival junk). Each look has its own mix; `custom_mutations` replaces
## it. Bosses in phase 2 (`enraged`) open more eyes, crack and drool more. All of it is drawn inside
## the body transform, so it follows every animation and the ragdoll pieces. Never touches physics.

enum Look { HERO, BRUTE, BRUTE_TOUGH, BANDIT, SLINGER, BOSS_WOODCUTTER, BOSS_SWAMP, BOSS_STORM, GRANDFATHER }
## Extra poses of the grandfather (the other looks ignore it).
enum Gesture { IDLE, TALK, POINT, HOLD_TORCH }
## Survival junk worn by a duck (bit flags of `survivor_props`).
const PROP_CAN: int = 1
const PROP_POT: int = 2
const PROP_PLUSH: int = 4
const PROP_PAN: int = 8
## What the duck is doing with its weapon. Enemies use ATTACK (its look decides the move);
## bosses use ATTACK (swipe), CHARGE and CAST (projectile volley).
enum Action { NONE, SLASH, HEAVY, DASH_SLASH, CAST, ATTACK, CHARGE }
enum Phase { WINDUP, STRIKE, RECOVER }
## ALL draws the whole duck; the others draw one ragdoll piece. FX (shadow, smears) is never a piece.
enum Part { ALL, BODY, HEAD, WEAPON, FX }
## Per-level look of the common enemies: dusty city survivors (some in gas masks), swamp ducks
## hung with algae and dripping, storm ducks cracked open with pulsing yellow light.
enum LevelStyle { NONE, POLVO, ALGAS, GRIETAS }

const INK := Color(0.106, 0.098, 0.122)
const PAPER := Color(0.984, 0.976, 0.957)
const BEAK := Color(0.86, 0.6, 0.27)
const BEAK_DARK := Color(0.68, 0.43, 0.18)
const STEEL := Color(0.82, 0.84, 0.84)
const EMBER := Color(1.0, 0.72, 0.26)
const WOOD := Color(0.5, 0.34, 0.2)
const INK_W := 2.6
const HERO_KIMONO := Color(0.6, 0.21, 0.2)
const BOSS_SCALE: float = 1.7
## Survivor palette: nothing is clean white or chick yellow any more.
const FEATHER_HERO := Color(0.85, 0.81, 0.66)
const FEATHER_ELDER := Color(0.89, 0.86, 0.73)
const ELDER_KIMONO := Color(0.42, 0.47, 0.55)
const SCLERA := Color(0.95, 0.92, 0.79)
const BAGS := Color(0.3, 0.2, 0.28)
const DIRT := Color(0.38, 0.28, 0.18)
const SOOT := Color(0.17, 0.16, 0.16)
const SKIN := Color(0.91, 0.72, 0.69)
const CORRUPT := Color(1.0, 0.42, 0.16)
const RUST := Color(0.56, 0.31, 0.17)
const BANDAGE := Color(0.87, 0.83, 0.7)
const DROOL := Color(0.15, 0.13, 0.11)
const TOOTH := Color(0.93, 0.9, 0.76)

@export var look: Look = Look.HERO:
	set(value):
		look = value
		_strands.clear()
		queue_redraw()
## Distance from the origin down to the floor (half the collision height).
@export var foot_y: float = 26.0
@export var part: Part = Part.ALL
## Color of the sword smear for the light slash (heavy and dash slash use their own).
@export var slash_color: Color = Color(1.0, 1.0, 1.0, 0.92)
@export var heavy_color: Color = Color(1.0, 0.65, 0.25, 0.92)
@export var dash_slash_color: Color = Color(0.4, 0.95, 1.0, 0.85)
## Grandfather pose: idle (slow breathing), talk, point with the cane, hold a lit torch.
## The hero also uses HOLD_TORCH: torch raised in the sword hand, katana sheathed at the waist.
@export var gesture: Gesture = Gesture.IDLE
## Intensity of the wear layer (dust, soot, eye bags, ruffled feathers): 0 clean, 1 the look's own.
@export_range(0.0, 1.5, 0.05) var wear: float = 1.0

@export_group("Mutations")
## Off: each look uses its own mix of mutations. On: the values below are used instead.
@export var custom_mutations: bool = false
@export_range(0, 3) var extra_eyes: int = 0
@export var twisted_beak: bool = false
@export var missing_feathers: bool = false
@export var corruption_cracks: bool = false
@export var drool: bool = false
@export var dead_wing: bool = false
@export var gas_mask: bool = false
@export_flags("Can helmet", "Pot helmet", "Plush", "Pan shield") var survivor_props: int = 0
@export_group("")
## Per-level look (set at run time by EnemyLevelStyle on the level's enemies). Visual only: a tint
## of the duck plus dust, algae or cracks drawn by a child node over it, and falling ash, drops
## or sparks.
@export var level_style: LevelStyle = LevelStyle.NONE:
	set(value):
		level_style = value
		_refresh_level_style()

# --- Pose inputs (written by the controller each frame) ---
var ground_speed: float = 0.0
var grounded: bool = true
var vertical_speed: float = 0.0
var dashing: bool = false
var action: Action = Action.NONE
var phase: Phase = Phase.WINDUP
## Progress 0..1 inside `phase`.
var phase_t: float = 0.0
var hurt: bool = false
var dead: bool = false
## Bosses in phase 2: hotter eyes and steam.
var enraged: bool = false
## Limp piece of a ragdoll: no body animation, rest pose, X eyes.
var ragdoll: bool = false
## Tint of the sword glow while casting the wave (comes from the wave tier).
var cast_color: Color = Color(0.6, 0.9, 1.0, 1.0)

# --- Animation state ---
var _time: float = 0.0
var _run_phase: float = 0.0
var _lean: float = 0.0
var _squash: Vector2 = Vector2.ONE
var _land_kick: float = 0.0
var _was_grounded: bool = true
var _dead_t: float = 0.0
var _ghosts: Array = []
var _ghost_clock: float = 0.0
var _strands: Array = []
var _root: Transform2D = Transform2D.IDENTITY
## Piece the current draw calls belong to (compared with `part`).
var _cur: Part = Part.BODY
## Where the weapon ends this frame (rig space), for effects drawn at the tip.
var _tip: Vector2 = Vector2.ZERO
## Mutations in effect this frame (see _mutations()).
var _mx: Dictionary = {}
## Seed of the per-duck level-style choices (who wears a gas mask, where the cracks run).
var style_seed: int = 0
var _style_fx: Node2D = null
## Falling ash, drops and sparks of the level style, in global space: {p, v, life, max, kind}.
var _style_bits: Array = []
var _style_clock: float = 0.0
var _style_rng := RandomNumberGenerator.new()
var _style_was_hurt: bool = false
var _puff_clock: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	_advance_body(delta)
	_advance_ghosts(delta)
	_advance_strands(delta)
	_advance_style(delta)
	queue_redraw()


# =====================================================================================
# Ragdoll support: where each piece sits, in this node's local space, at rest.
# =====================================================================================

func is_boss() -> bool:
	return look == Look.BOSS_WOODCUTTER or look == Look.BOSS_SWAMP or look == Look.BOSS_STORM


## Copies the wear, mutations and phase of another rig (ragdoll pieces keep the duck's look).
func copy_style_from(source: DuckRig) -> void:
	gesture = source.gesture
	wear = source.wear
	custom_mutations = source.custom_mutations
	extra_eyes = source.extra_eyes
	twisted_beak = source.twisted_beak
	missing_feathers = source.missing_feathers
	corruption_cracks = source.corruption_cracks
	drool = source.drool
	dead_wing = source.dead_wing
	gas_mask = source.gas_mask
	survivor_props = source.survivor_props
	enraged = source.enraged
	style_seed = source.style_seed
	level_style = source.level_style


## Mutations drawn this frame: the look's own mix (or the custom one), grown in a boss's phase 2.
func _mutations() -> Dictionary:
	var m: Dictionary = {"eyes": 0, "beak": false, "bald": false, "cracks": false, "drool": false,
			"dead_wing": false, "mask": false, "props": 0, "fury": false}
	if custom_mutations:
		m["eyes"] = extra_eyes
		m["beak"] = twisted_beak
		m["bald"] = missing_feathers
		m["cracks"] = corruption_cracks
		m["drool"] = drool
		m["dead_wing"] = dead_wing
		m["mask"] = gas_mask
		m["props"] = survivor_props
	else:
		match look:
			Look.BRUTE:
				m["eyes"] = 2
				m["beak"] = true
				m["dead_wing"] = true
			Look.BRUTE_TOUGH:
				m["eyes"] = 2
				m["beak"] = true
				m["dead_wing"] = true
				m["props"] = PROP_POT | PROP_PAN
			Look.BANDIT:
				m["beak"] = true
				m["bald"] = true
				m["props"] = PROP_CAN
			Look.SLINGER:
				m["mask"] = true
				m["props"] = PROP_PLUSH
			Look.BOSS_WOODCUTTER:
				m["eyes"] = 1
				m["beak"] = true
				m["drool"] = true
			Look.BOSS_SWAMP:
				m["eyes"] = 2
				m["bald"] = true
				m["drool"] = true
			Look.BOSS_STORM:
				m["eyes"] = 1
				m["cracks"] = true
	if is_boss() and enraged:
		m["eyes"] = mini(int(m["eyes"]) + 2, 4)
		m["cracks"] = true
		m["drool"] = true
		m["fury"] = true
	# One dusty city duck in three hides behind a gas mask with yellow visors.
	if level_style == LevelStyle.POLVO and not is_boss() and posmod(style_seed, 3) == 0:
		m["mask"] = true
	return m


func _mi(key: String) -> int:
	return int(_mx.get(key, 0))


func _mb(key: String) -> bool:
	return bool(_mx.get(key, false))


## Base wear of each look, scaled by `wear`.
func _wear_k() -> float:
	var base: float = 1.0
	match look:
		Look.HERO:
			base = 0.7
		Look.GRANDFATHER:
			base = 0.8
		Look.BOSS_WOODCUTTER, Look.BOSS_SWAMP, Look.BOSS_STORM:
			base = 1.15
	return clampf(wear * base, 0.0, 1.6)


func get_rest_transform() -> Transform2D:
	return Transform2D(0.0, Vector2.ONE * _look_scale(), 0.0, Vector2(0.0, foot_y))


func get_part_center(p: Part) -> Vector2:
	var rest: Transform2D = get_rest_transform()
	match p:
		Part.HEAD:
			return rest * _head_center()
		Part.WEAPON:
			return rest * _hand_point(_idle_weapon_pose(false))
	return rest * Vector2(-1, -15)


func get_part_radius(p: Part) -> float:
	match p:
		Part.HEAD:
			return _head_radius() * _body_scale()
		Part.WEAPON:
			return 4.0 * _body_scale()
	return 14.0 * _body_scale()


## Size of the duck's ragdoll pieces (their collision), which the bigger cartoon drawing of the
## brutes does not change.
func _body_scale() -> float:
	match look:
		Look.BRUTE:
			return 1.1
		Look.BRUTE_TOUGH:
			return 1.2
	return _look_scale()


## Cartoon exaggeration for every corrupted duck (not the hero or the grandfather): bigger bulging
## eyes, heavier bags, bigger grime, patches and teeth, longer tufts, so the wear reads at game size.
func _toon() -> bool:
	return look != Look.HERO and look != Look.GRANDFATHER


## Weapon from the hand to its tip (local space, at rest).
func get_weapon_vector() -> Vector2:
	var pose: Vector2 = _idle_weapon_pose(false)
	return Vector2.from_angle(pose.y) * _weapon_length() * _body_scale()


func get_neck_point() -> Vector2:
	var rest: Transform2D = get_rest_transform()
	return rest * Vector2(-1, -15).lerp(_head_center(), 0.62)


# =====================================================================================
# Motion
# =====================================================================================

func _advance_body(delta: float) -> void:
	if ragdoll:
		_lean = 0.0
		_squash = Vector2.ONE
		return
	if grounded and not _was_grounded and not dashing:
		_land_kick = 1.0
	_was_grounded = grounded
	_land_kick = move_toward(_land_kick, 0.0, delta * 6.0)
	if grounded and ground_speed > 5.0:
		_run_phase += ground_speed * delta * 0.085 / _look_scale()
	else:
		_run_phase = lerpf(_run_phase, roundf(_run_phase / PI) * PI, minf(delta * 10.0, 1.0))
	_dead_t = minf(_dead_t + delta * 3.5, 1.0) if dead else 0.0

	var target_lean: float = _base_lean()
	var target_squash := Vector2.ONE
	if dashing:
		target_lean += 0.32
		target_squash = Vector2(1.14, 0.9)
	elif not grounded:
		target_squash = Vector2(0.94, 1.07) if vertical_speed < 0.0 else Vector2(0.97, 1.03)
	elif ground_speed > 5.0:
		target_lean += 0.1
	if hurt:
		target_lean = -0.28
		if is_boss():
			target_lean = -0.12 + sin(_time * 40.0) * 0.04
	target_lean += _action_lean()
	target_squash *= _action_squash()
	if dead:
		target_lean = -1.45 * _ease_out(_dead_t)

	var rate: float = minf(delta * 16.0, 1.0)
	_lean = lerpf(_lean, target_lean, rate)
	_squash = _squash.lerp(target_squash, rate)


func _base_lean() -> float:
	match look:
		Look.BANDIT:
			# Skinny and hunched, always ready to bolt.
			return 0.17
		Look.BOSS_STORM:
			return 0.05
		Look.GRANDFATHER:
			return 0.07
	return 0.0


func _breath() -> float:
	if ragdoll or dead or dashing or not grounded or ground_speed > 5.0:
		return 0.0
	if look == Look.GRANDFATHER:
		# Slow, deep old man's breath.
		return sin(_time * 1.2) * 0.034
	return sin(_time * (1.8 if is_boss() else 2.6)) * 0.025


func _bob() -> float:
	if not ragdoll and grounded and ground_speed > 5.0 and not dashing:
		return -absf(sin(_run_phase)) * 2.6 * _look_scale()
	return 0.0


func _build_root() -> Transform2D:
	var kick: float = _land_kick * _land_kick
	var sq := Vector2(_squash.x * (1.0 + kick * 0.14), _squash.y * (1.0 - kick * 0.16 + _breath()))
	return Transform2D(_lean, sq * _look_scale(), 0.0, Vector2(0.0, foot_y + _bob()))


func _look_scale() -> float:
	match look:
		Look.BRUTE:
			return 1.2
		Look.BRUTE_TOUGH:
			return 1.25
		Look.BANDIT:
			return 0.95
		Look.BOSS_WOODCUTTER, Look.BOSS_SWAMP, Look.BOSS_STORM:
			return BOSS_SCALE
		Look.GRANDFATHER:
			return 1.05
	return 1.0


func _head_center() -> Vector2:
	match look:
		Look.HERO:
			return Vector2(7, -37)
		Look.BANDIT:
			return Vector2(5, -33)
		Look.SLINGER:
			return Vector2(5, -36)
		Look.BOSS_WOODCUTTER, Look.BOSS_SWAMP, Look.BOSS_STORM:
			return Vector2(7, -38)
		Look.GRANDFATHER:
			# Hunched: the head hangs forward and low.
			return Vector2(11, -32)
	return Vector2(6, -37)


func _head_radius() -> float:
	match look:
		Look.HERO:
			return 12.5
		Look.BANDIT:
			return 10.0
		Look.GRANDFATHER:
			return 11.0
	return 11.5


func _shoulder() -> Vector2:
	match look:
		Look.HERO:
			return Vector2(0, -22)
		Look.BANDIT:
			return Vector2(-1, -20)
		Look.SLINGER:
			return Vector2(0, -21)
		Look.BOSS_WOODCUTTER, Look.BOSS_SWAMP, Look.BOSS_STORM:
			return Vector2(-2, -25)
		Look.GRANDFATHER:
			return Vector2(4, -21)
	return Vector2(-2, -24)


func _arm_length() -> float:
	match look:
		Look.BANDIT, Look.GRANDFATHER:
			return 12.0
		Look.HERO, Look.SLINGER:
			return 13.0
	return 14.0


func _hand_point(pose: Vector2) -> Vector2:
	return _shoulder() + Vector2.from_angle(pose.x) * _arm_length()


func _weapon_length() -> float:
	match look:
		Look.HERO:
			return 38.0
		Look.BRUTE:
			return 30.0
		Look.BRUTE_TOUGH:
			return 34.0
		Look.BANDIT:
			return 19.0
		Look.SLINGER:
			return 12.0
		Look.BOSS_WOODCUTTER:
			return 40.0
		Look.BOSS_SWAMP:
			return 42.0
		Look.BOSS_STORM:
			return 48.0
		Look.GRANDFATHER:
			# Cane (or torch when holding it up).
			return 18.0 if gesture == Gesture.HOLD_TORCH else 32.0
	return 30.0


# =====================================================================================
# Afterimages (dash, lunge, charge) and loose strands (hair, tails, cape, moss)
# =====================================================================================

func _advance_ghosts(delta: float) -> void:
	for ghost in _ghosts:
		ghost["life"] -= delta * 4.0
	_ghosts = _ghosts.filter(func(g: Dictionary) -> bool: return g["life"] > 0.0)
	var lunging: bool = phase == Phase.STRIKE and (
			(look == Look.BANDIT and action == Action.ATTACK) or action == Action.CHARGE)
	if ragdoll or not (dashing or lunging) or not is_inside_tree():
		return
	_ghost_clock -= delta
	if _ghost_clock <= 0.0:
		_ghost_clock = 0.03
		_ghosts.append({ "xf": global_transform * _root, "life": 1.0 })


func _strand_specs() -> Array:
	# Anchor (rig space), segments, segment length, root width, color, rest direction, piece.
	match look:
		Look.HERO:
			# Shoulder-length and fanned out so the tips separate into loose locks.
			var hair: Color = _hair_color()
			return [
				[Vector2(-5, -44), 4, 4.5, 4.5, hair, Vector2(-1.0, 0.45), Part.HEAD],
				[Vector2(-6, -38), 4, 4.5, 5.0, hair, Vector2(-0.8, 0.8), Part.HEAD],
				[Vector2(-3, -33), 3, 4.5, 4.5, hair, Vector2(-0.35, 1.0), Part.HEAD],
				[Vector2(1, -48), 4, 4.0, 3.8, hair, Vector2(-1.0, 0.2), Part.HEAD],
			]
		Look.BANDIT:
			var red := Color(0.6, 0.24, 0.2)
			# Rag tied under the can helmet, frayed into two tails.
			return [[Vector2(-6, -38), 4, 4.5, 4.0, red, Vector2(-1.0, 0.3), Part.HEAD],
					[Vector2(-6, -36), 3, 5.0, 3.5, red.darkened(0.15), Vector2(-1.0, 0.6), Part.HEAD]]
		Look.GRANDFATHER:
			# Long untidy beard under the beak and a few loose locks at the nape.
			var beard := Color(0.88, 0.86, 0.76)
			return [[Vector2(19, -27), 4, 3.6, 4.2, beard, Vector2(0.1, 1.0), Part.HEAD],
					[Vector2(16, -26), 5, 3.6, 4.6, beard, Vector2(-0.15, 1.0), Part.HEAD],
					[Vector2(22, -27), 3, 3.4, 3.0, beard, Vector2(0.35, 1.0), Part.HEAD],
					[Vector2(13, -27), 3, 3.2, 3.0, beard.darkened(0.08), Vector2(-0.4, 1.0), Part.HEAD],
					[Vector2(1, -36), 3, 3.6, 2.6, beard, Vector2(-1.0, 0.7), Part.HEAD]]
		Look.BOSS_WOODCUTTER:
			var rope := Color(0.78, 0.66, 0.42)
			# Rope ends of the sack hood, knotted at the nape.
			return [[Vector2(-5, -31), 3, 4.0, 2.4, rope, Vector2(-1.0, 0.5), Part.HEAD],
					[Vector2(-5, -31), 3, 3.5, 2.4, rope, Vector2(-1.0, 0.9), Part.HEAD]]
		Look.BOSS_SWAMP:
			# Weed hanging off its back and tail.
			var moss := Color(0.31, 0.42, 0.27)
			return [[Vector2(-14, -22), 4, 4.0, 3.5, moss, Vector2(-0.7, 1.0), Part.BODY],
					[Vector2(-17, -13), 4, 4.0, 3.5, moss, Vector2(-0.5, 1.0), Part.BODY],
					[Vector2(-10, -28), 3, 4.0, 3.0, moss, Vector2(-1.0, 0.6), Part.BODY]]
		Look.BOSS_STORM:
			# Tattered cape strips streaming from the shoulders.
			var cape := Color(0.17, 0.18, 0.28)
			return [[Vector2(-14, -27), 6, 5.0, 7.0, cape, Vector2(-1.0, 0.45), Part.BODY],
					[Vector2(-18, -20), 6, 5.0, 7.5, cape, Vector2(-1.0, 0.7), Part.BODY],
					[Vector2(-11, -29), 5, 5.0, 6.0, cape, Vector2(-0.8, 0.9), Part.BODY]]
	return []


func _hair_color() -> Color:
	return Color(0.16, 0.14, 0.2)


func _advance_strands(delta: float) -> void:
	if not is_inside_tree():
		return
	_root = _build_root()
	var specs: Array = _strand_specs()
	if _strands.size() != specs.size():
		_strands.clear()
		for spec in specs:
			_strands.append({ "spec": spec, "p": PackedVector2Array(), "prev": PackedVector2Array() })
	var to_world: Transform2D = global_transform * _root
	var dt: float = clampf(delta, 0.001, 0.05)
	for strand in _strands:
		var spec: Array = strand["spec"]
		var count: int = spec[1]
		var rest_dir: Vector2 = global_transform.basis_xform(spec[5] as Vector2).normalized()
		var seg: float = spec[2] * _look_scale() * absf(global_transform.get_scale().y)
		var anchor: Vector2 = to_world * (spec[0] as Vector2)
		var p: PackedVector2Array = strand["p"]
		var prev: PackedVector2Array = strand["prev"]
		if p.size() != count + 1 or p[0].distance_to(anchor) > 200.0:
			p.resize(count + 1)
			prev.resize(count + 1)
			for i in count + 1:
				p[i] = anchor + rest_dir * seg * i
				prev[i] = p[i]
		p[0] = anchor
		prev[0] = anchor
		for i in range(1, count + 1):
			var velocity: Vector2 = (p[i] - prev[i]) * 0.86
			prev[i] = p[i]
			var sway := Vector2(sin(_time * 3.1 + i * 0.7) * 6.0, 0.0)
			p[i] += velocity + ((Vector2(0, 520) + sway) * dt * dt + rest_dir * 0.35 * i) * seg / spec[2]
		for _pass in 2:
			for i in range(1, count + 1):
				var d: Vector2 = p[i] - p[i - 1]
				p[i] = p[i - 1] + d.normalized() * seg if d.length() > 0.001 else p[i - 1] + rest_dir * seg
		strand["p"] = p
		strand["prev"] = prev


# =====================================================================================
# Drawing
# =====================================================================================

func _draw() -> void:
	_root = _build_root()
	_mx = _mutations()
	_cur = Part.FX
	_draw_shadow()
	_draw_ghosts()
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# The hero's hair and the grandfather's beard are drawn mid-body by their own drawers.
	if look != Look.HERO and look != Look.GRANDFATHER:
		_draw_strands()
	draw_set_transform_matrix(_root)
	match look:
		Look.HERO:
			_draw_hero()
		Look.BRUTE, Look.BRUTE_TOUGH:
			_draw_brute()
		Look.BANDIT:
			_draw_bandit()
		Look.SLINGER:
			_draw_slinger()
		Look.BOSS_WOODCUTTER, Look.BOSS_SWAMP, Look.BOSS_STORM:
			_draw_boss()
		Look.GRANDFATHER:
			_draw_grandfather()
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_shadow() -> void:
	if ragdoll:
		return
	var w: float = 17.0 * _look_scale()
	var alpha: float = 0.85 if grounded else 0.35
	if dead:
		w *= 1.4
	draw_set_transform(Vector2(0, foot_y), 0.0, Vector2(1.0 if grounded else 0.65, 1.0))
	_poly(_ellipse(Vector2.ZERO, w, 3.6 * sqrt(_look_scale()), 18), Color(INK, alpha))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_ghosts() -> void:
	var tint := Color(0.45, 0.4, 0.55)
	match look:
		Look.HERO:
			tint = Color(0.85, 0.3, 0.32)
		Look.BOSS_SWAMP:
			tint = Color(0.45, 0.6, 0.35)
		Look.BOSS_STORM:
			tint = Color(0.45, 0.8, 0.95)
	var inv: Transform2D = global_transform.affine_inverse()
	for ghost in _ghosts:
		draw_set_transform_matrix(inv * (ghost["xf"] as Transform2D))
		var c := Color(tint, 0.35 * float(ghost["life"]))
		_poly(_ellipse(Vector2(-1, -14), 16, 13), c)
		_poly(_ellipse(_head_center(), 11, 11), c)


func _draw_strands() -> void:
	# Ink pass first, then fill, so neighbouring strands merge into one mass of hair.
	for ink_pass in [true, false]:
		for strand in _strands:
			var spec: Array = strand["spec"]
			_cur = spec[6]
			var p: PackedVector2Array = strand["p"]
			var root_w: float = spec[3] * _look_scale()
			var color: Color = spec[4]
			for i in range(p.size() - 1):
				var a: Vector2 = to_local(p[i])
				var b: Vector2 = to_local(p[i + 1])
				var w: float = lerpf(root_w, root_w * 0.25, float(i) / float(maxi(p.size() - 2, 1)))
				if ink_pass:
					_line(a, b, INK, w + INK_W * 1.2 * _ink_scale(), true)
					_dot(b, (w + INK_W * 1.2 * _ink_scale()) * 0.5, INK)
				else:
					_line(a, b, color, w, true)
					_dot(b, w * 0.5, color)
			if not ink_pass and p.size() > 2:
				var h0: Vector2 = to_local(p[0])
				var h1: Vector2 = to_local(p[2])
				_line(h0 + Vector2(1, 0), h1 + Vector2(1, 0), Color(color.lightened(0.3), 0.7), 1.2, true)


## Strands are drawn in node space, so their outline follows the look's scale like the rest.
func _ink_scale() -> float:
	return _look_scale()


# --- Hero: kimono, long loose hair, katana ---

func _draw_hero() -> void:
	var arm: Vector2 = _weapon_pose()
	var kimono := HERO_KIMONO
	var obi := Color(0.2, 0.22, 0.32)
	var feather := FEATHER_HERO
	# The only healthy duck gets a soft light rim so it reads over the dark ruins.
	_draw_rim(Vector2(-1, -15), Vector2(15.5, 12.5), _head_center(), 14.5)
	_cur = Part.BODY
	_draw_feet(Color(BEAK))
	_draw_tail(Vector2(-13, -15), feather)
	# Robe: the top of the body egg flaring into a short skirt that leaves the legs visible.
	var robe := PackedVector2Array()
	for i in 13:
		var a: float = PI + PI * float(i) / 12.0
		robe.append(Vector2(-1, -15) + Vector2(cos(a) * 14.0, sin(a) * 11.0))
	robe.append_array([Vector2(15, -9), Vector2(12, -6), Vector2(-14, -6), Vector2(-17, -9)])
	_shape(robe, kimono)
	_shape(PackedVector2Array([Vector2(-16.2, -9), Vector2(14.2, -9), Vector2(12, -6), Vector2(-14, -6)]),
			HERO_KIMONO.darkened(0.3), 1.8)
	# Frayed hem: a torn notch and loose threads.
	_shape(PackedVector2Array([Vector2(3, -6), Vector2(5, -9.2), Vector2(7.5, -6)]), feather.darkened(0.25), 1.4)
	for x in [-11.0, -6.0, 9.5]:
		_line(Vector2(x, -6), Vector2(x - 0.6, -3.6), Color(INK, 0.7), 1.0, true)
	_line(Vector2(-5, -12), Vector2(-7, -7), INK, 1.3, true)
	_line(Vector2(5, -12), Vector2(6, -7), INK, 1.3, true)
	_grime(Vector2(-1, -14), Vector2(13.0, 8.0), 7, 11)
	_draw_patch(Vector2(-8.5, -21.0), 3.0, Color(0.45, 0.41, 0.33), 0.25)
	_hatch(Vector2(-10, -11), 6.0, 3, -0.9, 0.35)
	_draw_neck(Vector2(2, -24), feather)
	# Crossed collar over the chest, gone grey with dust.
	_shape(PackedVector2Array([Vector2(-3, -26), Vector2(3, -26), Vector2(10, -15), Vector2(5.5, -13)]),
			Color(0.84, 0.8, 0.68), 2.0)
	_dot(Vector2(6, -18), 1.3, Color(DIRT, 0.4))
	# Obi with its knot and tails at the back.
	_shape(PackedVector2Array([Vector2(-14.5, -17), Vector2(12.5, -17), Vector2(13.6, -12.5), Vector2(-15.2, -12.5)]),
			obi, 2.2)
	var flutter: float = sin(_time * 7.0) * 1.5 if ground_speed > 5.0 or dashing else 0.0
	_shape(PackedVector2Array([Vector2(-15, -14), Vector2(-21, -8 + flutter), Vector2(-17, -8.5 + flutter)]), obi, 1.8)
	_shape(PackedVector2Array([Vector2(-15, -14), Vector2(-24, -11 + flutter), Vector2(-20, -9 + flutter)]), obi, 1.8)
	_shape(_ellipse(Vector2(-15.5, -14.8), 3.6, 2.8), obi, 2.0)
	if gesture == Gesture.HOLD_TORCH:
		_draw_sheathed_katana()
		_cur = Part.BODY
	# The loose hair falls over the back of the kimono, then the head covers its roots.
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_strands()
	draw_set_transform_matrix(_root)
	var head: Vector2 = _head_center()
	_cur = Part.HEAD
	_draw_head(head, 12.5, feather)
	_grime(head + Vector2(2, 3), Vector2(7.0, 5.0), 3, 31)
	_draw_hero_hair_cap(head, 12.5)
	_draw_face_hero(head)
	_cur = Part.FX
	_draw_smear(Vector2(4, -24))
	_draw_sleeve_and_katana(_shoulder(), arm)


func _draw_hero_hair_cap(c: Vector2, r: float) -> void:
	# Crown of hair from the forehead over to the nape; strands carry on from the back.
	var hair: Color = _hair_color()
	# Greasy locks sticking up out of the crown: the hair has not seen a comb in months.
	for k in 4:
		var a: float = deg_to_rad(-95.0 - 28.0 * float(k))
		var base: Vector2 = c + Vector2.from_angle(a) * (r + 1.0)
		var tip: Vector2 = c + Vector2.from_angle(a + 0.3) * (r + 4.0 + 1.2 * float(k % 2)) + Vector2(0, sin(_time * 2.0 + k) * 0.3)
		var side: Vector2 = Vector2.from_angle(a).orthogonal() * 1.7
		_shape(PackedVector2Array([base - side, tip, base + side]), hair, 1.8)
	var cap := PackedVector2Array()
	for i in 15:
		var a: float = deg_to_rad(-55.0 - 155.0 * float(i) / 14.0)
		cap.append(c + Vector2(cos(a), sin(a)) * (r + 2.0))
	for i in 15:
		var a: float = deg_to_rad(-210.0 + 155.0 * float(i) / 14.0)
		var rr: float = r - 2.5 - 3.0 * sin(PI * float(i) / 14.0)
		cap.append(c + Vector2(-1.0, 0.5) + Vector2(cos(a), sin(a)) * rr)
	_shape(cap, hair)
	# Loose bangs falling over the forehead.
	_shape(PackedVector2Array([c + Vector2(1, -12), c + Vector2(6, -3), c + Vector2(6.5, -11)]), hair, 2.0)
	_shape(PackedVector2Array([c + Vector2(5, -12.5), c + Vector2(11, -5), c + Vector2(10.5, -10.5)]), hair, 2.0)
	_line(c + Vector2(-8, -8), c + Vector2(-2, -11.5), Color(0.42, 0.42, 0.5, 0.75), 1.5, true)
	# One stray hair across the face.
	_line_strip(PackedVector2Array([c + Vector2(8, -11), c + Vector2(10.5, -7), c + Vector2(9.5, -3)]), INK, 1.0)


func _draw_face_hero(c: Vector2) -> void:
	_draw_beak(c + Vector2(7.5, 0.0), 1.0)
	_draw_eye(c + Vector2(4.5, -3.0), false)
	if not dead and not hurt and not ragdoll:
		_line(c + Vector2(1.5, -9.5), c + Vector2(8, -8.0), INK, 2.0, true)
	# Small stitched scar on the cheek.
	_line(c + Vector2(-1.5, 2.5), c + Vector2(3.0, 6.0), Color(0.55, 0.3, 0.3), 1.4, true)
	for k in 2:
		var p: Vector2 = c + Vector2(-0.4 + k * 2.0, 3.4 + k * 1.6)
		_line(p + Vector2(-0.9, 1.0), p + Vector2(0.9, -1.0), INK, 0.9, true)


func _draw_sleeve_and_katana(shoulder: Vector2, arm: Vector2) -> void:
	var dir := Vector2.from_angle(arm.x)
	var hand: Vector2 = shoulder + dir * _arm_length()
	var side: Vector2 = dir.orthogonal()
	if gesture == Gesture.HOLD_TORCH and action == Action.NONE and not dead and not hurt:
		_draw_torch_sleeve(shoulder, hand, dir, side, arm.y)
		return
	# Wide kimono sleeve: always droops toward the floor, whatever the arm angle (hull keeps it valid).
	var sleeve := Geometry2D.convex_hull(PackedVector2Array([
		shoulder - side * 5.0, hand - side * 4.5, hand + side * 5.5,
		shoulder.lerp(hand, 0.6) + Vector2(0, 10), shoulder + side * 6.0 + Vector2(0, 5)]))
	sleeve.remove_at(sleeve.size() - 1)
	var behind: bool = sin(arm.y) < -0.55 and action != Action.NONE and phase == Phase.WINDUP
	if behind:
		_draw_katana(hand, arm.y, 34.0)
	_cur = Part.BODY
	_shape(sleeve, HERO_KIMONO)
	_grime(shoulder.lerp(hand, 0.5) + Vector2(0, 4), Vector2(3.0, 3.0), 2, 77)
	_line(hand - side * 4.5, hand + side * 5.5, Color(0.84, 0.8, 0.68), 2.0, true)
	if not behind:
		_draw_katana(hand, arm.y, 34.0)
	_cur = Part.BODY
	_shape(_ellipse(hand, 3.4, 3.0), FEATHER_HERO, 2.2)
	# Dirty bandage wrapped round the wrist, one loose end.
	_draw_bandage(hand - dir * 2.6, hand + dir * 0.4, 3.4)
	_line(hand - dir * 2.0 + side * 2.0, hand - dir * 4.5 + side * 4.5 + Vector2(0, sin(_time * 4.0) * 0.6), BANDAGE.darkened(0.1), 1.4, true)


## The hero's sleeve with a torch raised instead of the katana.
func _draw_torch_sleeve(shoulder: Vector2, hand: Vector2, dir: Vector2, side: Vector2, angle: float) -> void:
	_draw_torch(hand, angle)
	_cur = Part.BODY
	var sleeve := Geometry2D.convex_hull(PackedVector2Array([
		shoulder - side * 5.0, hand - side * 4.5, hand + side * 5.5,
		shoulder.lerp(hand, 0.6) + Vector2(0, 10), shoulder + side * 6.0 + Vector2(0, 5)]))
	sleeve.remove_at(sleeve.size() - 1)
	_shape(sleeve, HERO_KIMONO)
	_line(hand - side * 4.5, hand + side * 5.5, Color(0.84, 0.8, 0.68), 2.0, true)
	_shape(_ellipse(hand, 3.4, 3.0), FEATHER_HERO, 2.2)
	_draw_bandage(hand - dir * 2.6, hand + dir * 0.4, 3.4)


func _draw_katana(hand: Vector2, angle: float, length: float) -> void:
	_cur = Part.WEAPON
	var d := Vector2.from_angle(angle)
	var n: Vector2 = d.orthogonal()
	# Handle (tsuka) behind the hand, guard (tsuba), then a gently curved blade.
	var grip_a: Vector2 = hand - d * 9.0
	_line(grip_a, hand + d * 2.0, INK, 6.4, true)
	_line(grip_a, hand + d * 2.0, Color(0.32, 0.13, 0.15), 3.6, true)
	for i in 3:
		var p: Vector2 = grip_a + d * (2.0 + i * 3.0)
		_line(p - n * 1.6, p + d * 1.5 + n * 1.6, Color(0.85, 0.75, 0.55), 0.9, true)
	var blade := PackedVector2Array()
	var edge := PackedVector2Array()
	var base: Vector2 = hand + d * 4.0
	for i in 9:
		var u: float = float(i) / 8.0
		var curve: float = -u * u * 3.2
		blade.append(base + d * (length * u) + n * (curve - 1.6 * (1.0 - u * 0.4)))
		edge.append(base + d * (length * u) + n * (curve + 1.8 * (1.0 - u * 0.6)))
	var tip: Vector2 = base + d * (length + 4.0) + n * -3.6
	_tip = tip
	var poly := PackedVector2Array(blade)
	poly.append(tip)
	edge.reverse()
	poly.append_array(edge)
	_shape(poly, STEEL, 2.0)
	_line(base + n * 0.2, base + d * length * 0.9 + n * -2.4, Color(0.62, 0.74, 0.86), 1.0, true)
	_shape(_ellipse(hand + d * 3.0, 2.2, 4.6, 12, angle), Color(0.25, 0.23, 0.27), 1.8)
	_cur = Part.FX
	if action == Action.CAST:
		var glow: float = phase_t if phase == Phase.WINDUP else 1.0 - phase_t
		_line(base, tip, Color(cast_color, 0.55 * glow), 7.0, true)
	if action == Action.HEAVY and phase == Phase.WINDUP and phase_t > 0.55:
		_draw_glint(tip, (phase_t - 0.55) / 0.45)


func _draw_glint(at: Vector2, k: float) -> void:
	var s: float = 7.0 * sin(PI * clampf(k, 0.0, 1.0))
	if s < 0.5:
		return
	var star := PackedVector2Array([at + Vector2(0, -s), at + Vector2(s * 0.25, -s * 0.25), at + Vector2(s, 0),
			at + Vector2(s * 0.25, s * 0.25), at + Vector2(0, s), at + Vector2(-s * 0.25, s * 0.25),
			at + Vector2(-s, 0), at + Vector2(-s * 0.25, -s * 0.25)])
	_shape(star, Color(1, 0.97, 0.8), 1.4)


## Weapon smear for the attacks: a tapered crescent around the shoulder.
func _draw_smear(center: Vector2) -> void:
	_cur = Part.FX
	if action == Action.NONE or phase == Phase.WINDUP:
		return
	var fade: float = 1.0 if phase == Phase.STRIKE else 1.0 - phase_t
	if fade <= 0.02:
		return
	match action:
		Action.SLASH:
			_crescent(center, deg_to_rad(-80), deg_to_rad(65), 42.0, 12.0, _strike_k(), Color(slash_color, slash_color.a * fade))
		Action.HEAVY:
			_crescent(center, deg_to_rad(-95), deg_to_rad(80), 50.0, 17.0, _strike_k(), Color(heavy_color, heavy_color.a * fade))
		Action.DASH_SLASH:
			var c := Color(dash_slash_color, dash_slash_color.a * fade)
			var streak := PackedVector2Array([Vector2(-72, -20), Vector2(38, -26), Vector2(58, -19),
					Vector2(36, -12), Vector2(-60, -16)])
			_shape(streak, c, 2.0)
			_line(Vector2(-50, -18), Vector2(40, -20), Color(1, 1, 1, 0.8 * fade), 2.0, true)
		Action.CAST:
			if look == Look.HERO:
				var tip: Vector2 = center + Vector2(54, -2)
				var r: float = 6.0 + 14.0 * _strike_k()
				_arc(tip, r, 0.0, TAU, 24, Color(INK, fade), INK_W + 2.0, true)
				_arc(tip, r, 0.0, TAU, 24, Color(cast_color, fade), INK_W, true)
		Action.ATTACK:
			if look == Look.BRUTE or look == Look.BRUTE_TOUGH:
				_crescent(center, deg_to_rad(-120), deg_to_rad(60), 46.0, 14.0, _strike_k(), Color(1.0, 0.86, 0.6, 0.9 * fade))
			elif is_boss():
				_crescent(center, deg_to_rad(-125), deg_to_rad(55), 50.0, 15.0, _strike_k(), Color(_boss_fx_color(), 0.85 * fade))


func _strike_k() -> float:
	return _ease_out(phase_t) if phase == Phase.STRIKE else 1.0


func _crescent(center: Vector2, a0: float, a1: float, radius: float, thickness: float, k: float, color: Color) -> void:
	var end: float = lerpf(a0, a1, clampf(k, 0.05, 1.0))
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var steps: int = 14
	for i in steps + 1:
		var u: float = float(i) / float(steps)
		var a: float = lerpf(a0, end, u)
		var dir := Vector2.from_angle(a)
		outer.append(center + dir * radius)
		inner.append(center + dir * (radius - thickness * sin(PI * clampf(u * 1.05, 0.0, 1.0)) - 0.5))
	inner.reverse()
	var poly := PackedVector2Array(outer)
	poly.append_array(inner)
	_shape(poly, color, 2.0)


# --- Enemies ---

func _enemy_body_color() -> Color:
	match look:
		Look.BRUTE:
			# Pale, bruised purple.
			return Color(0.7, 0.61, 0.73)
		Look.BRUTE_TOUGH:
			return Color(0.58, 0.51, 0.62)
		Look.BANDIT:
			# Sickly grey-green.
			return Color(0.67, 0.69, 0.57)
		Look.SLINGER:
			return Color(0.62, 0.62, 0.53)
		Look.BOSS_WOODCUTTER:
			return Color(0.62, 0.55, 0.5)
		Look.BOSS_SWAMP:
			return Color(0.49, 0.55, 0.41)
		Look.BOSS_STORM:
			return Color(0.41, 0.42, 0.52)
		Look.GRANDFATHER:
			return FEATHER_ELDER
	return Color(0.7, 0.67, 0.74)


## Brute: huge and pale, three bulging eyes, a grin of crooked teeth, a dead wing, a shirt two sizes
## too small and dirty bandages. The armored one adds rusty scrap, a pot helmet and a frying pan.
func _draw_brute() -> void:
	var arm: Vector2 = _weapon_pose()
	var tough: bool = look == Look.BRUTE_TOUGH
	var body: Color = _enemy_body_color()
	var props: int = _mi("props")
	_cur = Part.BODY
	_draw_feet(BEAK_DARK)
	_draw_tail(Vector2(-16, -13), body)
	_shape(_ellipse(Vector2(-1, -15), 18.5, 15.5), body)
	_shape(_ellipse(Vector2(5, -8), 7.5, 5.5, 14), body.lightened(0.14), 1.8)
	_dot(Vector2(6, -7.5), 0.9, Color(INK, 0.7))
	_grime(Vector2(-1, -15), Vector2(16.0, 13.0), 9, 3)
	_hatch(Vector2(-12, -6), 7.0, 4, -0.8, 0.4)
	_draw_small_shirt()
	# Bandage strapped round the belly.
	_draw_bandage(Vector2(-14, -6.5), Vector2(11, -4.5), 3.6)
	if _mb("cracks"):
		_draw_cracks(Vector2(-1, -15), Vector2(14.0, 11.0), 3, 5)
	if tough:
		_draw_scrap_armor()
	if _mb("dead_wing"):
		_draw_dead_wing(Vector2(-14, -24), body)
	if props & PROP_PAN:
		_draw_pan(Vector2(11, -12))
	var shoulder: Vector2 = _shoulder()
	var hand: Vector2 = _hand_point(arm)
	var club_len: float = _weapon_length()
	# A club resting back over the shoulder hides behind the head; a swinging one is in front.
	if cos(arm.y) < -0.3:
		_draw_club(hand, arm.y, club_len, tough)
	_cur = Part.BODY
	_draw_neck(Vector2(2, -26), body)
	var head: Vector2 = _head_center()
	_cur = Part.HEAD
	_draw_head(head, 11.5, body)
	_draw_tufts(head, 11.5, body, 4)
	_grime(head + Vector2(0, 1), Vector2(7.0, 6.0), 3, 41)
	if _mb("beak"):
		_draw_twisted_beak(head + Vector2(7.5, 2.5), 1.15)
	else:
		_draw_beak(head + Vector2(7.5, 2.5), 1.15)
	var eye: Vector2 = head + (Vector2(5, 3.0) if props & PROP_POT else Vector2(5, -3.5))
	_draw_tired_eye(eye, 3.9, INK, body, false)
	_draw_extra_eyes()
	if _mb("drool"):
		_draw_drool(head + Vector2(12, 6), 1.0)
	if props & PROP_POT:
		_draw_pot_helmet(head)
	elif props & PROP_CAN:
		_draw_can_helmet(head)
	else:
		# A filthy bandage wound round the skull.
		_draw_bandage(head + Vector2(-10, -6), head + Vector2(7, -11.5), 3.4)
	if _mb("mask"):
		_draw_gas_mask(head, 11.5)
	_draw_smear(Vector2(0, -24))
	if cos(arm.y) >= -0.3:
		_draw_club(hand, arm.y, club_len, tough)
	_cur = Part.BODY
	_draw_wing(shoulder, hand, body)
	_draw_bandage(shoulder.lerp(hand, 0.35), shoulder.lerp(hand, 0.6), 3.0)
	if props & PROP_PLUSH:
		_draw_plush(Vector2(-8, -5))


## A shirt two sizes too small: rides up over the belly, torn, patched and stained.
func _draw_small_shirt() -> void:
	var cloth := Color(0.6, 0.56, 0.44)
	var shirt := PackedVector2Array([Vector2(-13, -27), Vector2(-4, -30.5), Vector2(6, -30), Vector2(13, -24),
			Vector2(15, -17), Vector2(12, -15), Vector2(9, -17), Vector2(6, -14.5), Vector2(2, -16.5),
			Vector2(-2, -14), Vector2(-6, -16), Vector2(-10, -14.5), Vector2(-14, -17), Vector2(-16.5, -21)])
	_shape(shirt, cloth, 2.2)
	_line(Vector2(4, -29.5), Vector2(7, -17), Color(INK, 0.5), 1.1, true)
	for k in 3:
		_dot(Vector2(4.6 + k * 0.9, -26 + k * 3.6), 0.9, Color(INK, 0.7))
	# Hole showing the feathers, a stitched patch and a dark stain.
	_shape(_ellipse(Vector2(-6, -24), 2.6, 1.9, 10), _enemy_body_color(), 1.4)
	_draw_patch(Vector2(9, -23), 2.6, Color(0.42, 0.45, 0.5), -0.3)
	_poly(_blob(Vector2(-1, -19), Vector2(3.0, 2.2), 8, 17), Color(DIRT, 0.4))
	_hatch(Vector2(-11, -19), 5.0, 3, -0.9, 0.35)


## Rusty scrap riveted over a shoulder and the belly.
func _draw_scrap_armor() -> void:
	var plate := PackedVector2Array([Vector2(-13, -31), Vector2(3, -33), Vector2(8, -24), Vector2(-10, -21)])
	_shape(plate, RUST, 2.2)
	_shape(PackedVector2Array([Vector2(-6, -12), Vector2(7, -13), Vector2(8, -6), Vector2(-5, -5)]), RUST.darkened(0.15), 2.0)
	for p in [Vector2(-10, -29), Vector2(1, -31), Vector2(5, -25.5), Vector2(-8, -23), Vector2(-3.5, -11), Vector2(5.5, -11.5)]:
		_dot(p, 1.0, Color(0.82, 0.7, 0.55))
		_dot(p + Vector2(0.3, 0.3), 0.5, INK)
	for p in [Vector2(-5, -27), Vector2(0, -9), Vector2(-7, -24)]:
		_poly(_blob(p, Vector2(1.8, 1.3), 7, int(p.x * 3.0)), Color(0.72, 0.4, 0.18, 0.7))
	_hatch(Vector2(-9, -25), 5.0, 3, -1.0, 0.45)
	# Wire twisted round the plates.
	_line_strip(PackedVector2Array([Vector2(-10, -21), Vector2(-12, -14), Vector2(-6, -12)]), Color(0.6, 0.6, 0.58), 1.0)


func _draw_club(hand: Vector2, angle: float, length: float, spiked: bool) -> void:
	_cur = Part.WEAPON
	var d := Vector2.from_angle(angle)
	var n: Vector2 = d.orthogonal()
	var poly := PackedVector2Array([hand - d * 6.0 - n * 2.6, hand + d * length - n * 5.2,
			hand + d * (length + 3.0), hand + d * length + n * 5.2, hand - d * 6.0 + n * 2.6])
	_shape(poly, WOOD)
	_line(hand + d * 8.0, hand + d * (length - 4.0), Color(0.38, 0.24, 0.13), 1.2, true)
	var nails: int = 3 if spiked else 2
	for i in nails:
		var p: Vector2 = hand + d * (length - 4.0 - i * 6.0)
		_line(p + n * 4.0, p + n * 8.0, INK, 1.8, true)
		_line(p - n * 4.0, p - n * 8.0, INK, 1.8, true)


## Bandit: skinny and hunched, twitching, split beak full of teeth, red eyes, feathers plucked out,
## a dented can for a helmet.
func _draw_bandit() -> void:
	var arm: Vector2 = _weapon_pose()
	var body: Color = _enemy_body_color()
	_cur = Part.BODY
	_draw_feet(BEAK_DARK)
	_draw_tail(Vector2(-11, -11), body)
	_shape(_ellipse(Vector2(-1, -13), 11.5, 11.0), body)
	if _mb("dead_wing"):
		_draw_dead_wing(Vector2(-9, -19), body)
	# Ribs showing through the plucked chest.
	for k in 3:
		_arc(Vector2(3, -15 + k * 3.0), 4.0, -0.9, 0.7, 6, Color(INK, 0.45), 1.0, true)
	if _mb("bald"):
		_draw_bald_patch(Vector2(-6, -15), Vector2(3.4, 2.6), 0.3)
		_draw_bald_patch(Vector2(1, -6), Vector2(2.4, 1.9), -0.2)
	_grime(Vector2(-1, -13), Vector2(9.0, 8.0), 6, 7)
	_hatch(Vector2(-8, -6), 5.0, 3, -0.8, 0.4)
	if _mb("cracks"):
		_draw_cracks(Vector2(-1, -13), Vector2(9.0, 8.0), 2, 9)
	_draw_neck(Vector2(1, -22), body)
	if _mb("bald"):
		_draw_bald_patch(Vector2(4, -27), Vector2(2.0, 2.6), 0.1)
	# Nervous twitch of the head while it waits.
	var twitch := Vector2.ZERO
	if not dead and not ragdoll and action == Action.NONE:
		twitch = Vector2(sin(_time * 31.0), cos(_time * 27.0)) * 0.35
	var head: Vector2 = _head_center() + twitch
	_cur = Part.HEAD
	_draw_head(head, 10.0, body)
	_draw_tufts(head, 10.0, body, 5)
	if _mb("bald"):
		_draw_bald_patch(head + Vector2(-5, -1), Vector2(2.6, 2.2), 0.4)
	_grime(head + Vector2(1, 2), Vector2(5.0, 4.0), 2, 47)
	if _mb("beak"):
		_draw_twisted_beak(head + Vector2(6.5, 1.5), 0.95)
	else:
		_draw_beak(head + Vector2(6.5, 1.5), 0.95)
	_draw_tired_eye(head + Vector2(4.5, -3.5), 3.4, Color(0.95, 0.16, 0.1), body, true)
	_draw_extra_eyes()
	if _mb("drool"):
		_draw_drool(head + Vector2(11, 5), 0.8)
	if _mi("props") & PROP_CAN:
		_draw_can_helmet(head)
	elif _mi("props") & PROP_POT:
		_draw_pot_helmet(head)
	if _mb("mask"):
		_draw_gas_mask(head, 10.0)
	_draw_smear(Vector2(0, -20))
	var shoulder: Vector2 = _shoulder()
	var hand: Vector2 = _hand_point(arm)
	_draw_shiv(hand, arm.y)
	_cur = Part.BODY
	_draw_wing(shoulder, hand, body)
	if _mi("props") & PROP_PLUSH:
		_draw_plush(Vector2(-7, -4))
	_cur = Part.FX
	if action == Action.ATTACK and phase == Phase.STRIKE:
		for i in 3:
			var y: float = -30.0 + i * 9.0
			_line(Vector2(-34 - i * 4, y), Vector2(-18 - i * 2, y), INK, 2.0, true)


func _draw_shiv(hand: Vector2, angle: float) -> void:
	_cur = Part.WEAPON
	var d := Vector2.from_angle(angle)
	var n: Vector2 = d.orthogonal()
	_line(hand - d * 5.0, hand + d * 2.0, INK, 5.4, true)
	_line(hand - d * 5.0, hand + d * 2.0, Color(0.45, 0.3, 0.2), 2.6, true)
	_shape(PackedVector2Array([hand + d * 2.0 - n * 2.4, hand + d * 15.0 - n * 1.0, hand + d * 19.0,
			hand + d * 13.0 + n * 2.2, hand + d * 2.0 + n * 2.4]), Color(0.78, 0.76, 0.72), 1.8)


## Slinger: gas mask with bright yellow visors under a ragged hood, a torn survivor vest and a
## broken plush toy swinging from the belt.
func _draw_slinger() -> void:
	var arm: Vector2 = _weapon_pose()
	var body: Color = _enemy_body_color()
	var hood := Color(0.36, 0.31, 0.24)
	_cur = Part.BODY
	_draw_feet(BEAK_DARK)
	_draw_tail(Vector2(-13, -12), body)
	# Ragged hood cape over the back.
	_shape(PackedVector2Array([Vector2(-6, -31), Vector2(-15, -24), Vector2(-19, -12), Vector2(-17, -7), Vector2(-14, -10),
			Vector2(-12, -6), Vector2(-9, -12), Vector2(-4, -24)]), hood, 2.2)
	_shape(_ellipse(Vector2(-1, -15), 14.5, 12.5), body)
	if _mb("dead_wing"):
		_draw_dead_wing(Vector2(-11, -22), body)
	_grime(Vector2(-1, -15), Vector2(12.0, 10.0), 6, 13)
	_draw_vest()
	if _mb("cracks"):
		_draw_cracks(Vector2(-1, -15), Vector2(11.0, 9.0), 2, 15)
	# Belt with a bent buckle.
	_shape(PackedVector2Array([Vector2(-15, -8.5), Vector2(13.5, -8.5), Vector2(13, -5.5), Vector2(-14.5, -5.5)]),
			Color(0.33, 0.24, 0.16), 1.8)
	_shape(PackedVector2Array([Vector2(3, -9.2), Vector2(7, -9.4), Vector2(7.2, -4.8), Vector2(3.2, -5)]), Color(0.66, 0.6, 0.42), 1.4)
	if _mi("props") & PROP_PLUSH:
		_draw_plush(Vector2(-12, -9))
	var head: Vector2 = _head_center()
	_cur = Part.HEAD
	_shape(PackedVector2Array([head + Vector2(-13, 8), head + Vector2(-14, -6), head + Vector2(-6, -15),
			head + Vector2(2, -18), head + Vector2(9, -12), head + Vector2(13, -2), head + Vector2(11, 9)]), hood)
	_line(head + Vector2(-9, -9), head + Vector2(-4, -14), Color(INK, 0.5), 1.1, true)
	_draw_patch(head + Vector2(-8, 1), 2.4, Color(0.5, 0.44, 0.3), 0.4)
	if _mb("mask"):
		_shape(_ellipse(head + Vector2(4, 0), 7.5, 8.0), Color(0.09, 0.08, 0.12), 2.0)
		_draw_gas_mask(head, 9.0)
	else:
		_shape(_ellipse(head + Vector2(4, 0), 7.5, 8.0), body, 2.0)
		_draw_beak(head + Vector2(9.5, 3.0), 1.0)
		_draw_tired_eye(head + Vector2(5, -2.5), 3.0, EMBER, body, true)
	_draw_extra_eyes()
	if _mb("drool"):
		_draw_drool(head + Vector2(14, 6), 0.7)
	if _mi("props") & PROP_CAN:
		_draw_can_helmet(head)
	var shoulder: Vector2 = _shoulder()
	var hand: Vector2 = _hand_point(arm)
	_draw_slingshot(hand, shoulder)
	_cur = Part.BODY
	_shape(_ellipse(hand, 4.0, 3.6), hood.lightened(0.15), 2.0)
	_draw_bandage(hand + Vector2(-2.5, -1.5), hand + Vector2(0.5, 1.5), 2.6)


## Survivor vest: torn, with stuffed pockets, a patch and a stain.
func _draw_vest() -> void:
	var cloth := Color(0.4, 0.39, 0.26)
	var vest := PackedVector2Array([Vector2(-12, -25), Vector2(-3, -28.5), Vector2(4, -27.5), Vector2(11, -21),
			Vector2(13.5, -12), Vector2(13, -8), Vector2(9, -10), Vector2(6, -7.5), Vector2(2, -9.5), Vector2(-3, -7.5),
			Vector2(-8, -9.5), Vector2(-14, -8), Vector2(-15, -17)])
	_shape(vest, cloth, 2.2)
	# Open front, pockets with flaps, a missing button.
	_line(Vector2(3, -27.5), Vector2(6, -9), Color(INK, 0.6), 1.3, true)
	for pocket in [Vector2(-6, -18), Vector2(8, -15)]:
		_shape(PackedVector2Array([pocket + Vector2(-3, -2.4), pocket + Vector2(3, -2.4), pocket + Vector2(3, 3), pocket + Vector2(-3, 3)]),
				cloth.darkened(0.12), 1.4)
		_line(pocket + Vector2(-3, -0.6), pocket + Vector2(3, -0.6), Color(INK, 0.6), 1.0, true)
	_draw_patch(Vector2(-9, -23), 2.4, Color(0.55, 0.36, 0.28), 0.2)
	_poly(_blob(Vector2(1, -13), Vector2(2.6, 2.0), 8, 23), Color(DIRT, 0.45))
	_hatch(Vector2(-11, -12), 5.0, 3, -0.9, 0.35)


func _draw_slingshot(hand: Vector2, shoulder: Vector2) -> void:
	_cur = Part.WEAPON
	var fork_l: Vector2 = hand + Vector2(1, -12)
	var fork_r: Vector2 = hand + Vector2(7, -11)
	_line(hand + Vector2(0, 4), hand + Vector2(3, -5), INK, 6.0, true)
	_line(hand + Vector2(0, 4), hand + Vector2(3, -5), WOOD, 3.0, true)
	for tip in [fork_l, fork_r]:
		_line(hand + Vector2(3, -5), tip, INK, 5.2, true)
		_line(hand + Vector2(3, -5), tip, WOOD, 2.4, true)
	# The pouch is pulled back toward the shoulder during the windup and snaps on release.
	var pull: float = 0.0
	if action == Action.ATTACK:
		match phase:
			Phase.WINDUP:
				pull = _ease_out(phase_t)
			Phase.STRIKE:
				pull = 1.0 - _ease_out(phase_t * 3.0)
	var rest: Vector2 = (fork_l + fork_r) * 0.5 + Vector2(-1, 1)
	var pouch: Vector2 = rest.lerp(shoulder + Vector2(-8, 0), pull)
	_line(fork_l, pouch, Color(0.85, 0.82, 0.74), 1.6, true)
	_line(fork_r, pouch, Color(0.85, 0.82, 0.74), 1.6, true)
	if pull > 0.1 or (action == Action.ATTACK and phase == Phase.WINDUP):
		_shape(_ellipse(pouch, 3.2, 3.0, 10), Color(0.55, 0.53, 0.5), 1.8)


# --- Bosses: three guardians built on the same duck ---

func _boss_eye_color() -> Color:
	match look:
		Look.BOSS_SWAMP:
			return Color(0.72, 1.0, 0.36)
		Look.BOSS_STORM:
			return Color(0.56, 0.95, 1.0)
	return EMBER


## Color of the boss's swipe smear and volley flash.
func _boss_fx_color() -> Color:
	match look:
		Look.BOSS_SWAMP:
			return Color(0.62, 0.8, 0.42)
		Look.BOSS_STORM:
			return Color(0.6, 0.92, 1.0)
	return Color(1.0, 0.8, 0.52)


func _draw_boss() -> void:
	var arm: Vector2 = _weapon_pose()
	var body: Color = _enemy_body_color()
	var shoulder: Vector2 = _shoulder()
	var hand: Vector2 = _hand_point(arm)
	var head: Vector2 = _head_center()
	_cur = Part.BODY
	_draw_feet(BEAK_DARK)
	_draw_tail(Vector2(-15, -13), body)
	match look:
		Look.BOSS_WOODCUTTER:
			_draw_back_saw(Vector2(-11, -27))
		Look.BOSS_STORM:
			_draw_star_shards()
	if look == Look.BOSS_SWAMP:
		# Cattail reeds growing out of its back.
		for r in [[Vector2(-10, -24), Vector2(-17, -44)], [Vector2(-6, -26), Vector2(-9, -48)], [Vector2(-13, -20), Vector2(-24, -36)]]:
			_line(r[0], r[1], INK, 3.4, true)
			_line(r[0], r[1], Color(0.48, 0.58, 0.3), 1.6, true)
			_shape(_ellipse(r[1], 2.2, 4.5, 10, (r[1] - r[0]).angle() + PI * 0.5), Color(0.45, 0.3, 0.18), 1.6)
	# The swamp guardian is bloated with bog water.
	if look == Look.BOSS_SWAMP:
		_shape(_ellipse(Vector2(-1, -14), 19.5, 16.0), body)
	else:
		_shape(_ellipse(Vector2(-1, -15), 17.5, 15.0), body)
	_grime(Vector2(-1, -15), Vector2(15.0, 12.0), 10, 19)
	_hatch(Vector2(-12, -6), 7.0, 4, -0.8, 0.45)
	if _mb("dead_wing"):
		_draw_dead_wing(Vector2(-13, -25), body)
	match look:
		Look.BOSS_WOODCUTTER:
			# Plaid work vest over the chest.
			var vest := PackedVector2Array([Vector2(-12, -26), Vector2(8, -27), Vector2(15, -16), Vector2(13, -5),
					Vector2(-14, -4), Vector2(-17, -14)])
			_shape(vest, Color(0.64, 0.24, 0.22))
			for x in [-9.0, -3.0, 3.0, 9.0]:
				_line(Vector2(x, -26), Vector2(x + 1.5, -5), Color(0.34, 0.12, 0.12, 0.8), 1.4, true)
			for y in [-20.0, -12.0]:
				_line(Vector2(-16, y), Vector2(14, y), Color(0.34, 0.12, 0.12, 0.8), 1.4, true)
		Look.BOSS_SWAMP:
			# Moss blobs and dripping mud.
			for m in [[Vector2(-8, -22), 5.5], [Vector2(4, -10), 4.5], [Vector2(-12, -9), 4.0]]:
				_shape(_ellipse(m[0], m[1], m[1] * 0.7, 12), Color(0.31, 0.42, 0.27), 1.6)
			for d in [Vector2(-3, -2), Vector2(7, -4)]:
				_shape(PackedVector2Array([d + Vector2(-2, -3), d + Vector2(2, -3), d + Vector2(0, 3 + sin(_time * 3.0 + d.x))]),
						Color(0.36, 0.3, 0.2), 1.4)
		Look.BOSS_STORM:
			# Jagged scar that glows like a bolt across the chest.
			var bolt := PackedVector2Array([Vector2(2, -27), Vector2(-4, -17), Vector2(1, -17), Vector2(-5, -6),
					Vector2(6, -19), Vector2(1, -19), Vector2(6, -27)])
			_shape(bolt, Color(_boss_eye_color(), 0.75 + 0.25 * sin(_time * 9.0)), 1.6)
	if _mb("bald"):
		_draw_bald_patch(Vector2(8, -21), Vector2(3.6, 2.8), 0.3)
		_draw_bald_patch(Vector2(-13, -16), Vector2(2.8, 3.4), -0.4)
	if _mb("cracks"):
		_draw_cracks(Vector2(-1, -15), Vector2(14.0, 11.0), 5 if _mb("fury") else 3, 29)
	_draw_extra_eyes(true)
	if cos(arm.y) < -0.3:
		_draw_boss_weapon(hand, arm.y)
	_cur = Part.BODY
	_draw_neck(Vector2(2, -27), body)
	_cur = Part.HEAD
	_draw_head(head, 11.5, body)
	if look != Look.BOSS_WOODCUTTER:
		_draw_tufts(head, 11.5, body, 5)
	_grime(head + Vector2(1, 2), Vector2(7.0, 5.0), 3, 53)
	if _mb("beak"):
		_draw_twisted_beak(head + Vector2(7.5, 2.5), 1.2)
	else:
		_draw_beak(head + Vector2(7.5, 2.5), 1.2)
	match look:
		Look.BOSS_WOODCUTTER:
			# Burlap sack hood with stitched seams and two ragged eye holes.
			var sack := PackedVector2Array([head + Vector2(-13, 6), head + Vector2(-14, -6), head + Vector2(-9, -14),
					head + Vector2(0, -17), head + Vector2(9, -14), head + Vector2(13, -5), head + Vector2(12, 3),
					head + Vector2(5, 2), head + Vector2(-3, 7)])
			_shape(sack, Color(0.78, 0.66, 0.44))
			for i in 5:
				var p: Vector2 = head + Vector2(-7 + i * 2.5, -15 + i * 4.0)
				_line(p - Vector2(1.5, 1), p + Vector2(1.5, 1), INK, 1.2, true)
			_shape(_ellipse(head + Vector2(3, -4), 3.4, 3.0), Color(0.08, 0.07, 0.1), 1.6)
			_shape(_ellipse(head + Vector2(9.5, -3.5), 2.6, 3.0), Color(0.08, 0.07, 0.1), 1.6)
			_draw_tired_eye(head + Vector2(3, -4), 2.6, _boss_eye_color(), Color(0.78, 0.66, 0.44), true)
			_draw_tired_eye(head + Vector2(9.5, -3.5), 2.2, _boss_eye_color(), Color(0.78, 0.66, 0.44), true)
			_line(head + Vector2(-12, 6), head + Vector2(6, 8), Color(0.62, 0.5, 0.3), 3.0, true)
		Look.BOSS_SWAMP:
			_draw_tired_eye(head + Vector2(5, -3.5), 3.8, _boss_eye_color(), body, true)
			# Lily pad hat with a notch and a small flower.
			var pad := PackedVector2Array()
			for i in 17:
				var a: float = deg_to_rad(25.0 + 310.0 * float(i) / 16.0)
				pad.append(head + Vector2(-1, -11) + Vector2(cos(a) * 15.0, sin(a) * 4.5))
			pad.append(head + Vector2(-1, -11))
			_shape(pad, Color(0.42, 0.62, 0.34))
			_shape(_ellipse(head + Vector2(-4, -15), 3.0, 2.4), Color(0.96, 0.62, 0.72), 1.6)
			_dot(head + Vector2(-4, -15.5), 1.0, Color(1.0, 0.9, 0.5))
		Look.BOSS_STORM:
			_draw_tired_eye(head + Vector2(5, -3.5), 3.6, _boss_eye_color(), body, true)
			_line(head + Vector2(1, -9), head + Vector2(9, -7.5), INK, 2.4, true)
			_draw_storm_cloud(head + Vector2(-1, -21))
	_draw_extra_eyes(false)
	if _mb("drool"):
		_draw_drool(head + Vector2(13, 7), 1.7 if _mb("fury") else 1.1)
	if _mb("mask"):
		_draw_gas_mask(head, 11.5)
	_cur = Part.FX
	if enraged and not dead and not ragdoll:
		for i in 2:
			var k: float = fmod(_time * 0.8 + i * 0.5, 1.0)
			_shape(_ellipse(head + Vector2(-8 + i * 12, -18 - k * 14), 2.5 + k * 3.0, 2.0 + k * 2.5, 10),
					Color(0.85, 0.85, 0.88, 0.7 * (1.0 - k)), 1.2)
	_draw_smear(shoulder + Vector2(2, 0))
	if cos(arm.y) >= -0.3:
		_draw_boss_weapon(hand, arm.y)
	_cur = Part.BODY
	_draw_wing(shoulder, hand, body)
	_draw_boss_cast_fx()


func _draw_storm_cloud(at: Vector2) -> void:
	var bob: float = sin(_time * 2.0) * 1.5
	var c := at + Vector2(0, bob)
	var grey := Color(0.5, 0.52, 0.6)
	for puff in [[Vector2(-7, 1), 5.0], [Vector2(0, -2), 6.5], [Vector2(7, 1), 5.0], [Vector2(0, 3), 5.0]]:
		_shape(_ellipse(c + puff[0], puff[1], puff[1] * 0.8, 14), grey, 2.0)
	_poly(_ellipse(c + Vector2(0, 1), 9.0, 3.2, 14), grey)
	# A bolt flickers out of the cloud now and then (more often when enraged).
	var flick: float = fmod(_time * (3.0 if enraged else 1.4), 1.0)
	if flick < 0.18 and not ragdoll:
		_cur = Part.FX
		_zigzag(c + Vector2(4, 4), c + Vector2(10, 18), 3, _boss_eye_color())
		_cur = Part.HEAD


func _draw_boss_weapon(hand: Vector2, angle: float) -> void:
	_cur = Part.WEAPON
	var d := Vector2.from_angle(angle)
	var n: Vector2 = d.orthogonal()
	var length: float = _weapon_length()
	_tip = hand + d * length
	match look:
		Look.BOSS_WOODCUTTER:
			# Long-handled axe with a half-moon head.
			_line(hand - d * 8.0, _tip, INK, 6.4, true)
			_line(hand - d * 8.0, _tip, WOOD, 3.6, true)
			var h: Vector2 = hand + d * (length - 6.0)
			var blade := PackedVector2Array([h - d * 5.0 + n * 2.0, h - d * 7.0 + n * 12.0, h + d * 1.0 + n * 15.0,
					h + d * 8.0 + n * 11.0, h + d * 6.0 + n * 2.0])
			_shape(blade, STEEL)
			_line(h - d * 5.0 + n * 12.5, h + d * 7.0 + n * 11.5, Color(0.62, 0.7, 0.78), 1.2, true)
		Look.BOSS_SWAMP:
			# Gnarled root staff topped with a glowing bulb of swamp light.
			var pts := PackedVector2Array()
			for i in 6:
				var u: float = float(i) / 5.0
				pts.append(hand - d * 10.0 + d * (length + 10.0) * u + n * sin(u * 9.0) * 2.2)
			_line_strip(pts, INK, 7.0)
			_line_strip(pts, Color(0.42, 0.3, 0.2), 4.0)
			_shape(_ellipse(_tip, 5.0, 5.0, 14), Color(0.72, 1.0, 0.36, 0.95), 2.0)
			_dot(_tip + Vector2(-1.5, -1.5), 1.5, Color(1, 1, 0.9))
		Look.BOSS_STORM:
			# Lightning rod spear with a forked head.
			_line(hand - d * 12.0, _tip, INK, 5.6, true)
			_line(hand - d * 12.0, _tip, Color(0.62, 0.66, 0.74), 2.8, true)
			for side in [-1.0, 0.0, 1.0]:
				var base: Vector2 = _tip - d * 2.0
				var prong: Vector2 = _tip + d * (8.0 - absf(side) * 2.0) + n * side * 5.0
				_line(base + n * side * 4.0, prong, INK, 4.4, true)
				_line(base + n * side * 4.0, prong, STEEL, 2.0, true)
			_line(_tip - d * 2.0 - n * 4.0, _tip - d * 2.0 + n * 4.0, INK, 4.0, true)
			_cur = Part.FX
			if action != Action.NONE and not ragdoll:
				_zigzag(_tip + d * 6.0, _tip + d * 6.0 + n * 10.0 - d * 8.0, 3, _boss_eye_color())
				_zigzag(_tip + d * 6.0, _tip + d * 6.0 - n * 10.0 - d * 6.0, 3, _boss_eye_color())


## Volley flash: a ring bursting from the weapon tip as the boss throws its projectiles.
func _draw_boss_cast_fx() -> void:
	_cur = Part.FX
	if action != Action.CAST or ragdoll:
		return
	var color: Color = _boss_fx_color()
	if phase == Phase.WINDUP:
		_dot(_tip, 3.0 + 6.0 * phase_t, Color(color, 0.35 + 0.4 * phase_t))
		return
	var fade: float = 1.0 if phase == Phase.STRIKE else 1.0 - phase_t
	var r: float = 6.0 + 12.0 * _strike_k()
	_arc(_tip, r, 0.0, TAU, 24, Color(INK, fade), INK_W + 2.0, true)
	_arc(_tip, r, 0.0, TAU, 24, Color(color, fade), INK_W, true)


func _zigzag(from: Vector2, to: Vector2, kinks: int, color: Color) -> void:
	var seed_step: int = int(_time * 18.0)
	var pts := PackedVector2Array([from])
	var n: Vector2 = (to - from).orthogonal().normalized()
	for i in range(1, kinks + 1):
		var u: float = float(i) / float(kinks + 1)
		var jitter: float = sin(float(seed_step * 13 + i * 7)) * 3.5
		pts.append(from.lerp(to, u) + n * jitter)
	pts.append(to)
	_line_strip(pts, INK, 3.6)
	_line_strip(pts, color, 1.8)


func _draw_glow_eye(at: Vector2, color: Color = EMBER) -> void:
	_draw_tired_eye(at, 2.8, color, _lid_color(), true)


# --- Grandfather: the hero's old samurai master, worn to the bone ---

func _draw_grandfather() -> void:
	var arm: Vector2 = _weapon_pose()
	var feather := FEATHER_ELDER
	var kimono := ELDER_KIMONO
	var shoulder: Vector2 = _shoulder()
	var dir := Vector2.from_angle(arm.x)
	var hand: Vector2 = shoulder + dir * _arm_length()
	var side: Vector2 = dir.orthogonal()
	var head: Vector2 = _head_center()
	if gesture == Gesture.TALK and not dead and not ragdoll:
		head += Vector2(0.0, sin(_time * 6.0) * 0.5)
	_cur = Part.BODY
	_draw_feet(BEAK_DARK)
	_draw_tail(Vector2(-14, -12), feather)
	if gesture == Gesture.HOLD_TORCH:
		# The torch takes the front hand: the cane moves to the back one, planted behind him.
		_draw_cane(Vector2(-8, -13), deg_to_rad(100.0), true)
		_cur = Part.BODY
		_shape(_ellipse(Vector2(-8, -13), 3.0, 2.8), feather, 2.0)
	# Long worn robe, hunched forward, the hem frayed into rags.
	var robe := PackedVector2Array([Vector2(-9, -27.5), Vector2(1, -29), Vector2(10, -25), Vector2(14, -17),
			Vector2(14.5, -9), Vector2(13, -3.5), Vector2(10, -5), Vector2(7, -3), Vector2(3, -4.5), Vector2(-1, -3),
			Vector2(-5, -4.6), Vector2(-9, -3), Vector2(-13, -4.5), Vector2(-16, -3.5), Vector2(-17.5, -11), Vector2(-16, -21)])
	_shape(robe, kimono)
	for f in [[Vector2(-6, -22), Vector2(-9, -6)], [Vector2(4, -20), Vector2(5, -5)], [Vector2(-12, -18), Vector2(-14, -6)]]:
		_line(f[0], f[1], Color(INK, 0.45), 1.2, true)
	_grime(Vector2(-1, -14), Vector2(13.0, 10.0), 8, 61)
	_draw_patch(Vector2(-10, -9), 3.2, Color(0.52, 0.47, 0.38), 0.3)
	_draw_patch(Vector2(8, -8), 2.6, Color(0.33, 0.37, 0.45), -0.2)
	_hatch(Vector2(-13, -12), 7.0, 4, -1.0, 0.4)
	# Crossed collar, grey with age.
	_shape(PackedVector2Array([Vector2(2, -28.5), Vector2(6, -28), Vector2(11, -19), Vector2(8, -17.5)]), Color(0.78, 0.76, 0.66), 2.0)
	# Obi and the sheathed katana he no longer draws.
	_shape(PackedVector2Array([Vector2(-16.5, -15), Vector2(14.2, -15), Vector2(14.4, -11), Vector2(-17, -11)]),
			Color(0.24, 0.23, 0.27), 2.0)
	_draw_sheathed_katana()
	_draw_neck(Vector2(5, -25), feather)
	_cur = Part.HEAD
	_draw_head(head, 11.0, feather)
	_draw_tufts(head, 11.0, feather, 6)
	# Small topknot, half undone.
	_shape(_ellipse(head + Vector2(-6, -11), 2.6, 3.6, 10, -0.6), feather.darkened(0.06), 1.6)
	_line(head + Vector2(-7.5, -9.5), head + Vector2(-4.5, -11.5), Color(0.35, 0.3, 0.4), 1.6, true)
	_grime(head + Vector2(0, 2), Vector2(6.0, 5.0), 3, 67)
	_draw_beak(head + Vector2(7.5, 0.5), 1.0)
	_draw_tired_eye(head + Vector2(4.5, -3.0), 3.0, INK, feather, false, 0.5)
	# Wrinkles at the corner of the eye.
	for k in 2:
		_arc(head + Vector2(8.5 + k * 1.4, -2.5), 2.6 + k, -0.7, 0.6, 5, Color(INK, 0.45), 0.9, true)
	_draw_brows(head, feather)
	# Beard and loose locks (physics strands), then the drooping moustache over them.
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_strands()
	draw_set_transform_matrix(_root)
	_cur = Part.HEAD
	for m in [[head + Vector2(8, 2), head + Vector2(5, 5), head + Vector2(3.5, 10)], [head + Vector2(10, 2.5), head + Vector2(10, 6.5), head + Vector2(8.5, 11)]]:
		var tuft := PackedVector2Array([m[0], m[1], m[2]])
		_line_strip(tuft, INK, 3.8)
		_line_strip(tuft, feather, 2.0)
	# Front arm: the cane (leaning on it or pointing it) or the torch for the prologue.
	if gesture == Gesture.HOLD_TORCH:
		_draw_torch(hand, arm.y)
	else:
		_draw_cane(hand, arm.y, gesture != Gesture.POINT)
	_cur = Part.BODY
	var sleeve := Geometry2D.convex_hull(PackedVector2Array([
		shoulder - side * 5.0, hand - side * 4.0, hand + side * 5.0,
		shoulder.lerp(hand, 0.6) + Vector2(0, 9), shoulder + side * 6.0 + Vector2(0, 5)]))
	sleeve.remove_at(sleeve.size() - 1)
	_shape(sleeve, kimono)
	_grime(shoulder.lerp(hand, 0.5) + Vector2(0, 3), Vector2(3.0, 3.0), 2, 71)
	_line(hand - side * 4.0, hand + side * 5.0, Color(0.78, 0.76, 0.66), 2.0, true)
	_shape(_ellipse(hand, 3.2, 2.9), feather, 2.0)
	_dot(hand + Vector2(0.8, -0.6), 0.7, Color(DIRT, 0.6))


## Long, untidy eyebrows that droop past the eye.
func _draw_brows(c: Vector2, color: Color) -> void:
	var lines: Array = [[c + Vector2(1, -7.5), c + Vector2(6, -9.2), c + Vector2(11, -7.6), c + Vector2(13.5, -4)],
			[c + Vector2(2, -6.6), c + Vector2(7, -8.0), c + Vector2(11.5, -5.8), c + Vector2(12.5, -2.5)]]
	for l in lines:
		var pts := PackedVector2Array([l[0], l[1], l[2], l[3]])
		_line_strip(pts, INK, 3.4)
		_line_strip(pts, color, 1.7)
	_line(c + Vector2(5, -9), c + Vector2(5.5, -12), INK, 1.0, true)
	_line(c + Vector2(8, -8.6), c + Vector2(9.5, -11.4), INK, 1.0, true)


func _draw_sheathed_katana() -> void:
	_cur = Part.BODY
	var mouth := Vector2(9, -14)
	var end := Vector2(-20, -7.5)
	# Scuffed black scabbard sticking out behind him.
	_line(mouth, end, INK, 6.0, true)
	_line(mouth, end, Color(0.17, 0.14, 0.16), 3.4, true)
	for k in 3:
		_dot(mouth.lerp(end, 0.25 + 0.25 * k), 0.7, Color(0.55, 0.5, 0.45, 0.8))
	_dot(end, 2.4, INK)
	_dot(end, 1.4, Color(0.55, 0.45, 0.3))
	# Guard and the wrapped hilt pointing forward and up.
	_shape(_ellipse(mouth, 1.6, 3.6, 10, -0.28), Color(0.35, 0.3, 0.26), 1.6)
	var grip_end := Vector2(17, -18)
	_line(mouth, grip_end, INK, 5.0, true)
	_line(mouth, grip_end, Color(0.3, 0.2, 0.2), 2.8, true)
	for k in 3:
		var p: Vector2 = mouth.lerp(grip_end, 0.25 + 0.25 * k)
		_line(p + Vector2(-0.6, -1.2), p + Vector2(0.6, 1.2), Color(0.8, 0.72, 0.55), 0.9, true)


## Knotted walking cane. `planted` stretches it down to the floor.
func _draw_cane(hand: Vector2, angle: float, planted: bool) -> void:
	_cur = Part.WEAPON
	var d := Vector2.from_angle(angle)
	var length: float = 32.0
	if planted and d.y > 0.2:
		length = clampf((0.0 - hand.y) / d.y + 1.0, 10.0, 44.0)
	var end: Vector2 = hand + d * length
	var top: Vector2 = hand - d * 4.0
	_line(top, end, INK, 5.4, true)
	_line(top, end, WOOD.darkened(0.12), 3.0, true)
	for k in 3:
		_dot(top.lerp(end, 0.3 + 0.25 * k), 1.0, Color(INK, 0.7))
	# Crook handle.
	_arc(top - d * 2.4, 2.6, angle + PI * 0.5, angle + PI * 1.5, 8, INK, 4.6, true)
	_arc(top - d * 2.4, 2.6, angle + PI * 0.5, angle + PI * 1.5, 8, WOOD.darkened(0.12), 2.2, true)
	_tip = end


## Torch held up for the prologue: rag-wrapped stick and a flickering flame that always burns upward.
func _draw_torch(hand: Vector2, angle: float) -> void:
	_cur = Part.WEAPON
	var d := Vector2.from_angle(angle)
	var top: Vector2 = hand + d * 16.0
	_line(hand - d * 6.0, top, INK, 5.6, true)
	_line(hand - d * 6.0, top, WOOD.darkened(0.15), 3.2, true)
	_shape(_ellipse(top, 3.4, 4.6, 12, angle + PI * 0.5), Color(0.36, 0.29, 0.22), 1.8)
	for k in 2:
		var p: Vector2 = top + d * (k * 2.4 - 1.2)
		_line(p + d.orthogonal() * 3.2, p - d.orthogonal() * 3.2, Color(INK, 0.6), 1.0, true)
	_tip = top
	_cur = Part.FX
	if ragdoll or dead:
		return
	var up: Vector2 = Vector2.UP.rotated(-_lean)
	var right: Vector2 = -up.orthogonal()
	var base: Vector2 = top + up * 3.0
	var flicker: float = 0.5 + 0.5 * sin(_time * 11.0) * sin(_time * 7.3 + 1.0)
	_dot(base + up * 6.0, 26.0 + flicker * 4.0, Color(1.0, 0.62, 0.22, 0.1))
	_dot(base + up * 6.0, 13.0 + flicker * 2.0, Color(1.0, 0.7, 0.3, 0.16))
	var layers: Array = [[16.0, 5.6, Color(0.9, 0.32, 0.12), true], [11.5, 4.0, Color(1.0, 0.6, 0.18), false], [7.0, 2.4, Color(1.0, 0.9, 0.52), false]]
	for i in layers.size():
		var spec: Array = layers[i]
		var h: float = float(spec[0]) * (1.0 + 0.14 * sin(_time * 13.0 + i * 1.7) + 0.08 * flicker)
		var w: float = spec[1]
		var sway: float = sin(_time * 9.0 + i) * 1.6 + sin(_time * 4.1) * 1.0
		var flame := PackedVector2Array()
		for j in 9:
			var a: float = PI * float(j) / 8.0
			flame.append(base + right * cos(a) * w - up * sin(a) * w * 0.7)
		flame.append(base + up * h * 0.38 - right * w * 0.8)
		flame.append(base + up * h + right * sway)
		flame.append(base + up * h * 0.38 + right * w * 0.8)
		if bool(spec[3]):
			_shape(flame, spec[2], 1.6)
		else:
			_poly(flame, spec[2])
	# Sparks rising off the flame.
	for k in 3:
		var u: float = fposmod(_time * 0.9 + k * 0.33, 1.0)
		var spark: Vector2 = base + up * (14.0 + u * 22.0) + right * sin(_time * 3.0 + k * 2.0) * 4.0
		_dot(spark, 1.1 * (1.0 - u) + 0.3, Color(1.0, 0.75, 0.3, 1.0 - u))


# --- Shared parts ---

func _draw_feet(color: Color) -> void:
	var tuck: bool = (not grounded or dashing) and not ragdoll
	for side in [-1.0, 1.0]:
		var ph: float = _run_phase + (0.0 if side > 0.0 else PI)
		var base_x: float = 5.0 * side
		var foot := Vector2(base_x, 0.0)
		if tuck:
			foot = Vector2(base_x - 2.0, -4.0 + (1.5 if side < 0.0 else 0.0))
		elif ground_speed > 5.0 and not ragdoll:
			foot = Vector2(base_x + sin(ph) * 6.5, -maxf(0.0, cos(ph)) * 4.5)
		var hip := Vector2(base_x * 0.6, -6.0)
		_line(hip, foot, INK, 5.0, true)
		_line(hip, foot, color, 2.4, true)
		var shade: Color = color if side > 0.0 else color.darkened(0.12)
		_shape(PackedVector2Array([foot + Vector2(-3, 0), foot + Vector2(7, 0), foot + Vector2(8, -2),
				foot + Vector2(1.5, -3.6), foot + Vector2(-3, -2.6)]), shade, 2.0)


func _draw_tail(at: Vector2, color: Color) -> void:
	var wag: float = sin(_time * 5.0) * 1.2 if ground_speed < 5.0 else sin(_run_phase * 2.0) * 1.6
	if ragdoll:
		wag = 0.0
	# Short upturned tuft: one curled tip, the way a duck tail flicks up.
	_shape(PackedVector2Array([at + Vector2(3, -5), at + Vector2(-4, -8), at + Vector2(-9, -13 + wag),
			at + Vector2(-8, -7 + wag * 0.5), at + Vector2(-6, -1), at + Vector2(3, 4)]), color, 2.4)


func _draw_neck(base: Vector2, color: Color = PAPER) -> void:
	_shape(PackedVector2Array([base + Vector2(-4, 0), base + Vector2(7, 0), base + Vector2(10, -11),
			base + Vector2(-1, -13)]), color)


func _draw_head(c: Vector2, r: float, color: Color = PAPER) -> void:
	_shape(_ellipse(c, r, r * 0.98, 22), color)


func _draw_beak(at: Vector2, s: float) -> void:
	var open: float = 0.0
	if hurt or ragdoll:
		open = 2.5
	elif action != Action.NONE and phase == Phase.STRIKE:
		open = 1.5
	elif look == Look.GRANDFATHER and gesture == Gesture.TALK and not dead:
		open = absf(sin(_time * 12.0)) * 2.4 + absf(sin(_time * 4.3)) * 0.6
	_shape(PackedVector2Array([at + Vector2(-1, -4) * s, at + Vector2(10, -3) * s, at + Vector2(12.5, -0.5) * s,
			at + Vector2(10, 1.5) * s, at + Vector2(-1, 1.5) * s]), BEAK, 2.2)
	_shape(PackedVector2Array([at + Vector2(-1, 1.5) * s, at + Vector2(9, 1.5) * s,
			at + Vector2(8, 3.5 + open) * s, at + Vector2(-1, 3.5 + open * 0.6) * s]), BEAK_DARK, 2.0)
	# Chipped edge and grime.
	_line(at + Vector2(6, -3.4) * s, at + Vector2(7, -2.2) * s, Color(INK, 0.6), 1.0, true)
	_dot(at + Vector2(3, -1.5) * s, 1.1 * s, Color(DIRT, 0.35 * minf(_wear_k(), 1.0)))


## Twisted, split beak hanging open on a row of crooked teeth.
func _draw_twisted_beak(at: Vector2, s: float) -> void:
	var open: float = 2.0
	if hurt or ragdoll:
		open = 3.2
	elif action != Action.NONE and phase == Phase.STRIKE:
		open = 3.0
	var mouth := PackedVector2Array([at + Vector2(-1, 0.6) * s, at + Vector2(9.5, -0.2) * s,
			at + Vector2(9.0, 1.6 + open * 0.4) * s, at + Vector2(-1, 1.8) * s])
	_shape(mouth, Color(0.22, 0.08, 0.1), 1.4)
	var lower := PackedVector2Array([at + Vector2(-1, 1.6) * s, at + Vector2(9, 1.4 + open * 0.4) * s,
			at + Vector2(10.5, 3.2 + open) * s, at + Vector2(7, 4.6 + open) * s, at + Vector2(-1, 3.8 + open * 0.6) * s])
	_shape(lower, BEAK_DARK, 2.0)
	for i in 2:
		var x: float = 3.0 + i * 3.4
		var y: float = 1.6 + open * 0.4 * (x / 9.0)
		var up: float = 1.3 * (1.7 if _toon() else 1.0)
		_shape(PackedVector2Array([at + Vector2(x - 0.9, y + 0.2) * s, at + Vector2(x + 0.9, y + 0.1) * s,
				at + Vector2(x + 0.4 - i * 0.8, y - up) * s]), TOOTH, 0.9)
	var upper := PackedVector2Array([at + Vector2(-1, -4) * s, at + Vector2(4, -4.4) * s, at + Vector2(7.5, -5.6) * s,
			at + Vector2(11, -4.6) * s, at + Vector2(12.5, -2.6) * s, at + Vector2(10, -0.6) * s, at + Vector2(6, 0.4) * s,
			at + Vector2(2.5, 0.2) * s, at + Vector2(-1, 1.0) * s])
	_shape(upper, BEAK, 2.2)
	var fang: float = 1.75 if _toon() else 1.0
	for i in 4:
		var x: float = 1.0 + i * 2.3
		var h: float = (1.2 + _hash(i * 7 + 1) * 1.4) * fang
		var lean: float = (_hash(i * 7 + 2) - 0.5) * 1.6
		var half_w: float = 0.8 * (1.3 if fang > 1.0 else 1.0)
		_shape(PackedVector2Array([at + Vector2(x - half_w, 0.3) * s, at + Vector2(x + half_w, 0.1) * s,
				at + Vector2(x + lean, 0.3 + h) * s]), TOOTH, 1.1 if fang > 1.0 else 0.9)
	# The split running down the beak.
	_line_strip(PackedVector2Array([at + Vector2(5.2, -4.8) * s, at + Vector2(6.0, -2.8) * s, at + Vector2(5.2, -1.2) * s,
			at + Vector2(5.8, 0.3) * s]), INK, 1.4)


func _draw_eye(at: Vector2, glow: bool) -> void:
	_draw_tired_eye(at, 3.4, EMBER if glow else INK, _lid_color(), glow)


## Feathers (or skin) the eyelids are made of.
func _lid_color() -> Color:
	match look:
		Look.HERO:
			return FEATHER_HERO
		Look.GRANDFATHER:
			return FEATHER_ELDER
	return _enemy_body_color()


## Big bulging survivor eye: dark bags, a heavy drooping lid, a tiny pupil that darts around.
## `glow` makes the iris burn with `iris` (corrupted ducks); otherwise `iris` is the pupil color.
func _draw_tired_eye(at: Vector2, r: float, iris: Color, lid: Color, glow: bool, droop: float = -1.0) -> void:
	var k: float = minf(_wear_k(), 1.0)
	var toon: bool = _toon()
	if toon:
		# Cartoon: bigger, bulging eyes over thick dark bags.
		r *= 1.32
	var bag := Color(BAGS.darkened(0.3) if toon else BAGS, (0.6 if toon else 0.3) + 0.35 * k)
	_arc(at + Vector2(0, r * 0.45), r * 1.05, PI * 0.18, PI * 0.82, 8, bag, 3.2 if toon else 1.8, true)
	_arc(at + Vector2(-0.3, r * 0.95), r * 0.85, PI * 0.25, PI * 0.75, 6, Color(bag, bag.a * 0.6), 2.2 if toon else 1.2, true)
	if dead or ragdoll:
		_draw_x_eye(at, r * 0.72)
		return
	if hurt:
		_line(at + Vector2(-r * 0.7, -r * 0.6), at + Vector2(r * 0.5, 0), INK, 1.8, true)
		_line(at + Vector2(r * 0.5, 0), at + Vector2(-r * 0.7, r * 0.6), INK, 1.8, true)
		return
	var period: float = 3.9 + _hash(int(at.x * 5.0) + 3) * 1.4
	if fmod(_time + _hash(int(at.y * 7.0)) * 3.0, period) > period - 0.13:
		_line(at + Vector2(-r, 0.4), at + Vector2(r, 0.4), INK, 1.8, true)
		return
	if glow:
		_dot(at, r * (1.9 if enraged else 1.5), Color(iris, 0.22))
	_shape(_ellipse(at, r, r * 1.08, 14), SCLERA, 2.2 if toon else 1.7)
	# Tiny pupil that darts from spot to spot, never quite still.
	var rate: float = 1.7 if look == Look.BANDIT else 0.7
	var step: int = int(floorf(_time * rate + _hash(int(at.y * 5.0)) * 5.0))
	var gaze := Vector2(_hash(step * 3 + 1) - 0.3, _hash(step * 3 + 2) - 0.5) * r * 0.75
	gaze += Vector2(sin(_time * 17.0), cos(_time * 13.0)) * 0.12
	var pupil: Vector2 = at + gaze.limit_length(r * 0.5)
	if glow:
		_dot(pupil, r * (0.36 if toon else 0.5), iris)
		_dot(pupil, r * (0.15 if toon else 0.2), INK)
	else:
		_dot(pupil, r * (0.17 if toon else 0.27), iris)
		_dot(pupil + Vector2(0.3, -0.4), 0.35, PAPER)
	_draw_lid(at, r, droop if droop >= 0.0 else 0.3 + 0.12 * k, lid)


## Heavy upper eyelid covering `cover` (0..1) of the eye from the top.
func _draw_lid(at: Vector2, r: float, cover: float, color: Color) -> void:
	var c: float = clampf(cover, 0.05, 0.85)
	var rx: float = r + 0.5
	var ry: float = r * 1.08 + 0.5
	var s0: float = clampf(-1.0 + 2.0 * c, -0.95, 0.95)
	var a0: float = PI - asin(s0)
	var a1: float = TAU + asin(s0)
	var pts := PackedVector2Array()
	for i in 9:
		var a: float = lerpf(a0, a1, float(i) / 8.0)
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry))
	pts.append(at + Vector2(0.0, s0 * ry + 0.8))
	_shape(pts, color, 1.6)


## A corrupted extra eye: misaligned, glowing, blinking out of step with the others.
func _draw_mutant_eye(at: Vector2, r: float, salt: int) -> void:
	if dead or ragdoll:
		_draw_x_eye(at, r * 0.7)
		return
	var period: float = 2.2 + _hash(salt) * 2.6
	var t: float = fposmod(_time + _hash(salt + 1) * period, period)
	var pulse: float = 0.6 + 0.4 * sin(_time * 4.0 + salt)
	var tilt: float = (_hash(salt + 3) - 0.5) * 0.8
	var shape := _ellipse(at, r, r * (0.9 + _hash(salt + 2) * 0.3), 12, tilt)
	_dot(at, r * 1.9, Color(CORRUPT, (0.3 if _toon() else 0.16) * pulse))
	if t > period - 0.16:
		_shape(shape, _lid_color(), 1.5)
		_line(at - Vector2(r, 0).rotated(tilt), at + Vector2(r, 0).rotated(tilt), INK, 1.2, true)
		return
	_shape(shape, Color(1.0, 0.86, 0.55), 1.5)
	var pupil: Vector2 = at + Vector2(sin(_time * 1.3 + salt), cos(_time * 1.1 + salt * 2)) * r * 0.3
	_dot(pupil, r * 0.5, CORRUPT.lerp(Color(1, 0.85, 0.4), 0.3 * pulse))
	_dot(pupil, r * 0.22, INK)


## Where each look grows its extra eyes: [position, radius, on the body (not the head)].
func _extra_eye_spots() -> Array:
	var c: Vector2 = _head_center()
	match look:
		Look.BOSS_SWAMP:
			return [[Vector2(-7, -21), 3.2, true], [Vector2(6, -11), 2.8, true], [Vector2(-12, -9), 2.3, true], [Vector2(3, -25), 2.0, true]]
		Look.BOSS_STORM:
			return [[c + Vector2(1, -10), 2.6, false], [c + Vector2(-6, -6), 2.1, false], [c + Vector2(-8, 2), 1.9, false], [c + Vector2(9, -10), 1.6, false]]
		Look.BOSS_WOODCUTTER:
			return [[c + Vector2(-4, -9), 2.4, false], [c + Vector2(-9, -2), 2.0, false], [c + Vector2(6, -11), 1.8, false], [c + Vector2(-3, 3), 1.6, false]]
		Look.BRUTE_TOUGH:
			return [[c + Vector2(-2.5, 4.5), 2.6, false], [c + Vector2(-7.5, 6.5), 2.0, false], [c + Vector2(0, 9), 1.6, false]]
		Look.BRUTE:
			return [[c + Vector2(-3, -2), 2.9, false], [c + Vector2(-8.5, 3.5), 2.2, false], [c + Vector2(0.5, 6.5), 1.7, false]]
	return [[c + Vector2(-3, -7), 2.3, false], [c + Vector2(-7, 0), 1.9, false], [c + Vector2(0, 5), 1.6, false], [c + Vector2(-5, 5), 1.4, false]]


func _draw_extra_eyes(body_spots: bool = false) -> void:
	var n: int = _mi("eyes")
	if n <= 0:
		return
	var spots: Array = _extra_eye_spots()
	for i in mini(n, spots.size()):
		var spot: Array = spots[i]
		if bool(spot[2]) != body_spots:
			continue
		_cur = Part.BODY if body_spots else Part.HEAD
		var at: Vector2 = spot[0]
		var r: float = float(spot[1]) * (1.35 if _toon() else 1.0)
		if look == Look.BOSS_WOODCUTTER:
			# A new ragged hole torn in the sack for each eye.
			_shape(_ellipse(at, r * 1.4, r * 1.25, 10), Color(0.08, 0.07, 0.1), 1.4)
		_draw_mutant_eye(at, r, i * 17 + 5)


func _draw_x_eye(at: Vector2, s: float) -> void:
	_line(at + Vector2(-s, -s), at + Vector2(s, s), INK, 1.8, true)
	_line(at + Vector2(-s, s), at + Vector2(s, -s), INK, 1.8, true)


func _draw_wing(shoulder: Vector2, hand: Vector2, color: Color) -> void:
	var d: Vector2 = (hand - shoulder).normalized()
	var n: Vector2 = d.orthogonal()
	_shape(PackedVector2Array([shoulder - n * 5.0, hand - n * 3.5, hand + d * 4.5, hand + n * 4.0,
			shoulder + n * 6.0 + Vector2(0, 3)]), color, 2.4)
	_line(hand - n * 1.0, hand + d * 3.0 - n * 0.5, Color(INK, 0.6), 1.2, true)


# =====================================================================================
# Wear and mutations (drawn in rig space, so they move with the body)
# =====================================================================================

## Soft pale halo behind the hero's body and head.
func _draw_rim(body_c: Vector2, body_r: Vector2, head_c: Vector2, head_r: float) -> void:
	_cur = Part.FX
	if ragdoll:
		return
	var rim := Color(1.0, 0.94, 0.8, 0.28)
	_poly(_ellipse(body_c, body_r.x + 2.8, body_r.y + 2.8, 20), rim)
	_poly(_ellipse(head_c, head_r + 2.6, head_r + 2.4, 20), rim)


## Irregular smudges of dust and soot spread over an ellipse.
func _grime(center: Vector2, r: Vector2, count: int, salt: int) -> void:
	var k: float = _wear_k()
	if k <= 0.01:
		return
	var n: int = int(roundf(float(count) * minf(k, 1.0) + maxf(k - 1.0, 0.0) * 3.0))
	for i in n:
		var a: float = _hash(salt + i * 3) * TAU
		var rr: float = sqrt(_hash(salt + i * 3 + 1)) * 0.75
		var p: Vector2 = center + Vector2(cos(a) * r.x, sin(a) * r.y) * rr
		var s: float = (1.3 + _hash(salt + i * 3 + 2) * 2.4) * (1.6 if _toon() else 1.0)
		var col: Color = SOOT if i % 3 == 0 else DIRT
		var alpha: float = (0.4 + 0.2 * _hash(salt + i * 7)) if _toon() else (0.2 + 0.15 * _hash(salt + i * 7))
		_poly(_blob(p, Vector2(s * 1.35, s), 7, salt + i * 11), Color(col.darkened(0.15) if _toon() else col, alpha * minf(k, 1.0)))
		if i % 4 == 1:
			_dot(p + Vector2(s * 1.6, -s * 0.4), 0.55, Color(col, 0.5 * minf(k, 1.0)))


## A few short parallel pen strokes, the hand-drawn shading of a shadow.
func _hatch(at: Vector2, length: float, count: int, angle: float, alpha: float) -> void:
	var k: float = minf(_wear_k(), 1.0)
	if k <= 0.05:
		return
	var d := Vector2.from_angle(angle)
	var n: Vector2 = d.orthogonal()
	for i in count:
		var p: Vector2 = at + n * (float(i) - float(count - 1) * 0.5) * 1.8
		var l: float = length * (0.7 + 0.3 * _hash(i * 5 + int(at.x)))
		_line(p - d * l * 0.5, p + d * l * 0.5, Color(INK, alpha * k), 0.9, true)


## Greasy feathers standing up out of the crown and the back of the head.
func _draw_tufts(c: Vector2, r: float, color: Color, count: int) -> void:
	var k: float = maxf(minf(_wear_k(), 1.2), 0.3)
	for i in count:
		var a: float = deg_to_rad(-70.0 - 150.0 * float(i) / float(maxi(count - 1, 1))) + (_hash(i * 5 + 3) - 0.5) * 0.3
		var base: Vector2 = c + Vector2.from_angle(a) * (r - 1.0)
		var length: float = (3.5 + _hash(i * 5 + 1) * 4.0) * (0.7 + 0.3 * k) * (1.8 if _toon() else 1.0)
		var bend: float = (_hash(i * 5 + 2) - 0.5) * 0.9
		var sway: float = 0.0 if ragdoll else sin(_time * 2.4 + i) * 0.08
		var tip: Vector2 = base + Vector2.from_angle(a + bend + sway) * (length + 1.0)
		var side: Vector2 = Vector2.from_angle(a).orthogonal() * (1.4 + _hash(i * 5 + 4))
		_shape(PackedVector2Array([base - side, tip, base + side]), color, 1.6)
		if i % 2 == 0:
			_line(base, base.lerp(tip, 0.6), Color(1.0, 1.0, 0.9, 0.3), 0.8, true)
	# A couple of loose hairs.
	_line_strip(PackedVector2Array([c + Vector2(-2, -r), c + Vector2(-1, -r - 4), c + Vector2(1.5, -r - 5)]), INK, 0.9)


## Square of cloth sewn on with big crude stitches.
func _draw_patch(at: Vector2, s: float, color: Color, rot: float) -> void:
	if _toon():
		s *= 1.3
	var corners := PackedVector2Array()
	for v in [Vector2(-s, -s), Vector2(s, -s * 0.9), Vector2(s * 1.05, s), Vector2(-s * 0.95, s * 1.05)]:
		corners.append(at + (v as Vector2).rotated(rot))
	_shape(corners, color, 1.5)
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var n: Vector2 = (b - a).orthogonal().normalized()
		for t in [0.33, 0.66]:
			var p: Vector2 = a.lerp(b, t)
			_line(p - n * 1.2, p + n * 1.2, INK, 1.3 if _toon() else 0.9, true)


## Dirty bandage wound between two points, with a rusty stain.
func _draw_bandage(a: Vector2, b: Vector2, w: float) -> void:
	if _toon():
		w *= 1.35
	_line(a, b, INK, w + 2.2, true)
	_line(a, b, BANDAGE, w, true)
	var d: Vector2 = b - a
	var count: int = maxi(int(d.length() / 2.4), 1)
	var dir: Vector2 = d.normalized()
	var n: Vector2 = dir.orthogonal()
	for i in count:
		var p: Vector2 = a.lerp(b, (float(i) + 0.5) / float(count))
		_line(p - n * w * 0.5 + dir * 0.6, p + n * w * 0.5 - dir * 0.6, Color(INK, 0.45), 0.9, true)
	_dot(a.lerp(b, 0.6), w * (0.42 if _toon() else 0.3), Color(0.55, 0.3, 0.22, 0.75 if _toon() else 0.45))


## Bare patch of pale pink skin where the feathers were torn out, stitched shut.
func _draw_bald_patch(at: Vector2, r: Vector2, rot: float) -> void:
	_shape(_ellipse(at, r.x, r.y, 12, rot), SKIN, 1.5)
	var d := Vector2.from_angle(rot)
	var n: Vector2 = d.orthogonal()
	_line(at - d * r.x * 0.75, at + d * r.x * 0.75, Color(0.55, 0.28, 0.3), 1.0, true)
	for i in 3:
		var p: Vector2 = at + d * r.x * (-0.5 + 0.5 * float(i))
		_line(p - n * 1.1, p + n * 1.1, INK, 0.9, true)
	_dot(at + Vector2(r.x * 0.3, r.y * 0.45), 0.4, Color(INK, 0.5))
	_dot(at + Vector2(-r.x * 0.4, -r.y * 0.4), 0.4, Color(INK, 0.5))


## Glowing fractures over the body, like a broken star shining through: they pulse.
func _draw_cracks(center: Vector2, r: Vector2, count: int, salt: int) -> void:
	var pulse: float = 0.6 + 0.4 * sin(_time * (5.0 if _mb("fury") else 3.0) + salt)
	if dead or ragdoll:
		pulse = 0.2
	for i in count:
		var a: float = _hash(salt + i * 13) * TAU
		var p: Vector2 = center + Vector2(cos(a) * r.x, sin(a) * r.y) * (0.2 + 0.3 * _hash(salt + i * 13 + 1))
		var pts := PackedVector2Array([p])
		var dir: float = a + (_hash(salt + i * 13 + 2) - 0.5)
		for j in 3:
			dir += (_hash(salt + i * 13 + j + 3) - 0.5) * 1.4
			p += Vector2.from_angle(dir) * r.x * 0.22
			pts.append(p)
		_line_strip(pts, Color(CORRUPT, 0.25 * pulse), 5.5)
		_line_strip(pts, INK, 2.8)
		_line_strip(pts, Color(CORRUPT.lerp(Color(1.0, 0.9, 0.55), 0.5 * pulse), 0.6 + 0.4 * pulse), 1.3)


## Dark drool stretching from the beak, dripping off now and then.
func _draw_drool(at: Vector2, amount: float) -> void:
	if _toon():
		amount *= 1.6
	var cycle: float = fposmod(_time * 0.45 + float(int(look)) * 0.3, 1.0)
	var full: float = 10.0 * amount
	var length: float = lerpf(2.0, full, _ease_out(cycle / 0.8)) if cycle < 0.8 else full * (1.0 - (cycle - 0.8) / 0.2 * 0.6)
	if ragdoll:
		length = full * 0.4
	# Hangs toward the floor whatever the lean.
	var down: Vector2 = Vector2.DOWN.rotated(-_lean)
	var end: Vector2 = at + down * length + Vector2(sin(_time * 3.0) * 0.8, 0.0)
	var mid: Vector2 = at.lerp(end, 0.5) + Vector2(0.6, 0.0)
	var strand := PackedVector2Array([at, mid, end])
	_line_strip(strand, INK, 3.6 if _toon() else 2.8)
	_line_strip(strand, DROOL, 2.2 if _toon() else 1.5)
	var blob: float = 1.3 + amount * 0.5
	_dot(end, blob + 0.7, INK)
	_dot(end, blob, DROOL)
	_dot(end + Vector2(-0.4, -0.4), 0.4, Color(1, 1, 1, 0.4))
	if cycle > 0.8 and not ragdoll:
		_cur = Part.FX
		_dot(end + down * (cycle - 0.8) / 0.2 * 14.0, 1.1, DROOL)


## A limp wing hanging off the back, ragged and bandaged.
func _draw_dead_wing(root: Vector2, color: Color) -> void:
	var swing: float = (0.0 if ragdoll else sin(_time * 1.6) * 0.06) - _lean * 0.6
	var u: Vector2 = Vector2(-0.55, 1.0).normalized().rotated(swing)
	var v: Vector2 = -u.orthogonal()
	var length: float = 19.0
	var back := PackedVector2Array()
	var front := PackedVector2Array()
	for i in 6:
		var t: float = float(i) / 5.0
		var along: Vector2 = root + u * length * t + v * sin(t * PI) * 1.5
		back.append(along + v * (3.5 - 2.7 * t))
		var zig: float = 1.6 if i % 2 == 1 else 0.0
		front.append(along - v * (1.0 + 2.5 * (1.0 - t) + zig))
	front.reverse()
	back.append_array(front)
	_shape(back, color.darkened(0.1), 2.2)
	for t in [0.35, 0.6, 0.82]:
		var p: Vector2 = root + u * length * t
		_line(p + v * 2.0, p - v * 2.2 + u * 2.0, Color(INK, 0.55), 1.0, true)
	var mid: Vector2 = root + u * length * 0.45
	_draw_bandage(mid - v * 3.2, mid + v * 3.4, 2.6)


## Dark rubber gas mask: two round yellow visors and a round filter where the beak was.
func _draw_gas_mask(c: Vector2, r: float) -> void:
	var rubber := Color(0.2, 0.2, 0.19)
	_line(c + Vector2(-r * 0.2, -r * 0.85), c + Vector2(-r * 0.95, -r * 0.1), INK, 3.6, true)
	_line(c + Vector2(-r * 0.2, -r * 0.85), c + Vector2(-r * 0.95, -r * 0.1), Color(0.3, 0.28, 0.25), 2.0, true)
	var plate := PackedVector2Array([c + Vector2(-1, -r * 0.75), c + Vector2(5, -r * 0.85), c + Vector2(r * 0.95, -r * 0.45),
			c + Vector2(r + 3, 0), c + Vector2(r + 4, 4), c + Vector2(r * 0.7, r * 0.8), c + Vector2(2, r * 0.9),
			c + Vector2(-2, r * 0.5), c + Vector2(-3, -r * 0.2)])
	_shape(plate, rubber)
	_poly(_blob(c + Vector2(r * 0.4, r * 0.4), Vector2(2.2, 1.6), 7, 91), Color(DIRT, 0.5))
	var broken: bool = dead or ragdoll
	var glass := Color(0.55, 0.5, 0.3) if broken else (Color(1.0, 0.93, 0.45) if level_style == LevelStyle.POLVO else Color(1.0, 0.86, 0.25))
	for v in [[c + Vector2(2.5, -3.2), 3.3], [c + Vector2(r * 0.75, -2.4), 2.8]]:
		var at: Vector2 = v[0]
		var vr: float = v[1]
		if not broken:
			if level_style == LevelStyle.POLVO:
				# Dusty city ducks: the visors burn through the dust.
				var beat: float = 0.75 + 0.25 * sin(_time * 3.0 + float(style_seed % 5))
				_dot(at, vr * 3.0, Color(1.0, 0.8, 0.2, 0.22 * beat))
				_dot(at, vr * 2.0, Color(1.0, 0.86, 0.25, 0.45 * beat))
			else:
				_dot(at, vr * 1.7, Color(1.0, 0.86, 0.25, 0.22))
		_shape(_ellipse(at, vr + 1.1, vr + 1.1, 14), Color(0.45, 0.42, 0.36), 1.6)
		_shape(_ellipse(at, vr, vr, 14), glass, 1.2)
		if broken:
			_line(at + Vector2(-vr * 0.6, -vr * 0.4), at + Vector2(vr * 0.5, vr * 0.6), INK, 1.0, true)
		else:
			_line(at + Vector2(-vr * 0.5, -vr * 0.2), at + Vector2(-vr * 0.1, -vr * 0.6), Color(1, 1, 1, 0.75), 1.0, true)
	# Round filter canister with ribs and holes.
	var f: Vector2 = c + Vector2(r + 5.5, 5.5)
	_shape(PackedVector2Array([c + Vector2(r + 1, 3), c + Vector2(r + 4.5, 2.5), c + Vector2(r + 5, 6), c + Vector2(r + 1.5, 6.5)]), rubber, 1.4)
	_shape(_ellipse(f, 4.6, 4.6, 16), Color(0.33, 0.33, 0.31), 1.8)
	_arc(f, 3.0, 0.0, TAU, 12, Color(INK, 0.6), 1.0, true)
	for h in [Vector2(-1.2, -0.8), Vector2(1.2, -0.6), Vector2(0, 1.3)]:
		_dot(f + h, 0.6, INK)


## Dented tin can worn as a helmet, the lid still hanging open.
func _draw_can_helmet(c: Vector2) -> void:
	var pivot: Vector2 = c + Vector2(0, -9)
	var tilt: float = -0.22
	var body := _rotp(PackedVector2Array([Vector2(-8, 4), Vector2(8, 4), Vector2(7.5, -6), Vector2(5, -6), Vector2(3.5, -4),
			Vector2(2, -6), Vector2(-7.5, -6)]), pivot, tilt)
	_shape(body, Color(0.62, 0.62, 0.6))
	_shape(_rotp(PackedVector2Array([Vector2(-7.8, -1.5), Vector2(7.8, -1.5), Vector2(7.9, 1.6), Vector2(-7.9, 1.6)]), pivot, tilt),
			Color(0.6, 0.32, 0.24, 0.85), 1.2)
	for y in [-4.0, 3.0]:
		var a: Vector2 = pivot + Vector2(-7.6, y).rotated(tilt)
		var b: Vector2 = pivot + Vector2(7.6, y).rotated(tilt)
		_line(a, b, Color(INK, 0.5), 0.9, true)
	_poly(_blob(pivot + Vector2(-4, 2).rotated(tilt), Vector2(1.8, 1.2), 7, 33), Color(0.62, 0.36, 0.18, 0.7))
	_shape(_rotp(PackedVector2Array([Vector2(-7.5, -6), Vector2(-1, -6), Vector2(-2, -10), Vector2(-8, -9)]), pivot, tilt),
			Color(0.72, 0.72, 0.7), 1.4)
	# String tied under the chin.
	_line(pivot + Vector2(-7, 4).rotated(tilt), c + Vector2(2, 9), Color(INK, 0.7), 1.0, true)


## Cooking pot jammed on the head, handles sticking out, sooty.
func _draw_pot_helmet(c: Vector2) -> void:
	_shape(PackedVector2Array([c + Vector2(-13, -1), c + Vector2(13, -1), c + Vector2(12, -15), c + Vector2(3, -15.5),
			c + Vector2(1.5, -13.5), c + Vector2(0, -15.5), c + Vector2(-12, -15)]), Color(0.3, 0.31, 0.33))
	_shape(PackedVector2Array([c + Vector2(-15, -1), c + Vector2(15, -1), c + Vector2(15, 2), c + Vector2(-15, 2)]),
			Color(0.22, 0.23, 0.26), 2.0)
	_arc(c + Vector2(-15, -8), 4.0, PI * 0.5, PI * 1.5, 10, INK, 2.4, true)
	_arc(c + Vector2(15, -8), 4.0, -PI * 0.5, PI * 0.5, 10, INK, 2.4, true)
	_poly(_blob(c + Vector2(-5, -9), Vector2(3.5, 2.4), 8, 37), Color(SOOT, 0.45))
	_hatch(c + Vector2(6, -9), 6.0, 3, -1.1, 0.5)


## Frying pan strapped on as a shield.
func _draw_pan(at: Vector2) -> void:
	_line(at + Vector2(-1, 8.5), at + Vector2(-3, 12.5), INK, 4.6, true)
	_line(at + Vector2(-1, 8.5), at + Vector2(-3, 12.5), WOOD, 2.4, true)
	_shape(_ellipse(at, 7.5, 9.0, 18, 0.15), Color(0.21, 0.21, 0.23), 2.4)
	_arc(at, 5.6, 0.0, TAU, 16, Color(0.4, 0.4, 0.42), 1.2, true)
	_line(at + Vector2(-3, -5), at + Vector2(-1, -6.5), Color(1, 1, 1, 0.4), 1.0, true)
	_arc(at + Vector2(2, 2), 1.8, 0.4, 2.6, 5, Color(INK, 0.7), 1.0, true)
	# Rope lashing it to the body.
	_line(at + Vector2(-7, -3), at + Vector2(-15, -7), Color(0.7, 0.6, 0.4), 1.6, true)
	_line(at + Vector2(-6, 5), at + Vector2(-15, 2), Color(0.7, 0.6, 0.4), 1.6, true)


## Torn plush bear swinging from the belt on a string, stuffing coming out.
func _draw_plush(belt: Vector2) -> void:
	var swing: float = (0.0 if ragdoll else sin(_time * 2.3 + _run_phase) * 0.35) - _lean
	# Small enough to swing clear of the floor.
	var down: Vector2 = Vector2.DOWN.rotated(swing) * 0.62
	var side: Vector2 = down.orthogonal()
	var fur := Color(0.6, 0.46, 0.34)
	var hc: Vector2 = belt + down * 6.5
	var bc: Vector2 = belt + down * 12.0
	_line(belt, belt + down * 4.0, INK, 1.0, true)
	_line(bc + down * 3.0 + side * 1.6, bc + down * 6.0 + side * 2.0, INK, 2.8, true)
	_line(bc + down * 3.0 + side * 1.6, bc + down * 6.0 + side * 2.0, fur, 1.4, true)
	_shape(_ellipse(bc, 2.2, 2.7, 12, swing), fur, 1.2)
	_shape(_blob(bc + side * 2.6, Vector2(1.0, 0.8), 7, 3), Color(0.92, 0.9, 0.84), 0.9)
	for e in [-1.0, 1.0]:
		_shape(_ellipse(hc - down * 2.2 + side * 2.2 * float(e), 0.8, 0.8, 8), fur, 1.0)
	_shape(_ellipse(hc, 2.0, 1.85, 12), fur, 1.2)
	_dot(hc + side * 1.0 - down * 0.3, 0.45, INK)
	var x: Vector2 = hc - side * 1.1 - down * 0.3
	_line(x - Vector2(0.4, 0.4), x + Vector2(0.4, 0.4), INK, 0.7, true)
	_line(x - Vector2(0.4, -0.4), x + Vector2(0.4, -0.4), INK, 0.7, true)
	_line(hc + down * 1.2 - side * 0.8, hc + down * 1.2 + side * 0.8, INK, 0.8, true)


## Broken saw blade stuck in the woodcutter's back (half of it hidden by the body).
func _draw_back_saw(c: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a: float = TAU * float(i) / 32.0
		pts.append(c + Vector2.from_angle(a) * (11.0 if i % 2 == 0 else 13.4))
	_shape(pts, STEEL.darkened(0.25), 2.0)
	_dot(c, 2.6, INK)
	for p in [c + Vector2(-5, -4), c + Vector2(3, -7), c + Vector2(-7, 4)]:
		_poly(_blob(p, Vector2(2.2, 1.6), 7, int(p.x * 5.0)), Color(0.62, 0.34, 0.18, 0.75))
	_line(c + Vector2(4, -2), c + Vector2(11, -6), INK, 1.2, true)


## Shards of a fallen star grown out of the storm guardian's back, glowing.
func _draw_star_shards() -> void:
	var pulse: float = 0.6 + 0.4 * sin(_time * (5.0 if _mb("fury") else 2.5))
	for s in [[Vector2(-8, -27), -2.0, 15.0], [Vector2(-14, -21), -2.6, 11.0], [Vector2(-3, -29), -1.6, 10.0]]:
		var base: Vector2 = s[0]
		var d := Vector2.from_angle(s[1])
		var n: Vector2 = d.orthogonal() * 2.8
		var length: float = s[2]
		_poly(_ellipse(base + d * length * 0.6, length * 0.6, 5.0, 12, s[1]), Color(CORRUPT, 0.18 * pulse))
		_shape(PackedVector2Array([base + n, base + d * length, base - n, base - d * 2.0]), CORRUPT.lerp(Color(1.0, 0.85, 0.5), 0.4 * pulse), 2.0)
		_line(base, base + d * length * 0.8, Color(1.0, 0.95, 0.8, 0.7), 0.9, true)


## Thicker ink for the hero, so the healthy one reads first.
func _ink_mult() -> float:
	return 1.22 if look == Look.HERO else 1.0


## Deterministic 0..1 value per look and `i`.
func _hash(i: int) -> float:
	var v: float = sin(float(i) * 12.9898 + float(int(look)) * 4.137) * 43758.5453
	return v - floorf(v)


## Lumpy blob around `c` (never self-intersecting: one point per angle).
func _blob(c: Vector2, r: Vector2, steps: int, salt: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a: float = TAU * float(i) / float(steps)
		var k: float = 0.75 + _hash(salt * 13 + i) * 0.35
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y) * k)
	return pts


func _rotp(points: PackedVector2Array, pivot: Vector2, angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(pivot + p.rotated(angle))
	return out


# =====================================================================================
# Pose curves
# =====================================================================================

## Returns (arm angle, weapon angle) in radians, rig space (0 = forward, -PI/2 = up).
func _weapon_pose() -> Vector2:
	if ragdoll:
		return _idle_weapon_pose(false)
	var idle: Vector2 = _idle_weapon_pose()
	if dead:
		return Vector2(deg_to_rad(150), deg_to_rad(95))
	if hurt:
		return Vector2(deg_to_rad(125), deg_to_rad(150))
	if action == Action.NONE:
		return idle
	var windup: Vector2
	var strike: Vector2
	match action:
		Action.SLASH:
			windup = _deg(-120, -150)
			strike = _deg(55, 35)
		Action.HEAVY:
			windup = _deg(-100, -92)
			strike = _deg(70, 85)
		Action.DASH_SLASH:
			windup = _deg(150, 175)
			strike = _deg(5, 2)
		Action.CAST:
			if is_boss():
				windup = _deg(-105, -100)
				strike = _deg(-15, -20)
			else:
				windup = _deg(160, 182)
				strike = _deg(-5, -2)
		Action.CHARGE:
			windup = _deg(25, 10)
			strike = _deg(5, -5)
		_:
			match look:
				Look.BRUTE, Look.BRUTE_TOUGH, Look.BOSS_WOODCUTTER, Look.BOSS_SWAMP, Look.BOSS_STORM:
					windup = _deg(-135, -165)
					strike = _deg(35, 22)
				Look.BANDIT:
					windup = _deg(160, 185)
					strike = _deg(0, -4)
				_:
					windup = _deg(5, 0)
					strike = _deg(0, 0)
	match phase:
		Phase.WINDUP:
			return _lerp_angles(idle, windup, _ease_out(phase_t))
		Phase.STRIKE:
			return _lerp_angles(windup, strike, _ease_out(minf(phase_t * 1.6, 1.0)))
	return _lerp_angles(strike, idle, _ease_in_out(phase_t))


func _idle_weapon_pose(animated: bool = true) -> Vector2:
	var sway: float = sin(_time * 2.6) * 0.04 if animated else 0.0
	var running: bool = animated and grounded and ground_speed > 5.0
	match look:
		Look.HERO:
			if gesture == Gesture.HOLD_TORCH:
				var bob: float = sin(_run_phase) * 0.06 if running else 0.0
				return _deg(-58, -94) + Vector2(sway * 0.5 + bob, sway * 0.3)
			if animated and dashing:
				return _deg(150, 172)
			if animated and not grounded:
				return _deg(30, -40)
			if running:
				return _deg(105, 160) + Vector2(sin(_run_phase) * 0.12, 0.0)
			return _deg(62, -18) + Vector2(sway, sway)
		Look.BRUTE, Look.BRUTE_TOUGH, Look.BOSS_WOODCUTTER:
			return _deg(-40, -145) + Vector2(sway, sway)
		Look.BANDIT:
			return _deg(45, 5) + Vector2(sin(_run_phase) * 0.15 if running else sway, 0.0)
		Look.BOSS_SWAMP, Look.BOSS_STORM:
			# Staff or spear planted upright beside the body.
			return _deg(55, -82) + Vector2(sway, sway * 0.5)
		Look.GRANDFATHER:
			var tremble: float = sin(_time * 9.0) * 0.012 if animated else 0.0
			match gesture:
				Gesture.POINT:
					# Cane raised and aimed ahead, shaking a little.
					return _deg(-6, -14) + Vector2(tremble, tremble * 2.0)
				Gesture.HOLD_TORCH:
					return _deg(-58, -94) + Vector2(sway * 0.5, sway * 0.3)
			# Leaning on the cane planted ahead of the feet.
			return _deg(24, 78) + Vector2(sway * 0.4, 0.0)
	return _deg(15, 0) + Vector2(sway, 0.0)


func _action_lean() -> float:
	if action == Action.NONE or dead or hurt:
		return 0.0
	var windup_lean: float = -0.1
	var strike_lean: float = 0.12
	match action:
		Action.HEAVY:
			windup_lean = -0.16
			strike_lean = 0.22
		Action.ATTACK:
			if look == Look.BANDIT:
				windup_lean = -0.14
				strike_lean = 0.42
			elif look == Look.SLINGER:
				windup_lean = -0.08
				strike_lean = 0.05
		Action.DASH_SLASH:
			windup_lean = 0.0
			strike_lean = 0.1
		Action.CHARGE:
			windup_lean = -0.12
			strike_lean = 0.36
		Action.CAST:
			if is_boss():
				windup_lean = -0.14
				strike_lean = 0.1
	match phase:
		Phase.WINDUP:
			return windup_lean * _ease_out(phase_t)
		Phase.STRIKE:
			return strike_lean
	return strike_lean * (1.0 - _ease_in_out(phase_t))


func _action_squash() -> Vector2:
	if action == Action.NONE or dead or hurt:
		return Vector2.ONE
	var crouch := Vector2(1.06, 0.92)
	if action == Action.HEAVY or action == Action.CHARGE:
		crouch = Vector2(1.1, 0.86)
	match phase:
		Phase.WINDUP:
			return Vector2.ONE.lerp(crouch, _ease_out(phase_t))
		Phase.STRIKE:
			if (look == Look.BANDIT and action == Action.ATTACK) or action == Action.CHARGE:
				return Vector2(1.16, 0.9)
			return Vector2(0.95, 1.05)
	return Vector2.ONE


# =====================================================================================
# Helpers: every draw call goes through these so a single ragdoll piece can be drawn.
# =====================================================================================

func _ok() -> bool:
	return part == Part.ALL or part == _cur


func _shape(points: PackedVector2Array, fill: Color, width: float = INK_W) -> void:
	if not _ok():
		return
	if fill.a > 0.0:
		draw_colored_polygon(points, fill)
	# Hand-drawn ink: the line strays a little off the fill, more on the worn-out ducks.
	var wob: float = 0.08 + 0.3 * minf(_wear_k(), 1.0)
	var outline := PackedVector2Array()
	for i in points.size():
		var p: Vector2 = points[i]
		outline.append(p + Vector2(sin(p.x * 1.7 + p.y * 0.9 + float(i) * 2.3), cos(p.y * 1.3 - p.x * 0.7 + float(i) * 1.7)) * wob)
	outline.append(outline[0])
	draw_polyline(outline, INK, width * _ink_mult(), true)


func _line(a: Vector2, b: Vector2, color: Color, width: float, antialiased: bool = false) -> void:
	if _ok():
		draw_line(a, b, color, width, antialiased)


func _line_strip(points: PackedVector2Array, color: Color, width: float) -> void:
	if _ok():
		draw_polyline(points, color, width, true)


func _dot(at: Vector2, radius: float, color: Color) -> void:
	if _ok():
		draw_circle(at, radius, color)


func _arc(center: Vector2, radius: float, a0: float, a1: float, steps: int, color: Color, width: float,
		antialiased: bool = false) -> void:
	if _ok():
		draw_arc(center, radius, a0, a1, steps, color, width, antialiased)


func _poly(points: PackedVector2Array, color: Color) -> void:
	if _ok():
		draw_colored_polygon(points, color)


func _ellipse(c: Vector2, rx: float, ry: float, steps: int = 20, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a: float = TAU * float(i) / float(steps)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


func _deg(arm_deg: float, weapon_deg: float) -> Vector2:
	return Vector2(deg_to_rad(arm_deg), deg_to_rad(weapon_deg))


func _lerp_angles(a: Vector2, b: Vector2, t: float) -> Vector2:
	return Vector2(lerpf(a.x, b.x, t), lerpf(a.y, b.y, t))


func _ease_out(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return 1.0 - (1.0 - c) * (1.0 - c)


func _ease_in_out(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


# =====================================================================================
# Level style: dust (city), algae (swamp), glowing cracks (storm). Drawn by a child node over
# the duck so the duck's tint (self_modulate) does not dull them.
# =====================================================================================

func _refresh_level_style() -> void:
	if style_seed == 0:
		style_seed = int(get_instance_id() % 100003) + 1
	_style_rng.seed = style_seed
	self_modulate = _style_tint()
	if level_style == LevelStyle.NONE:
		if _style_fx != null:
			_style_fx.queue_free()
			_style_fx = null
		_style_bits.clear()
		return
	if _style_fx == null:
		_style_fx = Node2D.new()
		_style_fx.name = "LevelStyleFx"
		add_child(_style_fx, false, Node.INTERNAL_MODE_BACK)
		_style_fx.draw.connect(_draw_level_style)
	_style_clock = _style_rng.randf_range(0.1, 0.6)


func _style_tint() -> Color:
	match level_style:
		LevelStyle.POLVO:
			return Color(0.92, 0.88, 0.82)
		LevelStyle.ALGAS:
			return Color(0.72, 0.92, 0.66)
		LevelStyle.GRIETAS:
			return Color(0.6, 0.47, 0.76)
	return Color.WHITE


## Stable per-duck random number in [0, 1).
func _sh(i: int) -> float:
	var v: float = sin(float(style_seed) * 12.9898 + float(i) * 78.233) * 43758.5453
	return v - floorf(v)


func _advance_style(delta: float) -> void:
	if level_style == LevelStyle.NONE or _style_fx == null:
		return
	for i in range(_style_bits.size() - 1, -1, -1):
		var bit: Dictionary = _style_bits[i]
		bit["life"] = float(bit["life"]) - delta
		if float(bit["life"]) <= 0.0:
			_style_bits.remove_at(i)
			continue
		var v: Vector2 = bit["v"]
		match String(bit["kind"]):
			"ash":
				v.x += sin(_time * 3.0 + float(i)) * 20.0 * delta
			"drop":
				v.y += 420.0 * delta
			"spark":
				v.y += 160.0 * delta
				v *= 0.97
			"puff":
				v *= 0.92
		bit["v"] = v
		bit["p"] = (bit["p"] as Vector2) + v * delta
	if not dead and not ragdoll and part == Part.ALL and is_visible_in_tree():
		_style_clock -= delta
		if _style_clock <= 0.0 and _style_bits.size() < 60:
			_emit_style_bit()
		if level_style == LevelStyle.POLVO:
			_emit_dust_puffs(delta)
	_style_fx.queue_redraw()


## Dusty ducks raise a cloud at their feet while walking and burst into dust when hit.
func _emit_dust_puffs(delta: float) -> void:
	var feet: Vector2 = to_global(Vector2(0.0, foot_y))
	var s: float = _look_scale()
	if hurt and not _style_was_hurt:
		var root: Transform2D = _build_root()
		for k in 9:
			var at: Vector2 = to_global(root * Vector2(_style_rng.randf_range(-14.0, 14.0), _style_rng.randf_range(-34.0, -6.0)))
			var dir: Vector2 = Vector2.from_angle(_style_rng.randf() * TAU)
			_add_bit(at, dir * _style_rng.randf_range(40.0, 90.0), _style_rng.randf_range(0.5, 0.8), "puff", 5.0 * s)
	_style_was_hurt = hurt
	_puff_clock -= delta
	if grounded and ground_speed > 5.0 and _puff_clock <= 0.0 and _style_bits.size() < 60:
		_puff_clock = 0.11
		var back: float = -signf(global_transform.x.x) if global_transform.x.x != 0.0 else -1.0
		_add_bit(feet + Vector2(_style_rng.randf_range(-6.0, 6.0) * s, -3.0), Vector2(back * _style_rng.randf_range(15.0, 35.0), -_style_rng.randf_range(8.0, 20.0)),
				_style_rng.randf_range(0.45, 0.7), "puff", 4.0 * s)


func _emit_style_bit() -> void:
	var root: Transform2D = _build_root()
	match level_style:
		LevelStyle.POLVO:
			# Ash shaken off the feathers, much more of it while the duck moves.
			var moving: bool = grounded and ground_speed > 5.0
			_style_clock = 0.07 if moving else _style_rng.randf_range(0.5, 1.0)
			var at := Vector2(_style_rng.randf_range(-12.0, 12.0), _style_rng.randf_range(-30.0, -8.0))
			_add_bit(to_global(root * at), Vector2(_style_rng.randf_range(-15.0, 15.0), _style_rng.randf_range(25.0, 45.0)),
					_style_rng.randf_range(0.8, 1.3), "ash")
		LevelStyle.ALGAS:
			_style_clock = _style_rng.randf_range(0.35, 0.8)
			var strands: Array = _algae_strands()
			var s: Array = strands[_style_rng.randi() % strands.size()]
			var pts: PackedVector2Array = _algae_points(s)
			_add_bit(to_global(root * pts[pts.size() - 1]), Vector2(0.0, 20.0), 0.7, "drop")
		LevelStyle.GRIETAS:
			_style_clock = _style_rng.randf_range(0.6, 1.8)
			var cracks: Array = _crack_paths()
			var path: PackedVector2Array = cracks[_style_rng.randi() % cracks.size()]
			var from: Vector2 = to_global(root * path[_style_rng.randi() % path.size()])
			for k in _style_rng.randi_range(3, 5):
				var dir: Vector2 = Vector2.from_angle(_style_rng.randf_range(-PI * 0.95, -PI * 0.05))
				_add_bit(from, dir * _style_rng.randf_range(50.0, 130.0), _style_rng.randf_range(0.3, 0.5), "spark")


func _add_bit(p: Vector2, v: Vector2, life: float, kind: String, size: float = 1.0) -> void:
	_style_bits.append({"p": p, "v": v, "life": life, "max": life, "kind": kind, "size": size})


## Algae strands as [root (rig space), length, phase]: off the head and the shoulders.
func _algae_strands() -> Array:
	var c: Vector2 = _head_center()
	var r: float = _head_radius()
	var sh: Vector2 = _shoulder()
	var out: Array = []
	# [root, length, phase, on the head]
	# Off the crown and the back of the head (the face stays clear), the shoulders and the hip;
	# none reaches below the feet.
	for k in 3:
		out.append([c + Vector2(-r * 0.95 + float(k) * r * 0.38, -r * 0.6 + absf(float(k) - 1.0) * r * 0.25), 13.0 + _sh(k) * 7.0, _sh(k + 10) * TAU, true])
	out.append([sh + Vector2(-5, 2), 15.0 + _sh(4) * 5.0, _sh(14) * TAU, false])
	out.append([sh + Vector2(5, 4), 13.0 + _sh(5) * 5.0, _sh(15) * TAU, false])
	out.append([Vector2(-12, -10), 8.0 + _sh(6) * 2.0, _sh(16) * TAU, false])
	return out


func _algae_points(s: Array) -> PackedVector2Array:
	var root: Vector2 = s[0]
	var length: float = s[1]
	var phase: float = s[2]
	var pts := PackedVector2Array()
	for i in 6:
		var u: float = float(i) / 5.0
		var still: float = 0.3 if ragdoll else 1.0
		pts.append(root + Vector2(sin(_time * 2.2 + phase + u * 2.4) * 4.0 * u * still, length * u))
	return pts


## Crack paths (rig space): three over the body and two over the head, fixed per duck.
func _crack_paths() -> Array:
	var out: Array = []
	var c: Vector2 = _head_center()
	var r: float = _head_radius()
	var starts: Array = [Vector2(-8, -20), Vector2(4, -12), Vector2(-4, -8), c + Vector2(-r * 0.4, -r * 0.4), c + Vector2(-r * 0.1, r * 0.2)]
	var body_c := Vector2(-1, -15)
	var body_r := Vector2(13.0, 10.5)
	for k in starts.size():
		var head: bool = k >= 3
		var p: Vector2 = starts[k]
		var dir: float = _sh(k + 20) * TAU
		var pts := PackedVector2Array([p])
		var step: float = 2.6 if head else 3.4
		for i in 4:
			dir += (_sh(k * 7 + i + 30) - 0.5) * 1.6
			p += Vector2.from_angle(dir) * step
			# Keep the crack on the duck: pull it back inside the head or the body.
			if head:
				p = c + (p - c).limit_length(r * 0.8)
			else:
				var q: Vector2 = (p - body_c) / body_r
				if q.length() > 1.0:
					p = body_c + q.normalized() * body_r
					dir += PI * 0.6
			pts.append(p)
		out.append(pts)
	return out


func _draw_level_style() -> void:
	var fx: Node2D = _style_fx
	if fx == null:
		return
	if part != Part.WEAPON and part != Part.FX:
		fx.draw_set_transform_matrix(_build_root())
		match level_style:
			LevelStyle.POLVO:
				_style_dust(fx)
			LevelStyle.ALGAS:
				_style_algae(fx)
			LevelStyle.GRIETAS:
				_style_cracks(fx)
	fx.draw_set_transform_matrix(Transform2D.IDENTITY)
	for bit in _style_bits:
		var p: Vector2 = fx.to_local(bit["p"])
		var a: float = clampf(float(bit["life"]) / float(bit["max"]), 0.0, 1.0)
		match String(bit["kind"]):
			"ash":
				fx.draw_circle(p, 1.5, Color(0.62, 0.6, 0.56, 0.85 * a))
			"drop":
				fx.draw_circle(p, 2.0, Color(0.4, 0.66, 0.36, 0.9 * a))
				fx.draw_circle(p + Vector2(-0.6, -0.6), 0.7, Color(0.85, 1.0, 0.8, 0.8 * a))
			"spark":
				var v: Vector2 = bit["v"]
				fx.draw_line(p, p - v * 0.035, Color(1.0, 0.9, 0.4, a), 2.0, true)
				fx.draw_circle(p, 1.5, Color(1.0, 1.0, 0.8, a))
			"puff":
				var grow: float = float(bit["size"]) * (1.0 + (1.0 - a) * 1.6)
				fx.draw_circle(p, grow, Color(0.66, 0.62, 0.55, 0.5 * a))
				fx.draw_circle(p + Vector2(-grow * 0.3, -grow * 0.3), grow * 0.55, Color(0.78, 0.74, 0.66, 0.4 * a))


## Whether a style decoration on the head (or on the body) belongs to the piece this rig draws
## (the whole duck, or one ragdoll piece).
func _style_on(head: bool) -> bool:
	return part == Part.ALL or (part == Part.HEAD) == head


## Big grey dust and soot blotches over the feathers.
func _style_dust(fx: Node2D) -> void:
	var c: Vector2 = _head_center()
	var r: float = _head_radius()
	for i in 7:
		var on_head: bool = i >= 5
		if not _style_on(on_head):
			continue
		var at := Vector2(-1.0 + (_sh(i) - 0.5) * 24.0, -15.0 + (_sh(i + 40) - 0.5) * 18.0)
		if on_head:
			at = c + Vector2((_sh(i) - 0.5) * r * 1.1, (_sh(i + 40) - 0.5) * r * 0.9)
		var col := Color(0.55, 0.53, 0.5, 0.7) if i % 2 == 0 else Color(0.32, 0.31, 0.3, 0.6)
		var blot := _ellipse(at, 5.0 + _sh(i + 50) * 4.5, 3.6 + _sh(i + 60) * 2.6, 12, _sh(i + 70) * PI)
		fx.draw_colored_polygon(blot, col)
		fx.draw_colored_polygon(_ellipse(at + Vector2(-1.2, -1.0), 2.2, 1.5, 8), Color(0.82, 0.8, 0.76, 0.35))
	if _style_on(false):
		for i in 6:
			fx.draw_circle(Vector2(-12.0 + _sh(i + 80) * 22.0, -26.0 + _sh(i + 90) * 22.0), 1.3, Color(0.22, 0.2, 0.18, 0.75))


## Long thick algae hanging off the head and the arms, swaying, with a moss cap.
func _style_algae(fx: Node2D) -> void:
	var c: Vector2 = _head_center()
	var r: float = _head_radius()
	if _style_on(true):
		var cap := _ellipse(c + Vector2(-1, -r * 0.72), r * 0.95, r * 0.42, 14)
		fx.draw_colored_polygon(cap, Color(0.3, 0.52, 0.24, 0.95))
		var ring := PackedVector2Array(cap)
		ring.append(cap[0])
		fx.draw_polyline(ring, Color(INK, 0.7), 1.6, true)
	for s in _algae_strands():
		if not _style_on(bool(s[3])):
			continue
		var pts: PackedVector2Array = _algae_points(s)
		fx.draw_polyline(pts, Color(INK, 0.9), 5.2, true)
		fx.draw_polyline(pts, Color(0.3, 0.55, 0.22), 3.2, true)
		fx.draw_polyline(pts, Color(0.5, 0.75, 0.35, 0.7), 1.0, true)
		var tip: Vector2 = pts[pts.size() - 1]
		fx.draw_colored_polygon(_ellipse(tip + Vector2(0, 1.5), 2.6, 3.6, 10), Color(0.42, 0.7, 0.3))


## Wide glowing yellow cracks that pulse, with a halo of light around them.
func _style_cracks(fx: Node2D) -> void:
	var pulse: float = 0.55 + 0.45 * sin(_time * 3.2 + float(style_seed % 7))
	if dead or ragdoll:
		pulse = 0.35
	var paths: Array = _crack_paths()
	for k in paths.size():
		if not _style_on(k >= 3):
			continue
		var path: PackedVector2Array = paths[k]
		fx.draw_polyline(path, Color(1.0, 0.8, 0.2, 0.12 * pulse), 11.0, true)
		fx.draw_polyline(path, Color(1.0, 0.82, 0.25, 0.28 * pulse), 7.0, true)
		fx.draw_polyline(path, Color(INK, 0.8), 4.6, true)
		fx.draw_polyline(path, Color(1.0, 0.92, 0.45, 0.65 + 0.35 * pulse), 2.6, true)
