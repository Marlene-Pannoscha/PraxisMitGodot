@tool
extends RefCounted
## Wiederverwendbare Moebeltypen; Standorte und Zuordnung stehen in den Raumdateien.

var praxis: Node3D
const KONFIGURATION = preload("res://Konfiguration/KonfigurationLader.gd")

func _init(ziel: Node3D) -> void:
	praxis = ziel

func create_box(object_name, pos, size, color):
	praxis.create_box(object_name, pos, size, color)

func create_furniture(daten: Dictionary) -> void:
	for platz in daten["warteplaetze"]:
		var punkt := KONFIGURATION.punkt2(platz["position"])
		create_chair(Vector3(punkt.x, 0, punkt.y))
	for eintrag in daten["ausstattung"]:
		var punkt := KONFIGURATION.punkt3(eintrag["position"])
		match String(eintrag["typ"]):
			"box": create_box(eintrag["name"], punkt, KONFIGURATION.punkt3(eintrag["groesse"]), Color(eintrag["farbe"]))
			"stuhl": create_chair(punkt, float(eintrag.get("lehnen_richtung", 1.0)))
			"tisch": create_desk(punkt)
			"liege": create_examination_bed(punkt)

func create_chair(pos: Vector3, lehnen_richtung: float = 1.0):
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
		pos + Vector3(0, 0.85, 0.3 * lehnen_richtung),
		Vector3(0.65, 0.8, 0.12),
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
