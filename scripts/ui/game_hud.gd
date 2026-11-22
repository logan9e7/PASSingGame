class_name GameHUD
extends CanvasLayer

signal practice_requested(display_name: String, color: int)
signal host_requested(display_name: String, color: int)
signal join_requested(display_name: String, color: int, address: String, code: String)
signal action_requested(kind: String, recipient: int)
signal leave_requested
signal menu_changed(open: bool)

const INK := Color("edf4df")
const LIME := Color("e6f778")
var root: Control
var menu: PanelContainer
var menu_box: VBoxContainer
var name_input: LineEdit
var ip_input: LineEdit
var code_input: LineEdit
var color_picker: OptionButton
var error_label: Label
var role: Label
var instruction: Label
var timer: Label
var room_label: Label
var roster: Label
var chatter: Label
var action_box: HBoxContainer
var acknowledgement: Button
var start_button: Button
var menu_button: Button
var toast: Label
var toast_time := 0.0
var modal: PanelContainer
var modal_text: RichTextLabel
var touch: TouchControls
var _action_key := ""
var _last_state: Dictionary = {}
var _local_id := 1
var _host_id := 1

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", INK)
	for item in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("e6f778") if item == "hover" else Color("315c53") if item == "pressed" else Color("24443f")
		style.set_corner_radius_all(10)
		style.set_content_margin_all(13)
		if item == "focus":
			style.border_color = LIME
			style.set_border_width_all(3)
		theme.set_stylebox(item, "Button", style)
	theme.set_color("font_hover_color", "Button", Color("152e2b"))
	root.theme = theme
	_build_hud()
	_build_menu()
	_build_modal()
	touch = TouchControls.new()
	root.add_child(touch)
	show_menu(true)

func _build_hud() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 28
	top.offset_top = 22
	top.offset_right = -28
	root.add_child(top)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(identity)
	var brand := label("PASSING GAME", 25, LIME)
	identity.add_child(brand)
	room_label = label("THE ORIGINAL CHILDHOOD CHASE", 14)
	identity.add_child(room_label)
	var time_box := VBoxContainer.new()
	top.add_child(time_box)
	timer = label("00:00", 29)
	time_box.add_child(timer)
	menu_button = button("Menu", func(): show_menu(not menu.visible))
	time_box.add_child(menu_button)
	var role_box := VBoxContainer.new()
	role_box.position = Vector2(28, 110)
	root.add_child(role_box)
	role = label("PASS. CHASE. SURVIVE.", 29, LIME)
	role_box.add_child(role)
	instruction = label("", 17)
	role_box.add_child(instruction)
	roster = label("", 15)
	roster.position = Vector2(28, 190)
	root.add_child(roster)
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_left = -310
	bottom.offset_right = 310
	bottom.offset_top = -135
	bottom.offset_bottom = -24
	root.add_child(bottom)
	acknowledgement = button("I SAID YES · ACKNOWLEDGE PASS", func(): action_requested.emit("ack", 0))
	bottom.add_child(acknowledgement)
	acknowledgement.hide()
	action_box = HBoxContainer.new()
	action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	action_box.add_theme_constant_override("separation", 8)
	bottom.add_child(action_box)
	start_button = button("Start chase · 4 players required", func(): action_requested.emit("start", 0))
	bottom.add_child(start_button)
	start_button.hide()
	chatter = label("", 15)
	chatter.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	chatter.offset_left = -330
	chatter.offset_right = -25
	chatter.offset_top = -240
	chatter.offset_bottom = -155
	root.add_child(chatter)
	toast = label("", 17, Color("ffe4ac"))
	toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toast.offset_left = -540
	toast.offset_top = 110
	toast.offset_right = -28
	toast.offset_bottom = 180
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(toast)
	var controls := label("WASD / arrows · move     Right mouse / swipe · look     Esc · menu", 14)
	controls.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	controls.offset_left = -310
	controls.offset_top = -26
	controls.offset_right = 360
	root.add_child(controls)

