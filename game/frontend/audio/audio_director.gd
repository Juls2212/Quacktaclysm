extends Node
## Autoload. Music and sound effects for the whole game, without touching gameplay code:
## it picks the music from the current scene, and it hooks SFX to the signals of nodes as
## they enter the tree (Player, Hurtbox, EnemyBase, BossBase, Checkpoint,
## SoulFragment and every BaseButton). Ducks quack (rate-limited per duck) and burst into
## feathers (FeatherBurst) when they die. Music plays on the "Music" bus and effects on "SFX",
## so the Options sliders (GameSettings) drive them. Credits: frontend/audio/CREDITS.md.
## Phase 14f: the sound events added since then (footsteps, impacts, exorcism, title card, portal,
## transition, boss sting, game over) are defined in ONE table, default_audio_events.tres, and played
## with `play_event` (cooldown and a cap of simultaneous copies per event). Each boss has its own
## music (same table). The music ducks while somebody talks (`set_music_duck`).

const MUSIC_DIR: String = "res://frontend/audio/music/"
const SFX_DIR: String = "res://frontend/audio/sfx/"

## Scene id (from the scene file name) -> music track. Unlisted scenes keep the current track.
const SCENE_MUSIC: Dictionary = {
	"main_menu": "title_screen.ogg",
	"tutorial": "treacherous_path.ogg",
	"level_1": "castle_on_the_mountain.ogg",
	"level_2": "castle_on_the_mountain.ogg",
	"level_3": "dungeon.ogg",
}
## Fallback boss music when the table has no entry for a level.
const BOSS_MUSIC: String = "the_evil_one.ogg"
## Seconds an event counts as playing when its stream length is unknown.
const EVENT_DEFAULT_LENGTH: float = 0.4
## Lowest the music may be ducked, in dB.
const MAX_DUCK_DB: float = -24.0
const GAME_OVER_MUSIC: String = "game_over.ogg"

## Decision and boss-phase sounds are built from existing files (no dedicated assets yet). Each entry
## is [file, pitch_jitter, volume_db, pitch]; Ingeniera 2 can swap the files for real ones.
const DECISION_SFX: Dictionary = {
	"released": [["checkpoint.ogg", 0.0, 0.0, 1.25], ["soul_fragment.wav", 0.0, -2.0, 1.4]],
	"kept": [["hit_heavy.ogg", 0.0, 0.0, 0.8], ["soul_fragment.wav", 0.0, -2.0, 0.6]],
}
const PHASE_TWO_SFX: Array = [["hit_heavy.ogg", 0.0, 2.0, 0.6], ["boss_start.wav", 0.0, 0.0, 0.7], ["ducks/quack_boss.wav", 0.0, 3.0, 0.7]]

const MUSIC_DB: float = -10.0
const SFX_DB: float = -4.0
const FADE_TIME: float = 0.8
const SFX_VOICES: int = 20
## UI focus sounds are ignored this long after a scene change (the first button grabs focus).
const UI_FOCUS_GRACE: float = 0.35

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _current_track: String = ""
var _level_track: String = ""
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _cache: Dictionary = {}
var _scene_age: float = 0.0
var _rng := RandomNumberGenerator.new()
## Duck instance id -> time (s) its next quack is allowed.
var _quack_ready: Dictionary = {}
## Times of the latest hit cries (the global rate limit looks at the last second).
var _cry_times: Array[float] = []
## Music profile state: current pitch / cutoff, our filter on the Music bus, who set it, the fade.
var _mix_pitch: float = 1.0
var _mix_cutoff: float = ProfileLook.FILTER_OPEN_HZ
var _lowpass: AudioEffectLowPassFilter = null
var _profile_owner: Object = null
var _profile_tween: Tween = null
## Windup sounds triggered so far and the kind of the last one (the tests read them).
var windup_count: int = 0
var last_windup_kind: StringName = &""
var _telegraphs: TelegraphSet = null
## Phase 14f. The audio table, per-event bookkeeping (when each may play again, when its copies end),
## counters the tests read, the music that was asked for, the pitch of each music player's track and
## the music ducking.
var _events: AudioEvents = null
var _event_ready: Dictionary = {}
var _event_active: Dictionary = {}
var events_played: Dictionary = {}
var events_blocked: Dictionary = {}
var _requested_track: String = ""
var _requested_pitch: float = 1.0
var _pitch_a: float = 1.0
var _pitch_b: float = 1.0
var _boss_music_active: bool = false
var _duck_owners: Dictionary = {}
var _duck_db: float = 0.0

