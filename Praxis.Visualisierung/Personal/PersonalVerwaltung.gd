extends RefCounted
## Uebernimmt im Offline-Modus die Personalzahlen und verteilt Figuren auf Layout-Arbeitsplaetze.
## Rollenwechsel und Belegung entscheidet der Kern; Godot erzeugt jede Person nur einmal.

const PERSONAL = preload("res://Personal/Personal.gd")
const ROLLEN: Array[String] = ["Rezeption", "Schwester", "Arzt"]

## Erst den gesamten Plan pruefen, damit bei Platzmangel keine unvollstaendige Besetzung entsteht.
## Explizite Zuordnungen bleiben erhalten; weitere Personen erhalten freie passende Plaetze.
static func planen(anzahlen: Dictionary, arbeitsplaetze: Array, zuordnungen: Dictionary = {}, rollenwechsel: Dictionary = {}) -> Dictionary:
	for rolle in anzahlen:
		if rolle not in ROLLEN:
			return {"fehler": "Unbekannte Personalrolle: " + str(rolle), "plaetze": []}
	var ids := {}
	for platz in arbeitsplaetze:
		var id := String(platz.get("id", ""))
		if id.is_empty() or ids.has(id):
			return {"fehler": "Fehlende oder doppelte Arbeitsplatz-ID: " + id, "plaetze": []}
		ids[id] = platz
	# Feste Zuordnungen zuerst reservieren, damit keine andere Person den Platz belegt.
	var reserviert := {}
	for rolle in ROLLEN:
		if not anzahlen.has(rolle) or typeof(anzahlen[rolle]) != TYPE_INT or int(anzahlen[rolle]) < 0:
			return {"fehler": "Fehlende oder ungueltige Personalzahl: " + rolle, "plaetze": []}
		for index in int(anzahlen[rolle]):
			var personal_id := "%s_%d" % [rolle.to_snake_case(), index + 1]
			if not zuordnungen.has(personal_id):
				continue
			var platz_id := String(zuordnungen[personal_id])
			if not ids.has(platz_id) or ids[platz_id].get("qualifikation", "") != rolle or reserviert.has(platz_id):
				return {"fehler": "Ungueltige oder doppelte Personalzuordnung: " + personal_id + " / " + platz_id, "plaetze": []}
			reserviert[platz_id] = true
	var ergebnis: Array[Dictionary] = []
	for rolle in ROLLEN:
		var anzahl := int(anzahlen[rolle])
		var passende: Array[Dictionary] = []
		for platz in arbeitsplaetze:
			if platz.get("qualifikation", "") == rolle:
				passende.append(platz)
		if anzahl > passende.size():
			return {"fehler": "%s: %d Personen aus der Simulation, aber nur %d passende Arbeitsplaetze im Godot-Layout. Bitte die Raumdateien erweitern." % [rolle, anzahl, passende.size()], "plaetze": []}
		var freie: Array[Dictionary] = []
		for platz in passende:
			if not reserviert.has(String(platz["id"])):
				freie.append(platz)
		for index in anzahl:
			var personal_id := "%s_%d" % [rolle.to_snake_case(), index + 1]
			# Eine zugeordnete Person bleibt an ihrem Platz; nur weitere Personen erhalten freie Plaetze.
			var platz: Dictionary = ids[String(zuordnungen[personal_id])] if zuordnungen.has(personal_id) else freie.pop_front()
			var position: Array = platz["position"]
			ergebnis.append({
				"personal_id": personal_id,
				"arbeitsplatz_id": String(platz["id"]), "rolle": rolle,
				"raum_id": String(platz.get("raum_id", "")),
				"position": Vector2(float(position[0]), float(position[1])),
				"winkel": deg_to_rad(float(platz["winkel_grad"])),
				"wegpunkte": platz.get("wegpunkte", []).duplicate(true)})
	if bool(rollenwechsel.get("aktiv", false)):
		var flexibel := int(rollenwechsel.get("schwesterId", 2))
		if int(anzahlen["Schwester"]) < 2 or flexibel < 1 or flexibel > int(anzahlen["Schwester"]):
			return {"fehler": "Für den Rollenwechsel werden mindestens zwei Schwestern benötigt.", "plaetze": []}
		var empfangsplatz := "rezeption_%d" % (int(anzahlen["Rezeption"]) + 1)
		var frei := false
		for platz in arbeitsplaetze:
			if String(platz["id"]) == empfangsplatz and platz.get("qualifikation", "") == "Rezeption":
				frei = true
		if not frei:
			return {"fehler": "Für die flexible Schwester fehlt ein zusätzlicher Rezeptionsplatz: " + empfangsplatz, "plaetze": []}
		for person in ergebnis:
			if person["personal_id"] == "schwester_%d" % flexibel:
				person["qualifikationen"] = ["Schwester", "Rezeption"]
	return {"fehler": "", "plaetze": ergebnis}

