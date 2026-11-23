class_name BloodFx
extends Node2D
## Stylized combat blood (Phase 15k). One node per level that watches hits and deaths (read-only: it only listens to signals, so it can
## never change damage, hitboxes or collision, and the run statistics never see it) and draws short spurts of droplets and floor stains that fade out. Blood is
## ONLY for gameplay combat: this node lives in level_base.tscn and nowhere else (never in the ending cinematics or story scenes).
## Rules by victim (the same for every attack kind, the sword wave included): a hit that LANDED makes a spurt, a blocked or dodged hit
## (guard, shield bubble, dash invulnerability) makes none (the existing sparks and clash sound stay); a kill makes a burst; ducklings
## bleed less; bosses spurt on hits and burst on defeat; the player gets a small spurt. A victim that is not alive (a spirit, a shell)
## sets the meta `no_blood` and never bleeds. The "Sangre" option off = this node draws and stores nothing. Drawn BELOW the telegraphs
## (z -1), the hazards and the boss platforms (z 2).

const LAYER_Z: int = -2
const SETTINGS_REFRESH_MSEC: int = 500

@export var config: BloodConfig = null

var droplets: Array[Dictionary] = []
var stains: Array[Dictionary] = []
var enabled: bool = true
var reduced: bool = false

var _rng := RandomNumberGenerator.new()
var _last_refresh: int = -100000


func _ready() -> void:
	if config == null:
		config = BloodConfig.get_default()
	z_index = LAYER_Z
	_rng.randomize()
	refresh_settings()
	get_tree().node_added.connect(_on_node_added)
	if get_parent() != null:
		_scan(get_parent())
	set_process(false)


## Reads "Sangre" and "Efectos de corrupcion" (cached for half a second: a hit never reads the settings file).
func refresh_settings() -> void:
	_last_refresh = Time.get_ticks_msec()
	var values: Dictionary = GameSettings.load_settings()
	var was_on: bool = enabled
	enabled = bool(values["blood"])
	reduced = not bool(values["corruption_effects"])
	if was_on and not enabled:
		clear()


func clear() -> void:
	droplets.clear()
	stains.clear()
	queue_redraw()


func _scan(root: Node) -> void:
	for node in root.find_children("*", "", true, false):
		_on_node_added(node)


func _on_node_added(node: Node) -> void:
	if node is Hurtbox:
		var hurtbox := node as Hurtbox
		hurtbox.hit_received.connect(_on_hit_received.bind(hurtbox), CONNECT_REFERENCE_COUNTED)
	elif node is EnemyBase:
		(node as EnemyBase).died.connect(_on_enemy_died, CONNECT_REFERENCE_COUNTED)
	elif node is BossBase:
		(node as BossBase).defeated.connect(_on_boss_defeated, CONNECT_REFERENCE_COUNTED)
	elif node is Player:
		(node as Player).died.connect(_on_player_died.bind(node), CONNECT_REFERENCE_COUNTED)
		(node as Player).respawned.connect(clear, CONNECT_REFERENCE_COUNTED)


## Does this victim bleed at all? (Alive things do; anything with the meta `no_blood` does not.)
static func bleeds(victim: Node) -> bool:
	return victim != null and not victim.has_meta(&"no_blood")


## Share of the full amount for this victim: ducklings bleed less, the reduced mode keeps blood with fewer droplets.
func scale_for(victim: Node) -> float:
	var share: float = config.duckling_scale if victim is Duckling else 1.0
	return share * (config.reduced_scale if reduced else 1.0)


func _on_hit_received(info: DamageInfo, applied: bool, hurtbox: Hurtbox) -> void:
	var victim: Node = hurtbox.owner
	if not applied or not is_instance_valid(victim) or not bleeds(victim):
		return
	var at: Vector2 = (victim as Node2D).global_position if victim is Node2D else hurtbox.global_position
	var dir: Vector2 = _direction(info, at)
	victim.set_meta(&"blood_dir", dir)
	var count: int = config.hit_droplets
	if victim is BossBase:
		count = config.boss_hit_droplets
	elif victim is Player:
		count = config.player_hit_droplets
	spurt(at, dir, count, scale_for(victim))


func _on_enemy_died(enemy: EnemyBase) -> void:
	if is_instance_valid(enemy) and bleeds(enemy):
		spurt(enemy.global_position, enemy.get_meta(&"blood_dir", Vector2.UP), config.kill_droplets, scale_for(enemy), 1.6)


func _on_boss_defeated(boss: BossBase) -> void:
	if is_instance_valid(boss) and bleeds(boss):
		spurt(boss.global_position, Vector2.UP, config.boss_defeat_droplets, scale_for(boss), 2.4)


