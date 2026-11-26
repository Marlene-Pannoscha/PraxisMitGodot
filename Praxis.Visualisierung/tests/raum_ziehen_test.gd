extends SceneTree
## Prueft echte Mausereignisse an Seiten-/Eckgriffen ohne das Nutzerlayout zu speichern.

const LAYOUT = preload("res://PraxisLayout.gd")
const BAU_FENSTER = preload("res://UI/Baukonfiguration.gd")
var fehler := 0
var fenster
var editor
var index := -1

func _initialize() -> void:
	call_deferred("testen")

func pruefe(bedingung: bool, text: String) -> void:
	if bedingung:
		print("OK: ", text)
	else:
		push_error(text)
		fehler += 1

func maus(punkt: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = punkt
	editor._gui_input(event)

func taste(punkt: Vector2, gedrueckt: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = gedrueckt
	event.position = punkt
	editor._gui_input(event)

func rect() -> Rect2:
	return editor._raum_bildschirm_rect(index)

func welt_rect() -> Rect2:
	return fenster.entwurf._raum_rechteck(index)

func testen() -> void:
	var quellhash := FileAccess.get_sha256("res://praxis-layout.json")
	var modell = LAYOUT.new()
	pruefe(modell.aus_json_text(modell.standard_json_text()).is_empty(), "Standardvorlage geladen")
	modell.baumodus_vorbereiten()
	index = modell._raum_index("Schwester")
	modell.groesse_setzen(index, Vector2(4, 4))
	modell.verschieben(index, Vector2(6, 4))
	fenster = BAU_FENSTER.new()
	root.gui_embed_subwindows = true
	root.add_child(fenster)
	await process_frame
	pruefe(fenster.vorbereiten(modell.als_json_text()).is_empty(), "Baumodus mit frei skalierbarem Schwesterraum geladen")
	fenster.popup_centered()
	await process_frame
	fenster.raum_auswahl.select(index)
	fenster._raum_gewaehlt(index)
	editor = fenster.grundriss
	var massstab: float = editor._massstab()
	var flurwand: float = welt_rect().position.y

	# Der Klick liegt ausserhalb des Raumrechtecks, aber auf der aeusseren Haelfte des Griffs.
	var rechts := Vector2(rect().end.x + 6, rect().get_center().y)
	pruefe(editor._raum_an_bildschirmposition(rechts) < 0, "Testklick liegt tatsaechlich ausserhalb des Raums")
	maus(rechts)
	pruefe(editor.mouse_default_cursor_shape == Control.CURSOR_HSIZE, "Seitengriff zeigt den Mauszeiger fuer Breite")
	taste(rechts, true)
	pruefe(editor.drag_modus == "groesse" and editor.drag_ecke == Vector2(1, 0), "Aeussere Griffhaelfte startet die Breitenaenderung")
	maus(rechts + Vector2(0.1, 0) * massstab)
	pruefe(fenster.entwurf.groesse(index) == Vector2(4, 4), "Kleine Mausbewegung verursacht keinen Rastersprung")
	maus(rechts + Vector2(0.5, 0) * massstab)
	pruefe(fenster.entwurf.groesse(index) == Vector2(4.5, 4), "Seitliches Ziehen aendert nur die Breite um 0,5 m")
	pruefe(is_equal_approx(welt_rect().position.x, 4.0), "Gegenueberliegende linke Wand bleibt exakt fest")
	pruefe(is_equal_approx(fenster.entwurf.position(index).x, 6.25), "Viertelmeter-Mitte wird nicht nochmals aufs Raster verschoben")
	pruefe(is_equal_approx(fenster.breite_feld.value, 4.5) and is_equal_approx(fenster.x_feld.value, 6.25), "Zahlenfelder zeigen dieselbe Groesse und Mitte wie die Mausvorschau")
	taste(rechts, false)

	var unten := Vector2(rect().get_center().x, rect().end.y + 6)
	maus(unten)
	pruefe(editor.mouse_default_cursor_shape == Control.CURSOR_VSIZE, "Unterer Griff zeigt den Mauszeiger fuer Tiefe")
	taste(unten, true)
	maus(unten + Vector2(0, 0.5) * massstab)
	pruefe(fenster.entwurf.groesse(index) == Vector2(4.5, 4.5), "Unterer Griff aendert nur die Tiefe")
	pruefe(is_equal_approx(welt_rect().position.y, flurwand) and fenster.entwurf.hat_direkten_fluranschluss(index), "Flurwand und Tuer bleiben bei Tiefeaenderung erhalten")
	taste(unten, false)

	var ecke := rect().end + Vector2(4, 4)
	taste(ecke, true)
	pruefe(editor.drag_ecke == Vector2(1, 1), "Eckgriff erlaubt weiterhin beide Achsen")
	maus(ecke + Vector2(0.5, 0.5) * massstab)
	pruefe(fenster.entwurf.groesse(index) == Vector2(5, 5), "Eckgriff vergroessert Breite und Tiefe gemeinsam")
	pruefe(welt_rect().position.is_equal_approx(Vector2(4, flurwand)), "Beim Eckziehen bleibt die gegenueberliegende Ecke fest")
	taste(ecke, false)

	var flur_ecke := Vector2(rect().end.x, rect().position.y)
	taste(flur_ecke, true)
	pruefe(editor.drag_ecke == Vector2(1, 0), "Eckgriff an der Flurwand aendert nur die seitliche Ausdehnung")
	maus(flur_ecke + Vector2(0.5, 0.5) * massstab)
	pruefe(fenster.entwurf.groesse(index) == Vector2(5.5, 5) and is_equal_approx(welt_rect().position.y, flurwand), "Ziehen am Flur-Eckgriff loest die Tuerwand nicht ab")
	taste(flur_ecke, false)

	# Ungueltige Zwischenpositionen duerfen den gueltigen Entwurf nicht beschaedigen.
	unten = Vector2(rect().get_center().x, rect().end.y + 4)
	var vorher: String = fenster.entwurf.als_json_text()
	taste(unten, true)
	maus(unten + Vector2(0, 0.5) * massstab)
	pruefe(not editor.drag_gueltig and fenster.entwurf.als_json_text() == vorher, "Ziehen ueber den Praxisrand zeigt Rot und behaelt den letzten gueltigen Stand")
	maus(unten)
	pruefe(editor.drag_gueltig, "Zurueckziehen auf den letzten gueltigen Stand loescht die rote Vorschau")
	taste(unten, false)

	var links := Vector2(rect().position.x - 4, rect().get_center().y)
	vorher = fenster.entwurf.als_json_text()
	taste(links, true)
	maus(links + Vector2(-6, 0) * massstab)
	pruefe(not editor.drag_gueltig and fenster.entwurf.als_json_text() == vorher, "Breite darf nicht in die bestehende Rezeption hineinragen")
	taste(links, false)

	# Raumbewegungen bleiben auch nach einer Groessenaenderung in relativen 0,5-m-Schritten stabil.
	var mitte := rect().get_center()
	var alte_position: Vector2 = fenster.entwurf.position(index)
	taste(mitte, true)
	pruefe(editor.drag_modus == "verschieben", "Raummitte startet weiterhin das Verschieben")
	maus(mitte + Vector2(0.5, 0) * massstab)
	pruefe(fenster.entwurf.position(index).is_equal_approx(alte_position + Vector2(0.5, 0)), "Raum mit Viertelmeter-Mitte verschiebt sich ohne zusaetzlichen Rastersprung")
	taste(mitte, false)
	pruefe(fenster._pruefen(), "Nach allen Mausaktionen bleibt der Entwurf gueltig")

	# Oberhalb des Flurs ist die obere Wand frei. Auch alte Masse wie 6,3 m bleiben stabil.
	index = fenster.entwurf._raum_index("Arzt1")
	fenster.raum_auswahl.select(index)
	fenster._raum_gewaehlt(index)
	var obere_tiefe: float = fenster.entwurf.groesse(index).y
	var untere_kante: float = welt_rect().end.y
	var oben := Vector2(rect().get_center().x, rect().position.y - 4)
	taste(oben, true)
	pruefe(editor.drag_ecke == Vector2(0, -1), "Im Arztzimmer oberhalb des Flurs kann die freie obere Wand gezogen werden")
	maus(oben + Vector2(0, 0.5) * massstab)
	pruefe(is_equal_approx(fenster.entwurf.groesse(index).y, obere_tiefe - 0.5), "Auch nicht-gerasterte Bestandsmasse aendern sich um genau 0,5 m")
	pruefe(is_equal_approx(welt_rect().end.y, untere_kante) and fenster.entwurf.hat_direkten_fluranschluss(index), "Untere Flurwand im Arztzimmer bleibt beim Ziehen fest")
	taste(oben, false)
	pruefe(fenster._pruefen(), "Beide Flurseiten bleiben nach dem Skalieren gueltig")
	fenster.queue_free()
	await process_frame
	pruefe(FileAccess.get_sha256("res://praxis-layout.json") == quellhash, "Nutzerlayout unveraendert")
	print("RAUM-ZIEHEN: ", "BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN")
	quit(1 if fehler > 0 else 0)
