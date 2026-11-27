extends RefCounted
## Gemeinsames Modell fuer JSON, 3D-Generator, Baumodus und SimSharp-Raumkapazitaeten.

const PROJEKT_DATEI := "res://praxis-layout.json"
const STANDARD_DATEI := "res://praxis-layout-standard.json"
const DATEINAME := "praxis-layout.json"
const TYPEN := ["Arzt", "Schwester", "Wartezimmer", "Rezeption", "Flur"]
const EDITIERBARE_TYPEN := ["Arzt", "Schwester", "Wartezimmer", "Rezeption"]
const RAUM_WEGE := preload("res://Raum3D/RaumWege.gd")
var daten: Dictionary = {}
var raeume: Array = []
var weg_berechnung = RAUM_WEGE.new()

func laden(pfad := "") -> String:
	var quelle := konfigurationspfad() if pfad.is_empty() else pfad
	if not FileAccess.file_exists(quelle):
		return "Praxislayout fehlt: " + quelle
	return aus_json_text(FileAccess.get_file_as_string(quelle), quelle)

func aus_json_text(text: String, quelle := "Eingabe") -> String:
	var json := JSON.new()
	var parse_fehler := json.parse(text)
	if parse_fehler != OK or not json.data is Dictionary:
		return "Praxislayout ist kein gueltiges JSON: %s, Zeile %d (%s)" % [quelle, json.get_error_line(), json.get_error_message()]
	var vorher := daten
	daten = (json.data as Dictionary).duplicate(true)
	var fehler := validieren()
	if not fehler.is_empty():
		daten = vorher
		return "Ungueltiges Praxislayout:\n" + "\n".join(fehler)
	raeume = daten["raeume"]
	return ""

func als_json_text() -> String:
	return JSON.stringify(daten, "  ")

func standard_json_text() -> String:
	return FileAccess.get_file_as_string(STANDARD_DATEI) if FileAccess.file_exists(STANDARD_DATEI) else ""

func baumodus_vorbereiten() -> void:
	# Alte Wandsegmente waren nicht an Raeume gekoppelt und konnten deshalb beim
	# Drag-and-drop stehen bleiben. Im Baumodus wird der Entwurf einmalig in ein
	# vollstaendig raumbasiertes Modell ueberfuehrt.
	var aussentueren: Array = []
	for tuer in daten["tueren"]:
		if "Draussen" in tuer.get("verbindung", []):
			aussentueren.append(tuer.duplicate(true))
	daten["waende"] = []
	daten["tueren"] = aussentueren
	for raum in raeume:
		raum["waende"] = []
		raum["tueren"] = []
	for index in raeume.size():
		if String(raeume[index].get("typ", "")) == "Flur":
			continue
		raeume[index]["automatisch_gebaut"] = true
		_raumwaende_aktualisieren(index)
		_automatische_tuer_sicherstellen(index)
		_raumkapazitaet_aktualisieren(index)
		_raumzugang_aktualisieren(index)
	_aussentueren_zuordnen()

func speichern(pfad := "") -> String:
	var ziel := konfigurationspfad() if pfad.is_empty() else pfad
	var fehler := validieren()
	if not fehler.is_empty():
		return "Layout nicht gespeichert:\n" + "\n".join(fehler)
	var datei := FileAccess.open(ziel, FileAccess.WRITE)
	if datei == null:
		return "Praxislayout kann nicht gespeichert werden: " + ziel
	datei.store_string(JSON.stringify(daten, "  "))
	datei.close()
	return ""

func konfigurationspfad() -> String:
	# Im Projekt wird die sichtbare JSON im Projektordner verwendet. In einem
	# Export liegt dieselbe frei editierbare Datei neben der Anwendung.
	if OS.has_feature("editor"):
		return PROJEKT_DATEI
	return OS.get_executable_path().get_base_dir().path_join(DATEINAME)

func validieren() -> PackedStringArray:
	var fehler := PackedStringArray()
	if int(daten.get("schema_version", 0)) != 2:
		fehler.append("schema_version muss 2 sein")
	for feld in ["boden", "raeume", "tueren", "waende", "stationen", "beschriftungen", "arbeitsplaetze", "warteplaetze", "ausstattung", "statusleuchten"]:
		if not daten.has(feld):
			fehler.append("Pflichtfeld fehlt: " + feld)
	if not fehler.is_empty():
		return fehler
	var ids := {}
	for raum in daten["raeume"]:
		var id := String(raum.get("id", ""))
		if id.is_empty() or ids.has(id):
			fehler.append("Fehlende oder doppelte Raum-ID: " + id)
		ids[id] = true
		if String(raum.get("typ", "")) not in TYPEN:
			fehler.append("Unbekannter Raumtyp in " + id)
		if not _zahlen(raum.get("position", []), 3) or not _positive_groesse(raum.get("groesse", [])):
			fehler.append("Ungueltige Position oder Groesse in " + id)
		if raum.has("grundriss"):
			var polygon: Array = raum["grundriss"]
			if polygon.size() < 3 or polygon.any(func(p): return not _zahlen(p, 2)):
				fehler.append("Ungueltiger polygonaler Grundriss in " + id)
			else:
				var polygon_punkte := PackedVector2Array()
				for punkt in polygon:
					polygon_punkte.append(Vector2(float(punkt[0]), float(punkt[1])))
				if Geometry2D.triangulate_polygon(polygon_punkte).is_empty():
					fehler.append("Polygon kann nicht als Raumflaeche erzeugt werden: " + id)
	for gruppe in ["arbeitsplaetze", "warteplaetze", "ausstattung", "statusleuchten"]:
		var gruppen_ids := {}
		for eintrag in daten[gruppe]:
			var id := String(eintrag.get("id", ""))
			if id.is_empty() or gruppen_ids.has(id):
				fehler.append("Fehlende oder doppelte ID in " + gruppe + ": " + id)
			gruppen_ids[id] = true
			if not ids.has(String(eintrag.get("raum_id", ""))):
				fehler.append("Unbekannte Raum-ID in %s: %s" % [gruppe, id])
			if not _zahlen(eintrag.get("position", []), 2):
				fehler.append("Ungueltige Position in %s: %s" % [gruppe, id])
			if gruppe == "arbeitsplaetze" and String(eintrag.get("qualifikation", "")) not in ["Arzt", "Schwester", "Rezeption"]:
				fehler.append("Ungueltige Arbeitsplatzqualifikation: " + id)
			if gruppe == "arbeitsplaetze" and eintrag.has("patienten_position") and not _zahlen(eintrag["patienten_position"], 2):
				fehler.append("Ungueltige Patientenposition am Arbeitsplatz: " + id)
			if gruppe == "ausstattung" and String(eintrag.get("typ", "")) not in ["box", "stuhl", "tisch", "liege"]:
				fehler.append("Unbekannter Ausstattungstyp: " + id)
			if gruppe == "ausstattung" and String(eintrag.get("typ", "")) == "box" and (not _zahlen(eintrag.get("groesse", []), 3) or not eintrag.has("farbe")):
				fehler.append("Box-Ausstattung braucht groesse und farbe: " + id)
	var tuer_ids := {}
	for tuer in daten["tueren"]:
		var id := String(tuer.get("id", ""))
		if id.is_empty() or tuer_ids.has(id):
			fehler.append("Fehlende oder doppelte Tuer-ID: " + id)
		tuer_ids[id] = true
		if not _zahlen(tuer.get("position", []), 2) or float(tuer.get("breite", 0)) <= 0:
			fehler.append("Ungueltige Tuer: " + id)
		for raum_id in tuer.get("verbindung", []):
			if raum_id != "Draussen" and not ids.has(String(raum_id)):
				fehler.append("Tuer %s verweist auf unbekannten Raum %s" % [id, raum_id])
	for wand in daten["waende"]:
		if not _zahlen(wand.get("von", []), 2) or not _zahlen(wand.get("bis", []), 2):
			fehler.append("Ungueltige Wand: " + String(wand.get("id", "")))
		for tuer_id in wand.get("tueren", []):
			if not tuer_ids.has(String(tuer_id)):
				fehler.append("Wand verweist auf unbekannte Tuer: " + String(tuer_id))
	var referenzen := {"arbeitsplaetze": {}, "warteplaetze": {}, "ausstattung": {}, "statusleuchten": {}}
	for gruppe in referenzen:
		for eintrag in daten[gruppe]:
			referenzen[gruppe][String(eintrag["id"])] = eintrag
	for raum in daten["raeume"]:
		for tuer_id in raum.get("tueren", []):
			if not tuer_ids.has(String(tuer_id)) or raum["id"] not in tuer_ids_daten(daten["tueren"], String(tuer_id)).get("verbindung", []):
				fehler.append("Ungueltiger Tuerverweis in Raum " + String(raum["id"]))
		for gruppe in referenzen:
			for objekt_id in raum.get(gruppe, []):
				if not referenzen[gruppe].has(String(objekt_id)) or String(referenzen[gruppe][String(objekt_id)].get("raum_id", "")) != String(raum["id"]):
					fehler.append("Ungueltiger %s-Verweis in Raum %s: %s" % [gruppe, raum["id"], objekt_id])
	for id in daten["stationen"]:
		if not _zahlen(daten["stationen"][id], 2):
			fehler.append("Ungueltige Stationsposition: " + String(id))
	for beschriftung in daten["beschriftungen"]:
		if not beschriftung.has("text") or not _zahlen(beschriftung.get("position", []), 3):
			fehler.append("Ungueltige Beschriftung: " + String(beschriftung.get("id", "")))
	return fehler

