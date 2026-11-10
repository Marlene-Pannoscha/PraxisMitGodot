extends Node3D
## Eine Figur pro Patient. Die Trace-Datei bestimmt den Weg, die FBX die Pose.

const LAUF_SZENE = preload("res://Unarmed/RPG-Character@Unarmed-Walk-Injured.FBX")
const WARTE_SZENE = preload("res://Unarmed/RPG-Character@Unarmed-Idle-Injured.FBX")
const FIGUR_GROESSE := 0.75

var animation: AnimationPlayer
var bewegt_sich := false

func _ready() -> void:
	var modell := LAUF_SZENE.instantiate() as Node3D
	# Die importierten Animationen richten das Skelett bereits auf die Y-Achse aus.
	modell.scale = Vector3.ONE * FIGUR_GROESSE
	add_child(modell)
	# Das Paket weist keine fertige Patiententextur zu.
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#247db5")
	material.roughness = 0.85
	for mesh in modell.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = material
	animation = modell.find_child("AnimationPlayer", true, false) as AnimationPlayer
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var bibliothek := AnimationLibrary.new()
	bibliothek.add_animation("Gehen", _animation_kopieren(animation))
	var warte_modell := WARTE_SZENE.instantiate()
	var warte_player := warte_modell.find_child("AnimationPlayer", true, false) as AnimationPlayer
	bibliothek.add_animation("Warten", _animation_kopieren(warte_player))
	warte_modell.free()
	for name in animation.get_animation_library_list():
		animation.remove_animation_library(name)
	animation.add_animation_library("", bibliothek)
	animation.play("Warten")
	animation.advance(0.0)

func _animation_kopieren(player: AnimationPlayer) -> Animation:
	var quelle: Animation
	for name in player.get_animation_list():
		if name != "RESET":
			quelle = player.get_animation(name)
			break
	var kopie := quelle.duplicate() as Animation
	kopie.loop_mode = Animation.LOOP_LINEAR
	# Kein doppelter Weg: Vorwaertsbewegung kommt ausschliesslich aus der Trace.
	for index in range(kopie.get_track_count() - 1, -1, -1):
		if kopie.track_get_type(index) == Animation.TYPE_POSITION_3D and kopie.track_get_path(index).get_subname(0) == &"Motion":
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
