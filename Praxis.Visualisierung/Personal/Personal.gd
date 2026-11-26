extends Node3D
## Sichtbares Personal am Arbeitsplatz; der SimSharp-Kern liefert keine Personalwege.

const MODELLE := {
	"Rezeption": preload("res://Personal/Modelle/Receptionist.glb"),
	"Schwester": preload("res://Personal/Modelle/WardNurse.glb"),
	"Arzt": preload("res://Personal/Modelle/WhiteCoatDoctor.glb")
}
const FIGUR_GROESSE := 15.0

# Einsatzrolle: Aufgabe und passender Arbeitsplatz fuer diesen Simulationslauf.
var rolle := ""
# Aussehen bleibt unabhaengig davon: Eine Schwester an der Rezeption bleibt sichtbar Schwester.
var modell := ""
# Stabile Identitaet der Person; wird bei einem neuen Einsatz nicht umbenannt.
var personal_id := ""
# Verweist auf den konkreten Platz im Layout, z.B. rezeption_2 oder schwester_1.
var arbeitsplatz_id := ""
var animation: AnimationPlayer
var wegpunkte: Array = []
var weg_index := 0
const LAUFGESCHWINDIGKEIT := 2.0

func _ready() -> void:
	# PersonalVerwaltung setzt das Modell vor add_child(). Aeltere Aufrufer, die nur
	# eine Rolle uebergeben, verwenden weiterhin deren bisheriges Standardmodell.
	var figur_modell := (MODELLE[modell if not modell.is_empty() else rolle] as PackedScene).instantiate() as Node3D
	figur_modell.scale = Vector3.ONE * FIGUR_GROESSE
	add_child(figur_modell)
	animation = figur_modell.find_child("AnimationPlayer", true, false) as AnimationPlayer
	# Main.gd gibt die vergangene Simulationszeit weiter; eine Pause haelt so auch die Pose an.
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var warten := animation.get_animation("Idle").duplicate() as Animation
	warten.loop_mode = Animation.LOOP_LINEAR
	# Die Animation darf die Figur nicht vom konfigurierten Arbeitsplatz wegschieben.
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
		# Der manuelle Arbeitsplatzwechsel erfolgt beim Neuaufbau der Figur direkt
		# zum neuen Einsatzplatz. Es gibt dabei keinen Laufweg zwischen den Stationen.
		# Personal muss auch vor Simulationsstart sichtbar am Arbeitsplatz stehen.
		# Der erste Wegpunkt liegt ausserhalb der Tuer und wuerde bei pausierter
		# Simulationsuhr sonst dauerhaft im Flur bleiben.
		var arbeitsplatz: Array = wegpunkte[-1]
		position = Vector3(float(arbeitsplatz[0]), 0.06, float(arbeitsplatz[1]))
		weg_index = wegpunkte.size()

## Aktualisiert die Darstellung. Hier werden weder Qualifikationen noch Rollen ausgewaehlt.
## Die Wegpunktbewegung ist eine Darstellungsfunktion, keine automatische Einsatzplanung.
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
