extends SceneTree
## Prueft Entwurf, Platzpruefung und neue Offline-Laeufe ueber die echte Personaloberflaeche.

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
	var quellhashes := {}
	for datei in ["rezeption-konfiguration.json", "arzt-konfiguration.json", "schwester-konfiguration.json"]:
		var pfad := ProjectSettings.globalize_path("res://../simSharpSimulation/simSharpSimulation/Ressourcen/" + datei)
		quellhashes[pfad] = FileAccess.get_sha256(pfad)
	var szene = load("res://Main.tscn").instantiate()
	root.add_child(szene)
	await process_frame
	szene.set_process(false)
	pruefe(szene.simulation_bereit, "Offline-Szene geladen")
	if not szene.simulation_bereit:
		szene.queue_free()
		quit(1)
		return
	var standard: Dictionary = szene.simulation.PersonalStandardwerteLesen()
	pruefe(not szene.personal_button.disabled, "Personaleinstellungen im Offline-Modus verfuegbar")
	szene.personal_button.pressed.emit()
	var fenster = szene.personal_fenster
	pruefe(fenster.visible and fenster.eingaben() == standard, "Fenster oeffnet mit den aktiven Werten")
	pruefe(fenster.is_embedded(), "Personalfenster ist in die Anwendung eingebettet")
	await process_frame
	await process_frame
	# Headless hat kein echtes Bildschirmrechteck fuer die Fensterzentrierung.
	if DisplayServer.get_name() != "headless":
		pruefe(fenster.size.y < root.size.y and fenster.position.y >= 0, "Personalfenster passt vollstaendig in die Anwendung")
	pruefe(fenster.platz_labels["Rezeption"].text == "2 vorhanden", "Fenster zeigt die vorhandenen Arbeitsplaetze")
	pruefe(fenster.platz_labels["Schwester"].text == "2 vorhanden", "Zwei Schwesterplaetze vorhanden")
	for rolle in standard:
		pruefe(fenster.aktiv_labels[rolle].text == str(standard[rolle]), "Aktive Zahl sichtbar: " + rolle)

	szene._start_pause()
	szene.simulation.Fortschalten(1.0)
	var bisher: Dictionary = szene.simulation.ZustandLesen()
	fenster.felder["Rezeption"].value = 2
	pruefe(szene.simulation.PersonalzahlenLesen() == standard, "Entwurf veraendert die Simulation nicht")
	pruefe(szene.simulation.ZustandLesen() == bisher, "Bearbeitung im Fenster laesst Laufzeit und Ereignisse unveraendert")
	fenster.felder["Arzt"].value = 3
	pruefe(fenster.get_ok_button().disabled and "Arzt: 3" in fenster.meldung.text, "Fehlender dritter Arztplatz sperrt Uebernehmen")
	fenster.confirmed.emit()
	pruefe(szene.simulation.ZustandLesen() == bisher, "Gesperrte Eingabe startet keinen neuen Lauf")
	pruefe(not szene._personal_uebernehmen({"Rezeption": 2, "Schwester": 1, "Arzt": 3}).is_empty(), "Auch direkter Aufruf prueft Arbeitsplaetze")
	pruefe(szene.simulation.ZustandLesen() == bisher, "Abgewiesene Platzpruefung behaelt den bisherigen Lauf")
	for ungueltig in [{}, {"Rezeption": 0, "Schwester": 1, "Arzt": 2}, {"Rezeption": 1.5, "Schwester": 1, "Arzt": 2}, {"Rezeption": 1, "Schwester": 1, "Arzt": 2, "Andere": 1}]:
		pruefe(not szene.simulation.PersonalzahlenAnwenden(ungueltig).is_empty(), "Bridge weist ungueltige Werte ab")
		pruefe(szene.simulation.ZustandLesen() == bisher and szene.simulation.PersonalzahlenLesen() == standard, "Ungueltige Werte veraendern weder Konfiguration noch Lauf")
	fenster.get_cancel_button().pressed.emit()
	pruefe(not fenster.visible and szene.simulation.PersonalzahlenLesen() == standard, "Abbrechen verwirft den Entwurf")
	szene.personal_button.pressed.emit()
	pruefe(fenster.eingaben() == standard, "Erneutes Oeffnen zeigt aktive Werte statt alten Entwurfs")
	fenster.felder["Rezeption"].value = 1
	fenster.felder["Schwester"].value = 2
	fenster.felder["Arzt"].value = 2
	pruefe(not fenster.get_ok_button().disabled, "Eine Rezeptionskraft, zwei Schwestern und zwei Aerzte passen ins Layout")
	fenster.get_ok_button().pressed.emit()
	var angepasst := {"Rezeption": 1, "Schwester": 2, "Arzt": 2}
	pruefe(not fenster.visible, "Erfolgreiches Uebernehmen schliesst das Fenster")
	pruefe(szene.simulation.PersonalzahlenLesen() == angepasst, "Neue Zahlen im Simulationskern uebernommen")
	pruefe(szene.simulation.PersonalStandardwerteLesen() == standard, "Standardwerte bleiben unabhaengig vom aktiven Lauf")
	pruefe(szene.laufzeit == 0.0 and szene.live_ereignisse == 0 and szene.patienten.is_empty() and szene.laeuft, "Neustart setzt Uhr und Patienten zurueck und startet den neuen Lauf")
	pruefe(szene.simulationslauf == int(bisher["lauf"]) + 1, "Uebernehmen erzeugt genau einen neuen Lauf")
	var sichtbar := {"Rezeption": 0, "Schwester": 0, "Arzt": 0}
	for figur in szene.personal_figuren:
		sichtbar[figur.rolle] += 1
	pruefe(sichtbar == angepasst, "Figuren wurden passend hinzugefuegt und entfernt")
	szene.simulation.Fortschalten(10000.0)
	pruefe(bool(szene.simulation.ZustandLesen()["abgeschlossen"]), "Geaenderte Personalzahlen laufen mit neuem Vorlauf bis Tagesende")
	szene._reset_simulation()
	pruefe(szene.simulation.PersonalzahlenLesen() == angepasst and szene.personal_figuren.size() == 5, "Reset behaelt die uebernommenen Zahlen ohne Duplikate")
	szene.personal_button.pressed.emit()
	pruefe(fenster.eingaben() == angepasst, "Fenster zeigt nach Neustart die angepassten Zahlen")
	fenster.felder["Arzt"].value = 1
	fenster.get_ok_button().pressed.emit()
	angepasst = {"Rezeption": 1, "Schwester": 2, "Arzt": 1}
	pruefe(szene.simulation.PersonalzahlenLesen() == angepasst and szene.personal_figuren.size() == 4, "Personal reduzieren entfernt eine Figur und aendert die Kernkapazitaet")
	szene.personal_button.pressed.emit()
	fenster.custom_action.emit(&"standard")
	pruefe(fenster.eingaben() == standard and szene.simulation.PersonalzahlenLesen() == angepasst, "Standardwerte laden veraendert nur den Entwurf")
	fenster.get_ok_button().pressed.emit()
	pruefe(szene.simulation.PersonalzahlenLesen() == standard, "Standardwerte mit neuem Lauf wiederhergestellt")
	for pfad in quellhashes:
		pruefe(not String(quellhashes[pfad]).is_empty() and FileAccess.get_sha256(pfad) == quellhashes[pfad], "Simulations-Quelldatei unveraendert: " + String(pfad).get_file())
	szene.queue_free()
	await process_frame
	print("GODOT-PERSONALFENSTER: ", "BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN")
	quit(1 if fehler > 0 else 0)
