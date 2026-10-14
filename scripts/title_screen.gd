extends Control
## Tela inicial: arte de capa, botões Jogar / Controles / Sair.

@onready var play_button: Button = $Menu/PlayButton
@onready var controls_button: Button = $Menu/ControlsButton
@onready var quit_button: Button = $Menu/QuitButton
@onready var controls_panel: PanelContainer = $ControlsPanel
@onready var close_controls: Button = $ControlsPanel/VBox/CloseButton
@onready var press_hint: Label = $PressHint
@onready var fade: ColorRect = $Fade
@onready var background: TextureRect = $Background

var _leaving := false


func _ready() -> void:
	for b in [play_button, controls_button, quit_button]:
		UiStyle.style_button(b, 32)
	UiStyle.style_button(close_controls, 24)
	controls_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	controls_panel.hide()

	play_button.pressed.connect(_on_play)
	controls_button.pressed.connect(_on_controls)
	quit_button.pressed.connect(func(): get_tree().quit())
	close_controls.pressed.connect(_on_close_controls)

	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, 0.6)
	play_button.grab_focus.call_deferred()


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	press_hint.modulate.a = 0.55 + sin(t * 3.0) * 0.35
	# leve "respiração" na arte de fundo
	background.scale = Vector2.ONE * (1.02 + sin(t * 0.5) * 0.01)


func _unhandled_input(event: InputEvent) -> void:
	if controls_panel.visible and event.is_action_pressed("ui_cancel"):
		_on_close_controls()


func _on_play() -> void:
	if _leaving:
		return
	_leaving = true
	GameState.play_sfx("win")
	GameState.new_game()
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.5)
	tw.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/game.tscn"))


func _on_controls() -> void:
	controls_panel.show()
	close_controls.grab_focus()


func _on_close_controls() -> void:
	controls_panel.hide()
	controls_button.grab_focus()
