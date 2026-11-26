# Deklaratives Praxislayout

Die einzige Layoutquelle ist [`../../praxis-layout.json`](../../praxis-layout.json).
Die frueheren Teil-JSONs wurden entfernt, damit Grundriss, Baumodus und
Simulation nicht aus verschiedenen Raumdaten lesen.

## Schema 2

- `boden`, `wandhoehe`, `wandstaerke`: globale 3D-Eigenschaften
- `raeume`: ID, Typ, Position, Groesse, Farbe und Verweise auf Rauminhalte
- `tueren`: verbundene Raum-IDs, Position und Breite
- `waende`: Anfang, Ende und Tuer-Oeffnungen
- `arbeitsplaetze`: Qualifikation, Personalposition und optionale Patientenposition
- `warteplaetze`: Sitzpositionen fuer Patienten
- `ausstattung`: `box`, `stuhl`, `tisch` oder `liege`
- `statusleuchten`: Raum-, Stations- und Arbeitsplatzbezug
- `stationen`: stabile IDs fuer die schrittweise Umstellung der Patientenwege
- `beschriftungen`: frei platzierbare 3D-Texte

Grundrisspositionen verwenden `[x, z]`, 3D-Positionen `[x, y, z]` und
Raumgroessen `[breite, bodendicke, tiefe]`. Alle Werte sind Meter.

Im Godot-Projekt wird ausschliesslich `res://praxis-layout.json` geladen. Bei
einem exportierten Programm ist die einzige Layoutquelle `praxis-layout.json`
direkt neben der ausfuehrbaren Datei. Sie ist jeweils die vom Benutzer gepflegte
Konfiguration und zugleich die Speicherdatei des Baumodus.

Ein Arbeitsplatz beschreibt einen moeglichen Platz und seine benoetigte
Qualifikation. Im Offline-Baumodus bekommt jeder neue Arzt-/Schwesternraum
beim Uebernehmen eine zusaetzliche Person direkt in diesem Raum. Die Anzahlen
und Arbeitsplatzzuordnungen werden unter `offline_personal` im Layout gespeichert.
Vergroessern allein erhoeht die Personalzahl nicht. Eine separate `besetzung.json`
ist offline nicht noetig und wurde entfernt; sie kann fuer den spaeteren
Server-Modus wieder angelegt werden.
