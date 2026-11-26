extends SceneTree
## Rezeptionsmoebel und Sitzposen mit beiden erlaubten Modellen, ohne Layout zu speichern.
const PERSONAL = preload("res://Personal/Personal.gd")
const PRAXIS = preload("res://Raum3D/Praxis.gd")
const LAYOUT = preload("res://PraxisLayout.gd")
var fehler := 0

func _initialize() -> void:
	call_deferred("testen")

func pruefe(bedingung: bool, beschreibung: String) -> void:
	if not bedingung:
		push_error(beschreibung)
		fehler += 1

func testen() -> void:
	for modell in ["Rezeption", "Schwester"]:
		var person := Node3D.new()
		person.set_script(PERSONAL)
		person.rolle = "Rezeption"
		person.modell = modell
		person.position = Vector3(2.0, 0.06, 3.0)
		root.add_child(person)
		var skelett: Skeleton3D = person.skelett
		var oberschenkel := "nhwq6v" if modell == "Rezeption" else "ufsvxn"
		var unterschenkel := "tcqu6j" if modell == "Rezeption" else "arj5mw"
		for delta in [0.0, 0.1, 0.5]:
			person.aktualisieren(delta)
			var huefte := skelett.to_global(skelett.get_bone_global_pose(skelett.find_bone(oberschenkel)).origin)
			var knie := skelett.to_global(skelett.get_bone_global_pose(skelett.find_bone(unterschenkel)).origin)
			pruefe(absf(huefte.y - 0.56) < 0.03, "Huefte bleibt ueber der Sitzflaeche: " + modell)
			pruefe(knie.z > huefte.z + 0.25, "Knie zeigen zum Tisch statt zur Stuhllehne: " + modell)
		pruefe(person.position.is_equal_approx(Vector3(2.0, 0.06, 3.0)), "Sitzpose verschiebt keinen Arbeitsplatz")
		pruefe(person.modell == modell and person.rolle == "Rezeption", "Sitzpose erhaelt Modell und Einsatzrolle")
		person.queue_free()
	var praxis := Node3D.new()
	praxis.set_script(PRAXIS)
	var daten: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://praxis-layout-standard.json"))
	# Auch eine seitlich gedrehte Rezeption muss Tisch und Stuhl passend ausrichten.
	for platz in daten["arbeitsplaetze"]:
		if platz["qualifikation"] == "Rezeption":
			platz["winkel_grad"] = 90.0
	praxis.layout_daten = daten
	root.add_child(praxis)
	for platz in daten["arbeitsplaetze"]:
		if platz["qualifikation"] != "Rezeption":
			continue
		var punkt := Vector3(float(platz["position"][0]), 0.0, float(platz["position"][1]))
		var tische := 0
		var stuehle := 0
		for objekt in praxis.generated.get_children():
			if not objekt is MeshInstance3D:
				continue
			if objekt.position.distance_to(punkt + Vector3(0.8, 0.75, 0.0)) < 0.001:
				tische += 1
				pruefe(objekt.mesh.size.x > objekt.mesh.size.z, "Rezeption hat eine rechteckige Tischplatte")
				pruefe(absf(objekt.rotation.y - PI / 2.0) < 0.001, "Tisch folgt der Blickrichtung am Arbeitsplatz")
			if objekt.position.distance_to(punkt + Vector3(0.0, 0.45, 0.0)) < 0.001:
				stuehle += 1
		pruefe(tische == 1 and stuehle == 1, "Genau ein Tisch und ein Stuhl je Rezeptionsplatz")
	pruefe(not praxis.generated.get_children().any(func(objekt): return String(objekt.name).begins_with("Empfangstresen")), "Alter hoher Tresen wird ersetzt")
	praxis.queue_free()
	# Die gewaehlte Wandaufstellung darf beim Oeffnen des Baumodus nicht wieder
	# in die Raummitte springen. Der direkte Durchgang muss moebelfrei bleiben.
	var layout = LAYOUT.new()
	pruefe(layout.laden("res://praxis-layout-standard.json").is_empty(), "Empfangs-Testlayout ist gueltig")
	for raum in layout.raeume:
		if raum["typ"] == "Rezeption":
			raum["arbeitsplaetze_anordnung"] = "linke_wand"
	layout.baumodus_vorbereiten()
	var vorher := {}
	for platz in layout.daten["arbeitsplaetze"]:
		if platz["qualifikation"] == "Rezeption":
			vorher[platz["id"]] = platz.duplicate(true)
	layout.baumodus_vorbereiten()
	var eingang := Vector2.ZERO
	var flurtuer := Vector2.ZERO
	for tuer in layout.daten["tueren"]:
		if tuer["id"] == "eingang":
			eingang = Vector2(float(tuer["position"][0]), float(tuer["position"][1]))
		if tuer["id"] == "Rezeption_tuer":
			flurtuer = Vector2(float(tuer["position"][0]), float(tuer["position"][1]))
	for platz in layout.daten["arbeitsplaetze"]:
		if platz["qualifikation"] != "Rezeption":
			continue
		var punkt := Vector2(float(platz["position"][0]), float(platz["position"][1]))
		var alt: Array = vorher[platz["id"]]["position"]
		pruefe(punkt.distance_to(Vector2(float(alt[0]), float(alt[1]))) < 0.01, "Empfangsplatz bleibt beim Oeffnen des Baumodus an der Wand")
		pruefe(absf(float(platz["winkel_grad"]) - 90.0) < 0.01, "Personal blickt von der Wand in den Raum")
		var tisch := Rect2(punkt + Vector2(0.8, 0.0) - Vector2(0.375, 0.75), Vector2(0.75, 1.5)).grow(0.25)
		var stuhl := Rect2(punkt - Vector2(0.325, 0.325), Vector2(0.65, 0.65)).grow(0.25)
		for schritt in range(101):
			var durchgang := eingang.lerp(flurtuer, float(schritt) / 100.0)
			pruefe(not tisch.has_point(durchgang) and not stuhl.has_point(durchgang), "Durchgang zwischen Eingang und Flur bleibt frei")
	await process_frame
	print("REZEPTION SITZEN: %s" % ("BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN"))
	quit(1 if fehler > 0 else 0)
