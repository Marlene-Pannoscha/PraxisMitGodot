extends RefCounted
## Bestehende Raumgrenzen und Wege, unveraendert ausgelagert.

var dynamische_raeume: Array = []
var dynamische_tueren: Dictionary = {}

func konfigurieren(daten: Dictionary) -> void:
	dynamische_raeume.clear()
	dynamische_tueren.clear()
	for raum in daten.get("raeume", []):
		dynamische_raeume.append(raum)
	for tuer in daten.get("tueren", []):
		dynamische_tueren[String(tuer.get("id", ""))] = tuer

func _polygon(raum: Dictionary) -> PackedVector2Array:
	var ergebnis := PackedVector2Array()
	if raum.has("grundriss"):
		for punkt in raum["grundriss"]:
			ergebnis.append(Vector2(float(punkt[0]), float(punkt[1])))
		return ergebnis
	var mitte := Vector2(float(raum["position"][0]), float(raum["position"][2]))
	var mass := Vector2(float(raum["groesse"][0]), float(raum["groesse"][2]))
	return PackedVector2Array([mitte - mass / 2.0, Vector2(mitte.x + mass.x / 2.0, mitte.y - mass.y / 2.0),
		mitte + mass / 2.0, Vector2(mitte.x - mass.x / 2.0, mitte.y + mass.y / 2.0)])

func _segment_liegt_im_raum(von: Vector2, bis: Vector2, polygon: PackedVector2Array) -> bool:
	var schritte := maxi(1, int(ceil(von.distance_to(bis) / 0.2)))
	for nummer in range(schritte + 1):
		var punkt := von.lerp(bis, float(nummer) / float(schritte))
		if not Geometry2D.is_point_in_polygon(punkt, polygon):
			return false
	return true

func _innenweg(von: Vector2, bis: Vector2, polygon: PackedVector2Array) -> Array[Vector2]:
	if _segment_liegt_im_raum(von, bis, polygon):
		return [von, bis]
	var ecke_x := Vector2(bis.x, von.y)
	if Geometry2D.is_point_in_polygon(ecke_x, polygon) and _segment_liegt_im_raum(von, ecke_x, polygon) and _segment_liegt_im_raum(ecke_x, bis, polygon):
		return [von, ecke_x, bis]
	var ecke_y := Vector2(von.x, bis.y)
	if Geometry2D.is_point_in_polygon(ecke_y, polygon) and _segment_liegt_im_raum(von, ecke_y, polygon) and _segment_liegt_im_raum(ecke_y, bis, polygon):
		return [von, ecke_y, bis]
	return _innenweg_raster(von, bis, polygon)

func _innenweg_raster(von: Vector2, bis: Vector2, polygon: PackedVector2Array) -> Array[Vector2]:
	const RASTER := 0.5
	var grenzen := Rect2(polygon[0], Vector2.ZERO)
	for punkt in polygon:
		grenzen = grenzen.expand(punkt)
	var knoten: Array[Vector2] = []
	var x := snappedf(grenzen.position.x, RASTER)
	while x <= grenzen.end.x + 0.01:
		var y := snappedf(grenzen.position.y, RASTER)
		while y <= grenzen.end.y + 0.01:
			var kandidat := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(kandidat, polygon):
				knoten.append(kandidat)
			y += RASTER
		x += RASTER
	if knoten.is_empty():
		return [von, bis]
	var start := knoten[0]
	var ziel := knoten[0]
	for knotenpunkt in knoten:
		if knotenpunkt.distance_squared_to(von) < start.distance_squared_to(von):
			start = knotenpunkt
		if knotenpunkt.distance_squared_to(bis) < ziel.distance_squared_to(bis):
			ziel = knotenpunkt
	var offen: Array[Vector2] = [start]
	var besucht := {start: true}
	var vorher := {}
	while not offen.is_empty():
		var aktuell: Vector2 = offen.pop_front()
		if aktuell.is_equal_approx(ziel):
			var rueckweg: Array[Vector2] = [ziel]
			while vorher.has(rueckweg[-1]):
				rueckweg.append(vorher[rueckweg[-1]])
			rueckweg.reverse()
			var ergebnis: Array[Vector2] = [von]
			for wegpunkt in rueckweg:
				if ergebnis[-1].distance_to(wegpunkt) > 0.05:
					ergebnis.append(wegpunkt)
			if ergebnis[-1].distance_to(bis) > 0.05:
				ergebnis.append(bis)
			return ergebnis
		var richtungen: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
		for richtung: Vector2 in richtungen:
			var nachbar: Vector2 = aktuell + richtung * RASTER
			if besucht.has(nachbar) or not Geometry2D.is_point_in_polygon(nachbar, polygon):
				continue
			if not _segment_liegt_im_raum(aktuell, nachbar, polygon):
				continue
			besucht[nachbar] = true
			vorher[nachbar] = aktuell
			offen.append(nachbar)
	return [von, bis]