func tuer_ids_daten(tueren: Array, id: String) -> Dictionary:
	for tuer in tueren:
		if String(tuer.get("id", "")) == id:
			return tuer
	return {}

func hinzufuegen(typ: String, position := Vector2.ZERO, form := "Rechteck", neue_groesse := Vector2(4, 4), auf_raster := true) -> Dictionary:
	if typ not in EDITIERBARE_TYPEN:
		return {}
	# Auch kleine Raeume direkt in der gewaehlten Groesse bauen, statt erst 4 x 4 m zu erzwingen.
	var mass := Vector2(maxf(1.0, raster(neue_groesse.x) if auf_raster else neue_groesse.x),
		maxf(1.0, raster(neue_groesse.y) if auf_raster else neue_groesse.y))
	var nummer := anzahl(typ) + 1
	var id := "%s%d" % [typ, nummer]
	while _raum_index(id) >= 0:
		nummer += 1
		id = "%s%d" % [typ, nummer]
	var farben := {"Arzt": "#dcebd6", "Schwester": "#e5ddf3", "Wartezimmer": "#d5e8f7", "Rezeption": "#f3dfc9"}
	var raumposition := Vector2(raster(position.x), raster(position.y)) if auf_raster else position
	var raum := {"id": id, "typ": typ, "name": id, "position": [raumposition.x, 0.02, raumposition.y],
		"groesse": [mass.x, 0.04, mass.y], "farbe": farben[typ], "tueren": [],
		"waende": [], "arbeitsplaetze": [], "warteplaetze": [], "ausstattung": [], "statusleuchten": [],
		"automatisch_gebaut": true, "automatische_ausstattung": true}
	daten["raeume"].append(raum)
	raeume = daten["raeume"]
	if form == "L-Form":
		var mitte := Vector2(float(raum["position"][0]), float(raum["position"][2]))
		raum["form"] = "L-Form"
		raum["grundriss"] = _l_form_punkte(mitte, mass)
	_raumwaende_aktualisieren(raeume.size() - 1)
	_raumstandard_ergaenzen(raeume.size() - 1)
	return raum

func entfernen(index: int) -> void:
	if index < 0 or index >= raeume.size():
		return
	var id := String(raeume[index]["id"])
	for gruppe in ["arbeitsplaetze", "warteplaetze", "ausstattung", "statusleuchten"]:
		daten[gruppe] = (daten[gruppe] as Array).filter(func(e): return String(e.get("raum_id", "")) != id)
	daten["waende"] = (daten["waende"] as Array).filter(func(e): return String(e.get("raum_id", "")) != id)
	daten["tueren"] = (daten["tueren"] as Array).filter(func(e): return id not in e.get("verbindung", []))
	var gueltige_tueren := {}
	for tuer in daten["tueren"]:
		gueltige_tueren[tuer["id"]] = true
	for anderer_raum in daten["raeume"]:
		anderer_raum["tueren"] = (anderer_raum.get("tueren", []) as Array).filter(func(t): return gueltige_tueren.has(t))
	for wand in daten["waende"]:
		wand["tueren"] = (wand.get("tueren", []) as Array).filter(func(t): return gueltige_tueren.has(t))
	daten["beschriftungen"] = (daten.get("beschriftungen", []) as Array).filter(func(e): return String(e.get("raum_id", "")) != id)
	daten["raeume"].remove_at(index)
	raeume = daten["raeume"]

func verschieben(index: int, position: Vector2, auf_raster := true) -> void:
	if index < 0 or index >= raeume.size():
		return
	var raum: Dictionary = raeume[index]
	var alt := Vector2(float(raum["position"][0]), float(raum["position"][2]))
	var neu := Vector2(raster(position.x), raster(position.y)) if auf_raster else position
	var delta := neu - alt
	raum["position"][0] = neu.x
	raum["position"][2] = neu.y
	if raum.has("grundriss"):
		for punkt in raum["grundriss"]:
			punkt[0] = float(punkt[0]) + delta.x
			punkt[1] = float(punkt[1]) + delta.y
	var id := String(raum["id"])
	for gruppe in ["arbeitsplaetze", "warteplaetze", "ausstattung", "statusleuchten"]:
		for eintrag in daten[gruppe]:
			if String(eintrag.get("raum_id", "")) == id:
				eintrag["position"][0] = float(eintrag["position"][0]) + delta.x
				var z_index := 2 if eintrag["position"].size() == 3 else 1
				eintrag["position"][z_index] = float(eintrag["position"][z_index]) + delta.y
				if gruppe == "arbeitsplaetze" and eintrag.has("patienten_position"):
					eintrag["patienten_position"][0] = float(eintrag["patienten_position"][0]) + delta.x
					eintrag["patienten_position"][1] = float(eintrag["patienten_position"][1]) + delta.y
	for beschriftung in daten.get("beschriftungen", []):
		if String(beschriftung.get("raum_id", "")) == id:
			beschriftung["position"][0] = float(beschriftung["position"][0]) + delta.x
			beschriftung["position"][2] = float(beschriftung["position"][2]) + delta.y
	for tuer in daten["tueren"]:
		if "Draussen" in tuer.get("verbindung", []) and id in tuer.get("verbindung", []):
			tuer["position"][0] = float(tuer["position"][0]) + delta.x
			tuer["position"][1] = float(tuer["position"][1]) + delta.y
	_raumwaende_aktualisieren(index)
	_raumzugang_aktualisieren(index)
	_aussentueren_zuordnen()

