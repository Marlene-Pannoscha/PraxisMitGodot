extends SceneTree
## Reproduziert die freie rechte Flaeche aus dem Baumodus, ohne das Nutzerlayout zu speichern.

const LAYOUT = preload("res://PraxisLayout.gd")
const BAU_FENSTER = preload("res://UI/Baukonfiguration.gd")
const VERWALTUNG = preload("res://Personal/PersonalVerwaltung.gd")
var fehler := 0

func _initialize() -> void:
	call_deferred("testen")

func pruefe(bedingung: bool, text: String) -> void:
	if bedingung:
		print("OK: ", text)
	else:
		push_error(text)
		fehler += 1

func testen() -> void:
	var quellhash := FileAccess.get_sha256("res://praxis-layout.json")
	var modell = LAYOUT.new()
	pruefe(modell.aus_json_text(modell.standard_json_text()).is_empty(), "Standardvorlage geladen")
	modell.baumodus_vorbereiten()
	var schwester_index: int = modell._raum_index("Schwester")
	modell.groesse_setzen(schwester_index, Vector2(3.5, 5))
	modell.verschieben(schwester_index, Vector2(2, 4.5))
	var ziel := Vector2(8.5, 3.5)
	pruefe(not modell.platzierung_pruefen(ziel, Vector2(4, 4)).is_empty(), "Bisherige feste 4-x-4-Groesse ragt am rechten Rand hinaus")
	pruefe(modell.platzierung_pruefen(ziel, Vector2(3, 3)).is_empty(), "Kleiner 3-x-3-Raum passt rechts mit direktem Fluranschluss")
	var vorher := VERWALTUNG.planen({"Rezeption": 1, "Schwester": 1, "Arzt": 2}, modell.daten["arbeitsplaetze"])
	var fenster = BAU_FENSTER.new()
	root.gui_embed_subwindows = true
	root.add_child(fenster)
	await process_frame
	pruefe(fenster.vorbereiten(modell.als_json_text()).is_empty(), "Baumodus uebernimmt den verkleinerten Bestandsraum")
	fenster.popup_centered()
	await process_frame
	var alter_raum: String = JSON.stringify(fenster.entwurf.raeume[schwester_index])
	fenster.neue_breite_feld.value = 2.5
	fenster.neue_tiefe_feld.value = 3.5
	pruefe(JSON.stringify(fenster.entwurf.raeume[schwester_index]) == alter_raum, "Neue Raummasse veraendern den ausgewaehlten Bestandsraum nicht")
	fenster.neue_breite_feld.value = 3
	fenster.neue_tiefe_feld.value = 3
	fenster.neuer_typ.select(LAYOUT.EDITIERBARE_TYPEN.find("Schwester"))
	fenster._platzierung_starten()
	pruefe(fenster.grundriss.platzierung_groesse == Vector2(3, 3), "Platzierungsvorschau verwendet die eingegebenen Masse")
	var bewegung := InputEventMouseMotion.new()
	bewegung.position = fenster.grundriss._welt_zu_bildschirm(ziel)
	fenster.grundriss._gui_input(bewegung)
	await process_frame
	pruefe(fenster.grundriss.platzierung_sichtbar, "Mausbewegung zeigt die Raumvorschau")
	var klick := InputEventMouseButton.new()
	klick.button_index = MOUSE_BUTTON_LEFT
	klick.pressed = true
	klick.position = bewegung.position
	fenster.grundriss._gui_input(klick)
	var neu_index: int = fenster.entwurf.raeume.size() - 1
	var raum: Dictionary = fenster.entwurf.raeume[neu_index]
	pruefe(fenster.entwurf.raeume.size() == modell.raeume.size() + 1 and raum["typ"] == "Schwester", "Mausklick platziert einen zusaetzlichen Schwesterraum")
	pruefe(fenster.entwurf.groesse(neu_index) == Vector2(3, 3), "Gebauter Raum hat die vorgewaehlten 3 x 3 Meter")
	pruefe(fenster.entwurf.position(neu_index) == ziel and fenster.entwurf.hat_direkten_fluranschluss(neu_index), "Raummitte und eigene Flurtuer stimmen")
	pruefe(raum["arbeitsplaetze"].size() == 1 and raum["ausstattung"].size() == 2, "Kleiner Schwesterraum erhaelt Arbeitsplatz, Tisch und Stuhl")
	pruefe(fenster._pruefen(), "Entwurf mit kleinem Raum kann uebernommen werden")
	var plan := VERWALTUNG.baumodus_planen(modell.daten, fenster.entwurf.daten, vorher["plaetze"])
	pruefe(plan["fehler"] == "" and plan["konfiguration"]["anzahlen"]["Schwester"] == 2, "Auch ein kleiner neuer Schwesterraum bekommt eine zusaetzliche Schwester")
	pruefe(plan["konfiguration"]["zuordnungen"]["schwester_2"] == raum["arbeitsplaetze"][0], "Neue Schwester ist genau dem kleinen Raum zugeordnet")
	fenster._grundriss_platzierung("Schwester", "Rechteck", Vector2(10, 6))
	pruefe(fenster.entwurf.raeume.size() == modell.raeume.size() + 1 and "innerhalb" in fenster.meldung.text, "Ungueltiger Klick ausserhalb legt keinen Raum an")
	fenster._grundriss_platzierung("Schwester", "L-Form", Vector2(5.5, 3.5))
	var l_index: int = fenster.entwurf.raeume.size() - 1
	pruefe(fenster.entwurf.raeume[l_index].get("form", "") == "L-Form" and fenster.entwurf.groesse(l_index) == Vector2(3, 3), "Auch kleine L-Formen nutzen die gewaehlte Groesse")
	pruefe(is_equal_approx(fenster.entwurf._raum_flaeche(l_index), 6.75), "L-Form hat die korrekte kleinere Polygonflaeche")
	pruefe(fenster._pruefen(), "Kleine Rechteck- und L-Raeume bleiben gemeinsam gueltig")
	fenster.queue_free()
	await process_frame
	pruefe(FileAccess.get_sha256("res://praxis-layout.json") == quellhash, "Nutzerlayout unveraendert")
	print("KLEINER-RAUM: ", "BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN")
	quit(1 if fehler > 0 else 0)
