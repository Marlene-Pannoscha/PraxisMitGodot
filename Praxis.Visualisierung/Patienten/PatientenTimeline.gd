extends RefCounted
## Räumliche Auswertung der Originalereignisse. Keine Behandlungs-/Queue-Logik.

const KONFIGURATION = preload("res://Konfiguration/KonfigurationLader.gd")
const RAUM_WEGE: GDScript = preload("res://Raum3D/RaumWege.gd")
var raum_wege = RAUM_WEGE.new()
# Vector2 steht fuer die X-/Z-Ebene der Praxis in Metern.
var STATIONEN: Dictionary = KONFIGURATION.stationen()
var wartepositionen: Array[Vector2] = KONFIGURATION.wartepositionen()
var arbeitsplaetze: Dictionary = {}
var arbeitsplaetze_nach_rolle: Dictionary = {"Arzt": [], "Schwester": [], "Rezeption": []}
var personal_arbeitsplaetze: Dictionary = {}
var patienten: Dictionary = {}
var belegung: Dictionary = {}
var aktive_plaetze: Dictionary = {}
var arbeitsplaetze: Dictionary = {}

func _init() -> void:
	for platz in KONFIGURATION.layout().get("arbeitsplaetze", []):
		arbeitsplaetze[String(platz["id"])] = platz

func _init() -> void:
	konfigurieren(KONFIGURATION.layout())

func konfigurieren(layout: Dictionary) -> void:
	personal_arbeitsplaetze.clear()
	raum_wege.konfigurieren(layout)
	wartepositionen.clear()
	for warteplatz in layout.get("warteplaetze", []):
		wartepositionen.append(KONFIGURATION.punkt2(warteplatz["position"]))
	arbeitsplaetze.clear()
	for rolle in arbeitsplaetze_nach_rolle:
		arbeitsplaetze_nach_rolle[rolle] = []
	for platz in layout.get("arbeitsplaetze", []):
		var platz_id := String(platz["id"])
		arbeitsplaetze[platz_id] = platz
		var rolle := String(platz.get("qualifikation", ""))
		if arbeitsplaetze_nach_rolle.has(rolle):
			arbeitsplaetze_nach_rolle[rolle].append(platz)

func personal_zuordnen(plaetze: Array) -> void:
	personal_arbeitsplaetze.clear()
	for person in plaetze:
		var platz_id := String(person["arbeitsplatz_id"])
		if arbeitsplaetze.has(platz_id):
			personal_arbeitsplaetze[String(person["personal_id"])] = arbeitsplaetze[platz_id]

func arbeitsplatz_fuer_personal(rolle: String, personal_nummer: int) -> Dictionary:
	var personal_id := "%s_%d" % [rolle.to_snake_case(), personal_nummer]
	if personal_arbeitsplaetze.has(personal_id):
		return personal_arbeitsplaetze[personal_id]
	var passende: Array = arbeitsplaetze_nach_rolle.get(rolle, [])
	if passende.is_empty() or personal_nummer < 1:
		return {}
	return passende[(personal_nummer - 1) % passende.size()]

func arbeitsplatz_aus_ereignis(ev: Dictionary, rolle: String, personal_nummer: int) -> Dictionary:
	var platz_id := String(ev.get("arbeitsplatzId", ""))
	if not platz_id.is_empty() and arbeitsplaetze.has(platz_id):
		var platz: Dictionary = arbeitsplaetze[platz_id]
		if String(platz.get("qualifikation", "")) == rolle:
			return platz
	return arbeitsplatz_fuer_personal(rolle, personal_nummer)

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

