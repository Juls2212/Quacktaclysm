class_name BossFightFx
extends Node2D
## The look of a boss fight, visual only. Finds the level's encounter, boss and player and listens
## to their public signals; it never changes the fight.
## - Presentation ("VS", ~4 s) when the encounter starts: a diagonal split screen, the hero on a
##   cold background on the left and the boss on dark purple on the right, each sliding in from its
##   edge; the hero's katana bursts into flames as it lands (fire licking up the whole blade, a
##   white-hot core, embers, a warm light over the hero's half); the seam glows and throws sparks;
##   a dark purple aura, sparks and little sheet ghosts spiral out of the boss, whose eyes glow; a
##   crisp "VS" slams in over its own flash, then the boss's name and a line in italics. Holds the
##   PauseLock while it plays; Esc, Enter or a click skip it. It fades back to the level in 0.6 s.
##   After a restart (the player died) only a short flash with the name is shown (~1 s, no pause).
## - Dark arena while the fight lasts: the sky and far scenery turn purple-black, a low red fog
##   crawls on the floor, a heavy vignette, falling ash, far purple lightning and an aura around
##   the boss. It fades back to the level's own look on a win or a restart. No platform is touched.
## - Framed arena: once the presentation is over, a camera of its own glides (0.8 s) to a fixed
##   shot of the whole arena (gate to right wall, ceiling to floor) with dark edges so the cut of
##   the scenery does not show, and shakes lightly on heavy hits (if camera shake is on). On a win
##   or a restart it glides back to the player's camera and is freed. The names come from BossNames.
## - The killing blow: a flash, impact lines and black bars, a frozen-moment look (time is never
##   slowed). The death itself is DuckRagdoll's boss death.
## Everything is skipped in headless runs.

enum Vs { NONE, FULL, FLASH }

const PURPLE := Color(0.42, 0.14, 0.64)
const VIOLET := Color(0.78, 0.5, 1.0)
const NIGHT := Color(0.07, 0.02, 0.1)
const COLD := Color(0.22, 0.42, 0.6)
const COLD_DARK := Color(0.04, 0.09, 0.16)
const FOE_BG := Color(0.2, 0.05, 0.27)
const FOE_DARK := Color(0.05, 0.01, 0.07)
const CREAM := Color(0.98, 0.93, 0.8)
const INK := Color(0.106, 0.098, 0.122)
const FOG := Color(0.6, 0.06, 0.09)
const SPARK := Color(1.0, 0.92, 0.7)
const VS_LENGTH: float = 3.5
const VS_FADE: float = 0.6
const FLASH_LENGTH: float = 1.0
const ARENA_IN: float = 1.5
const ARENA_OUT: float = 2.5
const IMPACT_LENGTH: float = 0.8
## After a win the arena stays dark while the boss dies, then fades back.
const WIN_HOLD: float = 2.8
const ASH_COUNT: int = 70
## Seam of the split screen: half its horizontal lean, in pixels.
const SEAM: float = 120.0
## Presentation time when the hero's katana catches fire (the hero has just landed).
const IGNITE_AT: float = 0.5
## Presentation time when "VS" slams in.
const VS_AT: float = 1.0
const FIRE_CORE := Color(1.0, 0.97, 0.86)
const FIRE_YELLOW := Color(1.0, 0.84, 0.3)
const FIRE_ORANGE := Color(1.0, 0.46, 0.08)
const FIRE_RED := Color(0.86, 0.12, 0.04)
const GHOST_RIM := Color(0.74, 0.42, 1.0)
const GHOST_EYE := Color(0.12, 0.03, 0.17)
## Seconds of the camera's glide to the arena shot and back.
const CAM_GLIDE: float = 0.8
## Darkness at the left and right edges of the arena shot.
const EDGE_DARK := Color(0.02, 0.0, 0.03)

enum Cam { NONE, IN, HOLD, OUT }

## Level number -> {"name", "subtitle"} shown on the presentation (BossNames by default).
@export var bosses: Dictionary = BossNames.BY_LEVEL.duplicate(true)
@export var vs_text: String = "VS"

## Levels whose full presentation was already seen in this run (the rematch only flashes).
static var _seen: Dictionary = {}

var _level: Node = null
var _encounter: Node = null
var _boss: Node2D = null
var _player: Node = null
var _source_rig: DuckRig = null
var _look: DuckRig.Look = DuckRig.Look.BOSS_WOODCUTTER
var _name: String = ""
var _subtitle: String = ""
var _shake_ok: bool = true
var _rng := RandomNumberGenerator.new()
var _time: float = 0.0

# Presentation
var _vs: Vs = Vs.NONE
var _vs_t: float = 0.0
var _leave_t: float = -1.0
var _holds_lock: bool = false
var _layer: CanvasLayer = null
var _back: Control = null
var _front: Control = null
var _hero: DuckRig = null
var _foe: DuckRig = null
var _sparks: Array = []
var _souls: Array = []
var _spark_clock: float = 0.0
var _soul_clock: float = 0.0
var _italic: FontVariation = null
# The burning katana: flame puffs {p, v, life, max, s} and embers {p, v, life, max, w, seed}.
var _fire: Control = null
var _fire_body: Control = null
var _flames: Array = []
var _embers: Array = []
var _flame_clock: float = 0.0
var _ember_clock: float = 0.0
var _ignite: float = 0.0
var _fire_grad: Gradient = null
var _glow_tex: GradientTexture2D = null

# Arena camera
var _cam: Camera2D = null
var _prev_cam: Camera2D = null
var _cam_mode: Cam = Cam.NONE
var _cam_t: float = 0.0
var _cam_from: Vector2 = Vector2.ZERO
var _cam_from_zoom: Vector2 = Vector2.ONE
var _cam_center: Vector2 = Vector2.ZERO
var _cam_zoom: Vector2 = Vector2.ONE
## How much of the arena shot is on screen (0 = the player's view, 1 = the whole arena).
var _cam_k: float = 0.0
var _shake: float = 0.0
var _shake_power: float = 0.0
var _boss_health: int = -1

# Arena
var _fight: bool = false
var _boss_alive: bool = false
var _dark: float = 0.0
var _dark_target: float = 0.0
var _floor_y: float = 0.0
var _sky: Node2D = null
var _ground: Node2D = null
var _frame: Node2D = null
var _aura: Node2D = null
var _aura_k: float = 0.0
var _ash: Array[Vector3] = []
var _bolts: Array = []
var _bolt_flash: float = 0.0
var _next_bolt: float = 2.5
var _rage: float = 0.0
var _restore_in: float = -1.0

# Killing blow
var _impact_t: float = -1.0
var _impact_at: Vector2 = Vector2.ZERO


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		set_process_input(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_level = get_parent()
	if _level == null:
		return
	_encounter = _level.get(&"encounter") as Node
	_boss = _level.get(&"boss") as Node2D
	_player = _level.get(&"player") as Node
	if _player == null:
		_player = _level.get_node_or_null(^"Player")
	if _encounter == null or _boss == null:
		set_process(false)
		set_process_input(false)
		return
	_encounter.connect(&"encounter_started", _on_encounter_started)
	_encounter.connect(&"encounter_won", _on_encounter_won)
	_boss.connect(&"defeated", _on_boss_defeated)
	_boss.connect(&"phase_changed", _on_phase_changed)
	if _boss.has_signal(&"encounter_reset"):
		_boss.connect(&"encounter_reset", _on_encounter_reset)
	if _boss.has_signal(&"health_changed"):
		_boss.connect(&"health_changed", _on_boss_health_changed)
	if _player != null and _player.has_signal(&"died"):
		_player.connect(&"died", _on_player_died)
	var player_health: Node = _player.get(&"health") as Node if _player != null else null
	if player_health != null and player_health.has_signal(&"damaged"):
		player_health.connect(&"damaged", _on_player_damaged)
	var visual: Node = _boss.get_node_or_null(^"Visual")
	if visual != null:
		_source_rig = visual.get(&"rig") as DuckRig
		var look: Variant = visual.get(&"look")
		if look != null:
			_look = int(look) as DuckRig.Look
	_read_names()
	_italic = FontVariation.new()
	_italic.base_font = GameFonts.BODY
	_italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.24, 1), Vector2.ZERO)
	for i in ASH_COUNT:
		_ash.append(Vector3(_rng.randf(), _rng.randf(), 0.6 + _rng.randf() * 0.8))
	_fire_grad = Gradient.new()
	_fire_grad.offsets = PackedFloat32Array([0.0, 0.14, 0.4, 0.7, 1.0])
	_fire_grad.colors = PackedColorArray([Color(1.0, 0.95, 0.62, 0.95), Color(FIRE_YELLOW, 0.9), Color(FIRE_ORANGE, 0.8),
			Color(FIRE_RED, 0.55), Color(0.35, 0.03, 0.02, 0.0)])
	var soft := Gradient.new()
	soft.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	soft.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = soft
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.width = 128
	_glow_tex.height = 128
	_build_arena()


