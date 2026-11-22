extends Node

signal updated(state: Dictionary)
signal notice(message: String)
signal session_closed

const Rules = preload("res://scripts/core/round_rules.gd")
const PROTOCOL := 1
const DEFAULT_PORT := 24567
var rules: RoundRules
var state: Dictionary = {}
var active := false
var practice := false
var my_id := 1
var room_code := ""
var desired_name := "Player"
var desired_color := 0
var authority := false
var input_direction := Vector2.ZERO
var sequence := 0
var _last_input: Dictionary = {}
var _last_sequence: Dictionary = {}
var _action_times: Dictionary = {}
var _send_clock := 0.0
var _bot_ack_clock := 0.0
var _pending_bot := 0
var _snapshot_sequence := 0
var _received_sequence := -1
var _critical_signature := ""

func _ready() -> void:
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_failed)
	multiplayer.server_disconnected.connect(_server_lost)

func start_practice(display_name: String, color: int) -> void:
	leave(false)
	practice = true
	authority = true
	active = true
	my_id = 1
	room_code = "PRACTICE"
	rules = Rules.new()
	rules.add_player(1, display_name, color)
	for i in range(3):
		var bot_name: String = ["Milo", "Nia", "Arlo"][i]
		if bot_name.to_lower() == display_name.strip_edges().to_lower():
			bot_name += " Bot"
		rules.add_player(i + 2, bot_name, i + 1)
	rules.action(1, "start")
	_publish()
	notice.emit("Practice · keyboard or joystick to move. Call a runner to begin.")

func host_room(display_name: String, color: int, port: int = DEFAULT_PORT) -> Error:
	leave(false)
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, 7)
	if error != OK:
		notice.emit("Cannot host on UDP port %d (%s)." % [port, error_string(error)])
		return error
	multiplayer.multiplayer_peer = peer
	rules = Rules.new()
	rules.add_player(1, display_name, color)
	room_code = _new_code()
	my_id = 1
	authority = true
	active = true
	_publish()
	notice.emit("Room ready. Share your host IP, port %d and code %s." % [port, room_code])
	return OK

func join_room(display_name: String, color: int, address: String, code: String, port: int = DEFAULT_PORT) -> Error:
	leave(false)
	desired_name = display_name
	desired_color = color
	room_code = code.strip_edges().to_upper()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), port)
	if error != OK:
		notice.emit("Could not connect: " + error_string(error))
		return error
	multiplayer.multiplayer_peer = peer
	notice.emit("Connecting to %s:%d…" % [address, port])
	return OK

func leave(announce: bool = true) -> void:
	active = false
	practice = false
	authority = false
	state = {}
	input_direction = Vector2.ZERO
	_last_input.clear()
	_last_sequence.clear()
	_action_times.clear()
	_pending_bot = 0
	_bot_ack_clock = 0.0
	_send_clock = 0.0
	sequence = 0
	_snapshot_sequence = 0
	_received_sequence = -1
	_critical_signature = ""
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if announce:
		session_closed.emit()

func act(kind: String, recipient: int = 0) -> void:
	if not active:
		return
	if authority:
		_apply_action(my_id, kind, recipient)
	else:
		_receive_action.rpc_id(1, kind, recipient)

func _physics_process(delta: float) -> void:
	if not active:
		return
	_send_clock += delta
	if authority:
		rules.set_input(my_id, input_direction)
		if practice:
			_update_bots(delta)
		else:
			var now := Time.get_ticks_msec()
			for id in rules.players:
				if id != my_id and now - int(_last_input.get(id, 0)) > 350:
					rules.set_input(id, Vector2.ZERO)
		rules.simulate(delta)
	if _send_clock >= 0.05:
		_send_clock = 0.0
		if authority:
			_publish()
		else:
			sequence += 1
			_receive_input.rpc_id(1, input_direction, sequence)

func _update_bots(delta: float) -> void:
	if rules.phase != "playing":
		return
	var chase_pos: Vector2 = rules.players[rules.chaser].position
	for id in rules.players:
		if id == my_id:
			continue
		var p: Dictionary = rules.players[id]
		if p.eliminated:
			continue
		var direction: Vector2
		if id == rules.chaser and rules.players.has(rules.target):
			direction = (rules.players[rules.target].position - p.position).normalized()
		elif id == rules.target:
			direction = (p.position - chase_pos).normalized()
		else:
			var angle := rules.round_time * 0.5 + float(id) * 2.0
			direction = Vector2(cos(angle), sin(angle)) * 0.55
		# Bots steer away from the edge, but follow the same obstacle/catch rules.
		if absf(p.position.x) > 14.0:
			direction.x = -signf(p.position.x)
		if absf(p.position.y) > 14.0:
			direction.y = -signf(p.position.y)
		rules.set_input(id, direction * 0.82)
	if rules.chaser != my_id and rules.target == 0:
		var eligible := rules.runners()
		if not eligible.is_empty():
			rules.action(rules.chaser, "call", int(eligible[0]))
	if rules.pending_to != 0 and rules.pending_to != my_id:
		if _pending_bot != rules.pending_to:
			_pending_bot = rules.pending_to
			_bot_ack_clock = 0.0
		_bot_ack_clock += delta
		if _bot_ack_clock > 1.0:
			rules.action(_pending_bot, "ack")
			_pending_bot = 0
	else:
		_pending_bot = 0
	if rules.players.has(rules.target) and rules.target != my_id and rules.pending_to == 0:
		var target_pos: Vector2 = rules.players[rules.target].position
		if target_pos.distance_to(chase_pos) < 2.5 and randf() < delta * 0.9:
			for candidate in rules.runners():
				if candidate != rules.target and candidate != rules.previous_target:
					rules.action(rules.target, "pass", candidate)
					break

