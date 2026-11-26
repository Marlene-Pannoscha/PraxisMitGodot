extends Control
## Interaktive 2D-Draufsicht auf dasselbe PraxisLayout-Modell.

signal raum_ausgewaehlt(index: int)
signal geometrie_angefordert(index: int, position: Vector2, groesse: Vector2)
signal platzierung_angefordert(typ: String, form: String, position: Vector2)

var modell
var auswahl := -1
var platzierung_typ := ""
var platzierung_form := "Rechteck"
var platzierung_groesse := Vector2(3, 3)
var platzierung_maus := Vector2.ZERO
var platzierung_sichtbar := false
var drag_modus := ""
var drag_start_maus := Vector2.ZERO
var drag_start_position := Vector2.ZERO
var drag_start_groesse := Vector2.ZERO
var drag_ecke := Vector2.ONE
var drag_vorschau_position := Vector2.ZERO
var drag_vorschau_groesse := Vector2.ZERO
var drag_gueltig := true
const RAND := 18.0
const GRIFF := 8.0
const GRIFF_TREFFER := 16.0

func _ready() -> void:
	# Breite Draufsicht, aber flexible Hoehe: Die Dialogaktionen muessen auch
	# auf kleineren Bildschirmen sichtbar bleiben.
	custom_minimum_size = Vector2(600, 300)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Eine zu grosse rote Vorschau darf nicht ueber die danebenliegenden Eingabefelder zeichnen.
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	tooltip_text = "Seitliche Griffe ändern die Breite, obere/untere Griffe die Tiefe.\nEckgriffe ändern beides. Die Wand zum Flur bleibt fest."
	set_process(false)
	mouse_exited.connect(func(): platzierung_sichtbar = false; queue_redraw())

func modell_setzen(neues_modell) -> void:
	modell = neues_modell
	auswahl = clampi(auswahl, -1, modell.raeume.size() - 1)
	queue_redraw()

func platzierung_starten(typ: String, form := "Rechteck", groesse := Vector2(3, 3)) -> void:
	platzierung_typ = typ
	platzierung_form = form
	platzierung_groesse = groesse
	platzierung_sichtbar = false
	drag_modus = ""
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	queue_redraw()

func platzierung_beenden() -> void:
	platzierung_typ = ""
	platzierung_sichtbar = false
	queue_redraw()

func auswahl_setzen(index: int) -> void:
	auswahl = index
	queue_redraw()