## Ergänzt genau ein bereits vom Kern erzeugtes Ereignis, ohne alle bisherigen
## Ereignisse erneut auszuwerten. Die fachliche Reihenfolge bleibt unverändert.
func ereignis_hinzufuegen(ev: Dictionary) -> void:
	# Main.gd reicht hier ausschliesslich bereits erzeugte Simulationsereignisse weiter.
	# Ankunftsabstaende werden im C#-PatientenGenerator aus patienten-konfiguration.json bestimmt.
	var id := str(int(ev["patientId"]))
	if int(id) <= 0:
		return
	var typ := String(ev["eventTyp"])
	var zeit := float(ev["zeit"])
	if not patienten.has(id):
		patienten[id] = []
	var patienten_timeline: Array = patienten[id]
	if typ == "betritt_klinik":
		# Ab diesem Ereignis kann Main.gd die Figur am Eingang sichtbar machen.
		_anhaengen(patienten_timeline, _eintrag(zeit, "Eingang", STATIONEN["Eingang"], typ, false, false))
		return
	if patienten_timeline.is_empty():
		return
	var vorher: Dictionary = patienten_timeline[-1]
	if typ == "verlaesst_klinik":
		_freigeben(id)
		_anhaengen(patienten_timeline, _eintrag(zeit, "Ausgang", STATIONEN["Ausgang"], typ, false, true))
	elif _ist_bewegung(typ):
		_freigeben(id)
		_anhaengen(patienten_timeline, _eintrag(zeit, vorher["station"], vorher["punkt"], typ, true, false))
		var dauer := float(ev.get("bewegungsdauerMinuten", 0.0))
		var ziel := _bewegungsziel(typ)
		if dauer > 0.0 and not ziel.is_empty():
			var zielpunkt: Vector2 = STATIONEN[ziel] if ziel == "Ausgang" else _platz(id, ziel, ev)
			_anhaengen(patienten_timeline, _eintrag(zeit + dauer, ziel, zielpunkt, typ + "_ziel", false, ziel == "Ausgang"))
	else:
		var station := _ankunft(typ)
		if station.is_empty() or (station == vorher["station"] and not vorher["bewegung"] and typ != "startet_schwester_prozess"):
			return
		_freigeben(id)
		var punkt := _platz(id, station, ev)
		_anhaengen(patienten_timeline, _eintrag(zeit, station, punkt, typ, false, false))

func _anhaengen(patienten_timeline: Array, eintrag: Dictionary) -> void:
	if not patienten_timeline.is_empty() and is_equal_approx(float(patienten_timeline[-1]["zeit"]), float(eintrag["zeit"])):
		patienten_timeline[-1] = eintrag
	else:
		patienten_timeline.append(eintrag)

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
	# Im gemeinsamen Personalpool liefert der Kern den wirklich reservierten Arbeitsplatz.
	var platz_id := String(ev.get("arbeitsplatzId", ""))
	if station in ["Rezeption", "Schwester"] and arbeitsplaetze.has(platz_id):
		var platz: Dictionary = arbeitsplaetze[platz_id]
		return KONFIGURATION.punkt2(platz["position"]) + Vector2(0, -1.7 if station == "Schwester" else -2.2)
	if station == "Arzt":
		var index := maxi(0, int(ev.get("arztId", 1)) - 1)
		# Die gelieferten zwei Ärzte erhalten je ihr eigenes Zimmer.
		var arzt_platz: Dictionary = arbeitsplatz_aus_ereignis(ev, "Arzt", index + 1)
		if not arzt_platz.is_empty():
			return KONFIGURATION.punkt2(arzt_platz.get("patienten_position", arzt_platz["position"]))
		return STATIONEN[station]
	if station == "Schwester":
		var index := maxi(0, int(ev.get("schwesterId", 1)) - 1)
		var schwester_platz: Dictionary = arbeitsplatz_aus_ereignis(ev, "Schwester", index + 1)
		if not schwester_platz.is_empty():
			return KONFIGURATION.punkt2(schwester_platz.get("patienten_position", schwester_platz["position"]))
		return STATIONEN[station]
	if station == "Rezeption":
		var rezeption_platz: Dictionary = arbeitsplatz_aus_ereignis(ev, "Rezeption", nummer + 1)
		return KONFIGURATION.punkt2(rezeption_platz.get("patienten_position", rezeption_platz["position"])) if not rezeption_platz.is_empty() else STATIONEN[station] + Vector2(nummer * 0.7, 0)
	if gruppe == "Wartezimmer":
		# Die ersten sieben Plaetze liegen genau auf den sichtbaren Stuehlen.
		if nummer < wartepositionen.size():
			return wartepositionen[nummer]
		# Weitere Patienten warten stehend am freien Rand des Wartezimmers.
		return Vector2(-9.0 + ((nummer - 7) % 8) * 0.68, -1.6 - ((nummer - 7) / 8) * 0.6)
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
	return raum_wege._raum(punkt)

func _auf_weg(start: Vector2, ziel: Vector2, faktor: float) -> Dictionary:
	return raum_wege._auf_weg(start, ziel, faktor)