func _publish() -> void:
	state = rules.snapshot()
	state["code"] = room_code
	state["practice"] = practice
	_snapshot_sequence += 1
	state["sequence"] = _snapshot_sequence
	updated.emit(state)
	if not practice:
		var encoded := var_to_bytes(state).compress(FileAccess.COMPRESSION_DEFLATE)
		var signature := str([state.phase, state.round, state.chaser, state.target, state.pending, state.winner, state.players.keys()])
		if signature != _critical_signature:
			_critical_signature = signature
			_receive_critical_snapshot.rpc(encoded)
		else:
			_receive_snapshot.rpc(encoded)

func _apply_action(id: int, kind: String, recipient: int) -> void:
	var error := rules.action(id, kind, recipient)
	if not error.is_empty():
		if id == my_id:
			notice.emit(error)
		else:
			_show_notice.rpc_id(id, error)
	_publish()

func _connected() -> void:
	my_id = multiplayer.get_unique_id()
	_register.rpc_id(1, desired_name, desired_color, room_code, PROTOCOL)

func _failed() -> void:
	leave()
	notice.emit("Connection failed. Check the host IP, UDP port and firewall.")

func _server_lost() -> void:
	leave()
	notice.emit("Host disconnected. Rejoin a new private room.")

func _peer_connected(_id: int) -> void:
	pass # Handshake must finish before this connection becomes a player.

func _peer_disconnected(id: int) -> void:
	if authority and active:
		rules.remove_player(id)
		_last_input.erase(id)
		_last_sequence.erase(id)
		_action_times.erase(id)
		_publish()

@rpc("any_peer", "call_remote", "reliable", 0)
func _register(display_name: String, color: int, code: String, protocol: int) -> void:
	if not authority or practice:
		return
	var id := multiplayer.get_remote_sender_id()
	if rules.players.has(id):
		return
	if protocol != PROTOCOL or code != room_code:
		_rejected.rpc_id(id, "Room code or game version does not match.")
		return
	var error := rules.add_player(id, display_name, color)
	if not error.is_empty():
		_rejected.rpc_id(id, error)
		return
	_last_input[id] = Time.get_ticks_msec()
	_welcome.rpc_id(id)
	_publish()

@rpc("authority", "call_remote", "reliable", 0)
func _welcome() -> void:
	active = true
	authority = false
	notice.emit("Joined the playground. The host starts with 4 players.")

@rpc("authority", "call_remote", "reliable", 0)
func _rejected(message: String) -> void:
	leave()
	notice.emit(message)

@rpc("authority", "call_remote", "reliable", 0)
func _show_notice(message: String) -> void:
	notice.emit(message)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _receive_input(direction: Vector2, input_sequence: int) -> void:
	if not authority or practice or not direction.is_finite():
		return
	var id := multiplayer.get_remote_sender_id()
	if not rules.players.has(id) or input_sequence <= int(_last_sequence.get(id, -1)):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_input.get(id, 0)) < 10:
		return
	_last_sequence[id] = input_sequence
	_last_input[id] = now
	rules.set_input(id, direction)

@rpc("any_peer", "call_remote", "reliable", 0)
func _receive_action(kind: String, recipient: int) -> void:
	if not authority or practice:
		return
	var id := multiplayer.get_remote_sender_id()
	if not rules.players.has(id):
		return
	var now := Time.get_ticks_msec()
	if now - int(_action_times.get(id, -1000)) < 100:
		return
	_action_times[id] = now
	_apply_action(id, kind, recipient)

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _receive_snapshot(encoded: PackedByteArray) -> void:
	_accept_snapshot(encoded)

@rpc("authority", "call_remote", "reliable", 0)
func _receive_critical_snapshot(encoded: PackedByteArray) -> void:
	_accept_snapshot(encoded)

func _accept_snapshot(encoded: PackedByteArray) -> void:
	if authority or encoded.size() > 32768:
		return
	var decoded := encoded.decompress_dynamic(65536, FileAccess.COMPRESSION_DEFLATE)
	var snapshot: Variant = bytes_to_var(decoded)
	if not snapshot is Dictionary or int(snapshot.get("sequence", -1)) <= _received_sequence:
		return
	_received_sequence = int(snapshot.sequence)
	state = snapshot
	updated.emit(state)

func _new_code() -> String:
	var alphabet := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	for i in range(6):
		code += alphabet[randi() % alphabet.length()]
	return code
