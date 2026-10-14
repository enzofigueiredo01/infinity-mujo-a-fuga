class_name Hud
extends CanvasLayer
## Interface da fuga: fase, habilidades, distância do caramujo, dicas,
## narrador (história / novas habilidades), pausa, captura e tela final.

## Ao recomeçar a mesma fase não repetimos o texto da nova habilidade.
static var restart_skips_intro := false

const ABILITY_NAMES := {"dash": "Dash (SHIFT)", "double": "Pulo duplo", "glide": "Planar"}

var game: Node
var skip_intro := false

var _level_label: Label
var _skills_label: Label
var _stats_label: Label
var _danger_label: Label
var _danger_bar: ColorRect
var _hint_panel: PanelContainer
var _hint_label: Label
var _banner: VBoxContainer
var _flash: ColorRect
var _story: Control
var _story_label: Label
var _story_hint: Label
var _story_text := ""
var _story_chars := 0.0
var _story_done: Callable
var _pause: Control
var _pause_first: Button


func setup(game_node: Node) -> void:
	game = game_node
	skip_intro = restart_skips_intro
	restart_skips_intro = false
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_top_bar()
	_build_hint()
	_build_banner()
	_flash = _full_rect(Color(1, 1, 1, 0))
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_build_story()
	_build_pause()


func ability_names(list: Array) -> Array:
	var out := ["correr", "pular"]
	for a in list:
		out.append(ABILITY_NAMES.get(a, a))
	return out


# ---------------------------------------------------------------- construção

