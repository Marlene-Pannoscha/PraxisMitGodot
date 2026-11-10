extends SceneTree

const PATIENT = preload("res://Patient.gd")
var fehler := 0

func _initialize() -> void:
	call_deferred("testen")

func pruefe(bedingung: bool, beschreibung: String) -> void:
	if not bedingung:
		push_error(beschreibung)
		fehler += 1

func testen() -> void:
	var figur := Node3D.new()
	figur.set_script(PATIENT)
	root.add_child(figur)
	await process_frame
	pruefe(figur.skelett != null and figur.bein_grundpose.size() == 4, "Vier Beinknochen fuer die Sitzpose gefunden")
	figur.aktualisieren(Vector3(-8.5, 0.06, -5.0), Vector3.ZERO, 0.1, "Wartezimmer")
	pruefe(figur.sitzt and figur.animation.current_animation == "Sitzen", "Wartezimmer: sitzende Figur")
	var oberschenkel: int = figur.skelett.find_bone("ufsvxn")
	pruefe(not figur.skelett.get_bone_pose_rotation(oberschenkel).is_equal_approx(figur.bein_grundpose[oberschenkel]), "Sitzpose beugt die Beine")
	pruefe(is_equal_approx(figur.rotation.y, PI), "Figur blickt von der Stuhllehne weg")
	figur.aktualisieren(Vector3(-9.0, 0.06, -1.6), Vector3.ZERO, 0.1, "Wartezimmer")
	pruefe(not figur.sitzt and figur.animation.current_animation == "Warten", "Ohne Stuhl: stehende Figur")
	figur.aktualisieren(Vector3(2.0, 0.06, 4.5), Vector3.ZERO, 0.1, "Schwester")
	pruefe(figur.sitzt and is_zero_approx(figur.rotation.y), "Schwester: zur Behandlung ausgerichtet")
	figur.aktualisieren(Vector3(6.5, 0.06, -4.0), Vector3.ZERO, 0.1, "Arzt")
	pruefe(figur.sitzt and figur.animation.current_animation == "Sitzen", "Arzt: sitzende Figur")
	figur.aktualisieren(figur.position, Vector3.FORWARD, 0.1, "Arzt")
	pruefe(not figur.sitzt and figur.animation.current_animation == "Gehen", "Nach der Behandlung: gehende Figur")
	figur.queue_free()
	print("PATIENT SITZEN: %s" % ("BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN"))
	quit(1 if fehler > 0 else 0)