func _exit_tree() -> void:
	_release_lock()


func _read_names() -> void:
	var info: Dictionary = BossNames.info_for(_boss, _level, bosses)
	if info.is_empty():
		info = bosses.get(BossNames.level_for_look(_look), {}) as Dictionary
	_name = String(info.get("name", ""))
	_subtitle = String(info.get("subtitle", ""))


func _level_key() -> String:
	return "%s|%s" % [_level.scene_file_path, str(_level.get(&"level_id"))]


# =====================================================================================
# Signals
# =====================================================================================

func _on_encounter_started() -> void:
	_fight = true
	_boss_alive = true
	_impact_t = -1.0
	_restore_in = -1.0
	_rage = 0.0
	_floor_y = _find_floor()
	_shake_ok = GameSettings.is_camera_shake_enabled()
	_boss_health = -1
	var key: String = _level_key()
	if _seen.has(key):
		_start_flash()
		_dark_target = 1.0
		# The rematch has no long presentation: the shot frames the arena right away.
		_begin_arena_cam()
		return
	_seen[key] = true
	_start_vs()


func _on_encounter_won() -> void:
	_fight = false
	_restore_in = WIN_HOLD
	_seen.erase(_level_key())
	_end_arena_cam()


func _on_player_died() -> void:
	_end_arena_cam()
	if not _fight:
		return
	_fight = false
	_boss_alive = false
	_dark_target = 0.0
	if _vs != Vs.NONE:
		_end_vs()


func _on_encounter_reset() -> void:
	_end_arena_cam()


func _on_boss_defeated(_defeated: Node) -> void:
	_boss_alive = false
	_impact_t = 0.0
	_kick(11.0)
	if is_instance_valid(_boss):
		_impact_at = _boss.global_position + Vector2(0, -20)


func _on_phase_changed(phase: int) -> void:
	if phase >= 2 and _fight:
		_rage = 1.0
		_strike(true)
		_kick(9.0)


## A heavy blow on the boss (a big chunk of its health at once) shakes the shot a little.
func _on_boss_health_changed(current: int, maximum: int) -> void:
	if _fight and _boss_health >= 0 and maximum > 0 and float(_boss_health - current) >= float(maximum) * 0.06:
		_kick(5.0)
	_boss_health = current


func _on_player_damaged(_info: Variant) -> void:
	if _fight:
		_kick(6.0)


## Where the boss stands: the floor line of the fight (world y).
func _find_floor() -> float:
	if _source_rig != null and is_instance_valid(_source_rig):
		return _source_rig.global_position.y + _source_rig.foot_y * absf(_source_rig.global_scale.y)
	return _boss.global_position.y + 40.0


# =====================================================================================
# Frame
# =====================================================================================

func _process(delta: float) -> void:
	_time += delta
	var paused: bool = get_tree().paused
	if _vs != Vs.NONE:
		_update_vs(delta)
	# The arena waits while the game is paused by someone else (pause menu, decision panel).
	if not paused or _vs != Vs.NONE:
		_update_arena(delta)
	_update_cam(delta, paused)
	if _impact_t >= 0.0:
		_impact_t += delta
		if _impact_t > IMPACT_LENGTH:
			_impact_t = -1.0


func _input(event: InputEvent) -> void:
	if _vs != Vs.FULL or _leave_t >= 0.0 or _vs_t < 0.2:
		return
	var skip: bool = event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("ui_accept")
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		skip = true
	if not skip:
		return
	get_viewport().set_input_as_handled()
	_start_leaving()


# =====================================================================================
# Presentation
# =====================================================================================

func _build_vs() -> void:
	if _layer != null:
		return
	_layer = CanvasLayer.new()
	_layer.name = "VsLayer"
	_layer.layer = 70
	add_child(_layer)
	_back = _full_control("Back", _draw_back)
	_hero = DuckRig.new()
	_hero.name = "Hero"
	_hero.look = DuckRig.Look.HERO
	_hero.action = DuckRig.Action.SLASH
	_hero.phase = DuckRig.Phase.WINDUP
	_hero.phase_t = 0.85
	_layer.add_child(_hero)
	_foe = DuckRig.new()
	_foe.name = "Boss"
	_foe.look = _look
	if _source_rig != null and is_instance_valid(_source_rig):
		_foe.copy_style_from(_source_rig)
	_foe.enraged = false
	_foe.action = DuckRig.Action.ATTACK
	_foe.phase = DuckRig.Phase.WINDUP
	_foe.phase_t = 0.55
	_layer.add_child(_foe)
	# The burning katana, on top of both ducks: the flames' bodies (normal blend, so the reds stay
	# red over the cold sky), then the light, the white-hot core and the embers (additive).
	_fire_body = _full_control("FireBody", _draw_fire_body)
	_fire = _full_control("Fire", _draw_fire)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fire.material = add
	_front = _full_control("Front", _draw_front)


func _full_control(node_name: String, drawer: Callable) -> Control:
	var c := Control.new()
	c.name = node_name
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.draw.connect(drawer)
	return c


func _start_vs() -> void:
	_build_vs()
	_vs = Vs.FULL
	_vs_t = 0.0
	_leave_t = -1.0
	_clear_vs_bits()
	_layer.visible = true
	_hero.visible = true
	_foe.visible = true
	_set_vs_alpha(1.0)
	if not _holds_lock:
		_holds_lock = true
		PauseLock.request(self, get_tree())


func _start_flash() -> void:
	_build_vs()
	_vs = Vs.FLASH
	_vs_t = 0.0
	_leave_t = -1.0
	_clear_vs_bits()
	_layer.visible = true
	_hero.visible = false
	_foe.visible = false
	_set_vs_alpha(1.0)


func _start_leaving() -> void:
	if _leave_t >= 0.0:
		return
	_leave_t = 0.0
	# The arena starts turning dark under the fading presentation.
	_dark_target = 1.0 if _fight else 0.0


func _end_vs() -> void:
	var was_full: bool = _vs == Vs.FULL
	_vs = Vs.NONE
	_leave_t = -1.0
	_clear_vs_bits()
	if _layer != null:
		_layer.visible = false
		_layer.offset = Vector2.ZERO
	_release_lock()
	# The presentation is over: the fight is framed.
	if was_full and _fight:
		_begin_arena_cam()


func _clear_vs_bits() -> void:
	_sparks.clear()
	_souls.clear()
	_flames.clear()
	_embers.clear()
	_ignite = 0.0


func _release_lock() -> void:
	if _holds_lock:
		_holds_lock = false
		PauseLock.release(self, get_tree())


func _set_vs_alpha(a: float) -> void:
	for item in [_back, _hero, _foe, _fire_body, _fire, _front]:
		(item as CanvasItem).modulate.a = a


func _update_vs(delta: float) -> void:
	_vs_t += delta
	if _vs == Vs.FLASH:
		if _vs_t >= FLASH_LENGTH:
			_end_vs()
			return
		_front.queue_redraw()
		_back.queue_redraw()
		return
	if _leave_t < 0.0 and _vs_t >= VS_LENGTH:
		_start_leaving()
	if _leave_t >= 0.0:
		_leave_t += delta
		_set_vs_alpha(1.0 - smoothstep(0.0, VS_FADE, _leave_t))
		if _leave_t >= VS_FADE:
			_end_vs()
			return
	var size: Vector2 = _back.size
	var t: float = _vs_t
	# The two halves slide in from their edges, each landing with a thud.
	var hero_in: float = _ease_out_back(clampf((t - 0.15) / 0.4, 0.0, 1.0))
	var foe_in: float = _ease_out_back(clampf((t - 0.35) / 0.4, 0.0, 1.0))
	var breathe: float = sin(_time * 2.0) * 3.0
	_hero.scale = Vector2(4.2, 4.2)
	_hero.position = Vector2(size.x * 0.24 - (1.0 - hero_in) * size.x * 0.6, size.y * 0.56 + breathe)
	_foe.scale = Vector2(-2.7, 2.7)
	_foe.position = Vector2(size.x * 0.75 + (1.0 - foe_in) * size.x * 0.6, size.y * 0.52 - breathe)
	# The hero's blade catches the light now and then.
	_hero.phase_t = 0.85 + sin(_time * 1.7) * 0.05
	_layer.offset = _vs_shake(t)
	_update_vs_bits(delta, size)
	_update_fire(delta)
	_back.queue_redraw()
	_fire_body.queue_redraw()
	_fire.queue_redraw()
	_front.queue_redraw()


