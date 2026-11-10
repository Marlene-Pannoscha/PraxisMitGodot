extends SceneTree

const PERSONAL = preload("res://Personal.gd")
const TIMELINE = preload("res://PatientenTimeline.gd")
var fehler := 0

func _initialize() -> void:
	call_deferred("testen")

func pruefe(bedingung: bool, beschreibung: String) -> void:
	if not bedingung:
		push_error(beschreibung)
		fehler += 1

func testen() -> void:
	var anzahl := {"Rezeption": 0, "Schwester": 0, "Arzt": 0}
	for platz in TIMELINE.PERSONAL_PLAETZE:
		var figur := Node3D.new()
		figur.set_script(PERSONAL)
		figur.rolle = String(platz["rolle"])
		root.add_child(figur)
		anzahl[figur.rolle] += 1
		pruefe(figur.animation != null and figur.animation.current_animation == "Warten", "Personalfigur mit Idle-Animation: " + figur.rolle)
		figur.aktualisieren(0.1)
		figur.queue_free()
	pruefe(anzahl == {"Rezeption": 1, "Schwester": 1, "Arzt": 2}, "Personal an vier Arbeitsplaetzen")
	print("PERSONAL: %s" % ("BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN"))
	quit(1 if fehler > 0 else 0)