## Ambient sounds (Phase 15t): the active slot, its gusts (each {player, t, length, level_db}), the timer to the next one and the bus of its filter.
const AMBIENT_BUS: StringName = &"Ambient"
var ambient_id: StringName = &""
var ambient_intensity: float = 1.0
## Gusts started since the ambient began (the tests read it; headless runs count none because they hear nothing).
var ambient_gusts: int = 0
var _ambient_slot: AmbientSlot = null
var _ambient_voices: Array[Dictionary] = []
var _ambient_pool: Array[AudioStreamPlayer] = []
var _ambient_wait: float = 0.0
var _ambient_bus_made: bool = false
var _ambient_paused: bool = false
var _ambient_stream: AudioStream = null

const HERO_FEATHERS := Color(0.97, 0.95, 0.86)
const ENEMY_FEATHERS := Color(0.78, 0.74, 0.66)
const BOSS_FEATHERS := Color(0.42, 0.36, 0.48)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Connected before the headless exit: the music profile must be dropped on leaving a level there too.
	get_tree().scene_changed.connect(_on_scene_changed)
	SceneManager.transition_started.connect(_on_transition_started)
	# Headless runs (the test suite) hear nothing; staying silent keeps their exit clean.
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	GameSettings.ensure_buses()
	_music_a = _make_player(GameSettings.MUSIC_BUS)
	_music_b = _make_player(GameSettings.MUSIC_BUS)
	_active_music = _music_a
	for i in SFX_VOICES:
		_voices.append(_make_player(GameSettings.SFX_BUS))
	get_tree().node_added.connect(_on_node_added)
	_on_scene_changed.call_deferred()


## Releases every stream so no audio resource is still in use when the game quits.
func _exit_tree() -> void:
	_drop_ambient_now()
	if _active_music == null:
		return
	for player in [_music_a, _music_b] + _voices:
		player.stop()
		player.stream = null
	_cache.clear()


func _process(delta: float) -> void:
	_scene_age += delta
	if _ambient_slot != null or not _ambient_voices.is_empty():
		_update_ambient(delta)


# =====================================================================================
# Public API
# =====================================================================================

## Plays a one-shot effect from frontend/audio/sfx (file name with extension).
func play_sfx(file: String, pitch_jitter: float = 0.06, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if _voices.is_empty():
		return
	var stream: AudioStream = _load(SFX_DIR + file)
	if stream == null:
		return
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.volume_db = SFX_DB + volume_db
	voice.pitch_scale = pitch * (1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter))
	voice.play()


## Plays one event of the audio table (default_audio_events.tres). Returns false, and plays nothing,
## when the event is unknown, still in its cooldown, already sounding `max_voices` times, or when its
## `source` is gone or dead.
func play_event(event_id: StringName, source: Variant = null, volume_offset_db: float = 0.0, pitch_scale: float = 1.0) -> bool:
	var event: AudioEvent = _audio_events().get_event(event_id)
	if event == null:
		push_warning("AudioDirector: unknown audio event '%s'" % event_id)
		return false
	if typeof(source) == TYPE_OBJECT and not _source_alive(source):
		_count(events_blocked, event_id)
		return false
	var now: float = _clock()
	if now < float(_event_ready.get(event_id, 0.0)):
		_count(events_blocked, event_id)
		return false
	var active: Array = _event_active.get(event_id, []) as Array
	for i in range(active.size() - 1, -1, -1):
		if float(active[i]) <= now:
			active.remove_at(i)
	if active.size() >= event.max_voices:
		_event_active[event_id] = active
		_count(events_blocked, event_id)
		return false
	var file: String = event.pick_file(_rng)
	if file.is_empty():
		return false
	var pitch: float = _rng.randf_range(event.pitch_min, maxf(event.pitch_min, event.pitch_max)) * pitch_scale
	var stream: AudioStream = _load(SFX_DIR + file)
	var length: float = stream.get_length() / pitch if stream != null and stream.get_length() > 0.0 else EVENT_DEFAULT_LENGTH
	active.append(now + length)
	_event_active[event_id] = active
	_event_ready[event_id] = now + event.cooldown
	_count(events_played, event_id)
	play_sfx(file, 0.0, event.volume_db + volume_offset_db, pitch)
	return true


