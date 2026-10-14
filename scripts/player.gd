class_name Player
extends CharacterBody2D
## O bilionário imortal em fuga. Corre e pula; a cada fase compra uma
## nova habilidade: dash (tênis turbo), pulo duplo (jetpack) e planar
## (guarda-chuva). Obstáculos não o matam: só o empurram e o atordoam.

const HALF := Vector2(5, 11)
const RUN_SPEED := 110.0
const GROUND_ACCEL := 1000.0
const AIR_ACCEL := 800.0
const GROUND_FRICTION := 1300.0
const GRAVITY := 900.0
const FALL_GRAVITY := 1100.0
const MAX_FALL := 320.0
const JUMP_VELOCITY := -330.0
const DOUBLE_JUMP_VELOCITY := -300.0
const JUMP_CUT := 0.45
const DASH_SPEED := 300.0
const DASH_TIME := 0.15
const GLIDE_FALL := 50.0
const FAN_LIFT := -130.0
const BOUNCE_VELOCITY := -560.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
const STUN_TIME := 0.45
const INVULNERABLE_TIME := 1.1

var abilities: Array = []
var gravity_scale := 1.0
var frozen := true
var caught := false

var facing := 1
var dash_ready := true
var can_double := true
var gliding := false
var in_wind := false

var _coyote := 0.0
var _jump_buffer := 0.0
var _jump_cut_done := true
var _dash_timer := 0.0
var _dash_dir := Vector2.ZERO
var _stun := 0.0
var _invulnerable := 0.0
var _was_on_floor := false
var _anim_t := 0.0
var _squash := Vector2.ONE
var _ghosts: Array = []


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = HALF * 2.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 4.0


func has(ability: String) -> bool:
	return ability in abilities


