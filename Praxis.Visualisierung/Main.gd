extends Control

# Originaler SimSharp-Kern, separate Godot-Darstellung.
# Die Simulation entscheidet; diese Datei zeichnet und animiert.

const SIMULATION_BRIDGE = preload("res://Anbindung/SimulationBridge.cs")
const OFFLINE_BRIDGE = preload("res://Anbindung/OfflineSimulationBridge.cs")
const TIMELINE = preload("res://Patienten/PatientenTimeline.gd")
var timeline = TIMELINE.new()
var oeffnungsdauer := SIMULATIONSENDE
var fehler := false
const SIMULATIONSENDE := 480.0
const PATIENT_SCRIPT = preload("res://Patienten/Patient.gd")
const PERSONAL_VERWALTUNG = preload("res://Personal/PersonalVerwaltung.gd")
const PERSONAL_FENSTER = preload("res://UI/PersonalMatrix.gd")
const BAU_FENSTER = preload("res://UI/Baukonfiguration.gd")
const STEUERUNG = preload("res://UI/Steuerung.gd")
const PRAXIS_3D = preload("res://Raum3D/Praxis.tscn")
const KONFIGURATION = preload("res://Konfiguration/KonfigurationLader.gd")
const PRAXIS_LAYOUT = preload("res://PraxisLayout.gd")
var layout_daten: Dictionary = KONFIGURATION.layout()
const ANSICHT := Rect2(22, 110, 1236, 510)
const GRUPPEN_MINDESTGROESSE := 6
const GRUPPEN_ABSTAND := 2.2
const GRUPPEN_UPDATE_INTERVALL := 0.2
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
var simulationsminuten_pro_sekunde := 8.0
var status_label: Label
var zeit_label: Label
var speed_label: Label
var play_button: Button
var speed_slider: HSlider
var letzter_trace_status := ""
var patienten_welt: Node3D
var patienten_figuren: Dictionary = {}
var gruppen_blasen: Array[Node3D] = []
var gruppen_update_rest := 0.0
var zimmer_leuchten: Dictionary = {}
var personal_figuren: Array[Node3D] = []
var personal_plan: Array = []
# Startvorlagen liefern Identitaet, Qualifikationen und Aussehen. Die aktive
# Arbeitsplatzbelegung steht getrennt in personal_plan und bleibt bis zum Neustart bestehen.
var personal_vorlagen: Array = []
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
var personal_button: Button
var personal_fenster: ConfirmationDialog
var bau_fenster: ConfirmationDialog
var praxis_layout = PRAXIS_LAYOUT.new()
var layout_welt: Node3D
var layout_knoten: Array[Node3D] = []
var baumodus := false
var ausgewaehlter_raum := -1
var raum_ziehen := false
var bau_status: Label
var bau_panel: Control
var bau_name: LineEdit
var bau_x: SpinBox
var bau_z: SpinBox
var bau_breite: SpinBox
var bau_tiefe: SpinBox
var bau_eingaben_werden_gesetzt := false
var praxis_3d: Node3D
var bau_vorschau_daten: Dictionary = {}
var bau_vorschau_geplant := false

func _ready() -> void:
	var layout_fehler: String = praxis_layout.laden()
	if not layout_fehler.is_empty():
		push_error(layout_fehler)
	else:
		layout_daten = praxis_layout.daten
	timeline.konfigurieren(layout_daten)
	# Eingebettetes Fenster bleibt mit der 3D-Ansicht in einem Anwendungsfenster.
	get_viewport().gui_embed_subwindows = true
	_baue_steuerung()
	_baue_patienten_ebene()
	_layout_anzeigen()
	personal_fenster = PERSONAL_FENSTER.new()
	add_child(personal_fenster)
	personal_fenster.uebernehmen.connect(_personal_uebernehmen)
	bau_fenster = BAU_FENSTER.new()
	add_child(bau_fenster)
	bau_fenster.vorschau.connect(_bau_dialog_vorschau)
	bau_fenster.uebernehmen.connect(_bau_dialog_uebernehmen)
	bau_fenster.verworfen.connect(_bau_dialog_verwerfen)
	bau_fenster.zurueckgesetzt.connect(_bau_dialog_zurueckgesetzt)
	_modus_wechseln(0)

