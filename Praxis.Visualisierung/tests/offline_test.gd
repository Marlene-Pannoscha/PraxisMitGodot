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
	pruefe(szene.simulation_bereit and not szene.fehler, "Offline-Modus lädt den SimSharp-Kern ohne Server")
	if not szene.simulation_bereit:
		szene.queue_free()
		quit(1)
		return
	pruefe(szene.simulation.DarstellungsplanLesen().is_empty(), "Keine Ereignisse vor dem Start")
	szene._start_pause()
	szene.simulation.Fortschalten(2.0)
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
	szene.simulation.Fortschalten(5.0)
	pruefe(is_equal_approx(szene.laufzeit, zeit_vor_pause), "Pause hält die Simulationsuhr an")
	szene._reset_simulation()
	pruefe(szene.laufzeit == 0.0 and szene.live_ereignisse == 0, "Reset beginnt neuen Lauf")
	szene.queue_free()
	await process_frame
	print("GODOT-OFFLINE: ", "BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN")
	quit(1 if fehler > 0 else 0)
