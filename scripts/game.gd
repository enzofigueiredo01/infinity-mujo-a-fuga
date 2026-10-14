extends Node2D
## Controla uma fase da fuga: monta o cenário, mostra o mapa inteiro com a
## câmera e aplica as regras.
##
## O homem é imortal: espinhos, lasers, carros e o trem só o empurram.
## Só o toque do caramujo acaba com ele (a fase recomeça).
## Para vencer, chegue à saída (helicóptero, porta, elevador, carro voador, cápsula).

const VIEW := Vector2(1280, 720)
## Uma faixa da trilha sonora para cada cenário (assets/music).
const MUSIC := {"city": "fase1_cidade", "metro": "fase2_metro", "bunker": "fase3_bunker",
	"neon": "fase4_neon", "space": "fase5_espaco"}

var data: Dictionary
var level: LevelMap
var nav: SnailNav
var player: Player
var snail: Snail
var exit_goal: Hazards.ExitGoal
var lasers: Array[Laser] = []
var cars: Array = []
var trains: Array = []
var fans: Array = []
var pads: Array = []
var coins: Array = []
var fx: Fx
var camera: Camera2D
var hud: Hud

var state := "intro"
var level_time := 0.0
var _fit_zoom := Vector2.ONE
var _map_center := Vector2.ZERO
var _shake := 0.0
var _reveal_tween: Tween
var _signs := {}


func _ready() -> void:
	data = LevelData.LEVELS[GameState.current_level]
	GameState.play_music(MUSIC.get(data.theme, ""))
	_build_level()
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	if GameState.current_level == 0 and not GameState.story_seen:
		GameState.story_seen = true
		hud.show_story(LevelData.INTRO_STORY, _start_reveal)
	elif data.intro != "" and not hud.skip_intro:
		GameState.play_sfx("unlock")
		hud.show_story(data.intro, _start_reveal)
	else:
		_start_reveal()


# ---------------------------------------------------------------- montagem

func _build_level() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var bg := SceneryBackground.new()
	bg_layer.add_child(bg)
	bg.setup(data.theme, bg_layer)

	level = LevelMap.new()
	add_child(level)
	level.build(data.map, data.theme)

	for i in level.laser_cells.size():
		var laser := Laser.new()
		laser.setup(level.laser_cells[i], level, i * 0.85)
		add_child(laser)
		lasers.append(laser)
	for cell in level.car_lanes:
		var lane := Hazards.CarLane.new()
		lane.setup(cell, level)
		add_child(lane)
		cars.append(lane)
	for cell in level.train_lanes:
		var train := Hazards.Train.new()
		train.setup(cell, level)
		add_child(train)
		trains.append(train)
	for cell in level.fan_cells:
		var fan := Hazards.Fan.new()
		fan.setup(cell, level)
		add_child(fan)
		fans.append(fan)
	for cell in level.bounce_cells:
		var pad := Hazards.BouncePad.new()
		pad.setup(cell)
		add_child(pad)
		pads.append(pad)
	for pos in level.coin_spawns:
		var coin := Hazards.Coin.new()
		coin.position = pos
		add_child(coin)
		coins.append(coin)
	for cell in level.sign_cells:
		var key := "%d,%d" % [cell.x, cell.y]
		if data.signs.has(key):
			_signs[cell] = data.signs[key]

	exit_goal = Hazards.ExitGoal.new()
	exit_goal.kind = data.theme
	exit_goal.position = level.exit_pos
	add_child(exit_goal)

	nav = SnailNav.new()
	nav.build(level, 1.0 / sqrt(data.gravity))

	player = Player.new()
	player.abilities = data.abilities
	player.gravity_scale = data.gravity
	add_child(player)
	player.reset_to(_player_spawn())

	snail = Snail.new()
	snail.nav = nav
	snail.target = player
	snail.speed = data.snail_speed
	snail.delay = data.snail_delay
	add_child(snail)
	snail.setup(level.snail_spawn)

	fx = Fx.new()
	add_child(fx)

	# câmera enquadrando o mapa inteiro da fase
	camera = Camera2D.new()
	add_child(camera)
	var size := level.pixel_size()
	_map_center = size / 2.0
	var z := minf(VIEW.x / size.x, VIEW.y / size.y)
	if z >= 1.0:
		z = floorf(z)
	_fit_zoom = Vector2(z, z)
	camera.position = _map_center
	camera.zoom = _fit_zoom
	camera.make_current()


func _player_spawn() -> Vector2:
	return level.player_spawn + Vector2(0, LevelMap.TILE / 2.0 - Player.HALF.y)


# ---------------------------------------------------------------- fluxo

