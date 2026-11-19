@tool
extends RefCounted
## Ausgangsdaten der Darstellung. Die Kapazitaeten des SimSharp-Kerns bleiben unveraendert.

const RAUM_LAYOUT = preload("res://Raum3D/RaumLayout.gd")

static func lesen(dateiname: String) -> Dictionary:
	var pfad := "res://Konfiguration/" + dateiname
	if not FileAccess.file_exists(pfad):
		push_error("Konfiguration fehlt: " + pfad)
		return {}
	var json := JSON.new()
	var fehler := json.parse(FileAccess.get_file_as_string(pfad))
	if fehler != OK or not json.data is Dictionary:
		push_error("Ungueltige Konfiguration: " + pfad + ": " + json.get_error_message())
		return {}
	var daten: Dictionary = json.data
	if int(daten.get("schema_version", 0)) != 1:
		push_error("Unbekannte Konfigurationsversion: " + pfad)
		return {}
	return daten

static func layout() -> Dictionary:
	var basis := "Praxislayout/"
	var manifest := lesen(basis + "layout.json")
	if manifest.is_empty():
		return {}
	var daten: Dictionary = manifest.duplicate(true)
	var navigation := lesen(basis + String(manifest["navigation"]))
	var tueren := lesen(basis + String(manifest["tueren"]))
	var waende := lesen(basis + String(manifest["waende"]))
	if navigation.is_empty() or tueren.is_empty() or waende.is_empty():
		return {}
	daten.merge(navigation, true)
	daten["tueren"] = tueren["tueren"]
	daten["waende"] = waende["waende"]
	daten["raeume"] = []
	for gruppe in ["arbeitsplaetze", "warteplaetze", "ausstattung", "statusleuchten"]:
		daten[gruppe] = []
	for datei in manifest["raeume"]:
		var raum := lesen(basis + String(datei))
		if raum.is_empty():
			return {}
		for gruppe in ["arbeitsplaetze", "warteplaetze", "ausstattung", "statusleuchten"]:
			var ids: Array[String] = []
			for eintrag in raum.get(gruppe, []):
				var platz: Dictionary = eintrag.duplicate(true)
				platz["raum_id"] = raum["id"]
				daten[gruppe].append(platz)
				if gruppe in ["arbeitsplaetze", "warteplaetze"]:
					ids.append(String(platz["id"]))
			if gruppe in ["arbeitsplaetze", "warteplaetze"]:
				raum[gruppe] = ids
		daten["raeume"].append(raum)
	var fehler: PackedStringArray = RAUM_LAYOUT.new(daten).pruefen()
	if not fehler.is_empty():
		push_error("Ungueltiges Praxislayout:\n" + "\n".join(fehler))
		return {}
	return daten

static func punkt2(werte: Array) -> Vector2:
	return Vector2(float(werte[0]), float(werte[1]))

static func punkt3(werte: Array) -> Vector3:
	return Vector3(float(werte[0]), float(werte[1]), float(werte[2]))

static func stationen() -> Dictionary:
	var ergebnis := {}
	var daten: Dictionary = layout().get("stationen", {})
	for id in daten:
		ergebnis[id] = punkt2(daten[id])
	return ergebnis

static func wartepositionen() -> Array[Vector2]:
	var ergebnis: Array[Vector2] = []
	for platz in layout().get("warteplaetze", []):
		ergebnis.append(punkt2(platz["position"]))
	return ergebnis

static func personal_plaetze() -> Array[Dictionary]:
	var personen := {}
	for person in lesen("personal.json").get("personal", []):
		if personen.has(person["id"]):
			push_error("Doppelte Personal-ID: " + str(person["id"]))
			return []
		personen[person["id"]] = person
	var plaetze := {}
	for platz in layout().get("arbeitsplaetze", []):
		if plaetze.has(platz["id"]):
			push_error("Doppelte Arbeitsplatz-ID: " + str(platz["id"]))
			return []
		plaetze[platz["id"]] = platz
	var ergebnis: Array[Dictionary] = []
	var belegte_personen := {}
	var belegte_plaetze := {}
	for zuordnung in lesen("besetzung.json").get("zuordnungen", []):
		var person_id := String(zuordnung["personal_id"])
		var platz_id := String(zuordnung["arbeitsplatz_id"])
		if not personen.has(person_id) or not plaetze.has(platz_id):
			push_error("Unbekannte Person oder unbekannter Arbeitsplatz: " + person_id + " / " + platz_id)
			return []
		var person: Dictionary = personen[person_id]
		var platz: Dictionary = plaetze[platz_id]
		if belegte_personen.has(person_id) or belegte_plaetze.has(platz_id) or platz["qualifikation"] not in person["qualifikationen"]:
			push_error("Doppelbelegung oder unpassende Qualifikation: " + person_id + " / " + platz_id)
			return []
		belegte_personen[person_id] = true
		belegte_plaetze[platz_id] = true
		ergebnis.append({"personal_id": person_id, "arbeitsplatz_id": platz_id,
			"rolle": String(person["modell"]), "position": punkt2(platz["position"]),
			"winkel": deg_to_rad(float(platz["winkel_grad"]))})
	return ergebnis