func _vs_shake(t: float) -> Vector2:
	if not _shake_ok:
		return Vector2.ZERO
	var k: float = 0.0
	for hit in [[0.55, 0.12, 5.0], [0.75, 0.12, 5.0], [1.05, 0.3, 14.0]]:
		var u: float = (t - float(hit[0])) / float(hit[1])
		if u >= 0.0 and u <= 1.0:
			k = maxf(k, (1.0 - u) * float(hit[2]))
	return Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * k


func _update_vs_bits(delta: float, size: Vector2) -> void:
	var t: float = _vs_t
	# Sparks along the seam once both halves are in.
	if t >= 0.75:
		_spark_clock -= delta
		while _spark_clock <= 0.0:
			_spark_clock += 0.025
			_seam_spark(size, 1.0)
		if t - delta < 0.75:
			for i in 40:
				_seam_spark(size, 2.2)
	# Purple sparks and souls out of the boss.
	if t >= 0.6:
		var chest: Vector2 = _foe_point(Vector2(-1, -15))
		if _rng.randf() < 0.5:
			_sparks.append({"p": chest + Vector2(_rng.randf_range(-70, 70), _rng.randf_range(-80, 60)),
					"v": Vector2(_rng.randf_range(-60, 60), -_rng.randf_range(60, 200)), "life": 0.0,
					"max": _rng.randf_range(0.5, 1.0), "col": VIOLET.lerp(Color.WHITE, _rng.randf() * 0.4), "w": 2.0})
		_soul_clock -= delta
		if _soul_clock <= 0.0:
			_soul_clock = _rng.randf_range(0.12, 0.22)
			var big: float = _rng.randf()
			_souls.append({"base": chest + Vector2(_rng.randf_range(-30, 30), 0), "a": _rng.randf() * TAU,
					"r": 10.0, "y": 0.0, "life": 0.0, "max": _rng.randf_range(1.6, 2.4),
					"s": lerpf(13.0, 46.0, big * big), "dir": -1.0 if _rng.randf() < 0.5 else 1.0, "trail": PackedVector2Array(),
					"mouth": _rng.randf() < 0.45, "seed": _rng.randf() * TAU})
	for i in range(_sparks.size() - 1, -1, -1):
		var sp: Dictionary = _sparks[i]
		sp["life"] = float(sp["life"]) + delta
		if float(sp["life"]) >= float(sp["max"]):
			_sparks.remove_at(i)
			continue
		var v: Vector2 = sp["v"]
		v.y += 260.0 * delta
		sp["v"] = v
		sp["p"] = (sp["p"] as Vector2) + v * delta
	for i in range(_souls.size() - 1, -1, -1):
		var soul: Dictionary = _souls[i]
		soul["life"] = float(soul["life"]) + delta
		if float(soul["life"]) >= float(soul["max"]):
			_souls.remove_at(i)
			continue
		soul["a"] = float(soul["a"]) + delta * 3.2 * float(soul["dir"])
		soul["r"] = float(soul["r"]) + delta * 34.0
		# Big ghosts drift up a little slower than small ones.
		soul["y"] = float(soul["y"]) + delta * (185.0 - float(soul["s"]) * 2.2)
		var trail: PackedVector2Array = soul["trail"]
		trail.append(_soul_pos(soul))
		if trail.size() > 14:
			trail.remove_at(0)
		soul["trail"] = trail


## The hero's katana: it catches fire as the hero lands, then keeps burning.
func _update_fire(delta: float) -> void:
	var t: float = _vs_t
	_ignite = maxf(_ignite - delta * 2.4, 0.0)
	if t >= IGNITE_AT:
		var blade: PackedVector2Array = _hero_blade()
		if t - delta < IGNITE_AT:
			_ignite = 1.0
			for i in 34:
				_emit_flame(blade, 1.5)
			for i in 46:
				_emit_ember(blade, 2.0)
		_flame_clock -= delta
		while _flame_clock <= 0.0:
			_flame_clock += 0.007
			_emit_flame(blade, 1.0)
		_ember_clock -= delta
		while _ember_clock <= 0.0:
			_ember_clock += 0.035
			_emit_ember(blade, 1.0)
	for i in range(_flames.size() - 1, -1, -1):
		var f: Dictionary = _flames[i]
		f["life"] = float(f["life"]) + delta
		if float(f["life"]) >= float(f["max"]):
			_flames.remove_at(i)
			continue
		var v: Vector2 = f["v"]
		# Flames speed up as they rise and sway sideways.
		v.y -= 220.0 * delta
		v.x += sin(float(f["life"]) * 14.0 + float(f["seed"])) * 260.0 * delta
		f["v"] = v
		f["p"] = (f["p"] as Vector2) + v * delta
	for i in range(_embers.size() - 1, -1, -1):
		var e: Dictionary = _embers[i]
		e["life"] = float(e["life"]) + delta
		if float(e["life"]) >= float(e["max"]):
			_embers.remove_at(i)
			continue
		var v: Vector2 = e["v"]
		v.y -= 40.0 * delta
		v.x += sin(float(e["life"]) * 9.0 + float(e["seed"])) * 180.0 * delta
		v *= 1.0 - 0.9 * delta
		e["v"] = v
		e["p"] = (e["p"] as Vector2) + v * delta


## A point on the burning blade (u: 0 at the guard, 1 at the tip), with a little scatter.
func _blade_point(blade: PackedVector2Array, u: float) -> Vector2:
	var f: float = clampf(u, 0.0, 1.0) * float(blade.size() - 1)
	var i: int = mini(int(f), blade.size() - 2)
	return blade[i].lerp(blade[i + 1], f - float(i))


func _emit_flame(blade: PackedVector2Array, power: float) -> void:
	var u: float = _rng.randf()
	var p: Vector2 = _blade_point(blade, u) + Vector2(_rng.randf_range(-5, 5), _rng.randf_range(-4, 4))
	_flames.append({"p": p, "v": Vector2(_rng.randf_range(-35, 35), -_rng.randf_range(110, 220)) * power,
			"life": 0.0, "max": _rng.randf_range(0.35, 0.75), "s": _rng.randf_range(11.0, 20.0) * (1.0 - 0.3 * u), "seed": _rng.randf() * TAU})


func _emit_ember(blade: PackedVector2Array, power: float) -> void:
	var p: Vector2 = _blade_point(blade, _rng.randf())
	_embers.append({"p": p, "v": Vector2(_rng.randf_range(-110, 110), -_rng.randf_range(90, 300)) * power,
			"life": 0.0, "max": _rng.randf_range(0.6, 1.4), "w": _rng.randf_range(1.6, 3.2), "seed": _rng.randf() * TAU})


## The spine of the hero's katana on the presentation layer, guard to tip (same shape as the rig's
## drawing of it).
func _hero_blade() -> PackedVector2Array:
	var pose: Vector2 = _hero.call(&"_weapon_pose")
	var shoulder: Vector2 = _hero.call(&"_shoulder")
	var hand: Vector2 = shoulder + Vector2.from_angle(pose.x) * float(_hero.call(&"_arm_length"))
	var d: Vector2 = Vector2.from_angle(pose.y)
	var n: Vector2 = d.orthogonal()
	var base: Vector2 = hand + d * 4.0
	var xf: Transform2D = _hero.get_transform() * (_hero.call(&"_build_root") as Transform2D)
	var pts := PackedVector2Array()
	for i in 9:
		var u: float = float(i) / 8.0
		pts.append(xf * (base + d * (34.0 * u) + n * (-u * u * 3.2)))
	pts.append(xf * (base + d * 38.0 + n * -3.6))
	return pts


func _seam_spark(size: Vector2, power: float) -> void:
	var u: float = _rng.randf()
	var p: Vector2 = _seam_top(size).lerp(_seam_bottom(size), u)
	var normal: Vector2 = (_seam_bottom(size) - _seam_top(size)).orthogonal().normalized()
	var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
	_sparks.append({"p": p, "v": (normal * side * _rng.randf_range(80, 320) + Vector2(0, -_rng.randf_range(0, 160))) * power,
			"life": 0.0, "max": _rng.randf_range(0.25, 0.6), "col": SPARK if _rng.randf() < 0.7 else VIOLET, "w": 2.4})


func _soul_pos(soul: Dictionary) -> Vector2:
	var a: float = soul["a"]
	return (soul["base"] as Vector2) + Vector2(cos(a) * float(soul["r"]), -float(soul["y"]) + sin(a) * 10.0)


func _seam_top(size: Vector2) -> Vector2:
	return Vector2(size.x * 0.5 + SEAM, -20.0)


func _seam_bottom(size: Vector2) -> Vector2:
	return Vector2(size.x * 0.5 - SEAM, size.y + 20.0)


## A point of the boss rig (rig units at rest) on the presentation layer.
func _foe_point(rig_point: Vector2) -> Vector2:
	var local: Vector2 = Vector2(0.0, _foe.foot_y) + rig_point * DuckRig.BOSS_SCALE
	return _foe.get_transform() * local


