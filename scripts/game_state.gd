extends Node
## Estado global (autoload "GameState"): progresso, contadores,
## mapeamento de controles e efeitos sonoros.

const LEVEL_COUNT := 5

var current_level := 0
var caught := 0  # quantas vezes o caramujo te alcançou
var coins := 0
var story_seen := false

var _sfx := {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	for sfx_name in ["jump", "dash", "land", "win", "alert", "shell", "select", "stick",
			"coin", "unlock", "horn", "bounce", "hit", "caught", "train", "car"]:
		var path := "res://assets/sfx/%s.wav" % sfx_name
		if ResourceLoader.exists(path):
			_sfx[sfx_name] = load(path)
	for i in 10:
		var player := AudioStreamPlayer.new()
		player.volume_db = -6.0
		add_child(player)
		_players.append(player)


func new_game() -> void:
	current_level = 0
	caught = 0
	coins = 0


func play_sfx(sfx_name: String, pitch := 1.0) -> void:
	if not _sfx.has(sfx_name):
		return
	for player in _players:
		if not player.playing:
			player.stream = _sfx[sfx_name]
			player.pitch_scale = pitch
			player.play()
			return


func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_add_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_add_action("move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_add_action("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_add_action("jump", [KEY_SPACE, KEY_C], [JOY_BUTTON_A])
	_add_action("dash", [KEY_SHIFT, KEY_X], [JOY_BUTTON_X])
	_add_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_add_action("restart", [KEY_R], [JOY_BUTTON_BACK])


func _add_action(action: String, keys: Array, buttons: Array = [], axes: Array = []) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.3)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
	for button in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = button
		InputMap.action_add_event(action, jb)
	for axis in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axis[0]
		jm.axis_value = axis[1]
		InputMap.action_add_event(action, jm)
