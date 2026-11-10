extends SceneTree

var fehler := 0
func pruefe(wahr: bool, text: String) -> void:
	if not wahr:
		push_error(text)
		fehler += 1
	else:
		print("OK: " + text)

func _initialize() -> void:
	call_deferred("testen")

func testen() -> void:
	var szene = load("res://Main.tscn").instantiate()
	root.add_child(szene)
	await process_frame
	pruefe(szene.simulation_bereit and not szene.fehler, "Godot per WebSocket mit SimSharp verbunden")
	pruefe(szene.simulation.DarstellungsplanLesen().is_empty(), "Kein vorberechneter Darstellungsplan")
	szene._geschwindigkeit_geaendert(5.0)
	szene._start_pause()
	var ende := Time.get_ticks_msec() + 10000
	while szene.live_ereignisse == 0 and Time.get_ticks_msec() < ende:
		await create_timer(0.05).timeout
	pruefe(szene.laeuft, "Serverseitiger Live-Lauf gestartet")
	pruefe(szene.live_ereignisse > 0, "Live-Ereignisse empfangen")
	var plan: Array = szene.simulation.DarstellungsplanLesen()
	pruefe(not plan.is_empty() and plan[0]["eventTyp"] == "betritt_klinik", "Erster Patient aus dem SimSharp-Lauf empfangen")
	pruefe(szene.patienten.size() > 0, "Patient in Godot erzeugt")
	szene._start_pause()
	var stop_ende := Time.get_ticks_msec() + 3000
	while szene.laeuft and Time.get_ticks_msec() < stop_ende:
		await create_timer(0.05).timeout
	pruefe(not szene.laeuft, "Live-Lauf über WebSocket gestoppt")
	szene._reset_simulation()
	pruefe(szene.laufzeit == 0.0 and szene.live_ereignisse == 0, "Lokale Live-Darstellung zurückgesetzt")
	szene.queue_free()
	await process_frame
	print("GODOT-WEBSOCKET-INTEGRATION: ", "BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN")
	quit(1 if fehler > 0 else 0)