func _build_menu() -> void:
	menu = panel()
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.offset_left = -265
	menu.offset_right = 265
	menu.offset_top = -295
	menu.offset_bottom = 295
	root.add_child(menu)
	var scroll := ScrollContainer.new()
	menu.add_child(scroll)
	menu_box = VBoxContainer.new()
	menu_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_box.add_theme_constant_override("separation", 10)
	scroll.add_child(menu_box)
	menu_box.add_child(label("BACK TO THE PLAYGROUND", 14, LIME))
	menu_box.add_child(label("PASSING GAME", 38))
	menu_box.add_child(label("A third-person chase with the original rules.", 17))
	name_input = field("Your name", "Player")
	menu_box.add_child(name_input)
	color_picker = OptionButton.new()
	for text in ["Lime shirt", "Lavender shirt", "Coral shirt", "Sky shirt", "Rose shirt", "Mint shirt", "Gold shirt", "Ice shirt"]:
		color_picker.add_item(text)
	menu_box.add_child(color_picker)
	menu_box.add_child(button("Practice · you + 3 bots", _practice))
	menu_box.add_child(button("Create a private LAN room", _host))
	ip_input = field("Host IP address (same network)", "127.0.0.1")
	menu_box.add_child(ip_input)
	code_input = field("6-character room code", "")
	code_input.max_length = 6
	menu_box.add_child(code_input)
	menu_box.add_child(button("Join private room", _join))
	var links := HBoxContainer.new()
	links.add_child(button("How to play", _rules))
	links.add_child(button("Survival records", _records))
	links.add_child(button("Resume", func():
		if Session.active:
			show_menu(false)
		else:
			show_notice("Start practice or join a room first.")))
	menu_box.add_child(links)
	menu_box.add_child(button("Leave playground", func(): leave_requested.emit()))
	error_label = label("", 15, Color("ffbc9b"))
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_box.add_child(error_label)
	menu_box.add_child(label("Prototype · Quick Match and online services are not connected.", 13))

func _build_modal() -> void:
	modal = panel()
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.offset_left = -330
	modal.offset_right = 330
	modal.offset_top = -250
	modal.offset_bottom = 250
	root.add_child(modal)
	var box := VBoxContainer.new()
	modal.add_child(box)
	modal_text = RichTextLabel.new()
	modal_text.bbcode_enabled = true
	modal_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(modal_text)
	box.add_child(button("Close", close_modal))
	modal.hide()

func update_state(state: Dictionary, local_id: int) -> void:
	_last_state = state
	_local_id = local_id
	_host_id = int(state.host)
	var players: Dictionary = state.players
	var playing: bool = state.phase == "playing"
	var mine: Dictionary = players.get(local_id, {})
	room_label.text = ("PRACTICE · BOTS" if state.get("practice", false) else "PRIVATE LAN · " + String(state.get("code", ""))) + "   /   ROUND %02d" % state.round
	timer.text = time_string(float(mine.get("streak", 0)))
	var chaser_name := player_name(int(state.chaser))
	var target_name := player_name(int(state.target))
	if not playing:
		role.text = "ROUND COMPLETE" if state.phase == "ended" else "GET THE GANG TOGETHER"
		instruction.text = "Next chaser: " + player_name(int(state.next_chaser)) if state.phase == "ended" and state.next_chaser != 0 else "The host starts when at least 4 players join."
	elif mine.get("eliminated", false):
		role.text = "OUT THIS ROUND"
		instruction.text = "Watch the chase. You return next round."
	elif local_id == state.chaser:
		role.text = "YOU ARE THE CHASER"
		instruction.text = "Catch " + target_name + ". Only the active target counts." if state.target != 0 else "Say a runner’s name, then call them below."
	elif local_id == state.target:
		role.text = "YOU ARE THE TARGET"
		instruction.text = "Run. Call PASS + a name, then select that runner."
	else:
		role.text = "YOU ARE A RUNNER"
		instruction.text = chaser_name + " is chasing " + target_name if state.target != 0 else "Stay ready. Your name could be next."
	if playing and state.pending != 0:
		instruction.text = "PASS " + player_name(int(state.pending)) + "? Waiting for acknowledgement. Current target stays active."
	var lines: Array[String] = []
	for id in players:
		var p: Dictionary = players[id]
		var badge := "OUT" if p.eliminated else "CHASER" if id == state.chaser and playing else "TARGET" if id == state.target and playing else "RUNNER"
		lines.append("%s  %s%s" % [p.name, badge, "  (you)" if id == local_id else ""])
	roster.text = "\n".join(lines)
	chatter.text = "\n".join(state.events.slice(0, 3))
	start_button.visible = not playing and local_id == state.host
	start_button.disabled = players.size() < 4
	start_button.text = "Play next round" if state.phase == "ended" else "Start chase · %d/4 ready" % mini(players.size(), 4)
	acknowledgement.visible = playing and state.pending == local_id
	var choices: Array = []
	var can_call: bool = playing and local_id == state.chaser and state.target == 0
	var can_pass: bool = playing and local_id == state.target
	if can_call or can_pass:
		for id in players:
			if id == state.chaser or id == local_id or players[id].eliminated:
				continue
			if can_pass and id == state.previous:
				continue
			choices.append(id)
	var key := str(choices) + str(can_call)
	if key != _action_key:
		_action_key = key
		for child in action_box.get_children():
			child.queue_free()
		for id in choices:
			var kind := "call" if can_call else "pass"
			var item := button(("Call " if can_call else "PASS ") + player_name(id), func(): action_requested.emit(kind, id))
			action_box.add_child(item)

