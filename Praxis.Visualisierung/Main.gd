extends Control

# Originaler SimSharp-Kern, separate Godot-Darstellung.
# Die Simulation entscheidet; diese Datei zeichnet und animiert.

const SIMULATION_BRIDGE = preload("res://SimulationBridge.cs")
const OFFLINE_BRIDGE = preload("res://OfflineSimulationBridge.cs")
const TIMELINE = preload("res://PatientenTimeline.gd")
var timeline = TIMELINE.new()
var oeffnungsdauer := SIMULATIONSENDE
var fehler := false
const SIMULATIONSENDE := 480.0
const PATIENT_SCRIPT = preload("res://Patient.gd")
const PRAXIS_3D = preload("res://Raum3D/Praxis.tscn")
const ANSICHT := Rect2(22, 110, 1236, 510)
var kamera: Camera3D
var kamera_winkel := 45.0
var kamera_neigung := 48.0
var kamera_zoom := 22.0
var kamera_drehen := false
var statistik_label: Label


var ereignisse: Array[Dictionary] = []
var patienten: Dictionary = {} # PatientId -> Ereignis-Timeline
var laufzeit := 0.0
var laeuft := false
var geschwindigkeit := 1.0
var status_label: Label
var zeit_label: Label
var speed_label: Label
var play_button: Button
var speed_slider: HSlider
var letzter_trace_status := ""
var patienten_welt: Node3D
var patienten_figuren: Dictionary = {}
var wiedergabe_ende := SIMULATIONSENDE
var rezeption_plaetze: Dictionary = {}
var simulation: Node
var simulation_bereit := false
var simulationslauf := 0
var lauf_abgeschlossen := false
var live_ereignisse := 0
var reset_button: Button
var modus_auswahl: OptionButton
var offline_modus := true

func _ready() -> void:
	_baue_steuerung()
	_baue_patienten_ebene()
	_modus_wechseln(0)

func _modus_wechseln(index: int) -> void:
	offline_modus = index == 0
	simulation_bereit = false
	fehler = false
	if is_instance_valid(simulation):
		simulation.queue_free()
	ereignisse.clear()
	_uebernehme_darstellungsplan([])
	simulationslauf = 0
	laufzeit = 0.0
	laeuft = false
	live_ereignisse = 0
	simulation = OFFLINE_BRIDGE.new() if offline_modus else SIMULATION_BRIDGE.new()
	add_child(simulation)
	simulation.ZustandGeaendert.connect(_simulation_zustand)
	simulation.EreignisAufgetreten.connect(_simulation_ereignis)
	var ladefehler: String = simulation.Laden()
	if not ladefehler.is_empty():
		fehler = true
		status_label.text = "Simulation konnte nicht geladen werden: " + ladefehler
		play_button.disabled = true
		reset_button.disabled = true
		return
	play_button.disabled = false
	reset_button.disabled = false
	simulation_bereit = true
	simulation.Initialisieren()
	_aktualisiere_patienten(0.0)
	queue_redraw()

func _process(delta: float) -> void:
	if simulation_bereit:
		simulation.Fortschalten(delta)
	_aktualisiere_patienten(delta * geschwindigkeit if laeuft else 0.0)

func _baue_patienten_ebene() -> void:
	# Grundriss, Möbel und Figuren teilen dieselbe echte 3D-Welt.
	var container := SubViewportContainer.new()
	container.position = ANSICHT.position
	container.size = ANSICHT.size
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ANSICHT.size)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	patienten_welt = Node3D.new()
	viewport.add_child(patienten_welt)
	patienten_welt.add_child(PRAXIS_3D.instantiate())
	kamera = Camera3D.new()
	kamera.projection = Camera3D.PROJECTION_ORTHOGONAL
	patienten_welt.add_child(kamera)
	kamera.current = true
	_kamera_aktualisieren()
	var licht := DirectionalLight3D.new()
	licht.rotation_degrees = Vector3(-55, -30, 0)
	licht.light_energy = 0.55
	patienten_welt.add_child(licht)
	var umgebung := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#dce6ec")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.35
	umgebung.environment = environment
	patienten_welt.add_child(umgebung)
	for daten in [["WARTEZIMMER", Vector3(-6.65, 2.8, -6.5)],
		["ARZT 1", Vector3(0, 2.8, -6.5)], ["ARZT 2", Vector3(6.65, 2.8, -6.5)],
		["REZEPTION", Vector3(-5, 2.8, 6.5)], ["SCHWESTER", Vector3(5, 2.8, 6.5)],
		["EIN- / AUSGANG", Vector3(-6.25, 0.5, 8.3)]]:
		var schild := Label3D.new()
		schild.text = daten[0]
		schild.position = daten[1]
		schild.font_size = 32
		schild.pixel_size = 0.018
		schild.modulate = Color("#18334a")
		schild.outline_modulate = Color.WHITE
		schild.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		schild.no_depth_test = true
		patienten_welt.add_child(schild)

