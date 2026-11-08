extends Node
## Autoload. Music and sound effects for the whole game, without touching gameplay code:
## it picks the music from the current scene, and it hooks SFX to the signals of nodes as
## they enter the tree (Player, Hurtbox, EnemyBase, BossBase, Checkpoint, HealthOrb,
## SoulFragment and every BaseButton). Music plays on the "Music" bus and effects on "SFX",
## so the Options sliders (GameSettings) drive them. Credits: frontend/audio/CREDITS.md.

const MUSIC_DIR: String = "res://frontend/audio/music/"
const SFX_DIR: String = "res://frontend/audio/sfx/"

## Scene id (from the scene file name) -> music track. Unlisted scenes keep the current track.
const SCENE_MUSIC: Dictionary = {
	"main_menu": "title_screen.ogg",
	"ending": "title_screen.ogg",
	"tutorial": "treacherous_path.ogg",
	"level_1": "castle_on_the_mountain.ogg",
	"level_2": "castle_on_the_mountain.ogg",
	"level_3": "dungeon.ogg",
}
const BOSS_MUSIC: String = "the_evil_one.ogg"
const GAME_OVER_MUSIC: String = "game_over.ogg"

const MUSIC_DB: float = -10.0
const SFX_DB: float = -4.0
const FADE_TIME: float = 0.8
const SFX_VOICES: int = 12
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()


## Releases every stream so no audio resource is still in use when the game quits.
func _exit_tree() -> void:
	if _active_music == null:
		return
	for player in [_music_a, _music_b] + _voices:
		player.stop()
		player.stream = null
	_cache.clear()


func _process(delta: float) -> void:
	_scene_age += delta


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


## Cross-fades to a track from frontend/audio/music. Same track again does nothing.
func play_music(file: String, loop: bool = true) -> void:
	if _active_music == null:
		return
	if file == _current_track and _active_music.playing:
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
	_active_music.play()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_active_music, "volume_db", MUSIC_DB, FADE_TIME)
	if old.playing:
		tween.tween_property(old, "volume_db", -60.0, FADE_TIME)
		tween.chain().tween_callback(old.stop)


# =====================================================================================
# Music by scene
# =====================================================================================

func _on_scene_changed() -> void:
	_scene_age = 0.0
	var scene: Node = get_tree().current_scene
	if scene == null:
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
		p.heavy_attack_started.connect(play_sfx.bind("swing_3.wav", 0.05, 0.0, 0.8))
		p.dash_started.connect(play_sfx.bind("dash.ogg", 0.1, 2.0, 1.2))
		p.dash_slash_started.connect(play_sfx.bind("swing_2.wav", 0.05, 0.0, 1.25))
		p.wave_cast.connect(_on_wave_cast)
		p.state_changed.connect(_on_player_state_changed)
		p.died.connect(_on_player_died)
		p.respawned.connect(_on_player_respawned)
	elif node is Hurtbox:
		var hb := node as Hurtbox
		hb.hit_received.connect(_on_hit_received.bind(hb))
	elif node is BossBase:
		var boss := node as BossBase
		boss.activated.connect(_on_boss_activated)
		boss.defeated.connect(_on_boss_defeated)
	elif node is EnemyBase:
		(node as EnemyBase).died.connect(_on_enemy_died)
	elif node is Checkpoint:
		(node as Checkpoint).activated.connect(_on_checkpoint)
	elif node is HealthOrb:
		(node as HealthOrb).collected.connect(_on_orb_collected)
	elif node is SoulFragment:
		(node as SoulFragment).collected.connect(_on_fragment_collected)
	elif node is BaseButton:
		var b := node as BaseButton
		b.pressed.connect(play_sfx.bind("ui_click.ogg", 0.03))
		b.mouse_entered.connect(_on_button_hover.bind(b))
		b.focus_entered.connect(_on_button_focus)


func _swing() -> void:
	play_sfx("swing_%d.wav" % _rng.randi_range(1, 2), 0.08)


func _on_wave_cast(tier: int) -> void:
	play_sfx("wave_cast.wav", 0.04, 0.0, 1.0 + 0.08 * float(tier))


func _on_player_state_changed(old_state: int, new_state: int) -> void:
	if new_state == Player.State.JUMP:
		play_sfx("jump.ogg", 0.05, -2.0, 1.1)
	elif old_state == Player.State.FALL and (new_state == Player.State.IDLE or new_state == Player.State.RUN):
		play_sfx("land.ogg", 0.1, -6.0)


func _on_player_died() -> void:
	play_sfx("player_die.ogg", 0.0)
	play_music(GAME_OVER_MUSIC, false)


func _on_player_respawned() -> void:
	if _level_track != "":
		play_music(_level_track)


func _on_hit_received(_info: DamageInfo, applied: bool, hurtbox: Hurtbox) -> void:
	if not applied:
		return
	if hurtbox.owner is Player:
		play_sfx("player_hurt.wav", 0.05)
	else:
		play_sfx("hit_%d.ogg" % _rng.randi_range(1, 2), 0.1)


func _on_enemy_died(_enemy: EnemyBase) -> void:
	play_sfx("enemy_die.ogg", 0.1)


func _on_boss_activated() -> void:
	play_sfx("boss_start.wav", 0.0)
	play_music(BOSS_MUSIC)


func _on_boss_defeated(_boss: BossBase) -> void:
	play_sfx("hit_heavy.ogg", 0.0)
	play_sfx("boss_defeated.ogg", 0.0, 2.0)
	if _level_track != "":
		play_music(_level_track)


func _on_checkpoint(_id: StringName) -> void:
	play_sfx("checkpoint.ogg", 0.0, -2.0)


func _on_orb_collected(_player: Player, _amount: int) -> void:
	play_sfx("health_orb.wav", 0.08)


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