func _draw() -> void:
	var hintergrund := Rect2(Vector2.ZERO, size)
	draw_rect(hintergrund, Color("#dce8ee"), true)
	if modell == null or modell.daten.is_empty():
		return
	var boden_rect := _boden_bildschirm_rect()
	draw_rect(boden_rect, Color("#f8fbfd"), true)
	draw_rect(boden_rect, Color("#7893a5"), false, 2.0)
	_raster_zeichnen(boden_rect)
	var farben := {"Arzt": Color("#b8d7b5"), "Schwester": Color("#d5c6e8"),
		"Wartezimmer": Color("#b9d9ec"), "Rezeption": Color("#efd0aa"), "Flur": Color("#e8dfc8")}
	for index in modell.raeume.size():
		var raum: Dictionary = modell.raeume[index]
		var rect := _raum_bildschirm_rect(index)
		if index == auswahl and not drag_modus.is_empty():
			rect = _geometrie_bildschirm_rect(drag_vorschau_position, drag_vorschau_groesse)
		var farbe: Color = farben.get(String(raum.get("typ", "")), Color("#d5dde2"))
		if index == auswahl:
			farbe = Color("#ffe29a")
		var rahmen := Color("#35566d") if index != auswahl else Color("#d48a13")
		if index == auswahl and not drag_gueltig:
			rahmen = Color("#c6342b")
		if raum.has("grundriss") and not (index == auswahl and not drag_modus.is_empty()):
			var polygon := _polygon_bildschirm(raum["grundriss"])
			draw_colored_polygon(polygon, farbe)
			var umriss := polygon
			umriss.append(polygon[0])
			draw_polyline(umriss, rahmen, 3.0 if index == auswahl else 2.0)
		else:
			draw_rect(rect, farbe, true)
			draw_rect(rect, rahmen, false, 3.0 if index == auswahl else 2.0)
		var text := String(raum.get("name", raum["id"]))
		draw_string(get_theme_default_font(), rect.position + Vector2(7, 19), text,
			HORIZONTAL_ALIGNMENT_LEFT, maxf(0, rect.size.x - 12), 13, Color("#18334a"))
		if index == auswahl and String(raum.get("typ", "")) != "Flur":
			for griff in _griffe(rect):
				var punkt: Vector2 = griff["punkt"]
				draw_rect(Rect2(punkt - Vector2.ONE * GRIFF, Vector2.ONE * GRIFF * 2.0), Color("#ffffff"), true)
				draw_rect(Rect2(punkt - Vector2.ONE * GRIFF, Vector2.ONE * GRIFF * 2.0), Color("#d48a13"), false, 2.0)
	if not platzierung_typ.is_empty():
		if platzierung_sichtbar:
			# Dieselben Rasterwerte, Form und Masse wie beim anschliessenden Anlegen verwenden.
			var mitte := Vector2(modell.raster(platzierung_maus.x), modell.raster(platzierung_maus.y))
			var mass := Vector2(modell.raster(platzierung_groesse.x), modell.raster(platzierung_groesse.y))
			var gueltig: bool = modell.platzierung_pruefen(mitte, mass, -1, true, platzierung_form).is_empty()
			var farbe := Color("#27824a") if gueltig else Color("#bc3434")
			var welt_polygon: PackedVector2Array = modell._kandidat_polygon(mitte, mass, -1, platzierung_form)
			var polygon := PackedVector2Array()
			for punkt in welt_polygon:
				polygon.append(_welt_zu_bildschirm(punkt))
			var fuellung := farbe
			fuellung.a = 0.3
			draw_colored_polygon(polygon, fuellung)
			polygon.append(polygon[0])
			draw_polyline(polygon, farbe, 3.0)
		draw_string(get_theme_default_font(), Vector2(28, size.y - 12),
			"%s: %.1f × %.1f m – Raummitte anklicken" % [platzierung_typ, platzierung_groesse.x, platzierung_groesse.y],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#174f75"))

func _gui_input(event: InputEvent) -> void:
	if modell == null:
		return
	if event is InputEventMouseMotion and not platzierung_typ.is_empty():
		platzierung_maus = _bildschirm_zu_welt(event.position)
		platzierung_sichtbar = true
		queue_redraw()
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not platzierung_typ.is_empty():
				platzierung_angefordert.emit(platzierung_typ, platzierung_form, _bildschirm_zu_welt(event.position))
				accept_event()
				return
			var getroffen := -1
			var griff := Vector2.ZERO
			# Die Griffe der Auswahl liegen zur Haelfte AUSSERHALB des Raums.
			# Sie zuerst pruefen, auch wenn dahinter schon ein Nachbarraum liegt.
			if auswahl >= 0 and String(modell.raeume[auswahl].get("typ", "")) != "Flur":
				griff = _getroffener_griff(event.position, _raum_bildschirm_rect(auswahl))
				if griff != Vector2.ZERO:
					getroffen = auswahl
			if getroffen < 0:
				getroffen = _raum_an_bildschirmposition(event.position)
			if getroffen < 0:
				auswahl = -1
				raum_ausgewaehlt.emit(-1)
				queue_redraw()
				return
			auswahl = getroffen
			raum_ausgewaehlt.emit(auswahl)
			if String(modell.raeume[auswahl].get("typ", "")) == "Flur":
				queue_redraw()
				return
			drag_start_maus = _bildschirm_zu_welt(event.position)
			drag_start_position = modell.position(auswahl)
			drag_start_groesse = modell.groesse(auswahl)
			drag_vorschau_position = drag_start_position
			drag_vorschau_groesse = drag_start_groesse
			drag_gueltig = true
			drag_ecke = griff
			drag_modus = "groesse" if drag_ecke != Vector2.ZERO else "verschieben"
			mouse_default_cursor_shape = _griff_cursor(drag_ecke) if drag_ecke != Vector2.ZERO else Control.CURSOR_MOVE
			accept_event()
		else:
			drag_modus = ""
			drag_gueltig = true
			_hover_cursor(event.position)
			queue_redraw()
	elif event is InputEventMouseMotion and not drag_modus.is_empty() and auswahl >= 0:
		var maus_welt := _bildschirm_zu_welt(event.position)
		var delta := maus_welt - drag_start_maus
		if drag_modus == "verschieben":
			# Auch bei Viertelmeter-Mitten den Versatz rastern, nicht die absolute Position.
			drag_vorschau_position = drag_start_position + Vector2(modell.raster(delta.x), modell.raster(delta.y))
			drag_vorschau_groesse = drag_start_groesse
			mouse_default_cursor_shape = Control.CURSOR_MOVE
			geometrie_angefordert.emit(auswahl, drag_vorschau_position, drag_vorschau_groesse)
		else:
			var neue_groesse := drag_start_groesse
			# Nur die gezogene Achse veraendern. Die Mausbewegung wird relativ zum
			# Drag-Start gerastert; kleine Bewegungen versetzen den Raum noch nicht.
			if drag_ecke.x != 0:
				neue_groesse.x = maxf(1.0, drag_start_groesse.x + modell.raster(drag_ecke.x * delta.x))
			if drag_ecke.y != 0:
				neue_groesse.y = maxf(1.0, drag_start_groesse.y + modell.raster(drag_ecke.y * delta.y))
			# Aus der gerasterten Groesse die Mitte ableiten: Gegenkante bleibt exakt fest.
			# Dabei sind auch Viertelmeter fuer die Mitte korrekt (0,5 m / 2).
			var neue_position := drag_start_position + Vector2(drag_ecke.x * (neue_groesse.x - drag_start_groesse.x),
				drag_ecke.y * (neue_groesse.y - drag_start_groesse.y)) / 2.0
			drag_vorschau_position = neue_position
			drag_vorschau_groesse = neue_groesse
			mouse_default_cursor_shape = _griff_cursor(drag_ecke)
			geometrie_angefordert.emit(auswahl, neue_position, neue_groesse)
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion:
		_hover_cursor(event.position)

func geometrie_ergebnis(gueltig: bool) -> void:
	drag_gueltig = gueltig
	if gueltig and auswahl >= 0:
		# Die Vorschau zeigt dieselben Rasterwerte wie das Modell und die Zahlenfelder.
		drag_vorschau_position = modell.position(auswahl)
		drag_vorschau_groesse = modell.groesse(auswahl)
	queue_redraw()

func _raum_an_bildschirmposition(punkt: Vector2) -> int:
	for index in range(modell.raeume.size() - 1, -1, -1):
		if _raum_bildschirm_rect(index).has_point(punkt):
			return index
	return -1

func _griffe(rect: Rect2) -> Array[Dictionary]:
	var ergebnis: Array[Dictionary] = []
	var tuer_seite := ""
	if auswahl >= 0:
		var anschluss: Dictionary = modell._anschluss_finden_polygon(modell._raum_polygon(auswahl), auswahl)
		tuer_seite = String(anschluss.get("seite", ""))
	for richtung in [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(1, 0),
		Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1), Vector2(-1, 0)]:
		var wirksam: Vector2 = richtung
		# Die Flurwand nicht wegziehen: Eckgriffe dort aendern nur die seitliche Ausdehnung.
		if (tuer_seite == "hinten" and richtung.y < 0) or (tuer_seite == "vorne" and richtung.y > 0):
			wirksam.y = 0
		if (tuer_seite == "links" and richtung.x < 0) or (tuer_seite == "rechts" and richtung.x > 0):
			wirksam.x = 0
		if wirksam != Vector2.ZERO:
			ergebnis.append({"punkt": rect.get_center() + Vector2(richtung.x * rect.size.x, richtung.y * rect.size.y) / 2.0,
				"richtung": wirksam})
	return ergebnis

