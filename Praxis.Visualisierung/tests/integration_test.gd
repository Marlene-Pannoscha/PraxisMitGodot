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
	szene.set_process(false)
	pruefe(szene.simulation_bereit and not szene.fehler, "Originalkern in Godot geladen")
	var bridge = szene.simulation
	var plan: Array = bridge.DarstellungsplanLesen()
	pruefe(plan.size() > 0 and szene.patienten.size() > 0, "Originalplan mit Patienten vorhanden")
	szene._start_pause()
	pruefe(szene.laeuft and szene.play_button.text == "Pause", "Start-Steuerung")
	bridge.Fortschalten(2.0)
	szene._start_pause()
	var zeit: float = szene.laufzeit
	bridge.Fortschalten(20.0)
	pruefe(szene.laufzeit == zeit and not szene.laeuft, "Pause-Steuerung")
	szene._geschwindigkeit_geaendert(2.0)
	pruefe(szene.geschwindigkeit == 2.0, "Geschwindigkeitsregler")
	szene._aktualisiere_patienten(0.1)
	pruefe(szene.patienten_figuren.size() > 0, "Animierte Patienten erzeugt")
	for figur in szene.patienten_figuren.values():
		pruefe(figur.animation.has_animation("Gehen") and figur.animation.has_animation("Warten"), "Demo-Animationen vorhanden")
		break
	szene._start_pause()
	var schritte := 0
	while not szene.lauf_abgeschlossen and schritte < 1000:
		bridge.Fortschalten(0.5)
		szene._aktualisiere_patienten(0.5)
		schritte += 1
		if schritte % 10 == 0:
			await process_frame
	pruefe(szene.lauf_abgeschlossen and szene.live_ereignisse == plan.size(), "Ganzer Originaltag in Godot ausgeführt")
	var sichtbar := 0
	for id in szene.patienten:
		var info: Dictionary = szene._position_patient(id)
		if not info.is_empty() and not info["ausgetreten"]:
			sichtbar += 1
	print("Am Tageslimit noch sichtbar: ", sichtbar)
	szene._reset_simulation()
	pruefe(szene.laufzeit == 0.0 and szene.live_ereignisse == 0 and not szene.laeuft, "Reset-Steuerung")
	szene.queue_free()
	await process_frame
	print("GODOT-INTEGRATION: ", "BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN")
	quit(1 if fehler > 0 else 0)