func _on_player_died(player: Node) -> void:
	if is_instance_valid(player) and bleeds(player):
		spurt((player as Node2D).global_position, Vector2.UP, config.player_death_droplets, scale_for(player), 1.4)


static func _direction(info: DamageInfo, at: Vector2) -> Vector2:
	if info.knockback.length() > 1.0:
		return info.knockback.normalized()
	if info.source is Node2D:
		var away: Vector2 = at - (info.source as Node2D).global_position
		if away.length() > 1.0:
			return away.normalized()
	return Vector2.UP


## Throws `amount` droplets from `at` in `dir` (scaled; at least one when the amount is above zero). Returns how many were created.
## Nothing at all happens while the option is off.
func spurt(at: Vector2, dir: Vector2, amount: int, share: float = 1.0, spread_factor: float = 1.0) -> int:
	if Time.get_ticks_msec() - _last_refresh > SETTINGS_REFRESH_MSEC:
		refresh_settings()
	if not enabled or amount <= 0:
		return 0
	var count: int = maxi(1, roundi(amount * share))
	var floor_y: float = _floor_y(at)
	var made: int = 0
	for i in count:
		if droplets.size() >= config.max_droplets:
			break
		var angle: float = dir.angle() + _rng.randf_range(-config.spread, config.spread) * spread_factor
		var speed: float = _rng.randf_range(config.speed_min, config.speed_max)
		var life: float = _rng.randf_range(config.life_min, config.life_max)
		droplets.append({
			"p": at + Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-8.0, 8.0)),
			"v": Vector2.from_angle(angle) * speed,
			"life": life, "max": life,
			"size": _rng.randf_range(config.size_min, config.size_max),
			"floor": floor_y,
		})
		made += 1
	set_process(true)
	return made


## The floor under `at` (world layer), or NAN when there is none.
func _floor_y(at: Vector2) -> float:
	if not is_inside_tree() or get_world_2d() == null:
		return NAN
	var query := PhysicsRayQueryParameters2D.create(at, at + Vector2(0.0, 360.0), CombatLayers.layer_bit(CombatLayers.LAYER_WORLD))
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return float((hit["position"] as Vector2).y) if not hit.is_empty() else NAN


func _process(delta: float) -> void:
	for i in range(droplets.size() - 1, -1, -1):
		var d: Dictionary = droplets[i]
		d["life"] = float(d["life"]) - delta
		d["v"] = (d["v"] as Vector2) + Vector2(0.0, config.gravity * delta)
		d["p"] = (d["p"] as Vector2) + (d["v"] as Vector2) * delta
		var landed: bool = not is_nan(float(d["floor"])) and (d["p"] as Vector2).y >= float(d["floor"])
		if landed:
			_add_stain(Vector2((d["p"] as Vector2).x, float(d["floor"])), float(d["size"]))
		if landed or float(d["life"]) <= 0.0:
			droplets.remove_at(i)
	for i in range(stains.size() - 1, -1, -1):
		stains[i]["age"] = float(stains[i]["age"]) + delta
		if float(stains[i]["age"]) >= config.stain_fade_seconds:
			stains.remove_at(i)
	queue_redraw()
	if droplets.is_empty() and stains.is_empty():
		set_process(false)


func _add_stain(at: Vector2, size: float) -> void:
	if _rng.randf() > 0.4:
		return
	while stains.size() >= config.max_stains:
		stains.remove_at(0)
	stains.append({"p": at + Vector2(0.0, -1.5), "age": 0.0, "r": size * _rng.randf_range(1.6, 3.0)})


func _draw() -> void:
	if not enabled:
		return
	for s in stains:
		var fade: float = 1.0 - float(s["age"]) / config.stain_fade_seconds
		var alpha: float = config.stain_opacity * clampf(fade * 2.0, 0.0, 1.0)
		var points := PackedVector2Array()
		for k in 14:
			var a: float = TAU * k / 14.0
			points.append((s["p"] as Vector2) + Vector2(cos(a) * float(s["r"]), sin(a) * float(s["r"]) * 0.28))
		draw_colored_polygon(points, Color(config.blood_color, alpha))
		points.append(points[0])
		draw_polyline(points, Color(config.outline_color, alpha * 0.8), 1.0)
	for d in droplets:
		var u: float = clampf(float(d["life"]) / float(d["max"]), 0.0, 1.0)
		var size: float = float(d["size"]) * (0.5 + 0.5 * u)
		draw_circle(d["p"], size + 1.2, config.outline_color)
		draw_circle(d["p"], size, config.blood_color)