func _modus_wechseln(index: int) -> void:
	offline_modus = index == 0
	simulation_bereit = false
	fehler = false
	personal_fenster.hide()
	personal_button.disabled = not offline_modus
	_entferne_personal()
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
	if offline_modus and simulation.has_method("LayoutKonfigurationSetzen"):
		simulation.LayoutKonfigurationSetzen(maxi(1, praxis_layout.anzahl("Arzt")),
			maxi(1, praxis_layout.anzahl("Schwester")), maxi(1, praxis_layout.anzahl("Rezeption")),
			praxis_layout.flaeche("Arzt"), praxis_layout.flaeche("Schwester"), praxis_layout.flaeche("Wartezimmer"))
	simulation.ZustandGeaendert.connect(_simulation_zustand)
	# Verbindung vom C#-Kern zur Darstellung: Jede Patientenmeldung landet im Handler unten.
	simulation.EreignisAufgetreten.connect(_simulation_ereignis)
	var ladefehler: String = simulation.Laden()
	if offline_modus:
		personal_button.disabled = simulation.PersonalStandardwerteLesen().is_empty()
	if ladefehler.is_empty():
		ladefehler = _baue_personal()
	if not ladefehler.is_empty():
		fehler = true
		status_label.text = "Simulation konnte nicht geladen werden: " + ladefehler
		play_button.disabled = true
		reset_button.disabled = true
		# Eine gueltige Personenkonfiguration kann trotzdem unbesetzte Einsatzrollen
		# ergeben. Dann darf der Nutzer die Besetzung im Fenster korrigieren.
		if offline_modus and not personal_vorlagen.is_empty() and PERSONAL_VERWALTUNG.personen_pruefen(personal_vorlagen).is_empty() and not personal_button.disabled:
			_personal_oeffnen()
		return
	play_button.disabled = false
	reset_button.disabled = false
	simulation_bereit = true
	simulation.Initialisieren()
	_aktualisiere_patienten(0.0)
	queue_redraw()

func _process(delta: float) -> void:
	var zeit_vorher := laufzeit
	if simulation_bereit:
		simulation.Fortschalten(delta)
	# Im Offline-Modus leitet sich auch die Animationsfortschaltung ausschließlich
	# aus der tatsächlich erreichten zentralen Simulationszeit ab.
	var animations_delta := 0.0
	if offline_modus:
		animations_delta = maxf(0.0, laufzeit - zeit_vorher) / simulationsminuten_pro_sekunde
	elif laeuft:
		animations_delta = delta * geschwindigkeit
	_aktualisiere_patienten(animations_delta)
	gruppen_update_rest -= delta
	if gruppen_update_rest <= 0.0:
		gruppen_update_rest = GRUPPEN_UPDATE_INTERVALL
		_aktualisiere_gruppenblasen()
	for figur in personal_figuren:
		figur.aktualisieren(animations_delta)

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
	praxis_3d = PRAXIS_3D.instantiate()
	patienten_welt.add_child(praxis_3d)
	layout_welt = Node3D.new()
	layout_welt.name = "EditierbaresPraxislayout"
	patienten_welt.add_child(layout_welt)
	_baue_zimmerleuchten()
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
	var beschriftungen: Array = layout_daten.get("beschriftungen", []).duplicate()
	for raum in layout_daten["raeume"]:
		if raum.has("beschriftung"):
			beschriftungen.append(raum["beschriftung"])
	for daten in beschriftungen:
		var schild := Label3D.new()
		schild.text = String(daten["text"])
		schild.position = KONFIGURATION.punkt3(daten["position"])
		schild.font_size = 32
		schild.pixel_size = 0.018
		schild.modulate = Color("#18334a")
		schild.outline_modulate = Color.WHITE
		schild.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		schild.no_depth_test = true
		patienten_welt.add_child(schild)

