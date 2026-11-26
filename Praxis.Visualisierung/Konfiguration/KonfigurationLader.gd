@tool
extends RefCounted
## Einheitlicher Zugang zur vollstaendigen praxis-layout.json und separaten Personaldaten.

const PRAXIS_LAYOUT = preload("res://PraxisLayout.gd")
const RAUM_LAYOUT = preload("res://Raum3D/RaumLayout.gd")

static func layout() -> Dictionary:
	var modell = PRAXIS_LAYOUT.new()
	var fehler: String = modell.laden()
	if not fehler.is_empty():
		push_error(fehler)
		return {}
	var raum_fehler: PackedStringArray = RAUM_LAYOUT.new(modell.daten).pruefen()
	if not raum_fehler.is_empty():
		push_error("Ungueltiges Praxislayout:\n" + "\n".join(raum_fehler))
		return {}
	return modell.daten

static func lesen(dateiname: String) -> Dictionary:
	var pfad := "res://Konfiguration/" + dateiname
	if not FileAccess.file_exists(pfad):
		push_error("Konfiguration fehlt: " + pfad)
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(pfad)) != OK or not json.data is Dictionary:
		push_error("Ungueltige Konfiguration: " + pfad)
		return {}
	return json.data

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

static func station_id(id: String) -> Vector2:
	var werte: Array = layout().get("stationen", {}).get(id, [])
	return punkt2(werte) if werte.size() >= 2 else Vector2.ZERO

static func arbeitsplatz_id(id: String) -> Dictionary:
	for platz in layout().get("arbeitsplaetze", []):
		if String(platz.get("id", "")) == id:
			return platz
	return {}

static func wartepositionen() -> Array[Vector2]:
	var ergebnis: Array[Vector2] = []
	for platz in layout().get("warteplaetze", []):
		ergebnis.append(punkt2(platz["position"]))
	return ergebnis

## Optionale explizite Besetzung fuer den spaeteren Server-Modus.
## Offline kommen Zahlen und Zuordnungen aus Simulation und praxis-layout.json.
## Ohne Besetzungsdatei werden online vorerst keine Personalfiguren erzeugt.
static func personal_plaetze() -> Array[Dictionary]:
	if not FileAccess.file_exists("res://Konfiguration/besetzung.json"):
		return []
	var personen := {}
	for person in lesen("personal.json").get("personal", []):
		personen[person["id"]] = person
	var plaetze := {}
	for platz in layout().get("arbeitsplaetze", []):
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
