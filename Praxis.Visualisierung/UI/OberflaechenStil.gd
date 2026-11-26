extends RefCounted
## Gemeinsame Darstellung; keine Aenderung an Rollen oder Simulationsablaeufen.

static func flaeche(farbe: String, rand: String = "#d6e2eb") -> StyleBoxFlat:
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color(farbe)
	stil.border_color = Color(rand)
	stil.set_border_width_all(1)
	stil.set_corner_radius_all(9)
	stil.content_margin_left = 14
	stil.content_margin_right = 14
	stil.content_margin_top = 9
	stil.content_margin_bottom = 9
	return stil

static func erstellen() -> Theme:
	var thema := Theme.new()
	thema.default_font_size = 15
	thema.set_color("font_color", "Label", Color("#203c50"))
	for typ in ["Button", "OptionButton"]:
		thema.set_stylebox("normal", typ, flaeche("#ffffff"))
		thema.set_stylebox("hover", typ, flaeche("#e8f3f6", "#85b9c7"))
		thema.set_stylebox("pressed", typ, flaeche("#d7eaf0", "#5093a5"))
		thema.set_stylebox("disabled", typ, flaeche("#e9eef2", "#dce4ea"))
		var fokus := flaeche("#ffffff00", "#167c91")
		fokus.set_border_width_all(2)
		thema.set_stylebox("focus", typ, fokus)
		for zustand in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			thema.set_color(zustand, typ, Color("#24465c"))
		thema.set_color("font_disabled_color", typ, Color("#8b9ca9"))
	thema.set_stylebox("normal", "LineEdit", flaeche("#ffffff"))
	thema.set_stylebox("focus", "LineEdit", flaeche("#ffffff", "#167c91"))
	thema.set_color("font_color", "LineEdit", Color("#203c50"))
	thema.set_color("caret_color", "LineEdit", Color("#167c91"))
	thema.set_color("selection_color", "LineEdit", Color("#b7dce5"))
	thema.set_stylebox("panel", "PopupMenu", flaeche("#ffffff"))
	thema.set_stylebox("hover", "PopupMenu", flaeche("#e8f3f6"))
	thema.set_color("font_color", "PopupMenu", Color("#203c50"))
	thema.set_color("font_hover_color", "PopupMenu", Color("#167c91"))
	var dialog := flaeche("#f4f8fb")
	dialog.set_content_margin_all(20)
	thema.set_stylebox("panel", "AcceptDialog", dialog)
	return thema

static func primaer(button: Button) -> void:
	button.add_theme_stylebox_override("normal", flaeche("#167c91", "#167c91"))
	button.add_theme_stylebox_override("hover", flaeche("#2095aa", "#2095aa"))
	button.add_theme_stylebox_override("pressed", flaeche("#105f72", "#105f72"))
	for zustand in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(zustand, Color.WHITE)
