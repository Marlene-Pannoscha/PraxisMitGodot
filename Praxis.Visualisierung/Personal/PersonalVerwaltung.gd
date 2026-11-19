extends RefCounted
## Erzeugt die bisherige stationaere Besetzung. Keine automatische Zuteilung.

const KONFIGURATION = preload("res://Konfiguration/KonfigurationLader.gd")
const PERSONAL = preload("res://Personal/Personal.gd")

static func erstellen(welt: Node3D) -> Array[Node3D]:
	var figuren: Array[Node3D] = []
	for platz in KONFIGURATION.personal_plaetze():
		var figur := Node3D.new()
		figur.set_script(PERSONAL)
		figur.rolle = String(platz["rolle"])
		var punkt: Vector2 = platz["position"]
		figur.position = Vector3(punkt.x, 0.06, punkt.y)
		figur.rotation.y = float(platz["winkel"])
		welt.add_child(figur)
		figuren.append(figur)
	return figuren
