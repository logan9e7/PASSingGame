extends SceneTree
const Rules = preload("res://scripts/core/round_rules.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func fixture() -> RoundRules:
	var r := Rules.new()
	for id in range(1, 7):
		r.add_player(id, String.chr(64 + id), id - 1)
	r.action(1, "start")
	r.action(1, "call", 4)
	return r

func run() -> void:
	var few := Rules.new()
	few.add_player(1, "A")
	expect(not few.action(1, "start").is_empty(), "A room needs four players")
	var r := fixture()
	expect(not r.action(2, "start").is_empty(), "Only host starts")
	expect(not r.action(1, "pass", 3).is_empty(), "Chaser cannot pass")
	expect(not r.action(2, "pass", 3).is_empty(), "Only target passes")
	expect(not r.action(4, "pass", 1).is_empty(), "No pass to chaser")
	expect(not r.action(4, "pass", 4).is_empty(), "No pass to self")
	for pair in [[4, 3], [3, 2], [2, 5]]:
		expect(r.action(pair[0], "pass", pair[1]).is_empty(), "Example pass valid")
		expect(r.target == pair[0], "Pending pass does not change target")
		expect(not r.action(6, "ack").is_empty(), "Only recipient acknowledges")
		expect(r.action(pair[1], "ack").is_empty(), "Recipient acknowledges")
		expect(r.target == pair[1], "Acknowledgement changes target")
	r.players[1].position = r.players[5].position
	r.simulate(0.02)
	expect(r.phase == "ended" and r.winner == 1, "Chaser wins original example")
	expect(r.next_chaser == 5, "Caught E becomes next chaser")
	r.action(1, "start")
	expect(r.chaser == 5 and r.round_number == 2, "Next round rotates correctly")
	r = fixture()
	r.action(4, "pass", 3)
	r.players[1].position = r.players[4].position
	expect(not r.action(3, "ack").is_empty(), "Catch precedes pending acknowledgement")
	expect(r.phase == "ended" and r.next_chaser == 4, "Old target is caught")
	r = fixture()
	r.action(4, "pass", 3)
	r.action(3, "ack")
	expect(not r.action(3, "pass", 4).is_empty(), "Immediate return prohibited")
	r.action(3, "pass", 2)
	r.action(2, "ack")
	expect(r.action(2, "pass", 4).is_empty(), "Later return allowed")
	r.action(4, "ack")
	for i in range(45):
		for candidate in [2, 3, 4]:
			if candidate != r.target and candidate != r.previous_target:
				expect(r.action(r.target, "pass", candidate).is_empty(), "Unlimited pass %d" % i)
				r.action(candidate, "ack")
				break
	r = fixture()
	r.players[4].position = Vector2(17.1, 0)
	r.simulate(0.02)
	expect(r.players[4].eliminated and r.phase == "playing" and r.target == 0, "Target boundary: out, round continues, chaser recalls")
	expect(r.action(1, "call", 3).is_empty(), "Chaser can select replacement target")
	r.players[1].position = Vector2(-17.1, 0)
	r.simulate(0.02)
	expect(r.phase == "ended" and r.winner == 0, "Chaser boundary aborts without winner")
	r = fixture()
	r.remove_player(4)
	expect(r.phase == "playing" and r.target == 0, "Disconnected target does not end round")
	r.remove_player(1)
	expect(r.phase == "ended" and r.winner == 0, "Disconnected chaser stops round")
	r = fixture()
	r.players[1].position = r.players[2].position
	r.simulate(0.02)
	expect(r.phase == "playing", "Contact with non-target is not catch")
	r = fixture()
	r.players[2].position = Vector2(0, 10)
	r.set_input(2, Vector2(50, 50))
	var origin: Vector2 = r.players[2].position
	r.simulate(0.2)
	expect(r.players[2].position.distance_to(origin) <= Rules.SPEED * 0.2 + 0.001, "Speed clamp includes diagonal input")
	r.set_input(2, Vector2(INF, NAN))
	expect(r.players[2].direction.is_finite(), "Invalid input never enters simulation")
	r.players[2].position = Vector2(-9, -3)
	r.set_input(2, Vector2.RIGHT)
	r.simulate(0.25)
	expect(r.players[2].position.x < -8.7, "Server resolves bench collisions")
	r = fixture()
	for i in range(300):
		if r.phase != "playing":
			break
		var direction: Vector2 = (r.players[4].position - r.players[1].position).normalized()
		r.set_input(1, direction)
		r.simulate(1.0 / 60.0)
	expect(r.phase == "ended", "Sustained movement catches target")
	expect(r.players[4].best > 0 and r.players[4].streak == 0, "Catch retains best and resets streak")
	var survivor_total: float = r.players[2].total
	r.action(1, "start")
	r.simulate(0.1)
	expect(r.players[2].total > survivor_total, "Records accumulate across rounds")
	print("RULES_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
