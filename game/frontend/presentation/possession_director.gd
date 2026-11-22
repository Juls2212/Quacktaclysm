class_name PossessionDirector
extends Node
## The possession (exorcism) sequence that plays when a boss crosses its phase line (Phase 15d). Child of every level
## (level_base.tscn); reusable for any later phase change (it listens to BossBase.phase_transition_started(next_phase),
## so boss 3's several phase changes can use it as they are).
##
## While it plays (default 3 s): the boss is held in its transition (inactive, invulnerable, cooldowns frozen), its
## patterns are already cancelled, enemy projectiles in the air are cleared and the hazards driven by that boss stop;
## the player is input-locked and invulnerable (Player.story_invulnerable). The boss rises and stands up trembling
## with red eyes and a pulsing outline, the backdrop fades to red (a second multiplier on top of the Phase 14c profile
## look: Backdrop.possession_grade), a red vignette pulses, the camera shakes a little and two capped red flashes go
## off. When it ends everything is released, the boss enters phase 2 exactly as before (patterns, armor, boss 2 spikes)
## and keeps a persistent red glow and a subtle red tint until it dies or the fight is cancelled; they then fade out.
##
## With the "Efectos de corrupción" option off there is no screen tint, flash, shake or vignette: a short freeze
## (`reduced_freeze`) with the pose change and the sound keeps the pacing and the fairness. Headless runs skip the
## whole thing (no hold at all) unless `play_when_headless`. It happens once per phase per fight; retries start clean.
## A cancel (player death, boss reset, boss death, leaving the level) restores everything at once. Pausing the game
## pauses it (it runs on the scene tree delta). Presentation only: no gameplay value is changed.

signal started(next_phase: int)
signal finished
signal cancelled

@export var config: PossessionConfig
@export var play_when_headless: bool = false

## True from the start of the sequence until it ends or is cancelled.
var active: bool = false
var elapsed: float = 0.0
var duration: float = 0.0
var reduced: bool = false
## The persistent possessed look after the sequence (until the boss dies or the fight is cancelled).
var persistent: bool = false
## How many sequences have started in this level (the tests read it).
var sequences_started: int = 0
## Phases already shown in this fight (a phase never plays twice).
var phases_shown: Array = []
## The current intensities (0-1), the tests read them.
var glow_amount: float = 0.0
var rise_amount: float = 0.0
var sky_amount: float = 0.0
var vignette_amount: float = 0.0
var flash_amount: float = 0.0
## Flash starts that already fired and the shake kicks already made in this sequence.
var flashes_fired: int = 0
var kicks_made: int = 0

var _level: Node = null
var _boss: BossBase = null
var _player: Player = null
var _visual: Node = null
var _backdrop: Backdrop = null
var _fx: Node = null
var _layer: PossessionLayer = null
var _color: Color = Color(0.95, 0.12, 0.08)
var _fading: bool = false
var _fade_left: float = 0.0
var _fade_from: Array[float] = [0.0, 0.0, 0.0]
var _roared: bool = false
var _slammed: bool = false
var _time: float = 0.0


func _ready() -> void:
	if config == null:
		config = PossessionConfig.get_default()
	_level = get_parent()
	if _level == null:
		return
	_boss = _level.get(&"boss") as BossBase
	if _boss == null:
		set_process(false)
		return
	_player = _level.get_node_or_null(^"Player") as Player
	_visual = _boss.get_node_or_null(^"Visual")
	_backdrop = _level.get_node_or_null(^"Backdrop") as Backdrop
	_fx = _level.get_node_or_null(^"BossFightFx")
	_boss.phase_transition_started.connect(_on_transition_started)
	_boss.activated.connect(_on_boss_activated)
	_boss.encounter_reset.connect(_on_boss_reset)
	_boss.defeated.connect(_on_boss_defeated)
	if _player != null:
		_player.died.connect(_on_player_died)


func _exit_tree() -> void:
	if active:
		_release_world()
	AudioDirector.release_music_duck(self)
	if is_instance_valid(_boss):
		_boss.remove_meta(&"possession_played")


# ---------------------------------------------------------------------------------------------
# Triggers
# ---------------------------------------------------------------------------------------------