## Ducks the music by `db` (negative) while `owner` needs it quiet (a guardian talking, a story scene,
## the boss presentation); 0 gives it back. Several owners: the strongest duck wins. Everything is
## released when the scene changes.
func set_music_duck(owner: Object, db: float) -> void:
	var key: int = owner.get_instance_id() if owner != null else 0
	if db >= 0.0:
		_duck_owners.erase(key)
	else:
		_duck_owners[key] = maxf(db, MAX_DUCK_DB)
	var lowest: float = 0.0
	for value: Variant in _duck_owners.values():
		lowest = minf(lowest, float(value))
	_duck_db = lowest
	if _active_music != null and _active_music.playing:
		var tween := create_tween()
		tween.tween_property(_active_music, "volume_db", _music_target_db(), _audio_events().duck_fade)


func release_music_duck(owner: Object) -> void:
	set_music_duck(owner, 0.0)


## What the music is doing, for the tests and the options: the track asked for (and its pitch), the
## level track it goes back to, whether a boss track is playing, and the duck.
func get_music_state() -> Dictionary:
	return {"requested_track": _requested_track, "requested_pitch": _requested_pitch, "level_track": _level_track,
			"boss_music": _boss_music_active, "duck_db": _duck_db}


## Cross-fades to a track from frontend/audio/music. Same track again does nothing.
## `track_pitch` multiplies the pitch of THIS track (a boss may sound faster or slower), on top of
## the adaptive-profile pitch of the level.
func play_music(file: String, loop: bool = true, track_pitch: float = 1.0) -> void:
	_requested_track = file
	_requested_pitch = track_pitch
	if _active_music == null:
		return
	if file == _current_track and _active_music.playing and is_equal_approx(track_pitch, _track_pitch_of(_active_music)):
		return
	var stream: AudioStream = _load(MUSIC_DIR + file)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	_current_track = file
	var old: AudioStreamPlayer = _active_music
	_active_music = _music_b if old == _music_a else _music_a
	_active_music.stream = stream
	_active_music.volume_db = -60.0
	if _active_music == _music_a:
		_pitch_a = track_pitch
	else:
		_pitch_b = track_pitch
	_active_music.pitch_scale = _mix_pitch * track_pitch
	_active_music.play()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_active_music, "volume_db", _music_target_db(), FADE_TIME)
	if old.playing:
		tween.tween_property(old, "volume_db", -60.0, FADE_TIME)
		tween.chain().tween_callback(old.stop)


# =====================================================================================
# Music profile (corruption presentation): pitch and low-pass of the Music bus
# =====================================================================================

## Gives the music a pitch and a low-pass cutoff (Hz), blending to them over `fade` seconds (0 = at
## once). `owner` is whoever asked (the level's ProfilePresenter), so only it can release the effect.
## Pitch 1.0 with a fully open filter is neutral and removes the filter from the bus.
func set_music_profile(pitch: float, cutoff_hz: float, fade: float = 0.0, owner: Object = null) -> void:
	_profile_owner = owner
	var end_pitch: float = clampf(pitch, 0.5, 1.5)
	var end_cutoff: float = clampf(cutoff_hz, 500.0, ProfileLook.FILTER_OPEN_HZ)
	if _profile_tween != null and _profile_tween.is_valid():
		_profile_tween.kill()
	_profile_tween = null
	if fade <= 0.0 or not is_inside_tree():
		_apply_music_mix(end_pitch, end_cutoff)
		return
	var start_pitch: float = _mix_pitch
	var start_cutoff: float = _mix_cutoff
	_profile_tween = create_tween()
	_profile_tween.tween_method(func(t: float) -> void:
			_apply_music_mix(lerpf(start_pitch, end_pitch, t),
					exp(lerpf(log(start_cutoff), log(end_cutoff), t))), 0.0, 1.0, fade)


## Back to the plain music (no pitch change, no filter on the bus).
func clear_music_profile(fade: float = 0.0) -> void:
	set_music_profile(1.0, ProfileLook.FILTER_OPEN_HZ, fade, null)


## Drops the profile only if `owner` is the one that set it (a level that is closing).
func release_music_profile(owner: Object) -> void:
	if _profile_owner == owner:
		clear_music_profile()


## Current pitch, cutoff and whether the filter is on the bus (for the tests and the options).
func get_music_profile() -> Dictionary:
	return {"pitch": _mix_pitch, "cutoff_hz": _mix_cutoff, "filter_on_bus": _find_filter_index() != -1}