func _full_rect(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	return r


func _label(text: String, size: int, color := Color.WHITE, outline := 6) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", UiStyle.NAVY)
	l.add_theme_constant_override("outline_size", outline)
	return l


func _build_top_bar() -> void:
	_level_label = _label("", 16, UiStyle.YELLOW)
	_level_label.position = Vector2(16, 6)
	add_child(_level_label)
	_skills_label = _label("", 16, UiStyle.MINT)
	_skills_label.position = Vector2(16, 26)
	add_child(_skills_label)

	# distância do caramujo: quanto mais perto, mais vermelho
	_danger_label = _label("", 16, Color.WHITE)
	_danger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_danger_label.position = Vector2(440, 6)
	_danger_label.size = Vector2(400, 20)
	add_child(_danger_label)
	var bar_bg := ColorRect.new()
	bar_bg.color = UiStyle.NAVY
	bar_bg.position = Vector2(490, 28)
	bar_bg.size = Vector2(300, 10)
	add_child(bar_bg)
	_danger_bar = ColorRect.new()
	_danger_bar.position = Vector2(492, 30)
	_danger_bar.size = Vector2(296, 6)
	add_child(_danger_bar)

	_stats_label = _label("", 16, Color.WHITE)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats_label.position = Vector2(1280 - 16 - 420, 6)
	_stats_label.size = Vector2(420, 24)
	add_child(_stats_label)


func _build_hint() -> void:
	_hint_panel = PanelContainer.new()
	var sb := UiStyle.panel()
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_hint_panel.add_theme_stylebox_override("panel", sb)
	_hint_panel.position = Vector2(190, 600)
	_hint_panel.custom_minimum_size = Vector2(900, 0)
	_hint_label = _label("", 16, Color.WHITE, 0)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_panel.add_child(_hint_label)
	_hint_panel.modulate.a = 0.0
	add_child(_hint_panel)


func _build_banner() -> void:
	_banner = VBoxContainer.new()
	_banner.position = Vector2(0, 200)
	_banner.size = Vector2(1280, 200)
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 3:
		var l := _label("", [32, 64, 16][i], [UiStyle.MINT, UiStyle.YELLOW, Color.WHITE][i], [8, 14, 6][i])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_banner.add_child(l)
	_banner.modulate.a = 0.0
	add_child(_banner)


func _build_story() -> void:
	_story = _full_rect(UiStyle.NAVY)
	_story.visible = false
	add_child(_story)
	_story_label = _label("", 32, Color.WHITE, 0)
	_story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_story_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_story_label.offset_bottom = -60
	_story.add_child(_story_label)
	_story_hint = _label("ESPAÇO para continuar", 16, UiStyle.YELLOW, 0)
	_story_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story_hint.position = Vector2(0, 660)
	_story_hint.size = Vector2(1280, 30)
	_story.add_child(_story_hint)


func _build_pause() -> void:
	_pause = _full_rect(Color(0, 0, 0, 0.6))
	_pause.visible = false
	add_child(_pause)
	var box := VBoxContainer.new()
	box.position = Vector2(440, 200)
	box.size = Vector2(400, 320)
	box.add_theme_constant_override("separation", 16)
	_pause.add_child(box)
	var title := _label("Pausado", 64, UiStyle.YELLOW, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_pause_first = _button(box, "Continuar", close_pause)
	_button(box, "Reiniciar fase", func(): game.restart_level())
	_button(box, "Menu principal", func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn"))


func _button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	UiStyle.style_button(b, 32)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


# ---------------------------------------------------------------- atualização

func _process(delta: float) -> void:
	if game and game.player:
		var p: Player = game.player
		_level_label.text = "FASE %d/%d  -  %s" % [GameState.current_level + 1, GameState.LEVEL_COUNT, game.data.name]
		var skills := ", ".join(ability_names(game.data.abilities))
		if p.has("dash"):
			skills += "   [dash %s]" % ("pronto" if p.dash_ready else "...")
		_skills_label.text = skills
		_stats_label.text = "Dinheiro %s     Capturas %d" % [game.coins_text(), GameState.caught]
		var dist: float = game.snail.position.distance_to(p.global_position) / 16.0
		var danger := clampf(1.0 - dist / 30.0, 0.0, 1.0)
		if not game.snail.active:
			_danger_label.text = "O CARAMUJO ESTÁ ACORDANDO..."
		else:
			_danger_label.text = "CARAMUJO A %d METROS" % int(dist)
		_danger_bar.size.x = 296.0 * danger
		_danger_bar.color = UiStyle.MINT.lerp(Color("ff3b6b"), danger)
		_danger_label.modulate.a = (0.55 + 0.45 * absf(sin(Time.get_ticks_msec() / 120.0))) if dist < 5.0 else 1.0

	if _story.visible:
		_story_chars += delta * 38.0
		_story_label.visible_characters = int(_story_chars)
		_story_hint.visible = _story_chars >= _story_text.length()
		_story_hint.modulate.a = 0.6 + sin(Time.get_ticks_msec() / 200.0) * 0.4


func _unhandled_input(event: InputEvent) -> void:
	if _story.visible and (event.is_action_pressed("jump") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		if _story_chars < _story_text.length():
			_story_chars = _story_text.length()
		else:
			_story.visible = false
			GameState.play_sfx("select")
			if _story_done.is_valid():
				_story_done.call()
	elif _pause.visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close_pause()


func set_hint(text: String) -> void:
	if text != "":
		_hint_label.text = text
	var target := 1.0 if text != "" else 0.0
	_hint_panel.modulate.a = move_toward(_hint_panel.modulate.a, target, 0.08)
	# a dica fica na metade da tela oposta ao homem
	var player_screen_y: float = game.player.get_global_transform_with_canvas().origin.y
	_hint_panel.position.y = 64.0 if player_screen_y > 360.0 else 690.0 - _hint_panel.size.y


func show_banner(top: String, title: String, sub: String) -> void:
	var labels := _banner.get_children()
	labels[0].text = top
	labels[1].text = title
	labels[2].text = sub
	create_tween().tween_property(_banner, "modulate:a", 1.0, 0.4)


func hide_banner() -> void:
	create_tween().tween_property(_banner, "modulate:a", 0.0, 0.5)


func show_story(text: String, on_done: Callable) -> void:
	_story_text = text
	_story_label.text = text
	_story_chars = 0.0
	_story_label.visible_characters = 0
	_story_done = on_done
	_story.visible = true
	_story.modulate.a = 0.0
	create_tween().tween_property(_story, "modulate:a", 1.0, 0.5)


func show_caught() -> void:
	_flash.color = Color(1, 0.36, 0.42, 0.45)
	create_tween().tween_property(_flash, "color:a", 0.0, 0.6)
	var box := VBoxContainer.new()
	box.position = Vector2(0, 250)
	box.size = Vector2(1280, 200)
	add_child(box)
	var t := _label("O caramujo te tocou!", 64, UiStyle.ORANGE, 14)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var s := _label("Fim da imortalidade... tente de novo.", 32, Color.WHITE, 8)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(s)
	box.modulate.a = 0.0
	create_tween().tween_property(box, "modulate:a", 1.0, 0.3)


func open_pause() -> void:
	_pause.visible = true
	get_tree().paused = true
	GameState.set_music_duck(8.0, 0.2)
	_pause_first.grab_focus()


func close_pause() -> void:
	_pause.visible = false
	get_tree().paused = false
	GameState.set_music_duck(0.0, 0.2)


func show_final() -> void:
	GameState.play_music("menu", 3.0)
	var final := _full_rect(UiStyle.NAVY)
	add_child(final)
	var cover := TextureRect.new()
	cover.texture = load("res://assets/images/title_cover.png")
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover.position = Vector2(90, 110)
	cover.size = Vector2(500, 500)
	final.add_child(cover)
	var box := VBoxContainer.new()
	box.position = Vector2(660, 150)
	box.size = Vector2(540, 420)
	box.add_theme_constant_override("separation", 18)
	final.add_child(box)
	box.add_child(_label("Você escapou... por enquanto!", 32, UiStyle.YELLOW, 12))
	box.add_child(_label("Capturas: %d" % GameState.caught, 32, Color.WHITE))
	box.add_child(_label("Dinheiro: %d" % GameState.coins, 32, UiStyle.MINT))
	box.add_child(_label("O caramujo é imortal.\nEle continua vindo, um milímetro por vez.", 16, Color.WHITE, 0))
	var again := _button(box, "Fugir de novo", func():
		GameState.new_game()
		get_tree().reload_current_scene())
	_button(box, "Menu principal", func(): get_tree().change_scene_to_file("res://scenes/title_screen.tscn"))
	again.grab_focus()
