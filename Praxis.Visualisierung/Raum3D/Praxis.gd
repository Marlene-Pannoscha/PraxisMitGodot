@tool
extends Node3D

const KONFIGURATION = preload("res://Konfiguration/KonfigurationLader.gd")
const RAUM_LAYOUT = preload("res://Raum3D/RaumLayout.gd")
const RAUM = preload("res://Raum3D/Raum.tscn")
const AUSSTATTUNG = preload("res://Raum3D/Ausstattung/Ausstattung.gd")

var generated: Node3D
var layout_daten: Dictionary = {}
var raum_layout

func _ready() -> void:
	build_layout()

func build_layout() -> void:
	var daten := KONFIGURATION.layout() if layout_daten.is_empty() else layout_daten
	raum_layout = RAUM_LAYOUT.new(daten)
	var fehler: PackedStringArray = raum_layout.pruefen()
	if not fehler.is_empty() or daten.is_empty():
		push_error("Praxisaufbau abgebrochen: " + "; ".join(fehler))
		return
	var old := get_node_or_null("Generated")
	if old:
		remove_child(old)
		old.free()
	generated = Node3D.new()
	generated.name = "Generated"
	add_child(generated)
	var boden: Dictionary = daten["boden"]
	create_box("Boden", KONFIGURATION.punkt3(boden["position"]), KONFIGURATION.punkt3(boden["groesse"]), Color(boden["farbe"]))
	for raum_daten in daten["raeume"]:
		var raum = RAUM.instantiate()
		raum.einrichten(raum_daten, raum_layout)
		generated.add_child(raum)
	for wand in daten["waende"]:
		_baue_wand(wand, daten)
	create_furniture()

func _baue_wand(wand: Dictionary, daten: Dictionary) -> void:
	var von := RAUM_LAYOUT.punkt(wand["von"])
	var bis := RAUM_LAYOUT.punkt(wand["bis"])
	var horizontal := is_equal_approx(von.y, bis.y)
	var anfang := minf(von.x, bis.x) if horizontal else minf(von.y, bis.y)
	var ende := maxf(von.x, bis.x) if horizontal else maxf(von.y, bis.y)
	var oeffnungen: Array[Vector2] = []
	var tuer_ids := {}
	for tuer_id in wand.get("tueren", []):
		tuer_ids[String(tuer_id)] = true
	# Auch aeltere gespeicherte Layouts enthalten die Tuer teilweise nur an einer
	# der zwei ueberlappenden Waende. Die 3D-Erzeugung erkennt die Gegenseite daher
	# zusaetzlich geometrisch und oeffnet beide Waende.
	var raum_id := String(wand.get("raum_id", ""))
	var wand_vektor := bis - von
	for tuer in raum_layout.tueren.values():
		if not raum_id.is_empty() and raum_id not in tuer.get("verbindung", []):
			continue
		var tuerpunkt := RAUM_LAYOUT.punkt(tuer["position"])
		var faktor := clampf((tuerpunkt - von).dot(wand_vektor) / maxf(wand_vektor.length_squared(), 0.0001), 0.0, 1.0)
		if tuerpunkt.distance_to(von + wand_vektor * faktor) <= 0.4:
			tuer_ids[String(tuer["id"])] = true
	for tuer_id in tuer_ids:
		if not raum_layout.tueren.has(tuer_id):
			continue
		var tuer: Dictionary = raum_layout.tueren[tuer_id]
		var mitte := float(tuer["position"][0 if horizontal else 1])
		var halb := float(tuer["breite"]) / 2.0
		oeffnungen.append(Vector2(mitte - halb, mitte + halb))
	oeffnungen.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var cursor := anfang
	for oeffnung in oeffnungen:
		_wandstueck(von, horizontal, cursor, oeffnung.x, wand, daten)
		cursor = maxf(cursor, oeffnung.y)
	_wandstueck(von, horizontal, cursor, ende, wand, daten)

func _wandstueck(von: Vector2, horizontal: bool, anfang: float, ende: float, wand: Dictionary, daten: Dictionary) -> void:
	if ende <= anfang:
		return
	var hoehe := float(wand.get("hoehe", daten["wandhoehe"]))
	var staerke := float(daten["wandstaerke"])
	var mitte := (anfang + ende) / 2.0
	var position := Vector3(mitte, hoehe / 2.0, von.y) if horizontal else Vector3(von.x, hoehe / 2.0, mitte)
	var groesse := Vector3(ende - anfang, hoehe, staerke) if horizontal else Vector3(staerke, hoehe, ende - anfang)
	create_box("Wand", position, groesse, Color("#e8eef0"))

func create_box(object_name, pos, size, color):
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = object_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh_instance.material_override = material
	mesh_instance.position = pos
	generated.add_child(mesh_instance)
	return mesh_instance

func create_furniture() -> void:
	AUSSTATTUNG.new(self).create_furniture(raum_layout.daten)