func position(index: int) -> Vector2:
	return Vector2(float(raeume[index]["position"][0]), float(raeume[index]["position"][2]))

func groesse(index: int) -> Vector2:
	return Vector2(float(raeume[index]["groesse"][0]), float(raeume[index]["groesse"][2]))

func position_mit_fester_tuerkante(index: int, neue_groesse: Vector2) -> Vector2:
	var ergebnis := position(index)
	var bisher := groesse(index)
	var tuer_id := String(raeume[index]["id"]) + "_tuer"
	var seite := ""
	for tuer in daten["tueren"]:
		if String(tuer.get("id", "")) == tuer_id and _flur_id() in tuer.get("verbindung", []):
			seite = String(tuer.get("seite", ""))
			break
	match seite:
		"links": ergebnis.x += (neue_groesse.x - bisher.x) / 2.0
		"rechts": ergebnis.x += (bisher.x - neue_groesse.x) / 2.0
		"hinten": ergebnis.y += (neue_groesse.y - bisher.y) / 2.0
		"vorne": ergebnis.y += (bisher.y - neue_groesse.y) / 2.0
	return ergebnis

func groesse_setzen(index: int, neue_groesse: Vector2, auf_raster := true) -> void:
	if index < 0 or index >= raeume.size():
		return
	var raum: Dictionary = raeume[index]
	var alt := groesse(index)
	var ziel := Vector2(maxf(raster(neue_groesse.x) if auf_raster else neue_groesse.x, 1.0),
		maxf(raster(neue_groesse.y) if auf_raster else neue_groesse.y, 1.0))
	if raum.has("grundriss"):
		var mitte := position(index)
		for punkt in raum["grundriss"]:
			punkt[0] = mitte.x + (float(punkt[0]) - mitte.x) * ziel.x / alt.x
			punkt[1] = mitte.y + (float(punkt[1]) - mitte.y) * ziel.y / alt.y
	raum["groesse"][0] = ziel.x
	raum["groesse"][2] = ziel.y
	_raumwaende_aktualisieren(index)
	_raumkapazitaet_aktualisieren(index)
	_raumzugang_aktualisieren(index)
	_aussentueren_zuordnen()

func geometrie_setzen(index: int, neue_position: Vector2, neue_groesse: Vector2, auf_raster := true) -> String:
	var fehler := platzierung_pruefen(neue_position, neue_groesse, index, auf_raster)
	if not fehler.is_empty():
		return fehler
	verschieben(index, neue_position, auf_raster)
	groesse_setzen(index, neue_groesse, auf_raster)
	return ""

func platzierung_pruefen(neue_position: Vector2, neue_groesse: Vector2, ignorieren := -1, auf_raster := true, form := "Rechteck") -> String:
	var groesse_neu := Vector2(maxf(raster(neue_groesse.x) if auf_raster else neue_groesse.x, 1.0), maxf(raster(neue_groesse.y) if auf_raster else neue_groesse.y, 1.0))
	var position_neu := Vector2(raster(neue_position.x), raster(neue_position.y)) if auf_raster else neue_position
	var kandidat := Rect2(position_neu - groesse_neu / 2.0, groesse_neu)
	var kandidat_polygon := _kandidat_polygon(position_neu, groesse_neu, ignorieren, form)
	var boden_mitte := Vector2(float(daten["boden"]["position"][0]), float(daten["boden"]["position"][2]))
	var boden_groesse := Vector2(float(daten["boden"]["groesse"][0]), float(daten["boden"]["groesse"][2]))
	var boden := Rect2(boden_mitte - boden_groesse / 2.0, boden_groesse)
	for polygon_punkt in kandidat_polygon:
		if not boden.has_point(polygon_punkt) and not boden.grow(0.001).has_point(polygon_punkt):
			return "Der Raum muss vollständig innerhalb des Praxisgrundrisses liegen."
	for index in raeume.size():
		if index == ignorieren:
			continue
		var schnitte := Geometry2D.intersect_polygons(kandidat_polygon, _raum_polygon(index))
		var schnitt_flaeche := 0.0
		for schnitt in schnitte:
			var schnitt_grenzen := _polygon_grenzen(schnitt)
			if schnitt_grenzen.size.x > 0.25 and schnitt_grenzen.size.y > 0.25:
				schnitt_flaeche += _polygon_flaeche(schnitt)
		# Kleine Wandueberdeckungen des Bestandsgrundrisses bleiben erlaubt.
		if schnitt_flaeche > 0.4:
			return "Der Raum überschneidet sich mit „%s“." % String(raeume[index].get("name", raeume[index]["id"]))
	if _anschluss_finden_polygon(kandidat_polygon, ignorieren).is_empty():
		return "Der Raum braucht eine gemeinsame Wandkante direkt zum Flur."
	return ""

func _kandidat_polygon(mitte: Vector2, mass: Vector2, index: int, form: String) -> PackedVector2Array:
	var punkte := PackedVector2Array()
	if index >= 0 and index < raeume.size() and raeume[index].has("grundriss"):
		var alt_mitte := position(index)
		var alt_mass := groesse(index)
		for punkt in raeume[index]["grundriss"]:
			punkte.append(mitte + Vector2((float(punkt[0]) - alt_mitte.x) * mass.x / alt_mass.x,
				(float(punkt[1]) - alt_mitte.y) * mass.y / alt_mass.y))
	elif form == "L-Form":
		for punkt in _l_form_punkte(mitte, mass):
			punkte.append(Vector2(float(punkt[0]), float(punkt[1])))
	else:
		punkte = PackedVector2Array([mitte - mass / 2.0, Vector2(mitte.x + mass.x / 2.0, mitte.y - mass.y / 2.0),
			mitte + mass / 2.0, Vector2(mitte.x - mass.x / 2.0, mitte.y + mass.y / 2.0)])
	return punkte

func _raum_polygon(index: int) -> PackedVector2Array:
	var raum: Dictionary = raeume[index]
	if raum.has("grundriss"):
		var polygon := PackedVector2Array()
		for punkt in raum["grundriss"]:
			polygon.append(Vector2(float(punkt[0]), float(punkt[1])))
		return polygon
	var rect := _raum_rechteck(index)
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])

func _naechster_innenpunkt(index: int, gewuenscht: Vector2) -> Vector2:
	var polygon := _raum_polygon(index)
	if Geometry2D.is_point_in_polygon(gewuenscht, polygon):
		return gewuenscht
	var grenzen := _polygon_grenzen(polygon)
	var bester_punkt := position(index)
	var bester_abstand := INF
	var x := grenzen.position.x + 0.4
	while x <= grenzen.end.x - 0.4:
		var y := grenzen.position.y + 0.4
		while y <= grenzen.end.y - 0.4:
			var kandidat := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(kandidat, polygon) and kandidat.distance_squared_to(gewuenscht) < bester_abstand:
				bester_punkt = kandidat
				bester_abstand = kandidat.distance_squared_to(gewuenscht)
			y += 0.4
		x += 0.4
	return bester_punkt

