extends SceneTree
const LAYOUT = preload("res://PraxisLayout.gd")
const PRAXIS = preload("res://Raum3D/Praxis.tscn")
const BAU_FENSTER = preload("res://UI/Baukonfiguration.gd")
const RAUM_WEGE = preload("res://Raum3D/RaumWege.gd")
var fehler := 0

func pruefe(wahr: bool, text: String) -> void:
	if wahr:
		print("OK: " + text)
	else:
		push_error(text)
		fehler += 1

func _initialize() -> void:
	call_deferred("testen")

func testen() -> void:
	var layout = LAYOUT.new()
	var ladefehler: String = layout.laden("res://praxis-layout.json")
	pruefe(ladefehler.is_empty(), "Vollstaendiges Praxislayout wird aus einer JSON-Datei geladen")
	var standard = LAYOUT.new()
	pruefe(standard.aus_json_text(layout.standard_json_text(), "Standardlayout").is_empty(), "Unveraenderliche Standardvorlage ist gueltig")
	var geometrie = LAYOUT.new()
	geometrie.aus_json_text(layout.standard_json_text(), "Geometrietest")
	pruefe(not geometrie.platzierung_pruefen(Vector2(0, -3.75), Vector2(4, 4)).is_empty(), "Kollisionspruefung verhindert ueberlappende Raeume")
	var warte_index := -1
	for raum_index in geometrie.raeume.size():
		if String(geometrie.raeume[raum_index]["typ"]) == "Wartezimmer":
			warte_index = raum_index
			break
	geometrie.entfernen(warte_index)
	pruefe(not geometrie.platzierung_pruefen(Vector2(-7, -5), Vector2(3, 2)).is_empty(), "Freier, aber nicht erreichbarer Platz wird abgelehnt")
	var anschluss_fehler: String = geometrie.platzierung_pruefen(Vector2(-6.5, -2.7), Vector2(4, 4))
	pruefe(anschluss_fehler.is_empty(), "Platz mit gemeinsamer Flurkante ist erreichbar: " + anschluss_fehler)
	var polygon_layout = LAYOUT.new()
	polygon_layout.aus_json_text(layout.standard_json_text(), "Polygontest")
	var l_raum: Dictionary = polygon_layout.hinzufuegen("Arzt", Vector2(0, 0), "L-Form")
	var l_index: int = polygon_layout.raeume.size() - 1
	pruefe(l_raum.get("grundriss", []).size() == 6 and l_raum.get("form", "") == "L-Form", "L-foermiger Raum besitzt sechs Polygonpunkte")
	pruefe(is_equal_approx(polygon_layout._raum_flaeche(l_index), 12.0), "Kapazitaet einer L-Form nutzt die tatsaechliche Polygonflaeche")
	pruefe(l_raum["waende"].size() == 6, "L-foermiger Raum erhaelt eine Wand je Polygonkante")
	var l_wege = RAUM_WEGE.new()
	var l_polygon := PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 0), Vector2(0, 0), Vector2(0, 2), Vector2(-2, 2)])
	var l_innenweg: Array[Vector2] = l_wege._innenweg(Vector2(1, -0.5), Vector2(-0.5, 1), l_polygon)
	var weg_bleibt_innen := l_innenweg.size() >= 3
	for weg_index in range(1, l_innenweg.size()):
		weg_bleibt_innen = weg_bleibt_innen and l_wege._segment_liegt_im_raum(l_innenweg[weg_index - 1], l_innenweg[weg_index], l_polygon)
	pruefe(weg_bleibt_innen, "Wege in einer L-Form umgehen die ausgesparte Ecke und Waende")
	polygon_layout.groesse_setzen(l_index, Vector2(8, 6))
	pruefe(is_equal_approx(polygon_layout._raum_flaeche(l_index), 36.0), "L-Form wird proportional skaliert")
	var form_pruefung = LAYOUT.new()
	form_pruefung.aus_json_text(layout.standard_json_text(), "Formkollision")
	var test_flur := {"id": "TestFlur", "typ": "Flur", "name": "Flur", "position": [0.0, 0.02, 3.0],
		"groesse": [4.0, 0.04, 2.0], "farbe": "#eeeeee", "tueren": [], "arbeitsplaetze": [],
		"warteplaetze": [], "ausstattung": [], "statusleuchten": []}
	var test_blocker := {"id": "Blocker", "typ": "Arzt", "name": "Blocker", "position": [1.0, 0.02, 1.0],
		"groesse": [1.5, 0.04, 1.5], "farbe": "#eeeeee", "tueren": [], "arbeitsplaetze": [],
		"warteplaetze": [], "ausstattung": [], "statusleuchten": []}
	form_pruefung.daten["raeume"] = [test_flur, test_blocker]
	form_pruefung.daten["tueren"] = []
	form_pruefung.raeume = form_pruefung.daten["raeume"]
	pruefe(form_pruefung.platzierung_pruefen(Vector2.ZERO, Vector2(4, 4), -1, true, "L-Form").is_empty(), "Ausgesparte Ecke der L-Form wird bei Kollisionen freigehalten")
	pruefe(not form_pruefung.platzierung_pruefen(Vector2.ZERO, Vector2(4, 4), -1, true, "Rechteck").is_empty(), "Rechteck mit gleichem Aussenmass kollidiert weiterhin")
	var direkter_flur := test_flur.duplicate(true)
	direkter_flur["position"] = [0.0, 0.02, 3.0]
	var verbindungsraum := test_blocker.duplicate(true)
	verbindungsraum["position"] = [0.0, 0.02, 0.5]
	verbindungsraum["groesse"] = [4.0, 0.04, 3.0]
	form_pruefung.daten["raeume"] = [direkter_flur, verbindungsraum]
	form_pruefung.raeume = form_pruefung.daten["raeume"]
	pruefe(not form_pruefung.platzierung_pruefen(Vector2(0, -2.5), Vector2(4, 3)).is_empty(), "Anschluss ueber einen anderen Raum wird ohne direkte Flurkante abgelehnt")
	var polygon_praxis = PRAXIS.instantiate()
	polygon_praxis.layout_daten = polygon_layout.daten
	root.add_child(polygon_praxis)
	await process_frame
	var polygon_knoten = polygon_praxis.get_node("Generated").find_child(String(l_raum["name"]), true, false)
	pruefe(polygon_knoten != null and polygon_knoten.mesh is ArrayMesh, "L-Form wird als echter polygonaler 3D-Boden erzeugt")
	polygon_praxis.queue_free()
	var kapazitaet = LAYOUT.new()
	kapazitaet.aus_json_text(layout.standard_json_text(), "Kapazitaetstest")
	kapazitaet.baumodus_vorbereiten()
	var kapazitaet_warten := kapazitaet._raum_index("Wartezimmer")
	kapazitaet.groesse_setzen(kapazitaet_warten, Vector2(4, 4))
	pruefe(kapazitaet.raeume[kapazitaet_warten]["warteplaetze"].size() == 3, "Verkleinertes Wartezimmer reduziert Plaetze und Stuehle")
	kapazitaet.groesse_setzen(kapazitaet_warten, Vector2(8, 6))
	pruefe(kapazitaet.raeume[kapazitaet_warten]["warteplaetze"].size() == 8, "Vergroessertes Wartezimmer erhoeht Plaetze und Stuehle")
	var verteilte_warteplaetze: Array = kapazitaet.daten["warteplaetze"].filter(func(p): return String(p.get("raum_id", "")) == String(kapazitaet.raeume[kapazitaet_warten]["id"]))
	var alle_stuehle_im_raum := true
	var alle_stuehle_an_waenden := true
	var alle_stuehle_ausgerichtet := true
	var warte_polygon := kapazitaet._raum_polygon(kapazitaet_warten)
	for warteplatz in verteilte_warteplaetze:
		var sitz := Vector2(float(warteplatz["position"][0]), float(warteplatz["position"][1]))
		alle_stuehle_im_raum = alle_stuehle_im_raum and kapazitaet._flaeche_liegt_im_raum(kapazitaet_warten, sitz, 0.38, 0.38)
		var wandabstand := INF
		for kanten_index in warte_polygon.size():
			var wandpunkt := Geometry2D.get_closest_point_to_segment(sitz, warte_polygon[kanten_index], warte_polygon[(kanten_index + 1) % warte_polygon.size()])
			wandabstand = minf(wandabstand, sitz.distance_to(wandpunkt))
		alle_stuehle_an_waenden = alle_stuehle_an_waenden and wandabstand <= 0.56
		alle_stuehle_ausgerichtet = alle_stuehle_ausgerichtet and warteplatz.get("lehnen_richtung", []).size() == 2
	pruefe(alle_stuehle_im_raum and alle_stuehle_an_waenden and alle_stuehle_ausgerichtet, "Wartestuehle bilden ausgerichtete Reihen entlang freier Waende")
	var kapazitaet_schwester := kapazitaet._raum_index("Schwester")
	kapazitaet.groesse_setzen(kapazitaet_schwester, Vector2(4, 5.5))
	pruefe(kapazitaet.raeume[kapazitaet_schwester]["arbeitsplaetze"].size() == 1, "Verkleinerter Behandlungsraum reduziert Arbeitsplaetze")
	var schwester_moebel: Array = kapazitaet.daten["ausstattung"].filter(func(a): return String(a.get("raum_id", "")) == String(kapazitaet.raeume[kapazitaet_schwester]["id"]) and String(a.get("typ", "")) in ["tisch", "stuhl"])
	pruefe(schwester_moebel.size() == 2, "Verkleinerter Schwesternraum entfernt ueberzaehlige Arbeitsplatzmoebel")
	var rezeption_index := kapazitaet._raum_index("Rezeption")
	var rezeption_platz_id: String = kapazitaet.raeume[rezeption_index]["arbeitsplaetze"][0]
	var rezeption_platz: Dictionary = kapazitaet.daten["arbeitsplaetze"].filter(func(a): return String(a["id"]) == rezeption_platz_id)[0]
	var rezeptionsposition := Vector2(float(rezeption_platz["position"][0]), float(rezeption_platz["position"][1]))
	var patientenposition := Vector2(float(rezeption_platz["patienten_position"][0]), float(rezeption_platz["patienten_position"][1]))
	pruefe(kapazitaet._raum_rechteck(rezeption_index).has_point(rezeptionsposition), "Rezeptionskraft steht innerhalb des Rezeptionsraums")
	pruefe(patientenposition.y < rezeptionsposition.y and is_equal_approx(float(rezeption_platz["winkel_grad"]), 180.0), "Rezeptionskraft blickt zur Patientenseite des Tresens")
	pruefe(layout.daten.has_all(["raeume", "tueren", "waende", "arbeitsplaetze", "warteplaetze", "ausstattung"]), "JSON enthaelt alle deklarativen 3D-Bereiche")
	pruefe(layout.anzahl("Arzt") >= 1 and layout.anzahl("Schwester") >= 1 and layout.anzahl("Rezeption") >= 1 and layout.anzahl("Wartezimmer") >= 1, "Konfiguration enthaelt die erforderlichen Raumtypen")
	var ungueltig = LAYOUT.new()
	ungueltig.daten = layout.daten.duplicate(true)
	ungueltig.daten["raeume"].append(ungueltig.daten["raeume"][0].duplicate(true))
	pruefe(not ungueltig.validieren().is_empty(), "Validierung weist doppelte IDs zurueck")
	# Die folgenden Mutationstests verwenden bewusst die unveraenderliche Vorlage,
	# damit ein vom Nutzer gespeicherter Entwurf die Testgeometrie nicht beeinflusst.
	layout = LAYOUT.new()
	layout.aus_json_text(layout.standard_json_text(), "Mutationsstandard")
	layout.baumodus_vorbereiten()
	var freier_platz := Vector2.ZERO
	for raum_index in layout.raeume.size():
		if String(layout.raeume[raum_index]["typ"]) == "Wartezimmer":
			freier_platz = layout.position(raum_index)
			layout.entfernen(raum_index)
			break
	var flur_index := layout._raum_index("Flur")
	freier_platz.y = layout.position(flur_index).y - layout.groesse(flur_index).y / 2.0 - 2.0
	var aerzte_vorher: int = layout.anzahl("Arzt")
	var raum: Dictionary = layout.hinzufuegen("Arzt", freier_platz)
	var index: int = layout.raeume.size() - 1
	var raum_start := layout.position(index)
	pruefe(layout.hat_direkten_fluranschluss(index), "Ein neuer Raum besitzt eine eigene Wandkante zum Flur")
	var neue_waende: Array = layout.daten["waende"].filter(func(w): return w.get("raum_id", "") == raum["id"])
	pruefe(neue_waende.size() == 4 and raum["waende"].size() == 4, "Ein neuer Raum erhaelt automatisch vier Waende")
	var neue_tueren: Array = layout.daten["tueren"].filter(func(t): return t.get("raum_id", "") == raum["id"])
	pruefe(neue_tueren.size() == 1 and raum["tueren"].size() == 1, "Ein neuer Raum erhaelt automatisch eine Tuer")
	var neue_arbeitsplaetze: Array = layout.daten["arbeitsplaetze"].filter(func(a): return a.get("raum_id", "") == raum["id"])
	pruefe(neue_arbeitsplaetze.size() == 1 and neue_arbeitsplaetze[0]["wegpunkte"].size() == 3, "Behandlungsraum erhaelt Arbeitsplatz und Personalzugang")
	var neue_ausstattung: Array = layout.daten["ausstattung"].filter(func(a): return a.get("raum_id", "") == raum["id"] and bool(a.get("automatisch_gebaut", false)))
	pruefe(neue_ausstattung.size() == 3 and neue_ausstattung.any(func(a): return a["typ"] == "tisch") and neue_ausstattung.any(func(a): return a["typ"] == "stuhl") and neue_ausstattung.any(func(a): return a["typ"] == "liege"), "Neues Arztzimmer erhaelt Tisch, Stuhl und Untersuchungsliege")
	pruefe(layout.daten["statusleuchten"].any(func(leuchte): return String(leuchte.get("raum_id", "")) == String(raum["id"])), "Neues Arztzimmer erhaelt eine eigene dynamische Statusleuchte")
	layout.groesse_setzen(index, Vector2(6.24, 3.76))
	pruefe(layout.groesse(index) == Vector2(6.0, 4.0), "Raumgroessen aus dem Baumodus rasten auf 0,5 Meter ein")
	var hintere_wand: Dictionary = layout.daten["waende"].filter(func(w): return w.get("id", "") == raum["id"] + "_wand_hinten")[0]
	var wand_von := Vector2(float(hintere_wand["von"][0]), float(hintere_wand["von"][1]))
	var wand_bis := Vector2(float(hintere_wand["bis"][0]), float(hintere_wand["bis"][1]))
	pruefe(wand_von.is_equal_approx(raum_start + Vector2(-3, -2)) and wand_bis.is_equal_approx(raum_start + Vector2(3, -2)), "Automatische Waende folgen der Raumgroesse")
	pruefe(layout.anzahl("Arzt") == aerzte_vorher + 1, "Raumzahl ist als SimSharp-Kapazitaet ableitbar")
	layout.daten["ausstattung"].append({"id": "test_moebel", "raum_id": raum["id"], "typ": "stuhl", "position": [raum_start.x, 0, raum_start.y]})
	raum["ausstattung"].append("test_moebel")
	layout.verschieben(index, Vector2(-2.24, 3.26))
	pruefe(layout.position(index) == Vector2(-2.0, 3.5), "Raeume lassen sich auf dem Raster verschieben")
	var tuerpunkt := Vector2(float(neue_tueren[0]["position"][0]), float(neue_tueren[0]["position"][1]))
	var raum_mitte := layout.position(index)
	var raum_mass := layout.groesse(index)
	var tuer_auf_rand := is_equal_approx(absf(tuerpunkt.x - raum_mitte.x), raum_mass.x / 2.0) or is_equal_approx(absf(tuerpunkt.y - raum_mitte.y), raum_mass.y / 2.0)
	pruefe(tuer_auf_rand, "Die Tuer folgt Position und Groesse des Raums")
	var waende_mit_tuer: Array = layout.daten["waende"].filter(func(w): return raum["tueren"][0] in w.get("tueren", []))
	pruefe(not waende_mit_tuer.is_empty() and "Flur" in neue_tueren[0]["verbindung"], "Die Tuer oeffnet die Raumwand direkt zum Flur")
	var weg_start: Array = neue_arbeitsplaetze[0]["wegpunkte"][0]
	pruefe(Vector2(float(weg_start[0]), float(weg_start[1])).distance_to(tuerpunkt) > 0.6, "Der Personalweg beginnt ausserhalb des aktualisierten Tuerzugangs")
	var raum_wege = RAUM_WEGE.new()
	raum_wege.konfigurieren(layout.daten)
	var arbeitsposition := Vector2(float(neue_arbeitsplaetze[0]["position"][0]), float(neue_arbeitsplaetze[0]["position"][1]))
	var tuerweg: Array[Vector2] = raum_wege._zum_flur(arbeitsposition)
	var tuer_durchlaufen := false
	for wegpunkt in tuerweg:
		tuer_durchlaufen = tuer_durchlaufen or wegpunkt.distance_to(tuerpunkt) <= 0.05
	pruefe(tuerweg.size() >= 3 and tuer_durchlaufen and raum_wege._raum(tuerweg[-1]) == "Flur", "Patientenweg fuehrt durch alle erforderlichen Tueren bis zum Flur: %s" % str(tuerweg))
	var test_moebel: Dictionary = layout.daten["ausstattung"].filter(func(a): return String(a["id"]) == "test_moebel")[0]
	pruefe(Vector2(test_moebel["position"][0], test_moebel["position"][2]) == Vector2(-2.0, 3.5), "Zugeordnete Ausstattung bewegt sich mit dem Raum")
	layout.entfernen(index)
	pruefe(layout.anzahl("Arzt") == aerzte_vorher and layout.daten["ausstattung"].all(func(e): return e["id"] != "test_moebel"), "Raum und zugeordnete Ausstattung lassen sich entfernen")
	pruefe(layout.daten["waende"].all(func(w): return w.get("raum_id", "") != raum["id"]), "Automatische Waende werden mit dem Raum entfernt")
	pruefe(layout.daten["tueren"].all(func(t): return t.get("raum_id", "") != raum["id"]), "Automatische Tuer wird mit dem Raum entfernt")
	var test_pfad := "user://praxis-layout-test.json"
	pruefe(layout.speichern(test_pfad).is_empty(), "Vollstaendiges Layout wird als JSON gespeichert")
	var erneut = LAYOUT.new()
	var erneut_fehler: String = erneut.laden(test_pfad)
	pruefe(erneut_fehler.is_empty() and erneut.als_json_text() == layout.als_json_text(), "Gespeichertes Layout ist verlustfrei wieder ladbar")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_pfad))
	layout.laden("res://praxis-layout.json")
	var praxis = PRAXIS.instantiate()
	praxis.layout_daten = layout.daten
	root.add_child(praxis)
	await process_frame
	var generated := praxis.get_node("Generated")
	pruefe(generated.get_child_count() > layout.raeume.size(), "3D-Praxis wird vollstaendig aus der JSON-Konfiguration erzeugt")
	if not layout.daten["ausstattung"].is_empty():
		var moebel_namen := {"tisch": "Schreibtisch", "stuhl": "Stuhl_Sitz", "liege": "Liege_Polster"}
		var erster_typ := String(layout.daten["ausstattung"][0]["typ"])
		var erwarteter_name := String(layout.daten["ausstattung"][0].get("name", "")) if erster_typ == "box" else String(moebel_namen.get(erster_typ, ""))
		pruefe(not erwarteter_name.is_empty() and generated.find_child(erwarteter_name, true, false) != null, "Deklaratives Moebel wird erzeugt")
	praxis.queue_free()
	var bau_fenster = BAU_FENSTER.new()
	root.add_child(bau_fenster)
	await process_frame
	pruefe(bau_fenster.vorbereiten(standard.als_json_text(), layout.standard_json_text()).is_empty(), "Baumodusfenster uebernimmt aktive und Standardkonfiguration")
	bau_fenster.raum_auswahl.select(0)
	bau_fenster._raum_gewaehlt(0)
	pruefe(is_equal_approx(bau_fenster.x_feld.value, snappedf(bau_fenster.entwurf.position(0).x, 0.01)) and is_equal_approx(bau_fenster.tiefe_feld.value, snappedf(bau_fenster.entwurf.groesse(0).y, 0.01)), "Meterfelder zeigen keine langen Gleitkomma-Artefakte")
	var formular_breite := maxf(1.0, bau_fenster.entwurf.groesse(0).x - 0.5)
	bau_fenster.breite_feld.value = formular_breite
	pruefe(is_equal_approx(bau_fenster.entwurf.groesse(0).x, formular_breite), "Gueltige Raumbreite wird ueber das Formular geaendert: " + bau_fenster.meldung.text)
	var alte_tiefe: float = bau_fenster.entwurf.groesse(0).y
	var neue_tiefe: float = maxf(1.0, snappedf(alte_tiefe - 0.5, 0.5))
	bau_fenster.tiefe_feld.value = neue_tiefe
	bau_fenster._zahlenwert_bestaetigt()
	pruefe(is_equal_approx(bau_fenster.entwurf.groesse(0).y, neue_tiefe) and bau_fenster.entwurf.hat_direkten_fluranschluss(0), "Enter uebernimmt die neue Raumtiefe und haelt die Tuerkante am Flur")
	var genaue_breite: float = bau_fenster.entwurf.groesse(0).x - 0.13
	bau_fenster.breite_feld.value = genaue_breite
	bau_fenster._zahlenwert_bestaetigt("breite")
	pruefe(is_equal_approx(bau_fenster.entwurf.groesse(0).x, genaue_breite), "Meterfelder uebernehmen genaue Raumgroessen mit zwei Nachkommastellen")
	bau_fenster._metertext_bestaetigt("5,73 m", bau_fenster.breite_feld, "breite")
	pruefe(is_equal_approx(bau_fenster.entwurf.groesse(0).x, 5.73), "Komma-Meterwert wird mit Enter uebernommen")
	bau_fenster._metertext_bestaetigt("5.81", bau_fenster.breite_feld, "breite")
	pruefe(is_equal_approx(bau_fenster.entwurf.groesse(0).x, 5.81), "Punkt-Meterwert wird mit Enter uebernommen")
	pruefe(is_nan(bau_fenster._meterwert_lesen("5,813")), "Mehr als zwei Nachkommastellen werden abgelehnt statt gerundet")
	bau_fenster._layout_zuruecksetzen()
	standard.baumodus_vorbereiten()
	pruefe(bau_fenster.entwurf.daten == standard.daten, "Bestaetigtes Zuruecksetzen stellt das Standardlayout wieder her")
	bau_fenster.queue_free()
	print("PRAXIS-LAYOUT: ", "BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN")
	quit(1 if fehler else 0)
