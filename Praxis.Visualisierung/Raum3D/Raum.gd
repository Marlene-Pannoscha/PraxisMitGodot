@tool
extends MeshInstance3D
## Raum mit Boden und aufgeloesten Verweisen auf Tueren, Arbeits- und Warteplaetze.

const KONFIGURATION = preload("res://Konfiguration/KonfigurationLader.gd")
var raum_id := ""
var groesse := Vector3.ZERO
var tueren: Array[Dictionary] = []
var arbeitsplaetze: Array[Dictionary] = []
var warteplaetze: Array[Dictionary] = []

func einrichten(daten: Dictionary, layout) -> void:
	raum_id = String(daten["id"])
	name = String(daten["name"])
	position = KONFIGURATION.punkt3(daten["position"])
	groesse = KONFIGURATION.punkt3(daten["groesse"])
	tueren.clear()
	arbeitsplaetze.clear()
	warteplaetze.clear()
	for id in daten["tueren"]:
		tueren.append(layout.tueren[id])
	for id in daten["arbeitsplaetze"]:
		arbeitsplaetze.append(layout.arbeitsplaetze[id])
	for id in daten["warteplaetze"]:
		warteplaetze.append(layout.warteplaetze[id])
	if daten.has("grundriss"):
		mesh = _polygon_boden(daten["grundriss"], position, groesse.y)
	else:
		var boden := BoxMesh.new()
		boden.size = groesse
		mesh = boden
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(daten["farbe"])
	material.roughness = 0.85
	material_override = material

func _polygon_boden(punkte_daten: Array, mitte: Vector3, dicke: float) -> ArrayMesh:
	var punkte := PackedVector2Array()
	for punkt in punkte_daten:
		punkte.append(Vector2(float(punkt[0]) - mitte.x, float(punkt[1]) - mitte.z))
	var dreiecke := Geometry2D.triangulate_polygon(punkte)
	var vertices := PackedVector3Array()
	var normalen := PackedVector3Array()
	for index in dreiecke:
		vertices.append(Vector3(punkte[index].x, 0.0, punkte[index].y))
		normalen.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normalen
	var ergebnis := ArrayMesh.new()
	ergebnis.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return ergebnis