func _draw_back() -> void:
	var size: Vector2 = _back.size
	if _vs == Vs.FLASH:
		return
	var t: float = _vs_t
	# Quick fade to black, then the halves come in over it.
	_back.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, smoothstep(0.0, 0.18, t)))
	var hero_in: float = _ease_out_back(clampf((t - 0.15) / 0.4, 0.0, 1.0))
	var foe_in: float = _ease_out_back(clampf((t - 0.35) / 0.4, 0.0, 1.0))
	var top: Vector2 = _seam_top(size)
	var bottom: Vector2 = _seam_bottom(size)
	# Left: the hero on a cold sky with speed lines.
	var dx: float = -(1.0 - hero_in) * size.x
	var left := PackedVector2Array([Vector2(-40 + dx, -20), top + Vector2(dx, 0), bottom + Vector2(dx, 0), Vector2(-40 + dx, size.y + 20)])
	_back.draw_polygon(left, PackedColorArray([COLD, COLD.lerp(COLD_DARK, 0.3), COLD_DARK, COLD_DARK]))
	for i in 14:
		var y: float = fposmod(float(i) * 61.3, size.y)
		var x: float = fposmod(float(i) * 173.0 - _time * (500.0 + float(i % 4) * 120.0), size.x * 0.75) - 80.0 + dx
		_back.draw_line(Vector2(x, y), Vector2(x + 90.0 + float(i % 3) * 40.0, y), Color(0.7, 0.88, 1.0, 0.16), 2.0, true)
	_back.draw_circle(Vector2(size.x * 0.24 + dx, size.y * 0.5), 210.0, Color(0.6, 0.85, 1.0, 0.08))
	# The burning katana warms the hero's half of the screen.
	var burn: float = _fire_on()
	if burn > 0.0:
		var blade: PackedVector2Array = _hero_blade()
		var heart: Vector2 = _blade_point(blade, 0.55)
		var flick: float = _fire_flicker()
		_glow(_back, heart + Vector2(0, 70), Vector2(520, 460), Color(1.0, 0.42, 0.1, 0.34 * burn * flick))
		_glow(_back, heart, Vector2(260, 240), Color(1.0, 0.66, 0.25, 0.3 * burn * flick))
	# Right: the boss on dark purple, a slow swirl behind it.
	var rx: float = (1.0 - foe_in) * size.x
	var right := PackedVector2Array([top + Vector2(rx, 0), Vector2(size.x + 40 + rx, -20), Vector2(size.x + 40 + rx, size.y + 20), bottom + Vector2(rx, 0)])
	_back.draw_polygon(right, PackedColorArray([FOE_BG, FOE_BG.lerp(FOE_DARK, 0.4), FOE_DARK, FOE_DARK]))
	var center := Vector2(size.x * 0.75 + rx, size.y * 0.45)
	for k in 3:
		var pts := PackedVector2Array()
		for i in 40:
			var a: float = _time * (0.6 + 0.2 * float(k)) + float(i) * 0.16 + float(k) * 2.1
			pts.append(center + Vector2(cos(a), sin(a) * 0.7) * (60.0 + float(i) * 7.0))
		_back.draw_polyline(pts, Color(PURPLE, 0.16), 6.0, true)
	if t < 0.6:
		return
	# The dark aura, pulsing behind the boss.
	var chest: Vector2 = _foe_point(Vector2(-1, -15))
	var pulse: float = 0.5 + 0.5 * sin(_time * 4.5)
	var grow: float = smoothstep(0.6, 1.0, t)
	for k in 7:
		var r: float = (120.0 + float(k) * 28.0 + pulse * 18.0) * grow
		_back.draw_colored_polygon(_oval(chest + Vector2(0, -10), r * 0.85, r, 28), Color(PURPLE.lerp(VIOLET, 0.15 * pulse), 0.13))
	for k in 9:
		var u: float = fposmod(_time * 0.7 + float(k) / 9.0, 1.0)
		var a: float = float(k) * 0.7
		var p: Vector2 = chest + Vector2(sin(a + _time) * 90.0, 60.0 - u * 260.0)
		_back.draw_circle(p, (26.0 + u * 30.0) * grow, Color(NIGHT, 0.35 * (1.0 - u)))


## 0 before the katana catches fire, 1 once it burns.
func _fire_on() -> float:
	if _vs != Vs.FULL:
		return 0.0
	return smoothstep(IGNITE_AT, IGNITE_AT + 0.18, _vs_t)


func _fire_flicker() -> float:
	return 0.82 + 0.1 * sin(_time * 23.0) + 0.08 * sin(_time * 7.3 + 1.1)


## The light of the burning katana (drawn additively over the flames' bodies): warm light over
## the hero, the hot inside of the tongues, a white-hot blade, embers and the ignition flash.
func _draw_fire() -> void:
	var on: float = _fire_on()
	if on <= 0.0:
		return
	var blade: PackedVector2Array = _hero_blade()
	var heart: Vector2 = _blade_point(blade, 0.55)
	var flick: float = _fire_flicker()
	_glow(_fire, heart + Vector2(-20, 60), Vector2(300, 300), Color(1.0, 0.4, 0.08, 0.2 * on * flick))
	_glow(_fire, heart, Vector2(140, 120), Color(1.0, 0.6, 0.2, 0.32 * on * flick))
	# The white-hot inside of the tongues.
	for i in range(1, blade.size()):
		var h: float = _tongue_height(i, blade.size()) * on
		var tip: Vector2 = blade[i] + Vector2(_tongue_sway(i, 0.3), -h * 0.3)
		_fire.draw_colored_polygon(_flame_shape(blade[i], 4.5, tip), Color(FIRE_CORE, 0.45 * on))
	_fire.draw_polyline(blade, Color(FIRE_RED, 0.5 * on), 20.0, true)
	_fire.draw_polyline(blade, Color(FIRE_ORANGE, 0.6 * on * flick), 12.0, true)
	_fire.draw_polyline(blade, Color(FIRE_YELLOW, 0.8 * on), 6.0, true)
	_fire.draw_polyline(blade, Color(FIRE_CORE, on), 2.6, true)
	for e in _embers:
		var u: float = float(e["life"]) / float(e["max"])
		var p: Vector2 = e["p"]
		var v: Vector2 = e["v"]
		var col: Color = FIRE_CORE.lerp(FIRE_YELLOW, smoothstep(0.0, 0.3, u)).lerp(FIRE_RED, smoothstep(0.4, 1.0, u))
		var a: float = (1.0 - u) * (0.7 + 0.3 * sin(_time * 30.0 + float(e["seed"])))
		_fire.draw_line(p, p - v * 0.03, Color(col, a * on), float(e["w"]), true)
		_fire.draw_circle(p, float(e["w"]) * 0.7, Color(FIRE_CORE, a * on))
	# The ignition: a burst of light along the blade.
	if _ignite > 0.0:
		var burst: float = _ignite * _ignite
		_glow(_fire, heart, Vector2.ONE * (110.0 + 240.0 * (1.0 - _ignite)), Color(1.0, 0.9, 0.65, burst))
		_fire.draw_polyline(blade, Color(1, 1, 1, burst), 10.0, true)
		for i in 10:
			var a: float = TAU * float(i) / 10.0 + 0.3
			var from: Vector2 = heart + Vector2.from_angle(a) * (30.0 + 60.0 * (1.0 - _ignite))
			_fire.draw_line(from, from + Vector2.from_angle(a) * 90.0 * _ignite, Color(FIRE_YELLOW, burst), 3.0, true)


## The bodies of the flames: rising puffs and tongues licking up from the whole blade (always
## upwards, whatever the blade's angle), yellow at the root, orange, then red as they thin out.
func _draw_fire_body() -> void:
	var on: float = _fire_on()
	if on <= 0.0:
		return
	var blade: PackedVector2Array = _hero_blade()
	# Tongues licking up from every point of the blade, red outside, orange, then yellow.
	for i in range(1, blade.size()):
		var k: float = float(i) / float(blade.size() - 1)
		var h: float = _tongue_height(i, blade.size()) * on
		var r: float = 13.0 * (1.0 - 0.3 * k)
		var root: Vector2 = blade[i]
		for layer in [[1.0, 1.0, FIRE_RED, 0.7], [0.72, 0.78, FIRE_ORANGE, 0.85], [0.45, 0.52, FIRE_YELLOW, 0.9]]:
			var w: float = r * float(layer[0])
			var tip: Vector2 = root + Vector2(_tongue_sway(i, float(layer[1])), -h * float(layer[1]))
			_fire_body.draw_colored_polygon(_flame_shape(root, w, tip), Color(layer[2] as Color, float(layer[3]) * on))
	# Loose flames that break off and rise, thinning from yellow to red.
	for f in _flames:
		var u: float = float(f["life"]) / float(f["max"])
		var col: Color = _fire_grad.sample(u)
		var r: float = float(f["s"]) * (1.0 - u * 0.7) * (0.55 + 0.45 * smoothstep(0.0, 0.12, u))
		var v: Vector2 = f["v"]
		var p: Vector2 = f["p"]
		_fire_body.draw_colored_polygon(_flame_shape(p, r, p + v.normalized() * r * (2.2 + u)), Color(col, col.a * on))