func _on_transition_started(next_phase: int) -> void:
	if phases_shown.has(next_phase):
		return
	if DisplayServer.get_name() == "headless" and not play_when_headless:
		return
	phases_shown.append(next_phase)
	begin(next_phase)


## Starts the sequence for the phase that begins after it. Called by the boss signal; the tests call it directly too.
func begin(next_phase: int) -> void:
	if active or _boss == null:
		return
	reduced = not GameSettings.is_corruption_effects_enabled()
	duration = config.reduced_freeze if reduced else config.duration_for(_boss.stats.boss_id)
	_color = config.color_for(_boss.stats.boss_id)
	elapsed = 0.0
	flashes_fired = 0
	kicks_made = 0
	_roared = false
	_slammed = false
	_fading = false
	active = true
	sequences_started += 1
	# The world stops: held boss, cleared projectiles and hazards, a locked and invulnerable player.
	_boss.hold_transition(self)
	_clear_projectiles()
	_stop_hazards()
	if _player != null and is_instance_valid(_player):
		_player.set_input_locked(true)
		_player.story_invulnerable = true
	_boss.set_meta(&"possession_played", true)
	AudioDirector.set_music_duck(self, AudioEvents.get_default().duck_presentation_db)
	AudioDirector.play_event(&"possession_start", _boss)
	if not reduced:
		_ensure_layer()
	started.emit(next_phase)
	_update_amounts()


func _on_boss_activated() -> void:
	# A new fight starts clean: nothing of a previous one is left, and every phase may play again.
	_hard_clear()
	phases_shown.clear()


func _on_boss_reset() -> void:
	_cancel()
	if persistent:
		_begin_fade()


func _on_boss_defeated(_defeated: Node) -> void:
	_cancel()
	if persistent or glow_amount > 0.0:
		_begin_fade()


func _on_player_died() -> void:
	_cancel()


# ---------------------------------------------------------------------------------------------
# Running
# ---------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if active:
		elapsed += delta
		_fire_events()
		if elapsed >= duration:
			_finish()
			return
		_update_amounts()
	elif _fading:
		_fade_left -= delta
		var k: float = clampf(_fade_left / maxf(config.fade_out_time, 0.001), 0.0, 1.0)
		glow_amount = _fade_from[0] * k
		sky_amount = _fade_from[1] * k
		vignette_amount = _fade_from[2] * k
		rise_amount = 0.0
		flash_amount = 0.0
		_apply()
		if _fade_left <= 0.0:
			_hard_clear()
	elif persistent:
		# The persistent look breathes a little.
		_apply()


## The whole sequence as a function of time: rise, glow, tint, vignette, flash.
func _update_amounts() -> void:
	var t: float = elapsed
	var tail: float = 0.6
	var persist_glow: float = config.persistent_glow
	var end_blend: float = smoothstep(duration - tail, duration, t)
	rise_amount = smoothstep(0.0, config.rise_time, t) * (1.0 - smoothstep(duration - 0.5, duration, t))
	glow_amount = lerpf(smoothstep(0.0, 0.8, t), persist_glow, end_blend)
	if reduced:
		sky_amount = 0.0
		vignette_amount = 0.0
		flash_amount = 0.0
	else:
		sky_amount = lerpf(smoothstep(0.0, 0.9, t), config.persistent_sky, end_blend)
		var pulse: float = 0.85 + 0.15 * sin(t * TAU * config.vignette_pulse_hz)
		vignette_amount = lerpf(config.vignette_peak * smoothstep(0.0, 0.7, t) * pulse, config.persistent_vignette, end_blend)
		flash_amount = _flash_at(t)
	_apply()


## The capped red flash at time `t`: a short triangle at each configured start (never more than the cap).
func _flash_at(t: float) -> float:
	var best: float = 0.0
	for start in config.flash_times:
		if t >= start and t <= start + config.flash_length:
			var phase: float = (t - start) / config.flash_length
			best = maxf(best, config.flash_alpha_cap * (1.0 - absf(phase * 2.0 - 1.0)))
	return minf(best, config.flash_alpha_cap)


