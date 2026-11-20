# Erlaubt die Verwendung des Laders auch im Godot-Editor.
@tool
extends RefCounted
## Ausgangsdaten der Darstellung. Die Kapazitaeten des SimSharp-Kerns bleiben unveraendert.
## Die statischen Methoden koennen ohne eigene Lader-Instanz aufgerufen werden.
## Dieser Lader liest nur die Godot-Dateien unter res://Konfiguration/.
## Patientenankuenfte und Simulationskapazitaeten werden separat vom C#-Kern geladen:
## simSharpSimulation/simSharpSimulation/Ressourcen/*-konfiguration.json (ab Repository-Wurzel).
## Verbindung und konkrete Einstellungsdateien: README/README_VERBINDUNG.md.

# Laedt das Skript fuer die abschliessende Pruefung des zusammengesetzten Layouts.
const RAUM_LAYOUT = preload("res://Raum3D/RaumLayout.gd")

## Liest eine JSON-Datei relativ zu res://Konfiguration/.
## Liefert bei fehlender Datei, ungueltigem JSON oder unbekannter Version ein leeres Dictionary.
static func lesen(dateiname: String) -> Dictionary:
	# res:// bezeichnet das Stammverzeichnis des Godot-Projekts.
	var pfad := "res://Konfiguration/" + dateiname
	if not FileAccess.file_exists(pfad):
		push_error("Konfiguration fehlt: " + pfad)
		return {}
	# Wandelt den Dateiinhalt in Godot-Daten um; als Wurzel wird ein JSON-Objekt erwartet.
	var json := JSON.new()
	var fehler := json.parse(FileAccess.get_file_as_string(pfad))
	if fehler != OK or not json.data is Dictionary:
		push_error("Ungueltige Konfiguration: " + pfad + ": " + json.get_error_message())
		return {}
	var daten: Dictionary = json.data
	# Nur Schema-Version 1 wird unterstuetzt; ein fehlender Versionswert ergibt 0.
	if int(daten.get("schema_version", 0)) != 1:
		push_error("Unbekannte Konfigurationsversion: " + pfad)
		return {}
	return daten

## Fuegt das Layout-Manifest, Navigation, Tueren, Waende und einzelne Raeume zusammen.
## Gibt das gepruefte Gesamtlayout zurueck oder bei einem erkannten Fehler {}.
## Neue sichtbare Raeume werden in Praxislayout/layout.json und den Raumdateien beschrieben.
## Die simulierte Raumkapazitaet in finanz-konfiguration.json wird hier nicht uebernommen.
static func layout() -> Dictionary:
	var basis := "Praxislayout/"
	# Das Manifest enthaelt Grundeinstellungen und die Dateinamen der Teilkonfigurationen.
	var manifest := lesen(basis + "layout.json")
	if manifest.is_empty():
		return {}
	# Eine tiefe Kopie uebernimmt auch verschachtelte Daten unabhaengig vom Manifest.
	var daten: Dictionary = manifest.duplicate(true)
	var navigation := lesen(basis + String(manifest["navigation"]))
	var tueren := lesen(basis + String(manifest["tueren"]))
	var waende := lesen(basis + String(manifest["waende"]))
	if navigation.is_empty() or tueren.is_empty() or waende.is_empty():
		return {}
	# Navigation wird auf oberster Ebene eingefuegt; gleichnamige Werte werden ersetzt.
	# Bei Tueren und Waenden werden die Dateiverweise durch die geladenen Listen ersetzt.
	daten.merge(navigation, true)
	daten["tueren"] = tueren["tueren"]
	daten["waende"] = waende["waende"]
	# Globale Sammellisten vorbereiten, die anschliessend aus allen Raeumen gefuellt werden.
	daten["raeume"] = []
	for gruppe in ["arbeitsplaetze", "warteplaetze", "ausstattung", "statusleuchten"]:
		daten[gruppe] = []
	# Jede Raumdatei beschreibt einen Raum mit seinen Plaetzen und Ausstattungsobjekten.
	for datei in manifest["raeume"]:
		var raum := lesen(basis + String(datei))
		if raum.is_empty():
			return {}
		# Fehlende optionale Gruppen werden wie leere Listen behandelt.
		for gruppe in ["arbeitsplaetze", "warteplaetze", "ausstattung", "statusleuchten"]:
			var ids: Array[String] = []
			for eintrag in raum.get(gruppe, []):
				# Kopie mit Raum-ID in die globale Liste aufnehmen, damit die Zugehoerigkeit bleibt.
				var platz: Dictionary = eintrag.duplicate(true)
				platz["raum_id"] = raum["id"]
				daten[gruppe].append(platz)
				if gruppe in ["arbeitsplaetze", "warteplaetze"]:
					ids.append(String(platz["id"]))
			# Im Raum selbst verweisen Arbeitsplatz- und Warteplatzlisten danach nur noch
			# ueber IDs auf die vollstaendigen Eintraege in den globalen Sammellisten.
			if gruppe in ["arbeitsplaetze", "warteplaetze"]:
				raum[gruppe] = ids
		daten["raeume"].append(raum)
	# Erst das vollstaendig zusammengesetzte Layout pruefen und alle Prueffehler melden.
	var fehler: PackedStringArray = RAUM_LAYOUT.new(daten).pruefen()
	if not fehler.is_empty():
		push_error("Ungueltiges Praxislayout:\n" + "\n".join(fehler))
		return {}
	return daten