## A flame: a round bottom of radius `r` at `center` drawn out into a point at `tip`.
func _flame_shape(center: Vector2, r: float, tip: Vector2) -> PackedVector2Array:
	var up: Vector2 = (tip - center).normalized()
	if up == Vector2.ZERO:
		up = Vector2.UP
	var side: Vector2 = up.orthogonal()
	var reach: float = center.distance_to(tip)
	var pts := PackedVector2Array()
	for i in 9:
		var a: float = PI * float(i) / 8.0
		pts.append(center + (side * cos(a) - up * sin(a)) * r)
	pts.append(center - side * r * 0.72 + up * reach * 0.45)
	pts.append(tip)
	pts.append(center + side * r * 0.72 + up * reach * 0.45)
	return pts


func _tongue_height(i: int, count: int) -> float:
	var k: float = float(i) / float(count - 1)
	return (110.0 + 30.0 * sin(_time * 9.0 + float(i) * 1.7) + 16.0 * sin(_time * 15.0 + float(i))) * (1.0 - 0.3 * k)


func _tongue_sway(i: int, q: float) -> float:
	return sin(_time * 8.0 + float(i) * 1.3 - q * 2.4) * q * 22.0


## A soft round light (the radial glow texture stretched over `radius`).
func _glow(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color) -> void:
	if color.a <= 0.003:
		return
	canvas.draw_texture_rect(_glow_tex, Rect2(center - radius, radius * 2.0), false, color)


func _draw_front() -> void:
	var size: Vector2 = _front.size
	if _vs == Vs.FLASH:
		_draw_name_flash(size)
		return
	var t: float = _vs_t
	var top: Vector2 = _seam_top(size)
	var bottom: Vector2 = _seam_bottom(size)
	# The glowing seam.
	var seam: float = smoothstep(0.6, 0.8, t)
	if seam > 0.0:
		var flick: float = 0.85 + 0.15 * sin(_time * 30.0)
		_front.draw_line(top, bottom, Color(VIOLET, 0.25 * seam * flick), 26.0, true)
		_front.draw_line(top, bottom, Color(SPARK, 0.5 * seam * flick), 10.0, true)
		_front.draw_line(top, bottom, Color(1, 1, 1, seam), 3.0, true)
	# The boss's glowing eyes.
	if t >= 0.6:
		var glow: float = smoothstep(0.6, 1.0, t) * (0.75 + 0.25 * sin(_time * 6.0))
		for eye in _eye_spots():
			var p: Vector2 = _foe_point(eye)
			var col: Color = _eye_color()
			_front.draw_circle(p, 34.0, Color(col, 0.12 * glow))
			_front.draw_circle(p, 18.0, Color(col, 0.3 * glow))
			_front.draw_circle(p, 7.0, Color(1, 1, 1, 0.8 * glow))
			_front.draw_line(p + Vector2(-46, 0) * glow, p + Vector2(46, 0) * glow, Color(col, 0.6 * glow), 2.0, true)
	for soul in _souls:
		var u: float = float(soul["life"]) / float(soul["max"])
		_draw_ghost(_front, soul, smoothstep(0.0, 0.15, u) * (1.0 - u), u)
	for sp in _sparks:
		var u: float = float(sp["life"]) / float(sp["max"])
		var p: Vector2 = sp["p"]
		var v: Vector2 = sp["v"]
		_front.draw_line(p, p - v * 0.035, Color(sp["col"] as Color, 1.0 - u), float(sp["w"]), true)
	# "VS" slams into the middle, sharp from its first frame; the flash bursts behind it.
	if t >= VS_AT:
		var since: float = t - VS_AT
		var flash: float = 1.0 - smoothstep(0.0, 0.45, since)
		var mid := Vector2(size.x * 0.5, size.y * 0.47)
		if flash > 0.0:
			_glow(_front, mid, Vector2.ONE * (150.0 + 300.0 * (1.0 - flash)), Color(1.0, 0.95, 0.82, 0.9 * flash))
			for i in 16:
				var a: float = TAU * float(i) / 16.0 + 0.2
				_front.draw_line(mid + Vector2.from_angle(a) * (110.0 + 120.0 * (1.0 - flash)), mid + Vector2.from_angle(a) * (170.0 + 260.0 * (1.0 - flash)), Color(SPARK, flash), 4.0, true)
		# A quick punch: a touch big on impact, settled in a tenth of a second.
		var s: float = lerpf(1.3, 1.0, smoothstep(0.0, 0.1, since))
		var height: float = 130.0
		var w: float = InkType.measure(vs_text, height)
		var style := InkType.Style.new()
		style.fill = Color(1.0, 0.86, 0.4)
		style.extrude = Color(0.45, 0.12, 0.5)
		style.depth = 1.2
		style.wobble = 0.0
		style.time = _time
		style.base = Transform2D(-0.08, Vector2(s, s), 0.0, mid) * Transform2D(0.0, Vector2(-w * 0.5, -height * 0.5))
		_front.draw_set_transform_matrix(Transform2D.IDENTITY)
		InkType.draw(_front, vs_text, Vector2.ZERO, height, style)
		_front.draw_set_transform_matrix(Transform2D.IDENTITY)
	# The boss's name, big, under its side, and a line in italics.
	var name_k: float = smoothstep(1.3, 1.6, t)
	if name_k > 0.0 and not _name.is_empty():
		var height: float = 46.0
		var w: float = InkType.measure(_name, height)
		var fit: float = minf(1.0, (size.x * 0.46) / maxf(w, 1.0))
		var origin := Vector2(size.x - 40.0 - w * fit + (1.0 - name_k) * 120.0, size.y - 150.0)
		var style := InkType.Style.new()
		style.fill = Color(0.92, 0.78, 1.0)
		style.extrude = Color(0.25, 0.06, 0.3)
		style.wobble = 0.8
		style.time = _time
		style.base = Transform2D(0.0, Vector2(fit, fit), 0.0, origin)
		_draw_ink(_front, _name, height, style, Color(1, 1, 1, name_k))
		_front.draw_set_transform_matrix(Transform2D.IDENTITY)
	var sub_k: float = smoothstep(1.6, 1.9, t)
	if sub_k > 0.0 and not _subtitle.is_empty():
		var text: String = "«%s»" % _subtitle
		var font_size: int = 30
		var w: float = _italic.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var at := Vector2(size.x - 48.0 - w, size.y - 64.0 + (1.0 - sub_k) * 14.0)
		_front.draw_string_outline(_italic, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(INK, sub_k))
		_front.draw_string(_italic, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(CREAM, sub_k))


## InkType has no alpha of its own: fade it by drawing on a modulated pass only when needed.
func _draw_ink(canvas: CanvasItem, text: String, height: float, style: InkType.Style, alpha: Color) -> void:
	if alpha.a < 1.0:
		style.fill = Color(style.fill, style.fill.a * alpha.a)
		style.extrude = Color(style.extrude, style.extrude.a * alpha.a)
		style.ink = Color(style.ink, style.ink.a * alpha.a)
		style.highlight = Color(style.highlight, style.highlight.a * alpha.a)
	InkType.draw(canvas, text, Vector2.ZERO, height, style)


## The rematch: a quick slash of dark purple across the screen with the boss's name.
func _draw_name_flash(size: Vector2) -> void:
	var t: float = _vs_t
	var a: float = smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.7, FLASH_LENGTH, t))
	var y: float = size.y * 0.3
	var band := PackedVector2Array([Vector2(-20, y - 40), Vector2(size.x + 20, y - 70), Vector2(size.x + 20, y + 50), Vector2(-20, y + 80)])
	_front.draw_colored_polygon(band, Color(FOE_DARK, 0.8 * a))
	_front.draw_line(Vector2(-20, y - 40), Vector2(size.x + 20, y - 70), Color(VIOLET, a), 3.0, true)
	_front.draw_line(Vector2(-20, y + 80), Vector2(size.x + 20, y + 50), Color(VIOLET, a), 3.0, true)
	var flash: float = 1.0 - smoothstep(0.0, 0.25, t)
	_front.draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.35 * flash))
	if _name.is_empty():
		return
	var height: float = 48.0
	var w: float = InkType.measure(_name, height)
	var fit: float = minf(1.0, (size.x * 0.8) / maxf(w, 1.0))
	var slide: float = (1.0 - _ease_out_back(clampf(t / 0.3, 0.0, 1.0))) * 200.0
	var style := InkType.Style.new()
	style.fill = Color(0.92, 0.78, 1.0)
	style.extrude = Color(0.25, 0.06, 0.3)
	style.wobble = 0.8
	style.time = _time
	style.base = Transform2D(-0.03, Vector2(fit, fit), 0.0, Vector2(size.x * 0.5 - w * fit * 0.5 + slide, y - height * 0.5 * fit))
	_draw_ink(_front, _name, height, style, Color(1, 1, 1, a))
	_front.draw_set_transform_matrix(Transform2D.IDENTITY)