static func zuordnungen_aus_plan(plaetze: Array) -> Dictionary:
	var ergebnis := {}
	for platz in plaetze:
		ergebnis[String(platz["personal_id"])] = String(platz["arbeitsplatz_id"])
	return ergebnis

## JSON liest Zahlen als float; nur ganze positive Werte in Kern-Anzahlen umwandeln.
static func konfiguration_planen(konfiguration: Dictionary, arbeitsplaetze: Array) -> Dictionary:
	var zahlen := {}
	if not konfiguration.get("anzahlen") is Dictionary or not konfiguration.get("zuordnungen") is Dictionary:
		return {"fehler": "Offline-Personal braucht Anzahlen und Arbeitsplatzzuordnungen.", "plaetze": []}
	for rolle in konfiguration["anzahlen"]:
		var wert = konfiguration["anzahlen"][rolle]
		if typeof(wert) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(wert)) or float(wert) != floor(float(wert)) or float(wert) < 1 or float(wert) > 2147483647:
			return {"fehler": "Ungueltige gespeicherte Personalzahl: " + str(rolle), "plaetze": []}
		zahlen[rolle] = int(wert)
	# Beim Neustart stammt diese Zuordnung aus offline_personal im Layout; besetzung.json ist offline nicht erforderlich.
	var plan := planen(zahlen, arbeitsplaetze, konfiguration["zuordnungen"])
	plan["anzahlen"] = zahlen
	return plan