func _flaeche_liegt_im_raum(index: int, mitte: Vector2, halbe_breite: float, halbe_tiefe: float) -> bool:
	var polygon := _raum_polygon(index)
	var pruefpunkte := [mitte,
		mitte + Vector2(-halbe_breite, -halbe_tiefe), mitte + Vector2(halbe_breite, -halbe_tiefe),
		mitte + Vector2(halbe_breite, halbe_tiefe), mitte + Vector2(-halbe_breite, halbe_tiefe),
		mitte + Vector2(0, -halbe_tiefe), mitte + Vector2(halbe_breite, 0),
		mitte + Vector2(0, halbe_tiefe), mitte + Vector2(-halbe_breite, 0)]
	return pruefpunkte.all(func(punkt): return Geometry2D.is_point_in_polygon(punkt, polygon))

func _naechster_flaechenpunkt(index: int, gewuenscht: Vector2, halbe_breite: float, halbe_tiefe: float) -> Vector2:
	if _flaeche_liegt_im_raum(index, gewuenscht, halbe_breite, halbe_tiefe):
		return gewuenscht
	var grenzen := _polygon_grenzen(_raum_polygon(index))
	var bester_punkt := _naechster_innenpunkt(index, gewuenscht)
	var bester_abstand := INF
	var x := grenzen.position.x + halbe_breite + 0.1
	while x <= grenzen.end.x - halbe_breite - 0.1:
		var y := grenzen.position.y + halbe_tiefe + 0.1
		while y <= grenzen.end.y - halbe_tiefe - 0.1:
			var kandidat := Vector2(x, y)
			if _flaeche_liegt_im_raum(index, kandidat, halbe_breite, halbe_tiefe) and kandidat.distance_squared_to(gewuenscht) < bester_abstand:
				bester_punkt = kandidat
				bester_abstand = kandidat.distance_squared_to(gewuenscht)
			y += 0.25
		x += 0.25
	return bester_punkt

func _polygon_flaeche(polygon: PackedVector2Array) -> float:
	var summe := 0.0
	for index in polygon.size():
		summe += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	return absf(summe) / 2.0

func _raum_rechteck(index: int) -> Rect2:
	return Rect2(position(index) - groesse(index) / 2.0, groesse(index))

func _anschluss_finden(kandidat: Rect2, ignorieren := -1) -> Dictionary:
	var polygon := PackedVector2Array([kandidat.position, Vector2(kandidat.end.x, kandidat.position.y),
		kandidat.end, Vector2(kandidat.position.x, kandidat.end.y)])
	return _anschluss_finden_polygon(polygon, ignorieren)

func _anschluss_finden_polygon(kandidat: PackedVector2Array, ignorieren := -1) -> Dictionary:
	var beste := {}
	var bester_abstand := INF
	var grenzen := _polygon_grenzen(kandidat)
	var mitte := grenzen.get_center()
	for index in raeume.size():
		if index == ignorieren:
			continue
		var raum_id := String(raeume[index]["id"])
		if String(raeume[index].get("typ", "")) != "Flur":
			continue
		var info := _gemeinsame_polygonkante(kandidat, _raum_polygon(index), mitte)
		if not info.is_empty() and float(info["abstand"]) < bester_abstand:
			bester_abstand = float(info["abstand"])
			beste = {"raum_id": raum_id, "seite": info["seite"], "tuer_position": info["tuer_position"]}
	return beste

func hat_direkten_fluranschluss(index: int) -> bool:
	if index < 0 or index >= raeume.size() or String(raeume[index].get("typ", "")) == "Flur":
		return true
	return not _anschluss_finden_polygon(_raum_polygon(index), index).is_empty()

func _gemeinsame_polygonkante(a: PackedVector2Array, b: PackedVector2Array, a_mitte: Vector2) -> Dictionary:
	var beste := {}
	for a_index in a.size():
		var a1 := a[a_index]
		var a2 := a[(a_index + 1) % a.size()]
		var a_horizontal := is_equal_approx(a1.y, a2.y)
		var a_vertikal := is_equal_approx(a1.x, a2.x)
		if not a_horizontal and not a_vertikal:
			continue
		for b_index in b.size():
			var b1 := b[b_index]
			var b2 := b[(b_index + 1) % b.size()]
			var abstand := INF
			var ueberlappung := 0.0
			if a_horizontal and is_equal_approx(b1.y, b2.y):
				abstand = absf(a1.y - b1.y)
				ueberlappung = minf(maxf(a1.x, a2.x), maxf(b1.x, b2.x)) - maxf(minf(a1.x, a2.x), minf(b1.x, b2.x))
			elif a_vertikal and is_equal_approx(b1.x, b2.x):
				abstand = absf(a1.x - b1.x)
				ueberlappung = minf(maxf(a1.y, a2.y), maxf(b1.y, b2.y)) - maxf(minf(a1.y, a2.y), minf(b1.y, b2.y))
			if abstand <= 0.35 and ueberlappung >= 1.5 and (beste.is_empty() or abstand < float(beste["abstand"])):
				var kantenmitte := (a1 + a2) / 2.0
				var seite := "hinten" if a_horizontal and kantenmitte.y <= a_mitte.y else "vorne"
				var tuer_position := kantenmitte
				if a_vertikal:
					seite = "links" if kantenmitte.x <= a_mitte.x else "rechts"
					var von_y := maxf(minf(a1.y, a2.y), minf(b1.y, b2.y))
					var bis_y := minf(maxf(a1.y, a2.y), maxf(b1.y, b2.y))
					tuer_position = Vector2(a1.x, (von_y + bis_y) / 2.0)
				else:
					var von_x := maxf(minf(a1.x, a2.x), minf(b1.x, b2.x))
					var bis_x := minf(maxf(a1.x, a2.x), maxf(b1.x, b2.x))
					tuer_position = Vector2((von_x + bis_x) / 2.0, a1.y)
				beste = {"seite": seite, "abstand": abstand, "ueberlappung": ueberlappung, "tuer_position": tuer_position}
	return beste

func _polygon_grenzen(polygon: PackedVector2Array) -> Rect2:
	var min_punkt := polygon[0]
	var max_punkt := polygon[0]
	for punkt in polygon:
		min_punkt.x = minf(min_punkt.x, punkt.x)
		min_punkt.y = minf(min_punkt.y, punkt.y)
		max_punkt.x = maxf(max_punkt.x, punkt.x)
		max_punkt.y = maxf(max_punkt.y, punkt.y)
	return Rect2(min_punkt, max_punkt - min_punkt)

func _gemeinsame_kante(a: Rect2, b: Rect2) -> Dictionary:
	const TOLERANZ := 0.35
	var x_ueberlappung := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
	var y_ueberlappung := minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y)
	var kandidaten := [
		{"seite": "links", "abstand": absf(a.position.x - b.end.x), "ueberlappung": y_ueberlappung},
		{"seite": "rechts", "abstand": absf(a.end.x - b.position.x), "ueberlappung": y_ueberlappung},
		{"seite": "hinten", "abstand": absf(a.position.y - b.end.y), "ueberlappung": x_ueberlappung},
		{"seite": "vorne", "abstand": absf(a.end.y - b.position.y), "ueberlappung": x_ueberlappung}
	]
	var beste := {}
	for kandidat in kandidaten:
		if float(kandidat["abstand"]) <= TOLERANZ and float(kandidat["ueberlappung"]) >= 1.5:
			if beste.is_empty() or float(kandidat["abstand"]) < float(beste["abstand"]):
				beste = kandidat
	return beste

