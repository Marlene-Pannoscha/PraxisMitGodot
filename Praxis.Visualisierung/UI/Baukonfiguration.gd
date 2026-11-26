extends ConfirmationDialog
## Formularbasierter Baumodus. Aenderungen bleiben bis zum Uebernehmen ein Entwurf.

signal vorschau(daten: Dictionary)
signal uebernehmen(json_text: String)
signal verworfen
signal zurueckgesetzt(json_text: String)

const PRAXIS_LAYOUT = preload("res://PraxisLayout.gd")
const INFO_TOOLTIP = preload("res://UI/InfoTooltip.gd")
const GRUNDRISS_EDITOR = preload("res://UI/GrundrissEditor.gd")
var entwurf = PRAXIS_LAYOUT.new()
var raum_auswahl: OptionButton
var neuer_typ: OptionButton
var neue_form: OptionButton
var name_feld: LineEdit
var x_feld: SpinBox
var z_feld: SpinBox
var breite_feld: SpinBox
var tiefe_feld: SpinBox
var meldung: Label
var wird_gesetzt := false
var ursprung_json := ""
var reset_abfrage: ConfirmationDialog
var grundriss

func _ready() -> void:
	title = "Praxis – Baumodus"
	size = Vector2i(1180, 720)
	min_size = Vector2i(900, 620)
	exclusive = true
	transient = true
	dialog_hide_on_ok = false
	get_ok_button().text = "Übernehmen & neu aufbauen"
	get_cancel_button().text = "Abbrechen"
	_button_gestalten(get_ok_button(), "primaer")
	_button_gestalten(get_cancel_button(), "neutral")
	confirmed.connect(_uebernehmen)
	canceled.connect(_abbrechen)
	close_requested.connect(_abbrechen)
	theme = Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", Color("#20394c"))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#f4f7fa")
	panel.set_content_margin_all(18)
	theme.set_stylebox("panel", "AcceptDialog", panel)

	var inhalt := VBoxContainer.new()
	inhalt.add_theme_constant_override("separation", 13)
	add_child(inhalt)
	var hinweis := Label.new()
	hinweis.text = "Räume im Grundriss auswählen, verschieben oder an den Eckpunkten skalieren.\nÄnderungen werden direkt als 3D-Vorschau angezeigt und erst beim Übernehmen gespeichert."
	inhalt.add_child(hinweis)
	var arbeitsbereich := HBoxContainer.new()
	arbeitsbereich.add_theme_constant_override("separation", 18)
	arbeitsbereich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inhalt.add_child(arbeitsbereich)
	grundriss = GRUNDRISS_EDITOR.new()
	grundriss.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grundriss.raum_ausgewaehlt.connect(_grundriss_auswahl)
	grundriss.geometrie_angefordert.connect(_grundriss_geometrie)
	grundriss.platzierung_angefordert.connect(_grundriss_platzierung)
	arbeitsbereich.add_child(grundriss)
	var eigenschaften := VBoxContainer.new()
	eigenschaften.custom_minimum_size.x = 470
	eigenschaften.add_theme_constant_override("separation", 10)
	arbeitsbereich.add_child(eigenschaften)

	var auswahl_zeile := HBoxContainer.new()
	eigenschaften.add_child(auswahl_zeile)
	var auswahl_label := Label.new()
	auswahl_label.text = "Raum"
	auswahl_label.custom_minimum_size.x = 145
	auswahl_zeile.add_child(auswahl_label)
	raum_auswahl = OptionButton.new()
	raum_auswahl.custom_minimum_size.x = 340
	raum_auswahl.item_selected.connect(_raum_gewaehlt)
	_auswahl_gestalten(raum_auswahl)
	auswahl_zeile.add_child(raum_auswahl)

	var tabelle := GridContainer.new()
	tabelle.columns = 2
	tabelle.add_theme_constant_override("h_separation", 28)
	tabelle.add_theme_constant_override("v_separation", 10)
	eigenschaften.add_child(tabelle)
	name_feld = _text_feld(tabelle, "Raumname")
	var links_rechts_hilfe := "Position der Raummitte\n\n• Negativer Wert: nach links\n• Positiver Wert: nach rechts"
	x_feld = _zahlen_feld(tabelle, "Mitte links / rechts", -30.0, 30.0, links_rechts_hilfe, 0.05, "x")
	x_feld.tooltip_text = links_rechts_hilfe
	var hinten_vorne_hilfe := "Position der Raummitte\n\n• Negativer Wert: nach hinten\n• Positiver Wert: nach vorne"
	z_feld = _zahlen_feld(tabelle, "Mitte hinten / vorne", -30.0, 30.0, hinten_vorne_hilfe, 0.05, "z")
	z_feld.tooltip_text = hinten_vorne_hilfe
	breite_feld = _zahlen_feld(tabelle, "Breite", 1.0, 30.0, "", 0.5, "breite")
	breite_feld.tooltip_text = "Gesamte Ausdehnung des Raums von links nach rechts."
	tiefe_feld = _zahlen_feld(tabelle, "Tiefe", 1.0, 30.0, "", 0.5, "tiefe")
	tiefe_feld.tooltip_text = "Gesamte Ausdehnung des Raums von hinten nach vorne."
	name_feld.text_changed.connect(_eigenschaft_geaendert)

	inhalt.add_child(HSeparator.new())
	var aktionen := HBoxContainer.new()
	aktionen.add_theme_constant_override("separation", 10)
	inhalt.add_child(aktionen)
	neuer_typ = OptionButton.new()
	neuer_typ.custom_minimum_size.x = 150
	for typ in PRAXIS_LAYOUT.EDITIERBARE_TYPEN:
		neuer_typ.add_item(typ)
	_auswahl_gestalten(neuer_typ)
	aktionen.add_child(neuer_typ)
	neue_form = OptionButton.new()
	neue_form.custom_minimum_size.x = 135
	neue_form.add_item("Rechteck")
	neue_form.add_item("L-Form")
	_auswahl_gestalten(neue_form)
	aktionen.add_child(neue_form)
	var neu := Button.new()
	neu.text = "+ Raum platzieren"
	neu.pressed.connect(_platzierung_starten)
	_button_gestalten(neu, "primaer")
	aktionen.add_child(neu)
	var entfernen := Button.new()
	entfernen.text = "Raum entfernen"
	entfernen.pressed.connect(_raum_entfernen)
	_button_gestalten(entfernen, "neutral")
	aktionen.add_child(entfernen)
	var zuruecksetzen := Button.new()
	zuruecksetzen.text = "Layout zurücksetzen"
	zuruecksetzen.tooltip_text = "Löscht alle Layoutänderungen und stellt das Standardlayout wieder her."
	zuruecksetzen.pressed.connect(_reset_bestaetigung_oeffnen)
	_button_gestalten(zuruecksetzen, "gefahr")
	aktionen.add_child(zuruecksetzen)

	meldung = Label.new()
	meldung.custom_minimum_size = Vector2(640, 58)
	meldung.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inhalt.add_child(meldung)
	var fuss := Label.new()
	fuss.text = "Die Position beschreibt die Raummitte. Negative Werte verschieben nach links/hinten, positive nach rechts/vorne.\nRaster: 0,5 m. Personalanzahl und Arbeitsplatzkapazität bleiben unabhängig."
	inhalt.add_child(fuss)

	reset_abfrage = ConfirmationDialog.new()
	reset_abfrage.title = "Layout wirklich zurücksetzen?"
	reset_abfrage.dialog_text = "Alle Änderungen am Layout werden gelöscht.\nMöchtest du wirklich das ursprüngliche Standardlayout wiederherstellen?"
	reset_abfrage.size = Vector2i(560, 230)
	reset_abfrage.min_size = reset_abfrage.size
	reset_abfrage.exclusive = true
	reset_abfrage.transient = true
	reset_abfrage.get_ok_button().text = "Ja, zurücksetzen"
	reset_abfrage.get_cancel_button().text = "Nein"
	_button_gestalten(reset_abfrage.get_ok_button(), "gefahr_primaer")
	_button_gestalten(reset_abfrage.get_cancel_button(), "neutral")
	reset_abfrage.confirmed.connect(_layout_zuruecksetzen)
	reset_abfrage.canceled.connect(reset_abfrage.hide)
	reset_abfrage.close_requested.connect(reset_abfrage.hide)
	add_child(reset_abfrage)

