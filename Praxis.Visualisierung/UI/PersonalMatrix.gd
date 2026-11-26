extends ConfirmationDialog
## Offline-Personalfenster. Eingaben sind Entwuerfe, bis ein neuer Lauf gestartet wird.

# Erst dieses Signal uebergibt den geprueften Entwurf an Main.gd.
# anzahlen sind Stammzahlen; die Kernkapazitaeten werden aus personen berechnet.
signal uebernehmen(anzahlen: Dictionary, personen: Array)

const VERWALTUNG = preload("res://Personal/PersonalVerwaltung.gd")
const STIL = preload("res://UI/OberflaechenStil.gd")
const BEZEICHNUNGEN := {"Rezeption": "Rezeption", "Schwester": "Schwestern", "Arzt": "Ärzte"}
var felder: Dictionary = {}
var aktiv_labels: Dictionary = {}
var platz_labels: Dictionary = {}
var standardwerte: Dictionary = {}
var arbeitsplaetze: Array = []
var meldung: Label
# Lokale Kopie: Auswahlaenderungen beeinflussen den aktiven Simulationslauf noch nicht.
var personen: Array = []
var vorlagen: Array = []
var rollen_felder: Dictionary = {}
var personen_tabelle: GridContainer
var einsatz_label: Label
var personen_fehler := ""

func _ready() -> void:
	title = "Personal – Offline"
	size = Vector2i(780, 710)
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
	theme = STIL.erstellen()
	STIL.primaer(get_ok_button())
	add_button("Standardwerte", false, "standard")
	custom_action.connect(_standardwerte_laden)
	var inhalt := VBoxContainer.new()
	inhalt.add_theme_constant_override("separation", 10)
	add_child(inhalt)
	var hinweis := Label.new()
	hinweis.text = "Personal nach Stammrolle einstellen und Einsatzrollen für den nächsten Lauf wählen.\nÜbernehmen verwirft den aktuellen Lauf und startet neu ab 08:00 Uhr."
	inhalt.add_child(hinweis)
	var tabelle := GridContainer.new()
	tabelle.columns = 4
	tabelle.add_theme_constant_override("h_separation", 24)
	tabelle.add_theme_constant_override("v_separation", 8)
	inhalt.add_child(tabelle)
	for text in ["Stammrolle", "Personen aktuell", "Personen neu", "Arbeitsplätze"]:
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
	var ueberschrift := Label.new()
	ueberschrift.text = "Einsatz je Person (für den gesamten neuen Lauf)"
	inhalt.add_child(ueberschrift)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 140
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inhalt.add_child(scroll)
	personen_tabelle = GridContainer.new()
	personen_tabelle.columns = 3
	personen_tabelle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	personen_tabelle.add_theme_constant_override("h_separation", 18)
	personen_tabelle.add_theme_constant_override("v_separation", 6)
	scroll.add_child(personen_tabelle)
	einsatz_label = Label.new()
	inhalt.add_child(einsatz_label)
	meldung = Label.new()
	meldung.custom_minimum_size = Vector2(700, 64)
	meldung.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meldung.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inhalt.add_child(meldung)
	var fuss := Label.new()
	fuss.text = "Mindestens eine Person je Einsatzrolle. Jede Person zählt genau einmal.\nÄnderungen gelten für diese Sitzung; keine automatischen Rollenwechsel.\nDie Simulationsdateien werden nicht gespeichert."
	inhalt.add_child(fuss)

## Bei jedem Oeffnen den aktiven Zustand kopieren. So sind zuvor abgebrochene Entwuerfe weg.
## aktuell/standard stammen aus dem Kern; Personen und Qualifikationen kommen aus Godot.
func vorbereiten(aktuell: Dictionary, standard: Dictionary, plaetze: Array, aktive_personen: Array = [], personal_vorlagen: Array = []) -> void:
	standardwerte = standard.duplicate()
	arbeitsplaetze = plaetze
	vorlagen = personal_vorlagen.duplicate(true)
	personen = aktive_personen.duplicate(true)
	# Eine Schwester an der Rezeption bleibt im oberen Zahlenfeld eine eingestellte
	# Schwester. Ihre Rezeptionskapazitaet steht erst in der Anzeige "Neuer Lauf".
	var stammzahlen: Dictionary = VERWALTUNG.personen_zahlen(personen, "stammrolle") if not personen.is_empty() else aktuell
	for rolle in VERWALTUNG.ROLLEN:
		aktiv_labels[rolle].text = str(stammzahlen[rolle])
		felder[rolle].max_value = maxf(100, float(stammzahlen[rolle]))
		felder[rolle].set_value_no_signal(int(stammzahlen[rolle]))
		var anzahl := 0
		for platz in plaetze:
			if platz.get("qualifikation", "") == rolle:
				anzahl += 1
		platz_labels[rolle].text = str(anzahl) + " vorhanden"
	_personen_aktualisieren()

func _eingabe_geaendert(_wert: float) -> void:
	_personen_aktualisieren()

