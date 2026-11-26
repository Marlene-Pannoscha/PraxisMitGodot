extends SceneTree
## Isolierte Layoutdateien: Tests veraendern weder Nutzerlayout noch Personal-JSONs.

const LAYOUT = preload("res://PraxisLayout.gd")
const VERWALTUNG = preload("res://Personal/PersonalVerwaltung.gd")
const HAUPTSZENE = preload("res://Main.tscn")
const TEST_PFAD := "user://baumodus-personal-test.json"
var fehler := 0

class TestLayout:
	extends "res://PraxisLayout.gd"
	func konfigurationspfad() -> String:
		return "user://baumodus-personal-test.json"

func _initialize() -> void:
	call_deferred("testen")

func pruefe(bedingung: bool, text: String) -> void:
	if bedingung:
		print("OK: ", text)
	else:
		push_error(text)
		fehler += 1

func standard_layout():
	var modell = LAYOUT.new()
	pruefe(modell.aus_json_text(modell.standard_json_text(), "Teststandard").is_empty(), "Standardvorlage geladen")
	return modell

func szene_laden():
	var szene = HAUPTSZENE.instantiate()
	szene.praxis_layout = TestLayout.new()
	root.add_child(szene)
	szene.set_process(false)
	return szene

func testen() -> void:
	var hashes := {}
	for pfad in ["res://praxis-layout.json", "res://Konfiguration/personal.json",
		"res://../simSharpSimulation/simSharpSimulation/Ressourcen/schwester-konfiguration.json",
		"res://../simSharpSimulation/simSharpSimulation/Ressourcen/arzt-konfiguration.json"]:
		hashes[pfad] = FileAccess.get_sha256(pfad)
	var standard = standard_layout()
	var zahlen := {"Rezeption": 1, "Schwester": 1, "Arzt": 2}
	var bisher := VERWALTUNG.planen(zahlen, standard.daten["arbeitsplaetze"])
	pruefe(bisher["fehler"] == "", "Ausgangsbesetzung geplant")
	var entwurf = standard_layout()
	entwurf.baumodus_vorbereiten()
	entwurf.groesse_setzen(entwurf._raum_index("Flur"), Vector2(36, 2.4))
	var schwester: Dictionary = entwurf.hinzufuegen("Schwester", Vector2(12, -2.7))
	var arzt: Dictionary = entwurf.hinzufuegen("Arzt", Vector2(16, -2.7))
	var plan := VERWALTUNG.baumodus_planen(standard.daten, entwurf.daten, bisher["plaetze"])
	pruefe(plan["fehler"] == "", "Neue Arzt- und Schwesternraeume koennen besetzt werden")
	if not String(plan["fehler"]).is_empty():
		quit(1)
		return
	pruefe(plan["konfiguration"]["anzahlen"] == {"Rezeption": 1, "Schwester": 2, "Arzt": 3}, "Je neuer Raum genau eine weitere Person; Rezeption unveraendert")
	var zuordnung: Dictionary = plan["konfiguration"]["zuordnungen"]
	var schwester_platz: Dictionary = entwurf.daten["arbeitsplaetze"].filter(func(p): return String(p["id"]) == String(zuordnung["schwester_2"]))[0]
	pruefe(schwester_platz["raum_id"] == schwester["id"], "Zweite Schwester steht im neuen Raum trotz freiem Platz im alten Raum")
	var arzt_platz: Dictionary = entwurf.daten["arbeitsplaetze"].filter(func(p): return String(p["id"]) == String(zuordnung["arzt_3"]))[0]
	pruefe(arzt_platz["raum_id"] == arzt["id"], "Dritter Arzt steht im neuen Arztzimmer")
	for person in bisher["plaetze"]:
		pruefe(zuordnung[person["personal_id"]] == person["arbeitsplatz_id"], "Bisheriger Arbeitsplatz erhalten: " + String(person["personal_id"]))
	var unveraendert := VERWALTUNG.baumodus_planen(entwurf.daten, entwurf.daten, plan["plaetze"])
	pruefe(unveraendert["konfiguration"] == plan["konfiguration"], "Erneutes Uebernehmen erhoeht die Zahlen nicht nochmals")
	var entfernt = LAYOUT.new()
	entfernt.aus_json_text(entwurf.als_json_text())
	entfernt.entfernen(entfernt._raum_index(String(schwester["id"])))
	var reduziert := VERWALTUNG.baumodus_planen(entwurf.daten, entfernt.daten, plan["plaetze"])
	pruefe(reduziert["fehler"] == "" and reduziert["konfiguration"]["anzahlen"]["Schwester"] == 1, "Entfernen des neuen Raums entfernt dessen zusaetzliche Schwester")
	var vergroessert = standard_layout()
	vergroessert.groesse_setzen(vergroessert._raum_index("Schwester"), Vector2(12, 6))
	var gleich := VERWALTUNG.baumodus_planen(standard.daten, vergroessert.daten, bisher["plaetze"])
	pruefe(gleich["fehler"] == "" and gleich["konfiguration"]["anzahlen"] == zahlen, "Vergroessern allein stellt niemanden ein")
	var zu_klein = standard_layout()
	zu_klein.groesse_setzen(zu_klein._raum_index("Schwester"), Vector2(4, 4))
	var zwei := VERWALTUNG.planen({"Rezeption": 1, "Schwester": 2, "Arzt": 2}, standard.daten["arbeitsplaetze"])
	pruefe(not String(VERWALTUNG.baumodus_planen(standard.daten, zu_klein.daten, zwei["plaetze"])["fehler"]).is_empty(), "Verkleinern mit Platzmangel wird vor dem Speichern abgewiesen")
	var reserviert := VERWALTUNG.planen({"Rezeption": 1, "Schwester": 2, "Arzt": 2}, standard.daten["arbeitsplaetze"], {"schwester_2": "schwester_1"})
	pruefe(reserviert["fehler"] == "" and VERWALTUNG.zuordnungen_aus_plan(reserviert["plaetze"])["schwester_1"] != "schwester_1", "Expliziter Platz bleibt reserviert, auch wenn die Person spaeter geplant wird")
	pruefe(not String(VERWALTUNG.planen(zahlen, standard.daten["arbeitsplaetze"], {"schwester_1": "arzt_1"})["fehler"]).is_empty(), "Unpassende Qualifikation einer Zuordnung abgewiesen")
	pruefe(not String(VERWALTUNG.planen({"Rezeption": 1, "Schwester": 2, "Arzt": 2}, standard.daten["arbeitsplaetze"], {"schwester_1": "schwester_1", "schwester_2": "schwester_1"})["fehler"]).is_empty(), "Doppelte Zuordnung abgewiesen")

	# Echte Hauptszene mit isoliertem Speicherpfad: Entwurf, Speichern, Neustart und Kern.
	pruefe(standard.speichern(TEST_PFAD).is_empty(), "Isoliertes Ausgangslayout gespeichert")
	var szene = szene_laden()
	await process_frame
	pruefe(szene.simulation_bereit, "Echte Offline-Szene geladen")
	if not szene.simulation_bereit:
		szene.queue_free()
		quit(1)
		return
	var aktive_zahlen: Dictionary = szene.simulation.PersonalzahlenLesen()
	var aktive_ids := VERWALTUNG.zuordnungen_aus_plan(szene.personal_plan)
	szene.bau_fenster.vorbereiten(szene.praxis_layout.als_json_text(), standard.standard_json_text())
	szene._bau_dialog_vorschau(entwurf.daten)
	szene._bau_vorschau_anwenden()
	pruefe(szene.simulation.PersonalzahlenLesen() == aktive_zahlen and VERWALTUNG.zuordnungen_aus_plan(szene.personal_plan) == aktive_ids, "3D-Vorschau veraendert weder Kernzahlen noch aktive Besetzung")
	szene._bau_dialog_verwerfen()
	await create_timer(0.1).timeout
	pruefe(szene.layout_daten == szene.praxis_layout.daten and szene.simulation.PersonalzahlenLesen() == aktive_zahlen, "Abbrechen stellt das Layout ohne Personalveraenderung wieder her")
	# Personalfenster-Werte muessen beim Bauen erhalten bleiben.
	pruefe(szene._personal_uebernehmen({"Rezeption": 1, "Schwester": 2, "Arzt": 2}).is_empty(), "Vor dem Umbau manuell eine zweite Schwester eingestellt")
	szene.simulation.Pausieren()
	var vorbereitet: Dictionary = szene._bau_entwurf_vorbereiten(entwurf.als_json_text())
	pruefe(vorbereitet["fehler"] == "", "Baumodus bereitet gespeicherte Personalbesetzung vor")
	var gespeichert = vorbereitet["entwurf"]
	pruefe(gespeichert.daten["offline_personal"]["anzahlen"] == {"Rezeption": 1, "Schwester": 3, "Arzt": 3}, "Aktive manuelle Zahlen plus neue Raeume uebernommen")
	pruefe(gespeichert.speichern(TEST_PFAD).is_empty(), "Layout und Besetzung gemeinsam gespeichert")
	szene.queue_free()
	await process_frame
	var neu = szene_laden()
	await process_frame
	pruefe(neu.simulation_bereit and neu.simulation.PersonalzahlenLesen() == {"Rezeption": 1, "Schwester": 3, "Arzt": 3}, "Neustart liest gespeicherte JSON-Zahlen und setzt den echten SimSharp-Kern")
	pruefe(neu.personal_figuren.size() == 7, "Sieben Figuren entsprechen den sieben Personen im Kern")
	var neu_zugeordnet := VERWALTUNG.zuordnungen_aus_plan(neu.personal_plan)
	var erwartete: Dictionary = gespeichert.daten["offline_personal"]["zuordnungen"]
	pruefe(neu_zugeordnet == erwartete, "Explizite Arbeitsplatzzuordnungen ueberstehen den Neustart")
	var neuer_schwesterplatz: Dictionary = neu.timeline.arbeitsplatz_fuer_personal("Schwester", 3)
	pruefe(neuer_schwesterplatz.get("raum_id", "") == schwester["id"], "Patientenziel der neuen Schwester ist derselbe neue Raum")
	var ev: Dictionary = neu._ereignis_mit_layoutziel({"eventTyp": "geht_zur_schwester", "schwesterId": 3})
	pruefe(ev.get("arbeitsplatzId", "") == erwartete["schwester_3"] and ev.get("raumId", "") == schwester["id"], "Patientenereignis enthaelt dieselbe Arbeitsplatz- und Raum-ID wie die Personalfigur")
	neu.simulation.Starten()
	neu.simulation.Fortschalten(10000.0)
	pruefe(bool(neu.simulation.ZustandLesen()["abgeschlossen"]), "Simulation mit zusaetzlichem Personal laeuft bis Tagesende")
	var ereignis_im_neuen_raum := false
	var arztweg_im_neuen_raum := false
	for ereignis in neu.ereignisse:
		if ereignis.get("eventTyp", "") == "geht_zur_schwester" and int(ereignis.get("schwesterId", 0)) == 3 and ereignis.get("raumId", "") == schwester["id"]:
			ereignis_im_neuen_raum = true
		if ereignis.get("eventTyp", "") == "geht_zum_arzt" and int(ereignis.get("arztId", 0)) == 3 and ereignis.get("raumId", "") == arzt["id"]:
			arztweg_im_neuen_raum = true
	pruefe(ereignis_im_neuen_raum, "Schon der Hinweg fuehrt zur zusaetzlichen Schwester im neuen Raum")
	pruefe(arztweg_im_neuen_raum, "Schon der Hinweg fuehrt zum zusaetzlichen Arzt im neuen Raum")
	neu._reset_simulation()
	pruefe(neu.personal_figuren.size() == 7 and VERWALTUNG.zuordnungen_aus_plan(neu.personal_plan) == erwartete, "Simulationsreset behaelt Personal ohne Duplikate")
	neu.queue_free()
	await process_frame
	# Layout-Reset speichert die unveraenderliche Vorlage ohne Offline-Ueberschreibung.
	standard = standard_layout()
	standard.baumodus_vorbereiten()
	pruefe(standard.speichern(TEST_PFAD).is_empty(), "Standardlayout fuer Reset gespeichert")
	var zurueck = szene_laden()
	await process_frame
	pruefe(zurueck.praxis_layout.als_json_text() == standard.als_json_text(), "Reset liest die gespeicherte Standardvorlage vollstaendig")
	pruefe(zurueck.simulation_bereit and zurueck.simulation.PersonalzahlenLesen() == zahlen and zurueck.personal_figuren.size() == 4, "Standardlayout stellt urspruengliche Personalzahlen wieder her")
	zurueck.queue_free()
	await process_frame
	for pfad in hashes:
		pruefe(hashes[pfad] == FileAccess.get_sha256(pfad), "Quelldatei unveraendert: " + pfad)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PFAD))
	print("BAUMODUS-PERSONAL: ", "BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN")
	quit(1 if fehler > 0 else 0)
