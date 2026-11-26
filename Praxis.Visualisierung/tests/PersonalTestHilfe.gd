extends RefCounted
## Bestehende Tests verwenden bewusst die urspruengliche Besetzung.
## Nur Testentwurf im Speicher; die vom Nutzer gewaehlte personal.json bleibt erhalten.

static func standardbesetzung(szene) -> void:
	# Aeltere Tests pruefen feste Kernkapazitaeten. Deren Startentwurf verwendet
	# deshalb die Stammrollen, unabhaengig von manuell gewaehlten Einsatz-Vorlagen.
	for eintrag in szene.personal_vorlagen:
		eintrag["einsatzrolle"] = eintrag.get("stammrolle", eintrag["qualifikationen"][0])
	if not szene.simulation_bereit:
		# Die Korrektur nutzt denselben Weg wie die Oberflaeche. Danach pausieren,
		# damit der jeweilige Test selbst den ersten Simulationsschritt ausloesen kann.
		var fehler: String = szene._personal_uebernehmen(szene.simulation.PersonalStandardwerteLesen())
		assert(fehler.is_empty(), fehler)
		szene.simulation.Pausieren()