func _apply_music_mix(pitch: float, cutoff_hz: float) -> void:
	_mix_pitch = pitch
	_mix_cutoff = cutoff_hz
	for player in [_music_a, _music_b]:
		if player != null:
			(player as AudioStreamPlayer).pitch_scale = pitch * _track_pitch_of(player as AudioStreamPlayer)
	GameSettings.ensure_buses()
	var bus: int = AudioServer.get_bus_index(GameSettings.MUSIC_BUS)
	var index: int = _find_filter_index()
	if cutoff_hz >= ProfileLook.FILTER_OPEN_HZ - 1.0:
		if index != -1:
			AudioServer.remove_bus_effect(bus, index)
		_lowpass = null
		return
	if index == -1:
		_lowpass = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(bus, _lowpass)
	_lowpass.cutoff_hz = cutoff_hz


## Index of our low-pass in the Music bus, or -1.
func _find_filter_index() -> int:
	if _lowpass == null:
		return -1
	var bus: int = AudioServer.get_bus_index(GameSettings.MUSIC_BUS)
	if bus < 0:
		return -1
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) == _lowpass:
			return i
	return -1


func _audio_events() -> AudioEvents:
	if _events == null:
		_events = AudioEvents.get_default()
	return _events


func _clock() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _count(counter: Dictionary, event_id: StringName) -> void:
	counter[event_id] = int(counter.get(event_id, 0)) + 1


## False for a freed source, or a player, enemy or boss that is already dead.
func _source_alive(source: Variant) -> bool:
	if not is_instance_valid(source):
		return false
	if source.get(&"is_dead") == true:
		return false
	var state: Variant = source.get(&"state")
	if source is EnemyBase and state == EnemyBase.State.DEAD:
		return false
	if source is BossBase and state == BossBase.State.DEAD:
		return false
	return true


func _track_pitch_of(player: AudioStreamPlayer) -> float:
	return _pitch_a if player == _music_a else _pitch_b


## Volume the music player of the current track should have (ducking included).
func _music_target_db() -> float:
	return MUSIC_DB + _duck_db


# =====================================================================================
# Ambient (Phase 15t): soft gusts, never a short sample repeated on a timer
# =====================================================================================

## Starts the ambient `slot_id` of the audio table (the cold wind of the endings): gusts that fade in and out, overlap a little and differ every time.
## `intensity` (0 to 1) scales how loud they are (the beats follow the wind of the scene). Calling it again only updates the intensity.
func start_ambient(slot_id: StringName, intensity: float = 1.0) -> bool:
	ambient_intensity = clampf(intensity, 0.0, 1.0)
	if ambient_id == slot_id and _ambient_slot != null:
		return true
	var slot: AmbientSlot = _audio_events().get_ambient(slot_id)
	if slot == null:
		push_warning("AudioDirector: unknown ambient '%s'" % slot_id)
		return false
	_ambient_slot = slot
	ambient_id = slot_id
	ambient_gusts = 0
	_ambient_wait = 0.5
	_ambient_stream = null
	return true


## Lets the gusts die away (their own fade-out) and starts no new one. `now` silences them at once.
func stop_ambient(now: bool = false) -> void:
	_ambient_slot = null
	ambient_id = &""
	if now:
		_drop_ambient_now()


## True while an ambient is started (its gusts may still be fading after it stopped).
func is_ambient_active() -> bool:
	return _ambient_slot != null


func ambient_voice_count() -> int:
	return _ambient_voices.size()


func _update_ambient(delta: float) -> void:
	if _ambient_pool.is_empty() and _voices.is_empty():
		# Headless: nothing is heard, nothing is played.
		return
	var tree_paused: bool = get_tree().paused
	if tree_paused != _ambient_paused:
		_ambient_paused = tree_paused
		for player in _ambient_pool:
			player.stream_paused = tree_paused
	if tree_paused:
		return
	var slot: AmbientSlot = _ambient_slot
	if slot != null:
		_ambient_wait -= delta
		if _ambient_wait <= 0.0 and _ambient_voices.size() < slot.max_voices:
			_start_gust(slot)
	for i in range(_ambient_voices.size() - 1, -1, -1):
		var voice: Dictionary = _ambient_voices[i]
		var player: AudioStreamPlayer = voice["player"] as AudioStreamPlayer
		var gust_slot: AmbientSlot = voice["slot"] as AmbientSlot
		var t: float = float(voice["t"]) + delta
		voice["t"] = t
		var length: float = float(voice["length"])
		if t >= length:
			player.stop()
			_ambient_voices.remove_at(i)
			continue
		var env: float = gust_slot.envelope(t, length)
		var follow: float = _duck_db * gust_slot.follow_duck
		player.volume_db = SFX_DB + float(voice["level_db"]) + linear_to_db(maxf(env * lerpf(0.35, 1.0, ambient_intensity), 0.0001)) + follow


