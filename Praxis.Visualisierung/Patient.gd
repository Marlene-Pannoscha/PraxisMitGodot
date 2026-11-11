extends Node3D
## Eine Figur pro Patient. Die Simulation bestimmt den Weg, Gobkit die Pose.

const PATIENT_SZENE = preload("res://Patienten/WardPatient.glb")
# Die importierte Figur hat stark verkleinerte Skelettkoordinaten.
# Bei Faktor 25 liegt ihre Hoehe in der Praxis bei etwa 1,75 m.
const FIGUR_GROESSE := 15.0

var animation: AnimationPlayer
var skelett: Skeleton3D
var bein_grundpose: Dictionary = {}
var bewegt_sich := false
var sitzt := false

func _ready() -> void:
	# Initialisiert die Patientenfigur, lädt Modell und Skelett und richtet die
	# drei verwendeten Zustände Gehen, Warten und Sitzen ein.
	var modell := PATIENT_SZENE.instantiate() as Node3D
	modell.scale = Vector3.ONE * FIGUR_GROESSE
	add_child(modell)
	animation = modell.find_child("AnimationPlayer", true, false) as AnimationPlayer
	skelett = modell.find_child("Skeleton3D", true, false) as Skeleton3D
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var bibliothek := AnimationLibrary.new()
	bibliothek.add_animation("Gehen", _animation_kopieren("Walk"))
	bibliothek.add_animation("Warten", _animation_kopieren("Idle"))
	bibliothek.add_animation("Sitzen", _animation_kopieren("Idle"))
	for bibliothek_name in animation.get_animation_library_list():
		animation.remove_animation_library(bibliothek_name)
	animation.add_animation_library("", bibliothek)
	animation.play("Warten")
	animation.advance(0.0)
	for knochen_name in ["ufsvxn", "pqqdkc", "arj5mw", "tmf7uk"]:
		var knochen := skelett.find_bone(knochen_name)
		if knochen >= 0:
			bein_grundpose[knochen] = skelett.get_bone_pose_rotation(knochen)

func _animation_kopieren(animationsname: String) -> Animation:
	# Erstellt eine eigene Kopie einer vorhandenen Gobkit-Animation.
	# Positionsspuren werden entfernt, weil die Bewegung der Figur durch die
	# Simulation und nicht durch die importierte Animation gesteuert wird.
	var kopie := animation.get_animation(animationsname).duplicate() as Animation
	kopie.loop_mode = Animation.LOOP_LINEAR
	# Die Wurzelposition bleibt am Ort; Bewegung kommt aus der Simulation.
	for index in range(kopie.get_track_count() - 1, -1, -1):
		if kopie.track_get_type(index) == Animation.TYPE_POSITION_3D:
			kopie.remove_track(index)
	return kopie

func aktualisieren(punkt: Vector3, richtung: Vector3, delta: float, station: String = "") -> void:
	# Aktualisiert Position, Bewegungszustand, Blickrichtung und Pose des Patienten.
	# Bei einer geeigneten Position auf einem Stuhl wird die Sitzpose aktiviert;
	# während des Gehens wird die Figur an der Bewegungsrichtung ausgerichtet.
	position = punkt
	var geht := richtung.length_squared() > 0.001
	var soll_sitzen := not geht and station in ["Wartezimmer", "WartezimmerSchwester", "SchwesterWarten", "Arzt", "Schwester"]
	# Nur die sieben belegbaren Stuehle im Wartezimmer haben Sitzpositionen.
	if station in ["Wartezimmer", "WartezimmerSchwester", "SchwesterWarten"]:
		soll_sitzen = soll_sitzen and _auf_wartestuhl(punkt)
	if geht != bewegt_sich or soll_sitzen != sitzt:
		bewegt_sich = geht
		sitzt = soll_sitzen
		animation.play("Gehen" if geht else ("Sitzen" if sitzt else "Warten"), 0.12)
		if not sitzt:
			skelett.reset_bone_poses()
	var modell := animation.get_parent() as Node3D
	modell.position.y = -0.35 if sitzt else 0.0
	if geht:
		# Die importierte Figur blickt nach +Z.
		rotation.y = atan2(richtung.x, richtung.z)
	elif sitzt:
		# Die Stuhllehne liegt hinter dem Patienten.
		rotation.y = 0.0 if station == "Schwester" else PI
	animation.advance(delta)
	if sitzt:
		_sitzpose_anwenden()

func _auf_wartestuhl(punkt: Vector3) -> bool:
	# Prüft, ob die angegebene 3D-Position einem der belegbaren Wartezimmersitze
	# entspricht. Dadurch sitzen Patienten nur auf tatsächlich vorhandenen Stühlen.
	for z in [-5.0, -3.0]:
		for i in range(4 if z == -5.0 else 3):
			if Vector2(punkt.x, punkt.z).distance_squared_to(Vector2(-8.5 + i * 1.2, z)) < 0.01:
				return true
	return false

func _sitzpose_anwenden() -> void:
	# Beugt die vier relevanten Beinknochen, damit die Idle-Figur eine Sitzhaltung
	# einnimmt. Die gespeicherte Grundrotation wird dabei als Ausgangspunkt genutzt.
	# Oberschenkel nach vorne, Unterschenkel wieder zum Boden.
	for knochen_name in ["ufsvxn", "pqqdkc", "arj5mw", "tmf7uk"]:
		var knochen := skelett.find_bone(knochen_name)
		if knochen < 0 or not bein_grundpose.has(knochen):
			continue
		var winkel := 80.0 if knochen_name in ["ufsvxn", "pqqdkc"] else -85.0
		skelett.set_bone_pose_rotation(knochen, Quaternion(Vector3.RIGHT, deg_to_rad(winkel)) * bein_grundpose[knochen])

func zuruecksetzen() -> void:
	# Setzt den Patienten vollständig in den neutralen Wartezustand zurück:
	# stehende Körperposition, Standardausrichtung, ursprüngliche Knochenposen
	# und die Animation Warten.
	bewegt_sich = false
	sitzt = false
	rotation.y = 0.0
	(animation.get_parent() as Node3D).position.y = 0.0
	skelett.reset_bone_poses()
	animation.play("Warten")
	animation.seek(0.0, true)