func _erreichbare_raum_ids(ignorieren := -1) -> Dictionary:
	var erreichbar := {}
	for index in raeume.size():
		if index != ignorieren and String(raeume[index].get("typ", "")) == "Flur":
			erreichbar[String(raeume[index]["id"])] = true
	var geaendert := true
	while geaendert:
		geaendert = false
		for tuer in daten["tueren"]:
			var verbindung: Array = tuer.get("verbindung", [])
			if verbindung.size() < 2:
				continue
			var a := String(verbindung[0])
			var b := String(verbindung[1])
			if _raum_index(a) == ignorieren or _raum_index(b) == ignorieren:
				continue
			if erreichbar.has(a) and not erreichbar.has(b) and b != "Draussen":
				erreichbar[b] = true
				geaendert = true
			elif erreichbar.has(b) and not erreichbar.has(a) and a != "Draussen":
				erreichbar[a] = true
				geaendert = true
	return erreichbar

func _raumwaende_aktualisieren(index: int) -> void:
	if index < 0 or index >= raeume.size():
		return
	var raum: Dictionary = raeume[index]
	var raum_id := String(raum["id"])
	var mitte := position(index)
	var mass := groesse(index)
	var links := mitte.x - mass.x / 2.0
	var rechts := mitte.x + mass.x / 2.0
	var hinten := mitte.y - mass.y / 2.0
	var vorne := mitte.y + mass.y / 2.0
	var kanten: Array = []
	if raum.has("grundriss"):
		var punkte: Array = raum["grundriss"]
		for punkt_index in punkte.size():
			kanten.append({"id": raum_id + "_wand_" + str(punkt_index), "von": punkte[punkt_index].duplicate(),
				"bis": punkte[(punkt_index + 1) % punkte.size()].duplicate()})
	else:
		kanten = [
			{"id": raum_id + "_wand_hinten", "von": [links, hinten], "bis": [rechts, hinten]},
			{"id": raum_id + "_wand_rechts", "von": [rechts, hinten], "bis": [rechts, vorne]},
			{"id": raum_id + "_wand_vorne", "von": [rechts, vorne], "bis": [links, vorne]},
			{"id": raum_id + "_wand_links", "von": [links, vorne], "bis": [links, hinten]}]
	var vorhandene := {}
	for wand in daten["waende"]:
		if String(wand.get("raum_id", "")) == raum_id:
			vorhandene[String(wand["id"])] = wand
	var wand_ids: Array = []
	for kante in kanten:
		var wand_id := String(kante["id"])
		wand_ids.append(wand_id)
		var wand: Dictionary
		if vorhandene.has(wand_id):
			wand = vorhandene[wand_id]
		else:
			wand = {"id": wand_id, "raum_id": raum_id, "tueren": []}
			daten["waende"].append(wand)
		wand["von"] = kante["von"]
		wand["bis"] = kante["bis"]
		wand["raum_id"] = raum_id
		if not wand.has("tueren"):
			wand["tueren"] = []
	raum["waende"] = wand_ids

func _raumstandard_ergaenzen(index: int) -> void:
	var raum: Dictionary = raeume[index]
	var raum_id := String(raum["id"])
	_automatische_tuer_sicherstellen(index)
	var typ := String(raum["typ"])
	if typ in ["Arzt", "Schwester", "Rezeption"]:
		var basis := typ.to_lower()
		var arbeitsplatz_id := _freie_id(basis + "_", daten["arbeitsplaetze"])
		var arbeitsplatz := {"id": arbeitsplatz_id, "raum_id": raum_id,
			"qualifikation": typ, "position": [0.0, 0.0], "patienten_position": [0.0, 0.0],
			"winkel_grad": 0.0, "wegpunkte": []}
		daten["arbeitsplaetze"].append(arbeitsplatz)
		raum["arbeitsplaetze"].append(arbeitsplatz_id)
	_raumzugang_aktualisieren(index)
	_raumkapazitaet_aktualisieren(index)
	_raumzugang_aktualisieren(index)

func _raumkapazitaet_aktualisieren(index: int) -> void:
	if index < 0 or index >= raeume.size():
		return
	var raum: Dictionary = raeume[index]
	var typ := String(raum.get("typ", ""))
	var raum_id := String(raum["id"])
	var mass := groesse(index)
	var mitte := position(index)
	var flaeche := _raum_flaeche(index)
	if typ == "Wartezimmer":
		var anzahl := maxi(1, int(round(flaeche / 5.8)))
		daten["warteplaetze"] = (daten["warteplaetze"] as Array).filter(func(e): return String(e.get("raum_id", "")) != raum_id)
		raum["warteplaetze"] = []
		var kandidaten := _wartezimmer_wandplaetze(index, raum_id)
		var ausgewaehlt: Array[Dictionary] = []
		for kandidat in kandidaten:
			if ausgewaehlt.size() >= anzahl:
				break
			var punkt: Vector2 = kandidat["position"]
			if ausgewaehlt.any(func(sitz): return punkt.distance_to(sitz["position"]) < 0.78):
				continue
			ausgewaehlt.append(kandidat)
		for erzeugt in ausgewaehlt.size():
			var kandidat: Dictionary = ausgewaehlt[erzeugt]
			var punkt: Vector2 = kandidat["position"]
			var lehne: Vector2 = kandidat["lehne"]
			var platz_id := raum_id.to_lower() + "_warte_" + str(erzeugt + 1)
			daten["warteplaetze"].append({"id": platz_id, "raum_id": raum_id,
				"position": [punkt.x, punkt.y], "lehnen_richtung": [lehne.x, lehne.y]})
			raum["warteplaetze"].append(platz_id)
		return
	if typ not in ["Arzt", "Schwester", "Rezeption"]:
		return
	var divisor := 30.0 if typ == "Arzt" else 20.0
	var ziel := maxi(1, int(floor(flaeche / divisor)))
	var vorhandene: Array = []
	for arbeitsplatz in daten["arbeitsplaetze"]:
		if String(arbeitsplatz.get("raum_id", "")) == raum_id:
			vorhandene.append(arbeitsplatz)
	while vorhandene.size() > ziel:
		var entfernt: Dictionary = vorhandene.pop_back()
		var entfernt_id := String(entfernt["id"])
		daten["arbeitsplaetze"] = (daten["arbeitsplaetze"] as Array).filter(func(e): return String(e.get("id", "")) != entfernt_id)
	while vorhandene.size() < ziel:
		var prefix := typ.to_lower() + "_"
		var arbeitsplatz_id := _freie_id(prefix, daten["arbeitsplaetze"])
		var neu := {"id": arbeitsplatz_id, "raum_id": raum_id, "qualifikation": typ,
			"position": [mitte.x, mitte.y], "patienten_position": [mitte.x, mitte.y],
			"winkel_grad": 0.0, "wegpunkte": []}
		daten["arbeitsplaetze"].append(neu)
		vorhandene.append(neu)
	raum["arbeitsplaetze"] = vorhandene.map(func(e): return String(e["id"]))