## Verbindet die Godot-Personen mit dem vorhandenen Offline-Kern: Erst die gesamte
## Besetzung pruefen, danach Einsatzkapazitaeten uebergeben und Figuren erstellen.
func _baue_personal() -> String:
	var plaetze: Array
	if offline_modus:
		var konfiguration: Dictionary = KONFIGURATION.lesen("personal.json")
		if not konfiguration.get("personal") is Array:
			return "personal.json braucht eine gueltige Personenliste."
		personal_vorlagen = konfiguration["personal"].duplicate(true)
		var vorlagen_fehler: String = PERSONAL_VERWALTUNG.personen_pruefen(personal_vorlagen)
		if not vorlagen_fehler.is_empty():
			return vorlagen_fehler
		var plan := {}
		var zahlen: Dictionary = simulation.PersonalzahlenLesen()
		var zuordnungen := {}
		if layout_daten.has("offline_personal"):
			# Ein im Baumodus gespeicherter Personenplan hat Vorrang vor den Startvorlagen.
			# Dadurch bleiben bereits uebernommene Einsatzrollen beim Laden erhalten.
			if not layout_daten["offline_personal"] is Dictionary:
				return "Ungueltige Offline-Personalkonfiguration im Layout."
			plan = PERSONAL_VERWALTUNG.konfiguration_planen(layout_daten["offline_personal"], layout_daten["arbeitsplaetze"])
			if not String(plan["fehler"]).is_empty():
				return String(plan["fehler"])
			zahlen = plan["anzahlen"]
			zuordnungen = layout_daten["offline_personal"]["zuordnungen"]
		if not plan.has("personen"):
			# Ohne gespeicherte Personen werden die eingestellten Stammzahlen mit den
			# Vorlagen verbunden. So funktionieren auch aeltere Layouts weiter.
			var entwurf: Dictionary = PERSONAL_VERWALTUNG.personen_erstellen(zahlen, personal_vorlagen)
			if not String(entwurf["fehler"]).is_empty():
				return String(entwurf["fehler"])
			# Alte Layoutzuordnungen gelten nur, solange die Einsatzrolle noch passt.
			var alte_plaetze: Array = plan.get("plaetze", [])
			if not alte_plaetze.is_empty():
				zuordnungen = PERSONAL_VERWALTUNG.zuordnungen_behalten(entwurf["personen"], alte_plaetze)
			plan = PERSONAL_VERWALTUNG.personen_planen(entwurf["personen"], layout_daten["arbeitsplaetze"], zuordnungen)
		if not String(plan["fehler"]).is_empty():
			return String(plan["fehler"])
		if plan["anzahlen"] != simulation.PersonalzahlenLesen():
			# Der Kern erhaelt ausschliesslich Anzahlen je Einsatzrolle. Qualifikationen,
			# stabile IDs und Aussehen bleiben in Godot; Kern-Quelldateien werden nicht geaendert.
			var kern_fehler: String = simulation.PersonalzahlenAnwenden(plan["anzahlen"])
			if not kern_fehler.is_empty():
				return kern_fehler
		plaetze = plan["plaetze"]
	else:
		# Das bestehende Serverprotokoll liefert noch keine Personalzahlen.
		# Eine spaeter wieder angelegte explizite Besetzung ist optional; ohne sie keine Personalfiguren.
		plaetze = KONFIGURATION.personal_plaetze()
	_personalplan_anwenden(plaetze)
	return ""

## Figuren und Patienten-Timeline erhalten denselben Plan, damit Personal und
## behandelter Patient denselben Arbeitsplatz als Ziel verwenden.
func _personalplan_anwenden(plaetze: Array) -> void:
	personal_plan = plaetze
	personal_figuren = PERSONAL_VERWALTUNG.erstellen(patienten_welt, plaetze)
	if offline_modus:
		timeline.personal_zuordnen(plaetze)

func _entferne_personal() -> void:
	for figur in personal_figuren:
		figur.visible = false
		figur.queue_free()
	personal_figuren.clear()
	personal_plan.clear()
	timeline.personal_zuordnen([])

func _personal_oeffnen() -> void:
	if not offline_modus or personal_button.disabled:
		return
	# Der Dialog bearbeitet Kopien; bis zum Uebernehmen bleibt die aktive Besetzung bestehen.
	personal_fenster.vorbereiten(simulation.PersonalzahlenLesen(), simulation.PersonalStandardwerteLesen(),
		layout_daten["arbeitsplaetze"], PERSONAL_VERWALTUNG.personen_aus_plan(personal_plan), personal_vorlagen)
	personal_fenster.popup_centered()