## A little sheet ghost: a rounded hood, a hem that ripples in points, two hollow eyes and now and
## then an open mouth; see-through white with a purple glow at the rim. It grows out of the boss,
## sways and turns a little as it rises, and leaves a faint wisp behind.
func _draw_ghost(canvas: CanvasItem, soul: Dictionary, alpha: float, age: float) -> void:
	if alpha <= 0.01:
		return
	var s: float = soul["s"]
	var salt: float = soul["seed"]
	var trail: PackedVector2Array = soul["trail"]
	for i in trail.size():
		var k: float = float(i) / float(maxi(trail.size(), 1))
		canvas.draw_circle(trail[i] + Vector2(0, s * 0.6), s * 0.5 * k, Color(0.82, 0.72, 0.98, 0.1 * alpha * k))
	var life: float = soul["life"]
	var turn: float = sin(life * 2.4 + salt) * 0.24 + float(soul["dir"]) * life * 0.22
	var grow: float = lerpf(0.45, 1.0, smoothstep(0.0, 0.18, age))
	canvas.draw_set_transform(_soul_pos(soul), turn, Vector2.ONE * grow)
	var body := PackedVector2Array()
	for i in 13:
		var a: float = PI + PI * float(i) / 12.0
		body.append(Vector2(cos(a) * s, sin(a) * s * 1.05 - s * 0.1))
	var hem: float = s * 0.95
	body.append(Vector2(s * 1.02, hem * 0.5))
	var points: int = 4
	for k in points * 2 + 1:
		var x: float = s - 2.0 * s * float(k) / float(points * 2)
		var down: bool = k % 2 == 0
		var ripple: float = sin(_time * 7.0 + salt + float(k) * 1.1) * s * 0.08
		if down:
			body.append(Vector2(x * 1.06, hem + s * 0.16 + ripple))
		else:
			body.append(Vector2(x, hem - s * 0.16 + ripple * 0.5))
	body.append(Vector2(-s * 1.02, hem * 0.5))
	var rim := PackedVector2Array(body)
	rim.append(body[0])
	canvas.draw_polyline(rim, Color(GHOST_RIM, 0.22 * alpha), maxf(s * 0.38, 4.0), true)
	canvas.draw_colored_polygon(body, Color(0.97, 0.95, 1.0, 0.58 * alpha))
	canvas.draw_polyline(rim, Color(GHOST_RIM, 0.75 * alpha), maxf(s * 0.07, 1.4), true)
	# A soft shine on the hood.
	canvas.draw_colored_polygon(_oval(Vector2(-s * 0.38, -s * 0.62), s * 0.2, s * 0.12, 12), Color(1, 1, 1, 0.45 * alpha))
	var eye := Color(GHOST_EYE, 0.88 * alpha)
	canvas.draw_colored_polygon(_oval(Vector2(-s * 0.34, -s * 0.2), s * 0.17, s * 0.26, 14), eye)
	canvas.draw_colored_polygon(_oval(Vector2(s * 0.34, -s * 0.2), s * 0.17, s * 0.26, 14), eye)
	if bool(soul["mouth"]):
		var open: float = 0.75 + 0.25 * sin(_time * 6.0 + salt)
		canvas.draw_colored_polygon(_oval(Vector2(0, s * 0.32), s * 0.13, s * 0.2 * open, 14), eye)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


func _eye_spots() -> Array:
	var head := Vector2(7, -38)
	match _look:
		DuckRig.Look.BOSS_WOODCUTTER:
			return [head + Vector2(3, -4), head + Vector2(9.5, -3.5)]
	return [head + Vector2(5, -3.5)]


func _eye_color() -> Color:
	match _look:
		DuckRig.Look.BOSS_SWAMP:
			return Color(0.72, 1.0, 0.36)
		DuckRig.Look.BOSS_STORM:
			return Color(0.56, 0.95, 1.0)
	return DuckRig.EMBER


# =====================================================================================
# Dark arena
# =====================================================================================

func _build_arena() -> void:
	# Over the sky and the far scenery, under the play field.
	_sky = _world_layer("ArenaSky", -15, _draw_sky)
	# Behind the boss.
	_aura = _world_layer("BossAura", -1, _draw_aura)
	# In front of the play field: fog and ash.
	_ground = _world_layer("ArenaGround", 36, _draw_ground)
	# Over everything in the world: vignette, lightning glare and the killing blow.
	_frame = _world_layer("ArenaFrame", 62, _draw_frame)


func _world_layer(node_name: String, z: int, drawer: Callable) -> Node2D:
	var n := Node2D.new()
	n.name = node_name
	n.z_index = z
	n.visible = false
	add_child(n)
	n.draw.connect(drawer.bind(n))
	return n


func _update_arena(delta: float) -> void:
	var rate: float = 1.0 / ARENA_IN if _dark_target > _dark else 1.0 / ARENA_OUT
	_dark = move_toward(_dark, _dark_target, delta * rate)
	_aura_k = move_toward(_aura_k, 1.0 if (_fight and _boss_alive and _vs == Vs.NONE) else 0.0, delta * 2.0)
	_rage = move_toward(_rage, 0.0, delta * 0.8)
	if _restore_in >= 0.0:
		_restore_in -= delta
		if _restore_in < 0.0:
			_dark_target = 0.0
	_bolt_flash = maxf(_bolt_flash - delta * 3.0, 0.0)
	for i in range(_bolts.size() - 1, -1, -1):
		_bolts[i]["life"] = float(_bolts[i]["life"]) - delta
		if float(_bolts[i]["life"]) <= 0.0:
			_bolts.remove_at(i)
	if _dark > 0.3 and _fight:
		_next_bolt -= delta
		if _next_bolt <= 0.0:
			_strike(false)
			_next_bolt = _rng.randf_range(3.0, 7.0)
	var on: bool = _dark > 0.0 or not _bolts.is_empty()
	for n in [_sky, _ground, _frame]:
		(n as Node2D).visible = on or (n == _frame and (_impact_t >= 0.0 or _cam_k > 0.0))
		if (n as Node2D).visible:
			(n as Node2D).queue_redraw()
	_aura.visible = _aura_k > 0.0 and is_instance_valid(_boss)
	if _aura.visible:
		_aura.queue_redraw()


# =====================================================================================
# Arena camera
# =====================================================================================

## Glides from whatever is on screen to the fixed shot of the whole arena.
func _begin_arena_cam() -> void:
	if not _fight:
		return
	var rect: Rect2 = _arena_rect()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var view: Vector2 = get_viewport_rect().size
	var z: float = minf(view.x / rect.size.x, view.y / rect.size.y)
	_cam_center = rect.get_center()
	_cam_zoom = Vector2(z, z)
	_cam_from = _screen_center()
	_cam_from_zoom = get_viewport().get_canvas_transform().get_scale().abs()
	if _cam == null:
		var current: Camera2D = get_viewport().get_camera_2d()
		_prev_cam = current
		_cam = Camera2D.new()
		_cam.name = "ArenaCamera"
		_cam.position_smoothing_enabled = false
		add_child(_cam)
		if is_instance_valid(current) and current.zoom.x > 0.0:
			_cam_from_zoom = current.zoom
	_cam.global_position = _cam_from
	_cam.zoom = _cam_from_zoom
	_cam.offset = Vector2.ZERO
	_cam.make_current()
	_cam_mode = Cam.IN
	_cam_t = 0.0


## Glides back to the player's camera (then hands the view to it and frees this one).
func _end_arena_cam() -> void:
	if _cam == null or _cam_mode == Cam.OUT:
		return
	_cam_from = _cam.global_position
	_cam_from_zoom = _cam.zoom
	_cam_mode = Cam.OUT
	_cam_t = 0.0


