extends Node3D
## Sichtbares Personal am Arbeitsplatz; der SimSharp-Kern liefert keine Personalwege.

const MODELLE := {
	"Rezeption": preload("res://Personal/Modelle/Receptionist.glb"),
	"Schwester": preload("res://Personal/Modelle/WardNurse.glb"),
	"Arzt": preload("res://Personal/Modelle/WhiteCoatDoctor.glb")
}
const FIGUR_GROESSE := 15.0

var rolle := ""
var personal_id := ""
var arbeitsplatz_id := ""
var animation: AnimationPlayer
var wegpunkte: Array = []
var weg_index := 0
const LAUFGESCHWINDIGKEIT := 2.0

func _ready() -> void:
	var modell := (MODELLE[rolle] as PackedScene).instantiate() as Node3D
	modell.scale = Vector3.ONE * FIGUR_GROESSE
	add_child(modell)
	animation = modell.find_child("AnimationPlayer", true, false) as AnimationPlayer
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var warten := animation.get_animation("Idle").duplicate() as Animation
	warten.loop_mode = Animation.LOOP_LINEAR
	for index in range(warten.get_track_count() - 1, -1, -1):
		if warten.track_get_type(index) == Animation.TYPE_POSITION_3D:
			warten.remove_track(index)
	var bibliothek := AnimationLibrary.new()
	bibliothek.add_animation("Warten", warten)
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
