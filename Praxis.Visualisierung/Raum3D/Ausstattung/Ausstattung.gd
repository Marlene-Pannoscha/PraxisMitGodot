@tool
extends RefCounted
## Wiederverwendbare Moebeltypen; Standorte und Zuordnung stehen in den Raumdateien.

var praxis: Node3D
# Lokale Moebelkoordinaten erlauben Tisch und Stuhl passend zum Arbeitsplatz zu drehen.
var moebel_transform := Transform3D.IDENTITY
const KONFIGURATION = preload("res://Konfiguration/KonfigurationLader.gd")

func _init(ziel: Node3D) -> void:
	praxis = ziel

func create_box(object_name, pos, size, color):
	var mesh: MeshInstance3D = praxis.create_box(object_name, pos, size, color)
	mesh.transform = moebel_transform * mesh.transform

func create_furniture(daten: Dictionary) -> void:
	var rezeptionen := {}
	for raum in daten["raeume"]:
		if String(raum.get("typ", "")) == "Rezeption":
			rezeptionen[String(raum["id"])] = true
	for platz in daten["warteplaetze"]:
		var punkt := KONFIGURATION.punkt2(platz["position"])
		var lehne_daten: Array = platz.get("lehnen_richtung", [0.0, 1.0])
		var lehne := Vector2(float(lehne_daten[0]), float(lehne_daten[1])).normalized()
		create_chair(Vector3(punkt.x, 0, punkt.y), lehne)
	for eintrag in daten["ausstattung"]:
		# Der alte hohe Tresen samt Einzelstuhl wird durch passende Sitzarbeitsplaetze
		# ersetzt. Eigene Zusatzmoebel und die gespeicherte Raumgeometrie bleiben erhalten.
		if rezeptionen.has(String(eintrag.get("raum_id", ""))):
			var standardstuhl := String(eintrag.get("id", "")) == String(eintrag["raum_id"]).to_lower() + "_ausstattung_4"
			var arbeitsplatzmoebel: bool = eintrag.has("arbeitsplatz_id") and String(eintrag.get("typ", "")) in ["tisch", "stuhl"]
			if String(eintrag.get("name", "")) in ["Empfangstresen", "Tresenplatte", "Rezeption_Monitor"] or standardstuhl or arbeitsplatzmoebel:
				continue
		var punkt := KONFIGURATION.punkt3(eintrag["position"])
		match String(eintrag["typ"]):
			"box": create_box(eintrag["name"], punkt, KONFIGURATION.punkt3(eintrag["groesse"]), Color(eintrag["farbe"]))
			"stuhl": create_chair(punkt, Vector2(0.0, float(eintrag.get("lehnen_richtung", 1.0))))
			"tisch": create_desk(punkt)
			"liege": create_examination_bed(punkt)
	# Pro vorhandenem Rezeptionsplatz ein rechteckiger Tisch und ein Stuhl.
	# Die Personal- und Patientenpositionen aus dem Layout werden nicht verschoben.
	for platz in daten["arbeitsplaetze"]:
		if String(platz.get("qualifikation", "")) != "Rezeption":
			continue
		var punkt := KONFIGURATION.punkt2(platz["position"])
		var winkel := deg_to_rad(float(platz.get("winkel_grad", 0.0)))
		moebel_transform = Transform3D(Basis(Vector3.UP, winkel), Vector3(punkt.x, 0.0, punkt.y))
		create_desk(Vector3(0.0, 0.0, 0.8))
		create_chair(Vector3.ZERO, Vector2(0.0, -1.0))
	moebel_transform = Transform3D.IDENTITY

func create_chair(pos: Vector3, lehnen_richtung := Vector2(0.0, 1.0)):
	var lehne: Vector2 = lehnen_richtung.normalized()
	# Sitzfläche
	create_box(
		"Stuhl_Sitz",
		pos + Vector3(0, 0.45, 0),
		Vector3(0.65, 0.15, 0.65),
		Color("#6f9db5")
	)

	# Rückenlehne
	create_box(
		"Stuhl_Lehne",
		pos + Vector3(lehne.x * 0.3, 0.85, lehne.y * 0.3),
		Vector3(0.12, 0.8, 0.65) if absf(lehne.x) > absf(lehne.y) else Vector3(0.65, 0.8, 0.12),
		Color("#6f9db5")
	)

	# Stuhlbeine
	for x in [-0.23, 0.23]:
		for z in [-0.23, 0.23]:
			create_box(
				"Stuhlbein",
				pos + Vector3(x, 0.2, z),
				Vector3(0.08, 0.4, 0.08),
				Color("#596b75")
			)


func create_desk(pos: Vector3):
	# Tischplatte
	create_box(
		"Schreibtisch",
		pos + Vector3(0, 0.75, 0),
		Vector3(1.5, 0.12, 0.75),
		Color("#c6a88a")
	)

	# Tischbeine
	for x in [-0.6, 0.6]:
		for z in [-0.25, 0.25]:
			create_box(
				"Tischbein",
				pos + Vector3(x, 0.35, z),
				Vector3(0.09, 0.7, 0.09),
				Color("#8c9299")
			)

	# Monitor
	create_box(
		"Monitor",
		pos + Vector3(0, 1.1, -0.15),
		Vector3(0.65, 0.45, 0.08),
		Color("#344450")
	)


func create_examination_bed(pos: Vector3):
	# Untergestell
	create_box(
		"Liege_Untergestell",
		pos + Vector3(0, 0.4, 0),
		Vector3(0.9, 0.8, 2.0),
		Color("#d8e1e5")
	)

	# Polster
	create_box(
		"Liege_Polster",
		pos + Vector3(0, 0.85, 0),
		Vector3(0.95, 0.15, 2.05),
		Color("#77b8c9")
	)

	# Kopfkissen
	create_box(
		"Liege_Kissen",
		pos + Vector3(0, 0.97, -0.75),
		Vector3(0.7, 0.1, 0.35),
		Color("#ffffff")
	)
