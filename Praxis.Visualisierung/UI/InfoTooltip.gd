extends Button
## Kleines Info-Symbol mit einer lesbaren, mehrzeiligen Tooltip-Karte.

func _init() -> void:
	text = "ⓘ"
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(24, 24)
	add_theme_font_size_override("font_size", 16)
	add_theme_color_override("font_color", Color("#42677f"))
	add_theme_color_override("font_hover_color", Color("#174f75"))
	mouse_default_cursor_shape = Control.CURSOR_HELP

func erklaerung_setzen(erklaerung: String) -> void:
	tooltip_text = erklaerung

func _make_custom_tooltip(for_text: String) -> Object:
	var karte := PanelContainer.new()
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color("#f8fbfd")
	stil.border_color = Color("#3978a8")
	stil.set_border_width_all(1)
	stil.set_corner_radius_all(7)
	stil.set_content_margin_all(12)
	stil.shadow_color = Color(0.05, 0.12, 0.18, 0.25)
	stil.shadow_size = 5
	karte.add_theme_stylebox_override("panel", stil)
	var label := Label.new()
	label.text = for_text
	label.custom_minimum_size.x = 310
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("#18334a"))
	label.add_theme_constant_override("line_spacing", 4)
	karte.add_child(label)
	return karte