func vorbereiten(json_text: String, standard_json := "") -> String:
	ursprung_json = standard_json if not standard_json.is_empty() else json_text
	var fehler: String = entwurf.aus_json_text(json_text, "Baumodus")
	if not fehler.is_empty():
		return fehler
	entwurf.baumodus_vorbereiten()
	_raumliste_aktualisieren(0)
	grundriss.modell_setzen(entwurf)
	_pruefen()
	return ""

func _raumliste_aktualisieren(index: int) -> void:
	wird_gesetzt = true
	raum_auswahl.clear()
	for raum in entwurf.raeume:
		raum_auswahl.add_item("%s – %s" % [raum.get("name", raum["id"]), raum["typ"]])
	if not entwurf.raeume.is_empty():
		raum_auswahl.select(clampi(index, 0, entwurf.raeume.size() - 1))
	wird_gesetzt = false
	_raum_gewaehlt(raum_auswahl.selected)
	grundriss.auswahl_setzen(raum_auswahl.selected)

func _raum_gewaehlt(index: int) -> void:
	if wird_gesetzt or index < 0 or index >= entwurf.raeume.size():
		return
	wird_gesetzt = true
	var raum: Dictionary = entwurf.raeume[index]
	grundriss.auswahl_setzen(index)
	var position := entwurf.position(index)
	var groesse := entwurf.groesse(index)
	name_feld.text = String(raum.get("name", raum["id"]))
	x_feld.set_value_no_signal(position.x)
	z_feld.set_value_no_signal(position.y)
	breite_feld.set_value_no_signal(groesse.x)
	tiefe_feld.set_value_no_signal(groesse.y)
	wird_gesetzt = false

