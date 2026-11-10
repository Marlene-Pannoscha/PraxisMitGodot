extends SceneTree
const TIMELINE = preload("res://PatientenTimeline.gd")
var fehler := 0
func pruefe(wahr: bool, text: String) -> void:
	if not wahr:
		push_error(text)
		fehler += 1
	else:
		print("OK: " + text)
func ev(t: float, typ: String, id: int = 1, arzt: int = 0, schwester: int = 0) -> Dictionary:
	return {"zeit": t, "eventTyp": typ, "patientId": id, "arztId": arzt, "schwesterId": schwester}
func _initialize() -> void:
	var t = TIMELINE.new()
	var plan: Array = [ev(0, "betritt_klinik"), ev(0, "geht_zur_rezeption"),
		ev(1, "betritt_rezeption_warteschlange"), ev(2, "betritt_rezeption"), ev(2, "startet_rezeption"),
		ev(5, "prognose_pruefung"), ev(10, "beendet_rezeption"), ev(10, "geht_ins_wartezimmer_schwester"),
		ev(11, "betritt_wartezimmer_schwester"), ev(12, "geht_zur_schwester"), ev(13, "betritt_schwesterzimmer"),
		ev(13, "startet_schwester_prozess", 1, 0, 2), ev(15, "beendet_schwester_prozess"),
		ev(15, "geht_ins_wartezimmer_fuer_arzt"), ev(16, "betritt_wartezimmer_fuer_arzt"),
		ev(20, "geht_zum_arzt"), ev(21, "betritt_arztzimmer"), ev(21, "startet_arzt_behandlung", 1, 2),
		ev(30, "beendet_arzt_behandlung"), ev(30, "geht_nach_arzt_zur_rezeption"),
		ev(31, "betritt_rezeption_warteschlange"), ev(32, "startet_rezeption"), ev(35, "geht_zum_ausgang"), ev(36, "verlaesst_klinik")]
	t.laden(plan)
	pruefe(t.zustand("1", -1).is_empty(), "Vor Eintritt unsichtbar")
	var a: Dictionary = t.zustand("1", 3)
	var b: Dictionary = t.zustand("1", 9)
	pruefe(a["position"] == b["position"] and a["richtung"] == Vector2.ZERO, "Während Behandlung stehen, auch über Prognosemeldungen hinweg")
	var unterwegs: Dictionary = t.zustand("1", 10.5)
	pruefe(unterwegs["richtung"] != Vector2.ZERO and unterwegs["position"] != b["position"], "Nur innerhalb protokollierter Wege bewegen")
	pruefe(t.zustand("1", 14)["station"] == "Schwester", "Schwesterstation erkannt")
	pruefe(t.zustand("1", 14)["position"] == Vector2(4.5, 4.5), "Schwester-ID für Sitzposition übernommen")
	pruefe(t.zustand("1", 25)["station"] == "Arzt", "Arztstation erkannt")
	pruefe(t.zustand("1", 25)["position"] == Vector2(6.5, -4.0), "Arzt-ID für Sitzposition übernommen")
	pruefe(t.zustand("1", 33)["station"] == "Rezeption", "Rückkehr zur Rezeption erkannt")
	pruefe(not t.zustand("1", 35.9)["ausgetreten"] and t.zustand("1", 36)["ausgetreten"], "Erst beim Original-Austrittsereignis ausblenden")
	t.laden([ev(0, "wartet_vor_oeffnung"), ev(1, "abgewiesen_vor_klinik_wegen_aufnahmeprognose")])
	pruefe(t.zustand("1", 10).is_empty(), "Außerhalb abgewiesene Personen bleiben unsichtbar")
	t.laden([ev(0, "betritt_klinik"), ev(1, "prognose_abbruch"), ev(1, "geht_zum_ausgang"), ev(2, "verlaesst_klinik")])
	pruefe(t.zustand("1", 1.5)["richtung"] != Vector2.ZERO and t.zustand("1", 2)["ausgetreten"], "Prognoseabbruch folgt dem Originalweg zum Ausgang")
	print("TIMELINE: ", "BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN")
	quit(1 if fehler > 0 else 0)