## Ein neuer Arzt-/Schwesternraum erhaelt genau eine weitere Person in diesem Raum.
## Bestehende Besetzungen bleiben erhalten. Entfernte Raeume nehmen ihre Personen mit.
## Das Ergebnis ist ein Entwurf; erst der Aufrufer speichert und startet den Kern neu.
static func baumodus_planen(bisher: Dictionary, entwurf: Dictionary, aktive_plaetze: Array) -> Dictionary:
	# PraxisLayout.gd hat Raeume, Arbeitsplaetze und Ausstattung bereits erzeugt.
	# Der Vergleich zeigt, welche Raeume hinzugekommen oder entfernt worden sind.
	var alte_raeume := {}
	var neue_raeume := {}
	var alte_plaetze := {}
	var neue_plaetze := {}
	for raum in bisher["raeume"]:
		alte_raeume[String(raum["id"])] = raum
	for raum in entwurf["raeume"]:
		neue_raeume[String(raum["id"])] = raum
	for platz in bisher["arbeitsplaetze"]:
		alte_plaetze[String(platz["id"])] = platz
	for platz in entwurf["arbeitsplaetze"]:
		neue_plaetze[String(platz["id"])] = platz
	var zahlen := {}
	var zuordnungen := {}
	for rolle in ROLLEN:
		var weiter: Array[String] = []
		for person in aktive_plaetze:
			if String(person["rolle"]) != rolle:
				continue
			var id := String(person["arbeitsplatz_id"])
			var raum_id := String(alte_plaetze.get(id, {}).get("raum_id", ""))
			# Die Rezeption wird durch diese Automatik nicht aufgestockt oder reduziert.
			if rolle in ["Arzt", "Schwester"] and not neue_raeume.has(raum_id):
				# Mit einem entfernten Behandlungsraum entfaellt auch dessen zugeordnetes Personal.
				continue
			var bleibt := neue_plaetze.has(id) and String(neue_plaetze[id].get("raum_id", "")) == raum_id
			# Bestehende Zuordnung behalten; ein entfallener Platz im erhaltenen Raum wird neu verteilt.
			weiter.append(id if bleibt else "")
		if rolle in ["Arzt", "Schwester"]:
			for raum in entwurf["raeume"]:
				# Nur neue Arzt-/Schwesternraeume erhalten Personal; Vergroessern allein erhoeht die Zahl nicht.
				if String(raum["typ"]) != rolle or alte_raeume.has(String(raum["id"])):
					continue
				# Gezielt einen Arbeitsplatz IN DIESEM neuen Raum suchen, auch wenn im alten Raum noch Platz ist.
				var passende: Array = entwurf["arbeitsplaetze"].filter(func(p): return String(p.get("raum_id", "")) == String(raum["id"]) and String(p.get("qualifikation", "")) == rolle)
				if passende.is_empty():
					return {"fehler": "Neuer Raum braucht einen passenden Arbeitsplatz: " + String(raum["id"]), "plaetze": []}
				# Genau eine weitere Person fuer diesen Raum: eine bisherige Schwester + ein neuer Raum ergibt zwei.
				weiter.append(String(passende[0]["id"]))
		# Der Offline-Kern braucht mindestens eine Person je Rolle.
		zahlen[rolle] = maxi(1, weiter.size())
		for index in weiter.size():
			if not weiter[index].is_empty():
				# Person-ID und Arbeitsplatz-ID sind verschieden; diese Zuordnung verbindet sie eindeutig.
				zuordnungen["%s_%d" % [rolle.to_snake_case(), index + 1]] = weiter[index]
	var plan := planen(zahlen, entwurf["arbeitsplaetze"], zuordnungen)
	if String(plan["fehler"]).is_empty():
		# Nur ein Entwurf: Vorschau und Abbrechen veraendern den aktiven Lauf nicht.
		# Main.gd speichert dies erst beim Uebernehmen unter offline_personal in praxis-layout.json.
		# Beim Neustart setzt die Offline-Anbindung die Zahlen ueber die vorhandene SimSharp-Schnittstelle.
		plan["konfiguration"] = {"anzahlen": zahlen, "zuordnungen": zuordnungen_aus_plan(plan["plaetze"])}
	return plan

## Figuren erst nach erfolgreicher Planung erstellen. Standorte kommen ausschliesslich aus dem Layout.
static func erstellen(welt: Node3D, plaetze: Array) -> Array[Node3D]:
	var figuren: Array[Node3D] = []
	for platz in plaetze:
		var figur := Node3D.new()
		figur.set_script(PERSONAL)
		figur.personal_id = String(platz["personal_id"])
		# Dieselbe Arbeitsplatzzuordnung verwendet die Patienten-Timeline fuer die Wege zur Person.
		figur.arbeitsplatz_id = String(platz["arbeitsplatz_id"])
		figur.name = "Personal_" + figur.personal_id
		figur.rolle = String(platz["rolle"])
		figur.qualifikationen.assign(platz.get("qualifikationen", [figur.rolle]))
		var punkt: Vector2 = platz["position"]
		figur.position = Vector3(punkt.x, 0.06, punkt.y)
		figur.rotation.y = float(platz["winkel"])
		figur.wegpunkte = platz.get("wegpunkte", [])
		welt.add_child(figur)
		figuren.append(figur)
	return figuren
