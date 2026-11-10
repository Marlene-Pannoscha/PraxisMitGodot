extends SceneTree

const TIMELINE = preload("res://PatientenTimeline.gd")
var fehler := 0
var pruefungen := 0

func _initialize() -> void:
	call_deferred("testen")

func pruefe(wahr: bool, text: String) -> void:
	pruefungen += 1
	if not wahr:
		push_error(text)
		fehler += 1

func testen() -> void:
	var szene = load("res://Main.tscn").instantiate()
	root.add_child(szene)
	await process_frame
	szene.set_process(false)
	pruefe(szene.simulation_bereit, "Originalkern geladen")
	szene._start_pause()
	szene.simulation.Fortschalten(15.0)
	szene._start_pause()
	pruefe(szene.patienten_welt.get_node("Praxis3D/Generated").get_child_count() > 100, "3D-Räume und Möbel vorhanden")
	pruefe(szene.get_node_or_null("Klinikgrundriss") == null, "2D-Grundriss ersetzt")
	var waende: Array[Rect2] = []
	for teil in szene.patienten_welt.get_node("Praxis3D/Generated").get_children():
		var mesh: BoxMesh = teil.mesh
		if is_equal_approx(mesh.size.x, 0.18) or is_equal_approx(mesh.size.z, 0.18):
			waende.append(Rect2(Vector2(teil.position.x - mesh.size.x / 2, teil.position.z - mesh.size.z / 2), Vector2(mesh.size.x, mesh.size.z)).grow(0.15))
	var t = szene.timeline
	var wege := 0
	for id in t.patienten:
		var verlauf: Array = t.patienten[id]
		for i in range(verlauf.size() - 1):
			if not verlauf[i]["bewegung"]:
				continue
			wege += 1
			var start: Vector2 = verlauf[i]["punkt"]
			var ziel: Vector2 = verlauf[i + 1]["punkt"]
			for j in range(101):
				var info: Dictionary = t._auf_weg(start, ziel, j / 100.0)
				for wand in waende:
					pruefe(not wand.has_point(info["position"]), "Patient %s geht durch eine Wand: %s -> %s bei %s" % [id, start, ziel, info["position"]])
	pruefe(wege > 0, "Reale Originalwege geprüft")
	var links: Vector2 = t._platz("test-arzt1", "Arzt", {"arztId": 1})
	var rechts: Vector2 = t._platz("test-arzt2", "Arzt", {"arztId": 2})
	pruefe(t._raum(links) == "Arzt1" and t._raum(rechts) == "Arzt2", "Ärzte nutzen ihre getrennten Zimmer")
	var vorne: Dictionary = t._auf_weg(links, rechts, 0.0)
	var hinten: Dictionary = t._auf_weg(links, rechts, 1.0)
	pruefe(vorne["position"].is_equal_approx(links) and hinten["position"].is_equal_approx(rechts), "3D-Weg hält Start und Ziel ein")
	var zoom_event := InputEventMouseButton.new()
	zoom_event.position = Vector2(640, 350)
	zoom_event.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom_event.pressed = true
	root.push_input(zoom_event, true)
	await process_frame
	pruefe(szene.kamera.size == 21, "Mausrad zoomt die 3D-Ansicht")
	var drehen := InputEventMouseButton.new()
	drehen.position = Vector2(640, 350)
	drehen.button_index = MOUSE_BUTTON_RIGHT
	drehen.pressed = true
	root.push_input(drehen, true)
	var bewegung := InputEventMouseMotion.new()
	bewegung.position = Vector2(660, 350)
	bewegung.relative = Vector2(20, 0)
	root.push_input(bewegung, true)
	await process_frame
	pruefe(szene.kamera_winkel < 45, "Rechte Maustaste dreht die 3D-Ansicht")
	drehen.pressed = false
	root.push_input(drehen, true)

	szene.kamera_winkel = 90
	szene.kamera_zoom = 30
	szene._kamera_zuruecksetzen()
	pruefe(szene.kamera_winkel == 45 and szene.kamera.size == 22, "Ansicht zurücksetzen")
	szene._aktualisiere_patienten(0)
	for id in szene.patienten_figuren:
		var figur: Node3D = szene.patienten_figuren[id]
		var punkt: Vector2 = szene._position_patient(id)["position"]
		pruefe(figur.position.is_equal_approx(Vector3(punkt.x, 0.06, punkt.y)), "Figuren stehen im 3D-Koordinatensystem")
		var pose: float = figur.animation.current_animation_position
		szene._aktualisiere_patienten(0)
		pruefe(is_equal_approx(pose, figur.animation.current_animation_position), "Pause hält die Animation an")
	# Gobkit liefert ein aufrecht importiertes Modell mit Geh- und Warteanimation.
	for figur in szene.patienten_figuren.values():
		var skelett: Skeleton3D = figur.find_child("Skeleton3D", true, false)
		pruefe(skelett != null and skelett.get_bone_count() > 0, "Gobkit-Skelett vorhanden")
		pruefe(figur.animation.has_animation("Gehen") and figur.animation.has_animation("Warten"), "Gobkit-Gehen und -Warten vorhanden")
		var mesh := figur.find_child("WardPatient", true, false) as MeshInstance3D
		pruefe(mesh != null and mesh.mesh.get_surface_count() > 0, "Gobkit-Patient hat 3D-Geometrie")
		var min_y := INF
		var max_y := -INF
		for knochen in range(skelett.get_bone_count()):
			var hoehe := skelett.to_global(skelett.get_bone_global_pose(knochen).origin).y
			min_y = minf(min_y, hoehe)
			max_y = maxf(max_y, hoehe)
		pruefe(max_y - min_y > 1.3 and max_y - min_y < 2.5, "Gobkit-Patient hat menschliche Groesse")
		figur.aktualisieren(figur.position, Vector3.FORWARD, 0.1)
		pruefe(figur.animation.current_animation == "Gehen", "Gobkit-Patient geht")
		figur.aktualisieren(figur.position, Vector3.ZERO, 0.1)
		pruefe(figur.animation.current_animation == "Warten", "Gobkit-Patient wartet")

	szene.queue_free()
	await process_frame
	print("3D-RAUM: %d Wege, %d Prüfungen, %d Fehler" % [wege, pruefungen, fehler])
	quit(1 if fehler > 0 else 0)