func _update_cam(delta: float, paused: bool) -> void:
	if _cam == null:
		_cam_k = 0.0
		return
	if not is_instance_valid(_cam):
		_cam = null
		_cam_mode = Cam.NONE
		return
	_cam_t = minf(_cam_t + delta / CAM_GLIDE, 1.0)
	var k: float = smoothstep(0.0, 1.0, _cam_t)
	match _cam_mode:
		Cam.IN:
			_cam.global_position = _cam_from.lerp(_cam_center, k)
			_cam.zoom = _cam_from_zoom.lerp(_cam_zoom, k)
			_cam_k = k
			if _cam_t >= 1.0:
				_cam_mode = Cam.HOLD
		Cam.HOLD:
			_cam.global_position = _cam_center
			_cam.zoom = _cam_zoom
			_cam_k = 1.0
		Cam.OUT:
			var to: Vector2 = _player_view_center()
			var to_zoom: Vector2 = _prev_cam.zoom if is_instance_valid(_prev_cam) else Vector2.ONE
			_cam.global_position = _cam_from.lerp(to, k)
			_cam.zoom = _cam_from_zoom.lerp(to_zoom, k)
			_cam_k = 1.0 - k
			if _cam_t >= 1.0:
				_release_cam()
				return
	# A light shake on heavy hits (it waits while the game is paused).
	if not paused:
		_shake = maxf(_shake - delta, 0.0)
	var amount: float = _shake_power * pow(_shake / 0.3, 2.0) if _shake > 0.0 else 0.0
	_cam.offset = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * amount / maxf(_cam.zoom.x, 0.01) if amount > 0.05 and not paused else Vector2.ZERO


func _release_cam() -> void:
	if is_instance_valid(_prev_cam) and _prev_cam.is_inside_tree():
		_prev_cam.make_current()
		_prev_cam.reset_smoothing()
	if is_instance_valid(_cam):
		_cam.queue_free()
	_cam = null
	_prev_cam = null
	_cam_mode = Cam.NONE
	_cam_k = 0.0
	_shake = 0.0


## A short light shake of the arena shot (only with camera shake on in the settings).
func _kick(power: float) -> void:
	if not _shake_ok or _cam == null:
		return
	_shake_power = power if _shake <= 0.0 else maxf(power, _shake_power)
	_shake = 0.3


## The world point at the centre of the screen right now.
func _screen_center() -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * (get_viewport_rect().size * 0.5)


## Where the player's camera would look now (its target clamped to its limits).
func _player_view_center() -> Vector2:
	if not is_instance_valid(_prev_cam):
		return _cam_from
	var view: Vector2 = get_viewport_rect().size
	var zoom: Vector2 = _prev_cam.zoom if _prev_cam.zoom.x > 0.0 else Vector2.ONE
	var half: Vector2 = view / zoom * 0.5
	var c: Vector2 = _prev_cam.global_position + _prev_cam.offset
	if float(_prev_cam.limit_right - _prev_cam.limit_left) >= half.x * 2.0:
		c.x = clampf(c.x, float(_prev_cam.limit_left) + half.x, float(_prev_cam.limit_right) - half.x)
	if float(_prev_cam.limit_bottom - _prev_cam.limit_top) >= half.y * 2.0:
		c.y = clampf(c.y, float(_prev_cam.limit_top) + half.y, float(_prev_cam.limit_bottom) - half.y)
	return c


## The whole arena in world space: from the arena gate to the level's right wall, from the arena
## ceiling to the bottom of the floor.
func _arena_rect() -> Rect2:
	var content: Node = _level.get_node_or_null(^"Content")
	var gate: Node2D = null
	var gates: Variant = _level.get(&"arena_gates")
	if gates is Array and not (gates as Array).is_empty():
		gate = (gates as Array)[0] as Node2D
	if gate == null and content != null:
		gate = content.get_node_or_null(^"ArenaGate") as Node2D
	if gate == null or content == null:
		return Rect2()
	var gate_rect: Rect2 = _block_rect(gate)
	var left: float = gate_rect.position.x
	var right: float = -INF
	var top: float = INF
	var bottom: float = -INF
	var floor_top: float = INF
	var wall: Node2D = content.get_node_or_null(^"WallRight") as Node2D
	var ceiling: Node2D = content.get_node_or_null(^"ArenaCeiling") as Node2D
	if wall != null:
		right = _block_rect(wall).end.x
	if ceiling != null:
		top = _block_rect(ceiling).position.y
	var boss_x: float = _boss.global_position.x
	for child in content.get_children():
		var block := child as Node2D
		if block == null or child == gate or child.get(&"size") == null or not (child is StaticBody2D):
			continue
		var r: Rect2 = _block_rect(block)
		# Without named pieces: the tallest block right of the gate is the wall, the lowest
		# horizontal block over the gate's top the ceiling.
		if wall == null and r.size.y > r.size.x and r.position.x > left:
			right = maxf(right, r.end.x)
		if ceiling == null and r.size.x > r.size.y and r.end.y <= gate_rect.position.y + 1.0 and r.position.x <= boss_x and r.end.x >= boss_x:
			top = minf(top, r.position.y)
		# The floor the boss stands on.
		if r.size.x > r.size.y and r.position.x <= boss_x and r.end.x >= boss_x and r.position.y >= _floor_y - 24.0 and r.position.y < floor_top:
			floor_top = r.position.y
			bottom = r.end.y
	if right == -INF:
		var limits: Variant = _level.get(&"camera_limits")
		right = float((limits as Rect2i).end.x) if limits is Rect2i and (limits as Rect2i).size.x > 0 else gate_rect.end.x + 1000.0
	if top == INF:
		top = gate_rect.position.y - 40.0
	if bottom == -INF:
		bottom = maxf(gate_rect.end.y, _floor_y + 40.0)
	if right <= left or bottom <= top:
		return Rect2()
	return Rect2(left, top, right - left, bottom - top)


## A level block's rectangle in world space (blocks are centred on their position).
func _block_rect(block: Node2D) -> Rect2:
	var size_value: Variant = block.get(&"size")
	var size: Vector2 = size_value if size_value is Vector2 else Vector2.ZERO
	size *= block.global_scale.abs()
	return Rect2(block.global_position - size * 0.5, size)


## A far purple bolt in the sky (and a faint glare over the view).
func _strike(big: bool) -> void:
	var view: Vector2 = get_viewport_rect().size
	var x: float = _rng.randf_range(0.1, 0.9) * view.x
	var end_y: float = view.y * _rng.randf_range(0.25, 0.45) * (1.6 if big else 1.0)
	var pts := PackedVector2Array([Vector2(x, -10)])
	var p: Vector2 = pts[0]
	for i in 9:
		p = Vector2(p.x + _rng.randf_range(-26.0, 26.0), lerpf(-10.0, end_y, float(i + 1) / 9.0))
		pts.append(p)
	var fork := PackedVector2Array([pts[4]])
	var q: Vector2 = pts[4]
	var dir: float = -1.0 if _rng.randf() < 0.5 else 1.0
	for j in 3:
		q += Vector2(dir * _rng.randf_range(10.0, 26.0), _rng.randf_range(12.0, 22.0))
		fork.append(q)
	_bolts.append({"pts": pts, "fork": fork, "life": 0.45, "salt": _rng.randf() * 10.0})
	_bolt_flash = 1.0 if big else 0.6


## Draws in screen space on a world node: undo the camera.
func _screen_space(n: Node2D) -> void:
	var to_world: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	n.draw_set_transform_matrix(n.global_transform.affine_inverse() * to_world)


