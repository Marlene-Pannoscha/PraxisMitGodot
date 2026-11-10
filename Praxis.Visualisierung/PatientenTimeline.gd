extends RefCounted
## Räumliche Auswertung der Originalereignisse. Keine Behandlungs-/Queue-Logik.

# Vector2 steht hier für die X-/Z-Ebene der Praxis in Metern.
const STATIONEN := {
	"Eingang": Vector2(-6.25, 8), "Rezeption": Vector2(-6.5, 2.05),
	"RezeptionWarten": Vector2(-8.9, 4.7), "Wartezimmer": Vector2(-8.8, -1.6),
	"WartezimmerSchwester": Vector2(-8.8, -1.6), "SchwesterWarten": Vector2(-8.8, -1.6),
	"Schwester": Vector2(2, 3.5), "ArztWarten": Vector2(0, -1.7),
	"Arzt": Vector2(0, -3.0), "Ausgang": Vector2(-6.25, 8.6)
}
var patienten: Dictionary = {}
var belegung: Dictionary = {}
var aktive_plaetze: Dictionary = {}

func laden(plan: Array) -> void:
	patienten.clear()
	belegung.clear()
	aktive_plaetze.clear()
	# Die Eingabe kommt bereits in der exakten Ausführungsreihenfolge des Kerns.
	for ev in plan:
		var id := str(int(ev["patientId"]))
		if int(id) <= 0:
			continue # Globale Prognosemeldungen sind keine Personen.
		var typ := String(ev["eventTyp"])
		var zeit := float(ev["zeit"])
		if not patienten.has(id):
			patienten[id] = []
		var timeline: Array = patienten[id]
		if typ == "betritt_klinik":
			timeline.append(_eintrag(zeit, "Eingang", STATIONEN["Eingang"], typ, false, false))
			continue
		if timeline.is_empty():
			continue # Vor Öffnung wartende/außerhalb abgewiesene Personen bleiben draußen.
		var vorher: Dictionary = timeline[-1]
		if typ == "verlaesst_klinik":
			_freigeben(id)
			timeline.append(_eintrag(zeit, "Ausgang", STATIONEN["Ausgang"], typ, false, true))
		elif _ist_bewegung(typ):
			_freigeben(id)
			timeline.append(_eintrag(zeit, vorher["station"], vorher["punkt"], typ, true, false))
			# Der Server liefert die echte Dauer des gerade gestarteten SimSharp-Timeouts.
			# Damit beginnt die Bewegung live, ohne ein künftiges Ereignis vorwegzunehmen.
			var dauer := float(ev.get("bewegungsdauerMinuten", 0.0))
			var ziel := _bewegungsziel(typ)
			if dauer > 0.0 and not ziel.is_empty():
				var zielpunkt: Vector2 = STATIONEN[ziel] if ziel == "Ausgang" else _platz(id, ziel, ev)
				timeline.append(_eintrag(zeit + dauer, ziel, zielpunkt, typ + "_ziel", false, ziel == "Ausgang"))
		else:
			var station := _ankunft(typ)
			if station.is_empty() or (station == vorher["station"] and not vorher["bewegung"] and typ != "startet_schwester_prozess"):
				continue # Prognose-/Terminmeldungen ändern keine räumliche Position.
			_freigeben(id)
			var punkt := _platz(id, station, ev)
			timeline.append(_eintrag(zeit, station, punkt, typ, false, false))

	# Mehrere räumliche Meldungen desselben Zeitpunkts ergeben die letzte Position.
	# Die vollständige Ereignisfolge bleibt im C#-Controller erhalten.
	for id in patienten:
		var kompakt: Array = []
		for ev in patienten[id]:
			if not kompakt.is_empty() and ev["zeit"] == kompakt[-1]["zeit"]:
				kompakt[-1] = ev
			else:
				kompakt.append(ev)
		patienten[id] = kompakt

func _eintrag(zeit: float, station: String, punkt: Vector2, typ: String, bewegt: bool, draussen: bool) -> Dictionary:
	return {"zeit": zeit, "station": station, "punkt": punkt, "typ": typ,
		"bewegung": bewegt, "ausgetreten": draussen}

func _ist_bewegung(typ: String) -> bool:
	return typ.begins_with("geht_") or typ in ["verlaesst_nach_arzt_ohne_rezeption", "verlaesst_wartezimmer_fuer_arzt", "verlaesst_wartezimmer_schwester"]

