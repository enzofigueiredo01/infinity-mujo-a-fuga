class_name Fx
extends Node2D
## Partículas simples em pixel: explosão ao morrer, poeira do dash, anel de renascimento.

var _parts: Array = []  # [pos, vel, life, max_life, color, size]
var _rings: Array = []  # [pos, t]
var _texts: Array = []  # [pos, text, t]
var _font: Font = preload("res://assets/fonts/alagard.ttf")


func _ready() -> void:
	z_index = 5


func burst(pos: Vector2, colors: Array, count: int, power: float) -> void:
	for i in count:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * randf_range(power * 0.3, power)
		_parts.append([pos, v, 0.0, randf_range(0.4, 0.8), colors[i % colors.size()], randf_range(1.5, 3.0)])


func dust(pos: Vector2, color: Color) -> void:
	_parts.append([pos + Vector2(randf_range(-4, 4), randf_range(-4, 4)), Vector2.ZERO, 0.0, 0.3, color, 2.0])


func ring(pos: Vector2) -> void:
	_rings.append([pos, 0.0])


## Texto flutuante (ex.: "-5s" de tempo perdido).
func popup(pos: Vector2, text: String) -> void:
	_texts.append([pos, text, 0.0])


func _process(delta: float) -> void:
	for p in _parts:
		p[2] += delta
		p[1].y += 300.0 * delta
		p[0] += p[1] * delta
	_parts = _parts.filter(func(p): return p[2] < p[3])
	for r in _rings:
		r[1] += delta
	_rings = _rings.filter(func(r): return r[1] < 0.4)
	for t in _texts:
		t[2] += delta
	_texts = _texts.filter(func(t): return t[2] < 1.2)
	queue_redraw()


func _draw() -> void:
	for p in _parts:
		var c: Color = p[4]
		c.a *= 1.0 - p[2] / p[3]
		var s: float = p[5]
		draw_rect(Rect2(p[0] - Vector2(s, s) / 2.0, Vector2(s, s)), c)
	for r in _rings:
		var t: float = r[1] / 0.4
		draw_arc(r[0], 4.0 + t * 20.0, 0.0, TAU, 20, Color(0.75, 0.96, 0.91, 1.0 - t), 2.0)
	for tx in _texts:
		var k: float = tx[2] / 1.2
		var p: Vector2 = tx[0] + Vector2(-12, -k * 14.0)
		draw_string_outline(_font, p, tx[1], HORIZONTAL_ALIGNMENT_CENTER, 24, 16, 4, Color(0.043, 0.063, 0.255, 1.0 - k))
		draw_string(_font, p, tx[1], HORIZONTAL_ALIGNMENT_CENTER, 24, 16, Color(1, 0.36, 0.42, 1.0 - k))