func _start_gust(slot: AmbientSlot) -> void:
	var plan: Dictionary = slot.plan(_rng)
	_ambient_wait = float(plan["gap"])
	if _ambient_stream == null:
		_ambient_stream = slot.generate_wind() if slot.file.is_empty() else _load(SFX_DIR + slot.file)
	if _ambient_stream == null:
		return
	var player: AudioStreamPlayer = _ambient_player()
	if player == null:
		return
	var pitch: float = float(plan["pitch"])
	var stream_length: float = _ambient_stream.get_length()
	var looped: bool = _ambient_stream is AudioStreamWAV and (_ambient_stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	var offset: float = minf(float(plan["offset"]), maxf(stream_length - 0.5, 0.0))
	# A file shorter than a gust makes a shorter gust (never a repeated loop); the generated wind loops under its fades.
	var length: float = slot.gust_seconds if looped else minf(slot.gust_seconds, maxf((stream_length - offset) / pitch, 1.0))
	player.stream = _ambient_stream
	player.pitch_scale = pitch
	player.volume_db = -60.0
	player.bus = AMBIENT_BUS if _ambient_bus_made else GameSettings.SFX_BUS
	player.play(offset)
	ambient_gusts += 1
	_ambient_voices.append({"player": player, "slot": slot, "t": 0.0, "length": length, "level_db": float(plan["volume_db"])})


## A free ambient player (up to the slot's voices), created on the first gust; also makes the filter bus for a file that needs one.
func _ambient_player() -> AudioStreamPlayer:
	for player in _ambient_pool:
		if not player.playing:
			return player
	if _ambient_pool.size() >= 4:
		return null
	if not _ambient_bus_made and _ambient_slot != null and not _ambient_slot.file.is_empty() and _ambient_slot.lowpass_hz < 20000.0:
		_make_ambient_bus(_ambient_slot.lowpass_hz)
	var player := _make_player(AMBIENT_BUS if _ambient_bus_made else GameSettings.SFX_BUS)
	_ambient_pool.append(player)
	return player


func _make_ambient_bus(cutoff_hz: float) -> void:
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, AMBIENT_BUS)
	AudioServer.set_bus_send(index, GameSettings.SFX_BUS)
	var filter := AudioEffectLowPassFilter.new()
	filter.cutoff_hz = cutoff_hz
	AudioServer.add_bus_effect(index, filter)
	_ambient_bus_made = true


## Silences every gust, frees the players and removes the filter bus (everything is as it was before the ambient).
func _drop_ambient_now() -> void:
	_ambient_slot = null
	ambient_id = &""
	_ambient_voices.clear()
	for player in _ambient_pool:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
			player.bus = GameSettings.SFX_BUS
			player.queue_free()
	_ambient_pool.clear()
	_ambient_stream = null
	if _ambient_bus_made:
		var index: int = AudioServer.get_bus_index(AMBIENT_BUS)
		if index >= 0:
			AudioServer.remove_bus(index)
		_ambient_bus_made = false


# =====================================================================================
# Music by scene
# =====================================================================================

func _on_scene_changed() -> void:
	_scene_age = 0.0
	# Nobody keeps the music ducked across a scene change.
	if not _duck_owners.is_empty():
		_duck_owners.clear()
		_duck_db = 0.0
	_boss_music_active = false
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	# Only levels may carry a music profile; the menu, prologue and ending always sound neutral.
	if not scene is LevelBase:
		clear_music_profile()
	if _active_music == null:
		return
	var id: String = scene.scene_file_path.get_file().get_basename()
	if SCENE_MUSIC.has(id):
		_level_track = SCENE_MUSIC[id]
		play_music(_level_track)


# =====================================================================================
# SFX hooks
# =====================================================================================

