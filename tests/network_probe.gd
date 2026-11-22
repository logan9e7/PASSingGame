extends SceneTree
var session: Node
var role := "host"
var player_name := "Host"
var report_path := "/tmp/passing-net.json"
var port := 24681
var elapsed := 0.0
var passed := false
var acted := false
var acknowledged := false
var phase_stage := 0
var wait_after_success := 0.0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.get_slice("=", 1)
		if arg.begins_with("--name="): player_name = arg.get_slice("=", 1)
		if arg.begins_with("--report="): report_path = arg.get_slice("=", 1)
		if arg.begins_with("--port="): port = int(arg.get_slice("=", 1))
	call_deferred("begin")

func begin() -> void:
	session = root.get_node("Session")
	if role == "host":
		if session.host_room("Host", 0, port) != OK:
			finish(false, "Host could not bind UDP")
			return
		# Fixed code is a test fixture, not a production bypass.
		session.room_code = "TEST42"
	else:
		session.join_room(player_name, 1, "127.0.0.1", "TEST42", port)

func _process(delta: float) -> bool:
	elapsed += delta
	if passed and role != "host":
		if not session.active:
			quit(0)
		return false
	if elapsed > 22:
		finish(false, "Timed out before complete four-peer round")
		return false
	if session == null or not session.active or session.state.is_empty():
		return false
	var state: Dictionary = session.state
	var ids: Dictionary = {}
	for id in state.players:
		ids[String(state.players[id].name)] = id
	if role == "host":
		if state.players.size() == 4 and phase_stage == 0:
			session.act("start")
			phase_stage = 1
		elif phase_stage == 1 and state.phase == "playing" and ids.has("Bee"):
			session.act("call", ids.Bee)
			phase_stage = 2
		elif phase_stage == 2 and ids.has("Cee") and state.target == ids.Cee:
			var chaser_pos: Vector2 = state.players[1].position
			var target_pos: Vector2 = state.players[ids.Cee].position
			session.input_direction = (target_pos - chaser_pos).normalized()
			phase_stage = 3
		elif phase_stage == 3:
			if state.phase == "playing":
				session.input_direction = (state.players[ids.Cee].position - state.players[1].position).normalized()
			elif state.phase == "ended":
				if state.winner != 1 or state.next_chaser != ids.Cee or state.players[ids.Cee].best <= 0:
					finish(false, "Bad catch or survival result")
					return false
				session.input_direction = Vector2.ZERO
				session.act("start")
				phase_stage = 4
		elif phase_stage == 4:
			if state.round == 2 and state.chaser == ids.get("Cee", 0):
				passed = true
			wait_after_success += delta
			if wait_after_success > 1.5:
				finish(passed, "Host validated handshake, PASS, ACK, movement catch, scoring and round 2")
	else:
		if player_name == "Bee" and state.phase == "playing" and state.target == session.my_id and not acted:
			if ids.has("Cee"):
				session.act("pass", ids.Cee)
				acted = true
		if player_name == "Cee" and state.pending == session.my_id and not acknowledged:
			session.act("ack")
			acknowledged = true
		if state.round == 2 and state.chaser == ids.get("Cee", 0):
			passed = true
			write_result(true, "Client observed authoritative next-chaser state; identity " + player_name)
	return false

func write_result(success: bool, message: String) -> void:
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"passed": success, "role": role, "name": player_name, "message": message}))
	print("NETWORK_RESULT " + message + " · " + str(success))

func finish(success: bool, message: String) -> void:
	write_result(success, message)
	quit(0 if success else 1)
