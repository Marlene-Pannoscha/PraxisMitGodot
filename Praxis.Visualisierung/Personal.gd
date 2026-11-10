extends Node3D
## Sichtbares Personal am Arbeitsplatz; der SimSharp-Kern liefert keine Personalwege.

const MODELLE := {
	"Rezeption": preload("res://Personal/Receptionist.glb"),
	"Schwester": preload("res://Personal/WardNurse.glb"),
	"Arzt": preload("res://Personal/WhiteCoatDoctor.glb")
}
const FIGUR_GROESSE := 15.0

var rolle := ""
var animation: AnimationPlayer

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

func aktualisieren(delta: float) -> void:
	animation.advance(delta)