func show_menu(open: bool) -> void:
	menu.visible = open
	menu_button.text = "Resume" if open else "Menu"
	if touch != null:
		touch.enabled = not open and not modal.visible
		touch.reset()
	menu_changed.emit(open)
	if open:
		name_input.grab_focus()

func show_notice(message: String) -> void:
	toast.text = message
	toast_time = 5.0
	if menu.visible:
		error_label.text = message

func _process(delta: float) -> void:
	toast_time -= delta
	if toast_time <= 0:
		toast.text = ""

func _practice() -> void:
	if _valid_name():
		practice_requested.emit(name_input.text.strip_edges(), color_picker.selected)

func _host() -> void:
	if _valid_name():
		host_requested.emit(name_input.text.strip_edges(), color_picker.selected)

func _join() -> void:
	if not _valid_name():
		return
	if ip_input.text.strip_edges().is_empty():
		error_label.text = "Enter the host IP address."
		ip_input.grab_focus()
		return
	if code_input.text.strip_edges().length() != 6:
		error_label.text = "Enter the 6-character room code."
		code_input.grab_focus()
		return
	join_requested.emit(name_input.text.strip_edges(), color_picker.selected, ip_input.text, code_input.text)

func _valid_name() -> bool:
	if name_input.text.strip_edges().is_empty():
		error_label.text = "Enter your playground name."
		name_input.grab_focus()
		return false
	error_label.text = ""
	return true

func _rules() -> void:
	modal_text.text = "[font_size=28]THE WAY WE PLAYED.[/font_size]\n\nFour or more players. One chaser; everyone else runs.\n\nThe chaser calls a runner’s name. That runner becomes the active target. Only touching that player counts.\n\nOnly the active target can PASS. Say PASS and another runner’s name, then select them. The named player says yes and presses ACKNOWLEDGE. Until then, the old target stays active. A catch before acknowledgement wins.\n\nUnlimited passes. No immediate passing back to the previous target. No powers, combat or safe zones.\n\nCross the yellow boundary and you are out until next round. If the target goes out, the chaser calls another runner. If the chaser goes out or no runners remain, stop the round without a winner.\n\nThe caught player becomes the next chaser. Survival streaks carry across rounds until you become chaser.\n\nWASD / arrows move. Hold right mouse to look, or Tab to capture the mouse. Touch: joystick on the left, swipe on the right. Use your own group voice call; speech is not verified."
	modal.show()
	touch.enabled = false
	menu_changed.emit(true)

func _records() -> void:
	var text := "[font_size=28]SURVIVAL RECORDS[/font_size]\n\n"
	if _last_state.is_empty():
		text += "Your survival story starts with your first chase."
	else:
		for p in _last_state.players.values():
			text += "%s   ·   Best %s   ·   Total %s\n" % [String(p.name).replace("[", "("), time_string(p.best), time_string(p.total)]
		text += "\nCurrent session only. Persistence is planned."
	modal_text.text = text
	modal.show()
	touch.enabled = false
	menu_changed.emit(true)

func close_modal() -> void:
	modal.hide()
	touch.enabled = not menu.visible
	menu_changed.emit(menu.visible)

func player_name(id: int) -> String:
	return String(_last_state.get("players", {}).get(id, {}).get("name", "—"))

static func time_string(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func label(text: String, font_size_value: int = 18, color: Color = INK) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size_value)
	item.add_theme_color_override("font_color", color)
	item.add_theme_color_override("font_shadow_color", Color(0.03, 0.09, 0.08, 0.9))
	item.add_theme_constant_override("shadow_offset_x", 1)
	item.add_theme_constant_override("shadow_offset_y", 2)
	item.add_theme_color_override("font_outline_color", Color(0.03, 0.09, 0.08, 0.6))
	item.add_theme_constant_override("outline_size", 3)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item

func button(text: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size.y = 46
	item.pressed.connect(callback)
	return item

func field(placeholder: String, value: String) -> LineEdit:
	var item := LineEdit.new()
	item.placeholder_text = placeholder
	item.text = value
	item.custom_minimum_size.y = 44
	item.max_length = 64
	return item

func panel() -> PanelContainer:
	var item := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.15, 0.14, 0.96)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(22)
	style.border_color = Color("537366")
	style.set_border_width_all(1)
	item.add_theme_stylebox_override("panel", style)
	return item
