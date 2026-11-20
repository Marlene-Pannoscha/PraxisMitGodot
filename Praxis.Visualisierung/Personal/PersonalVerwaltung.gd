extends RefCounted
## Uebernimmt im Offline-Modus die Personalzahlen und verteilt Figuren auf Layout-Arbeitsplaetze.
## Noch keine gemeinsamen Qualifikationen oder dynamischen Rollenwechsel.

const PERSONAL = preload("res://Personal/Personal.gd")
const ROLLEN: Array[String] = ["Rezeption", "Schwester", "Arzt"]

## Erst den gesamten Plan pruefen, damit bei Platzmangel keine unvollstaendige Besetzung entsteht.
## Die Reihenfolge der passenden Arbeitsplaetze im Layout bestimmt die Zuordnung.
static func planen(anzahlen: Dictionary, arbeitsplaetze: Array) -> Dictionary:
	for rolle in anzahlen:
		if rolle not in ROLLEN:
			return {"fehler": "Unbekannte Personalrolle: " + str(rolle), "plaetze": []}
	var ids := {}
	for platz in arbeitsplaetze:
		var id := String(platz.get("id", ""))
		if id.is_empty() or ids.has(id):
			return {"fehler": "Fehlende oder doppelte Arbeitsplatz-ID: " + id, "plaetze": []}
		ids[id] = true
	var ergebnis: Array[Dictionary] = []
	for rolle in ROLLEN:
		if not anzahlen.has(rolle) or typeof(anzahlen[rolle]) != TYPE_INT or int(anzahlen[rolle]) < 0:
			return {"fehler": "Fehlende oder ungueltige Personalzahl: " + rolle, "plaetze": []}
		var anzahl := int(anzahlen[rolle])
		var passende: Array[Dictionary] = []
		for platz in arbeitsplaetze:
			if platz.get("qualifikation", "") == rolle:
				passende.append(platz)
		if anzahl > passende.size():
			return {"fehler": "%s: %d Personen aus der Simulation, aber nur %d passende Arbeitsplaetze im Godot-Layout. Bitte die Raumdateien erweitern." % [rolle, anzahl, passende.size()], "plaetze": []}
		for index in anzahl:
			var platz: Dictionary = passende[index]
			var position: Array = platz["position"]
			ergebnis.append({
				"personal_id": "%s_%d" % [rolle.to_snake_case(), index + 1],
				"arbeitsplatz_id": String(platz["id"]), "rolle": rolle,
				"position": Vector2(float(position[0]), float(position[1])),
				"winkel": deg_to_rad(float(platz["winkel_grad"]))})
	return {"fehler": "", "plaetze": ergebnis}

## Figuren erst nach erfolgreicher Planung erstellen. Standorte kommen ausschliesslich aus dem Layout.
static func erstellen(welt: Node3D, plaetze: Array) -> Array[Node3D]:
	var figuren: Array[Node3D] = []
	for platz in plaetze:
		var figur := Node3D.new()
		figur.set_script(PERSONAL)
		figur.personal_id = String(platz["personal_id"])
		figur.arbeitsplatz_id = String(platz["arbeitsplatz_id"])
		figur.name = "Personal_" + figur.personal_id
		figur.rolle = String(platz["rolle"])
		var punkt: Vector2 = platz["position"]
		figur.position = Vector3(punkt.x, 0.06, punkt.y)
		figur.rotation.y = float(platz["winkel"])
		welt.add_child(figur)
		figuren.append(figur)
	return figuren
