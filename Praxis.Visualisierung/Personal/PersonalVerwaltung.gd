extends RefCounted
## Uebernimmt im Offline-Modus die Personalzahlen und verteilt Figuren auf Layout-Arbeitsplaetze.
## Einsatzrollen gelten fuer einen ganzen Lauf. Keine automatischen Rollenwechsel.
## Ablauf: Personenliste erstellen -> Qualifikationen pruefen -> Arbeitsplaetze planen.
## Nur die daraus berechneten Einsatz-Anzahlen werden spaeter an den Kern uebergeben.

const PERSONAL = preload("res://Personal/Personal.gd")
const ROLLEN: Array[String] = ["Rezeption", "Schwester", "Arzt"]

## Alte Eintraege ohne Stamm-/Einsatzrolle bleiben lesbar.
## Ohne neue Felder gelten die erste Qualifikation als Stammrolle und diese als Einsatzrolle.
static func person_normalisieren(person: Dictionary) -> Dictionary:
	var qualifikationen = person.get("qualifikationen", [])
	var stammrolle := String(person.get("stammrolle", qualifikationen[0] if qualifikationen is Array and not qualifikationen.is_empty() else ""))
	return {"id": String(person.get("id", "")), "qualifikationen": qualifikationen,
		"stammrolle": stammrolle, "einsatzrolle": String(person.get("einsatzrolle", stammrolle)),
		"modell": String(person.get("modell", stammrolle))}

## Prueft die gesamte Personenliste vor der Planung; ein leerer Text bedeutet Erfolg.
## Eine gueltige Stammrolle allein erlaubt keinen Einsatz ohne passende Qualifikation.
static func personen_pruefen(personen: Array) -> String:
	var ids := {}
	for eintrag in personen:
		if not eintrag is Dictionary:
			return "Ungueltiger Personaleintrag."
		var person := person_normalisieren(eintrag)
		var id := String(person["id"])
		if id.is_empty() or ids.has(id):
			return "Fehlende oder doppelte Personal-ID: " + id
		ids[id] = true
		if not person["qualifikationen"] is Array or person["qualifikationen"].is_empty():
			return "Qualifikationen fehlen: " + id
		for rolle in person["qualifikationen"]:
			if rolle not in ROLLEN:
				return "Unbekannte Qualifikation: " + id + " / " + str(rolle)
		if person["stammrolle"] not in person["qualifikationen"] or person["einsatzrolle"] not in person["qualifikationen"]:
			return "Stamm- und Einsatzrolle brauchen eine passende Qualifikation: " + id
		if person["modell"] not in ROLLEN:
			return "Unbekanntes Personalmodell: " + id
	return ""

## Jede Person zaehlt genau einmal: nach Einsatzrolle fuer den Kern oder nach Stammrolle
## fuer die Zahlenfelder. Zwei Qualifikationen ergeben niemals zwei Arbeitskraefte.
static func personen_zahlen(personen: Array, feld := "einsatzrolle") -> Dictionary:
	var zahlen := {"Rezeption": 0, "Schwester": 0, "Arzt": 0}
	for person in personen:
		var rolle := String(person.get(feld, ""))
		if zahlen.has(rolle):
			zahlen[rolle] += 1
	return zahlen