func _wartezimmer_wandplaetze(index: int, raum_id: String) -> Array[Dictionary]:
	var polygon := _raum_polygon(index)
	var reihen: Array[Dictionary] = []
	for kanten_index in polygon.size():
		var von := polygon[kanten_index]
		var bis := polygon[(kanten_index + 1) % polygon.size()]
		var richtung := (bis - von).normalized()
		var laenge := von.distance_to(bis)
		if laenge < 1.4:
			continue
		var normale := Vector2(-richtung.y, richtung.x)
		var kantenmitte := (von + bis) / 2.0
		if not Geometry2D.is_point_in_polygon(kantenmitte + normale * 0.52, polygon):
			normale = -normale
		var nutzbar := laenge - 1.2
		var sitzanzahl := maxi(1, int(floor(nutzbar / 0.85)) + 1)
		var abstand := 0.0 if sitzanzahl == 1 else minf(0.9, nutzbar / float(sitzanzahl - 1))
		var reihenlaenge := abstand * float(sitzanzahl - 1)
		var start := von + richtung * ((laenge - reihenlaenge) / 2.0)
		var plaetze: Array[Dictionary] = []
		for sitz_index in sitzanzahl:
			var punkt := start + richtung * (abstand * sitz_index) + normale * 0.52
			if _flaeche_liegt_im_raum(index, punkt, 0.38, 0.38) and not _warteplatz_blockiert(raum_id, punkt):
				plaetze.append({"position": punkt, "lehne": -normale})
		if not plaetze.is_empty():
			reihen.append({"laenge": laenge, "plaetze": plaetze})
	# Zuerst die laengsten freien Wandreihen belegen; das ergibt ruhige, reale
	# Sitzreihen statt einzelner Stuehle in Ecken oder mitten im Raum.
	reihen.sort_custom(func(a, b): return a["plaetze"].size() > b["plaetze"].size() if a["plaetze"].size() != b["plaetze"].size() else a["laenge"] > b["laenge"])
	var ergebnis: Array[Dictionary] = []
	for reihe in reihen:
		for platz in reihe["plaetze"]:
			ergebnis.append(platz)
	return ergebnis

func _warteplatz_blockiert(raum_id: String, punkt: Vector2) -> bool:
	for tuer in daten["tueren"]:
		if raum_id in tuer.get("verbindung", []):
			var tuerpunkt := Vector2(float(tuer["position"][0]), float(tuer["position"][1]))
			if punkt.distance_to(tuerpunkt) < 1.15:
				return true
	for objekt in daten["ausstattung"]:
		if String(objekt.get("raum_id", "")) != raum_id:
			continue
		var position3: Array = objekt.get("position", [])
		if position3.size() < 3:
			continue
		var objektpunkt := Vector2(float(position3[0]), float(position3[2]))
		var halbe_breite := 0.6
		var halbe_tiefe := 0.6
		if String(objekt.get("typ", "")) == "box" and objekt.get("groesse", []).size() >= 3:
			halbe_breite = float(objekt["groesse"][0]) / 2.0 + 0.45
			halbe_tiefe = float(objekt["groesse"][2]) / 2.0 + 0.45
		if absf(punkt.x - objektpunkt.x) < halbe_breite and absf(punkt.y - objektpunkt.y) < halbe_tiefe:
			return true
	return false

func _automatische_tuer_sicherstellen(index: int) -> void:
	var raum: Dictionary = raeume[index]
	var raum_id := String(raum["id"])
	var tuer_id := raum_id + "_tuer"
	var vorhanden := false
	for tuer in daten["tueren"]:
		if String(tuer.get("id", "")) == tuer_id:
			vorhanden = true
			break
	if not vorhanden:
		daten["tueren"].append({"id": tuer_id, "raum_id": raum_id, "breite": 1.5,
			"position": [0.0, 0.0], "verbindung": [raum_id, _flur_id()]})
	if tuer_id not in raum["tueren"]:
		raum["tueren"].append(tuer_id)
	var flur_index := _raum_index(_flur_id())
	if flur_index >= 0 and tuer_id not in raeume[flur_index].get("tueren", []):
		raeume[flur_index]["tueren"].append(tuer_id)

func _aussentueren_zuordnen() -> void:
	for tuer in daten["tueren"]:
		if "Draussen" not in tuer.get("verbindung", []):
			continue
		var raum_id := ""
		for verbunden in tuer["verbindung"]:
			if String(verbunden) != "Draussen":
				raum_id = String(verbunden)
		var index := _raum_index(raum_id)
		if index < 0:
			continue
		if String(tuer["id"]) not in raeume[index]["tueren"]:
			raeume[index]["tueren"].append(String(tuer["id"]))
		var punkt := Vector2(float(tuer["position"][0]), float(tuer["position"][1]))
		var mitte := position(index)
		var mass := groesse(index)
		var abstaende := {
			"links": absf(punkt.x - (mitte.x - mass.x / 2.0)),
			"rechts": absf(punkt.x - (mitte.x + mass.x / 2.0)),
			"hinten": absf(punkt.y - (mitte.y - mass.y / 2.0)),
			"vorne": absf(punkt.y - (mitte.y + mass.y / 2.0))}
		var seite := "vorne"
		for kandidat in abstaende:
			if float(abstaende[kandidat]) < float(abstaende[seite]):
				seite = kandidat
		match seite:
			"links": punkt = Vector2(mitte.x - mass.x / 2.0, clampf(punkt.y, mitte.y - mass.y / 2.0 + 0.8, mitte.y + mass.y / 2.0 - 0.8))
			"rechts": punkt = Vector2(mitte.x + mass.x / 2.0, clampf(punkt.y, mitte.y - mass.y / 2.0 + 0.8, mitte.y + mass.y / 2.0 - 0.8))
			"hinten": punkt = Vector2(clampf(punkt.x, mitte.x - mass.x / 2.0 + 0.8, mitte.x + mass.x / 2.0 - 0.8), mitte.y - mass.y / 2.0)
			"vorne": punkt = Vector2(clampf(punkt.x, mitte.x - mass.x / 2.0 + 0.8, mitte.x + mass.x / 2.0 - 0.8), mitte.y + mass.y / 2.0)
		tuer["position"] = [punkt.x, punkt.y]
		var wand_id := _naechste_wand_id(raum_id, punkt)
		for wand in daten["waende"]:
			if String(wand["id"]) == wand_id and String(tuer["id"]) not in wand["tueren"]:
				wand["tueren"].append(String(tuer["id"]))

