extends SceneTree

var fehler := 0

func pruefe(bedingung: bool, beschreibung: String) -> void:
	if bedingung:
		print("OK: ", beschreibung)
	else:
		push_error(beschreibung)
		fehler += 1

func _initialize() -> void:
	call_deferred("testen")

func testen() -> void:
	var szene = load("res://Main.tscn").instantiate()
	root.add_child(szene)
	await process_frame
	szene.set_process(false)
	# Fuer den Fehlerfall kann die Test-Ausgabekonfiguration mehr Personal als Plaetze enthalten.
	if "--erwarte-platzmangel" in OS.get_cmdline_user_args():
		pruefe(szene.fehler and not szene.simulation_bereit, "Platzmangel verhindert den Simulationsstart")
		pruefe(szene.play_button.disabled and szene.reset_button.disabled, "Start und Reset bei Platzmangel gesperrt")
		pruefe(szene.personal_figuren.is_empty(), "Kein unvollstaendiges Personal bei Platzmangel")
		pruefe("Rezeption: 3" in szene.status_label.text and "nur 2" in szene.status_label.text, "Platzmangel nennt Rolle und beide Anzahlen")
		szene.queue_free()
		await process_frame
		print("GODOT-PERSONAL-PLATZMANGEL: ", "BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN")
		quit(1 if fehler > 0 else 0)
		return
	pruefe(szene.simulation_bereit and not szene.fehler, "Offline-Modus lädt den SimSharp-Kern ohne Server")
	if not szene.simulation_bereit:
		szene.queue_free()
		quit(1)
		return
	pruefe(szene.simulation.DarstellungsplanLesen().is_empty(), "Keine Ereignisse vor dem Start")
	var personalzahlen: Dictionary = szene.simulation.PersonalzahlenLesen()
	var sichtbares_personal := {"Rezeption": 0, "Schwester": 0, "Arzt": 0}
	var personal_ids := {}
	for figur in szene.personal_figuren:
		sichtbares_personal[figur.rolle] += 1
		personal_ids[figur.personal_id] = figur.get_instance_id()
	pruefe(sichtbares_personal == personalzahlen, "Figurenanzahl je Rolle entspricht den geladenen Simulationswerten")
	var kopie: Dictionary = szene.simulation.PersonalzahlenLesen()
	kopie["Rezeption"] = 999
	pruefe(szene.simulation.PersonalzahlenLesen() == personalzahlen, "Aufrufer koennen die geladene Momentaufnahme nicht veraendern")
	szene._start_pause()
	var startzeit: float = szene.laufzeit
	szene.simulation.Fortschalten(2.0)
	pruefe(is_equal_approx(szene.laufzeit - startzeit, 16.0), "Zentrale Uhr: 1x entspricht 8 Simulationsminuten pro Sekunde")
	pruefe(szene.live_ereignisse > 0, "SimSharp-Ereignisse direkt in Godot empfangen")
	pruefe(szene.patienten.size() > 0, "Patient in der Visualisierung erzeugt")
	var bewegung_gefunden := false
	for ereignis in szene.simulation.DarstellungsplanLesen():
		if ereignis["eventTyp"] == "geht_zur_rezeption" and ereignis["bewegungsdauerMinuten"] > 0.0:
			bewegung_gefunden = true
			break
	pruefe(bewegung_gefunden, "Patientenweg erhält die echte Dauer aus dem SimSharp-Vorlauf")

	szene._start_pause()
	var zeit_vor_pause: float = szene.laufzeit
	var positionen_vor_pause := {}
	for patient_id in szene.patienten:
		positionen_vor_pause[patient_id] = szene._position_patient(patient_id)
	szene.simulation.Fortschalten(5.0)
	pruefe(is_equal_approx(szene.laufzeit, zeit_vor_pause), "Pause hält die Simulationsuhr an")
	var positionen_stabil := true
	for patient_id in positionen_vor_pause:
		positionen_stabil = positionen_stabil and szene._position_patient(patient_id) == positionen_vor_pause[patient_id]
	pruefe(positionen_stabil, "Pause hält alle Patientenpositionen ohne Sprung fest")

	szene._start_pause()
	szene.simulation.Fortschalten(0.5)
	pruefe(is_equal_approx(szene.laufzeit, zeit_vor_pause + 4.0), "Fortsetzen läuft nahtlos ab Pausenzeit weiter")
	szene._geschwindigkeit_geaendert(2.0)
	var zeit_vor_schneller: float = szene.laufzeit
	szene.simulation.Fortschalten(0.5)
	pruefe(is_equal_approx(szene.laufzeit, zeit_vor_schneller + 8.0), "2x steuert SimSharp und zentrale Uhr gemeinsam")
	szene._geschwindigkeit_geaendert(0.5)
	var zeit_vor_langsamer: float = szene.laufzeit
	szene.simulation.Fortschalten(0.5)
	pruefe(is_equal_approx(szene.laufzeit, zeit_vor_langsamer + 2.0), "0,5x wird von derselben Uhr angewendet")

	var ereignisse_vor_ende: int = szene.live_ereignisse
	szene.simulation.Fortschalten(10000.0)
	var endzustand: Dictionary = szene.simulation.ZustandLesen()
	pruefe(bool(endzustand["abgeschlossen"]), "Großer Zeitschritt erreicht das Simulationsende")
	pruefe(szene.live_ereignisse > ereignisse_vor_ende, "Kein fälliges SimSharp-Ereignis wird übersprungen")

	szene._reset_simulation()
	pruefe(szene.laufzeit == 0.0 and szene.live_ereignisse == 0 and not szene.laeuft, "Reset synchronisiert Uhr, SimSharp und Darstellung")
	pruefe(szene.personal_figuren.size() == personal_ids.size(), "Reset erzeugt keine doppelten Personalfiguren")
	for figur in szene.personal_figuren:
		pruefe(personal_ids.get(figur.personal_id) == figur.get_instance_id(), "Reset behaelt die Personalfigur " + figur.personal_id)
	szene.queue_free()
	await process_frame
	print("GODOT-OFFLINE-UHR: ", "BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN")
	quit(1 if fehler > 0 else 0)