## Nach einer Aenderung der Zahlenfelder die Personenliste neu aufbauen.
## Bereits gewaehlte Einsaetze bleiben erhalten. Vorlagen bestimmen die Qualifikationen
## und Startrollen der neu eingestellten Personen, etwa die flexible zweite Schwester.
func _personen_aktualisieren() -> void:
	var entwurf: Dictionary = VERWALTUNG.personen_erstellen(eingaben(), vorlagen, personen)
	personen_fehler = String(entwurf["fehler"])
	if personen_fehler.is_empty():
		personen = entwurf["personen"]
	for kind in personen_tabelle.get_children():
		personen_tabelle.remove_child(kind)
		kind.queue_free()
	rollen_felder.clear()
	for text in ["Person", "Qualifikationen", "Einsatzrolle"]:
		var kopf := Label.new()
		kopf.text = text
		personen_tabelle.add_child(kopf)
	for person in personen:
		var name_label := Label.new()
		name_label.text = String(person["id"])
		personen_tabelle.add_child(name_label)
		var qualifikationen := Label.new()
		qualifikationen.text = ", ".join(person["qualifikationen"])
		personen_tabelle.add_child(qualifikationen)
		var auswahl := OptionButton.new()
		# Die Liste enthaelt ausschliesslich Qualifikationen dieser konkreten Person.
		# Personen mit nur einer Qualifikation erhalten keine umschaltbare Auswahl.
		for rolle in person["qualifikationen"]:
			auswahl.add_item(String(rolle))
			auswahl.set_item_metadata(auswahl.item_count - 1, rolle)
			if rolle == person["einsatzrolle"]:
				auswahl.select(auswahl.item_count - 1)
		auswahl.disabled = auswahl.item_count == 1
		auswahl.item_selected.connect(_rolle_waehlen.bind(String(person["id"])))
		personen_tabelle.add_child(auswahl)
		rollen_felder[person["id"]] = auswahl
	_pruefen()

## Aendert nur den Entwurf und prueft danach erneut Mindestbesetzung und Arbeitsplatzbedarf.
func _rolle_waehlen(index: int, personal_id: String) -> void:
	var auswahl: OptionButton = rollen_felder[personal_id]
	for person in personen:
		if person["id"] == personal_id:
			person["einsatzrolle"] = String(auswahl.get_item_metadata(index))
	_pruefen()

## Eine tiefe Kopie verhindert, dass Empfaenger versehentlich den Fensterentwurf veraendern.
func personen_eingaben() -> Array:
	return personen.duplicate(true)

## Liefert eingestellte Personen nach Stammrolle, noch keine Einsatzkapazitaeten fuer den Kern.
func eingaben() -> Dictionary:
	var zahlen := {}
	for rolle in VERWALTUNG.ROLLEN:
		zahlen[rolle] = int(felder[rolle].value)
	return zahlen

## Zeigt die resultierenden Einsatzzahlen und sperrt ungueltige Entwuerfe vor dem Uebernehmen.
func _pruefen() -> bool:
	var plan: Dictionary = VERWALTUNG.personen_planen(personen, arbeitsplaetze)
	var fehlertext := personen_fehler if not personen_fehler.is_empty() else String(plan["fehler"])
	var zahlen: Dictionary = VERWALTUNG.personen_zahlen(personen)
	einsatz_label.text = "Neuer Lauf: %d Rezeption · %d Schwestern · %d Ärzte" % [zahlen["Rezeption"], zahlen["Schwester"], zahlen["Arzt"]]
	# Alternativen nur anbieten, wenn nach dem Wechsel alle Einsatzrollen und Plaetze passen.
	for person_index in personen.size():
		var person: Dictionary = personen[person_index]
		var auswahl: OptionButton = rollen_felder[person["id"]]
		for index in auswahl.item_count:
			if index == auswahl.selected:
				auswahl.set_item_disabled(index, false)
				continue
			var kandidat: Array = personen.duplicate(true)
			# Jede Alternative probeweise auf einer Kopie planen. Dadurch laesst sich
			# ein unzulaessiger Wechsel deaktivieren, ohne Personen tatsaechlich umzusetzen.
			kandidat[person_index]["einsatzrolle"] = String(auswahl.get_item_metadata(index))
			var wechsel: Dictionary = VERWALTUNG.personen_planen(kandidat, arbeitsplaetze)
			auswahl.set_item_disabled(index, not String(wechsel["fehler"]).is_empty())
		auswahl.tooltip_text = "Nur qualifizierte Einsätze mit freiem Arbeitsplatz und mindestens einer Person je Einsatzrolle."
	get_ok_button().disabled = not fehlertext.is_empty()
	if fehlertext.is_empty():
		meldung.text = "Die Einsatzrollen passen zu den vorhandenen Arbeitsplätzen.\nWirksam erst mit Übernehmen & neu starten."
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
	# Standardrollen aus personal.json statt Rollen des aktiven Laufs verwenden.
	personen = []
	_personen_aktualisieren()

## Auch beim Klick erneut pruefen. Erst Main.gd wendet die Zahlen an und startet neu.
func _uebernehmen() -> void:
	if _pruefen():
		uebernehmen.emit(eingaben(), personen_eingaben())