func _on_node_added(node: Node) -> void:
	if node is Player:
		var p := node as Player
		p.attack_started.connect(_swing)
		p.heavy_attack_started.connect(_on_heavy_attack)
		p.dash_started.connect(play_sfx.bind("dash.ogg", 0.1, 2.0, 1.2))
		p.dash_slash_started.connect(_on_dash_slash)
		p.wave_cast.connect(_on_wave_cast)
		p.state_changed.connect(_on_player_state_changed)
		p.died.connect(_on_player_died.bind(p))
		p.respawned.connect(_on_player_respawned)
		p.focus_started.connect(play_event.bind(&"focus_start", p))
		p.double_jumped.connect(play_event.bind(&"double_jump", p))
		p.focus_completed.connect(_on_focus_completed.bind(p))
		var soul := p.get_node_or_null(^"Soul") as SoulComponent
		if soul != null:
			soul.soul_gained.connect(_on_soul_gained.bind(p))
			soul.soul_full.connect(play_event.bind(&"soul_full", p))
			soul.heal_denied.connect(_on_heal_denied.bind(p))
		var visual: Node = p.get_node_or_null(^"Visual")
		if visual != null and visual.has_signal(&"footstep"):
			visual.connect(&"footstep", _on_footstep.bind(p))
	elif node is Hurtbox:
		var hb := node as Hurtbox
		hb.hit_received.connect(_on_hit_received.bind(hb))
	elif node is BossBase:
		var boss := node as BossBase
		boss.activated.connect(_on_boss_activated.bind(boss))
		boss.defeated.connect(_on_boss_defeated)
		boss.pattern_started.connect(_on_boss_pattern.bind(boss))
		boss.phase_changed.connect(_on_boss_phase_changed.bind(boss))
	elif node is BouncePad:
		(node as BouncePad).launched.connect(_on_pad_launched.bind(node))
	elif node is FloorHazard:
		(node as FloorHazard).state_changed.connect(_on_hazard_state.bind(node))
	elif node is LeapPattern:
		(node as LeapPattern).leap_started.connect(_on_leap_started.bind(node))
		(node as LeapPattern).landed.connect(_on_leap_landed.bind(node))
	elif node is EnemyBase:
		var enemy := node as EnemyBase
		enemy.died.connect(_on_enemy_died)
		enemy.attack_phase_changed.connect(_on_enemy_attack_phase.bind(enemy))
	elif node is Checkpoint:
		(node as Checkpoint).activated.connect(_on_checkpoint)
	elif node is DecisionFlow:
		(node as DecisionFlow).decision_made.connect(_on_decision_made)
	elif node is SoulFragment:
		(node as SoulFragment).collected.connect(_on_fragment_collected)
	elif node is Projectile:
		var projectile := node as Projectile
		projectile.despawned.connect(_on_projectile_despawned.bind(projectile))
		var projectile_hitbox := projectile.get_node_or_null(^"Hitbox") as Hitbox
		if projectile_hitbox != null:
			projectile_hitbox.hit_landed.connect(_on_projectile_hit.bind(projectile))
	elif node is BossEncounter:
		(node as BossEncounter).encounter_started.connect(play_event.bind(&"boss_vs_sting"))
	elif node is GameOverPanel:
		(node as GameOverPanel).opened.connect(play_event.bind(&"game_over"))
	elif node is LevelTitleCard:
		play_event(&"title_card")
	elif node is ExorcismCutscene:
		play_event(&"exorcism")
	elif node.has_signal(&"portal_lit"):
		node.connect(&"portal_lit", play_event.bind(&"portal_lit"))
		node.connect(&"portal_entered", play_event.bind(&"portal_enter"))
	elif node is BaseButton:
		var b := node as BaseButton
		b.pressed.connect(play_sfx.bind("ui_click.ogg", 0.03))
		b.mouse_entered.connect(_on_button_hover.bind(b))
		b.focus_entered.connect(_on_button_focus)


func _on_footstep(player: Node) -> void:
	play_event(&"footstep", player)


func _on_transition_started(_scene_id: String) -> void:
	play_event(&"transition")


## A projectile reached somebody. The player's sword wave sounds different from an enemy projectile.
func _on_projectile_hit(hurtbox: Hurtbox, _info: DamageInfo, projectile: Projectile) -> void:
	if not is_instance_valid(projectile):
		return
	if projectile.source is Player:
		play_event(&"wave_impact")
	elif is_instance_valid(hurtbox) and hurtbox.owner is Player:
		play_event(&"projectile_impact_player")
	else:
		play_event(&"projectile_impact_enemy")


func _on_projectile_despawned(reason: StringName, projectile: Projectile) -> void:
	if reason != Projectile.REASON_WORLD or not is_instance_valid(projectile):
		return
	play_event(&"wave_impact_world" if projectile.source is Player else &"projectile_impact_world")


func _swing() -> void:
	play_sfx(_sword(), 0.08, 1.0, 1.1)


func _on_heavy_attack() -> void:
	play_sfx(_sword(), 0.04, 2.0, 0.78)
	play_sfx("swing_3.wav", 0.05, -3.0, 0.8)


func _on_dash_slash() -> void:
	play_sfx(_sword(), 0.05, 1.0, 1.3)
	play_sfx("swing_2.wav", 0.05, -4.0, 1.25)


func _on_wave_cast(tier: int) -> void:
	play_sfx("wave_cast.wav", 0.04, 0.0, 1.0 + 0.08 * float(tier))
	play_sfx(_sword(), 0.05, -2.0, 0.9)
	_quack("quack_hero.wav", self, 0.6, 0.06, -3.0)