## Eingaben veraendern den aktiven Lauf erst, wenn Validierung und neuer Vorlauf erfolgreich sind.
## anzahlen bezeichnet eingestellte Personen nach Stammrolle. Die Einsatzrollen in
## personen bestimmen die tatsaechlichen Kernkapazitaeten fuer den neuen Tag.
func _personal_uebernehmen(anzahlen: Dictionary, personen: Array = []) -> String:
	var fehlermeldung := ""
	if not offline_modus:
		fehlermeldung = "Personal kann nur im Offline-Modus eingestellt werden."
	else:
		for rolle in PERSONAL_VERWALTUNG.ROLLEN:
			if not anzahlen.has(rolle) or typeof(anzahlen[rolle]) != TYPE_INT or int(anzahlen[rolle]) < 1:
				fehlermeldung = "Bitte für jede Rolle eine ganze Anzahl von mindestens 1 angeben."
				break
	var plan := {}
	if fehlermeldung.is_empty():
		if personen.is_empty():
			# Bestehende Aufrufer duerfen weiterhin nur Zahlen uebergeben. Ihre aktiven
			# Personen und Einsatzrollen werden dann in die neue Besetzung uebernommen.
			var entwurf: Dictionary = PERSONAL_VERWALTUNG.personen_erstellen(anzahlen, personal_vorlagen, PERSONAL_VERWALTUNG.personen_aus_plan(personal_plan))
			fehlermeldung = String(entwurf["fehler"])
			personen = entwurf["personen"]
		else:
			# Die zusaetzliche Pruefung schuetzt auch direkte Aufrufe ausserhalb des Dialogs.
			fehlermeldung = PERSONAL_VERWALTUNG.personen_pruefen(personen)
			if fehlermeldung.is_empty() and PERSONAL_VERWALTUNG.personen_zahlen(personen, "stammrolle") != anzahlen:
				fehlermeldung = "Personenliste passt nicht zu den eingestellten Stammrollen."
	if fehlermeldung.is_empty():
		plan = PERSONAL_VERWALTUNG.personen_planen(personen, layout_daten["arbeitsplaetze"], PERSONAL_VERWALTUNG.zuordnungen_behalten(personen, personal_plan))
		fehlermeldung = String(plan["fehler"])
	if fehlermeldung.is_empty():
		fehlermeldung = simulation.PersonalzahlenAnwenden(plan["anzahlen"])
	if not fehlermeldung.is_empty():
		personal_fenster.fehler_anzeigen(fehlermeldung)
		return fehlermeldung
	# Erst nach erfolgreicher Kernvorbereitung die alten Figuren ersetzen. Die neue
	# Figur derselben Person steht direkt an ihrem neu zugeteilten Arbeitsplatz.
	_entferne_personal()
	_personalplan_anwenden(plan["plaetze"])
	fehler = false
	simulation_bereit = true
	play_button.disabled = false
	reset_button.disabled = false
	# Initialisieren setzt Timeline und Patienten gemeinsam mit der Kernuhr zurueck.
	simulation.Initialisieren()
	_aktualisiere_gruppenblasen()
	personal_fenster.hide()
	simulation.Starten()
	return ""

func _baue_zimmerleuchten() -> void:
	for daten in layout_daten["statusleuchten"]:
		var leuchte := Node3D.new()
		leuchte.name = "Statusleuchte_" + String(daten["id"])
		leuchte.position = KONFIGURATION.punkt3(daten["position"])
		var kugel := MeshInstance3D.new()
		kugel.name = "Licht"
		var mesh := SphereMesh.new()
		mesh.radius = 0.22
		mesh.height = 0.44
		kugel.mesh = mesh
		kugel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		leuchte.add_child(kugel)
		var beschriftung := Label3D.new()
		beschriftung.name = "Status"
		beschriftung.position = Vector3(0, 0.4, 0)
		beschriftung.font_size = 32
		beschriftung.pixel_size = 0.012
		beschriftung.outline_size = 8
		beschriftung.outline_modulate = Color(0.02, 0.05, 0.04, 1.0)
		beschriftung.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		beschriftung.no_depth_test = true
		leuchte.add_child(beschriftung)
		patienten_welt.add_child(leuchte)
		zimmer_leuchten[String(daten["id"])] = leuchte
		_setze_zimmerleuchte(String(daten["id"]), false)

func _aktualisiere_zimmerleuchten() -> void:
	var belegt := {}
	for raum in praxis_layout.raeume:
		if String(raum.get("typ", "")) in ["Arzt", "Schwester"]:
			belegt[String(raum["id"])] = false
	for patient_id in patienten.keys():
		var info := _position_patient(patient_id)
		if info.is_empty() or bool(info.get("ausgetreten", true)):
			continue
		var station := String(info.get("station", ""))
		var punkt: Vector2 = info.get("position", Vector2.ZERO)
		if station in ["Arzt", "Schwester"]:
			var erwarteter_typ := station
			for raum_index in praxis_layout.raeume.size():
				var raum: Dictionary = praxis_layout.raeume[raum_index]
				if String(raum.get("typ", "")) == erwarteter_typ and Geometry2D.is_point_in_polygon(punkt, praxis_layout._raum_polygon(raum_index)):
					belegt[String(raum["id"])] = true
					break
	for zimmer_id in zimmer_leuchten.keys():
		_setze_zimmerleuchte(zimmer_id, bool(belegt.get(zimmer_id, false)))

