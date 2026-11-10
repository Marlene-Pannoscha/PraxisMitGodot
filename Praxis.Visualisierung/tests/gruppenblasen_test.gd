extends SceneTree

var fehler := 0

func pruefe(bedingung: bool, text: String) -> void:
	if bedingung:
		print("OK: ", text)
	else:
		push_error(text)
		fehler += 1

func patient(szene: Node, id: String, position: Vector3) -> void:
	var figur := Node3D.new()
	figur.position = position
	szene.patienten_welt.add_child(figur)
	szene.patienten_figuren[id] = figur

func entfernen(szene: Node, id: String) -> void:
	var figur: Node3D = szene.patienten_figuren[id]
	szene.patienten_figuren.erase(id)
	figur.queue_free()

func _initialize() -> void:
	call_deferred("testen")

func testen() -> void:
	var szene = load("res://Main.tscn").instantiate()
	root.add_child(szene)
	await process_frame
	szene.set_process(false)
	for index in 6:
		patient(szene, "test%d" % index, Vector3((index % 3) * 0.4, 0, (index / 3) * 0.4))
	szene._aktualisiere_gruppenblasen()
	pruefe(szene.gruppen_blasen.size() == 1 and szene.gruppen_blasen[0].visible, "Blase erscheint ab 6 nahen Patienten")
	pruefe((szene.gruppen_blasen[0].get_node("Anzahl") as Label3D).text == "6 Personen", "Blase zeigt aktuelle Personenzahl")
	patient(szene, "test6", Vector3(0.8, 0, 0.4))
	szene._aktualisiere_gruppenblasen()
	pruefe((szene.gruppen_blasen[0].get_node("Anzahl") as Label3D).text == "7 Personen", "Blase aktualisiert hinzukommende Patienten")
	entfernen(szene, "test5")
	entfernen(szene, "test6")
	szene._aktualisiere_gruppenblasen()
	pruefe(not szene.gruppen_blasen[0].visible, "Blase verschwindet bei höchstens 5 Patienten")

	for id in szene.patienten_figuren.keys():
		if String(id).begins_with("test"):
			entfernen(szene, String(id))
	for index in 6:
		var id := "links%d" % index
		patient(szene, id, Vector3((index % 3) * 0.15, 0, (index / 3) * 0.15))
		patient(szene, "rechts%d" % index, Vector3(3.0 + (index % 3) * 0.15, 0, (index / 3) * 0.15))
	szene._aktualisiere_gruppenblasen()
	pruefe(szene.gruppen_blasen.size() >= 2 and szene.gruppen_blasen[0].visible and szene.gruppen_blasen[1].visible, "Zwei getrennte Gruppen erhalten zwei Blasen")
	pruefe(not is_equal_approx(szene.gruppen_blasen[0].position.y, szene.gruppen_blasen[1].position.y), "Nahe Blasen werden gegen Überlappung versetzt")
	szene.queue_free()
	await process_frame
	print("GRUPPENBLASEN: ", "BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN")
	quit(1 if fehler > 0 else 0)