## Wandelt ein JSON-Koordinatenpaar [x, z] in einen Vector2 um.
## Dessen y-Komponente steht bei Grundrisspositionen fuer die z-Achse der 3D-Welt.
static func punkt2(werte: Array) -> Vector2:
	return Vector2(float(werte[0]), float(werte[1]))

## Wandelt drei JSON-Koordinaten [x, y, z] in einen Vector3 um.
## Beide Punkt-Hilfsfunktionen erwarten ausreichend viele numerische Werte.
static func punkt3(werte: Array) -> Vector3:
	return Vector3(float(werte[0]), float(werte[1]), float(werte[2]))

## Liefert die Stationspositionen als Dictionary: Stations-ID -> Vector2 im Grundriss.
static func stationen() -> Dictionary:
	var ergebnis := {}
	# Ohne Stationsdaten bleibt das Ergebnis leer; vorhandene IDs werden beibehalten.
	var daten: Dictionary = layout().get("stationen", {})
	for id in daten:
		ergebnis[id] = punkt2(daten[id])
	return ergebnis

## Liefert nur die Positionen der Warteplaetze in der Reihenfolge des geladenen Layouts.
static func wartepositionen() -> Array[Vector2]:
	var ergebnis: Array[Vector2] = []
	# Aus jedem Warteplatz-Eintrag wird das Koordinatenpaar als Vector2 uebernommen.
	for platz in layout().get("warteplaetze", []):
		ergebnis.append(punkt2(platz["position"]))
	return ergebnis

## Bisherige feste Besetzung fuer den WebSocket-Modus und bestehende Konfigurationspruefungen.
## Offline verwendet PersonalVerwaltung.planen() stattdessen die geladenen Personalzahlen des Kerns.
## Verknuepft Personal, Arbeitsplaetze und Besetzung fuer die sichtbaren Personalfiguren.
## Nur Personen mit einer Zuordnung in besetzung.json werden zurueckgegeben.
## Im WebSocket-Modus personal.json, besetzung.json und die Arbeitsplaetze separat pflegen.
static func personal_plaetze() -> Array[Dictionary]:
	# personal.json beschreibt die Personen: ID, Qualifikationen und sichtbares Modell.
	# Das Dictionary ermoeglicht den direkten Zugriff auf eine Person ueber ihre ID.
	var personen := {}
	for person in lesen("personal.json").get("personal", []):
		if personen.has(person["id"]):
			push_error("Doppelte Personal-ID: " + str(person["id"]))
			return []
		personen[person["id"]] = person
	# Das Praxislayout liefert Position, Blickrichtung und benoetigte Qualifikation
	# jedes Arbeitsplatzes. Auch diese Eintraege werden nach ihrer ID gesammelt.
	var plaetze := {}
	for platz in layout().get("arbeitsplaetze", []):
		if plaetze.has(platz["id"]):
			push_error("Doppelte Arbeitsplatz-ID: " + str(platz["id"]))
			return []
		plaetze[platz["id"]] = platz
	var ergebnis: Array[Dictionary] = []
	# Merkt bereits verwendete IDs: Jede Person und jeder Platz darf nur einmal vorkommen.
	var belegte_personen := {}
	var belegte_plaetze := {}
	# besetzung.json legt fest, welche Person an welchem Arbeitsplatz steht.
	for zuordnung in lesen("besetzung.json").get("zuordnungen", []):
		var person_id := String(zuordnung["personal_id"])
		var platz_id := String(zuordnung["arbeitsplatz_id"])
		# Beide IDs muessen existieren; bei einem Fehler wird keine Besetzung geliefert.
		if not personen.has(person_id) or not plaetze.has(platz_id):
			push_error("Unbekannte Person oder unbekannter Arbeitsplatz: " + person_id + " / " + platz_id)
			return []
		var person: Dictionary = personen[person_id]
		var platz: Dictionary = plaetze[platz_id]
		# Die geforderte Arbeitsplatz-Qualifikation muss in den Qualifikationen der Person
		# enthalten sein. Das sichtbare Modell allein entscheidet nicht ueber die Eignung.
		if belegte_personen.has(person_id) or belegte_plaetze.has(platz_id) or platz["qualifikation"] not in person["qualifikationen"]:
			push_error("Doppelbelegung oder unpassende Qualifikation: " + person_id + " / " + platz_id)
			return []
		belegte_personen[person_id] = true
		belegte_plaetze[platz_id] = true
		# PersonalVerwaltung nutzt diese Daten, um die Figur zu erzeugen und auszurichten.
		# "rolle" waehlt das Modell; die 2D-Position wird dort in die X/Z-Ebene uebertragen.
		# Godot erwartet den Drehwinkel im Bogenmass, die Konfiguration enthaelt Grad.
		ergebnis.append({"personal_id": person_id, "arbeitsplatz_id": platz_id,
			"rolle": String(person["modell"]), "position": punkt2(platz["position"]),
			"winkel": deg_to_rad(float(platz["winkel_grad"]))})
	return ergebnis