func _setze_zimmerleuchte(zimmer_id: String, belegt: bool) -> void:
	if not zimmer_leuchten.has(zimmer_id):
		return
	var leuchte: Node3D = zimmer_leuchten[zimmer_id]
	var kugel := leuchte.get_node("Licht") as MeshInstance3D
	var material := StandardMaterial3D.new()
	var farbe := Color("#e53935") if belegt else Color("#28b463")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = farbe
	material.emission_enabled = true
	material.emission = farbe
	material.emission_energy_multiplier = 2.0
	kugel.material_override = material
	var status := leuchte.get_node("Status") as Label3D
	status.text = "BELEGT" if belegt else "FREI"
	status.modulate = farbe

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
		if baumodus and event.button_index == MOUSE_BUTTON_LEFT and ANSICHT.has_point(event.position) and (not is_instance_valid(bau_panel) or not bau_panel.get_global_rect().has_point(event.position)):
			if event.pressed:
				ausgewaehlter_raum = _raum_an_position(_maus_auf_boden(event.position))
				raum_ziehen = ausgewaehlter_raum >= 0
				_layout_anzeigen()
			else:
				raum_ziehen = false
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			kamera_drehen = event.pressed and ANSICHT.has_point(event.position)
		if event.pressed and ANSICHT.has_point(event.position):
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				kamera_zoom = maxf(14.0, kamera_zoom - 1.0)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				kamera_zoom = minf(34.0, kamera_zoom + 1.0)
			_kamera_aktualisieren()
	elif event is InputEventMouseMotion:
		if baumodus and raum_ziehen:
			praxis_layout.verschieben(ausgewaehlter_raum, _maus_auf_boden(event.position))
			_praxis_vorschau_aktualisieren()
			_layout_anzeigen()
		elif kamera_drehen:
			kamera_winkel -= event.relative.x * 0.35
			kamera_neigung = clampf(kamera_neigung + event.relative.y * 0.2, 25.0, 80.0)
			_kamera_aktualisieren()

func _maus_auf_boden(maus: Vector2) -> Vector2:
	var lokal := maus - ANSICHT.position
	var start := kamera.project_ray_origin(lokal)
	var richtung := kamera.project_ray_normal(lokal)
	if absf(richtung.y) < 0.0001:
		return Vector2.ZERO
	var treffer := start + richtung * (-start.y / richtung.y)
	return Vector2(treffer.x, treffer.z)

func _raum_an_position(punkt: Vector2) -> int:
	for index in range(praxis_layout.raeume.size() - 1, -1, -1):
		var raum: Dictionary = praxis_layout.raeume[index]
		if String(raum.get("typ", "")) not in PRAXIS_LAYOUT.EDITIERBARE_TYPEN:
			continue
		var mitte := praxis_layout.position(index)
		var raum_groesse := praxis_layout.groesse(index)
		if absf(punkt.x - mitte.x) <= raum_groesse.x / 2.0 and absf(punkt.y - mitte.y) <= raum_groesse.y / 2.0:
			return index
	return -1

func _layout_anzeigen() -> void:
	if not is_instance_valid(layout_welt):
		return
	for knoten in layout_knoten:
		knoten.queue_free()
	layout_knoten.clear()
	var farben := {"Arzt": Color("#58a85b"), "Schwester": Color("#8c6cc4"),
		"Wartezimmer": Color("#4d9ed4"), "Rezeption": Color("#d5944c")}
	for index in praxis_layout.raeume.size():
		var raum: Dictionary = praxis_layout.raeume[index]
		if String(raum.get("typ", "")) not in PRAXIS_LAYOUT.EDITIERBARE_TYPEN:
			continue
		var mitte := praxis_layout.position(index)
		var raum_groesse := praxis_layout.groesse(index)
		var knoten := Node3D.new()
		knoten.position = Vector3(mitte.x, 0.08, mitte.y)
		var boden := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(raum_groesse.x, 0.08, raum_groesse.y)
		boden.mesh = mesh
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var farbe: Color = farben[String(raum["typ"])]
		farbe.a = 0.72 if baumodus else 0.12
		if index == ausgewaehlter_raum:
			farbe = Color(1.0, 0.82, 0.18, 0.88)
		material.albedo_color = farbe
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		boden.material_override = material
		knoten.add_child(boden)
		var label := Label3D.new()
		label.text = String(raum["typ"])
		label.position.y = 0.25
		label.font_size = 30
		label.pixel_size = 0.013
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.visible = baumodus
		knoten.add_child(label)
		layout_welt.add_child(knoten)
		layout_knoten.append(knoten)
	if is_instance_valid(bau_status):
		bau_status.text = "Raster 0,5 m | %d Räume%s" % [praxis_layout.raeume.size(),
			(" | Auswahl: " + String(praxis_layout.raeume[ausgewaehlter_raum]["typ"])) if ausgewaehlter_raum >= 0 else ""]
	_bau_inspektor_aktualisieren()

func _bau_inspektor_aktualisieren() -> void:
	if not is_instance_valid(bau_name):
		return
	bau_eingaben_werden_gesetzt = true
	var aktiv: bool = ausgewaehlter_raum >= 0 and ausgewaehlter_raum < praxis_layout.raeume.size()
	for feld in [bau_name, bau_x, bau_z, bau_breite, bau_tiefe]:
		feld.editable = aktiv
	if aktiv:
		var raum: Dictionary = praxis_layout.raeume[ausgewaehlter_raum]
		var position := praxis_layout.position(ausgewaehlter_raum)
		var groesse := praxis_layout.groesse(ausgewaehlter_raum)
		bau_name.text = String(raum.get("name", raum["id"]))
		bau_x.value = position.x
		bau_z.value = position.y
		bau_breite.value = groesse.x
		bau_tiefe.value = groesse.y
	else:
		bau_name.text = "Raum in der Praxis anklicken"
	bau_eingaben_werden_gesetzt = false