func reset_to(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	facing = 1
	dash_ready = true
	can_double = true
	gliding = false
	caught = false
	visible = true
	_dash_timer = 0.0
	_stun = 0.0
	_invulnerable = 0.0
	_ghosts.clear()


func hurtbox() -> Rect2:
	return Rect2(global_position - HALF + Vector2(1, 2), HALF * 2.0 - Vector2(2, 3))


func is_dashing() -> bool:
	return _dash_timer > 0.0


func is_invulnerable() -> bool:
	return _invulnerable > 0.0


## Obstáculo acertou: o homem imortal é arremessado e fica tonto um instante.
func knockback(dir: Vector2, strength := 1.0) -> void:
	if _invulnerable > 0.0:
		return
	var push := Vector2(dir.x * 180.0, -260.0) * strength
	if dir.y > 0.5:
		push.y = 120.0  # espinho do teto empurra para baixo
	if absf(dir.x) < 0.1:
		push.x = -facing * 90.0 * strength
	velocity = push
	_stun = STUN_TIME
	_invulnerable = INVULNERABLE_TIME
	_dash_timer = 0.0
	gliding = false
	_squash = Vector2(0.7, 1.3)
	GameState.play_sfx("hit")


func bounce() -> void:
	velocity.y = BOUNCE_VELOCITY * sqrt(gravity_scale)
	can_double = true
	dash_ready = true
	_jump_cut_done = true
	_squash = Vector2(0.6, 1.5)
	GameState.play_sfx("bounce")


func _physics_process(delta: float) -> void:
	_anim_t += delta
	_squash = _squash.lerp(Vector2.ONE, min(1.0, delta * 12.0))
	for gh in _ghosts:
		gh[1] += delta
	while not _ghosts.is_empty() and _ghosts[0][1] > 0.25:
		_ghosts.pop_front()
	_invulnerable = max(0.0, _invulnerable - delta)
	queue_redraw()
	if frozen:
		return

	var ix := Input.get_axis("move_left", "move_right")
	var iy := Input.get_axis("move_up", "move_down")
	ix = 0.0 if absf(ix) < 0.3 else signf(ix)
	iy = 0.0 if absf(iy) < 0.3 else signf(iy)
	_coyote = max(0.0, _coyote - delta)
	_jump_buffer = max(0.0, _jump_buffer - delta)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER

	var on_floor := is_on_floor()
	if on_floor:
		_coyote = COYOTE_TIME
		can_double = true
		gliding = false
		if _dash_timer <= 0.0:
			dash_ready = true

	if _stun > 0.0:
		_stun -= delta
		velocity.y = min(velocity.y + GRAVITY * gravity_scale * delta, MAX_FALL)
		velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
		move_and_slide()
		return

	# dash (tênis turbo de ouro)
	if has("dash") and Input.is_action_just_pressed("dash") and dash_ready and _dash_timer <= 0.0:
		var dir := Vector2(ix, iy)
		if dir == Vector2.ZERO:
			dir = Vector2(facing, 0)
		_dash_dir = dir.normalized()
		_dash_timer = DASH_TIME
		dash_ready = false
		gliding = false
		_squash = Vector2(1.3, 0.75)
		GameState.play_sfx("dash")
	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = _dash_dir * DASH_SPEED
		move_and_slide()
		_ghosts.append([global_position, 0.0, facing])
		if _dash_timer <= 0.0:
			velocity *= 0.55
			_jump_cut_done = true
		return

	if ix != 0.0:
		facing = int(ix)
	var target := ix * RUN_SPEED
	if on_floor:
		velocity.x = move_toward(velocity.x, target, (GROUND_ACCEL if ix != 0.0 else GROUND_FRICTION) * delta)
	elif absf(velocity.x) > RUN_SPEED and signf(velocity.x) == signf(target):
		velocity.x = move_toward(velocity.x, target, 150.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, target, AIR_ACCEL * delta)

	# pulo, pulo duplo (jetpack de bolso)
	if _jump_buffer > 0.0:
		if on_floor or _coyote > 0.0:
			_jump(JUMP_VELOCITY, 1.0)
		elif has("double") and can_double:
			can_double = false
			_jump(DOUBLE_JUMP_VELOCITY, 1.3)
	if not Input.is_action_pressed("jump") and velocity.y < 0.0 and not _jump_cut_done:
		velocity.y *= JUMP_CUT
		_jump_cut_done = true

	# planar (guarda-chuva): segurar pulo caindo
	gliding = has("glide") and not on_floor and velocity.y > -20.0 and Input.is_action_pressed("jump") and _jump_buffer <= 0.0
	var g := (FALL_GRAVITY if velocity.y > 0.0 else GRAVITY) * gravity_scale
	if in_wind:
		if gliding:
			velocity.y = move_toward(velocity.y, FAN_LIFT, 700.0 * delta)
		else:
			velocity.y = min(velocity.y + g * 0.35 * delta, MAX_FALL)
	elif gliding:
		velocity.y = min(velocity.y + g * delta, GLIDE_FALL)
	else:
		velocity.y = min(velocity.y + g * delta, MAX_FALL * (0.75 if gravity_scale < 1.0 else 1.0))

	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		_squash = Vector2(1.3, 0.75)
		GameState.play_sfx("land", randf_range(0.9, 1.1))
	_was_on_floor = is_on_floor()


func _jump(v: float, pitch: float) -> void:
	velocity.y = v  # com gravidade baixa o mesmo impulso leva muito mais alto
	_jump_buffer = 0.0
	_coyote = 0.0
	_jump_cut_done = false
	_squash = Vector2(0.75, 1.3)
	GameState.play_sfx("jump", pitch)


# ---------------------------------------------------------------- visual

func _draw() -> void:
	if not visible:
		return
	for gh in _ghosts:
		var a: float = 0.45 * (1.0 - gh[1] / 0.25)
		draw_set_transform(gh[0] - global_position, 0.0, Vector2(gh[2], 1))
		draw_rect(Rect2(-5, -11, 10, 22), Color(1, 0.87, 0.53, a))
	if _invulnerable > 0.0 and int(_anim_t * 20.0) % 2 == 0:
		return
	draw_set_transform(Vector2(0, 11 * (1.0 - _squash.y)), 0.0, Vector2(facing, 1) * _squash)
	_draw_man()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_man() -> void:
	var suit := Color("1d2463")
	var skin := Color("f2c39b")
	var gold := Color("e5cd32")
	var running := absf(velocity.x) > 10.0 and is_on_floor()
	var step := sin(_anim_t * 16.0) * 3.0 if running else 0.0
	var air := not is_on_floor()
	# pernas
	if air:
		draw_rect(Rect2(-4, 4, 3, 5), suit)
		draw_rect(Rect2(1, 2, 3, 5), suit)
	else:
		draw_rect(Rect2(-4 + step * 0.4, 4, 3, 7), suit)
		draw_rect(Rect2(1 - step * 0.4, 4, 3, 7), suit)
	# sapatos (tênis turbo dourados a partir da fase 2)
	var shoe := gold if has("dash") else Color.BLACK
	draw_rect(Rect2(-5 + step * 0.4, 10, 4, 1), shoe)
	draw_rect(Rect2(1 - step * 0.4, 10, 4, 1), shoe)
	# jetpack de bolso nas costas
	if has("double"):
		draw_rect(Rect2(-8, -5, 3, 8), Color("8fa3c0"))
		if air and not can_double:
			draw_rect(Rect2(-8, 3, 3, 3 + absf(sin(_anim_t * 40.0)) * 3.0), Color("fb7f5a"))
	# terno, camisa e gravata
	draw_rect(Rect2(-5, -6, 10, 11), suit)
	draw_rect(Rect2(-1, -6, 2, 6), Color.WHITE)
	draw_rect(Rect2(-0.5, -5, 1, 5), gold)
	# braço balançando
	draw_rect(Rect2(2 - step * 0.5, -4, 2, 7), suit)
	# cabeça e cartola
	draw_rect(Rect2(-3, -12, 6, 6), skin)
	draw_rect(Rect2(1, -10, 1, 1), Color.BLACK)
	draw_rect(Rect2(-4, -13, 8, 1), Color.BLACK)
	draw_rect(Rect2(-3, -18, 6, 5), Color.BLACK)
	draw_rect(Rect2(-3, -15, 6, 1), gold)
	# guarda-chuva planador aberto
	if gliding:
		var c := Color("ff4fd8")
		draw_line(Vector2(0, -14), Vector2(0, -26), Color("6b3d1a"), 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-12, -24), Vector2(0, -32), Vector2(12, -24)]), c)
		draw_rect(Rect2(-12, -25, 24, 2), c.darkened(0.3))
