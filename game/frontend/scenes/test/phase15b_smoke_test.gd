extends Node
## Headless smoke test for Phase 15b: the dash is invulnerable for ALL of its frames (and a KillZone still kills
## in it), the "Nueva habilidad" card waits for the corruption animation (PresentationQueue), the boss intro
## (VS, the guardian's greeting, the duck's story, then combat; first time only), the three monologues, and the
## continuous floor of the three arenas (with the intentional gaps before them intact). Development only. Run:
##   <godot> --headless --path game res://frontend/scenes/test/phase15b_smoke_test.tscn
## Uses a redirected save path; the real save and the real controls are never touched.

const TEST_SAVE: String = "user://test_save_phase15b.json"
const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const KILL_ZONE_SCENE: PackedScene = preload("res://backend/combat/kill_zone.tscn")
const EXORCISM_SCENE: PackedScene = preload("res://frontend/fx/exorcism_cutscene.tscn")
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const FLOOR_Y: float = 300.0

var failures: int = 0
var real_save_before: String = ""
var real_controls_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig


func _ready() -> void:
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
	real_controls_before = _read_file(ControlsConfig.DEFAULT_PATH)
	_run.call_deferred()


func _check(check_name: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("PASS: %s %s" % [check_name, detail])
	else:
		failures += 1
		print("FAIL: %s %s" % [check_name, detail])


func _read_file(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "<missing>"


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _clean_state() -> void:
	Engine.time_scale = 1.0
	PauseLock.reset(get_tree())
	get_tree().paused = false
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.autosave_enabled = false
	AbilityCard.forget_all()
	BossDialogue.forget_all()
	for action in [&"dash", &"move_right", &"jump", &"attack", &"heal"]:
		Input.action_release(action)


func _run() -> void:
	_clean_state()
	_test_guards()
	await _test_dash_invulnerability()
	await _test_queue()
	await _test_card_after_animation()
	_test_monologues()
	await _test_boss_intro()
	await _test_arena_floors()
	_clean_state()
	SaveSystem.purge()
	GameState.autosave_enabled = true
	_check("the real save file was not touched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	_check("the real controls file was not touched", _read_file(ControlsConfig.DEFAULT_PATH) == real_controls_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _arena() -> Node2D:
	var world := Node2D.new()
	add_child(world)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	floor_body.position = Vector2(400.0, FLOOR_Y + 20.0)
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(3000.0, 40.0)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	return world


func _grounded_player(world: Node2D) -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(0.0, FLOOR_Y - 26.0)
	world.add_child(player)
	await _physics(30)
	return player


func _enemy_hit(player: Player, amount: int = 1) -> bool:
	return player.hurtbox.receive_hit(DamageInfo.create(amount, Vector2.ZERO, null, CombatLayers.Team.ENEMY))


# ---------------------------------------------------------------------------------------------
# Guards
# ---------------------------------------------------------------------------------------------

func _test_guards() -> void:
	var keys: Array = GameState.to_dict().keys()
	keys.sort()
	var expected: Array = SAVE_KEYS.duplicate()
	expected.sort()
	_check("save: still exactly the seven keys", keys == expected, str(keys))
	var autoloads: PackedStringArray = PackedStringArray()
	for property in ProjectSettings.get_property_list():
		var property_name: String = property["name"]
		if property_name.begins_with("autoload/"):
			autoloads.append(property_name.trim_prefix("autoload/"))
	autoloads.sort()
	_check("autoloads: exactly GameState, SceneManager and AudioDirector", autoloads == PackedStringArray(["AudioDirector", "GameState", "SceneManager"]), str(autoloads))
	var stats := PlayerStats.new()
	_check("dash numbers did not change (speed 700, duration 0.18, cooldown 0.4, 1 air dash)",
		is_equal_approx(stats.dash_speed, 700.0) and is_equal_approx(stats.dash_duration, 0.18) and is_equal_approx(stats.dash_cooldown, 0.4) and stats.max_air_dashes == 1)
	_check("dash slash numbers did not change (2 damage, input buffer 0.1, extra active 0.06, extra recovery 0.12)",
		stats.dash_slash_damage == 2 and is_equal_approx(stats.dash_slash_input_buffer_time, 0.1) and is_equal_approx(stats.dash_slash_extra_active_time, 0.06)
		and is_equal_approx(stats.dash_slash_extra_recovery_time, 0.12))
	_check("dash: the extra grace after the dash is an exported value that defaults to 0", is_zero_approx(stats.dash_invulnerability_grace))
	_check("dash: there is no separate invulnerability time any more", not ("dash_invulnerability_time" in stats))


# ---------------------------------------------------------------------------------------------
# 1. Dash invulnerability = the whole dash
# ---------------------------------------------------------------------------------------------

func _test_dash_invulnerability() -> void:
	_clean_state()
	var world: Node2D = _arena()
	var player: Player = await _grounded_player(world)
	var rejected: int = 0
	var dash_frames: int = 0
	var accepted_after: Array[bool] = []
	var health_before: int = player.health.current_health
	Input.action_press(&"dash")
	await _physics(2)
	Input.action_release(&"dash")
	var guard: int = 0
	while guard < 60:
		guard += 1
		if player.state == Player.State.DASH:
			dash_frames += 1
			if not _enemy_hit(player) and player.is_dash_invulnerable and player.health.current_health == health_before:
				rejected += 1
		else:
			break
		await get_tree().physics_frame
	var dash_ended: bool = player.state != Player.State.DASH
	var first_after: bool = _enemy_hit(player)
	accepted_after.append(first_after)
	_check("dash: it lasted about 0.18 s (%d frames)" % dash_frames, dash_ended and absi(dash_frames - 11) <= 2)
	_check("dash: an enemy hit on EVERY physics frame of the dash is rejected (%d of %d)" % [rejected, dash_frames], dash_frames > 0 and rejected == dash_frames)
	_check("dash: the first frame after the dash accepts damage", first_after and player.health.current_health == health_before - 1)
	# A real enemy hitbox and a real enemy projectile also fail during the dash.
	await _physics(80)
	var hitbox := Hitbox.new()
	hitbox.team = CombatLayers.Team.ENEMY
	hitbox.damage = 1
	var hit_shape := CollisionShape2D.new()
	var hit_rect := RectangleShape2D.new()
	hit_rect.size = Vector2(200.0, 200.0)
	hit_shape.shape = hit_rect
	hitbox.add_child(hit_shape)
	player.add_child(hitbox)
	var hp: int = player.health.current_health
	Input.action_press(&"dash")
	await _physics(2)
	Input.action_release(&"dash")
	var blocked: bool = true
	for i in 6:
		await get_tree().physics_frame
		if player.state == Player.State.DASH:
			hitbox._hit_times.clear()
			hitbox.is_active = true
			hitbox._try_hit(player.hurtbox)
			hitbox.is_active = false
			blocked = blocked and player.health.current_health == hp
	_check("dash: a real enemy hitbox and contact damage do nothing during the dash", blocked and player.health.current_health == hp)
	hitbox.queue_free()
	await _physics(60)
	world.free()
	await _frames(2)
	# A KillZone still kills in the dash (it never reads the invulnerability).
	var kill_world: Node2D = _arena()
	var kill_player: Player = await _grounded_player(kill_world)
	var kill_zone := KILL_ZONE_SCENE.instantiate() as KillZone
	kill_zone.size = Vector2(60.0, 400.0)
	kill_zone.position = Vector2(kill_player.global_position.x + 90.0, FLOOR_Y - 100.0)
	kill_world.add_child(kill_zone)
	await _physics(3)
	var died: Array[bool] = [false]
	kill_player.died.connect(func() -> void: died[0] = true)
	Input.action_press(&"dash")
	await _physics(2)
	Input.action_release(&"dash")
	var was_invulnerable: bool = kill_player.is_dash_invulnerable
	await _physics(25)
	_check("dash: a KillZone still kills during the dash (falling out of the world is never prevented)", was_invulnerable and died[0] and kill_player.is_dead)
	kill_world.free()
	# The grace is optional: with a grace the window outlasts the dash, with 0 it ends with it.
	var grace_world: Node2D = _arena()
	var grace_player: Player = await _grounded_player(grace_world)
	grace_player.stats = grace_player.stats.duplicate() as PlayerStats
	grace_player.stats.dash_invulnerability_grace = 0.1
	Input.action_press(&"dash")
	await _physics(2)
	Input.action_release(&"dash")
	var guard_two: int = 0
	while grace_player.state == Player.State.DASH and guard_two < 60:
		guard_two += 1
		await get_tree().physics_frame
	var protected_after: bool = grace_player.is_dash_invulnerable
	await _physics(10)
	_check("dash: an exported grace extends the window after the dash, then it ends", protected_after and not grace_player.is_dash_invulnerable)
	grace_world.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 2. The presentation queue and the card after the corruption animation
# ---------------------------------------------------------------------------------------------

class Gate:
	extends Node
	signal opened
	var started_at: int = -1
	var open_after: int = 0


func _make_step(log: Array, name_text: String, frames: int) -> Callable:
	return func() -> Variant:
		var gate := Gate.new()
		add_child(gate)
		log.append("start:" + name_text)
		var timer_frames: int = frames
		var finish: Callable = func() -> void:
			for i in timer_frames:
				await get_tree().process_frame
			log.append("end:" + name_text)
			gate.opened.emit()
		finish.call()
		return Signal(gate, &"opened")


func _test_queue() -> void:
	var queue := PresentationQueue.new()
	add_child(queue)
	var log: Array = []
	queue.enqueue("one", _make_step(log, "one", 5))
	queue.enqueue("two", _make_step(log, "two", 3))
	queue.enqueue("instant", func() -> Variant:
		log.append("start:instant")
		return Signal())
	queue.enqueue("three", _make_step(log, "three", 2))
	_check("queue: nothing starts in the same call (listeners of the event run first)", log.is_empty() and queue.is_busy())
	await _frames(40)
	_check("queue: steps run one after another and never overlap",
		log == ["start:one", "end:one", "start:two", "end:two", "start:instant", "start:three", "end:three"], str(log))
	_check("queue: it reports every finished step in order and goes idle", queue.finished_ids == ["one", "two", "instant", "three"] and not queue.is_busy())
	# An empty queue (the headless path) completes at once.
	var drained: Array[bool] = [false]
	queue.drained.connect(func() -> void: drained[0] = true)
	queue.enqueue("only_instant", func() -> Variant: return Signal())
	await _frames(2)
	_check("queue: a step with nothing to show completes immediately", drained[0] and not queue.is_busy())
	# The safety timeout abandons a step that never signals.
	var stuck := Gate.new()
	add_child(stuck)
	var timed: Array = []
	queue.step_finished.connect(func(id: String, timed_out: bool) -> void: timed.append([id, timed_out]))
	queue.enqueue("stuck", func() -> Variant: return Signal(stuck, &"opened"), 0.3)
	queue.enqueue("after_stuck", func() -> Variant: return Signal())
	await get_tree().create_timer(0.6, true, false, true).timeout
	await _frames(3)
	_check("queue: a step that never signals is abandoned after its timeout and the next one runs", timed == [["stuck", true], ["after_stuck", false]], str(timed))
	queue.free()
	stuck.free()
	for node in get_children():
		if node is Gate:
			node.free()
	await _frames(2)


func _level(number: int) -> LevelBase:
	var level := (load("res://frontend/levels/level_%d.tscn" % number) as PackedScene).instantiate() as LevelBase
	return level


func _test_card_after_animation() -> void:
	_clean_state()
	var level: LevelBase = _level(1)
	var intro := level.get_node("AbilityIntro") as AbilityIntro
	intro.play_when_headless = true
	add_child(level)
	await _frames(4)
	var queue: PresentationQueue = intro.get_queue()
	_check("card: the level owns a presentation queue", queue != null and queue == level.get_node("PresentationQueue"))
	# Keeping the fragment: the decision is recorded, the event fires, and (like FragmentFx) the corruption
	# animation is spawned by another listener of the SAME event.
	GameState.record_decision("fragment_level_1", "placeholder_boss", 1, GameState.CHOICE_KEPT)
	level.decision_flow.decision_made.emit("fragment_level_1", GameState.CHOICE_KEPT)
	var cut := EXORCISM_SCENE.instantiate() as ExorcismCutscene
	cut.fragment_id = "fragment_level_1"
	cut.player = level.player
	level.add_child(cut)
	await _frames(6)
	_check("card: while the corruption animation runs the card is NOT open", intro.card == null and is_instance_valid(cut) and get_tree().paused)
	await _frames(30)
	_check("card: it stays closed for as long as the animation plays", intro.card == null and is_instance_valid(cut))
	cut._finish()
	await _frames(4)
	_check("card: it opens right after the animation ends", intro.card != null and intro.card.is_open and not is_instance_valid(cut))
	_check("card: the game stays paused only because the card is open", get_tree().paused and PauseLock.is_locked())
	_check("card: the queue ran the animation step first, then the card",
		queue.finished_ids.size() == 1 and String(queue.finished_ids[0]).begins_with("corruption_") and queue.current_id.begins_with("card_"), str(queue.finished_ids))
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	intro.card._elapsed = 1.0
	intro.card._input(accept)
	await _frames(4)
	_check("card: dismissed, the queue is idle and nothing stays paused", not get_tree().paused and not PauseLock.is_locked() and not queue.is_busy()
		and queue.finished_ids.size() == 2)
	level.free()
	await _frames(2)
	# The timeout path: the animation never signals, so the card waits for the safety timeout and no longer.
	_clean_state()
	var slow: LevelBase = _level(1)
	var slow_intro := slow.get_node("AbilityIntro") as AbilityIntro
	slow_intro.play_when_headless = true
	add_child(slow)
	await _frames(4)
	var slow_queue: PresentationQueue = slow_intro.get_queue()
	slow_queue.step_timeout = 0.8
	GameState.record_decision("fragment_level_1", "placeholder_boss", 1, GameState.CHOICE_KEPT)
	slow.decision_flow.decision_made.emit("fragment_level_1", GameState.CHOICE_KEPT)
	var stuck_cut := EXORCISM_SCENE.instantiate() as ExorcismCutscene
	stuck_cut.fragment_id = "fragment_level_1"
	stuck_cut.player = slow.player
	slow.add_child(stuck_cut)
	await get_tree().create_timer(0.4, true, false, true).timeout
	_check("timeout path: before the timeout the card is closed", slow_intro.card == null)
	await get_tree().create_timer(0.9, true, false, true).timeout
	await _frames(4)
	_check("timeout path: after the safety timeout the queue moves on and the card opens", slow_intro.card != null and slow_intro.card.is_open)
	if slow_intro.card != null:
		slow_intro.card.dismiss()
	stuck_cut.queue_free()
	await _frames(4)
	slow.free()
	await _frames(2)
	# The release path: its own animation, no card, no queue work.
	_clean_state()
	var released: LevelBase = _level(1)
	var released_intro := released.get_node("AbilityIntro") as AbilityIntro
	released_intro.play_when_headless = true
	add_child(released)
	await _frames(4)
	GameState.record_decision("fragment_level_1", "placeholder_boss", 1, GameState.CHOICE_RELEASED)
	released.decision_flow.decision_made.emit("fragment_level_1", GameState.CHOICE_RELEASED)
	await _frames(6)
	_check("release path: no card, nothing paused and the queue never started", released_intro.card == null and not get_tree().paused and not released_intro.get_queue().is_busy()
		and released_intro.get_queue().finished_ids.is_empty())
	released.free()
	await _frames(2)
	# A kept fragment that does not improve the wave (the last level) shows no card either.
	_clean_state()
	var last: LevelBase = _level(3)
	var last_intro := last.get_node("AbilityIntro") as AbilityIntro
	last_intro.play_when_headless = true
	add_child(last)
	await _frames(4)
	GameState.record_decision("fragment_level_3", "boss_three", 3, GameState.CHOICE_KEPT)
	last.decision_flow.decision_made.emit("fragment_level_3", GameState.CHOICE_KEPT)
	await _frames(6)
	_check("card: keeping the last fragment (no wave upgrade) opens no card", last_intro.card == null and not get_tree().paused)
	last.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 3. The monologues
# ---------------------------------------------------------------------------------------------

func _test_monologues() -> void:
	var texts := StoryTexts.get_default()
	var accent_re := RegEx.new()
	accent_re.compile("[áéíóúñ¿¡«]")
	_check("monologue: the speaker is the duck", texts.duck_speaker == "Pato")
	for level in [1, 2, 3]:
		var story: BossStory = texts.get_boss(level)
		var lines: Array[String] = story.duck_lines
		var longest: int = 0
		var seconds: float = 0.0
		var accents: int = 0
		for line in lines:
			longest = maxi(longest, line.length())
			seconds += BossDialogue.intro_line_seconds(line)
			accents += 1 if accent_re.search(line) != null else 0
		_check("monologue %d: 5 to 7 lines (%d)" % [level, lines.size()], lines.size() >= 5 and lines.size() <= 7)
		_check("monologue %d: no line is longer than 110 characters (longest %d)" % [level, longest], longest <= 110)
		_check("monologue %d: it lasts at most about 25 s (%.1f s)" % [level, seconds], seconds <= 25.0)
		_check("monologue %d: Spanish with accents in %d lines" % [level, accents], accents >= 3)
	var one: String = " ".join(texts.get_boss(1).duck_lines).to_lower()
	var two: String = " ".join(texts.get_boss(2).duck_lines).to_lower()
	var three: String = " ".join(texts.get_boss(3).duck_lines).to_lower()
	_check("monologue 1: training with the grandfather and the night the first star fell", one.contains("abuelo") and one.contains("katana") and one.contains("primera estrella"))
	_check("monologue 2: what the blade does and the grandfather's silence (the erased prophecy)", two.contains("alma") and two.contains("silencio") and two.contains("el resto está borrado"))
	_check("monologue 3: Kenzo, the doubt and why he cannot go back", three.contains("kenzo") and three.contains("dud") and three.contains("volver atrás"))
	var everything: String = (one + two + three)
	_check("monologues quote nothing against the story (no ending or soul contradicted: no mention of releasing or keeping a named soul)",
		not everything.contains("daigo") and not everything.contains("hana") and not everything.contains("liberé a"))


# ---------------------------------------------------------------------------------------------
# 3. The boss intro
# ---------------------------------------------------------------------------------------------

func _enter_arena(level: LevelBase) -> void:
	level.player.global_position = level.encounter.global_position
	level.player.velocity = Vector2.ZERO


func _boss_level(play_intro: bool = true) -> LevelBase:
	var level: LevelBase = _level(1)
	(level.get_node("BossIntro") as BossIntro).play_when_headless = play_intro
	add_child(level)
	return level


func _test_boss_intro() -> void:
	_clean_state()
	# Headless default: the intro stays quiet and the boss wakes at once (the old behaviour for automated runs).
	var quiet: LevelBase = _level(1)
	add_child(quiet)
	await _frames(8)
	_enter_arena(quiet)
	await _physics(6)
	_check("intro: in automated (headless) runs it stays quiet and the boss wakes at once", quiet.boss.state != BossBase.State.INACTIVE and not (quiet.get_node("BossIntro") as BossIntro).active)
	quiet.free()
	await _frames(2)
	_clean_state()
	var level: LevelBase = _boss_level()
	await _frames(8)
	var intro := level.get_node("BossIntro") as BossIntro
	var dialogue := level.get_node("BossDialogue") as BossDialogue
	var boss: BossBase = level.boss
	var player: Player = level.player
	var boss_start: Vector2 = boss.global_position
	var hp_start: int = player.health.current_health
	var boss_hp: int = boss.health.current_health
	_check("intro: should_play is true the first time", intro.should_play())
	Engine.time_scale = 8.0
	_enter_arena(level)
	await _physics(10)
	_check("intro: the boss stays inactive, the player is locked and invulnerable", intro.active and boss.state == BossBase.State.INACTIVE and player.is_input_locked() and player.story_invulnerable
		and player.is_invulnerable())
	_check("intro: the guardian speaks first (its greeting)", dialogue.is_speaking() and dialogue.current_text().begins_with(BossNames.info_for(boss, level)["name"]), dialogue.current_text())
	# Nothing can hurt anybody while the lines are on screen.
	var duck_hit: bool = _enemy_hit(player)
	var boss_hit: bool = boss.hurtbox.receive_hit(DamageInfo.create(5, Vector2.ZERO, player, CombatLayers.Team.PLAYER))
	_check("intro: the player cannot be hurt and the boss cannot be hurt", not duck_hit and not boss_hit and player.health.current_health == hp_start and boss.health.current_health == boss_hp)
	var saw_duck: bool = false
	var frames: int = 0
	while intro.active and frames < 3000:
		frames += 1
		if dialogue.is_speaking() and dialogue.current_text().begins_with("Pato:"):
			saw_duck = true
		await get_tree().physics_frame
		if intro.active:
			if boss.state != BossBase.State.INACTIVE or boss.global_position.distance_to(boss_start) > 1.0 or player.health.current_health != hp_start:
				break
	Engine.time_scale = 1.0
	_check("intro: the duck tells his story after the guardian's lines", saw_duck)
	_check("intro: the boss did not move, attack or wake up, and nothing hurt the player, until the last line", not intro.active and player.health.current_health == hp_start)
	_check("intro: the order was VS, guardian, duck, fight", intro.order == ["vs", "guardian", "duck", "fight"], str(intro.order))
	await _physics(4)
	_check("intro: when the last line ends the lock and the invulnerability end and the boss wakes up",
		boss.state != BossBase.State.INACTIVE and not player.is_input_locked() and not player.story_invulnerable and boss.hurtbox.enabled)
	_check("intro: the music duck is released after the lines", not AudioDirector.is_music_ducked() if AudioDirector.has_method(&"is_music_ducked") else true)
	var sequences: int = dialogue.sequence_count
	# Dying and retrying the fight does not repeat it.
	player.health.kill()
	await _physics(4)
	player.respawn()
	await _physics(20)
	_enter_arena(level)
	await _physics(8)
	_check("intro: it does not repeat after the player dies and retries (the boss wakes at once)", not intro.active and boss.state != BossBase.State.INACTIVE
		and dialogue.sequence_count == sequences and not player.is_input_locked(), "sequences %d -> %d" % [sequences, dialogue.sequence_count])
	level.free()
	await _frames(2)
	# Skipping with the confirm action.
	_clean_state()
	var skip_level: LevelBase = _boss_level()
	await _frames(8)
	var skip_intro := skip_level.get_node("BossIntro") as BossIntro
	var skip_dialogue := skip_level.get_node("BossDialogue") as BossDialogue
	_enter_arena(skip_level)
	await _physics(10)
	_check("skip: the intro is running", skip_intro.active and skip_level.boss.state == BossBase.State.INACTIVE)
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	skip_dialogue._input(accept)
	_check("skip: a press right at the start is ignored (leftover presses)", skip_intro.active)
	skip_dialogue._grace_left = 0.0
	skip_dialogue._input(accept)
	await _physics(8)
	_check("skip: confirm skips the whole sequence and the fight begins", not skip_intro.active and skip_intro.skipped and skip_level.boss.state != BossBase.State.INACTIVE
		and not skip_level.player.is_input_locked() and not skip_level.player.story_invulnerable)
	skip_level.free()
	await _frames(2)
	# The VS presentation keeps its place: the lines wait for it.
	_clean_state()
	var vs_level: LevelBase = _boss_level()
	await _frames(8)
	var vs_intro := vs_level.get_node("BossIntro") as BossIntro
	var vs_dialogue := vs_level.get_node("BossDialogue") as BossDialogue
	var fake_fx := FakeFx.new()
	fake_fx.name = "FakeFx"
	vs_level.add_child(fake_fx)
	vs_intro._fx = fake_fx
	fake_fx.presenting = true
	_enter_arena(vs_level)
	await _physics(20)
	_check("vs: while the presentation is on screen no line is said and the boss waits", vs_intro.active and not vs_dialogue.is_speaking() and vs_level.boss.state == BossBase.State.INACTIVE)
	fake_fx.presenting = false
	fake_fx.presentation_finished.emit()
	await _physics(10)
	_check("vs: when the presentation ends the guardian speaks", vs_dialogue.is_speaking())
	vs_dialogue._grace_left = 0.0
	vs_dialogue._input(accept)
	await _physics(8)
	_check("vs: then the fight starts after the lines", not vs_intro.active and vs_level.boss.state != BossBase.State.INACTIVE)
	vs_level.free()
	await _frames(2)
	# Dying during the intro (a kill zone) stops it and the boss never wakes.
	_clean_state()
	var die_level: LevelBase = _boss_level()
	await _frames(8)
	var die_intro := die_level.get_node("BossIntro") as BossIntro
	_enter_arena(die_level)
	await _physics(10)
	die_level.player.health.kill()
	await _physics(10)
	_check("abort: dying during the intro ends it and the boss never wakes up", not die_intro.active and die_level.boss.state == BossBase.State.INACTIVE and not die_level.player.story_invulnerable
		and die_level.boss.hurtbox.enabled)
	die_level.free()
	await _frames(2)
	# Continuing from the arena checkpoint: no intro.
	_clean_state()
	GameState.set_checkpoint("level_1_arena")
	var cont: LevelBase = _boss_level()
	await _frames(8)
	var cont_intro := cont.get_node("BossIntro") as BossIntro
	_check("continue: a level opened from its arena checkpoint does not play the intro", not cont_intro.should_play())
	_enter_arena(cont)
	await _physics(8)
	_check("continue: entering the arena wakes the boss at once", not cont_intro.active and cont.boss.state != BossBase.State.INACTIVE and not cont.player.is_input_locked())
	cont.free()
	await _frames(2)
	_clean_state()


class FakeFx:
	extends Node
	signal presentation_finished
	var presenting: bool = false

	func is_presenting() -> bool:
		return presenting


# ---------------------------------------------------------------------------------------------
# 4. Arena floors
# ---------------------------------------------------------------------------------------------

func _world_rects(level: LevelBase) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in level.find_children("*", "CollisionShape2D", true, false):
		var shape_node := node as CollisionShape2D
		var rect_shape := shape_node.shape as RectangleShape2D
		if rect_shape == null:
			continue
		var body: Node = shape_node.get_parent()
		var kind: String = "other"
		if body is KillZone:
			kind = "kill"
		elif body is StaticBody2D:
			kind = "static"
		var center: Vector2 = shape_node.global_position
		result.append({"rect": Rect2(center - rect_shape.size / 2.0, rect_shape.size), "kind": kind, "name": String(body.name)})
	return result


func _test_arena_floors() -> void:
	var expected_gaps: Dictionary = {1: [285.0], 2: [170.0, 285.0, 285.0], 3: [285.0, 175.0, 285.0]}
	for number in [1, 2, 3]:
		_clean_state()
		var level: LevelBase = _level(number)
		add_child(level)
		await _frames(3)
		var rects: Array[Dictionary] = _world_rects(level)
		var gate_x: float = 0.0
		var wall_inner: float = 0.0
		var ceiling_bottom: float = 0.0
		for node in level.find_children("ArenaGate", "", true, false):
			gate_x = (node as Node2D).global_position.x
		var floor_top: float = 0.0
		var floors: Array[Rect2] = []
		for entry in rects:
			var rect: Rect2 = entry["rect"]
			if String(entry["name"]).begins_with("Floor"):
				floors.append(rect)
				floor_top = rect.position.y
			elif String(entry["name"]) == "WallRight":
				wall_inner = rect.position.x
			elif String(entry["name"]) == "ArenaCeiling":
				ceiling_bottom = rect.end.y
		floors.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
		# Coverage of [gate, right wall] by the floor intervals.
		var covered_to: float = gate_x
		var progress: bool = true
		while progress and covered_to < wall_inner:
			progress = false
			for floor_rect in floors:
				if floor_rect.position.x <= covered_to + 0.01 and floor_rect.end.x > covered_to:
					covered_to = floor_rect.end.x
					progress = true
		_check("level %d: the floor is continuous from the gate (%.0f) to the right wall (%.0f)" % [number, gate_x, wall_inner], covered_to >= wall_inner, "covered to %.1f" % covered_to)
		# No KillZone in the arena volume (gate to wall, ceiling to floor).
		var arena_volume := Rect2(Vector2(gate_x, ceiling_bottom), Vector2(wall_inner - gate_x, floor_top - ceiling_bottom))
		var kill_overlap: bool = false
		for entry in rects:
			if String(entry["kind"]) == "kill" and (entry["rect"] as Rect2).intersects(arena_volume):
				kill_overlap = true
		_check("level %d: no KillZone overlaps the arena" % number, not kill_overlap)
		# The intentional gaps before the arena are still there and crossable.
		var gaps: Array[float] = []
		for i in range(floors.size() - 1):
			var gap: float = floors[i + 1].position.x - floors[i].end.x
			if gap > 1.0 and floors[i + 1].position.x < gate_x:
				gaps.append(snappedf(gap, 0.5))
		_check("level %d: the intentional gaps before the arena are unchanged %s" % [number, str(gaps)], gaps == expected_gaps[number])
		var crossable: bool = true
		for gap in gaps:
			crossable = crossable and gap <= 328.0
			if gap > 220.0:
				crossable = crossable and gap <= 328.0
		_check("level %d: every gap is crossable with the measured reach (jump 220 px, jump + dash 328 px)" % number, crossable)
		var needs_dash: int = 0
		var plain_jump: int = 0
		for gap in gaps:
			if gap > 220.0:
				needs_dash += 1
			else:
				plain_jump += 1
		_check("level %d: the 285 px gaps still need the dash and the 170-175 px gaps only a jump" % number, needs_dash == expected_gaps[number].filter(func(g: float) -> bool: return g > 220.0).size()
			and plain_jump == expected_gaps[number].filter(func(g: float) -> bool: return g <= 220.0).size())
		level.free()
		await _frames(2)
	_clean_state()