func _bau_raumdaten_geaendert(_wert = null) -> void:
	if bau_eingaben_werden_gesetzt or ausgewaehlter_raum < 0:
		return
	praxis_layout.verschieben(ausgewaehlter_raum, Vector2(bau_x.value, bau_z.value))
	praxis_layout.groesse_setzen(ausgewaehlter_raum, Vector2(bau_breite.value, bau_tiefe.value))
	var name_text := bau_name.text.strip_edges()
	if not name_text.is_empty():
		praxis_layout.raeume[ausgewaehlter_raum]["name"] = name_text
	_praxis_vorschau_aktualisieren()
	_layout_anzeigen()

func _praxis_vorschau_aktualisieren() -> void:
	layout_daten = praxis_layout.daten
	if is_instance_valid(praxis_3d):
		praxis_3d.layout_daten = layout_daten
		praxis_3d.build_layout()

func _kamera_zuruecksetzen() -> void:
	kamera_winkel = 45.0
	kamera_neigung = 48.0
	kamera_zoom = 22.0
	_kamera_aktualisieren()

func _grundriss_zu_3d(punkt: Vector2) -> Vector3:
	# Die Timeline verwendet jetzt die X-/Z-Meterkoordinaten der 3D-Praxis.
	return Vector3(punkt.x, 0.06, punkt.y)

func _aktualisiere_patienten(delta: float) -> void:
	# Pro sichtbarer Patient-ID aus der Timeline eine Figur erzeugen und spaeter aktualisieren.
	# Haeufigere Ankuenfte im Kern liefern dadurch automatisch mehr eintretende Figuren.
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
			figur.aktualisieren(_grundriss_zu_3d(punkt), Vector3(richtung.x, 0, richtung.y), delta, String(info["station"]))
	_aktualisiere_zimmerleuchten()

func _aktualisiere_gruppenblasen() -> void:
	var figuren: Array[Node3D] = []
	for figur in patienten_figuren.values():
		if is_instance_valid(figur) and figur.visible:
			figuren.append(figur)
	var eltern: Array[int] = []
	for index in figuren.size():
		eltern.append(index)
	var abstand_quadrat := GRUPPEN_ABSTAND * GRUPPEN_ABSTAND
	for links in figuren.size():
		for rechts in range(links + 1, figuren.size()):
			var a := Vector2(figuren[links].position.x, figuren[links].position.z)
			var b := Vector2(figuren[rechts].position.x, figuren[rechts].position.z)
			if a.distance_squared_to(b) <= abstand_quadrat:
				_gruppen_vereinigen(eltern, links, rechts)
	var gruppen := {}
	for index in figuren.size():
		var wurzel := _gruppen_wurzel(eltern, index)
		if not gruppen.has(wurzel):
			gruppen[wurzel] = []
		gruppen[wurzel].append(index)
	var sichtbare_gruppen: Array[Dictionary] = []
	for gruppe in gruppen.values():
		if gruppe.size() < GRUPPEN_MINDESTGROESSE:
			continue
		var mitte := Vector3.ZERO
		for index in gruppe:
			mitte += figuren[index].position
		mitte /= float(gruppe.size())
		sichtbare_gruppen.append({"anzahl": gruppe.size(), "position": mitte})
	sichtbare_gruppen.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["position"].z < b["position"].z)
	for index in sichtbare_gruppen.size():
		var daten: Dictionary = sichtbare_gruppen[index]
		var position: Vector3 = daten["position"] + Vector3(0, 3.2, 0)
		for vorher in index:
			var andere: Vector3 = sichtbare_gruppen[vorher]["position"] + Vector3(0, 3.2, 0)
			if Vector2(position.x, position.z).distance_to(Vector2(andere.x, andere.z)) < 3.2:
				position.y += 0.8
		var blase := _gruppenblase(index)
		blase.position = position
		blase.visible = true
		var label := blase.get_node("Anzahl") as Label3D
		label.text = "%d Personen" % int(daten["anzahl"])
	for index in range(sichtbare_gruppen.size(), gruppen_blasen.size()):
		gruppen_blasen[index].visible = false

func _gruppen_wurzel(eltern: Array[int], index: int) -> int:
	while eltern[index] != index:
		eltern[index] = eltern[eltern[index]]
		index = eltern[index]
	return index

