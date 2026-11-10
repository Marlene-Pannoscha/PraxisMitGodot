
@tool
extends Node3D

const WALL_HEIGHT = 2.5
const WALL_THICKNESS = 0.18
const DOOR_WIDTH = 1.5

var generated: Node3D


func _ready():
	build_layout()


func build_layout():
	var old = get_node_or_null("Generated")

	if old:
		remove_child(old)
		old.free()

	generated = Node3D.new()
	generated.name = "Generated"
	add_child(generated)

	# Gesamtboden
	create_box(
		"Boden",
		Vector3(0, -0.15, 0),
		Vector3(20, 0.3, 14),
		Color("#e8edf0")
	)

	# Hintere drei Räume
	create_box("Wartezimmer",
		Vector3(-6.65, 0.02, -3.75),
		Vector3(6.5, 0.04, 6.3),
		Color("#d5e8f7"))

	create_box("Arztzimmer_1",
		Vector3(0, 0.02, -3.75),
		Vector3(6.5, 0.04, 6.3),
		Color("#dcebd6"))

	create_box("Arztzimmer_2",
		Vector3(6.65, 0.02, -3.75),
		Vector3(6.5, 0.04, 6.3),
		Color("#dcebd6"))

	# Vorderer Bereich
	create_box("Rezeption",
		Vector3(-5, 0.02, 4.35),
		Vector3(9.8, 0.04, 5.1),
		Color("#f3dfc9"))

	create_box("Schwesternzimmer",
		Vector3(5, 0.02, 4.35),
		Vector3(9.8, 0.04, 5.1),
		Color("#e5ddf3"))

	# Zentraler Flur
	create_box("Flur",
		Vector3(0, 0.025, 0.5),
		Vector3(19.8, 0.05, 2.4),
		Color("#f4e9cf"))

	# Außenwände
	wall_x(-7, -10, 10)
	wall_z(-10, -7, 7)
	wall_z(10, -7, 7)

	# Vorderwand mit Eingang
	wall_x(7, -10, -7)
	wall_x(7, -5.5, 10)

	# Trennwände der hinteren Räume
	wall_z(-3.33, -7, -0.7)
	wall_z(3.33, -7, -0.7)

	# Trennwand zwischen Rezeption und Schwestern
	wall_z(0, 1.7, 7)

	# Hintere Raumfronten mit Türen
	door_wall(-6.65, -0.7, 6.5)
	door_wall(0, -0.7, 6.5)
	door_wall(6.65, -0.7, 6.5)

	# Vordere Raumfronten mit Türen
	door_wall(-5, 1.7, 10)
	door_wall(5, 1.7, 10)
	create_furniture()


func door_wall(center_x, z, width):
	var left = center_x - width / 2
	var right = center_x + width / 2

	wall_x(z, left, center_x - DOOR_WIDTH / 2)
	wall_x(z, center_x + DOOR_WIDTH / 2, right)



func wall_x(z, start_x, end_x):
	var height = WALL_HEIGHT

	# Vorderwand deutlich niedriger darstellen
	if z > 6.5:
		height = 0.45

	create_box(
		"Wand",
		Vector3((start_x + end_x) / 2, height / 2, z),
		Vector3(end_x - start_x, height, WALL_THICKNESS),
		Color("#e8eef0")
	)



func wall_z(x, start_z, end_z):
	create_box(
		"Wand",
		Vector3(x, WALL_HEIGHT / 2, (start_z + end_z) / 2),
		Vector3(WALL_THICKNESS, WALL_HEIGHT, end_z - start_z),
		Color("#e8eef0")
	)


func create_box(object_name, pos, size, color):
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = object_name

	var mesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh

	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85

	mesh_instance.material_override = material
	mesh_instance.position = pos

	generated.add_child(mesh_instance)
	

func create_furniture():
	# ==========================
	# REZEPTION
	# ==========================

	# Empfangstresen
	create_box(
		"Empfangstresen",
		Vector3(-6.5, 0.55, 3.0),
		Vector3(3.5, 1.1, 0.75),
		Color("#a8c5d1")
	)

	# Arbeitsplatte
	create_box(
		"Tresenplatte",
		Vector3(-6.5, 1.12, 3.0),
		Vector3(3.7, 0.1, 0.9),
		Color("#f5f5f5")
	)

	# Monitor
	create_box(
		"Rezeption_Monitor",
		Vector3(-6.5, 1.5, 3.5),
		Vector3(0.7, 0.5, 0.08),
		Color("#303b46")
	)

	create_chair(Vector3(-6.5, 0, 4.3))

	# ==========================
	# WARTEZIMMER
	# ==========================

	for i in range(4):
		create_chair(
			Vector3(-8.5 + i * 1.2, 0, -5.0)
		)

	for i in range(3):
		create_chair(
			Vector3(-8.5 + i * 1.2, 0, -3.0)
		)

	# Kleiner Tisch
	create_box(
		"Wartezimmer_Tisch",
		Vector3(-6.5, 0.4, -4.0),
		Vector3(1.2, 0.8, 0.8),
		Color("#b99b7a")
	)

	# ==========================
	# ARZT 1
	# ==========================

	create_desk(Vector3(0, 0, -5.0))
	create_chair(Vector3(0, 0, -4.0))
	create_examination_bed(Vector3(1.6, 0, -3.0))

	# ==========================
	# ARZT 2
	# ==========================

	create_desk(Vector3(6.5, 0, -5.0))
	create_chair(Vector3(6.5, 0, -4.0))
	create_examination_bed(Vector3(8.0, 0, -3.0))

	# ==========================
	# SCHWESTERNZIMMER
	# ==========================

	for i in range(3):
		var x = 2.0 + i * 2.5
		create_desk(Vector3(x, 0, 5.5))
		create_chair(Vector3(x, 0, 4.5))


func create_chair(pos: Vector3):
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
		pos + Vector3(0, 0.85, 0.3),
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
