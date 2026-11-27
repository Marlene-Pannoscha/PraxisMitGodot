extends SceneTree

const LAYOUT = preload("res://PraxisLayout.gd")
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

func _enthaelt_punkt(weg: Array[Vector2], punkt: Vector2) -> bool:
	return weg.any(func(wegpunkt): return wegpunkt.distance_to(punkt) <= 0.02)

func _raum_punkt(wege, raum: Dictionary) -> Vector2:
	var mitte := Vector2(float(raum["position"][0]), float(raum["position"][2]))
	if Geometry2D.is_point_in_polygon(mitte, wege._polygon(raum)):
		return mitte
	var polygon = wege._polygon(raum)
	for punkt in polygon:
		var kandidat: Vector2 = punkt.lerp(mitte, 0.2)
		if Geometry2D.is_point_in_polygon(kandidat, polygon):
			return kandidat
	return mitte

func testen() -> void:
	var layout = LAYOUT.new()
	var ladefehler: String = layout.laden("res://praxis-layout.json")
	pruefe(ladefehler.is_empty(), "Aktuelles Praxislayout geladen")
	var wege = RAUM_WEGE.new()
	wege.konfigurieren(layout.daten)
	var flur_id := ""
	for raum in layout.daten["raeume"]:
		if String(raum.get("typ", "")) == "Flur":
			flur_id = String(raum["id"])
	pruefe(not flur_id.is_empty(), "Flur fuer die Patientenwege vorhanden")

	var raumpunkte := {}
	for raum in layout.daten["raeume"]:
		raumpunkte[String(raum["id"])] = _raum_punkt(wege, raum)
	var flurpunkt: Vector2 = raumpunkte[flur_id]
	for raum in layout.daten["raeume"]:
		var raum_id := String(raum["id"])
		if raum_id == flur_id:
			continue
		var weg: Array[Vector2] = wege._wegpunkte(raumpunkte[raum_id], flurpunkt)
		var passende_tueren: Array = layout.daten["tueren"].filter(func(t): return raum_id in t.get("verbindung", []) and flur_id in t.get("verbindung", []))
		var durch_tuer := passende_tueren.any(func(t): return _enthaelt_punkt(weg, Vector2(float(t["position"][0]), float(t["position"][1]))))
		pruefe(not passende_tueren.is_empty() and durch_tuer, "%s erreicht den Flur durch seine konfigurierte Tür" % raum_id)

	# Jede Kombination der fachlichen Raeume nutzt beim Verlassen und Betreten
	# beide zugehoerigen Tueren. Damit sind alle moeglichen Patientenwechsel abgedeckt.
	var raum_ids: Array = raumpunkte.keys().filter(func(id): return id != flur_id)
	for start_id in raum_ids:
		for ziel_id in raum_ids:
			if start_id == ziel_id:
				continue
			var weg: Array[Vector2] = wege._wegpunkte(raumpunkte[start_id], raumpunkte[ziel_id])
			for raum_id in [start_id, ziel_id]:
				var tueren: Array = layout.daten["tueren"].filter(func(t): return raum_id in t.get("verbindung", []) and flur_id in t.get("verbindung", []))
				pruefe(tueren.any(func(t): return _enthaelt_punkt(weg, Vector2(float(t["position"][0]), float(t["position"][1])))), "%s → %s passiert die Tür von %s" % [start_id, ziel_id, raum_id])

	var aussentuer: Dictionary = wege._aussentuer()
	pruefe(not aussentuer.is_empty(), "Konfigurierter Ein-/Ausgang vorhanden")
	if not aussentuer.is_empty():
		var aussen := Vector2(float(aussentuer["position"][0]), float(aussentuer["position"][1]) + 1.5)
		var tuerpunkt := Vector2(float(aussentuer["position"][0]), float(aussentuer["position"][1]))
		for ziel_id in raum_ids:
			var hinweg: Array[Vector2] = wege._wegpunkte(aussen, raumpunkte[ziel_id])
			var rueckweg: Array[Vector2] = wege._wegpunkte(raumpunkte[ziel_id], aussen)
			pruefe(_enthaelt_punkt(hinweg, tuerpunkt) and _enthaelt_punkt(rueckweg, tuerpunkt), "Ein- und Ausgangsweg zu %s passiert die Außentür" % ziel_id)

	print("PATIENTENWEGE-TUEREN: ", "BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN")
	quit(1 if fehler else 0)
