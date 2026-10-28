extends Node2D
## Sandbox for the combat framework. Debug keys are handled here only (not in the input map):
## F fires a player-team hitbox in front of the player, R resets, L reloads the scene.

const TEST_HITBOX_SIZE: Vector2 = Vector2(60.0, 50.0)
const TEST_HITBOX_OFFSET: float = 50.0
const TEST_HITBOX_LIFETIME: float = 0.15
const TEST_HITBOX_DAMAGE: int = 1
const TEST_HITBOX_KNOCKBACK: Vector2 = Vector2(200.0, -100.0)

@onready var player: Player = $Player
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var one_shot_hitbox: Hitbox = $OneShotHitbox
@onready var hud: PlayerHealthHud = $Hud
@onready var debug_label: Label = $DebugLayer/DebugLabel


func _ready() -> void:
	player.global_position = spawn_point.global_position
	player.set_respawn_point(spawn_point.global_position)
	hud.bind(player)


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_F:
			_fire_test_hitbox()
		KEY_R:
			_reset_all()
		KEY_L:
			get_tree().reload_current_scene()


func _process(_delta: float) -> void:
	debug_label.text = "health: %d/%d\ninvulnerable: %s\nstate: %s (hurt: %s)\ndead: %s\n[J/X/click] attack  [F] fire hitbox  [R] reset  [L] reload" % [
		player.health.current_health,
		player.health.max_health,
		player.is_invulnerable(),
		Player.State.keys()[player.state],
		player.state == Player.State.HURT,
		player.is_dead,
	]


func _fire_test_hitbox() -> void:
	var hitbox := Hitbox.new()
	hitbox.team = CombatLayers.Team.PLAYER
	hitbox.damage = TEST_HITBOX_DAMAGE
	hitbox.knockback = TEST_HITBOX_KNOCKBACK
	hitbox.owner_body = player
	hitbox.active_on_ready = true
	hitbox.position = player.global_position + Vector2(TEST_HITBOX_OFFSET * player.facing_direction, 0.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = TEST_HITBOX_SIZE
	shape.shape = rect
	hitbox.add_child(shape)
	add_child(hitbox)
	get_tree().create_timer(TEST_HITBOX_LIFETIME).timeout.connect(hitbox.queue_free)


func _reset_all() -> void:
	for dummy in get_tree().get_nodes_in_group("training_dummies"):
		(dummy as TrainingDummy).reset_dummy()
	one_shot_hitbox.activate()
	player.revive()
