extends RefCounted
## Aufbau der Bedienoberflaeche mit Zugang zum Offline-Personalfenster.
const PRAXIS_LAYOUT = preload("res://PraxisLayout.gd")

static func bauen(haupt: Control) -> void:
	# Hintergrund und Kopfbereich
	var hintergrund := ColorRect.new()
	hintergrund.color = Color("#f2f5f8")
	hintergrund.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hintergrund.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hintergrund.show_behind_parent = true
	hintergrund.z_index = -2
	haupt.add_child(hintergrund)

	var kopf := VBoxContainer.new()
	kopf.position = Vector2(22, 14)
	kopf.size = Vector2(850, 76)
	kopf.add_theme_constant_override("separation", 3)
	haupt.add_child(kopf)

	var titel := Label.new()
	titel.text = "ARZTPRAXIS | 3D-VISUALISIERUNG"
	titel.add_theme_font_size_override("font_size", 24)
	titel.add_theme_color_override("font_color", Color("#18334a"))
	kopf.add_child(titel)

	var untertitel := Label.new()
	untertitel.text = "Rechte Maustaste: Ansicht drehen | Mausrad: Zoom | Patienten folgen den Originalereignissen"
	untertitel.add_theme_color_override("font_color", Color("#526779"))
	kopf.add_child(untertitel)

	haupt.personal_button = Button.new()
	haupt.personal_button.text = "Personal einstellen"
	haupt.personal_button.position = Vector2(730, 14)
	haupt.personal_button.size = Vector2(170, 34)
	haupt.personal_button.pressed.connect(haupt._personal_oeffnen)
	haupt.add_child(haupt.personal_button)

	haupt.modus_auswahl = OptionButton.new()
	haupt.modus_auswahl.position = Vector2(910, 34)
	haupt.modus_auswahl.custom_minimum_size = Vector2(310, 40)
	haupt.modus_auswahl.add_item("Offline (direkt in Godot)")
	haupt.modus_auswahl.add_item("WebSocket (Server)")
	haupt.modus_auswahl.selected = 0
	haupt.modus_auswahl.item_selected.connect(haupt._modus_wechseln)
	haupt.add_child(haupt.modus_auswahl)

	var bau_schalter := Button.new()
	bau_schalter.text = "Baumodus"
	bau_schalter.position = Vector2(910, 78)
	bau_schalter.size = Vector2(145, 32)
	bau_schalter.pressed.connect(haupt._baumodus_umschalten)
	haupt.add_child(bau_schalter)

	var steuerung := HBoxContainer.new()
	steuerung.position = Vector2(22, 665)
	steuerung.size = Vector2(850, 48)
	steuerung.add_theme_constant_override("separation", 10)
	haupt.add_child(steuerung)

	haupt.play_button = Button.new()
	haupt.play_button.text = "Start"
	haupt.play_button.custom_minimum_size = Vector2(100, 38)
	haupt.play_button.pressed.connect(haupt._start_pause)
	steuerung.add_child(haupt.play_button)

	haupt.reset_button = Button.new()
	haupt.reset_button.text = "Reset"
	haupt.reset_button.custom_minimum_size = Vector2(100, 38)
	haupt.reset_button.pressed.connect(haupt._reset_simulation)
	steuerung.add_child(haupt.reset_button)

	haupt.speed_label = Label.new()
	haupt.speed_label.text = "Geschwindigkeit: 1.0x"
	haupt.speed_label.custom_minimum_size = Vector2(170, 38)
	haupt.speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	haupt.speed_label.add_theme_color_override("font_color", Color("#2f5068"))
	steuerung.add_child(haupt.speed_label)

	haupt.speed_slider = HSlider.new()
	haupt.speed_slider.min_value = 0.5
	haupt.speed_slider.max_value = 5.0
	haupt.speed_slider.step = 0.25
	haupt.speed_slider.value = 1.0
	haupt.speed_slider.custom_minimum_size = Vector2(210, 38)
	haupt.speed_slider.value_changed.connect(haupt._geschwindigkeit_geaendert)
	steuerung.add_child(haupt.speed_slider)

	haupt.zeit_label = Label.new()
	haupt.zeit_label.text = "Simulationszeit: 00:00:00"
	haupt.zeit_label.custom_minimum_size = Vector2(360, 38)
	haupt.zeit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	haupt.zeit_label.add_theme_color_override("font_color", Color("#2f5068"))
	steuerung.add_child(haupt.zeit_label)

	haupt.status_label = Label.new()
	haupt.status_label.position = Vector2(22, 720)
	haupt.status_label.size = Vector2(1236, 60)
	haupt.status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	haupt.status_label.add_theme_color_override("font_color", Color("#526779"))
	haupt.add_child(haupt.status_label)

	var kamera_button := Button.new()
	kamera_button.text = "Ansicht zurücksetzen"
	kamera_button.pressed.connect(haupt._kamera_zuruecksetzen)
	steuerung.add_child(kamera_button)
	haupt.statistik_label = Label.new()
	haupt.statistik_label.position = Vector2(22, 630)
	haupt.statistik_label.add_theme_color_override("font_color", Color("#18334a"))
	haupt.add_child(haupt.statistik_label)