## Die Zahlenfelder verwalten Personen nach Stammrolle, unabhaengig vom Einsatz.
## Vorhandene IDs und Rollen bleiben erhalten. Die Anzahl bestimmt, wie viele Vorlagen
## tatsaechlich eingestellt sind; eine Vorlage allein stellt keine weitere Person ein.
static func personen_erstellen(anzahlen: Dictionary, vorlagen: Array, bisher: Array = []) -> Dictionary:
	var fehler := personen_pruefen(vorlagen)
	if fehler.is_empty():
		fehler = personen_pruefen(bisher)
	if not fehler.is_empty():
		return {"fehler": fehler, "personen": []}
	if anzahlen.size() != ROLLEN.size():
		return {"fehler": "Bitte genau die drei Personalrollen angeben.", "personen": []}
	var personen: Array = []
	var ids := {}
	for rolle in ROLLEN:
		if not anzahlen.has(rolle) or typeof(anzahlen[rolle]) != TYPE_INT or int(anzahlen[rolle]) < 1:
			return {"fehler": "Mindestens eine Person je Stammrolle einstellen: " + rolle, "personen": []}
		var kandidaten: Array = []
		var bekannt := {}
		# Aktive Einstellungen haben Vorrang vor den Startwerten aus personal.json.
		# So setzt eine Aenderung der Personenzahl bestehende Einsatzrollen nicht zurueck.
		for eintrag in bisher + vorlagen:
			var person := person_normalisieren(eintrag)
			if person["stammrolle"] == rolle and not bekannt.has(person["id"]):
				kandidaten.append(person)
				bekannt[person["id"]] = true
		for index in int(anzahlen[rolle]):
			var person: Dictionary
			if index < kandidaten.size():
				person = kandidaten[index].duplicate(true)
			else:
				# Zusatzpersonal entsteht erst durch die gewaehlte Anzahl im Fenster.
				# Freie IDs werden gesucht; eine feste zweite Schwester gibt es hier nicht.
				var nummer := 1
				var id := "%s_%d" % [rolle.to_snake_case(), nummer]
				while ids.has(id) or bekannt.has(id) or vorlagen.any(func(p): return String(p["id"]) == id) or bisher.any(func(p): return String(p["id"]) == id):
					nummer += 1
					id = "%s_%d" % [rolle.to_snake_case(), nummer]
				person = _person_neu(id, rolle, kandidaten)
			if ids.has(person["id"]):
				return {"fehler": "Doppelte Personal-ID: " + String(person["id"]), "personen": []}
			ids[person["id"]] = true
			personen.append(person)
	return {"fehler": "", "personen": personen}

## Wandelt besetzte Arbeitsplaetze wieder in Personen um, etwa zum Oeffnen des Fensters
## oder zum Speichern im Layout. Positionen und Kernnummern werden getrennt neu geplant.
static func personen_aus_plan(plaetze: Array) -> Array:
	var personen: Array = []
	for platz in plaetze:
		var rolle := String(platz["rolle"])
		personen.append({"id": String(platz["personal_id"]), "stammrolle": String(platz.get("stammrolle", rolle)),
			"einsatzrolle": rolle, "qualifikationen": platz.get("qualifikationen", [rolle]).duplicate(),
			"modell": String(platz.get("modell", rolle))})
	return personen

## Kern-IDs werden je Einsatzrolle neu nummeriert; die Person-ID bleibt stabil.
## Beispiel: schwester_2 arbeitet als rezeption_2; schwester_3 kann dann als zweite
## Schwester des Kerns arbeiten. Die Zuordnung verhindert falsche Patientenwege.
static func personen_planen(personen: Array, arbeitsplaetze: Array, zuordnungen: Dictionary = {}) -> Dictionary:
	var fehler := personen_pruefen(personen)
	if not fehler.is_empty():
		return {"fehler": fehler, "plaetze": []}
	var normalisiert: Array = []
	for person in personen:
		normalisiert.append(person_normalisieren(person))
	var zahlen := personen_zahlen(normalisiert)
	# Die vorhandene Offline-Schnittstelle verlangt mindestens eine Person je Einsatzrolle.
	# Die einzige Schwester darf deshalb erst nach Einstellung einer weiteren wechseln.
	for rolle in ROLLEN:
		if zahlen[rolle] < 1:
			return {"fehler": "Mindestens eine Person muss als %s eingesetzt bleiben. Bitte weiteres Personal einstellen oder die Einsatzrolle aendern." % rolle, "plaetze": []}
	var kern_zuordnungen := {}
	var nach_kern := {}
	for rolle in ROLLEN:
		var nummer := 0
		for person in normalisiert:
			if person["einsatzrolle"] != rolle:
				continue
			nummer += 1
			var kern_id := "%s_%d" % [rolle.to_snake_case(), nummer]
			nach_kern[kern_id] = person
			if zuordnungen.has(person["id"]):
				kern_zuordnungen[kern_id] = zuordnungen[person["id"]]
	var plan := planen(zahlen, arbeitsplaetze, kern_zuordnungen)
	if not String(plan["fehler"]).is_empty():
		return plan
	for platz in plan["plaetze"]:
		# Erst den technischen Platzplan erstellen, dann die stabile Person mit ihrem
		# Aussehen und ihren Qualifikationen zuordnen. Die Einsatzrolle bleibt im Feld rolle.
		var kern_id := String(platz["personal_id"])
		var person: Dictionary = nach_kern[kern_id]
		platz["kern_id"] = kern_id
		platz["personal_id"] = person["id"]
		platz["stammrolle"] = person["stammrolle"]
		platz["qualifikationen"] = person["qualifikationen"].duplicate()
		platz["modell"] = person["modell"]
	plan["anzahlen"] = zahlen
	plan["personen"] = normalisiert
	return plan

