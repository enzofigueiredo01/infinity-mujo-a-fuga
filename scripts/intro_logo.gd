extends Control
## Logo de introdução (Mujo Estudio), exibida antes do menu inicial.

const NEXT_SCENE := "res://scenes/title_screen.tscn"

@onready var logo: TextureRect = $Logo
@onready var trail: ColorRect = $SlimeTrail
@onready var presents: Label = $Presents
@onready var fade: ColorRect = $Fade

var _leaving := false
var _can_skip := false


func _ready() -> void:
	logo.modulate.a = 0.0
	logo.pivot_offset = logo.size / 2.0
	logo.scale = Vector2(0.85, 0.85)
	presents.modulate.a = 0.0
	trail.scale.x = 0.0
	fade.color.a = 0.0

	var tw := create_tween()
	tw.tween_interval(0.3)
	# o rastro de muco "desenha" a entrada da logo
	tw.tween_property(trail, "scale:x", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(logo, "modulate:a", 1.0, 0.9)
	tw.parallel().tween_property(logo, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): GameState.play_sfx("stick", 0.8))
	tw.tween_property(presents, "modulate:a", 1.0, 0.5)
	tw.tween_callback(func(): _can_skip = true)
	tw.tween_interval(1.6)
	tw.tween_callback(_leave)
	get_tree().create_timer(0.4).timeout.connect(func(): _can_skip = true)


func _process(_delta: float) -> void:
	# a antena do caramujo "respira"
	logo.position.y = (size.y - logo.size.y) / 2.0 - 30.0 + sin(Time.get_ticks_msec() / 400.0) * 2.0


func _unhandled_input(event: InputEvent) -> void:
	if _can_skip and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed():
		_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.5)
	tw.tween_callback(func(): get_tree().change_scene_to_file(NEXT_SCENE))
