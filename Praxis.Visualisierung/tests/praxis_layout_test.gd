extends SceneTree
const LAYOUT = preload("res://PraxisLayout.gd")
var fehler := 0

func pruefe(wahr: bool, text: String) -> void:
	if wahr:
		print("OK: " + text)
	else:
		push_error(text)
		fehler += 1

func _initialize() -> void:
	var layout = LAYOUT.new()
	var ladefehler: String = layout.laden()
	pruefe(ladefehler.is_empty(), "Praxislayout wird automatisch aus JSON geladen")
	pruefe(layout.anzahl("Arzt") >= 1 and layout.anzahl("Schwester") >= 1 and layout.anzahl("Rezeption") >= 1, "Pflichtraumtypen sind vorhanden")
	var aerzte_vorher: int = layout.anzahl("Arzt")
	var raum: Dictionary = layout.hinzufuegen("Arzt", Vector2(1.26, 2.74))
	pruefe(float(raum["x"]) == 1.5 and float(raum["z"]) == 2.5, "Neue Räume rasten auf 0,5 Meter ein")
	pruefe(layout.anzahl("Arzt") == aerzte_vorher + 1, "Raumanzahl wird als SimSharp-Kapazität ableitbar")
	var index: int = layout.raeume.size() - 1
	layout.verschieben(index, Vector2(-2.24, 3.26))
	pruefe(float(layout.raeume[index]["x"]) == -2.0 and float(layout.raeume[index]["z"]) == 3.5, "Räume lassen sich auf dem Raster verschieben")
	pruefe(layout.flaeche("Arzt") > 0.0, "Raumfläche wird für die SimSharp-Konfiguration berechnet")
	layout.entfernen(index)
	pruefe(layout.anzahl("Arzt") == aerzte_vorher, "Räume lassen sich entfernen")
	print("PRAXIS-LAYOUT: ", "BESTANDEN" if fehler == 0 else "FEHLGESCHLAGEN")
	quit(1 if fehler else 0)