func _gruppen_vereinigen(eltern: Array[int], links: int, rechts: int) -> void:
	var links_wurzel := _gruppen_wurzel(eltern, links)
	var rechts_wurzel := _gruppen_wurzel(eltern, rechts)
	if links_wurzel != rechts_wurzel:
		eltern[rechts_wurzel] = links_wurzel

func _gruppenblase(index: int) -> Node3D:
	if index < gruppen_blasen.size():
		return gruppen_blasen[index]
	var blase := Node3D.new()
	blase.name = "Personengruppe%d" % index
	var hintergrund := MeshInstance3D.new()
	var flaeche := QuadMesh.new()
	flaeche.size = Vector2(3.4, 1.0)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.albedo_color = Color(0.05, 0.25, 0.43, 0.82)
	material.render_priority = 0
	flaeche.material = material
	hintergrund.mesh = flaeche
	hintergrund.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blase.add_child(hintergrund)
	var label := Label3D.new()
	label.name = "Anzahl"
	label.position = Vector3(0, 0, 0.06)
	label.font_size = 52
	label.pixel_size = 0.013
	label.modulate = Color.WHITE
	label.outline_modulate = Color(0.02, 0.08, 0.13, 1.0)
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	blase.add_child(label)
	patienten_welt.add_child(blase)
	gruppen_blasen.append(blase)
	return blase

func _baue_steuerung() -> void:
	STEUERUNG.bauen(self)

func _baumodus_umschalten() -> void:
	baumodus = true
	raum_ziehen = false
	if laeuft and simulation_bereit:
		simulation.Pausieren()
	var meldung: String = bau_fenster.vorbereiten(praxis_layout.als_json_text(), praxis_layout.standard_json_text())
	if not meldung.is_empty():
		status_label.text = meldung
		baumodus = false
		return
	_bau_dialog_vorschau(bau_fenster.entwurf.daten)
	bau_fenster.popup_centered()
	_layout_anzeigen()

func _bau_dialog_vorschau(daten: Dictionary) -> void:
	bau_vorschau_daten = daten
	if bau_vorschau_geplant:
		return
	bau_vorschau_geplant = true
	get_tree().create_timer(0.06).timeout.connect(_bau_vorschau_anwenden)

func _bau_vorschau_anwenden() -> void:
	bau_vorschau_geplant = false
	if bau_vorschau_daten.is_empty():
		return
	layout_daten = bau_vorschau_daten
	if is_instance_valid(praxis_3d):
		praxis_3d.layout_daten = layout_daten
		praxis_3d.build_layout()

func _bau_dialog_uebernehmen(json_text: String) -> void:
	var ergebnis := _bau_entwurf_vorbereiten(json_text)
	var entwurf = ergebnis["entwurf"]
	var meldung := String(ergebnis["fehler"])
	if meldung.is_empty():
		meldung = entwurf.speichern()
	if not meldung.is_empty():
		status_label.text = meldung
		bau_fenster.meldung.text = meldung
		bau_fenster.meldung.add_theme_color_override("font_color", Color("#a12626"))
		return
	get_tree().reload_current_scene()

func _bau_entwurf_vorbereiten(json_text: String) -> Dictionary:
	var entwurf = PRAXIS_LAYOUT.new()
	var meldung: String = entwurf.aus_json_text(json_text, "Baumodus")
	if meldung.is_empty() and offline_modus:
		if not simulation_bereit:
			meldung = "Die Offline-Simulation muss vor dem Umbau gueltig geladen sein."
		else:
			# Neue Personen erhalten auch beim Bauen ihre Qualifikationen aus den Vorlagen.
			var plan: Dictionary = PERSONAL_VERWALTUNG.baumodus_planen(praxis_layout.daten, entwurf.daten, personal_plan, personal_vorlagen)
			meldung = String(plan["fehler"])
			if meldung.is_empty():
				entwurf.daten["offline_personal"] = plan["konfiguration"]
	return {"fehler": meldung, "entwurf": entwurf}

func _bau_dialog_verwerfen() -> void:
	baumodus = false
	bau_vorschau_daten = {}
	layout_daten = praxis_layout.daten
	_praxis_vorschau_aktualisieren()
	_layout_anzeigen()

func _bau_dialog_zurueckgesetzt(standard_json: String) -> void:
	baumodus = false
	bau_fenster.hide()
	var meldung: String = praxis_layout.aus_json_text(standard_json, "Standardlayout")
	if meldung.is_empty():
		meldung = praxis_layout.speichern()
	if not meldung.is_empty():
		status_label.text = meldung
		return
	# Die gesamte Visualisierung neu laden, damit neben dem Grundriss auch
	# Moebel, Personal, Tueren, Leuchten und Wege den gespeicherten Stand nutzen.
	get_tree().call_deferred("reload_current_scene")

