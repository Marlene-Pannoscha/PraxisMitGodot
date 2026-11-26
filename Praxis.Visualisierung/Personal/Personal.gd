extends Node3D
## Eine Figur je Person. Aufgaben und Rollenwechsel kommen ausschliesslich aus dem Simulationskern.

const MODELLE := {
	"Rezeption": preload("res://Personal/Modelle/Receptionist.glb"),
	"Schwester": preload("res://Personal/Modelle/WardNurse.glb"),
	"Arzt": preload("res://Personal/Modelle/WhiteCoatDoctor.glb")
}
const FIGUR_GROESSE := 15.0
const RAUM_WEGE = preload("res://Raum3D/RaumWege.gd")
var raum_wege = RAUM_WEGE.new()

var rolle := ""
var personal_id := ""
var arbeitsplatz_id := ""
var qualifikationen: Array[String] = []
var aktuelle_rolle := ""
var animation: AnimationPlayer
var wegpunkte: Array = []
var weg_index := 0
const LAUFGESCHWINDIGKEIT := 2.0
var stammposition: Vector3
var stammwinkel: float
var stammplatz: String
var unterwegs := false
var wechsel_von := Vector2.ZERO
var wechsel_nach := Vector2.ZERO
var wechsel_start := 0.0
var wechsel_dauer := 0.0

func _ready() -> void:
	stammposition = position
	stammwinkel = rotation.y
	stammplatz = arbeitsplatz_id
	aktuelle_rolle = rolle
	var modell := (MODELLE[rolle] as PackedScene).instantiate() as Node3D
	modell.scale = Vector3.ONE * FIGUR_GROESSE
	add_child(modell)
	animation = modell.find_child("AnimationPlayer", true, false) as AnimationPlayer
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var bibliothek := AnimationLibrary.new()
	bibliothek.add_animation("Warten", _animation_kopieren("Idle"))
	bibliothek.add_animation("Gehen", _animation_kopieren("Walk" if animation.has_animation("Walk") else "Idle"))
	for bibliothek_name in animation.get_animation_library_list():
		animation.remove_animation_library(bibliothek_name)
	animation.add_animation_library("", bibliothek)
	animation.play("Warten")
	animation.advance(0.0)
	if not wegpunkte.is_empty():
		# Personal muss auch vor Simulationsstart sichtbar am Arbeitsplatz stehen.
		# Der erste Wegpunkt liegt ausserhalb der Tuer und wuerde bei pausierter
		# Simulationsuhr sonst dauerhaft im Flur bleiben.
		var arbeitsplatz: Array = wegpunkte[-1]
		position = Vector3(float(arbeitsplatz[0]), 0.06, float(arbeitsplatz[1]))
		weg_index = wegpunkte.size()

func _animation_kopieren(animationsname: String) -> Animation:
	var kopie := animation.get_animation(animationsname).duplicate() as Animation
	kopie.loop_mode = Animation.LOOP_LINEAR
	for index in range(kopie.get_track_count() - 1, -1, -1):
		if kopie.track_get_type(index) == Animation.TYPE_POSITION_3D:
			kopie.remove_track(index)
	return kopie

func zuruecksetzen() -> void:
	position = stammposition
	rotation.y = stammwinkel
	arbeitsplatz_id = stammplatz
	aktuelle_rolle = rolle
	unterwegs = false
	animation.play("Warten")
	animation.advance(0.0)

func ereignis_uebernehmen(ev: Dictionary, ziel: Vector2, winkel: float) -> void:
	# Vor einem neuen Ereignis die eventuell laufende Bewegung exakt bis zu dessen Zeit auswerten.
	zeit_setzen(float(ev["zeit"]))
	match String(ev["eventTyp"]):
		"personal_wechsel_start":
			wechsel_von = Vector2(position.x, position.z)
			wechsel_nach = ziel
			wechsel_start = float(ev["zeit"])
			wechsel_dauer = float(ev["bewegungsdauerMinuten"])
			unterwegs = true
			animation.play("Gehen")
		"personal_wechsel_ende", "personal_aufgabe_start":
			position = Vector3(ziel.x, stammposition.y, ziel.y)
			rotation.y = winkel
			aktuelle_rolle = String(ev["zuRolle"])
			arbeitsplatz_id = String(ev["arbeitsplatzId"])
			unterwegs = false
			animation.play("Warten")

func zeit_setzen(minute: float) -> void:
	if not unterwegs or wechsel_dauer <= 0.0:
		return
	var faktor := clampf((minute - wechsel_start) / wechsel_dauer, 0.0, 1.0)
	var info: Dictionary = raum_wege._auf_weg(wechsel_von, wechsel_nach, faktor)
	var punkt: Vector2 = info["position"]
	position = Vector3(punkt.x, stammposition.y, punkt.y)
	var richtung: Vector2 = info["richtung"]
	if not richtung.is_zero_approx():
		rotation.y = atan2(richtung.x, richtung.y)

func aktualisieren(delta: float) -> void:
	animation.advance(delta)
	if weg_index >= wegpunkte.size() or delta <= 0.0:
		return
	var ziel_daten: Array = wegpunkte[weg_index]
	var ziel := Vector3(float(ziel_daten[0]), 0.06, float(ziel_daten[1]))
	var abstand := position.distance_to(ziel)
	if abstand <= 0.02:
		position = ziel
		weg_index += 1
		return
	var richtung := (ziel - position).normalized()
	position += richtung * minf(abstand, LAUFGESCHWINDIGKEIT * delta)
	rotation.y = atan2(richtung.x, richtung.z)