func _raum(punkt: Vector2) -> String:
	# Zuletzt erzeugte Raeume zuerst pruefen. Das macht die Vorschau auch dann
	# stabil, wenn ein noch nicht gespeicherter Entwurf kurz alte Flaechen beruehrt.
	for index in range(dynamische_raeume.size() - 1, -1, -1):
		var raum: Dictionary = dynamische_raeume[index]
		if Geometry2D.is_point_in_polygon(punkt, _polygon(raum)):
			return String(raum["id"])
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
	var raum_id := _raum(punkt)
	var dynamischer_weg := _raumweg_zum_flur(punkt, raum_id, {})
	if not dynamischer_weg.is_empty():
		return dynamischer_weg
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

func _raum_daten(raum_id: String) -> Dictionary:
	for raum in dynamische_raeume:
		if String(raum["id"]) == raum_id:
			return raum
	return {}

func _anderer_raum(tuer: Dictionary, raum_id: String) -> String:
	for verbunden in tuer.get("verbindung", []):
		if String(verbunden) != raum_id and String(verbunden) != "Draussen":
			return String(verbunden)
	return ""

func _flur_distanz(raum_id: String, besucht: Dictionary) -> int:
	var raum := _raum_daten(raum_id)
	if raum.is_empty():
		return 1000000
	if String(raum.get("typ", "")) == "Flur":
		return 0
	if besucht.has(raum_id):
		return 1000000
	var naechste_besucht := besucht.duplicate()
	naechste_besucht[raum_id] = true
	var beste := 1000000
	for tuer_id in raum.get("tueren", []):
		var tuer: Dictionary = dynamische_tueren.get(String(tuer_id), {})
		var nachbar := _anderer_raum(tuer, raum_id)
		if not nachbar.is_empty():
			beste = mini(beste, 1 + _flur_distanz(nachbar, naechste_besucht))
	return beste

func _raumweg_zum_flur(punkt: Vector2, raum_id: String, besucht: Dictionary) -> Array[Vector2]:
	var raum := _raum_daten(raum_id)
	if raum.is_empty() or besucht.has(raum_id):
		return []
	if String(raum.get("typ", "")) == "Flur":
		return [punkt]
	var naechste_besucht := besucht.duplicate()
	naechste_besucht[raum_id] = true
	var beste_tuer: Dictionary = {}
	var bester_nachbar := ""
	var beste_distanz := 1000000
	for tuer_id in raum.get("tueren", []):
		var tuer: Dictionary = dynamische_tueren.get(String(tuer_id), {})
		var nachbar := _anderer_raum(tuer, raum_id)
		if nachbar.is_empty() or naechste_besucht.has(nachbar):
			continue
		var distanz := _flur_distanz(nachbar, naechste_besucht)
		if distanz < beste_distanz:
			beste_distanz = distanz
			beste_tuer = tuer
			bester_nachbar = nachbar
	if beste_tuer.is_empty() or beste_distanz >= 1000000:
		return []
	var tuerpunkt := Vector2(float(beste_tuer["position"][0]), float(beste_tuer["position"][1]))
	var innen_richtung := Vector2(0, -1)
	match String(beste_tuer.get("seite", "vorne")):
		"links": innen_richtung = Vector2(1, 0)
		"rechts": innen_richtung = Vector2(-1, 0)
		"hinten": innen_richtung = Vector2(0, 1)
	if String(beste_tuer.get("raum_id", "")) != raum_id:
		innen_richtung = -innen_richtung
	var innen := tuerpunkt + innen_richtung * 0.65
	var nachbar_punkt := tuerpunkt - innen_richtung * 0.65
	var weg := _innenweg(punkt, innen, _polygon(raum))
	weg.append(tuerpunkt)
	weg.append(nachbar_punkt)
	var fortsetzung := _raumweg_zum_flur(nachbar_punkt, bester_nachbar, naechste_besucht)
	if not fortsetzung.is_empty():
		fortsetzung.pop_front()
		weg.append_array(fortsetzung)
	return weg

func _wegpunkte(start: Vector2, ziel: Vector2) -> Array[Vector2]:
	if _raum(start) == _raum(ziel):
		var raum_id := _raum(start)
		for raum in dynamische_raeume:
			if String(raum["id"]) == raum_id:
				return _innenweg(start, ziel, _polygon(raum))
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