func _on_pad_launched(_player: Player, pad: Node) -> void:
	play_event(&"pad_bounce", pad)


func _on_hazard_state(new_state: int, hazard: Node) -> void:
	if new_state == FloorHazard.State.WARNING:
		play_event(&"spike_warning", hazard)
	elif new_state == FloorHazard.State.ACTIVE:
		play_event(&"spike_rise", hazard)


func _on_leap_started(_from: Vector2, _to: Vector2, pattern: Node) -> void:
	play_event(&"boss_leap", pattern)


func _on_leap_landed(_position: Vector2, pattern: Node) -> void:
	play_event(&"leap_land", pattern)


func _on_player_state_changed(old_state: int, new_state: int) -> void:
	if new_state == Player.State.JUMP:
		play_sfx("jump.ogg", 0.05, -2.0, 1.1)
	elif old_state == Player.State.FALL and (new_state == Player.State.IDLE or new_state == Player.State.RUN):
		play_sfx("land.ogg", 0.1, -6.0)


func _on_player_died(player: Player) -> void:
	play_sfx("player_die.ogg", 0.0)
	play_sfx("ducks/quack_die.wav", 0.0, 2.0, 1.15)
	_feathers.call_deferred(player.get_parent(), player.global_position, HERO_FEATHERS, 18)
	play_music(GAME_OVER_MUSIC, false)


func _on_player_respawned() -> void:
	_boss_music_active = false
	if _level_track != "":
		play_music(_level_track)


func _on_hit_received(_info: DamageInfo, applied: bool, hurtbox: Hurtbox) -> void:
	var victim: Node = hurtbox.owner
	if not applied:
		# Dodged, blocked or invulnerable: steel rings against steel.
		play_sfx(_clash(), 0.1, -4.0, 1.1)
		return
	if victim is Player:
		play_sfx("player_hurt.wav", 0.05)
		_quack("quack_hurt.wav", victim, 0.25, 0.06, -1.0)
	else:
		play_sfx("hit_%d.ogg" % _rng.randi_range(1, 2), 0.1)
		play_sfx(_clash(), 0.12, -6.0)
		if victim != null and (victim is BossBase or victim is EnemyBase):
			_hit_cry(victim)


func _on_enemy_died(enemy: EnemyBase) -> void:
	play_sfx("enemy_die.ogg", 0.1)
	play_sfx("ducks/quack_die.wav", 0.08)
	_feathers.call_deferred(enemy.get_parent(), enemy.global_position, ENEMY_FEATHERS, 14)


func _on_enemy_attack_phase(phase: int, enemy: EnemyBase) -> void:
	if phase == EnemyBase.AttackPhase.STARTUP:
		_play_windup(TelegraphSet.kind_of_enemy(enemy), enemy.state == EnemyBase.State.DEAD)
	elif phase == EnemyBase.AttackPhase.ACTIVE:
		play_sfx("swing_%d.wav" % _rng.randi_range(1, 3), 0.1, -3.0, 0.85)


func _on_boss_pattern(pattern_id: StringName, boss: BossBase) -> void:
	_play_windup(TelegraphSet.kind_of_pattern(pattern_id), boss.state == BossBase.State.DEAD)


## The distinct windup sound of an enemy type or boss pattern (the entries live in the telegraph
## styles, default_telegraphs.tres): played once per windup, never for something already dead.
func _play_windup(kind: StringName, dead: bool) -> void:
	if dead:
		return
	if _telegraphs == null:
		_telegraphs = TelegraphSet.get_default()
	var style: TelegraphStyle = _telegraphs.get_style(kind)
	if style == null:
		return
	windup_count += 1
	last_windup_kind = kind
	_play_set(style.windup_sounds)


func _on_boss_phase_changed(phase: int, boss: BossBase = null) -> void:
	# The possession sequence has its own sounds (Phase 15d): the phase 2 sting must not play on top of them.
	if phase >= 2 and not (boss != null and boss.has_meta(&"possession_played")):
		_play_set(PHASE_TWO_SFX)


## Releasing and keeping a fragment sound different (a bright chime / a dark thud).
func _on_decision_made(_fragment_id: String, choice: String) -> void:
	_play_set(DECISION_SFX.get(choice, []))


func _play_set(sounds: Array) -> void:
	for entry: Array in sounds:
		play_sfx(String(entry[0]), float(entry[1]), float(entry[2]), float(entry[3]))