func _draw_sky(n: Node2D) -> void:
	var view: Vector2 = get_viewport_rect().size
	var d: float = smoothstep(0.0, 1.0, _dark)
	_screen_space(n)
	var top := Color(0.05, 0.01, 0.08, 0.9 * d)
	var low := Color(0.16, 0.03, 0.12, 0.72 * d)
	n.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(view.x, 0), Vector2(view.x, view.y), Vector2(0, view.y)]),
			PackedColorArray([top, top, low, low]))
	# A sick glow low on the horizon.
	n.draw_polygon(PackedVector2Array([Vector2(0, view.y * 0.55), Vector2(view.x, view.y * 0.55), Vector2(view.x, view.y), Vector2(0, view.y)]),
			PackedColorArray([Color(PURPLE, 0.0), Color(PURPLE, 0.0), Color(0.45, 0.06, 0.2, 0.3 * d), Color(0.45, 0.06, 0.2, 0.3 * d)]))
	for bolt in _bolts:
		var life: float = float(bolt["life"]) / 0.45
		var on: float = life * (0.55 + 0.45 * signf(sin(float(bolt["salt"]) + life * 28.0))) * maxf(d, 0.3)
		if on <= 0.02:
			continue
		var pts: PackedVector2Array = bolt["pts"]
		n.draw_polyline(pts, Color(PURPLE, 0.3 * on), 12.0, true)
		n.draw_polyline(pts, Color(VIOLET, 0.6 * on), 5.0, true)
		n.draw_polyline(pts, Color(0.95, 0.88, 1.0, on), 2.0, true)
		n.draw_polyline(bolt["fork"], Color(VIOLET, 0.7 * on), 1.6, true)
	n.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_ground(n: Node2D) -> void:
	var view: Vector2 = get_viewport_rect().size
	var d: float = smoothstep(0.0, 1.0, _dark)
	var canvas: Transform2D = get_viewport().get_canvas_transform()
	var floor_screen: float = (canvas * Vector2(0.0, _floor_y)).y
	_screen_space(n)
	# Low red fog crawling over the floor: a soft band and drifting puffs.
	var y0: float = floor_screen - 90.0
	var y1: float = floor_screen + 30.0
	n.draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(view.x, y0), Vector2(view.x, y1), Vector2(0, y1)]),
			PackedColorArray([Color(FOG, 0.0), Color(FOG, 0.0), Color(FOG, 0.32 * d), Color(FOG, 0.32 * d)]))
	var cam_x: float = canvas.origin.x
	for k in 3:
		var speed: float = 18.0 + float(k) * 14.0
		for i in 9:
			var span: float = view.x + 320.0
			var x: float = fposmod(float(i) * 197.0 + float(k) * 71.0 + _time * speed * (1.0 if k % 2 == 0 else -1.0) + cam_x * (0.2 + 0.1 * float(k)), span) - 160.0
			var y: float = floor_screen - 18.0 - float(k) * 14.0 + sin(_time * 0.9 + float(i)) * 5.0
			var r: float = 70.0 + float((i * 37 + k * 11) % 50)
			n.draw_colored_polygon(_oval(Vector2(x, y), r, r * 0.32, 18), Color(FOG.lerp(Color(0.25, 0.02, 0.06), float(k) * 0.3), 0.1 * d))
	# Ash drifting down, a few embers among it.
	for i in _ash.size():
		var a: Vector3 = _ash[i]
		var px: float = fposmod(a.x * (view.x + 40.0) + sin(_time * 0.8 + a.y * 9.0) * 26.0 - _time * 14.0 * a.z, view.x + 40.0) - 20.0
		var py: float = fposmod(a.y * (view.y + 20.0) + _time * 42.0 * a.z, view.y + 20.0) - 10.0
		var spin: float = _time * 2.0 * a.z + float(i)
		var r: float = 1.6 + a.z * 1.6
		if i % 9 == 0:
			n.draw_circle(Vector2(px, py), r * 0.8, Color(1.0, 0.45, 0.25, 0.7 * d))
		else:
			n.draw_colored_polygon(PackedVector2Array([Vector2(px, py) + Vector2(r, 0).rotated(spin), Vector2(px, py) + Vector2(0, r * 0.5).rotated(spin),
					Vector2(px, py) + Vector2(-r, 0).rotated(spin), Vector2(px, py) + Vector2(0, -r * 0.5).rotated(spin)]), Color(0.2, 0.18, 0.2, 0.75 * d))
	n.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_frame(n: Node2D) -> void:
	var view: Vector2 = get_viewport_rect().size
	var d: float = smoothstep(0.0, 1.0, _dark)
	_screen_space(n)
	if d > 0.0:
		_vignette_band(n, view, view * Vector2(0.24, 0.3), 0.8 * d)
		_vignette_band(n, view, view * Vector2(0.07, 0.09), 0.55 * d)
	if _cam_k > 0.0:
		_draw_arena_edges(n, view, smoothstep(0.0, 1.0, _cam_k))
	if _bolt_flash > 0.0:
		n.draw_rect(Rect2(Vector2.ZERO, view), Color(VIOLET, 0.1 * _bolt_flash * maxf(d, 0.3)))
	if _impact_t >= 0.0:
		_draw_impact(n, view)
	n.draw_set_transform_matrix(Transform2D.IDENTITY)


## The arena shot ends in darkness at the left and right so the edge of the scenery never shows.
func _draw_arena_edges(n: Node2D, view: Vector2, k: float) -> void:
	for band in [[0.14, 0.6], [0.06, 0.7], [0.02, 0.9]]:
		var w: float = view.x * float(band[0])
		var solid := Color(EDGE_DARK, float(band[1]) * k)
		var clear := Color(EDGE_DARK, 0.0)
		n.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, view.y), Vector2(0, view.y)]),
				PackedColorArray([solid, clear, clear, solid]))
		n.draw_polygon(PackedVector2Array([Vector2(view.x - w, 0), Vector2(view.x, 0), view, Vector2(view.x - w, view.y)]),
				PackedColorArray([clear, solid, solid, clear]))


func _vignette_band(n: Node2D, view: Vector2, inset: Vector2, alpha: float) -> void:
	var col := Color(0.04, 0.0, 0.05)
	var tl := Vector2.ZERO
	var tr := Vector2(view.x, 0)
	var br := view
	var bl := Vector2(0, view.y)
	var itl := inset
	var itr := Vector2(view.x - inset.x, inset.y)
	var ibr := view - inset
	var ibl := Vector2(inset.x, view.y - inset.y)
	var colors := PackedColorArray([Color(col, alpha), Color(col, alpha), Color(col, 0.0), Color(col, 0.0)])
	n.draw_polygon(PackedVector2Array([tl, tr, itr, itl]), colors)
	n.draw_polygon(PackedVector2Array([tr, br, ibr, itr]), colors)
	n.draw_polygon(PackedVector2Array([br, bl, ibl, ibr]), colors)
	n.draw_polygon(PackedVector2Array([bl, tl, itl, ibl]), colors)


## The killing blow: a white flash, impact lines rushing at the boss and cinema bars.
func _draw_impact(n: Node2D, view: Vector2) -> void:
	var t: float = _impact_t
	var at: Vector2 = get_viewport().get_canvas_transform() * _impact_at
	var flash: float = 1.0 - smoothstep(0.0, 0.22, t)
	n.draw_rect(Rect2(Vector2.ZERO, view), Color(1, 1, 1, 0.6 * flash))
	var lines: float = smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.45, IMPACT_LENGTH, t))
	if lines > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = 911 + int(t * 24.0)
		for i in 44:
			var a: float = TAU * float(i) / 44.0 + rng.randf_range(-0.05, 0.05)
			var dir: Vector2 = Vector2.from_angle(a)
			var outer: Vector2 = at + dir * view.length()
			var inner: Vector2 = at + dir * rng.randf_range(120.0, 260.0)
			var w: float = rng.randf_range(2.0, 7.0)
			var side: Vector2 = dir.orthogonal() * w
			n.draw_colored_polygon(PackedVector2Array([inner, outer + side, outer - side]), Color(INK, 0.55 * lines))
		var ring: float = smoothstep(0.0, 0.5, t)
		n.draw_arc(at, 40.0 + 220.0 * ring, 0.0, TAU, 48, Color(1, 1, 1, 0.7 * (1.0 - ring)), 6.0 * (1.0 - ring) + 1.0, true)
	var bars: float = smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.55, IMPACT_LENGTH, t))
	if bars > 0.0:
		var h: float = view.y * 0.1 * bars
		n.draw_rect(Rect2(0, 0, view.x, h), Color(0, 0, 0, 0.92))
		n.draw_rect(Rect2(0, view.y - h, view.x, h), Color(0, 0, 0, 0.92))


## The dark aura around the boss while it fights (stronger right after its rage starts).
func _draw_aura(n: Node2D) -> void:
	if not is_instance_valid(_boss):
		return
	var c: Vector2 = n.to_local(_boss.global_position + Vector2(0, -16))
	var k: float = _aura_k * (1.0 + _rage * 0.6)
	var pulse: float = 0.5 + 0.5 * sin(_time * 4.0)
	for i in 6:
		var r: float = 44.0 + float(i) * 11.0 + pulse * 8.0
		n.draw_colored_polygon(_oval(c, r * 0.8, r, 24), Color(PURPLE.darkened(0.25), 0.07 * k))
	for i in 8:
		var u: float = fposmod(_time * 0.6 + float(i) / 8.0, 1.0)
		var p: Vector2 = c + Vector2(sin(float(i) * 1.9 + _time * 1.3) * 36.0, 30.0 - u * 110.0)
		n.draw_circle(p, 9.0 + u * 12.0, Color(NIGHT, 0.4 * (1.0 - u) * k))
	for i in 5:
		var u: float = fposmod(_time * 0.9 + float(i) * 0.37, 1.0)
		var p: Vector2 = c + Vector2(sin(float(i) * 2.7 + _time * 2.0) * 50.0, 40.0 - u * 120.0)
		n.draw_circle(p, 1.8, Color(VIOLET, (1.0 - u) * k))


# =====================================================================================
# Helpers
# =====================================================================================

func _oval(c: Vector2, rx: float, ry: float, steps: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a: float = TAU * float(i) / float(steps)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _ease_out_back(x: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