func _bewegungsziel(typ: String) -> String:
	match typ:
		"geht_zur_rezeption", "geht_nach_arzt_zur_rezeption": return "RezeptionWarten"
		"geht_ins_wartezimmer_schwester": return "WartezimmerSchwester"
		"geht_zur_schwester": return "Schwester"
		"geht_ins_wartezimmer_fuer_arzt": return "Wartezimmer"
		"geht_zum_arzt", "verlaesst_wartezimmer_fuer_arzt": return "ArztWarten"
		"geht_zum_ausgang", "verlaesst_nach_arzt_ohne_rezeption": return "Ausgang"
	return ""

func _ankunft(typ: String) -> String:
	match typ:
		"betritt_rezeption_warteschlange": return "RezeptionWarten"
		"betritt_rezeption", "startet_rezeption": return "Rezeption"
		"betritt_wartezimmer_schwester", "betritt_schwester_warteschlange": return "WartezimmerSchwester"
		"betritt_schwesterzimmer", "startet_schwester_prozess": return "Schwester"
		"betritt_wartezimmer", "betritt_wartezimmer_fuer_arzt": return "Wartezimmer"
		"betritt_arztzimmer", "betritt_arzt_warteschlange": return "ArztWarten"
		"startet_arzt_behandlung": return "Arzt"
	return ""

func _freigeben(id: String) -> void:
	if aktive_plaetze.has(id):
		var platz: Dictionary = aktive_plaetze[id]
		belegung[platz["station"]].erase(platz["nummer"])
		aktive_plaetze.erase(id)

func _platz(id: String, station: String, ev: Dictionary) -> Vector2:
	# Beide fachlichen Warteschlangen nutzen denselben sichtbaren Warteraum.
	# Die Platzbelegung ist ausschließlich grafisch und ändert keine Modellqueue.
	var gruppe := "Wartezimmer" if station in ["Wartezimmer", "WartezimmerSchwester", "SchwesterWarten"] else station
	if not belegung.has(gruppe):
		belegung[gruppe] = {}
	var nummer := 0
	while belegung[gruppe].has(nummer):
		nummer += 1
	belegung[gruppe][nummer] = id
	aktive_plaetze[id] = {"station": gruppe, "nummer": nummer}
	if station == "Arzt":
		var index := maxi(0, int(ev.get("arztId", 1)) - 1)
		# Die gelieferten zwei Ärzte erhalten je ihr eigenes Zimmer.
		return Vector2(6.65 * (index % 2) - 0.8 * (index / 2), -3.0)
	if station == "Schwester":
		var index := maxi(0, int(ev.get("schwesterId", 1)) - 1)
		return Vector2(2.0 + (index % 3) * 2.5, 3.5 - (index / 3) * 0.6)
	if station == "Rezeption":
		return STATIONEN[station] + Vector2(nummer * 0.7, 0)
	if gruppe == "Wartezimmer":
		# Freie Streifen vor und hinter den übernommenen Sitzreihen.
		var reihen := [-1.6, -2.25, -6.15]
		if nummer < 24:
			return Vector2(-9.0 + (nummer % 8) * 0.68, reihen[nummer / 8])
		# Zusätzliche grafische Warteplätze im Flur bei starker Belegung.
		return Vector2(-9.0 + ((nummer - 24) % 24) * 0.78, -0.25 + ((nummer - 24) / 24) * 0.6)
	if station == "ArztWarten":
		return STATIONEN[station] + Vector2((nummer % 4) * 0.6 - 0.9, -(nummer / 4) * 0.6)
	return STATIONEN[station] + Vector2((nummer % 3) * 0.65, (nummer / 3) * 0.6)

func zustand(id: String, minute: float) -> Dictionary:
	var timeline: Array = patienten.get(id, [])
	if timeline.is_empty() or minute < float(timeline[0]["zeit"]):
		return {}
	# Letztes Ereignis <= Uhr; Reihenfolge bei gleicher Zeit bleibt erhalten.
	var links := 0
	var rechts := timeline.size()
	while links < rechts:
		var mitte := (links + rechts) / 2
		if float(timeline[mitte]["zeit"]) <= minute:
			links = mitte + 1
		else:
			rechts = mitte
	var index := links - 1
	var aktuell: Dictionary = timeline[index]
	var punkt: Vector2 = aktuell["punkt"]
	var richtung := Vector2.ZERO
	if aktuell["bewegung"] and index + 1 < timeline.size():
		var ziel: Dictionary = timeline[index + 1]
		# Zwischen Bewegungsstart und tatsächlichem Ankunftsereignis interpolieren.
		var dauer := float(ziel["zeit"]) - float(aktuell["zeit"])
		if dauer > 0:
			var faktor := clampf((minute - float(aktuell["zeit"])) / dauer, 0, 1)
			var position_info := _auf_weg(punkt, ziel["punkt"], faktor)
			punkt = position_info["position"]
			richtung = position_info["richtung"]
	return {"position": punkt, "richtung": richtung, "ausgetreten": aktuell["ausgetreten"],
		"station": aktuell["station"], "typ": aktuell["typ"]}