func _eigenschaft_geaendert(_wert = null) -> void:
	if wird_gesetzt or raum_auswahl.selected < 0:
		return
	var index := raum_auswahl.selected
	var neuer_name := name_feld.text.strip_edges()
	if not neuer_name.is_empty():
		entwurf.raeume[index]["name"] = neuer_name
		raum_auswahl.set_item_text(index, "%s – %s" % [neuer_name, entwurf.raeume[index]["typ"]])
	_pruefen()
	grundriss.modell_setzen(entwurf)
	vorschau.emit(entwurf.daten)

func _geometriefeld_geaendert(_wert: float, kennung: String) -> void:
	if wird_gesetzt or raum_auswahl.selected < 0:
		return
	var index := raum_auswahl.selected
	var bisherige_position := entwurf.position(index)
	var bisherige_groesse := entwurf.groesse(index)
	var ziel_position := bisherige_position
	var ziel_groesse := bisherige_groesse
	match kennung:
		"x": ziel_position.x = x_feld.value
		"z": ziel_position.y = z_feld.value
		"breite": ziel_groesse.x = breite_feld.value
		"tiefe": ziel_groesse.y = tiefe_feld.value
	# Bei einer reinen Groessenaenderung bleibt die Wand mit der Flurtuer fest.
	# So verliert der Raum durch eine neue Tiefe nicht seinen Fluranschluss.
	if ziel_position.is_equal_approx(bisherige_position) and not ziel_groesse.is_equal_approx(bisherige_groesse):
		ziel_position = entwurf.position_mit_fester_tuerkante(index, ziel_groesse)
	var fehler := entwurf.geometrie_setzen(index, ziel_position, ziel_groesse, false)
	if not fehler.is_empty():
		meldung.text = fehler
		meldung.add_theme_color_override("font_color", Color("#a12626"))
		_raum_gewaehlt(index)
		return
	_formular_geometrie_anzeigen(index)
	_pruefen()
	grundriss.modell_setzen(entwurf)
	vorschau.emit(entwurf.daten)

func _formular_geometrie_anzeigen(index: int) -> void:
	wird_gesetzt = true
	var aktuelle_position := entwurf.position(index)
	var aktuelle_groesse := entwurf.groesse(index)
	x_feld.set_value_no_signal(aktuelle_position.x)
	z_feld.set_value_no_signal(aktuelle_position.y)
	breite_feld.set_value_no_signal(aktuelle_groesse.x)
	tiefe_feld.set_value_no_signal(aktuelle_groesse.y)
	wird_gesetzt = false

func _platzierung_starten() -> void:
	grundriss.platzierung_starten(neuer_typ.get_item_text(neuer_typ.selected), neue_form.get_item_text(neue_form.selected))
	meldung.text = "Klicke im Grundriss auf eine freie Fläche mit einer gemeinsamen Wandkante direkt zum Flur."
	meldung.add_theme_color_override("font_color", Color("#174f75"))

func _grundriss_platzierung(typ: String, form: String, position: Vector2) -> void:
	var fehler := entwurf.platzierung_pruefen(position, Vector2(4, 4), -1, true, form)
	if not fehler.is_empty():
		meldung.text = fehler
		meldung.add_theme_color_override("font_color", Color("#a12626"))
		return
	entwurf.hinzufuegen(typ, position, form)
	grundriss.platzierung_beenden()
	_raumliste_aktualisieren(entwurf.raeume.size() - 1)
	grundriss.modell_setzen(entwurf)
	_pruefen()
	vorschau.emit(entwurf.daten)

func _grundriss_auswahl(index: int) -> void:
	if index < 0:
		return
	raum_auswahl.select(index)
	_raum_gewaehlt(index)