## Bei einem Rollenwechsel nur den bisherigen, nun unpassenden Arbeitsplatz freigeben.
static func zuordnungen_behalten(personen: Array, plaetze: Array) -> Dictionary:
	var zuordnungen := {}
	for person in personen:
		for platz in plaetze:
			if person["id"] == platz["personal_id"] and person["einsatzrolle"] == platz["rolle"]:
				zuordnungen[person["id"]] = platz["arbeitsplatz_id"]
	return zuordnungen

## Erst den gesamten Plan pruefen, damit bei Platzmangel keine unvollstaendige Besetzung entsteht.
## Explizite Zuordnungen bleiben erhalten; weitere Personen erhalten freie passende Plaetze.
static func planen(anzahlen: Dictionary, arbeitsplaetze: Array, zuordnungen: Dictionary = {}) -> Dictionary:
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
	return {"fehler": "", "plaetze": ergebnis}

## Speichert die Verbindung der stabilen Personal-ID zum konkreten Arbeitsplatz.
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
	var plan: Dictionary
	if konfiguration.has("personen"):
		# Neue Layouts enthalten die Personen selbst, damit ein manueller Einsatz
		# nach dem Laden erhalten bleibt. Die mitgespeicherten Summen muessen dazu passen.
		if not konfiguration["personen"] is Array:
			return {"fehler": "Ungueltige gespeicherte Personenliste.", "plaetze": []}
		plan = personen_planen(konfiguration["personen"], arbeitsplaetze, konfiguration["zuordnungen"])
		if String(plan["fehler"]).is_empty() and plan["anzahlen"] != zahlen:
			return {"fehler": "Gespeicherte Personalzahlen passen nicht zu den Einsatzrollen.", "plaetze": []}
	else:
		# Aeltere Layouts enthalten nur Zahlen und Zuordnungen und bleiben weiter lesbar.
		plan = planen(zahlen, arbeitsplaetze, konfiguration["zuordnungen"])
	plan["anzahlen"] = zahlen
	return plan

