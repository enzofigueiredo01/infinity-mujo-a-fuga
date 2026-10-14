class_name LevelMap
extends Node2D
## Lê o mapa ASCII da fase, cria as colisões e desenha os blocos
## com o visual do cenário (cidade, metrô, bunker, neon, espaço).

const TILE := 16

const THEMES := {
	"city": {"fill": "8c4b3a", "dark": "5e2f24", "light": "b5654f", "top": "c9c1b1", "plat_a": "fb7f5a", "plat_b": "fedd86"},
	"metro": {"fill": "d9e2e6", "dark": "9fb0b8", "light": "f4f8fa", "top": "3aa676", "plat_a": "2c3e50", "plat_b": "e5cd32"},
	"bunker": {"fill": "5a5f66", "dark": "3d4147", "light": "7a8088", "top": "e5cd32", "plat_a": "4a5876", "plat_b": "8fa3c0"},
	"neon": {"fill": "1a1033", "dark": "0c0820", "light": "2d1f55", "top": "3ef0ff", "plat_a": "ff4fd8", "plat_b": "2d1f55"},
	"space": {"fill": "dfe6ee", "dark": "9aa6b5", "light": "ffffff", "top": "4fc3ff", "plat_a": "c0c8d4", "plat_b": "4fc3ff"},
}
const SPIKE := Color("eef3fa")
const SPIKE_DARK := Color("0b1041")

var theme := "city"
var cols := 0
var rows := 0
var cells: Array[PackedStringArray] = []
var player_spawn := Vector2.ZERO
var snail_spawn := Vector2.ZERO
var exit_pos := Vector2.ZERO
var coin_spawns: Array[Vector2] = []
var laser_cells: Array[Vector2i] = []
var sign_cells: Array[Vector2i] = []
var car_lanes: Array[Vector2i] = []
var train_lanes: Array[Vector2i] = []
var fan_cells: Array[Vector2i] = []
var bounce_cells: Array[Vector2i] = []

var _c := {}
var _t := 0.0


func build(map: Array, theme_name: String) -> void:
	theme = theme_name
	for k in THEMES[theme]:
		_c[k] = Color(THEMES[theme][k])
	rows = map.size()
	cols = String(map[0]).length()
	cells.clear()
	for y in rows:
		var row := PackedStringArray()
		var line: String = map[y]
		for x in cols:
			var c := line[x] if x < line.length() else "."
			var center := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			var cell := Vector2i(x, y)
			match c:
				"P": player_spawn = center
				"S": snail_spawn = center
				"X": exit_pos = center
				"$": coin_spawns.append(center)
				"L": laser_cells.append(cell)
				"?": sign_cells.append(cell)
				"A": car_lanes.append(cell)
				"T": train_lanes.append(cell)
				"F": fan_cells.append(cell)
				"B": bounce_cells.append(cell)
			if c in ["P", "S", "X", "$", "A", "T", "F", "B"]:
				c = "."
			row.append(c)
		cells.append(row)
	_build_collision()
	queue_redraw()


func pixel_size() -> Vector2:
	return Vector2(cols * TILE, rows * TILE)


func get_cell(cx: int, cy: int) -> String:
	if cx < 0 or cy < 0 or cx >= cols or cy >= rows:
		return "#"
	return cells[cy][cx]


func is_solid_cell(cx: int, cy: int) -> bool:
	return get_cell(cx, cy) in ["#", "=", "L"]


func is_spike_cell(cx: int, cy: int) -> bool:
	return get_cell(cx, cy) in ["^", "v", "<", ">"]