func _start_reveal() -> void:
	state = "reveal"
	player.frozen = true
	var skills := "Habilidades: " + ", ".join(hud.ability_names(data.abilities))
	hud.show_banner("Fase %d / %d" % [GameState.current_level + 1, GameState.LEVEL_COUNT], data.name,
		"Fuja até: %s     %s" % [data.exit_name, skills])
	# começa mostrando o caramujo, passa pelo homem e abre o mapa todo
	camera.position = snail.position
	camera.zoom = _fit_zoom * 3.0
	_reveal_tween = create_tween()
	_reveal_tween.tween_interval(0.9)
	_reveal_tween.tween_property(camera, "position", player.position, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_reveal_tween.tween_property(camera, "position", _map_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_reveal_tween.parallel().tween_property(camera, "zoom", _fit_zoom, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_reveal_tween.tween_callback(_begin_play)


func _skip_reveal() -> void:
	if _reveal_tween and _reveal_tween.is_running():
		_reveal_tween.kill()
	camera.position = _map_center
	camera.zoom = _fit_zoom
	_begin_play()


func _begin_play() -> void:
	if state == "play":
		return
	state = "play"
	player.frozen = false
	snail.running = true
	hud.hide_banner()


func restart_level(skip_intro := true) -> void:
	get_tree().paused = false
	Hud.restart_skips_intro = skip_intro
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if state == "reveal" and (event.is_action_pressed("jump") or event.is_action_pressed("ui_accept")):
		_skip_reveal()
		get_viewport().set_input_as_handled()
	elif state == "play" and event.is_action_pressed("pause"):
		hud.open_pause()
		get_viewport().set_input_as_handled()
	elif state == "play" and event.is_action_pressed("restart"):
		restart_level()


func _physics_process(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 20.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	if state != "play":
		return
	level_time += delta
	var hb := player.hurtbox()

	# o único perigo de verdade
	if snail.hitbox().intersects(hb):
		_caught()
		return

	# obstáculos: o homem é imortal, só é empurrado
	if not player.is_invulnerable():
		var spike := level.spike_hit(hb)
		if spike != Vector2.ZERO:
			_hit(Vector2(-player.facing * 0.6, spike.y) if spike.y != 0.0 else spike, 1.0)
		for laser in lasers:
			if laser.state() == "on" and laser.hurt_rect().intersects(hb):
				_hit(Vector2(signf(player.global_position.x - laser.global_position.x), 0), 1.0)
		for lane in cars:
			for r in lane.hurt_rects():
				if r.intersects(hb):
					_hit(Vector2.LEFT, 1.3)
		for train in trains:
			for r in train.hurt_rects():
				if r.intersects(hb):
					_hit(Vector2.RIGHT, 1.6)

	player.in_wind = false
	for fan in fans:
		if fan.wind_rect().has_point(player.global_position):
			player.in_wind = true
	var feet := Rect2(player.global_position + Vector2(-5, Player.HALF.y - 3), Vector2(10, 4))
	for pad in pads:
		if player.velocity.y >= 0.0 and pad.trigger_rect().intersects(feet):
			player.bounce()
			pad.fire()

	for coin in coins:
		if not coin.collected and coin.pick_rect().intersects(hb):
			coin.collect()
			fx.burst(coin.global_position, [Color("fedd86"), Color("e5cd32")], 8, 60.0)

	if exit_goal.goal_rect().intersects(hb):
		_win()
		return

	var hint := ""
	for cell in _signs:
		var sign_pos := Vector2(cell.x * LevelMap.TILE + 8, cell.y * LevelMap.TILE + 8)
		if sign_pos.distance_to(player.global_position) < 40.0:
			hint = _signs[cell]
	hud.set_hint(hint)
	if player.is_dashing():
		fx.dust(player.global_position, Color(1, 0.87, 0.53, 0.8))


func _hit(dir: Vector2, strength: float) -> void:
	if player.is_invulnerable():
		return
	player.knockback(dir, strength)
	fx.burst(player.global_position, [Color.WHITE, Color("fedd86")], 10, 80.0)
	fx.popup(player.global_position + Vector2(0, -20), "Ai!")
	_shake = 4.0


## O caramujo encostou: fim da imortalidade. A fase recomeça.
func _caught() -> void:
	state = "caught"
	GameState.caught += 1
	player.frozen = true
	player.caught = true
	snail.running = false
	GameState.play_sfx("caught")
	GameState.set_music_duck(14.0, 0.3)
	fx.burst(player.global_position, [Color("e5cd32"), Color("fedd86"), Color("bff5e8")], 26, 130.0)
	_shake = 6.0
	var tw := create_tween()
	tw.tween_property(camera, "position", snail.position, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(camera, "zoom", _fit_zoom * 3.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hud.show_caught()
	await get_tree().create_timer(2.0).timeout
	restart_level()


func _win() -> void:
	state = "win"
	player.frozen = true
	snail.running = false
	hud.set_hint("")
	for coin in coins:
		if coin.collected:
			GameState.coins += 1
	GameState.play_sfx("win")
	player.visible = false
	fx.burst(exit_goal.global_position, [Color("fedd86"), Color("fb7f5a"), Color("bff5e8")], 30, 120.0)
	var tw := create_tween()
	tw.tween_property(camera, "position", exit_goal.position, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(camera, "zoom", _fit_zoom * 2.5, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# a saída "vai embora" com o homem dentro
	tw.tween_property(exit_goal, "position:y", exit_goal.position.y - 400.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	var last := GameState.current_level + 1 >= GameState.LEVEL_COUNT
	hud.show_story(data.outro, _on_outro_done if not last else hud.show_final)


func _on_outro_done() -> void:
	GameState.current_level += 1
	Hud.restart_skips_intro = false
	get_tree().reload_current_scene()


func coins_text() -> String:
	var got := 0
	for coin in coins:
		if coin.collected:
			got += 1
	return "%d/%d" % [got, coins.size()]