func _fire_events() -> void:
	if not reduced:
		while flashes_fired < config.flash_times.size() and elapsed >= config.flash_times[flashes_fired]:
			flashes_fired += 1
		while kicks_made < config.shake_times.size() and elapsed >= config.shake_times[kicks_made]:
			kicks_made += 1
			if _fx != null and _fx.has_method(&"kick") and config.shake_power > 0.0:
				_fx.call(&"kick", config.shake_power)
	if not _roared and elapsed >= config.rise_time * 0.7:
		_roared = true
		AudioDirector.play_event(&"possession_roar", _boss)
	if not _slammed and elapsed >= duration - 0.45:
		_slammed = true
		AudioDirector.play_event(&"possession_slam", _boss)


func _finish() -> void:
	active = false
	_release_world()
	persistent = true
	glow_amount = config.persistent_glow
	rise_amount = 0.0
	sky_amount = 0.0 if reduced else config.persistent_sky
	vignette_amount = 0.0 if reduced else config.persistent_vignette
	flash_amount = 0.0
	_apply()
	finished.emit()


## Gives the world back: the player free and vulnerable, the music up, the boss released from its transition.
func _release_world() -> void:
	if _player != null and is_instance_valid(_player):
		_player.set_input_locked(false)
		_player.story_invulnerable = false
	if is_instance_valid(_boss):
		_boss.release_transition(self)
	AudioDirector.release_music_duck(self)


func _cancel() -> void:
	if not active:
		return
	active = false
	_release_world()
	flash_amount = 0.0
	rise_amount = 0.0
	_apply()
	cancelled.emit()


func _begin_fade() -> void:
	if _fading:
		return
	_fading = true
	_fade_left = config.fade_out_time
	_fade_from = [glow_amount, sky_amount, vignette_amount]
	persistent = false


## Everything off at once: no tint, no glow, no layer, no meta.
func _hard_clear() -> void:
	active = false
	_fading = false
	persistent = false
	glow_amount = 0.0
	rise_amount = 0.0
	sky_amount = 0.0
	vignette_amount = 0.0
	flash_amount = 0.0
	_apply()
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	if is_instance_valid(_boss):
		_boss.remove_meta(&"possession_played")


# ---------------------------------------------------------------------------------------------
# What the sequence stops
# ---------------------------------------------------------------------------------------------

## Enemy projectiles in the air disappear (the player's own waves stay).
func _clear_projectiles() -> void:
	for node in get_tree().root.find_children("*", "Projectile", true, false):
		var projectile := node as Projectile
		if projectile == null or projectile.is_queued_for_deletion():
			continue
		var hitbox := projectile.get_node_or_null(^"Hitbox") as Hitbox
		if hitbox != null and hitbox.team == CombatLayers.Team.ENEMY:
			projectile.queue_free()


## Hazards driven by this boss (the swamp floor spikes) stop; they start again by themselves with the next phase.
func _stop_hazards() -> void:
	for node in _level.find_children("*", "FloorHazard", true, false):
		var hazard := node as FloorHazard
		if hazard != null and hazard.boss == _boss:
			hazard.stop()


# ---------------------------------------------------------------------------------------------
# Applying the amounts
# ---------------------------------------------------------------------------------------------

func _ensure_layer() -> void:
	if is_instance_valid(_layer):
		return
	_layer = PossessionLayer.new()
	_layer.name = "PossessionLayer"
	add_child(_layer)
	_layer.set_look(Color(_color.r * 0.8, _color.g * 0.35, _color.b * 0.3), config.flash_color)


func _apply() -> void:
	if is_instance_valid(_visual) and _visual.has_method(&"set_possession"):
		var pose: float = clampf(rise_amount * 1.4, 0.0, 1.0)
		if glow_amount <= 0.001 and rise_amount <= 0.001:
			_visual.call(&"clear_possession")
		else:
			_visual.call(&"set_possession", glow_amount, rise_amount, pose, _color, config.rise_height, config.tremble, config.tremble_hz, config.pulse_hz)
	if _backdrop != null and is_instance_valid(_backdrop):
		var tint: Color = Color.WHITE.lerp(config.sky_tint, clampf(sky_amount, 0.0, 1.0))
		_backdrop.set_possession_grade(tint)
	if is_instance_valid(_layer):
		var breathe: float = 1.0
		if persistent and not active:
			breathe = 0.9 + 0.1 * sin(_time * TAU * config.vignette_pulse_hz)
		_layer.set_amounts(vignette_amount * breathe, flash_amount)