func _getroffener_griff(punkt: Vector2, rect: Rect2) -> Vector2:
	var richtung := Vector2.ZERO
	var bester_abstand := GRIFF_TREFFER
	for griff in _griffe(rect):
		var abstand := punkt.distance_to(griff["punkt"])
		if abstand <= bester_abstand:
			bester_abstand = abstand
			richtung = griff["richtung"]
	return richtung

func _griff_cursor(richtung: Vector2) -> int:
	if richtung.x == 0:
		return Control.CURSOR_VSIZE
	if richtung.y == 0:
		return Control.CURSOR_HSIZE
	return Control.CURSOR_FDIAGSIZE if richtung.x * richtung.y > 0 else Control.CURSOR_BDIAGSIZE

func _hover_cursor(punkt: Vector2) -> void:
	if auswahl >= 0 and String(modell.raeume[auswahl].get("typ", "")) != "Flur":
		var richtung := _getroffener_griff(punkt, _raum_bildschirm_rect(auswahl))
		if richtung != Vector2.ZERO:
			mouse_default_cursor_shape = _griff_cursor(richtung)
			return
	var index := _raum_an_bildschirmposition(punkt)
	mouse_default_cursor_shape = Control.CURSOR_MOVE if index >= 0 and String(modell.raeume[index].get("typ", "")) != "Flur" else Control.CURSOR_ARROW

