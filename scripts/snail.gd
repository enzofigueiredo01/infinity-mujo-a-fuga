class_name Snail
extends Node2D
## O caramujo imortal e superinteligente. Lento, mas nunca para:
## calcula o caminho mais curto até o homem rastejando por chão, paredes
## e tetos, salta no casco entre plataformas e se solta do teto para cair
## em cima dele. Nada o machuca. Se encostar no homem, é o fim.

const REPLAN_TIME := 0.35
const DROP_GRAVITY := 900.0
const FAR_DISTANCE := 14.0 * 16.0  # longe demais: acelera com o muco
const RAMP_PER_SECOND := 0.5       # fica um pouco mais rápido a cada segundo da fase
const RAMP_MAX := 22.0
const LUNGE_RANGE := 5.0 * 16.0    # investida de muco quando está perto
const LUNGE_WARN := 0.45
const LUNGE_TIME := 0.7
const LUNGE_MULT := 2.6
const LUNGE_COOLDOWN := 3.5

var nav: SnailNav
var target: Player
var speed := 30.0
var delay := 2.0
var active := false
var running := false  # só anda quando a fase está em jogo

var node := -1
var _path: Array = []
var _edge_to := -1
var _edge_type := -1
var _from := Vector2.ZERO
var _k := 0.0
var _leap_time := 0.5
var _fall_v := 0.0
var _replan := 0.0
var _timer := 0.0
var _chase_t := 0.0
var _lunge_warn := 0.0
var _lunge := 0.0
var _lunge_cd := 2.0
var _alert := 0.0
var _anim_t := 0.0
var _rot := 0.0
var _facing := 1
var _flip := 1
var _trail: Array = []


func setup(start_center: Vector2) -> void:
	node = nav.node_near(start_center)
	position = _surface_pos(node)
	_rot = _angle_for(node)


func hitbox() -> Rect2:
	return Rect2(position - Vector2(6, 5), Vector2(12, 10))


func is_leaping() -> bool:
	return _edge_type == SnailNav.LEAP


func _surface_pos(n: int) -> Vector2:
	return SnailNav.center_of(nav.cells[n]) - nav.normals[n] * 3.0


func _angle_for(n: int) -> float:
	return nav.normals[n].angle() + PI / 2.0


func _process(delta: float) -> void:
	_anim_t += delta
	_alert = max(0.0, _alert - delta)
	queue_redraw()
	if not running or not is_instance_valid(target):
		return
	if not active:
		_timer += delta
		if _timer >= delay:
			active = true
			_alert = 1.2
			GameState.play_sfx("alert", 0.8)
		return

	_chase_t += delta
	var dist := position.distance_to(target.global_position)
	var spd := speed + minf(_chase_t * RAMP_PER_SECOND, RAMP_MAX)
	if dist > FAR_DISTANCE:
		spd *= 1.5
	# investida de muco: avisa (brilho) e dá um bote curto quando está perto
	_lunge_cd = max(0.0, _lunge_cd - delta)
	if _lunge_warn > 0.0:
		_lunge_warn -= delta
		if _lunge_warn <= 0.0:
			_lunge = LUNGE_TIME
			GameState.play_sfx("dash", 0.7)
		spd *= 0.3  # se encolhe antes do bote
	elif _lunge > 0.0:
		_lunge -= delta
		spd *= LUNGE_MULT
	elif _lunge_cd <= 0.0 and dist < LUNGE_RANGE:
		_lunge_warn = LUNGE_WARN
		_lunge_cd = LUNGE_COOLDOWN
		GameState.play_sfx("shell", 0.6)

	if _edge_to == -1:
		_replan -= delta
		if _replan <= 0.0 or _path.is_empty():
			_replan = REPLAN_TIME
			var goal := nav.node_near(target.global_position + Vector2(0, 6))
			_path = nav.find_path(node, goal)
		if _path.is_empty():
			return
		var step: Array = _path.pop_front()
		_edge_to = step[0]
		_edge_type = step[1]
		_from = position
		_k = 0.0
		_fall_v = 0.0
		if _edge_type == SnailNav.LEAP:
			_leap_time = 0.3 + _from.distance_to(_surface_pos(_edge_to)) / 160.0
			GameState.play_sfx("shell", 1.3)

	var to := _surface_pos(_edge_to)
	match _edge_type:
		SnailNav.CRAWL:
			position = position.move_toward(to, spd * delta)
			_rot = lerp_angle(_rot, _angle_for(_edge_to), min(1.0, delta * 10.0))
			_leave_trail()
			if position.distance_to(to) < 0.5:
				_arrive()
		SnailNav.DROP:
			_fall_v = min(_fall_v + DROP_GRAVITY * delta, 420.0)
			position = position.move_toward(to, _fall_v * delta)
			_rot += delta * 12.0
			if position.distance_to(to) < 0.5:
				_arrive()
		SnailNav.LEAP:
			_k = min(1.0, _k + delta / _leap_time)
			var h := SnailNav.arc_height(nav.cells[node], nav.cells[_edge_to])
			position = SnailNav.arc_point(_from, to, h, _k)
			_rot += delta * 14.0 * signf(to.x - _from.x)
			if _k >= 1.0:
				_arrive()
	# vira a cabeça para o lado em que está andando sobre a superfície
	var move := to - position
	if move.length() > 0.1 and _edge_type == SnailNav.CRAWL:
		var local_x := Vector2(cos(_rot), sin(_rot))
		_flip = 1 if move.dot(local_x) >= 0.0 else -1


