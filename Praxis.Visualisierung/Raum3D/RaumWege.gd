extends RefCounted
## Bestehende Raumgrenzen und Wege, unveraendert ausgelagert.

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