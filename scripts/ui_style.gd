class_name UiStyle
extends RefCounted
## Paleta e estilos de botões usados nas telas (baseados no projeto de UI/UX).

const NAVY := Color("0b1041")
const NAVY_LIGHT := Color("1d2463")
const YELLOW := Color("fedd86")
const ORANGE := Color("fb7f5a")
const BROWN := Color("7f2707")
const MINT := Color("bff5e8")
const GOLD := Color("e5cd32")


static func box(bg: Color, border := Color.TRANSPARENT, border_width := 0, shadow := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	if shadow > 0:
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 0
		sb.shadow_offset = Vector2(shadow, shadow)
	return sb


static func style_button(button: Button, font_size := 32) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_stylebox_override("normal", box(ORANGE, GOLD, 3, 6))
	button.add_theme_stylebox_override("hover", box(BROWN, YELLOW, 3, 6))
	button.add_theme_stylebox_override("focus", box(BROWN, YELLOW, 3, 6))
	button.add_theme_stylebox_override("pressed", box(NAVY, YELLOW, 3, 2))
	button.add_theme_color_override("font_color", NAVY)
	button.add_theme_color_override("font_hover_color", YELLOW)
	button.add_theme_color_override("font_focus_color", YELLOW)
	button.add_theme_color_override("font_pressed_color", YELLOW)
	button.focus_entered.connect(func(): GameState.play_sfx("select"))
	button.mouse_entered.connect(func(): button.grab_focus())


static func panel() -> StyleBoxFlat:
	var sb := box(Color(NAVY, 0.92), YELLOW, 3, 8)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	return sb