func _arrive() -> void:
	node = _edge_to
	position = _surface_pos(node)
	if _edge_type != SnailNav.CRAWL:
		_rot = _angle_for(node)
		GameState.play_sfx("land", 0.6)
	_edge_to = -1
	_edge_type = -1


func _leave_trail() -> void:
	if _trail.is_empty() or (_trail[_trail.size() - 1][0] as Vector2).distance_to(position) > 3.0:
		_trail.append([position + nav.normals[node] * -2.0, _anim_t])
		if _trail.size() > 120:
			_trail.pop_front()


# ---------------------------------------------------------------- visual

func _draw() -> void:
	for t in _trail:
		var age: float = _anim_t - t[1]
		if age < 5.0:
			draw_rect(Rect2(t[0] - position - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.75, 0.96, 0.91, 0.7 * (1.0 - age / 5.0)))
	if _edge_type == SnailNav.LEAP or _edge_type == SnailNav.DROP:
		_draw_shell(_rot)
	else:
		# o desenho "em pé" é girado para grudar em paredes e tetos
		draw_set_transform(Vector2.ZERO, _rot, Vector2(_flip, 1))
		_draw_snail()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _lunge_warn > 0.0 or _lunge > 0.0:
		# brilho de muco avisando o bote
		var a := 0.5 + 0.5 * sin(_anim_t * 40.0) if _lunge_warn > 0.0 else 0.35
		draw_circle(Vector2.ZERO, 11.0, Color(0.75, 0.96, 0.91, a * 0.5))
	if not active:
		# dormindo antes de começar a perseguição
		var z := Color(1, 1, 1, 0.8)
		draw_rect(Rect2(6, -16 - fmod(_anim_t * 6.0, 6.0), 4, 1), z)
		draw_rect(Rect2(9, -15 - fmod(_anim_t * 6.0, 6.0), 1, 1), z)
		draw_rect(Rect2(6, -14 - fmod(_anim_t * 6.0, 6.0), 4, 1), z)
	elif _alert > 0.0:
		var red := Color("ff3b6b")
		draw_rect(Rect2(-2, -26, 4, 8), red)
		draw_rect(Rect2(-2, -16, 4, 3), red)


func _draw_snail() -> void:
	var body := Color("f2a65a")
	var body_dark := Color("c46f2c")
	var shell := Color("f07a2a")
	var shell_dark := Color("9c3416")
	var crawl := sin(_anim_t * 10.0)
	draw_rect(Rect2(-9, 1, 18, 4), body)
	draw_rect(Rect2(-9, 4, 18, 1), body_dark)
	draw_rect(Rect2(4 + crawl * 0.5, -4, 5, 7), body)
	draw_rect(Rect2(5, -9, 1, 5), body_dark)
	draw_rect(Rect2(8, -8 + crawl * 0.5, 1, 4), body_dark)
	draw_rect(Rect2(4, -10, 2, 2), Color("2b1a10"))
	draw_rect(Rect2(7, -9 + crawl * 0.5, 2, 2), Color("2b1a10"))
	draw_rect(Rect2(7, -2, 1, 1), Color("2b1a10"))
	draw_circle(Vector2(-2, -2), 7.0, shell_dark)
	draw_circle(Vector2(-2, -2), 6.0, shell)
	draw_arc(Vector2(-2, -2), 3.5, 0.0, TAU * 0.8, 10, shell_dark, 1.3)
	draw_circle(Vector2(-2, -2), 1.3, shell_dark)
	draw_rect(Rect2(-6, -6, 2, 1), Color("ffc06b"))


func _draw_shell(angle: float) -> void:
	draw_circle(Vector2.ZERO, 7.0, Color("9c3416"))
	draw_circle(Vector2.ZERO, 6.0, Color("f07a2a"))
	draw_arc(Vector2.ZERO, 3.5, angle, angle + TAU * 0.8, 10, Color("9c3416"), 1.3)
	draw_circle(Vector2(cos(angle), sin(angle)) * 1.3, 1.3, Color("9c3416"))