func _raumzugang_aktualisieren(index: int) -> void:
	if index < 0 or index >= raeume.size():
		return
	var raum: Dictionary = raeume[index]
	if not bool(raum.get("automatisch_gebaut", false)):
		return
	var mitte := position(index)
	var mass := groesse(index)
	var anschluss := _anschluss_finden_polygon(_raum_polygon(index), index)
	var tuer_id := String(raum["id"]) + "_tuer"
	if anschluss.is_empty():
		daten["tueren"] = (daten["tueren"] as Array).filter(func(tuer): return String(tuer.get("id", "")) != tuer_id)
		for anderer_raum in raeume:
			anderer_raum["tueren"] = (anderer_raum.get("tueren", []) as Array).filter(func(id): return String(id) != tuer_id)
		for wand in daten["waende"]:
			wand["tueren"] = (wand.get("tueren", []) as Array).filter(func(id): return String(id) != tuer_id)
		return
	_automatische_tuer_sicherstellen(index)
	var seite := String(anschluss.get("seite", "vorne"))
	var tuer_position := Vector2(mitte.x, mitte.y + mass.y / 2.0)
	var innen_richtung := Vector2(0, -1)
	match seite:
		"links":
			tuer_position = Vector2(mitte.x - mass.x / 2.0, mitte.y)
			innen_richtung = Vector2(1, 0)
		"rechts":
			tuer_position = Vector2(mitte.x + mass.x / 2.0, mitte.y)
			innen_richtung = Vector2(-1, 0)
		"hinten":
			tuer_position = Vector2(mitte.x, mitte.y - mass.y / 2.0)
			innen_richtung = Vector2(0, 1)
	if anschluss.has("tuer_position"):
		tuer_position = anschluss["tuer_position"]
	var innen := tuer_position + innen_richtung * 0.65
	var aussen := tuer_position - innen_richtung * 0.65
	var anschluss_id := String(anschluss.get("raum_id", _flur_id()))
	var wandlaenge := mass.y if seite in ["links", "rechts"] else mass.x
	var tuerbreite := clampf(wandlaenge - 0.4, 0.6, 1.5)
	for tuer in daten["tueren"]:
		if String(tuer.get("id", "")) == tuer_id:
			tuer["position"] = [tuer_position.x, tuer_position.y]
			tuer["verbindung"] = [String(raum["id"]), anschluss_id]
			tuer["seite"] = seite
			tuer["breite"] = tuerbreite
	for anderer_raum in raeume:
		if String(anderer_raum["id"]) != String(raum["id"]):
			anderer_raum["tueren"] = (anderer_raum.get("tueren", []) as Array).filter(func(id): return String(id) != tuer_id)
	var anschluss_index := _raum_index(anschluss_id)
	if anschluss_index >= 0 and tuer_id not in raeume[anschluss_index].get("tueren", []):
		raeume[anschluss_index]["tueren"].append(tuer_id)
	_tuer_waenden_zuordnen(tuer_id, [String(raum["id"]), anschluss_id], tuer_position)
	if String(raum.get("typ", "")) == "Wartezimmer":
		# Erst mit der aktualisierten Tuerposition verteilen, damit der Zugang frei bleibt.
		_raumkapazitaet_aktualisieren(index)
		return
	_statusleuchte_aktualisieren(index, tuer_position + innen_richtung * 0.08)
	var arbeitsplatz_ids: Array = raum.get("arbeitsplaetze", [])
	for platz_index in arbeitsplatz_ids.size():
		var arbeitsplatz_id = arbeitsplatz_ids[platz_index]
		for arbeitsplatz in daten["arbeitsplaetze"]:
			if String(arbeitsplatz.get("id", "")) != String(arbeitsplatz_id):
				continue
			var quer_richtung := Vector2(-innen_richtung.y, innen_richtung.x)
			var quer_mass := mass.x if absf(quer_richtung.x) > 0.5 else mass.y
			var abstand := minf(2.2, maxf(1.1, (quer_mass - 1.2) / maxf(1.0, float(arbeitsplatz_ids.size()))))
			var quer_versatz := (float(platz_index) - float(arbeitsplatz_ids.size() - 1) / 2.0) * abstand
			var arbeits_tiefe := 0.0 if String(raum["typ"]) == "Rezeption" else minf(1.7, (mass.y if absf(innen_richtung.y) > 0.5 else mass.x) * 0.28)
			var patienten_tiefe := -minf(2.3, (mass.y if absf(innen_richtung.y) > 0.5 else mass.x) * 0.38) if String(raum["typ"]) == "Rezeption" else 0.0
			var arbeitsposition := _naechster_flaechenpunkt(index, mitte + quer_richtung * quer_versatz + innen_richtung * arbeits_tiefe, 0.45, 0.45)
			var patientenposition := _naechster_flaechenpunkt(index, mitte + quer_richtung * quer_versatz + innen_richtung * patienten_tiefe, 0.45, 0.45)
			# Optional im Layout: Empfangsplaetze entlang der linken Wand lassen
			# die Mitte zwischen Eingang und Flurtuer frei. Auch beim Oeffnen des
			# Baumodus und beim Raumverschieben diese Anordnung erhalten.
			if String(raum["typ"]) == "Rezeption" and String(raum.get("arbeitsplaetze_anordnung", "")) == "linke_wand":
				var grenzen := _polygon_grenzen(_raum_polygon(index))
				var sitzabstand := minf(2.2, maxf(0.8, (grenzen.size.y - 1.8) / maxf(1.0, float(arbeitsplatz_ids.size() - 1))))
				var entlang_wand := (float(platz_index) - float(arbeitsplatz_ids.size() - 1) / 2.0) * sitzabstand
				arbeitsposition = _naechster_flaechenpunkt(index, Vector2(grenzen.position.x + 1.25, grenzen.get_center().y + entlang_wand), 0.45, 0.45)
				patientenposition = _naechster_flaechenpunkt(index, arbeitsposition + Vector2(1.8, 0.0), 0.45, 0.45)
			var blickrichtung := (patientenposition - arbeitsposition).normalized()
			arbeitsplatz["position"] = [arbeitsposition.x, arbeitsposition.y]
			arbeitsplatz["patienten_position"] = [patientenposition.x, patientenposition.y]
			arbeitsplatz["winkel_grad"] = rad_to_deg(atan2(blickrichtung.x, blickrichtung.y))
			var innenweg: Array[Vector2] = weg_berechnung._innenweg(innen, arbeitsposition, _raum_polygon(index))
			var wegpunkte: Array = [[aussen.x, aussen.y]]
			for wegpunkt in innenweg:
				wegpunkte.append([wegpunkt.x, wegpunkt.y])
			arbeitsplatz["wegpunkte"] = wegpunkte
	_arbeitsplatz_ausstattung_aktualisieren(index)

func _statusleuchte_aktualisieren(index: int, punkt: Vector2) -> void:
	var raum: Dictionary = raeume[index]
	var typ := String(raum.get("typ", ""))
	if typ not in ["Arzt", "Schwester"]:
		return
	var raum_id := String(raum["id"])
	for leuchte in daten["statusleuchten"]:
		if String(leuchte.get("raum_id", "")) == raum_id:
			leuchte["position"] = [punkt.x, 2.15, punkt.y]
			leuchte["station"] = typ
			if String(leuchte["id"]) not in raum.get("statusleuchten", []):
				raum["statusleuchten"].append(String(leuchte["id"]))
			return
	var leuchten_id := raum_id
	if daten["statusleuchten"].any(func(leuchte): return String(leuchte.get("id", "")) == leuchten_id):
		leuchten_id = _freie_id(raum_id + "_leuchte_", daten["statusleuchten"])
	var leuchte := {"id": leuchten_id, "raum_id": raum_id, "station": typ,
		"position": [punkt.x, 2.15, punkt.y], "automatisch_gebaut": true}
	daten["statusleuchten"].append(leuchte)
	raum["statusleuchten"].append(leuchten_id)