func _grundriss_geometrie(index: int, position: Vector2, groesse: Vector2) -> void:
	var ziel_position := Vector2(entwurf.raster(position.x), entwurf.raster(position.y))
	var ziel_groesse := Vector2(maxf(1.0, entwurf.raster(groesse.x)), maxf(1.0, entwurf.raster(groesse.y)))
	if entwurf.position(index).is_equal_approx(ziel_position) and entwurf.groesse(index).is_equal_approx(ziel_groesse):
		return
	var fehler := entwurf.geometrie_setzen(index, position, groesse)
	if not fehler.is_empty():
		meldung.text = fehler
		meldung.add_theme_color_override("font_color", Color("#a12626"))
		grundriss.geometrie_ergebnis(false)
		return
	grundriss.geometrie_ergebnis(true)
	_raum_gewaehlt(index)
	grundriss.modell_setzen(entwurf)
	_pruefen()
	vorschau.emit(entwurf.daten)

func _raum_entfernen() -> void:
	var index := raum_auswahl.selected
	if index < 0:
		return
	entwurf.entfernen(index)
	_raumliste_aktualisieren(maxi(0, index - 1))
	grundriss.modell_setzen(entwurf)
	_pruefen()
	vorschau.emit(entwurf.daten)

func _reset_bestaetigung_oeffnen() -> void:
	reset_abfrage.popup_centered()

func _layout_zuruecksetzen() -> void:
	var fehler: String = entwurf.aus_json_text(ursprung_json, "Gespeichertes Ursprungslayout")
	if not fehler.is_empty():
		meldung.text = fehler
		meldung.add_theme_color_override("font_color", Color("#a12626"))
		return
	entwurf.baumodus_vorbereiten()
	_raumliste_aktualisieren(0)
	grundriss.modell_setzen(entwurf)
	_pruefen()
	meldung.text = "Das ursprüngliche Standardlayout wurde wiederhergestellt."
	meldung.add_theme_color_override("font_color", Color("#245f3e"))
	vorschau.emit(entwurf.daten)
	zurueckgesetzt.emit(entwurf.als_json_text())

func _pruefen() -> bool:
	var fehler := entwurf.validieren()
	for raum_index in entwurf.raeume.size():
		var raum: Dictionary = entwurf.raeume[raum_index]
		if String(raum.get("typ", "")) != "Flur" and not entwurf.hat_direkten_fluranschluss(raum_index):
			fehler.append("%s braucht eine eigene Tür direkt zum Flur." % String(raum.get("name", raum.get("id", "Raum"))))
	for typ in PRAXIS_LAYOUT.EDITIERBARE_TYPEN:
		if entwurf.anzahl(typ) < 1:
			fehler.append("Mindestens ein Raum vom Typ %s ist erforderlich." % typ)
	get_ok_button().disabled = not fehler.is_empty()
	if fehler.is_empty():
		var kapazitaet_text := ""
		if raum_auswahl.selected >= 0 and raum_auswahl.selected < entwurf.raeume.size():
			var raum: Dictionary = entwurf.raeume[raum_auswahl.selected]
			if String(raum["typ"]) == "Wartezimmer":
				kapazitaet_text = " | %d Warteplätze mit Stühlen" % raum.get("warteplaetze", []).size()
			elif String(raum["typ"]) in ["Arzt", "Schwester", "Rezeption"]:
				kapazitaet_text = " | %d Arbeitsplätze" % raum.get("arbeitsplaetze", []).size()
		meldung.text = "%d Räume konfiguriert%s. Der Entwurf ist gültig." % [entwurf.raeume.size(), kapazitaet_text]
		meldung.add_theme_color_override("font_color", Color("#245f3e"))
	else:
		meldung.text = "\n".join(fehler.slice(0, 3))
		meldung.add_theme_color_override("font_color", Color("#a12626"))
	return fehler.is_empty()

func _uebernehmen() -> void:
	if _pruefen():
		uebernehmen.emit(entwurf.als_json_text())

func _abbrechen() -> void:
	verworfen.emit()
	hide()

func _text_feld(tabelle: GridContainer, text: String) -> LineEdit:
	var label := Label.new()
	label.text = text
	tabelle.add_child(label)
	var feld := LineEdit.new()
	feld.custom_minimum_size.x = 360
	feld.custom_minimum_size.y = 38
	_eingabe_gestalten(feld)
	tabelle.add_child(feld)
	return feld

