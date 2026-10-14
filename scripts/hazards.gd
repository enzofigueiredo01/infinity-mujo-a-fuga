class_name Hazards
extends RefCounted
## Fábrica dos elementos especiais das fases (carros, trem, ventiladores,
## molas, dinheiro e a saída). Cada classe interna é um Node2D desenhado
## em código.


class CarLane:
	extends Node2D
	## Faixa de carros da avenida: andam da direita para a esquerda.
	const SPEED := 150.0
	const INTERVAL := 2.3
	const CAR := Vector2(30, 14)
	var x_min := 0.0
	var x_max := 0.0
	var floor_y := 0.0
	var cars: Array = []  # [x, cor]
	var _spawn_t := 1.0
	var _colors := [Color("fb7f5a"), Color("3ef0ff"), Color("e5cd32"), Color("5bd06a")]
	var _n := 0

	func setup(cell: Vector2i, level: LevelMap) -> void:
		x_min = cell.x * 16.0
		var x := cell.x
		while x + 1 < level.cols and not level.is_solid_cell(x + 1, cell.y):
			x += 1
		x_max = (x + 1) * 16.0
		floor_y = (cell.y + 1) * 16.0

	func hurt_rects() -> Array:
		var out := []
		for c in cars:
			out.append(Rect2(Vector2(c[0], floor_y - CAR.y), CAR))
		return out

	func _process(delta: float) -> void:
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			_spawn_t = INTERVAL + (0.8 if _n % 3 == 1 else 0.0)
			cars.append([x_max, _colors[_n % _colors.size()]])
			_n += 1
		for c in cars:
			c[0] -= SPEED * delta
		cars = cars.filter(func(c): return c[0] > x_min - CAR.x)
		queue_redraw()

	func _draw() -> void:
		for c in cars:
			var x0: float = max(c[0], x_min)
			var x1: float = min(c[0] + CAR.x, x_max)
			if x1 <= x0:
				continue
			var col: Color = c[1]
			var y := floor_y - CAR.y
			draw_rect(Rect2(x0, y + 4, x1 - x0, 7), col)
			var cab0: float = max(c[0] + 7, x_min)
			var cab1: float = min(c[0] + 22, x_max)
			if cab1 > cab0:
				draw_rect(Rect2(cab0, y, cab1 - cab0, 5), col.darkened(0.2))
				draw_rect(Rect2(cab0 + 1, y + 1, max(0.0, cab1 - cab0 - 2), 3), Color("bff5e8"))
			for wx in [c[0] + 4, c[0] + 22]:
				if wx >= x_min and wx + 5 <= x_max:
					draw_rect(Rect2(wx, y + 10, 5, 4), Color.BLACK)
			if c[0] >= x_min:
				draw_rect(Rect2(c[0], y + 6, 2, 2), Color("fedd86"))


class Train:
	extends Node2D
	## Trem do metrô: luzes piscam e a buzina toca antes dele passar.
	const IDLE := 2.8
	const WARN := 1.6
	const SPEED := 650.0
	const LENGTH := 640.0
	var x_min := 0.0
	var x_max := 0.0
	var top_y := 0.0
	var bottom_y := 0.0
	var _t := 0.0
	var _x := -9999.0
	var _state := "idle"

	func setup(cell: Vector2i, level: LevelMap) -> void:
		x_min = cell.x * 16.0
		var x := cell.x
		while x + 1 < level.cols and not level.is_solid_cell(x + 1, cell.y):
			x += 1
		x_max = (x + 1) * 16.0
		bottom_y = (cell.y + 1) * 16.0
		top_y = bottom_y - 48.0

	func hurt_rects() -> Array:
		if _state != "pass":
			return []
		var x0: float = max(_x, x_min)
		var x1: float = min(_x + LENGTH, x_max)
		if x1 <= x0:
			return []
		return [Rect2(x0, top_y + 4, x1 - x0, bottom_y - top_y - 4)]

	func _process(delta: float) -> void:
		_t += delta
		match _state:
			"idle":
				if _t > IDLE:
					_state = "warn"
					_t = 0.0
					GameState.play_sfx("horn")
			"warn":
				if _t > WARN:
					_state = "pass"
					_t = 0.0
					_x = x_min - LENGTH
					GameState.play_sfx("train")
			"pass":
				_x += SPEED * delta
				if _x > x_max:
					_state = "idle"
					_t = 0.0
		queue_redraw()

	func _draw() -> void:
		# trilhos
		draw_rect(Rect2(x_min, bottom_y - 3, x_max - x_min, 2), Color("8fa3c0"))
		for x in range(int(x_min), int(x_max), 12):
			draw_rect(Rect2(x, bottom_y - 1, 6, 1), Color("6b3d1a"))
		# luzes de aviso nas duas pontas
		var on := _state == "warn" and int(_t * 8.0) % 2 == 0
		for lx in [x_min + 2, x_max - 8]:
			draw_rect(Rect2(lx, top_y - 10, 6, 6), Color("ff3b6b") if on else Color("4a2030"))
		if _state != "pass":
			return
		var x0: float = max(_x, x_min)
		var x1: float = min(_x + LENGTH, x_max)
		if x1 <= x0:
			return
		draw_rect(Rect2(x0, top_y + 4, x1 - x0, bottom_y - top_y - 7), Color("c0c8d4"))
		draw_rect(Rect2(x0, top_y + 12, x1 - x0, 4), Color("3aa676"))
		for wx in range(int(_x) + 10, int(_x + LENGTH) - 20, 40):
			if wx >= x_min and wx + 24 <= x_max:
				draw_rect(Rect2(wx, top_y + 20, 24, 10), Color("1d2463"))
		if _x + LENGTH <= x_max and _x + LENGTH >= x_min:
			draw_rect(Rect2(_x + LENGTH - 6, top_y + 24, 4, 4), Color("fedd86"))


