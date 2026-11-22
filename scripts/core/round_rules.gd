class_name RoundRules
extends RefCounted

# Pure server simulation. No scene tree, network, wall clock or client scores.
const LIMIT := 17.0
const SPEED := 5.2
const RADIUS := 0.36
const CATCH_DISTANCE := 0.85
const MAX_PLAYERS := 8
# These footprints are also used by Arena to construct the matching 3D props.
const BENCHES := [Vector2(-7, -3), Vector2(7, 3)]
const TREES := [Vector2(-12, -11), Vector2(12, -11), Vector2(-12, 11), Vector2(12, 11)]

var players: Dictionary = {}
var phase := "lobby"
var round_number := 0
var host_id := 1
var chaser := 0
var target := 0
var previous_target := 0
var pending_to := 0
var next_chaser := 0
var winner := 0
var round_time := 0.0
var events: Array[String] = []

func add_player(id: int, display_name: String, color_index: int = 0) -> String:
	if phase == "playing":
		return "A chase is running. Join when this round ends."
	if players.size() >= MAX_PLAYERS:
		return "This playground is full (8 players)."
	var clean := display_name.strip_edges().replace("\n", " ").replace("\r", " ").left(16)
	if clean.is_empty():
		return "Enter a name."
	for p in players.values():
		if String(p.name).nocasecmp_to(clean) == 0:
			return "That name is already in the room."
	players[id] = {"id": id, "name": clean, "color": posmod(color_index, 8), "position": Vector2(cos(players.size() * 1.3), sin(players.size() * 1.3)) * 7.0,
		"direction": Vector2.ZERO, "eliminated": false, "total": 0.0, "streak": 0.0, "best": 0.0}
	_log(clean + " joined the playground")
	return ""

func remove_player(id: int) -> void:
	if not players.has(id):
		return
	var departing: String = players[id].name
	players.erase(id)
	if phase == "playing":
		if id == chaser:
			_abort("Chaser disconnected. Round stopped.")
		elif id == target:
			target = 0
			pending_to = 0
			_log("Target disconnected. Chaser: call another runner.")
		elif id == pending_to:
			pending_to = 0
		if phase == "playing" and runners().is_empty():
			_abort("No runners remain. Round stopped.")
	_log(departing + " left")

func set_input(id: int, direction: Vector2) -> void:
	if not players.has(id) or not direction.is_finite():
		return
	players[id].direction = direction.limit_length(1.0)

func action(id: int, kind: String, recipient: int = 0) -> String:
	if not players.has(id):
		return "Join the room first."
	# Resolve touching before applying any handover, including a pending ACK.
	_check_catch()
	if kind == "start":
		if id != host_id:
			return "Only the host can start a round."
		if phase == "playing":
			return "A chase is already running."
		if players.size() < 4:
			return "At least 4 players are needed."
		_start_round()
		return ""
	if phase != "playing" or players[id].eliminated:
		return "You cannot do that right now."
	if kind == "call":
		if id != chaser or target != 0:
			return "Only the chaser can call an initial target."
		if not runners().has(recipient):
			return "Choose a runner."
		target = recipient
		_log(_name(id) + " called " + _name(recipient))
	elif kind == "pass":
		if id != target:
			return "Only the active target can PASS."
		if not runners().has(recipient) or recipient == id or recipient == previous_target:
			return "Choose a runner other than yourself or the previous target."
		pending_to = recipient
		_log(_name(id) + ": PASS " + _name(recipient) + "?")
	elif kind == "ack":
		if pending_to != id:
			return "No PASS is waiting for you."
		previous_target = target
		target = id
		pending_to = 0
		_log(_name(id) + " acknowledged. Target changed.")
	else:
		return "Unknown action."
	return ""

func simulate(delta: float) -> void:
	# Bounded substeps prevent fast crossings from skipping a catch or a prop.
	var remaining := clampf(delta, 0.0, 0.25)
	while remaining > 0.00001 and phase == "playing":
		var dt := minf(remaining, 0.02)
		_tick(dt)
		remaining -= dt

func _tick(dt: float) -> void:
	round_time += dt
	for id in players:
		var p: Dictionary = players[id]
		if p.eliminated:
			continue
		if id != chaser:
			p.total += dt
			p.streak += dt
			p.best = maxf(p.best, p.streak)
		var pos: Vector2 = p.position
		var movement: Vector2 = p.direction * SPEED * dt
		var proposed := Vector2(pos.x + movement.x, pos.y)
		if not _blocked(proposed):
			pos.x = proposed.x
		proposed = Vector2(pos.x, pos.y + movement.y)
		if not _blocked(proposed):
			pos.y = proposed.y
		p.position = pos
		if absf(pos.x) > LIMIT or absf(pos.y) > LIMIT:
			p.eliminated = true
			p.direction = Vector2.ZERO
			_log(_name(id) + " crossed the boundary")
			if id == chaser:
				_abort("Chaser out. Round stopped without a winner.")
				return
			if id == target:
				target = 0
				pending_to = 0
				_log("Chaser: call another runner")
			if id == pending_to:
				pending_to = 0
	_check_catch()
	if phase == "playing" and runners().is_empty():
		_abort("No runners remain. Round stopped without a winner.")

func _blocked(pos: Vector2) -> bool:
	for center in BENCHES:
		var local: Vector2 = pos - center
		if absf(local.x) < 1.35 + RADIUS and absf(local.y) < 0.43 + RADIUS:
			return true
	for center in TREES:
		if pos.distance_to(center) < 0.45 + RADIUS:
			return true
	return false

func _check_catch() -> void:
	if phase != "playing" or not players.has(target) or not players.has(chaser):
		return
	if players[target].eliminated or players[chaser].eliminated:
		return
	if players[chaser].position.distance_to(players[target].position) <= CATCH_DISTANCE:
		phase = "ended"
		winner = chaser
		next_chaser = target
		pending_to = 0
		_log(_name(chaser) + " caught " + _name(target))
		players[target].best = maxf(players[target].best, players[target].streak)
		players[target].streak = 0.0
		for p in players.values():
			p.direction = Vector2.ZERO

func _start_round() -> void:
	var ids := players.keys()
	ids.sort()
	round_number += 1
	round_time = 0.0
	phase = "playing"
	chaser = next_chaser if players.has(next_chaser) else int(ids[0])
	target = 0
	previous_target = 0
	pending_to = 0
	winner = 0
	for i in range(ids.size()):
		var p: Dictionary = players[ids[i]]
		var angle := TAU * float(i) / float(ids.size())
		p.position = Vector2(cos(angle), sin(angle)) * 7.0
		p.direction = Vector2.ZERO
		p.eliminated = false
	players[chaser].streak = 0.0
	_log("Round %d · %s is the chaser" % [round_number, _name(chaser)])

func runners() -> Array:
	var result: Array = []
	for id in players:
		if id != chaser and not players[id].eliminated:
			result.append(id)
	return result

func snapshot() -> Dictionary:
	return {"players": players.duplicate(true), "phase": phase, "round": round_number, "host": host_id,
		"chaser": chaser, "target": target, "previous": previous_target, "pending": pending_to,
		"next_chaser": next_chaser, "winner": winner, "time": round_time, "events": events.duplicate()}

func _abort(reason: String) -> void:
	phase = "ended"
	winner = 0
	next_chaser = 0
	pending_to = 0
	for p in players.values():
		p.direction = Vector2.ZERO
	_log(reason)

func _name(id: int) -> String:
	return String(players[id].name) if players.has(id) else "Player"

func _log(text: String) -> void:
	events.push_front(text)
	if events.size() > 12:
		events.resize(12)