func cell_at(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


func is_solid_at(pos: Vector2) -> bool:
	var c := cell_at(pos)
	return is_solid_cell(c.x, c.y)


## Retorna a direção da ponta do espinho tocado (para o empurrão) ou ZERO.
func spike_hit(rect: Rect2) -> Vector2:
	var c0 := cell_at(rect.position)
	var c1 := cell_at(rect.end)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			if not is_spike_cell(cx, cy):
				continue
			var o := Vector2(cx * TILE, cy * TILE)
			var hit: Rect2
			var dir: Vector2
			match get_cell(cx, cy):
				"^":
					hit = Rect2(o + Vector2(2, 9), Vector2(12, 7))
					dir = Vector2.UP
				"v":
					hit = Rect2(o + Vector2(2, 0), Vector2(12, 7))
					dir = Vector2.DOWN
				"<":
					hit = Rect2(o + Vector2(9, 2), Vector2(7, 12))
					dir = Vector2.LEFT
				">":
					hit = Rect2(o + Vector2(0, 2), Vector2(7, 12))
					dir = Vector2.RIGHT
			if hit.intersects(rect):
				return dir
	return Vector2.ZERO


func _build_collision() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	var used := {}
	for y in rows:
		var x := 0
		while x < cols:
			if not is_solid_cell(x, y) or used.has(Vector2i(x, y)):
				x += 1
				continue
			var x2 := x
			while x2 + 1 < cols and is_solid_cell(x2 + 1, y) and not used.has(Vector2i(x2 + 1, y)):
				x2 += 1
			var y2 := y
			var grow := true
			while grow and y2 + 1 < rows:
				for xx in range(x, x2 + 1):
					if not is_solid_cell(xx, y2 + 1) or used.has(Vector2i(xx, y2 + 1)):
						grow = false
						break
				if grow:
					y2 += 1
			for yy in range(y, y2 + 1):
				for xx in range(x, x2 + 1):
					used[Vector2i(xx, yy)] = true
			var shape := RectangleShape2D.new()
			shape.size = Vector2((x2 - x + 1) * TILE, (y2 - y + 1) * TILE)
			var cs := CollisionShape2D.new()
			cs.shape = shape
			cs.position = Vector2(x * TILE, y * TILE) + shape.size / 2.0
			body.add_child(cs)
			x = x2 + 1


func _process(delta: float) -> void:
	_t += delta
	if theme == "neon" or theme == "space":
		queue_redraw()  # luzes piscando


# ---------------------------------------------------------------- desenho

func _draw() -> void:
	for y in rows:
		for x in cols:
			var c := get_cell(x, y)
			var o := Vector2(x * TILE, y * TILE)
			match c:
				"#", "L": _draw_block(x, y, o)
				"=": _draw_platform(x, y, o)
				"^", "v", "<", ">": _draw_spike(c, o)
				"?": _draw_sign(o)


func _draw_block(x: int, y: int, o: Vector2) -> void:
	var r := Rect2(o, Vector2(TILE, TILE))
	draw_rect(r, _c.fill)
	var open_top := not is_solid_cell(x, y - 1)
	match theme:
		"city":
			# tijolos
			var off := 0 if y % 2 == 0 else 8
			draw_rect(Rect2(o + Vector2(0, 7), Vector2(TILE, 1)), _c.dark)
			draw_rect(Rect2(o + Vector2(0, 15), Vector2(TILE, 1)), _c.dark)
			draw_rect(Rect2(o + Vector2((off + 4) % 16, 0), Vector2(1, 7)), _c.dark)
			draw_rect(Rect2(o + Vector2((off + 12) % 16, 8), Vector2(1, 7)), _c.dark)
			if (x * 3 + y * 7) % 11 == 0 and not open_top:
				draw_rect(Rect2(o + Vector2(4, 3), Vector2(8, 9)), Color("fedd86") if (x + y) % 2 == 0 else Color("2b2f4a"))
		"metro":
			draw_rect(Rect2(o, Vector2(TILE, TILE)), _c.dark, false, 1.0)
			draw_rect(Rect2(o + Vector2(8, 0), Vector2(1, TILE)), _c.dark)
			draw_rect(Rect2(o + Vector2(0, 8), Vector2(TILE, 1)), _c.dark)
		"bunker":
			draw_rect(Rect2(o + Vector2(1, 1), Vector2(3, 3)), _c.light)
			draw_rect(Rect2(o + Vector2(12, 12), Vector2(2, 2)), _c.dark)
			draw_rect(Rect2(o + Vector2(0, 15), Vector2(TILE, 1)), _c.dark)
		"neon":
			if (x * 5 + y * 3) % 4 == 0:
				var win := Color("ff4fd8") if (x + y) % 3 == 0 else Color("3ef0ff")
				win.a = 0.5 + 0.3 * sin(_t * 2.0 + x)
				draw_rect(Rect2(o + Vector2(4, 4), Vector2(4, 6)), win)
		"space":
			draw_rect(Rect2(o, Vector2(TILE, TILE)), _c.dark, false, 1.0)
			draw_rect(Rect2(o + Vector2(2, 2), Vector2(2, 2)), _c.dark)
			draw_rect(Rect2(o + Vector2(12, 12), Vector2(2, 2)), _c.dark)
	if open_top:
		match theme:
			"bunker":
				for i in 4:
					draw_rect(Rect2(o + Vector2(i * 4, 0), Vector2(2, 3)), _c.top)
					draw_rect(Rect2(o + Vector2(i * 4 + 2, 0), Vector2(2, 3)), Color.BLACK)
			"neon", "space":
				var glow: Color = _c.top
				glow.a = 0.75 + 0.25 * sin(_t * 3.0 + x * 0.5)
				draw_rect(Rect2(o, Vector2(TILE, 2)), glow)
			_:
				draw_rect(Rect2(o, Vector2(TILE, 3)), _c.top)


func _draw_platform(x: int, _y: int, o: Vector2) -> void:
	match theme:
		"city":
			# toldo listrado
			draw_rect(Rect2(o, Vector2(TILE, 6)), _c.plat_a if x % 2 == 0 else _c.plat_b)
			draw_rect(Rect2(o + Vector2(0, 6), Vector2(TILE, 2)), Color("7f2707"))
			for i in 4:
				draw_rect(Rect2(o + Vector2(i * 4, 8), Vector2(2, 2)), _c.plat_a if x % 2 == 0 else _c.plat_b)
		"metro":
			# placa suspensa
			draw_rect(Rect2(o, Vector2(TILE, 10)), _c.plat_a)
			draw_rect(Rect2(o + Vector2(0, 0), Vector2(TILE, 2)), _c.plat_b)
			draw_rect(Rect2(o + Vector2(3, 5), Vector2(10, 1)), Color.WHITE)
			draw_rect(Rect2(o + Vector2(7, -16), Vector2(1, 16)), Color(0.2, 0.2, 0.25, 0.5))
		"bunker":
			draw_rect(Rect2(o, Vector2(TILE, 6)), _c.plat_a)
			for i in 4:
				draw_rect(Rect2(o + Vector2(i * 4 + 1, 1), Vector2(2, 4)), _c.plat_b)
		"neon":
			var glow: Color = _c.plat_a
			glow.a = 0.8 + 0.2 * sin(_t * 4.0 + x)
			draw_rect(Rect2(o, Vector2(TILE, 6)), _c.plat_b)
			draw_rect(Rect2(o, Vector2(TILE, 2)), glow)
			draw_rect(Rect2(o + Vector2(0, 5), Vector2(TILE, 1)), glow)
		"space":
			draw_rect(Rect2(o, Vector2(TILE, 6)), _c.plat_a)
			draw_rect(Rect2(o, Vector2(TILE, 1)), Color.WHITE)
			if x % 2 == 0:
				var l: Color = _c.plat_b
				l.a = 0.5 + 0.5 * sin(_t * 5.0 + x)
				draw_rect(Rect2(o + Vector2(6, 3), Vector2(4, 2)), l)


func _draw_spike(c: String, o: Vector2) -> void:
	for i in 2:
		var b := float(i * 8)
		var pts: PackedVector2Array
		match c:
			"^": pts = PackedVector2Array([o + Vector2(b, 16), o + Vector2(b + 4, 7), o + Vector2(b + 8, 16)])
			"v": pts = PackedVector2Array([o + Vector2(b, 0), o + Vector2(b + 4, 9), o + Vector2(b + 8, 0)])
			"<": pts = PackedVector2Array([o + Vector2(16, b), o + Vector2(7, b + 4), o + Vector2(16, b + 8)])
			">": pts = PackedVector2Array([o + Vector2(0, b), o + Vector2(9, b + 4), o + Vector2(0, b + 8)])
		draw_colored_polygon(pts, SPIKE)
		draw_polyline(pts, SPIKE_DARK, 1.0)


func _draw_sign(o: Vector2) -> void:
	draw_rect(Rect2(o + Vector2(7, 8), Vector2(2, 8)), Color("6b3d1a"))
	draw_rect(Rect2(o + Vector2(1, 1), Vector2(14, 9)), Color("6b3d1a"))
	draw_rect(Rect2(o + Vector2(2, 2), Vector2(12, 7)), UiStyle.YELLOW)
	var q := Color("7f2707")
	draw_rect(Rect2(o + Vector2(6, 3), Vector2(4, 1)), q)
	draw_rect(Rect2(o + Vector2(9, 4), Vector2(1, 1)), q)
	draw_rect(Rect2(o + Vector2(8, 5), Vector2(1, 1)), q)
	draw_rect(Rect2(o + Vector2(7, 5), Vector2(1, 2)), q)
	draw_rect(Rect2(o + Vector2(7, 8), Vector2(1, 1)), q)