func _boden_daten() -> Rect2:
	var boden: Dictionary = modell.daten["boden"]
	var mitte := Vector2(float(boden["position"][0]), float(boden["position"][2]))
	var groesse := Vector2(float(boden["groesse"][0]), float(boden["groesse"][2]))
	return Rect2(mitte - groesse / 2.0, groesse)

func _massstab() -> float:
	var boden := _boden_daten()
	return minf((size.x - RAND * 2.0) / boden.size.x, (size.y - RAND * 2.0) / boden.size.y)

func _welt_zu_bildschirm(punkt: Vector2) -> Vector2:
	var boden := _boden_daten()
	var scale := _massstab()
	var ursprung := (size - boden.size * scale) / 2.0
	return ursprung + (punkt - boden.position) * scale

func _bildschirm_zu_welt(punkt: Vector2) -> Vector2:
	var boden := _boden_daten()
	var scale := _massstab()
	var ursprung := (size - boden.size * scale) / 2.0
	return boden.position + (punkt - ursprung) / scale

func _boden_bildschirm_rect() -> Rect2:
	var boden := _boden_daten()
	return Rect2(_welt_zu_bildschirm(boden.position), boden.size * _massstab())

func _raum_bildschirm_rect(index: int) -> Rect2:
	var rect = modell._raum_rechteck(index)
	return Rect2(_welt_zu_bildschirm(rect.position), rect.size * _massstab())

func _geometrie_bildschirm_rect(position: Vector2, groesse: Vector2) -> Rect2:
	return Rect2(_welt_zu_bildschirm(position - groesse / 2.0), groesse * _massstab())

func _polygon_bildschirm(punkte: Array) -> PackedVector2Array:
	var ergebnis := PackedVector2Array()
	for punkt in punkte:
		ergebnis.append(_welt_zu_bildschirm(Vector2(float(punkt[0]), float(punkt[1]))))
	return ergebnis

func _raster_zeichnen(rect: Rect2) -> void:
	var schritt := float(modell.daten.get("raster", 0.5)) * _massstab()
	if schritt < 5.0:
		return
	var x := rect.position.x
	while x <= rect.end.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(0.35, 0.48, 0.56, 0.16), 1.0)
		x += schritt
	var y := rect.position.y
	while y <= rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.35, 0.48, 0.56, 0.16), 1.0)
		y += schritt
