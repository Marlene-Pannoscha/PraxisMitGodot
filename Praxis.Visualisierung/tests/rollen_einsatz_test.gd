extends SceneTree
## Manuelle Einsatzrollen ueber die echte Oberflaeche und den unveraenderten Kern.

const VERWALTUNG = preload("res://Personal/PersonalVerwaltung.gd")
const TEST_PFAD := "user://einsatzrollen-test.json"
var fehler := 0

class TestLayout:
	extends "res://PraxisLayout.gd"
	# Den Neustart mit einem separaten Testlayout pruefen, ohne das Nutzerlayout zu speichern.
	func konfigurationspfad() -> String:
		return "user://einsatzrollen-test.json"

func _initialize() -> void:
	call_deferred("testen")

func pruefe(bedingung: bool, text: String) -> void:
	if bedingung:
		print("OK: ", text)
	else:
		push_error(text)
		fehler += 1

func rolle_waehlen(fenster, rolle: String) -> void:
	# Dieselbe Auswahl und dasselbe Signal ausloesen wie bei einem Klick im Dialog.
	var feld: OptionButton = fenster.rollen_felder["schwester_2"]
	for index in feld.item_count:
		if feld.get_item_metadata(index) == rolle:
			feld.select(index)
			feld.item_selected.emit(index)
			return
	pruefe(false, "Einsatzrolle angeboten: " + rolle)

func person_finden(personen: Array, id: String) -> Dictionary:
	# Personenentwuerfe verwenden id, Arbeitsplatzplaene dagegen personal_id.
	for person in personen:
		if person.get("personal_id", person.get("id", "")) == id:
			return person
	return {}

