extends SceneTree
const MAIN = preload("res://Main.gd")
var fehler := 0

func pruefe(wahr: bool, text: String) -> void:
	if wahr:
		print("OK: " + text)
	else:
		push_error(text)
		fehler += 1

func ev(t: float, typ: String, id: int, arzt: int = 0, schwester: int = 0) -> Dictionary:
	return {"zeit": t, "eventTyp": typ, "patientId": id, "arztId": arzt,
		"schwesterId": schwester, "bewegungsdauerMinuten": 0.0}

func _initialize() -> void:
	var szene = MAIN.new()
	root.add_child(szene)
	await process_frame
	pruefe(szene.zimmer_leuchten.size() == 3, "Zwei Arzt- und eine Schwesternleuchte vorhanden")
	pruefe((szene.zimmer_leuchten["Arzt1"].get_node("Status") as Label3D).text == "FREI", "Zimmer sind initial frei")
	var plan: Array = [ev(0, "betritt_klinik", 1), ev(1, "startet_arzt_behandlung", 1, 2)]
	szene.timeline.laden(plan)
	szene.patienten = szene.timeline.patienten
	szene.laufzeit = 2.0
	szene._aktualisiere_zimmerleuchten()
	pruefe((szene.zimmer_leuchten["Arzt1"].get_node("Status") as Label3D).text == "FREI", "Nicht behandelndes Arztzimmer bleibt frei")
	pruefe((szene.zimmer_leuchten["Arzt2"].get_node("Status") as Label3D).text == "BELEGT", "Arztzimmer wird anhand der SimSharp-Arzt-ID belegt")
	plan = [ev(0, "betritt_klinik", 2), ev(1, "startet_schwester_prozess", 2, 0, 1)]
	szene.timeline.laden(plan)
	szene.patienten = szene.timeline.patienten
	szene._aktualisiere_zimmerleuchten()
	pruefe((szene.zimmer_leuchten["Schwester1"].get_node("Status") as Label3D).text == "BELEGT", "Schwesternzimmer wird bei Behandlung belegt")
	szene.timeline.laden([])
	szene.patienten = szene.timeline.patienten
	szene._aktualisiere_zimmerleuchten()
	pruefe((szene.zimmer_leuchten["Arzt2"].get_node("Status") as Label3D).text == "FREI" and (szene.zimmer_leuchten["Schwester1"].get_node("Status") as Label3D).text == "FREI", "Zimmer werden nach Behandlung wieder frei")
	print("ZIMMERLEUCHTEN: ", "BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN")
	quit(1 if fehler else 0)