func _kamera_aktualisieren() -> void:
	var yaw := deg_to_rad(kamera_winkel)
	var pitch := deg_to_rad(kamera_neigung)
	kamera.position = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 35.0
	kamera.look_at(Vector3.ZERO)
	kamera.size = kamera_zoom

func _input(event: InputEvent) -> void:
	if not is_instance_valid(kamera):
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			kamera_drehen = event.pressed and ANSICHT.has_point(event.position)
		if event.pressed and ANSICHT.has_point(event.position):
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				kamera_zoom = maxf(14.0, kamera_zoom - 1.0)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				kamera_zoom = minf(34.0, kamera_zoom + 1.0)
			_kamera_aktualisieren()
	elif event is InputEventMouseMotion and kamera_drehen:
		kamera_winkel -= event.relative.x * 0.35
		kamera_neigung = clampf(kamera_neigung + event.relative.y * 0.2, 25.0, 80.0)
		_kamera_aktualisieren()

func _kamera_zuruecksetzen() -> void:
	kamera_winkel = 45.0
	kamera_neigung = 48.0
	kamera_zoom = 22.0
	_kamera_aktualisieren()

func _grundriss_zu_3d(punkt: Vector2) -> Vector3:
	# Die Timeline verwendet jetzt die X-/Z-Meterkoordinaten der 3D-Praxis.
	return Vector3(punkt.x, 0.06, punkt.y)

func _aktualisiere_patienten(delta: float) -> void:
	for patient_id in patienten.keys():
		var info := _position_patient(patient_id)
		var sichtbar: bool = not info.is_empty() and not info.get("ausgetreten", true)
		if not patienten_figuren.has(patient_id):
			if not sichtbar:
				continue
			var figur := Node3D.new()
			figur.set_script(PATIENT_SCRIPT)
			patienten_welt.add_child(figur)
			patienten_figuren[patient_id] = figur
			var nummer := Label3D.new()
			nummer.text = str(patient_id)
			nummer.position.y = 2.1
			nummer.font_size = 40
			nummer.pixel_size = 0.014
			nummer.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			nummer.no_depth_test = true
			figur.add_child(nummer)
		var figur: Node3D = patienten_figuren[patient_id]
		figur.visible = sichtbar
		if not sichtbar:
			figur.queue_free()
			patienten_figuren.erase(patient_id)
			continue
		if sichtbar:
			var punkt: Vector2 = info["position"]
			var richtung: Vector2 = info.get("richtung", Vector2.ZERO)
			figur.aktualisieren(_grundriss_zu_3d(punkt), Vector3(richtung.x, 0, richtung.y), delta)

func _baue_steuerung() -> void:
	# Hintergrund und Kopfbereich
	var hintergrund := ColorRect.new()
	hintergrund.color = Color("#f2f5f8")
	hintergrund.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hintergrund.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hintergrund.show_behind_parent = true
	hintergrund.z_index = -2
	add_child(hintergrund)

	var kopf := VBoxContainer.new()
	kopf.position = Vector2(22, 14)
	kopf.size = Vector2(850, 76)
	kopf.add_theme_constant_override("separation", 3)
	add_child(kopf)

	var titel := Label.new()
	titel.text = "ARZTPRAXIS | 3D-VISUALISIERUNG"
	titel.add_theme_font_size_override("font_size", 24)
	titel.add_theme_color_override("font_color", Color("#18334a"))
	kopf.add_child(titel)

	var untertitel := Label.new()
	untertitel.text = "Rechte Maustaste: Ansicht drehen | Mausrad: Zoom | Patienten folgen den Originalereignissen"
	untertitel.add_theme_color_override("font_color", Color("#526779"))
	kopf.add_child(untertitel)

	modus_auswahl = OptionButton.new()
	modus_auswahl.position = Vector2(910, 34)
	modus_auswahl.custom_minimum_size = Vector2(310, 40)
	modus_auswahl.add_item("Offline (direkt in Godot)")
	modus_auswahl.add_item("WebSocket (Server)")
	modus_auswahl.selected = 0
	modus_auswahl.item_selected.connect(_modus_wechseln)
	add_child(modus_auswahl)

	var steuerung := HBoxContainer.new()
	steuerung.position = Vector2(22, 665)
	steuerung.size = Vector2(850, 48)
	steuerung.add_theme_constant_override("separation", 10)
	add_child(steuerung)

	play_button = Button.new()
	play_button.text = "Start"
	play_button.custom_minimum_size = Vector2(100, 38)
	play_button.pressed.connect(_start_pause)
	steuerung.add_child(play_button)

	reset_button = Button.new()
	reset_button.text = "Reset"
	reset_button.custom_minimum_size = Vector2(100, 38)
	reset_button.pressed.connect(_reset_simulation)
	steuerung.add_child(reset_button)

	speed_label = Label.new()
	speed_label.text = "Geschwindigkeit: 1.0x"
	speed_label.custom_minimum_size = Vector2(170, 38)
	speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speed_label.add_theme_color_override("font_color", Color("#2f5068"))
	steuerung.add_child(speed_label)

	speed_slider = HSlider.new()
	speed_slider.min_value = 0.25
	speed_slider.max_value = 5.0
	speed_slider.step = 0.25
	speed_slider.value = 1.0
	speed_slider.custom_minimum_size = Vector2(210, 38)
	speed_slider.value_changed.connect(_geschwindigkeit_geaendert)
	steuerung.add_child(speed_slider)

	zeit_label = Label.new()
	zeit_label.text = "Simulationszeit: 00:00:00"
	zeit_label.custom_minimum_size = Vector2(230, 38)
	zeit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zeit_label.add_theme_color_override("font_color", Color("#2f5068"))
	steuerung.add_child(zeit_label)

	status_label = Label.new()
	status_label.position = Vector2(22, 720)
	status_label.size = Vector2(1236, 60)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("#526779"))
	add_child(status_label)

	var kamera_button := Button.new()
	kamera_button.text = "Ansicht zurücksetzen"
	kamera_button.pressed.connect(_kamera_zuruecksetzen)
	steuerung.add_child(kamera_button)
	statistik_label = Label.new()
	statistik_label.position = Vector2(22, 630)
	statistik_label.add_theme_color_override("font_color", Color("#18334a"))
	add_child(statistik_label)

