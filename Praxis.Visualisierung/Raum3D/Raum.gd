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
	var boden := BoxMesh.new()
	boden.size = groesse
	mesh = boden
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(daten["farbe"])
	material.roughness = 0.85
	material_override = material
