class_name SceneryBackground
extends Node2D
## Fundo desenhado de cada cenário (na tela, atrás do mapa).
## A cidade usa a animação em vídeo das artes do projeto.

const VIEW := Vector2(1280, 720)
const CITY_VIDEO := "res://assets/video/city_background.ogv"

var theme := "city"
var _t := 0.0
var _stars: Array = []


func setup(theme_name: String, layer: CanvasLayer) -> void:
	theme = theme_name
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 140:
		_stars.append([Vector2(rng.randf() * VIEW.x, rng.randf() * VIEW.y), rng.randf_range(1.0, 3.0), rng.randf() * TAU])
	if theme == "city" and ResourceLoader.exists(CITY_VIDEO):
		var sky := ColorRect.new()
		sky.color = Color("9bdde6")
		sky.size = VIEW
		layer.add_child(sky)
		var video := VideoStreamPlayer.new()
		video.stream = load(CITY_VIDEO)
		video.expand = true
		video.loop = true
		video.size = Vector2(VIEW.y * 2.5, VIEW.y)
		video.position = Vector2((VIEW.x - video.size.x) / 2.0, 0)
		video.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(video)
		video.play()
		var tint := ColorRect.new()
		tint.color = Color(0.043, 0.063, 0.255, 0.15)
		tint.size = VIEW
		layer.add_child(tint)
		visible = false


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	match theme:
		"metro": _draw_metro()
		"bunker": _draw_bunker()
		"neon": _draw_neon()
		"space": _draw_space()


func _gradient(top: Color, bottom: Color) -> void:
	for i in 24:
		var k := i / 23.0
		draw_rect(Rect2(0, i * VIEW.y / 24.0, VIEW.x, VIEW.y / 24.0 + 1), top.lerp(bottom, k))


func _draw_metro() -> void:
	_gradient(Color("16202a"), Color("2a3a44"))
	# parede de azulejos ao fundo, pilares e cartazes
	for x in range(0, int(VIEW.x), 48):
		draw_rect(Rect2(x, 0, 2, VIEW.y), Color(1, 1, 1, 0.03))
	for i in 6:
		var px := 80.0 + i * 220.0
		draw_rect(Rect2(px, 0, 36, VIEW.y), Color("1e2b35"))
		draw_rect(Rect2(px + 4, 0, 4, VIEW.y), Color(1, 1, 1, 0.05))
	for i in 3:
		var cx := 200.0 + i * 420.0
		draw_rect(Rect2(cx, 210, 120, 160), Color("e5cd32", 0.25))
		draw_rect(Rect2(cx + 10, 225, 100, 20), Color("fb7f5a", 0.35))
	# luzes do teto
	for i in 10:
		var lx := 60.0 + i * 130.0
		var a := 0.5 + 0.5 * sin(_t * 1.5 + i)
		draw_rect(Rect2(lx, 30, 60, 6), Color(1, 0.95, 0.75, 0.25 + 0.15 * a))


func _draw_bunker() -> void:
	_gradient(Color("23262b"), Color("33373d"))
	for y in range(0, int(VIEW.y), 64):
		draw_rect(Rect2(0, y, VIEW.x, 2), Color(0, 0, 0, 0.25))
	# canos
	for i in 4:
		var y := 120.0 + i * 170.0
		draw_rect(Rect2(0, y, VIEW.x, 14), Color("40454c"))
		draw_rect(Rect2(0, y + 2, VIEW.x, 3), Color("5d636b"))
	# luzes de alerta girando
	for i in 3:
		var a := 0.5 + 0.5 * sin(_t * 4.0 + i * 2.0)
		draw_circle(Vector2(240 + i * 400, 60), 20.0 + a * 10.0, Color(1, 0.3, 0.2, 0.12 * a))


func _draw_neon() -> void:
	_gradient(Color("140a2e"), Color("3a1257"))
	for s in _stars:
		draw_rect(Rect2(s[0] * Vector2(1, 0.5), Vector2(1, 1) * (s[1] * 0.6)), Color(1, 1, 1, 0.4 + 0.3 * sin(_t * 2.0 + s[2])))
	# prédios neon ao fundo
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var x := 0.0
	while x < VIEW.x:
		var w := rng.randf_range(60, 140)
		var h := rng.randf_range(200, 520)
		draw_rect(Rect2(x, VIEW.y - h, w - 8, h), Color("1d1040"))
		var glow := Color("ff4fd8") if rng.randf() < 0.5 else Color("3ef0ff")
		glow.a = 0.35 + 0.15 * sin(_t * 2.0 + x)
		draw_rect(Rect2(x, VIEW.y - h, w - 8, 3), glow)
		for wy in range(int(VIEW.y - h) + 16, int(VIEW.y), 28):
			for wx in range(int(x) + 8, int(x + w) - 16, 18):
				if rng.randf() < 0.4:
					draw_rect(Rect2(wx, wy, 6, 10), Color(glow.r, glow.g, glow.b, 0.25))
		x += w
	# carros voadores passando
	for i in 3:
		var cx := fmod(_t * (60.0 + i * 25.0) + i * 500.0, VIEW.x + 200.0) - 100.0
		var cy := 140.0 + i * 90.0
		draw_rect(Rect2(cx, cy, 30, 8), Color("3ef0ff", 0.5))
		draw_rect(Rect2(cx - 20, cy + 3, 20, 2), Color("ff4fd8", 0.3))


func _draw_space() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color("05060f"))
	for s in _stars:
		draw_rect(Rect2(s[0], Vector2(1, 1) * s[1]), Color(1, 1, 1, 0.5 + 0.4 * sin(_t * 1.5 + s[2])))
	# a Terra lá embaixo
	draw_circle(Vector2(VIEW.x * 0.7, VIEW.y + 520), 700.0, Color("1d4f9c"))
	draw_circle(Vector2(VIEW.x * 0.7, VIEW.y + 520), 700.0 - 6.0, Color("2a6fd0"))
	for i in 6:
		draw_circle(Vector2(VIEW.x * 0.3 + i * 160.0, VIEW.y - 60 + sin(i) * 30.0), 50.0, Color("5bd06a", 0.35))
	draw_arc(Vector2(VIEW.x * 0.7, VIEW.y + 520), 712.0, PI, TAU, 96, Color("4fc3ff", 0.4), 6.0)