func _on_boss_activated(boss: BossBase) -> void:
	play_sfx("boss_start.wav", 0.0)
	play_sfx("ducks/quack_boss.wav", 0.0, 3.0, 0.9)
	# Each guardian has its own music (the audio table); the level's track comes back when it falls.
	var choice: Array = _audio_events().get_boss_music(BossNames.level_number_of(boss))
	_boss_music_active = true
	if choice.size() >= 2:
		play_music(String(choice[0]), true, float(choice[1]))
	else:
		play_music(BOSS_MUSIC)


func _on_boss_defeated(boss: BossBase) -> void:
	play_sfx("hit_heavy.ogg", 0.0)
	play_sfx(_clash(), 0.0, 0.0, 0.8)
	play_sfx("ducks/quack_boss_die.wav", 0.0, 3.0)
	play_sfx("boss_defeated.ogg", 0.0, 2.0)
	_feathers.call_deferred(boss.get_parent(), boss.global_position, BOSS_FEATHERS, 30)
	_boss_music_active = false
	if _level_track != "":
		play_music(_level_track)


## Deferred: deaths arrive inside physics callbacks, where adding nodes is not allowed.
func _feathers(container: Node, at: Vector2, tint: Color, amount: int) -> void:
	if is_instance_valid(container):
		FeatherBurst.spawn(container, at, tint, amount)


func _sword() -> String:
	return "swords/sword_%d.ogg" % _rng.randi_range(1, 10)


func _clash() -> String:
	return "swords/clash_%d.ogg" % _rng.randi_range(1, 10)


## Plays a duck voice at most once every `cooldown` seconds per duck (so a crowd does not
## turn into noise).
## The cry of a duck enemy that was hit: a random file from the table, a random pitch, a per-target cooldown and a global cap per second.
func _hit_cry(victim: Node) -> bool:
	var table: AudioEvents = _audio_events()
	var now: float = Time.get_ticks_msec() / 1000.0
	var id: int = victim.get_instance_id()
	if now < float(_quack_ready.get(id, 0.0)):
		return false
	while not _cry_times.is_empty() and now - _cry_times[0] > 1.0:
		_cry_times.pop_front()
	if _cry_times.size() >= table.hit_cry_global_per_second:
		return false
	var is_boss: bool = victim is BossBase
	var files: PackedStringArray = table.boss_cry_files if is_boss else table.hit_cry_files
	if files.is_empty():
		return false
	var pitch: float = _rng.randf_range(table.hit_cry_pitch_min, table.hit_cry_pitch_max)
	var volume: float = table.boss_cry_volume_db if is_boss else table.hit_cry_volume_db
	if is_boss:
		pitch *= table.boss_pitch_factor
	elif victim is Duckling:
		pitch *= table.duckling_pitch_factor
		volume -= 3.0
	_quack_ready[id] = now + table.hit_cry_target_cooldown
	_cry_times.append(now)
	_count(events_played, &"hit_cry")
	play_sfx("ducks/" + files[_rng.randi_range(0, files.size() - 1)], 0.0, volume, pitch)
	return true


func _quack(file: String, duck: Object, cooldown: float, jitter: float, volume_db: float,
		pitch: float = 1.0) -> void:
	var id: int = duck.get_instance_id()
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < float(_quack_ready.get(id, 0.0)):
		return
	_quack_ready[id] = now + cooldown
	play_sfx("ducks/" + file, jitter, volume_db, pitch)


func _on_checkpoint(_id: StringName) -> void:
	play_sfx("checkpoint.ogg", 0.0, -2.0)


func _on_soul_gained(_amount: int, player: Node) -> void:
	play_event(&"soul_gain", player)


func _on_focus_completed(_healed: int, player: Node) -> void:
	play_event(&"heal_done", player)


func _on_heal_denied(_reason: StringName, player: Node) -> void:
	play_event(&"heal_denied", player)


func _on_fragment_collected(_fragment: SoulFragment) -> void:
	play_sfx("soul_fragment.wav", 0.0)


func _on_button_hover(button: BaseButton) -> void:
	if not button.disabled:
		play_sfx("ui_hover.ogg", 0.05, -4.0)


func _on_button_focus() -> void:
	if _scene_age > UI_FOCUS_GRACE and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		play_sfx("ui_hover.ogg", 0.05, -4.0)


# =====================================================================================
# Helpers
# =====================================================================================

func _make_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


func _load(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) as AudioStream if ResourceLoader.exists(path) else null
		if _cache[path] == null:
			push_warning("AudioDirector: missing audio %s" % path)
	return _cache[path]
