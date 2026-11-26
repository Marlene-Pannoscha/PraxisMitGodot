extends ConfirmationDialog
## Offline-Personalfenster. Eingaben sind Entwuerfe, bis ein neuer Lauf gestartet wird.

signal uebernehmen(anzahlen: Dictionary, rollenwechsel: bool)

const VERWALTUNG = preload("res://Personal/PersonalVerwaltung.gd")
const BEZEICHNUNGEN := {"Rezeption": "Rezeption", "Schwester": "Schwestern", "Arzt": "Ärzte"}
var felder: Dictionary = {}
var aktiv_labels: Dictionary = {}
var platz_labels: Dictionary = {}
var standardwerte: Dictionary = {}
var arbeitsplaetze: Array = []
var meldung: Label
var wechsel_option: CheckBox
var wechsel_regeln: Dictionary = {}
var wechsel_standard: Dictionary = {}

func _ready() -> void:
	title = "Personal – Offline"
	size = Vector2i(650, 550)
	min_size = size
	exclusive = true
	transient = true
	get_ok_button().text = "Übernehmen & neu starten"
	get_cancel_button().text = "Abbrechen"
	dialog_hide_on_ok = false
	confirmed.connect(_uebernehmen)
	canceled.connect(hide)
	close_requested.connect(hide)
	# Helle Oberflaeche passend zum Hauptfenster; die Zahlenfelder behalten ihre Eingaberahmen.
	theme = Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", Color("#20394c"))
	theme.set_color("font_color", "CheckBox", Color("#20394c"))
	theme.set_color("font_hover_color", "CheckBox", Color("#20394c"))
	theme.set_color("font_pressed_color", "CheckBox", Color("#20394c"))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#f4f7fa")
	panel.set_content_margin_all(18)
	theme.set_stylebox("panel", "AcceptDialog", panel)
	add_button("Standardwerte", false, "standard")
	custom_action.connect(_standardwerte_laden)
	var inhalt := VBoxContainer.new()
	inhalt.add_theme_constant_override("separation", 16)
	add_child(inhalt)
	var hinweis := Label.new()
	hinweis.text = "Anzahlen für den nächsten Lauf einstellen.\nBeim Übernehmen wird der aktuelle Lauf verworfen.\nDer neue Lauf startet ab 08:00 Uhr."
	inhalt.add_child(hinweis)
	var tabelle := GridContainer.new()
	tabelle.columns = 4
	tabelle.add_theme_constant_override("h_separation", 24)
	tabelle.add_theme_constant_override("v_separation", 12)
	inhalt.add_child(tabelle)
	for text in ["Rolle", "Aktiver Lauf", "Neuer Lauf", "Arbeitsplätze"]:
		var kopf := Label.new()
		kopf.text = text
		tabelle.add_child(kopf)
	for rolle in VERWALTUNG.ROLLEN:
		var name_label := Label.new()
		name_label.text = BEZEICHNUNGEN[rolle]
		name_label.custom_minimum_size.x = 130
		tabelle.add_child(name_label)
		var aktiv := Label.new()
		tabelle.add_child(aktiv)
		aktiv_labels[rolle] = aktiv
		var feld := SpinBox.new()
		feld.min_value = 1
		feld.max_value = 100
		feld.step = 1
		feld.custom_minimum_size.x = 110
		feld.update_on_text_changed = true
		feld.value_changed.connect(_eingabe_geaendert)
		tabelle.add_child(feld)
		felder[rolle] = feld
		var platz := Label.new()
		tabelle.add_child(platz)
		platz_labels[rolle] = platz
	wechsel_option = CheckBox.new()
	wechsel_option.text = "Schwester 2 hilft bei Bedarf an der Rezeption"
	wechsel_option.toggled.connect(func(_aktiv: bool): _pruefen())
	inhalt.add_child(wechsel_option)
	meldung = Label.new()
	meldung.custom_minimum_size = Vector2(580, 54)
	inhalt.add_child(meldung)
	var fuss := Label.new()
	fuss.text = "Mindestens eine Person je Rolle. Änderungen gelten nur in Godot.\nRäume und Ausstattung bleiben bestehen.\nDie Simulationsdateien werden nicht gespeichert."
	inhalt.add_child(fuss)

func vorbereiten(aktuell: Dictionary, standard: Dictionary, plaetze: Array, regeln: Dictionary = {}, standard_regeln: Dictionary = {}) -> void:
	standardwerte = standard.duplicate()
	wechsel_regeln = regeln.duplicate()
	wechsel_standard = standard_regeln.duplicate()
	wechsel_option.set_pressed_no_signal(bool(regeln.get("aktiv", false)))
	wechsel_option.text = "Schwester %d hilft bei Bedarf an der Rezeption" % int(regeln.get("schwesterId", 2))
	arbeitsplaetze = plaetze
	for rolle in VERWALTUNG.ROLLEN:
		aktiv_labels[rolle].text = str(aktuell[rolle])
		felder[rolle].max_value = maxf(100, float(aktuell[rolle]))
		felder[rolle].set_value_no_signal(int(aktuell[rolle]))
		var anzahl := 0
		for platz in plaetze:
			if platz.get("qualifikation", "") == rolle:
				anzahl += 1
		platz_labels[rolle].text = str(anzahl) + " vorhanden"
	_pruefen()

func _eingabe_geaendert(_wert: float) -> void:
	_pruefen()

func eingaben() -> Dictionary:
	var zahlen := {}
	for rolle in VERWALTUNG.ROLLEN:
		zahlen[rolle] = int(felder[rolle].value)
	return zahlen

func _pruefen() -> bool:
	var regeln := wechsel_regeln.duplicate()
	regeln["aktiv"] = wechsel_option.button_pressed
	var plan: Dictionary = VERWALTUNG.planen(eingaben(), arbeitsplaetze, {}, regeln)
	var fehlertext := String(plan["fehler"])
	get_ok_button().disabled = not fehlertext.is_empty()
	if fehlertext.is_empty():
		meldung.text = "Die Besetzung passt zu den vorhandenen Arbeitsplätzen.\nWirksam erst mit Übernehmen & neu starten."
		meldung.add_theme_color_override("font_color", Color("#245f3e"))
	else:
		fehler_anzeigen(fehlertext)
	return fehlertext.is_empty()

func fehler_anzeigen(text: String) -> void:
	meldung.text = text.replace(", aber", ",\naber").replace(". Bitte", ".\nBitte")
	meldung.add_theme_color_override("font_color", Color("#a12626"))

func _standardwerte_laden(aktion: StringName) -> void:
	if aktion != &"standard":
		return
	for rolle in VERWALTUNG.ROLLEN:
		felder[rolle].set_value_no_signal(int(standardwerte[rolle]))
	wechsel_option.set_pressed_no_signal(bool(wechsel_standard.get("aktiv", false)))
	_pruefen()

func _uebernehmen() -> void:
	if _pruefen():
		uebernehmen.emit(eingaben(), wechsel_option.button_pressed)