func _arbeitsplatz_ausstattung_aktualisieren(index: int) -> void:
	var raum: Dictionary = raeume[index]
	var typ := String(raum.get("typ", ""))
	if typ not in ["Arzt", "Schwester", "Rezeption"]:
		return
	var raum_id := String(raum["id"])
	var vorhandene_ids: Array = raum.get("ausstattung", [])
	var hat_manuelle_ausstattung := false
	for objekt in daten["ausstattung"]:
		if String(objekt.get("raum_id", "")) == raum_id and not bool(objekt.get("automatisch_gebaut", false)):
			hat_manuelle_ausstattung = true
			break
	var bestehende_arbeitsplatzmoebel_verwalten := typ in ["Arzt", "Schwester"]
	if not bool(raum.get("automatische_ausstattung", false)) and hat_manuelle_ausstattung and not bestehende_arbeitsplatzmoebel_verwalten:
		return
	raum["automatische_ausstattung"] = true
	daten["ausstattung"] = (daten["ausstattung"] as Array).filter(func(objekt):
		if String(objekt.get("raum_id", "")) != raum_id:
			return true
		if bool(objekt.get("automatisch_gebaut", false)):
			return false
		var ist_altes_standardmoebel := String(objekt.get("id", "")).begins_with(raum_id.to_lower() + "_ausstattung_")
		return not bestehende_arbeitsplatzmoebel_verwalten or not ist_altes_standardmoebel or String(objekt.get("typ", "")) not in ["tisch", "stuhl", "liege"])
	var manuelle_ids: Array = []
	for objekt_id in vorhandene_ids:
		for objekt in daten["ausstattung"]:
			if String(objekt["id"]) == String(objekt_id):
				manuelle_ids.append(String(objekt_id))
	var neue_ids: Array = manuelle_ids
	for arbeitsplatz_id in raum.get("arbeitsplaetze", []):
		var arbeitsplatz: Dictionary = {}
		for kandidat in daten["arbeitsplaetze"]:
			if String(kandidat["id"]) == String(arbeitsplatz_id):
				arbeitsplatz = kandidat
				break
		if arbeitsplatz.is_empty():
			continue
		var arbeit := Vector2(float(arbeitsplatz["position"][0]), float(arbeitsplatz["position"][1]))
		var patient := arbeit
		if arbeitsplatz.has("patienten_position"):
			patient = Vector2(float(arbeitsplatz["patienten_position"][0]), float(arbeitsplatz["patienten_position"][1]))
		var richtung := (patient - arbeit).normalized()
		if richtung.is_zero_approx():
			richtung = Vector2(0, 1)
		var tischposition := _naechster_flaechenpunkt(index, arbeit + richtung * 0.8, 0.85, 0.48)
		var stuhlposition := _naechster_flaechenpunkt(index, arbeit, 0.43, 0.43)
		var moebel := [
			{"id": String(arbeitsplatz_id) + "_tisch", "typ": "tisch", "position": [tischposition.x, 0.0, tischposition.y]},
			{"id": String(arbeitsplatz_id) + "_stuhl", "typ": "stuhl", "position": [stuhlposition.x, 0.0, stuhlposition.y], "lehnen_richtung": -1.0 if richtung.y < 0 else 1.0}]
		if typ == "Arzt":
			var quer := Vector2(-richtung.y, richtung.x)
			var liegenposition := _naechster_flaechenpunkt(index, patient + quer * 1.4, 0.58, 1.12)
			moebel.append({"id": String(arbeitsplatz_id) + "_liege", "typ": "liege", "position": [liegenposition.x, 0.0, liegenposition.y]})
		for objekt in moebel:
			objekt["raum_id"] = raum_id
			objekt["arbeitsplatz_id"] = String(arbeitsplatz_id)
			objekt["automatisch_gebaut"] = true
			daten["ausstattung"].append(objekt)
			neue_ids.append(String(objekt["id"]))
	raum["ausstattung"] = neue_ids

func _flur_id() -> String:
	for raum in raeume:
		if String(raum.get("typ", "")) == "Flur":
			return String(raum["id"])
	return "Flur"

func _naechste_wand_id(raum_id: String, punkt: Vector2) -> String:
	var beste_id := ""
	var bester_abstand := INF
	for wand in daten["waende"]:
		if String(wand.get("raum_id", "")) != raum_id:
			continue
		var a := Vector2(float(wand["von"][0]), float(wand["von"][1]))
		var b := Vector2(float(wand["bis"][0]), float(wand["bis"][1]))
		var ab := b - a
		var faktor := clampf((punkt - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var abstand := punkt.distance_to(a + ab * faktor)
		if abstand < bester_abstand:
			bester_abstand = abstand
			beste_id = String(wand["id"])
	return beste_id

func _tuer_waenden_zuordnen(tuer_id: String, verbindung: Array, punkt: Vector2) -> void:
	# Eine gemeinsame Raumkante wird in der 3D-Geometrie von beiden Raeumen als
	# Wand erzeugt. Deshalb muss dieselbe Tueroeffnung in beiden Waenden liegen.
	for wand in daten["waende"]:
		wand["tueren"] = (wand.get("tueren", []) as Array).filter(func(id): return String(id) != tuer_id)
	for raum_id_daten in verbindung:
		var raum_id := String(raum_id_daten)
		if raum_id == "Draussen":
			continue
		var wand_id := _naechste_wand_id(raum_id, punkt)
		if wand_id.is_empty():
			continue
		for wand in daten["waende"]:
			if String(wand["id"]) == wand_id and tuer_id not in wand.get("tueren", []):
				wand["tueren"].append(tuer_id)

func _freie_id(prefix: String, eintraege: Array) -> String:
	var nummer := 1
	var ids := {}
	for eintrag in eintraege:
		ids[String(eintrag.get("id", ""))] = true
	while ids.has(prefix + str(nummer)):
		nummer += 1
	return prefix + str(nummer)

func anzahl(typ: String) -> int:
	return raeume.filter(func(r): return String(r.get("typ", "")) == typ).size()

func flaeche(typ: String) -> float:
	var ergebnis := 0.0
	for raum in raeume:
		if String(raum.get("typ", "")) == typ:
			ergebnis += float(raum["groesse"][0]) * float(raum["groesse"][2])
	return ergebnis

func raster(wert: float) -> float:
	return snappedf(wert, float(daten.get("raster", 0.5)))

func _l_form_punkte(mitte: Vector2, mass: Vector2) -> Array:
	var links := mitte.x - mass.x / 2.0
	var rechts := mitte.x + mass.x / 2.0
	var hinten := mitte.y - mass.y / 2.0
	var vorne := mitte.y + mass.y / 2.0
	return [[links, hinten], [rechts, hinten], [rechts, mitte.y], [mitte.x, mitte.y], [mitte.x, vorne], [links, vorne]]

func _raum_flaeche(index: int) -> float:
	var raum: Dictionary = raeume[index]
	if not raum.has("grundriss"):
		return groesse(index).x * groesse(index).y
	var punkte: Array = raum["grundriss"]
	var doppelte_flaeche := 0.0
	for punkt_index in punkte.size():
		var a: Array = punkte[punkt_index]
		var b: Array = punkte[(punkt_index + 1) % punkte.size()]
		doppelte_flaeche += float(a[0]) * float(b[1]) - float(b[0]) * float(a[1])
	return absf(doppelte_flaeche) / 2.0

func _raum_index(id: String) -> int:
	for index in raeume.size():
		if String(raeume[index].get("id", "")) == id:
			return index
	return -1

func _zahlen(werte, minimum: int) -> bool:
	if not werte is Array or werte.size() < minimum:
		return false
	for index in minimum:
		if typeof(werte[index]) not in [TYPE_INT, TYPE_FLOAT]:
			return false
	return true

func _positive_groesse(werte) -> bool:
	return _zahlen(werte, 3) and float(werte[0]) > 0 and float(werte[1]) > 0 and float(werte[2]) > 0