func _raum_hinzufuegen(typ: String) -> void:
	var versatz := Vector2((praxis_layout.raeume.size() % 5) * 1.0 - 2.0,
		(praxis_layout.raeume.size() % 3) * 1.0 - 1.0)
	praxis_layout.hinzufuegen(typ, versatz)
	ausgewaehlter_raum = praxis_layout.raeume.size() - 1
	_praxis_vorschau_aktualisieren()
	_layout_anzeigen()

func _raum_entfernen() -> void:
	if ausgewaehlter_raum < 0:
		bau_status.text = "Bitte zuerst einen Raum anklicken."
		return
	praxis_layout.entfernen(ausgewaehlter_raum)
	ausgewaehlter_raum = -1
	_praxis_vorschau_aktualisieren()
	_layout_anzeigen()

func _layout_speichern() -> void:
	if praxis_layout.anzahl("Arzt") < 1 or praxis_layout.anzahl("Schwester") < 1 or praxis_layout.anzahl("Rezeption") < 1 or praxis_layout.anzahl("Wartezimmer") < 1:
		bau_status.text = "Mindestens je ein Raumtyp wird benötigt."
		return
	var fehler_text: String = praxis_layout.speichern()
	if not fehler_text.is_empty():
		bau_status.text = fehler_text
		return
	bau_status.text = "Gespeichert. Praxis wird aus der JSON-Konfiguration neu aufgebaut."
	get_tree().reload_current_scene()

func _uebernehme_darstellungsplan(plan: Array) -> void:
	var zugeordneter_plan: Array = []
	for ereignis in plan:
		zugeordneter_plan.append(_ereignis_mit_layoutziel(ereignis))
	timeline.laden(zugeordneter_plan)
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
	simulationsminuten_pro_sekunde = float(zustand.get("minutenProSekunde", simulationsminuten_pro_sekunde))
	speed_slider.set_value_no_signal(geschwindigkeit)
	speed_label.text = "Geschwindigkeit: %.2fx" % geschwindigkeit
	play_button.text = ("Pause" if offline_modus else "Stop") if laeuft else "Start"
	letzter_trace_status = "%s: %d Patienten, %d Ereignisse. %s" % ["Offline" if offline_modus else "WebSocket", patienten.size(), live_ereignisse, String(zustand.get("status", ""))]
	_aktualisiere_status()
	if not laeuft:
		_aktualisiere_patienten(0.0)
	queue_redraw()

func _simulation_ereignis(ereignis: Dictionary) -> void:
	# Ereigniskette: SimulationsDaten.LogEvent -> C#-Bridge -> dieses Signal -> Timeline -> Figur.
	# PatientenTimeline wertet "betritt_klinik" aus; sie berechnet keine eigenen Ankunftszeiten.
	var zugeordnet := _ereignis_mit_layoutziel(ereignis)
	ereignisse.append(zugeordnet)
	# Nur bereits vom Kern erzeugte Ereignisse werden dargestellt.
	timeline.ereignis_hinzufuegen(zugeordnet)
	patienten = timeline.patienten
	_aktualisiere_patienten(0.0)

func _ereignis_mit_layoutziel(ereignis: Dictionary) -> Dictionary:
	var ergebnis: Dictionary = ereignis.duplicate(true)
	if not String(ergebnis.get("arbeitsplatzId", "")).is_empty():
		return ergebnis
	var rolle := ""
	var personal_nummer := 0
	if int(ergebnis.get("arztId", 0)) > 0:
		rolle = "Arzt"
		personal_nummer = int(ergebnis["arztId"])
	elif int(ergebnis.get("schwesterId", 0)) > 0:
		rolle = "Schwester"
		personal_nummer = int(ergebnis["schwesterId"])
	if rolle.is_empty():
		return ergebnis
	var arbeitsplatz: Dictionary = timeline.arbeitsplatz_fuer_personal(rolle, personal_nummer)
	if not arbeitsplatz.is_empty():
		ergebnis["arbeitsplatzId"] = String(arbeitsplatz["id"])
		ergebnis["raumId"] = String(arbeitsplatz["raum_id"])
	return ergebnis

func _aktualisiere_status() -> void:
	var sekunden := int(laufzeit * 60.0)
	var praxis_sekunden := sekunden + 8 * 3600
	zeit_label.text = "Simulation: %02d:%02d:%02d | Praxis: %02d:%02d:%02d" % [sekunden / 3600, (sekunden / 60) % 60, sekunden % 60, (praxis_sekunden / 3600) % 24, (praxis_sekunden / 60) % 60, praxis_sekunden % 60]
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
