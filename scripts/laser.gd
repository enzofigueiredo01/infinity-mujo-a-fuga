class_name Laser
extends Node2D
## Laser do bilionário: emissor no teto que dispara para baixo em ciclos.
## Pisca (aviso) antes de ligar; só machuca quando está ligado.

const ON_TIME := 1.3
const WARN_TIME := 0.5
const OFF_TIME := 1.1
const CYCLE := ON_TIME + WARN_TIME + OFF_TIME

var length := 16.0
var phase := 0.0
var _t := 0.0


func setup(cell: Vector2i, level: LevelMap, phase_offset: float) -> void:
	position = Vector2(cell.x * LevelMap.TILE + LevelMap.TILE / 2.0, (cell.y + 1) * LevelMap.TILE)
	var y := cell.y + 1
	while y < level.rows and not level.is_solid_cell(cell.x, y):
		y += 1
	length = (y - cell.y - 1) * LevelMap.TILE
	phase = phase_offset
	_t = phase


func state() -> String:
	var t := fmod(_t, CYCLE)
	if t < OFF_TIME:
		return "off"
	if t < OFF_TIME + WARN_TIME:
		return "warn"
	return "on"


func reset() -> void:
	_t = phase


func hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-3, 0), Vector2(6, length))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := state()
	# lente do emissor
	draw_rect(Rect2(-5, -4, 10, 4), Color("4a5876"))
	draw_rect(Rect2(-3, -2, 6, 2), Color("ff3b6b") if s != "off" else Color("6b2030"))
	match s:
		"warn":
			if int(_t * 16.0) % 2 == 0:
				draw_rect(Rect2(-0.5, 0, 1, length), Color(1, 0.23, 0.42, 0.7))
		"on":
			var w := 3.0 + sin(_t * 40.0) * 0.6
			draw_rect(Rect2(-w - 2, 0, (w + 2) * 2, length), Color(1, 0.23, 0.42, 0.25))
			draw_rect(Rect2(-w, 0, w * 2, length), Color(1, 0.23, 0.42, 0.85))
			draw_rect(Rect2(-1, 0, 2, length), Color(1, 0.92, 0.95, 1))
			draw_rect(Rect2(-6, length - 3, 12, 3), Color(1, 0.6, 0.7, 0.8))