## Ein neuer Arzt-/Schwesternraum erhaelt genau eine weitere Person in diesem Raum.
## Bestehende Besetzungen bleiben erhalten. Entfernte Raeume nehmen ihre Personen mit.
## Das Ergebnis ist ein Entwurf; erst der Aufrufer speichert und startet den Kern neu.
static func baumodus_planen(bisher: Dictionary, entwurf: Dictionary, aktive_plaetze: Array, vorlagen: Array = []) -> Dictionary:
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
	var personen: Array = []
	var zuordnungen := {}
	# Identitaet, Qualifikationen und manuell eingestellte Einsatzrolle erhalten.
	for platz in aktive_plaetze:
		var rolle := String(platz["rolle"])
		var id := String(platz["arbeitsplatz_id"])
		var raum_id := String(alte_plaetze.get(id, {}).get("raum_id", ""))
		if rolle in ["Arzt", "Schwester"] and not neue_raeume.has(raum_id):
			continue
		var person: Dictionary = personen_aus_plan([platz])[0]
		personen.append(person)
		if neue_plaetze.has(id) and String(neue_plaetze[id].get("raum_id", "")) == raum_id:
			zuordnungen[person["id"]] = id
	for raum in entwurf["raeume"]:
		var rolle := String(raum["typ"])
		if rolle not in ["Arzt", "Schwester"] or alte_raeume.has(String(raum["id"])):
			continue
		var passende: Array = entwurf["arbeitsplaetze"].filter(func(p): return String(p.get("raum_id", "")) == String(raum["id"]) and String(p.get("qualifikation", "")) == rolle)
		if passende.is_empty():
			return {"fehler": "Neuer Raum braucht einen passenden Arbeitsplatz: " + String(raum["id"]), "plaetze": []}
		var person := _weitere_person(rolle, personen, aktive_plaetze, vorlagen)
		# Die bestehende Baumodus-Regel ergaenzt je neuem Arzt-/Schwesternraum eine
		# Person genau in diesem Raum. Das ist unabhaengig von manuellen Einsatzwechseln.
		personen.append(person)
		zuordnungen[person["id"]] = String(passende[0]["id"])
	for rolle in ROLLEN:
		if personen_zahlen(personen)[rolle] == 0:
			# Die bisherige Mindestbesetzung beim Entfernen von Raeumen bleibt bestehen;
			# die anschliessende Planung prueft, ob dafuer noch ein Arbeitsplatz vorhanden ist.
			personen.append(_weitere_person(rolle, personen, aktive_plaetze, vorlagen))
	var plan := personen_planen(personen, entwurf["arbeitsplaetze"], zuordnungen)
	if String(plan["fehler"]).is_empty():
		# Nur ein Entwurf: Vorschau und Abbrechen veraendern den aktiven Lauf nicht.
		# Main.gd speichert dies erst beim Uebernehmen unter offline_personal in praxis-layout.json.
		# Beim Neustart setzt die Offline-Anbindung die Zahlen ueber die vorhandene SimSharp-Schnittstelle.
		plan["konfiguration"] = {"anzahlen": plan["anzahlen"], "personen": personen_aus_plan(plan["plaetze"]),
			"zuordnungen": zuordnungen_aus_plan(plan["plaetze"])}
	return plan

## Erzeugt fuer den Bauentwurf eine freie ID ohne die Identitaet einer alten Person zu kopieren.
static func _weitere_person(rolle: String, personen: Array, alte_plaetze: Array, vorlagen: Array = []) -> Dictionary:
	var nummer := 1
	var id := "%s_%d" % [rolle.to_snake_case(), nummer]
	while personen.any(func(p): return String(p["id"]) == id) or alte_plaetze.any(func(p): return String(p["personal_id"]) == id):
		nummer += 1
		id = "%s_%d" % [rolle.to_snake_case(), nummer]
	return _person_neu(id, rolle, personen + vorlagen)

## Zusatzpersonal uebernimmt Qualifikationen und Modell der letzten Vorlage seiner
## Stammrolle. So bleiben die erste Schwester fest und ab der zweiten beide Einsaetze
## moeglich, ohne eine feste Personalanzahl im Code. Neue IDs starten in ihrer Stammrolle.
static func _person_neu(id: String, rolle: String, vorlagen: Array) -> Dictionary:
	var qualifikationen: Array = [rolle]
	var modell := rolle
	for eintrag in vorlagen:
		var vorlage := person_normalisieren(eintrag)
		if vorlage["stammrolle"] == rolle:
			qualifikationen = vorlage["qualifikationen"].duplicate()
			modell = String(vorlage["modell"])
	return {"id": id, "qualifikationen": qualifikationen, "stammrolle": rolle, "einsatzrolle": rolle, "modell": modell}

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
		# Aufgabe und Aussehen getrennt setzen, bevor _ready() durch add_child() startet.
		figur.rolle = String(platz["rolle"])
		figur.modell = String(platz.get("modell", platz["rolle"]))
		var punkt: Vector2 = platz["position"]
		figur.position = Vector3(punkt.x, 0.06, punkt.y)
		figur.rotation.y = float(platz["winkel"])
		figur.wegpunkte = platz.get("wegpunkte", [])
		welt.add_child(figur)
		figuren.append(figur)
	return figuren
