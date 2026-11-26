@tool
extends RefCounted
## Ordnet die vorhandenen Raumdaten nach IDs. Keine Wegplanung oder Raumverwaltung.

var daten: Dictionary
var raeume: Dictionary = {}
var tueren: Dictionary = {}
var arbeitsplaetze: Dictionary = {}
var warteplaetze: Dictionary = {}
var ausstattung: Dictionary = {}
var statusleuchten: Dictionary = {}

func _init(eingabe: Dictionary) -> void:
	daten = eingabe
	for raum in daten.get("raeume", []):
		raeume[raum["id"]] = raum
	for tuer in daten.get("tueren", []):
		tueren[tuer["id"]] = tuer
	for platz in daten.get("arbeitsplaetze", []):
		arbeitsplaetze[platz["id"]] = platz
	for platz in daten.get("warteplaetze", []):
		warteplaetze[platz["id"]] = platz
	for objekt in daten.get("ausstattung", []):
		ausstattung[objekt["id"]] = objekt
	for leuchte in daten.get("statusleuchten", []):
		statusleuchten[leuchte["id"]] = leuchte

static func punkt(werte: Array) -> Vector2:
	return Vector2(float(werte[0]), float(werte[1]))

func pruefen() -> PackedStringArray:
	var fehler := PackedStringArray()
	for gruppe in ["raeume", "tueren", "arbeitsplaetze", "warteplaetze", "ausstattung", "statusleuchten", "waende"]:
		var ids := {}
		for eintrag in daten.get(gruppe, []):
			var id := String(eintrag.get("id", ""))
			if id.is_empty() or ids.has(id):
				fehler.append("Fehlende oder doppelte ID in " + gruppe + ": " + id)
			ids[id] = true
	for raum in raeume.values():
		for feld in ["position", "groesse", "tueren", "arbeitsplaetze", "warteplaetze"]:
			if not raum.has(feld):
				fehler.append("Raum " + String(raum["id"]) + ": " + feld + " fehlt")
		for tuer_id in raum.get("tueren", []):
			if not tueren.has(tuer_id) or raum["id"] not in tueren[tuer_id].get("verbindung", []):
				fehler.append("Ungueltiger Tuerverweis in Raum " + String(raum["id"]))
		for gruppe in ["arbeitsplaetze", "warteplaetze"]:
			var plaetze: Dictionary = arbeitsplaetze if gruppe == "arbeitsplaetze" else warteplaetze
			for platz_id in raum.get(gruppe, []):
				if not plaetze.has(platz_id) or plaetze[platz_id].get("raum_id") != raum["id"]:
					fehler.append("Ungueltiger Platzverweis: " + String(platz_id))
		for gruppe in ["ausstattung", "statusleuchten"]:
			var objekte: Dictionary = ausstattung if gruppe == "ausstattung" else statusleuchten
			for objekt_id in raum.get(gruppe, []):
				if not objekte.has(objekt_id) or objekte[objekt_id].get("raum_id") != raum["id"]:
					fehler.append("Ungueltiger %s-Verweis: %s" % [gruppe, objekt_id])
	for tuer in tueren.values():
		var verbindung: Array = tuer.get("verbindung", [])
		if verbindung.size() != 2 or float(tuer.get("breite", 0)) <= 0.0:
			fehler.append("Ungueltige Tuer: " + String(tuer["id"]))
		for raum_id in verbindung:
			if raum_id != "Draussen" and not raeume.has(raum_id):
				fehler.append("Tuer verweist auf unbekannten Raum: " + String(raum_id))
	for gruppe in ["arbeitsplaetze", "warteplaetze", "ausstattung", "statusleuchten"]:
		for eintrag in daten.get(gruppe, []):
			if not raeume.has(eintrag.get("raum_id", "")):
				fehler.append("Unbekannter Raum in " + gruppe)
	for wand in daten.get("waende", []):
		for tuer_id in wand.get("tueren", []):
			if not tueren.has(tuer_id):
				fehler.append("Unbekannte Tuer in Wand " + String(wand["id"]))
	return fehler
