extends Node3D

const Arena = preload("res://scripts/world/arena.gd")
const Avatar = preload("res://scripts/world/avatar.gd")
const HUD = preload("res://scripts/ui/game_hud.gd")
var avatars: Dictionary = {}
var hud: GameHUD
var rig: Node3D
var pitch_pivot: Node3D
var spring: SpringArm3D
var camera: Camera3D
var yaw := 0.0
var pitch := -0.37
var menu_open := true
var orbit_time := 0.0
var _awaiting_join := false
var _last_target := 0
var _last_phase := "lobby"
var sound: AudioStreamPlayer

func _ready() -> void:
	_install_inputs()
	add_child(Arena.new())
	rig = Node3D.new()
	add_child(rig)
	pitch_pivot = Node3D.new()
	rig.add_child(pitch_pivot)
	spring = SpringArm3D.new()
	spring.spring_length = 6.8
	spring.margin = 0.3
	spring.collision_mask = 1
	pitch_pivot.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 72
	camera.far = 120
	spring.add_child(camera)
	camera.current = true
	hud = HUD.new()
	add_child(hud)
	hud.practice_requested.connect(_practice)
	hud.host_requested.connect(_host)
	hud.join_requested.connect(_join)
	hud.action_requested.connect(Session.act)
	hud.leave_requested.connect(Session.leave)
	hud.menu_changed.connect(_menu_changed)
	hud.touch.look_drag.connect(_look)
	Session.updated.connect(_sync)
	Session.notice.connect(hud.show_notice)
	Session.session_closed.connect(_closed)
	sound = AudioStreamPlayer.new()
	sound.volume_db = -20
	add_child(sound)
	var args := OS.get_cmdline_user_args()
	if args.has("--practice"):
		_practice("Player", 0)

func _process(delta: float) -> void:
	if Session.active and avatars.has(Session.my_id):
		var actor: PlaygroundAvatar = avatars[Session.my_id]
		var focus := actor.global_position + Vector3(0, 1.25, 0)
		if rig.global_position.distance_to(focus) > 8:
			rig.global_position = focus
		else:
			rig.global_position = rig.global_position.lerp(focus, 1.0 - exp(-delta * 10))
		rig.rotation.y = yaw
		pitch_pivot.rotation.x = pitch
		spring.spring_length = 6.8
	else:
		orbit_time += delta * 0.025
		rig.position = Vector3(sin(orbit_time) * 4, 1.2, cos(orbit_time) * 2)
		rig.rotation.y = orbit_time
		pitch_pivot.rotation.x = -0.48
		spring.spring_length = 28
	var direction := Vector2.ZERO
	if Session.active and not menu_open:
		direction = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if hud.touch.direction.length_squared() > 0.01:
			direction = hud.touch.direction
	Session.input_direction = direction.rotated(-yaw)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		if hud.modal.visible:
			hud.close_modal()
		else:
			hud.show_menu(not hud.menu.visible)
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("capture_mouse") and not menu_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and not menu_open:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_look(event.relative)

func _look(relative: Vector2) -> void:
	if menu_open:
		return
	yaw -= relative.x * 0.004
	pitch = clampf(pitch - relative.y * 0.003, -0.9, -0.1)

func _menu_changed(open: bool) -> void:
	menu_open = open
	Session.input_direction = Vector2.ZERO
	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _practice(display_name: String, color: int) -> void:
	Session.start_practice(display_name, color)
	hud.show_menu(false)

func _host(display_name: String, color: int) -> void:
	if Session.host_room(display_name, color) == OK:
		hud.show_menu(false)

func _join(display_name: String, color: int, address: String, code: String) -> void:
	_awaiting_join = Session.join_room(display_name, color, address, code) == OK

func _sync(state: Dictionary) -> void:
	var players: Dictionary = state.players
	for id in avatars.keys():
		if not players.has(id):
			avatars[id].queue_free()
			avatars.erase(id)
	for id in players:
		if not avatars.has(id):
			var actor := Avatar.new()
			actor.player_id = int(id)
			add_child(actor)
			avatars[id] = actor
		avatars[id].update_player(players[id], state, Session.my_id)
	hud.update_state(state, Session.my_id)
	if _awaiting_join and Session.active and not Session.authority:
		_awaiting_join = false
		hud.show_menu(false)
	if int(state.target) == Session.my_id and _last_target != Session.my_id:
		_beep(640)
	if state.phase == "ended" and _last_phase == "playing":
		_beep(260)
	_last_target = int(state.target)
	_last_phase = state.phase

func _closed() -> void:
	_awaiting_join = false
	for actor in avatars.values():
		actor.queue_free()
	avatars.clear()
	hud.show_menu(true)
	hud.role.text = "PASS. CHASE. SURVIVE."
	hud.instruction.text = ""
	hud.roster.text = ""
	hud.chatter.text = ""
	hud.room_label.text = "THE ORIGINAL CHILDHOOD CHASE"
	hud.start_button.hide()
	hud.acknowledgement.hide()
	for child in hud.action_box.get_children():
		child.queue_free()

func _beep(frequency: float) -> void:
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var bytes := PackedByteArray()
	var samples := 3300
	bytes.resize(samples * 2)
	for i in range(samples):
		var sample := sin(float(i) * frequency * TAU / 22050.0) * 12000.0 * (1.0 - float(i) / samples)
		bytes.encode_s16(i * 2, int(sample))
	wave.data = bytes
	sound.stream = wave
	sound.play()

func _install_inputs() -> void:
	var bindings := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN], "menu": [KEY_ESCAPE], "capture_mouse": [KEY_TAB]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
