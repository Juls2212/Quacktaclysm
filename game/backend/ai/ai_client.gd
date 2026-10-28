class_name AiClient
extends Node
## Non-blocking JSON client for the AI service. One request in flight at a time.
##
## A new request cancels the previous one: the old id is reported ONCE through `completed`
## with status "cancelled" (synchronously, inside request_profile). Freeing the node cancels
## silently (no signals). Failures that are known up front (disabled, invalid URL, connection
## refused at start) are reported on the next idle frame, never before the id is returned.
##
## Test transport: assign `transport` a Callable(request_id: int, url: String,
## headers: PackedStringArray, body: String, on_done: Callable). It must eventually call
## on_done.call({"result": HTTPRequest.RESULT_*, "code": int, "body": PackedByteArray}).

signal completed(request_id: int, outcome: Dictionary)

const STATUS_OK: String = "ok"
const STATUS_DISABLED: String = "disabled"
const STATUS_INVALID_URL: String = "invalid_url"
const STATUS_CONNECTION_FAILED: String = "connection_failed"
const STATUS_TIMEOUT: String = "timeout"
const STATUS_HTTP_ERROR: String = "http_error"
const STATUS_INVALID_JSON: String = "invalid_json"
const STATUS_CANCELLED: String = "cancelled"

const DEFAULT_CONFIG_PATH: String = "res://backend/ai/default_ai_service_config.tres"
const _HEADERS: PackedStringArray = ["Content-Type: application/json", "Accept: application/json"]

@export var config: AiServiceConfig
## Optional fake network (see the class comment). Empty = real HTTPRequest.
var transport: Callable = Callable()
var in_flight: bool = false

var _http: HTTPRequest = null
var _next_id: int = 0
var _active_id: int = 0


func _exit_tree() -> void:
	_active_id = 0
	in_flight = false
	if _http != null and is_instance_valid(_http):
		_http.cancel_request()


## Starts a request and returns its id (> 0). Never blocks.
func request_profile(payload: Dictionary) -> int:
	if in_flight:
		cancel()
	if config == null:
		config = load(DEFAULT_CONFIG_PATH) as AiServiceConfig
		if config == null:
			config = AiServiceConfig.new()
	_next_id += 1
	var request_id: int = _next_id
	_active_id = request_id
	in_flight = true
	if not config.enabled:
		_fail_later(request_id, STATUS_DISABLED, "AI service disabled in config")
		return request_id
	var url: String = config.resolve_profile_url()
	if url.is_empty():
		_fail_later(request_id, STATUS_INVALID_URL, "base URL must start with http:// or https://")
		return request_id
	var body: String = JSON.stringify(payload)
	if transport.is_valid():
		transport.call(request_id, url, _HEADERS, body, _on_transport_done.bind(request_id))
		return request_id
	if not is_inside_tree():
		_fail_later(request_id, STATUS_CONNECTION_FAILED, "client is not in the scene tree")
		return request_id
	_ensure_http()
	_http.timeout = config.request_timeout_seconds
	_http.body_size_limit = config.max_response_bytes
	_http.cancel_request()
	var error: Error = _http.request(url, _HEADERS, HTTPClient.METHOD_POST, body)
	if error != OK:
		_fail_later(request_id, STATUS_CONNECTION_FAILED, "request could not start (%s)" % error_string(error))
	return request_id


## Cancels the request in flight (reported once as "cancelled"). No-op if idle.
func cancel() -> void:
	if not in_flight:
		return
	var request_id: int = _active_id
	_active_id = 0
	in_flight = false
	if _http != null and is_instance_valid(_http):
		_http.cancel_request()
	completed.emit(request_id, _outcome(STATUS_CANCELLED, "request cancelled"))


func _ensure_http() -> void:
	if _http != null and is_instance_valid(_http):
		return
	_http = HTTPRequest.new()
	_http.request_completed.connect(_on_http_completed)
	add_child(_http)


func _on_http_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_on_transport_done({"result": result, "code": response_code, "body": body}, _active_id)


func _on_transport_done(raw: Dictionary, request_id: int) -> void:
	# Real transports answer from the network, fakes may answer immediately: always defer.
	_finish.call_deferred(request_id, _parse(raw))


func _fail_later(request_id: int, status: String, message: String) -> void:
	_finish.call_deferred(request_id, _outcome(status, message))


func _finish(request_id: int, outcome: Dictionary) -> void:
	if request_id == 0 or request_id != _active_id:
		return
	_active_id = 0
	in_flight = false
	completed.emit(request_id, outcome)


func _outcome(status: String, message: String, data: Variant = null) -> Dictionary:
	return {"ok": status == STATUS_OK, "status": status, "data": data, "message": message}


## Defensive: any failure becomes a status, never an error.
func _parse(raw: Dictionary) -> Dictionary:
	var result: int = raw.get("result", HTTPRequest.RESULT_CANT_CONNECT)
	if result == HTTPRequest.RESULT_TIMEOUT:
		return _outcome(STATUS_TIMEOUT, "request timed out")
	if result == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
		return _outcome(STATUS_HTTP_ERROR, "response too large")
	if result != HTTPRequest.RESULT_SUCCESS:
		return _outcome(STATUS_CONNECTION_FAILED, "network error (result %d)" % result)
	var code: int = raw.get("code", 0)
	if code < 200 or code >= 300:
		return _outcome(STATUS_HTTP_ERROR, "HTTP status %d" % code)
	var body: PackedByteArray = raw.get("body", PackedByteArray())
	if body.size() > config.max_response_bytes:
		return _outcome(STATUS_HTTP_ERROR, "response too large")
	if body.is_empty():
		return _outcome(STATUS_INVALID_JSON, "empty body")
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return _outcome(STATUS_INVALID_JSON, "body is not valid JSON")
	return _outcome(STATUS_OK, "ok", json.data)