func _raum(punkt: Vector2) -> String:
	if punkt.y > 7.0:
		return "Draussen"
	if punkt.y >= 1.7:
		return "Rezeption" if punkt.x < 0 else "Schwester"
	if punkt.y <= -0.7:
		if punkt.x < -3.33:
			return "Wartezimmer"
		return "Arzt1" if punkt.x < 3.33 else "Arzt2"
	return "Flur"

func _zum_flur(punkt: Vector2) -> Array[Vector2]:
	# Austritt aus einem Raum immer durch dessen reale Tür, dann in den Flur.
	match _raum(punkt):
		"Wartezimmer":
			if punkt.y < -2.6:
				var seite := -9.35 if punkt.x < -6.65 else -3.85
				return [punkt, Vector2(seite, punkt.y), Vector2(seite, -1.15), Vector2(-6.65, -1.15), Vector2(-6.65, 0.5)]
			return [punkt, Vector2(-6.65, -1.15), Vector2(-6.65, 0.5)]
		"Arzt1": return [punkt, Vector2(0, -1.15), Vector2(0, 0.5)]
		"Arzt2": return [punkt, Vector2(6.65, -1.15), Vector2(6.65, 0.5)]
		"Rezeption":
			if punkt.y > 2.4:
				return [punkt, Vector2(-8.9, punkt.y), Vector2(-8.9, 2.05), Vector2(-5, 2.1), Vector2(-5, 0.5)]
			return [punkt, Vector2(-5, 2.1), Vector2(-5, 0.5)]
		"Schwester": return [punkt, Vector2(5, 2.1), Vector2(5, 0.5)]
		"Draussen": return [punkt, Vector2(-6.25, 6.5), Vector2(-8.9, 6.1), Vector2(-8.9, 2.1), Vector2(-5, 2.1), Vector2(-5, 0.5)]
	return [punkt]

func _wegpunkte(start: Vector2, ziel: Vector2) -> Array[Vector2]:
	if _raum(start) == _raum(ziel):
		if _raum(start) == "Rezeption" and (start.y > 2.4) != (ziel.y > 2.4):
			return [start, Vector2(-8.9, start.y), Vector2(-8.9, ziel.y), ziel]
		return [start, ziel]
	# Eingang und Empfang liegen im selben Raum: am Tresen vorbeigehen.
	if _raum(start) in ["Draussen", "Rezeption"] and _raum(ziel) in ["Draussen", "Rezeption"]:
		var raus := _raum(ziel) == "Draussen"
		var innen := start if raus else ziel
		var aussen := ziel if raus else start
		var weg: Array[Vector2] = [aussen, Vector2(-6.25, 6.1), Vector2(-8.9, 6.1), Vector2(-8.9, 2.05), innen]
		if innen.y > 3.8:
			weg = [aussen, Vector2(-6.25, 6.1), Vector2(innen.x, 6.1), innen]
		if raus:
			weg.reverse()
		return weg
	var punkte := _zum_flur(start)
	var zurueck := _zum_flur(ziel)
	zurueck.reverse()
	punkte.append_array(zurueck)
	return punkte

func _auf_weg(start: Vector2, ziel: Vector2, faktor: float) -> Dictionary:
	var punkte := _wegpunkte(start, ziel)
	var laenge := 0.0
	for i in range(1, punkte.size()):
		laenge += punkte[i - 1].distance_to(punkte[i])
	var rest := faktor * laenge
	for i in range(1, punkte.size()):
		var abschnitt := punkte[i - 1].distance_to(punkte[i])
		if abschnitt < 0.00001:
			continue
		if rest <= abschnitt:
			return {"position": punkte[i - 1].lerp(punkte[i], rest / abschnitt), "richtung": punkte[i] - punkte[i - 1]}
		rest -= abschnitt
	return {"position": ziel, "richtung": Vector2.ZERO}