class Fan:
	extends Node2D
	## Ventilador no chão: sopra uma coluna de vento para cima.
	var top_y := 0.0
	var base_y := 0.0
	var _t := 0.0

	func setup(cell: Vector2i, level: LevelMap) -> void:
		position = Vector2(cell.x * 16.0 + 8.0, 0)
		base_y = (cell.y + 1) * 16.0
		var y := cell.y - 1
		while y > 0 and not level.is_solid_cell(cell.x, y):
			y -= 1
		top_y = (y + 1) * 16.0

	func wind_rect() -> Rect2:
		return Rect2(position.x - 12, top_y, 24, base_y - top_y)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-12, top_y, 24, base_y - top_y), Color(0.24, 0.94, 1.0, 0.06))
		for i in 10:
			var y := base_y - fmod(_t * 160.0 + i * 37.0, base_y - top_y)
			var x := sin(_t * 3.0 + i) * 7.0
			draw_rect(Rect2(x - 1, y, 2, 7), Color(0.75, 0.96, 1.0, 0.45))
		draw_rect(Rect2(-8, base_y - 6, 16, 6), Color("4a5876"))
		var blade := absf(sin(_t * 30.0)) * 7.0
		draw_rect(Rect2(-blade, base_y - 8, blade * 2.0, 2), Color("d8e4f2"))


class BouncePad:
	extends Node2D
	## Mola: lança o homem bem alto.
	var _squish := 0.0

	func setup(cell: Vector2i) -> void:
		position = Vector2(cell.x * 16.0 + 8.0, (cell.y + 1) * 16.0)

	func trigger_rect() -> Rect2:
		return Rect2(position + Vector2(-7, -6), Vector2(14, 6))

	func fire() -> void:
		_squish = 1.0

	func _process(delta: float) -> void:
		_squish = max(0.0, _squish - delta * 4.0)
		queue_redraw()

	func _draw() -> void:
		var h := 6.0 - _squish * 3.0 + (1.0 - _squish) * 0.0
		draw_rect(Rect2(-7, -2, 14, 2), Color("4a5876"))
		for i in 3:
			draw_rect(Rect2(-5 + (i % 2) * 2, -2 - (i + 1) * h / 3.0, 8, 1), Color("d8e4f2"))
		draw_rect(Rect2(-7, -3 - h, 14, 2), Color("ff4fd8") if _squish > 0.0 else Color("fb7f5a"))


