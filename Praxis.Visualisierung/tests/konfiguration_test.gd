extends SceneTree

const KONFIGURATION = preload("res://Konfiguration/KonfigurationLader.gd")
var fehler := 0

func pruefe(bedingung: bool, text: String) -> void:
	if not bedingung:
		push_error(text)
		fehler += 1

func _initialize() -> void:
	var layout := KONFIGURATION.layout()
	var raeume := {}
	var tueren := {}
	var arbeitsplaetze := {}
	var warteplaetze := {}
	for raum in layout["raeume"]:
		pruefe(not raeume.has(raum["id"]), "Raum-ID eindeutig")
		raeume[raum["id"]] = raum
	for tuer in layout["tueren"]:
		tueren[tuer["id"]] = tuer
		for raum_id in tuer["verbindung"]:
			pruefe(raum_id == "Draussen" or raeume.has(raum_id), "Tuer verbindet bekannte Raeume")
	for platz in layout["arbeitsplaetze"]:
		arbeitsplaetze[platz["id"]] = platz
		pruefe(raeume.has(platz["raum_id"]), "Arbeitsplatz hat bekannten Raum")
	for platz in layout["warteplaetze"]:
		warteplaetze[platz["id"]] = platz
		pruefe(raeume.has(platz["raum_id"]), "Warteplatz hat bekannten Raum")
	for raum in raeume.values():
		for tuer_id in raum["tueren"]:
			pruefe(tueren.has(tuer_id) and raum["id"] in tueren[tuer_id]["verbindung"], "Raumtuer ist beidseitig zugeordnet")
		for platz_id in raum["arbeitsplaetze"]:
			pruefe(arbeitsplaetze.has(platz_id) and arbeitsplaetze[platz_id]["raum_id"] == raum["id"], "Arbeitsplatzverweis passt zum Raum")
		for platz_id in raum["warteplaetze"]:
			pruefe(warteplaetze.has(platz_id) and warteplaetze[platz_id]["raum_id"] == raum["id"], "Warteplatzverweis passt zum Raum")
	pruefe(raeume.size() == 6 and tueren.size() == 6 and warteplaetze.size() == 7, "Vorhandenes Layout vollstaendig")
	var plaetze := KONFIGURATION.personal_plaetze()
	if not FileAccess.file_exists("res://Konfiguration/besetzung.json"):
		pruefe(plaetze.is_empty(), "Fehlende optionale Serverbesetzung erzeugt kein erfundenes Personal")
	for platz in plaetze:
		pruefe(arbeitsplaetze.has(platz["arbeitsplatz_id"]), "Optionale Serverbesetzung verweist auf einen vorhandenen Arbeitsplatz")
	print("KONFIGURATION: %s" % ("BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN"))
	quit(1 if fehler > 0 else 0)
