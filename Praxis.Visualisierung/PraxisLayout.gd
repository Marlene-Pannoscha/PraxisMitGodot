extends RefCounted

const DATEI := "user://praxis-layout.json"
const STANDARD_DATEI := "res://praxis-layout.json"
const TYPEN := ["Arzt", "Schwester", "Wartezimmer", "Rezeption"]
var raeume: Array[Dictionary] = []

func laden() -> String:
	var pfad := DATEI if FileAccess.file_exists(DATEI) else STANDARD_DATEI
	var datei := FileAccess.open(pfad, FileAccess.READ)
	if datei == null:
		return "Praxislayout konnte nicht geöffnet werden: " + pfad
	var daten = JSON.parse_string(datei.get_as_text())
	if not daten is Dictionary or not daten.has("raeume"):
		return "Praxislayout ist ungültig: " + pfad
	raeume.clear()
	for raum in daten["raeume"]:
		if raum is Dictionary and String(raum.get("typ", "")) in TYPEN:
			raeume.append(_normalisieren(raum))
	return "" if not raeume.is_empty() else "Praxislayout enthält keine Räume."

func speichern() -> String:
	var datei := FileAccess.open(DATEI, FileAccess.WRITE)
	if datei == null:
		return "Praxislayout kann nicht gespeichert werden: " + DATEI
	datei.store_string(JSON.stringify({"version": 1, "raster": 0.5, "raeume": raeume}, "  "))
	return ""

func hinzufuegen(typ: String, position := Vector2.ZERO) -> Dictionary:
	var nummer := 1
	for raum in raeume:
		if String(raum["typ"]) == typ:
			nummer += 1
	var raum := {"id": typ.to_lower() + str(numero_sicher(nummer)), "typ": typ,
		"x": raster(position.x), "z": raster(position.y), "breite": 4.0, "tiefe": 4.0}
	raeume.append(raum)
	return raum

func entfernen(index: int) -> void:
	if index >= 0 and index < raeume.size():
		raeume.remove_at(index)

func verschieben(index: int, position: Vector2) -> void:
	if index >= 0 and index < raeume.size():
		raeume[index]["x"] = raster(position.x)
		raeume[index]["z"] = raster(position.y)

func anzahl(typ: String) -> int:
	var ergebnis := 0
	for raum in raeume:
		if String(raum["typ"]) == typ:
			ergebnis += 1
	return ergebnis

func flaeche(typ: String) -> float:
	var ergebnis := 0.0
	for raum in raeume:
		if String(raum["typ"]) == typ:
			ergebnis += float(raum["breite"]) * float(raum["tiefe"])
	return ergebnis

func raster(wert: float) -> float:
	return snappedf(wert, 0.5)

func numero_sicher(nummer: int) -> String:
	return "%02d" % nummer

func _normalisieren(raum: Dictionary) -> Dictionary:
	return {"id": String(raum.get("id", "raum" + str(raeume.size() + 1))),
		"typ": String(raum["typ"]), "x": raster(float(raum.get("x", 0))),
		"z": raster(float(raum.get("z", 0))), "breite": maxf(1.0, raster(float(raum.get("breite", 4)))),
		"tiefe": maxf(1.0, raster(float(raum.get("tiefe", 4))))}