class Coin:
	extends Node2D
	## Dinheiro do bilionário (coletável).
	var collected := false
	var _t := 0.0
	var _pop := 0.0

	func pick_rect() -> Rect2:
		return Rect2(position - Vector2(6, 6), Vector2(12, 12))

	func collect() -> void:
		collected = true
		_pop = 0.001
		GameState.play_sfx("coin")

	func _process(delta: float) -> void:
		_t += delta
		if _pop > 0.0:
			_pop += delta
			if _pop > 0.4:
				visible = false
		queue_redraw()

	func _draw() -> void:
		if _pop > 0.0:
			draw_arc(Vector2.ZERO, 4.0 + _pop * 30.0, 0.0, TAU, 16, Color(1, 0.87, 0.53, 1.0 - _pop / 0.4), 2.0)
			return
		var w := absf(cos(_t * 3.0)) * 3.0 + 3.0
		var y := sin(_t * 2.5) * 2.0
		draw_rect(Rect2(-w, y - 5, w * 2.0, 10), Color("e5cd32"))
		draw_rect(Rect2(-w + 1, y - 4, max(0.0, w * 2.0 - 2.0), 8), Color("fedd86"))
		if w > 3.0:
			draw_rect(Rect2(-0.5, y - 3, 1, 6), Color("8a6a2e"))
			draw_rect(Rect2(-2, y - 2, 4, 1), Color("8a6a2e"))
			draw_rect(Rect2(-2, y + 1, 4, 1), Color("8a6a2e"))


class ExitGoal:
	extends Node2D
	## Saída da fase, com o visual de cada cenário.
	var kind := "city"
	var _t := 0.0

	func goal_rect() -> Rect2:
		return Rect2(position + Vector2(-8, -14), Vector2(16, 22))

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var glow := 0.5 + 0.5 * sin(_t * 4.0)
		draw_rect(Rect2(-12, 6, 24, 2), Color(1, 0.87, 0.53, 0.3 + 0.4 * glow))
		match kind:
			"city":
				# helicóptero pousado no telhado
				var r := 22.0 * absf(sin(_t * 25.0))
				draw_rect(Rect2(-r, -14, r * 2.0, 1), Color.BLACK)
				draw_rect(Rect2(-1, -14, 2, 4), Color.BLACK)
				draw_rect(Rect2(-12, -10, 22, 13), Color("1d2463"))
				draw_rect(Rect2(2, -8, 7, 6), Color("bff5e8"))
				draw_rect(Rect2(-24, -7, 14, 3), Color("1d2463"))
				draw_rect(Rect2(-10, -3, 18, 2), Color("e5cd32"))
				draw_rect(Rect2(-12, 5, 22, 1), Color.BLACK)
				draw_rect(Rect2(-8, 3, 1, 3), Color.BLACK)
				draw_rect(Rect2(5, 3, 1, 3), Color.BLACK)
			"metro":
				draw_rect(Rect2(-8, -16, 16, 24), Color("3aa676"))
				draw_rect(Rect2(-6, -14, 12, 22), Color("1d4f3a"))
				draw_rect(Rect2(-9, -22, 18, 6), Color("3aa676"))
				draw_rect(Rect2(-6, -20, 4, 2), Color.WHITE)
				draw_rect(Rect2(-1, -21, 2, 4), Color.WHITE)
				draw_rect(Rect2(2, -20, 4, 2), Color.WHITE)
			"bunker":
				draw_rect(Rect2(-10, -16, 20, 24), Color("8fa3c0"))
				var open := 4.0 + glow * 2.0
				draw_rect(Rect2(-open, -14, open * 2.0, 22), Color("fedd86", 0.8))
				draw_rect(Rect2(-3, -22, 6, 4), Color("ff3b6b") if glow > 0.5 else Color("5bd06a"))
			"neon":
				var y := sin(_t * 3.0) * 2.0
				draw_rect(Rect2(-14, -6 + y, 28, 9), Color("ff4fd8"))
				draw_rect(Rect2(-6, -11 + y, 14, 6), Color("3ef0ff", 0.8))
				draw_rect(Rect2(-14, 3 + y, 6, 2), Color("3ef0ff", glow))
				draw_rect(Rect2(8, 3 + y, 6, 2), Color("3ef0ff", glow))
			"space":
				draw_circle(Vector2(0, -4), 11.0, Color("dfe6ee"))
				draw_circle(Vector2(0, -4), 6.0, Color("4fc3ff"))
				draw_rect(Rect2(-4, 6, 8, 3 + glow * 4.0), Color("fb7f5a"))
		# seta "SAÍDA" pulsando
		var ay := -30.0 - glow * 3.0
		draw_colored_polygon(PackedVector2Array([Vector2(-4, ay), Vector2(4, ay), Vector2(0, ay + 5)]), Color("fedd86"))
