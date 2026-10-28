extends Node
## Integration test against a REAL AI service (mock mode) over localhost. Development only.
## Run by ai-service/scripts/integration_mock.py. Env vars:
##   QUACKTACLYSM_AI_URL       base URL of the service (read by AiServiceConfig)
##   QUACKTACLYSM_IT_EXPECT    "ok" (round trip accepted) or "down" (graceful fallback)
## Uses a redirected test save path; never touches the real save.

const TEST_PATH: String = "user://test_save_phase10_it.json"
const EXPECT_ENV_NAME: String = "QUACKTACLYSM_IT_EXPECT"
const MAX_WAIT_MSEC: int = 20000

var failures: int = 0
var applied: Array[AdaptiveResult] = []
var skipped: Array[String] = []


func _ready() -> void:
	SaveSystem.set_save_path(TEST_PATH)
	_run.call_deferred()


func _check(check_name: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("PASS: %s %s" % [check_name, detail])
	else:
		failures += 1
		print("FAIL: %s %s" % [check_name, detail])


func _run() -> void:
	var expect: String = OS.get_environment(EXPECT_ENV_NAME)
	SaveSystem.purge()
	GameState.autosave_enabled = true
	GameState.start_new_game()
	GameState.record_decision("it_fragment_1", "boss_a", 1, AdaptiveIds.CHOICE_RELEASED)
	GameState.record_decision("it_fragment_2", "boss_a", 2, AdaptiveIds.CHOICE_RELEASED)
	GameState.refresh_adaptive_profile()
	var local_profile: String = GameState.adaptive_profile
	var refiner := AdaptiveRefiner.new()
	add_child(refiner)
	refiner.refinement_applied.connect(func(result: AdaptiveResult) -> void: applied.append(result))
	refiner.refinement_skipped.connect(func(reason: String) -> void: skipped.append(reason))
	print("base url: %s  expect: %s" % [refiner.config.resolve_base_url(), expect])
	_check("local profile is compassionate before the request", local_profile == AdaptiveIds.PROFILE_COMPASSIONATE)
	_check("request starts and returns at once", refiner.request_refinement() and refiner.in_flight)
	var started_at: int = Time.get_ticks_msec()
	while refiner.in_flight and Time.get_ticks_msec() - started_at < MAX_WAIT_MSEC:
		await get_tree().process_frame
	_check("request finished", not refiner.in_flight, refiner.last_status)
	if expect == "ok":
		_check("round trip accepted", applied.size() == 1 and skipped.is_empty() and refiner.last_status == "applied",
			"%s %s" % [refiner.last_status, refiner.last_message])
		var result: AdaptiveResult = GameState.get_adaptive_result()
		_check("profile and variant from the service table", GameState.adaptive_profile == AdaptiveIds.PROFILE_COMPASSIONATE
			and result.source == AdaptiveIds.SOURCE_REMOTE and result.narrative_variant == "mercy")
	elif expect == "down":
		_check("graceful fallback (service down)", applied.is_empty() and skipped.size() == 1
			and refiner.last_status in ["connection_failed", "timeout"], "%s %s" % [refiner.last_status, refiner.last_message])
		_check("local state untouched", GameState.adaptive_profile == local_profile and GameState.adaptive_narrative_variant.is_empty())
	else:
		_check("QUACKTACLYSM_IT_EXPECT must be 'ok' or 'down'", false, expect)
	refiner.free()
	SaveSystem.purge()
	GameState.start_new_game()
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)