func testen() -> void:
	# Vorher-/Nachher-Hashes belegen, dass weder Godot- noch Kernkonfigurationen
	# durch das Einstellen und Neustarten des Personals gespeichert werden.
	var hashes := {}
	for pfad in ["res://Konfiguration/personal.json", "res://praxis-layout.json",
		"res://../simSharpSimulation/simSharpSimulation/Ressourcen/rezeption-konfiguration.json",
		"res://../simSharpSimulation/simSharpSimulation/Ressourcen/schwester-konfiguration.json"]:
		hashes[pfad] = FileAccess.get_sha256(pfad)
	var szene = load("res://Main.tscn").instantiate()
	root.add_child(szene)
	await process_frame
	szene.set_process(false)
	var fenster = szene.personal_fenster
	szene.personal_button.pressed.emit()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		pruefe(fenster.size.y < root.size.y and fenster.size.x < root.size.x, "Personalfenster passt in die Anwendung: %s / %s" % [fenster.size, root.size])
	var standard: Dictionary = szene.simulation.PersonalStandardwerteLesen()
	pruefe(standard == {"Rezeption": 1, "Schwester": 1, "Arzt": 2}, "Kern-Standardzahlen bleiben unveraendert")
	pruefe(szene.simulation_bereit and not szene.play_button.disabled, "Erste Schwester bleibt fest im Schwesternbereich; Start ist gueltig")
	pruefe(fenster.visible and not szene.personal_button.disabled, "Personalfenster zur manuellen Einstellung geoeffnet")
	pruefe(fenster.eingaben()["Schwester"] == 1 and not fenster.rollen_felder.has("schwester_2"), "Zweite Vorlage stellt keine Person automatisch ein")
	pruefe(fenster.rollen_felder["schwester_1"].item_count == 1 and fenster.rollen_felder["schwester_1"].disabled, "Erste Schwester hat ausschliesslich die Schwester-Qualifikation")
	fenster.felder["Schwester"].value = 2
	pruefe(fenster.rollen_felder["schwester_2"].item_count == 2 and not fenster.rollen_felder["schwester_2"].disabled, "Ab zweiter Schwester sind beide Einsatzrollen moeglich")
	var drei: Dictionary = VERWALTUNG.personen_erstellen({"Rezeption": 1, "Schwester": 3, "Arzt": 2}, szene.personal_vorlagen, fenster.personen_eingaben())
	pruefe(person_finden(drei["personen"], "schwester_3")["qualifikationen"] == ["Schwester", "Rezeption"], "Auch weitere Schwestern erhalten beide Qualifikationen")
	pruefe(fenster.personen_eingaben().size() == 5 and not fenster.get_ok_button().disabled, "Zweite Schwester ausschliesslich im Godot-Zahlenfeld eingestellt")
	pruefe(szene.simulation.PersonalzahlenLesen() == standard, "Entwurf veraendert den Kern nicht")
	fenster.get_cancel_button().pressed.emit()
	szene.personal_button.pressed.emit()
	pruefe(fenster.eingaben()["Schwester"] == 1, "Abbrechen verwirft den Entwurf")
	fenster.felder["Schwester"].value = 2
	fenster.get_ok_button().pressed.emit()
	var erwartet := {"Rezeption": 2, "Schwester": 1, "Arzt": 2}
	pruefe(szene.simulation_bereit and not fenster.visible and szene.laeuft, "Uebernehmen startet den gueltigen Lauf")
	pruefe(szene.simulation.PersonalzahlenLesen() == erwartet, "Kern erhaelt zwei Rezeptionskraefte und eine Schwester")
	var flexibel := person_finden(szene.personal_plan, "schwester_2")
	var verbleibend := person_finden(szene.personal_plan, "schwester_1")
	pruefe(flexibel["rolle"] == "Rezeption" and flexibel["modell"] == "Schwester" and flexibel["kern_id"] == "rezeption_2", "Person-ID und Aussehen bleiben bei Rollenwechsel erhalten")
	pruefe(verbleibend["kern_id"] == "schwester_1", "Kernnummer unabhaengig von stabiler Personal-ID")
	pruefe(szene.timeline.arbeitsplatz_fuer_personal("Schwester", 1)["id"] == verbleibend["arbeitsplatz_id"], "Patientenziel ist die verbleibende Schwester")
	var ids := {}
	var plaetze := {}
	for figur in szene.personal_figuren:
		pruefe(not ids.has(figur.personal_id) and not plaetze.has(figur.arbeitsplatz_id), "Keine doppelte Person oder Platzbelegung")
		ids[figur.personal_id] = true
		plaetze[figur.arbeitsplatz_id] = true
		if figur.personal_id == "schwester_2":
			pruefe(figur.modell == "Schwester" and figur.rolle == "Rezeption", "Schwester-Modell an der Rezeption")
	szene.simulation.Fortschalten(2.0)
	# Ein Rollenentwurf waehrend eines aktiven Tages darf dessen Zustand nicht veraendern.
	var bisher: Dictionary = szene.simulation.ZustandLesen()
	var alter_plan: Array = szene.personal_plan.duplicate(true)
	szene.personal_button.pressed.emit()
	pruefe(fenster.eingaben() == {"Rezeption": 1, "Schwester": 2, "Arzt": 2}, "Wiederoeffnen zeigt Stammzahlen statt Einsatzkapazitaeten")
	rolle_waehlen(fenster, "Schwester")
	pruefe(szene.simulation.ZustandLesen() == bisher and szene.personal_plan == alter_plan, "Rollenentwurf laesst den aktiven Lauf unveraendert")
	fenster.felder["Arzt"].value = 3
	pruefe(fenster.get_ok_button().disabled and "Arzt: 3" in fenster.meldung.text, "Fehlender Arbeitsplatz sperrt Uebernehmen")
	fenster.confirmed.emit()
	pruefe(szene.simulation.ZustandLesen() == bisher, "Abgewiesener Entwurf verwirft den Tag nicht")
	fenster.felder["Arzt"].value = 2
	fenster.get_ok_button().pressed.emit()
	pruefe(szene.simulation.PersonalzahlenLesen() == {"Rezeption": 1, "Schwester": 2, "Arzt": 2}, "Manueller Rueckwechsel gilt fuer den neuen Lauf")
	pruefe(szene.laufzeit == 0.0 and szene.patienten.is_empty() and szene.live_ereignisse == 0 and szene.simulationslauf == int(bisher["lauf"]) + 1, "Genau ein Neustart setzt Uhr und Patienten zurueck")
	var ungueltig: Array = VERWALTUNG.personen_aus_plan(szene.personal_plan)
	# Auch ein Aufruf ohne UI muss einen Einsatz ohne passende Qualifikation abweisen.
	ungueltig[0]["einsatzrolle"] = "Arzt"
	var vor_fehler: Dictionary = szene.simulation.ZustandLesen()
	pruefe(not szene._personal_uebernehmen({"Rezeption": 1, "Schwester": 2, "Arzt": 2}, ungueltig).is_empty(), "Unqualifizierter direkter Aufruf abgewiesen")
	pruefe(szene.simulation.ZustandLesen() == vor_fehler, "Ungueltiger Einsatz laesst den aktiven Lauf bestehen")
	szene.personal_button.pressed.emit()
	rolle_waehlen(fenster, "Rezeption")
	fenster.get_ok_button().pressed.emit()
	var vor_reset: Array = szene.personal_plan.duplicate(true)
	szene.simulation.Fortschalten(10000.0)
	pruefe(bool(szene.simulation.ZustandLesen()["abgeschlossen"]), "Echter SimSharp-Lauf bis Tagesende mit manuellen Rollen")
	szene._reset_simulation()
	pruefe(szene.personal_plan == vor_reset and szene.simulation.PersonalzahlenLesen() == erwartet, "Reset erhaelt Rollen und IDs")
	# Ein bestehender besetzter Rezeptionsplatz blockiert einen weiteren Einsatz.
	var personen: Array = VERWALTUNG.personen_aus_plan(szene.personal_plan)
	var doppel := personen.duplicate(true)
	doppel.append(doppel[0].duplicate(true))
	pruefe(not VERWALTUNG.personen_planen(doppel, szene.layout_daten["arbeitsplaetze"])["fehler"].is_empty(), "Doppelte Person-ID abgewiesen")
	var ohne_zweiten_platz: Array = szene.layout_daten["arbeitsplaetze"].filter(func(p): return p["id"] != flexibel["arbeitsplatz_id"])
	pruefe(not VERWALTUNG.personen_planen(personen, ohne_zweiten_platz)["fehler"].is_empty(), "Freier passender Arbeitsplatz ist Voraussetzung")
	# Baumodus muss manuelle Einsaetze samt stabiler IDs speichern und wieder laden.
	var gespeichert := TestLayout.new()
	pruefe(gespeichert.aus_json_text(JSON.stringify(szene.layout_daten)).is_empty(), "Isoliertes Testlayout vorbereitet")
	var bauplan: Dictionary = VERWALTUNG.baumodus_planen(gespeichert.daten, gespeichert.daten, szene.personal_plan)
	pruefe(bauplan["fehler"] == "" and bauplan["anzahlen"] == erwartet, "Baumodus erhaelt die manuelle Einsatzverteilung")
	gespeichert.daten["offline_personal"] = bauplan["konfiguration"]
	pruefe(gespeichert.speichern(TEST_PFAD).is_empty(), "Besetzung in isolierter Testdatei gespeichert")
	var kaputt: Dictionary = bauplan["konfiguration"].duplicate(true)
	kaputt["anzahlen"]["Schwester"] = 2
	pruefe(not VERWALTUNG.konfiguration_planen(kaputt, gespeichert.daten["arbeitsplaetze"])["fehler"].is_empty(), "Widerspruch zwischen gespeicherten Personen und Zahlen wird abgewiesen")
	szene.queue_free()
	await process_frame
	var neu = load("res://Main.tscn").instantiate()
	neu.praxis_layout = TestLayout.new()
	root.add_child(neu)
	neu.set_process(false)
	await process_frame
	pruefe(neu.simulation_bereit and neu.simulation.PersonalzahlenLesen() == erwartet, "Neustart liest die gespeicherten Einsatzrollen")
	pruefe(neu.personal_plan == vor_reset, "IDs, Modelle und Arbeitsplaetze ueberstehen den Layout-Neustart")
	neu.queue_free()
	await process_frame
	# Nur die isolierte Testdatei entfernen; die Quell-Layouts bleiben bestehen.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PFAD))
	for pfad in hashes:
		pruefe(hashes[pfad] == FileAccess.get_sha256(pfad), "Quelldatei unveraendert: " + pfad)
	print("GODOT-EINSATZROLLEN: ", "BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN")
	quit(1 if fehler > 0 else 0)
