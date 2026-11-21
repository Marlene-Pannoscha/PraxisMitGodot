extends SceneTree
## End-to-End: eine Schwesterfigur, zwei Qualifikationen und Ereignisse aus dem echten Kern.

const WEGE = preload("res://Raum3D/RaumWege.gd")
var fehler := 0

func pruefe(bedingung: bool, text: String) -> void:
	if bedingung:
		print("OK: ", text)
	else:
		push_error(text)
		fehler += 1

func _initialize() -> void:
	call_deferred("testen")

func testen() -> void:
	var szene = load("res://Main.tscn").instantiate()
	root.add_child(szene)
	await process_frame
	szene.set_process(false)
	pruefe(szene.simulation_bereit, "Offline-Kern geladen")
	if not szene.simulation_bereit:
		szene.queue_free()
		quit(1)
		return
	szene.personal_button.pressed.emit()
	var fenster = szene.personal_fenster
	fenster.felder["Rezeption"].value = 1
	fenster.felder["Schwester"].value = 1
	fenster.wechsel_option.button_pressed = true
	pruefe(fenster.get_ok_button().disabled, "Flexible Rolle mit nur einer Schwester gesperrt")
	fenster.felder["Schwester"].value = 2
	fenster.felder["Arzt"].value = 2
	pruefe(not fenster.get_ok_button().disabled, "Eine Rezeptionskraft, zwei Schwestern und zwei Aerzte erlauben Rollenwechsel")
	fenster.felder["Rezeption"].value = 2
	pruefe(fenster.get_ok_button().disabled and "zusätzlicher Rezeptionsplatz" in fenster.meldung.text, "Rollenwechsel braucht einen freien zusaetzlichen Rezeptionsplatz")
	fenster.felder["Rezeption"].value = 1
	fenster.get_ok_button().pressed.emit()
	pruefe(bool(szene.simulation.RollenwechselLesen()["aktiv"]), "Option im Kern aktiviert")
	pruefe(szene.personal_figuren.size() == 5, "Flexible Schwester wird nur einmal erzeugt")
	var flexibel: Node3D
	for figur in szene.personal_figuren:
		if figur.personal_id == "schwester_2":
			flexibel = figur
	pruefe(is_instance_valid(flexibel) and flexibel.qualifikationen == ["Schwester", "Rezeption"], "Schwester 2 hat beide Qualifikationen")
	var start := {}
	var gelesen := 0
	for schritt in 12000:
		szene.simulation.Fortschalten(0.005)
		var plan: Array = szene.simulation.DarstellungsplanLesen()
		for index in range(gelesen, plan.size()):
			if plan[index]["eventTyp"] == "personal_wechsel_start":
				start = plan[index]
				break
		gelesen = plan.size()
		if not start.is_empty() or szene.lauf_abgeschlossen:
			break
	pruefe(not start.is_empty(), "Kern erzeugt einen echten Rollenwechsel")
	if not start.is_empty():
		var dauer := float(start["bewegungsdauerMinuten"])
		var halbzeit := float(start["zeit"]) + dauer / 2.0
		szene.simulation.Fortschalten(maxf(0.0, halbzeit - szene.laufzeit) / 8.0)
		var wege = WEGE.new()
		var erwartung: Dictionary = wege._auf_weg(Vector2(4.5, 6.2), Vector2(-5.3, 4.25), 0.5)
		pruefe(flexibel.unterwegs and flexibel.animation.current_animation == "Gehen", "Schwesterfigur geht waehrend des Stationswechsels")
		pruefe(Vector2(flexibel.position.x, flexibel.position.z).is_equal_approx(erwartung["position"]), "Figur folgt bei halber Wegzeit dem Weg durch die Tueren")
		szene.simulation.Pausieren()
		var punkt: Vector3 = flexibel.position
		var minute: float = szene.laufzeit
		szene.simulation.Fortschalten(1.0)
		pruefe(flexibel.position == punkt and szene.laufzeit == minute, "Pause haelt auch die wechselnde Personalfigur fest")
		szene.simulation.Starten()
		szene.simulation.Fortschalten((float(start["zeit"]) + dauer + 0.0001 - szene.laufzeit) / 8.0)
		pruefe(flexibel.aktuelle_rolle == "Rezeption" and flexibel.arbeitsplatz_id == "rezeption_2", "Dieselbe Schwesterfigur arbeitet nach Ankunft an der Rezeption")
		pruefe(flexibel.rolle == "Schwester", "Stammrolle und Modell bleiben Schwester")
		szene.simulation.Fortschalten(10000.0)
		pruefe(szene.lauf_abgeschlossen and not szene.laeuft, "Rollenwechsel-Lauf bleibt bis Tagesende mit dem Vorlauf synchron")
		var rezeption_erkannt := false
		for ev in szene.simulation.DarstellungsplanLesen():
			if ev["eventTyp"] == "startet_rezeption" and ev["personalId"] == "schwester_2":
				rezeption_erkannt = true
		pruefe(rezeption_erkannt, "Patient wird von derselben Schwester an der Rezeption bearbeitet")
	szene._reset_simulation()
	pruefe(flexibel.position == flexibel.stammposition and flexibel.aktuelle_rolle == "Schwester" and not flexibel.unterwegs, "Reset stellt Stammplatz und Stammrolle wieder her")
	pruefe(szene.personal_figuren.size() == 5 and bool(szene.simulation.RollenwechselLesen()["aktiv"]), "Reset behaelt Qualifikation und Option ohne Duplikate")
	szene.personal_button.pressed.emit()
	pruefe(fenster.wechsel_option.button_pressed, "Fenster zeigt die aktive Wechseloption")
	fenster.wechsel_option.button_pressed = false
	fenster.get_ok_button().pressed.emit()
	pruefe(not bool(szene.simulation.RollenwechselLesen()["aktiv"]), "Rollenwechsel laesst sich fuer den naechsten Lauf deaktivieren")
	szene.queue_free()
	await process_frame
	print("GODOT-ROLLENWECHSEL: ", "BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN")
	quit(1 if fehler > 0 else 0)