func _uebernehme_darstellungsplan(plan: Array) -> void:
	timeline.laden(plan)
	patienten = timeline.patienten
	for figur in patienten_figuren.values():
		figur.queue_free()
	patienten_figuren.clear()
	letzter_trace_status = "%d Patienten im Original-Darstellungsplan. Bereit." % patienten.size()
	_aktualisiere_status()

func _start_pause() -> void:
	if not simulation_bereit:
		return
	if laeuft:
		simulation.Pausieren()
	else:
		simulation.Starten()

func _reset_simulation() -> void:
	if simulation_bereit:
		simulation.Zuruecksetzen()

func _geschwindigkeit_geaendert(wert: float) -> void:
	if simulation_bereit:
		simulation.GeschwindigkeitSetzen(wert)

func _simulation_zustand(zustand: Dictionary) -> void:
	var neuer_lauf := int(zustand["lauf"])
	if neuer_lauf != simulationslauf:
		simulationslauf = neuer_lauf
		ereignisse.clear()
		timeline.laden(ereignisse)
		patienten = timeline.patienten
		for figur in patienten_figuren.values():
			figur.queue_free()
		patienten_figuren.clear()
	laufzeit = float(zustand["zeit"])
	geschwindigkeit = float(zustand["geschwindigkeit"])
	laeuft = bool(zustand["laeuft"])
	lauf_abgeschlossen = bool(zustand["abgeschlossen"])
	live_ereignisse = int(zustand["ereigniszahl"])
	wiedergabe_ende = float(zustand["dauer"])
	oeffnungsdauer = float(zustand["oeffnungsdauer"])
	speed_slider.set_value_no_signal(geschwindigkeit)
	speed_label.text = "Geschwindigkeit: %.2fx" % geschwindigkeit
	play_button.text = ("Pause" if offline_modus else "Stop") if laeuft else "Start"
	letzter_trace_status = "%s: %d Patienten, %d Ereignisse. %s" % ["Offline" if offline_modus else "WebSocket", patienten.size(), live_ereignisse, String(zustand.get("status", ""))]
	_aktualisiere_status()
	if not laeuft:
		_aktualisiere_patienten(0.0)
	queue_redraw()

func _simulation_ereignis(ereignis: Dictionary) -> void:
	ereignisse.append(ereignis)
	# Nur bereits vom Kern erzeugte Ereignisse werden dargestellt.
	timeline.laden(ereignisse)
	patienten = timeline.patienten
	_aktualisiere_patienten(0.0)

func _aktualisiere_status() -> void:
	var sekunden := int(laufzeit * 60.0)
	zeit_label.text = "Simulationszeit: %02d:%02d:%02d" % [sekunden / 3600, (sekunden / 60) % 60, sekunden % 60]
	status_label.text = letzter_trace_status
	if laufzeit > oeffnungsdauer and laufzeit < wiedergabe_ende:
		status_label.text = letzter_trace_status + " Ankunftszeitraum beendet; Originalnachlauf läuft."

func _draw() -> void:
	var sichtbar := 0
	var warten := 0
	var in_behandlung := 0
	for id in patienten:
		var info := _position_patient(id)
		if info.is_empty() or info["ausgetreten"]:
			continue
		sichtbar += 1
		var station: String = info["station"]
		if info["richtung"] == Vector2.ZERO and ("Warten" in station or "Wartezimmer" in station):
			warten += 1
		elif info["richtung"] == Vector2.ZERO and station in ["Arzt", "Schwester", "Rezeption"]:
			in_behandlung += 1
	statistik_label.text = "In der Praxis: %d   |   an Wartepositionen: %d   |   an Stationen: %d" % [sichtbar, warten, in_behandlung]

func _position_patient(patient_id: String) -> Dictionary:
	return timeline.zustand(patient_id, laufzeit)