func _zahlen_feld(tabelle: GridContainer, text: String, minimum: float, maximum: float, hilfe := "", schritt := 0.5, kennung := "") -> SpinBox:
	var beschriftung := HBoxContainer.new()
	beschriftung.add_theme_constant_override("separation", 5)
	var label := Label.new()
	label.text = text
	beschriftung.add_child(label)
	if not hilfe.is_empty():
		var info := INFO_TOOLTIP.new()
		info.erklaerung_setzen(hilfe)
		beschriftung.add_child(info)
	tabelle.add_child(beschriftung)
	var feld := SpinBox.new()
	feld.min_value = minimum
	feld.max_value = maximum
	feld.step = schritt
	feld.suffix = " m"
	# Nicht bei jedem Zeichen anwenden: Beim Ersetzen von "6,5" entsteht sonst
	# kurz ein leerer/ungueltiger Wert und das Formular springt sofort zurueck.
	feld.update_on_text_changed = false
	feld.value_changed.connect(_geometriefeld_geaendert.bind(kennung))
	feld.custom_minimum_size.y = 38
	var texteingabe := feld.get_line_edit()
	texteingabe.select_all_on_focus = true
	texteingabe.keep_editing_on_text_submit = true
	texteingabe.text_submitted.connect(func(_text): _zahlenwert_bestaetigt.call_deferred(kennung))
	texteingabe.placeholder_text = "Wert in Metern"
	_eingabe_gestalten(texteingabe)
	tabelle.add_child(feld)
	return feld

func _zahlenwert_bestaetigt(kennung := "tiefe") -> void:
	# SpinBox uebernimmt den Text beim Enter-Ereignis. Der verzögerte Aufruf liest
	# anschließend garantiert den neuen Zahlenwert statt des vorherigen Werts.
	var feld: SpinBox = {"x": x_feld, "z": z_feld, "breite": breite_feld, "tiefe": tiefe_feld}.get(kennung) as SpinBox
	if feld != null:
		_geometriefeld_geaendert(float(feld.value), kennung)

func _eingabe_gestalten(feld: LineEdit) -> void:
	feld.add_theme_color_override("font_color", Color("#18334a"))
	feld.add_theme_color_override("font_selected_color", Color.WHITE)
	feld.add_theme_color_override("selection_color", Color("#3978a8"))
	feld.add_theme_color_override("caret_color", Color("#18334a"))
	feld.add_theme_font_size_override("font_size", 17)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#ffffff")
	normal.border_color = Color("#8da6b8")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 7
	normal.content_margin_bottom = 7
	feld.add_theme_stylebox_override("normal", normal)
	var fokus := normal.duplicate() as StyleBoxFlat
	fokus.border_color = Color("#2674a6")
	fokus.set_border_width_all(2)
	feld.add_theme_stylebox_override("focus", fokus)
	feld.add_theme_stylebox_override("read_only", normal)

func _auswahl_gestalten(feld: OptionButton) -> void:
	feld.custom_minimum_size.y = 38
	feld.add_theme_color_override("font_color", Color("#18334a"))
	feld.add_theme_color_override("font_hover_color", Color("#102b3d"))
	feld.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#ffffff")
	normal.border_color = Color("#8da6b8")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	feld.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#edf5fa")
	hover.border_color = Color("#3978a8")
	feld.add_theme_stylebox_override("hover", hover)
	feld.add_theme_stylebox_override("pressed", hover)
	feld.add_theme_stylebox_override("focus", hover)

func _button_gestalten(button: Button, art: String) -> void:
	button.custom_minimum_size.y = 38
	button.add_theme_font_size_override("font_size", 15)
	var hintergrund := Color("#ffffff")
	var rahmen := Color("#8da6b8")
	var schrift := Color("#20394c")
	var hover_farbe := Color("#edf5fa")
	if art == "primaer":
		hintergrund = Color("#2f719d")
		rahmen = Color("#245c80")
		schrift = Color.WHITE
		hover_farbe = Color("#245f86")
	elif art == "gefahr":
		hintergrund = Color("#fff4f2")
		rahmen = Color("#c75b50")
		schrift = Color("#8f2525")
		hover_farbe = Color("#fbe3df")
	elif art == "gefahr_primaer":
		hintergrund = Color("#b42318")
		rahmen = Color("#861c14")
		schrift = Color.WHITE
		hover_farbe = Color("#8f1f17")
	button.add_theme_color_override("font_color", schrift)
	button.add_theme_color_override("font_hover_color", schrift)
	button.add_theme_color_override("font_pressed_color", schrift)
	var normal := StyleBoxFlat.new()
	normal.bg_color = hintergrund
	normal.border_color = rahmen
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = hover_farbe
	hover.border_color = rahmen.darkened(0.12)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
