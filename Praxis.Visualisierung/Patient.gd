extends Node3D
## Eine Figur pro Patient. Die Simulation bestimmt den Weg, Gobkit die Pose.

const PATIENT_SZENE = preload("res://Patienten/WardPatient.glb")
# Die importierte Figur hat stark verkleinerte Skelettkoordinaten.
# Bei Faktor 25 liegt ihre Hoehe in der Praxis bei etwa 1,75 m.
const FIGUR_GROESSE := 15.0

var animation: AnimationPlayer
var bewegt_sich := false

func _ready() -> void:
	var modell := PATIENT_SZENE.instantiate() as Node3D
	modell.scale = Vector3.ONE * FIGUR_GROESSE
	add_child(modell)
	animation = modell.find_child("AnimationPlayer", true, false) as AnimationPlayer
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var bibliothek := AnimationLibrary.new()
	bibliothek.add_animation("Gehen", _animation_kopieren("Walk"))
	bibliothek.add_animation("Warten", _animation_kopieren("Idle"))
	for bibliothek_name in animation.get_animation_library_list():
		animation.remove_animation_library(bibliothek_name)
	animation.add_animation_library("", bibliothek)
	animation.play("Warten")
	animation.advance(0.0)

func _animation_kopieren(animationsname: String) -> Animation:
	var kopie := animation.get_animation(animationsname).duplicate() as Animation
	kopie.loop_mode = Animation.LOOP_LINEAR
	# Die Wurzelposition bleibt am Ort; Bewegung kommt aus der Simulation.
	for index in range(kopie.get_track_count() - 1, -1, -1):
		if kopie.track_get_type(index) == Animation.TYPE_POSITION_3D:
			kopie.remove_track(index)
	return kopie

func aktualisieren(punkt: Vector3, richtung: Vector3, delta: float) -> void:
	position = punkt
	var geht := richtung.length_squared() > 0.001
	if geht != bewegt_sich:
		bewegt_sich = geht
		animation.play("Gehen" if geht else "Warten", 0.12)
	if geht:
		# Die importierte Figur blickt nach +Z.
		rotation.y = atan2(richtung.x, richtung.z)
	animation.advance(delta)

func zuruecksetzen() -> void:
	bewegt_sich = false
	rotation.y = 0.0
	animation.play("Warten")
	animation.seek(0.0, true)
