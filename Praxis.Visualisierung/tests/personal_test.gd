extends SceneTree

const PERSONAL = preload("res://Personal/Personal.gd")
const KONFIGURATION = preload("res://Konfiguration/KonfigurationLader.gd")
const VERWALTUNG = preload("res://Personal/PersonalVerwaltung.gd")
var fehler := 0

func _initialize() -> void:
	call_deferred("testen")

func pruefe(bedingung: bool, beschreibung: String) -> void:
	if not bedingung:
		push_error(beschreibung)
		fehler += 1

func testen() -> void:
	var anzahl := {"Rezeption": 0, "Schwester": 0, "Arzt": 0}
	for platz in KONFIGURATION.personal_plaetze():
		var figur := Node3D.new()
		figur.set_script(PERSONAL)
		figur.rolle = String(platz["rolle"])
		root.add_child(figur)
		anzahl[figur.rolle] += 1
		pruefe(figur.animation != null and figur.animation.current_animation == "Warten", "Personalfigur mit Idle-Animation: " + figur.rolle)
		figur.aktualisieren(0.1)
		figur.queue_free()
	pruefe(anzahl == {"Rezeption": 1, "Schwester": 1, "Arzt": 2}, "Personal an vier Arbeitsplaetzen")
	var arbeitsplaetze: Array = KONFIGURATION.layout()["arbeitsplaetze"]
	var standard := VERWALTUNG.planen({"Rezeption": 1, "Schwester": 1, "Arzt": 2}, arbeitsplaetze)
	pruefe(standard["fehler"] == "", "Standardzahlen passen ins Layout")
	var bisherige := {}
	for platz in KONFIGURATION.personal_plaetze():
		bisherige[platz["personal_id"]] = platz["position"]
	for platz in standard["plaetze"]:
		pruefe(platz["position"] == bisherige[platz["personal_id"]], "Bisherige Position fuer " + platz["personal_id"])

	# Hoehere Zahlen erzeugen neue Figuren ohne neue Eintraege in personal.json oder besetzung.json.
	var erweitert := VERWALTUNG.planen({"Rezeption": 1, "Schwester": 2, "Arzt": 2}, arbeitsplaetze)
	pruefe(erweitert["fehler"] == "" and erweitert["plaetze"].size() == 5, "Eine Rezeptionskraft, zwei Schwestern und zwei Aerzte ergeben fuenf Figuren")
	var welt := Node3D.new()
	root.add_child(welt)
	var figuren := VERWALTUNG.erstellen(welt, erweitert["plaetze"])
	var personal_ids := {}
	var platz_ids := {}
	var schwestern := 0
	for figur in figuren:
		pruefe(not personal_ids.has(figur.personal_id), "Personal-ID eindeutig")
		pruefe(not platz_ids.has(figur.arbeitsplatz_id), "Keine Doppelbelegung eines Arbeitsplatzes")
		personal_ids[figur.personal_id] = true
		platz_ids[figur.arbeitsplatz_id] = true
		if figur.rolle == "Schwester":
			schwestern += 1
		pruefe(figur.animation.current_animation == "Warten", "Automatisch erzeugte Figur animiert")
	pruefe(schwestern == 2 and personal_ids.has("schwester_2"), "Zweite Schwesterfigur automatisch erzeugt")
	pruefe(not personal_ids.has("rezeption_2"), "Freier Rezeptionsplatz erzeugt keine zusaetzliche Person")
	pruefe(VERWALTUNG.planen({"Rezeption": 2, "Schwester": 1, "Arzt": 2}, arbeitsplaetze)["fehler"] == "", "Zweiter Rezeptionsplatz bleibt als Einsatzplatz verfuegbar")
	welt.queue_free()

	var reduziert := VERWALTUNG.planen({"Rezeption": 1, "Schwester": 0, "Arzt": 1}, arbeitsplaetze)
	pruefe(reduziert["fehler"] == "" and reduziert["plaetze"].size() == 2, "Weniger Personal entfernt ueberzaehlige Figuren aus dem Plan")
	var voll := VERWALTUNG.planen({"Rezeption": 3, "Schwester": 1, "Arzt": 2}, arbeitsplaetze)
	pruefe("Rezeption: 3" in voll["fehler"] and voll["plaetze"].is_empty(), "Platzmangel liefert Fehler statt unvollstaendiger Besetzung")
	var doppelt := arbeitsplaetze.duplicate(true)
	doppelt.append(doppelt[0].duplicate(true))
	pruefe(not VERWALTUNG.planen({"Rezeption": 1, "Schwester": 1, "Arzt": 2}, doppelt)["fehler"].is_empty(), "Doppelte Arbeitsplatz-ID abgewiesen")
	for ungueltig in [{}, {"Rezeption": -1, "Schwester": 1, "Arzt": 2}, {"Rezeption": 1.5, "Schwester": 1, "Arzt": 2}, {"Rezeption": 1, "Schwester": 1, "Arzt": 2, "Andere": 1}]:
		pruefe(not VERWALTUNG.planen(ungueltig, arbeitsplaetze)["fehler"].is_empty(), "Ungueltige oder fehlende Personalzahlen abgewiesen")
	print("PERSONAL: %s" % ("BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN"))
	quit(1 if fehler > 0 else 0)
