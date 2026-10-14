class_name SnailNav
extends RefCounted
## Grafo de navegação do caramujo imortal.
## Ele rasteja por QUALQUER superfície (chão, paredes e tetos), então os nós
## são as células vazias encostadas em algum bloco. As arestas são:
##  - CRAWL: rastejar para uma célula vizinha (contornando quinas)
##  - DROP:  soltar-se e cair em linha reta até o chão (ex.: do teto)
##  - LEAP:  salto no casco entre bordas de plataformas
## O caminho é calculado com Dijkstra (fila de prioridade) até o homem.

enum { CRAWL, DROP, LEAP }

const TILE := 16
const LEAP_MAX_DX := 6
const LEAP_MAX_UP := 4
const LEAP_MAX_DOWN := 5

var level: LevelMap
var cells: Array[Vector2i] = []
var index := {}
var edges: Array = []      # por nó: Array de [to, type, cost]
var normals: Array[Vector2] = []  # direção "para fora" da superfície onde o caramujo gruda


func build(map: LevelMap, leap_boost := 1.0) -> void:
	level = map
	for y in level.rows:
		for x in level.cols:
			if _crawlable(x, y):
				index[Vector2i(x, y)] = cells.size()
				cells.append(Vector2i(x, y))
				normals.append(_normal_of(x, y))
	for i in cells.size():
		edges.append(_edges_for(cells[i], leap_boost))


func _free(x: int, y: int) -> bool:
	return not level.is_solid_cell(x, y)


func _crawlable(x: int, y: int) -> bool:
	if not _free(x, y):
		return false
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		if level.is_solid_cell(x + d.x, y + d.y):
			return true
	return false


func _normal_of(x: int, y: int) -> Vector2:
	if level.is_solid_cell(x, y + 1):
		return Vector2.UP
	if level.is_solid_cell(x, y - 1):
		return Vector2.DOWN
	if level.is_solid_cell(x - 1, y):
		return Vector2.RIGHT
	if level.is_solid_cell(x + 1, y):
		return Vector2.LEFT
	# só encosta numa quina (diagonal)
	for d in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		if level.is_solid_cell(x + d.x, y + d.y):
			return -Vector2(d).normalized()
	return Vector2.UP


func is_floor(c: Vector2i) -> bool:
	return level.is_solid_cell(c.x, c.y + 1)


func _edges_for(c: Vector2i, leap_boost: float) -> Array:
	var out: Array = []
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := c + d
		if index.has(n):
			out.append([index[n], CRAWL, 1.0])
	# soltar e cair (do teto, de paredes, de bordas)
	if _free(c.x, c.y + 1):
		var y := c.y + 1
		while y + 1 < level.rows and _free(c.x, y + 1):
			y += 1
		var landing := Vector2i(c.x, y)
		if y - c.y >= 2 and index.has(landing):
			out.append([index[landing], DROP, 1.0 + 0.15 * (y - c.y)])
	# salto no casco a partir da borda de uma plataforma
	if is_floor(c):
		var max_dx := int(LEAP_MAX_DX * leap_boost)
		for side: int in [-1, 1]:
			if index.has(c + Vector2i(side, 0)) and is_floor(c + Vector2i(side, 0)):
				continue  # não é borda nesse lado
			for dx in range(2, max_dx + 1):
				for dy in range(-int(LEAP_MAX_UP * leap_boost), LEAP_MAX_DOWN + 1):
					var t := Vector2i(c.x + side * dx, c.y + dy)
					if index.has(t) and is_floor(t) and _arc_clear(c, t):
						out.append([index[t], LEAP, 2.0 + 0.3 * (dx + absi(dy))])
	return out


static func center_of(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE / 2.0, c.y * TILE + TILE / 2.0)


## Altura do arco do salto entre duas células (em pixels).
static func arc_height(a: Vector2i, b: Vector2i) -> float:
	return 14.0 + maxf(0.0, (a.y - b.y) * TILE) + absi(b.x - a.x) * 2.0


static func arc_point(a: Vector2, b: Vector2, h: float, k: float) -> Vector2:
	var p := a.lerp(b, k)
	p.y -= h * 4.0 * k * (1.0 - k)
	return p


func _arc_clear(a: Vector2i, b: Vector2i) -> bool:
	var pa := center_of(a)
	var pb := center_of(b)
	var h := arc_height(a, b)
	for i in range(1, 20):
		var p := arc_point(pa, pb, h, i / 20.0)
		for off in [Vector2(-5, -4), Vector2(5, -4), Vector2(-5, 4), Vector2(5, 4)]:
			if level.is_solid_at(p + off):
				return false
	return true


## Nó mais próximo de uma posição (o homem pode estar no ar).
func node_near(pos: Vector2) -> int:
	var c := level.cell_at(pos)
	if index.has(c):
		return index[c]
	for dy in range(1, 6):
		if index.has(c + Vector2i(0, dy)):
			return index[c + Vector2i(0, dy)]
	var best := -1
	var best_d := INF
	for i in cells.size():
		var d := center_of(cells[i]).distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = i
	return best


## Dijkstra com fila de prioridade (heap binário).
func find_path(start: int, goal: int) -> Array:
	if start < 0 or goal < 0:
		return []
	var n := cells.size()
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var prev_type := PackedInt32Array()
	prev_type.resize(n)
	var heap: Array = [[0.0, start]]
	dist[start] = 0.0
	while not heap.is_empty():
		var top: Array = _heap_pop(heap)
		var u: int = top[1]
		if top[0] > dist[u]:
			continue
		if u == goal:
			break
		for e in edges[u]:
			var v: int = e[0]
			var nd: float = dist[u] + e[2]
			if nd < dist[v]:
				dist[v] = nd
				prev[v] = u
				prev_type[v] = e[1]
				_heap_push(heap, [nd, v])
	if dist[goal] == INF:
		return []
	var path: Array = []
	var cur := goal
	while cur != start and cur != -1:
		path.push_front([cur, prev_type[cur]])
		cur = prev[cur]
	return path


func _heap_push(h: Array, item: Array) -> void:
	h.append(item)
	var i := h.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if h[p][0] <= h[i][0]:
			break
		var tmp = h[p]
		h[p] = h[i]
		h[i] = tmp
		i = p


func _heap_pop(h: Array) -> Array:
	var top: Array = h[0]
	var last: Array = h.pop_back()
	if not h.is_empty():
		h[0] = last
		var i := 0
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < h.size() and h[l][0] < h[m][0]:
				m = l
			if r < h.size() and h[r][0] < h[m][0]:
				m = r
			if m == i:
				break
			var tmp = h[m]
			h[m] = h[i]
			h[i] = tmp
			i = m
	return top
