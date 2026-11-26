extends RefCounted
## Bedienleiste ausserhalb der 3D-Ansicht; alle Aktionen bleiben bei Main.
const STIL = preload("res://UI/OberflaechenStil.gd")

static func bauen(haupt: Control) -> void:
	haupt.theme = STIL.erstellen()
	var hintergrund := ColorRect.new()
	hintergrund.color = Color("#edf3f7")
	hintergrund.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hintergrund.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hintergrund.z_index = -2
	haupt.add_child(hintergrund)
	var kopf := VBoxContainer.new()
	kopf.position = Vector2(24, 18)
	kopf.add_theme_constant_override("separation", 4)
	haupt.add_child(kopf)
	var titel := Label.new()
	titel.text = "Arztpraxis"
	titel.add_theme_font_size_override("font_size", 28)
	kopf.add_child(titel)
	var untertitel := Label.new()
	untertitel.text = "3D-Simulation  ·  Rechte Maustaste: drehen  ·  Mausrad: Zoom"
	untertitel.add_theme_font_size_override("font_size", 13)
	untertitel.add_theme_color_override("font_color", Color("#60778b"))
	kopf.add_child(untertitel)
	# Gemeinsame Zeile statt einzeln positionierter, ueberlappender Buttons.
	var werkzeuge := HBoxContainer.new()
	werkzeuge.position = Vector2(656, 30)
	werkzeuge.add_theme_constant_override("separation", 10)
	haupt.add_child(werkzeuge)
	haupt.modus_auswahl = OptionButton.new()
	haupt.modus_auswahl.custom_minimum_size = Vector2(250, 44)
	haupt.modus_auswahl.add_item("Offline · direkt in Godot")
	haupt.modus_auswahl.add_item("WebSocket · Server")
	haupt.modus_auswahl.tooltip_text = "Datenquelle der Simulation auswählen"
	haupt.modus_auswahl.item_selected.connect(haupt._modus_wechseln)
	werkzeuge.add_child(haupt.modus_auswahl)
	haupt.personal_button = _button("Personal einstellen", Vector2(190, 44))
	haupt.personal_button.tooltip_text = "Personalzahlen und manuelle Einsatzrollen für den nächsten Lauf einstellen"
	haupt.personal_button.pressed.connect(haupt._personal_oeffnen)
	werkzeuge.add_child(haupt.personal_button)
	var bau_schalter := _button("Baumodus", Vector2(142, 44))
	bau_schalter.tooltip_text = "Räume und Arbeitsplätze bearbeiten"
	bau_schalter.pressed.connect(haupt._baumodus_umschalten)
	werkzeuge.add_child(bau_schalter)
	# Rahmen fangen keine Mausereignisse ab; die 3D-Flaeche bleibt gleich gross.
	_karte(haupt, Rect2(20, 108, 1240, 514))
	_karte(haupt, Rect2(22, 634, 1236, 40))
	haupt.statistik_label = Label.new()
	haupt.statistik_label.position = Vector2(38, 642)
	haupt.statistik_label.add_theme_font_size_override("font_size", 14)
	haupt.add_child(haupt.statistik_label)
	var steuerung := HBoxContainer.new()
	steuerung.position = Vector2(22, 690)
	steuerung.size = Vector2(1236, 44)
	steuerung.add_theme_constant_override("separation", 12)
	haupt.add_child(steuerung)
	haupt.play_button = _button("Start", Vector2(100, 44))
	STIL.primaer(haupt.play_button)
	haupt.play_button.pressed.connect(haupt._start_pause)
	steuerung.add_child(haupt.play_button)
	haupt.reset_button = _button("Reset", Vector2(86, 44))
	haupt.reset_button.tooltip_text = "Aktuellen Simulationslauf zurücksetzen"
	haupt.reset_button.pressed.connect(haupt._reset_simulation)
	steuerung.add_child(haupt.reset_button)
	haupt.speed_label = Label.new()
	haupt.speed_label.text = "Geschwindigkeit: 1.00x"
	haupt.speed_label.custom_minimum_size = Vector2(170, 44)
	haupt.speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	haupt.speed_label.add_theme_font_size_override("font_size", 14)
	steuerung.add_child(haupt.speed_label)
	haupt.speed_slider = HSlider.new()
	haupt.speed_slider.min_value = 0.5
	haupt.speed_slider.max_value = 5.0
	haupt.speed_slider.step = 0.25
	haupt.speed_slider.value = 1.0
	haupt.speed_slider.custom_minimum_size = Vector2(150, 44)
	haupt.speed_slider.tooltip_text = "Wiedergabegeschwindigkeit: 0,5× bis 5×"
	haupt.speed_slider.value_changed.connect(haupt._geschwindigkeit_geaendert)
	steuerung.add_child(haupt.speed_slider)
	var abstand := Control.new()
	abstand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	steuerung.add_child(abstand)
	haupt.zeit_label = Label.new()
	haupt.zeit_label.text = "Simulation: 00:00:00 | Praxis: 08:00:00"
	haupt.zeit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	haupt.zeit_label.add_theme_font_size_override("font_size", 14)
	steuerung.add_child(haupt.zeit_label)
	var kamera_button := _button("Ansicht zurücksetzen", Vector2(184, 44))
	kamera_button.pressed.connect(haupt._kamera_zuruecksetzen)
	steuerung.add_child(kamera_button)
	haupt.status_label = Label.new()
	haupt.status_label.position = Vector2(24, 752)
	haupt.status_label.size = Vector2(1232, 40)
	haupt.status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	haupt.status_label.add_theme_font_size_override("font_size", 13)
	haupt.status_label.add_theme_color_override("font_color", Color("#60778b"))
	haupt.add_child(haupt.status_label)

static func _button(text: String, mindestgroesse: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = mindestgroesse
	return button

static func _karte(haupt: Control, bereich: Rect2) -> void:
	var panel := Panel.new()
	panel.position = bereich.position
	panel.size = bereich.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", STIL.flaeche("#ffffff", "#d6e2eb"))
	haupt.add_child(panel)
