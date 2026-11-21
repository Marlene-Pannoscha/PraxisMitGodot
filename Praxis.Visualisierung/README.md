# Praxis.Visualisierung

Godot-3D-Darstellung der bestehenden SimSharp-Arztpraxis. Der Offline-Modus
fuehrt den Originalkern direkt aus; der WebSocket-Modus bleibt separat.

## Start

Das Godot-Projekt liegt in diesem Ordner. Hauptszene ist `Main.tscn`.

- Start/Pause und Reset steuern den aktuellen Simulationsmodus.
- Der Geschwindigkeitsregler steuert die gemeinsame Simulationsuhr.
- Rechte Maustaste dreht die Kamera, das Mausrad zoomt.
- `Personal einstellen` bearbeitet nur Personalzahlen des Offline-Laufs.
- `Baumodus` bietet eine visuelle Bauoberfläche für Raumtyp, Name, Position,
  Breite und Tiefe auf einem 0,5-m-Raster.

## Eine deklarative Layoutquelle

Der Benutzer beschreibt die vollstaendige Praxis in
[praxis-layout.json](./praxis-layout.json). Godot liest bei jedem Start genau
diese Datei, validiert sie und erzeugt daraus:

- Boden, Raeume und Farben
- Waende und Tueroeffnungen
- Warteplaetze und Stuehle
- Tische, Liegen und frei beschriebene Box-Moebel
- Arbeitsplaetze und Patientenpositionen
- Statusleuchten und Beschriftungen
- Stations-IDs fuer die Patientendarstellung

Grundrisspunkte sind `[x, z]`, 3D-Punkte `[x, y, z]`; alle Werte sind Meter.
Ein neues Moebel wird beispielsweise nur als Eintrag unter `ausstattung`
angelegt und ueber `raum_id` sowie die ID-Liste des Raumes zugeordnet.

Es gibt keine zweite oder versteckte Layoutkopie unter `user://`. Der Baumodus
bearbeitet dieselbe `praxis-layout.json`, speichert das vollstaendige Dokument
dort und laedt die Szene danach neu. Manuelle Aenderungen an der JSON werden
beim naechsten Start unmittelbar sichtbar; GDScript muss dafuer nicht angepasst
werden.

Die Datei muss nicht in einem externen Editor geöffnet werden. `Baumodus`
öffnet ein Konfigurationsfenster nach dem Vorbild der Personalverwaltung. Dort
wählt der Benutzer einen Raum aus und ändert Name, Position der Raummitte,
Breite und Tiefe über verständlich beschriftete Eingabefelder. Negative
Positionswerte bedeuten links beziehungsweise hinten, positive Werte rechts
beziehungsweise vorne. Räume lassen sich außerdem nach Typ hinzufügen
oder entfernen. Die 3D-Praxis wird während der Eingabe als Vorschau aktualisiert;
`Übernehmen & neu aufbauen` speichert den Entwurf dauerhaft. `Abbrechen` verwirft
ihn.

`Layout zurücksetzen` stellt nach einer Ja/Nein-Sicherheitsabfrage die
unveränderliche Vorlage `praxis-layout-standard.json` wieder her. Nach der
Bestätigung wird sie als aktive `praxis-layout.json` gespeichert und die
komplette Visualisierung neu geladen. Dabei gehen alle individuellen
Layoutänderungen verloren.

Ein im Baumodus neu angelegter Raum erhält automatisch vier Außenwände. Beim
Verschieben oder Ändern von Breite und Tiefe werden seine Wände neu berechnet;
beim Entfernen des Raums werden sie ebenfalls entfernt.

Zusätzlich erhält jeder neue Raum eine Tür zum Flur. Arzt-, Schwester- und
Rezeptionsräume bekommen einen passenden Arbeitsplatz, eine Patientenposition
und einen konfigurierten Zugangsweg von der Tür zum Arbeitsplatz. Tür,
Arbeitsplatz und Wegpunkte folgen späteren Positions- und Größenänderungen. Neu
zugewiesenes Personal läuft beim Aufbau über diese Wegpunkte an seinen Platz.

## Interaktiver 2D-Grundriss

Der Baumodus zeigt die Praxis zusätzlich als Draufsicht mit 0,5-m-Raster:

- Raum anklicken und per Drag-and-drop verschieben
- ausgewählten Raum an jedem der vier Eckpunkte vergrößern oder verkleinern
- Raumtyp wählen, `+ Raum platzieren` anklicken und den Raum im Grundriss setzen
- alle gültigen Änderungen unmittelbar in der 3D-Praxis sehen

Eine Änderung wird nur angenommen, wenn der Raum innerhalb des Praxisbodens
liegt, keinen anderen Raum überschneidet und mit einer ausreichend langen Kante
an den Flur oder einen bereits erreichbaren Raum grenzt. Ein geometrisch freier,
aber isolierter Platz wird mit einer verständlichen Meldung abgelehnt. Die Tür
wird automatisch an der ermittelten Anschlussseite angeordnet.

Die Kapazität passt sich an die Raumfläche an. Wartezimmer erzeugen ungefähr
einen Warteplatz samt sichtbarem Stuhl je 5,8 m². Arztzimmer erhalten ungefähr
einen Arbeitsplatz je 30 m², Schwester- und Rezeptionsräume einen je 20 m².
Beim Verkleinern werden überzählige Plätze entfernt, beim Vergrößern neue Plätze
erzeugt und innerhalb des Raums verteilt. Die Personalanzahl bleibt davon
unabhängig und wird weiterhin separat konfiguriert.

Beim Platzieren kann neben `Rechteck` auch `L-Form` gewählt werden. Eine L-Form
wird als Polygon mit sechs Außenkanten gespeichert. 2D-Grundriss, 3D-Boden,
Wände, Türzuordnung und Kapazitätsberechnung verwenden die tatsächliche
Polygonform. Breite und Tiefe skalieren die komplette Form proportional;
Drag-and-drop verschiebt sie als zusammenhängenden Raum.

Im Godot-Projekt ist dies `Praxis.Visualisierung/praxis-layout.json`. Bei einer
exportierten Anwendung legt der Benutzer `praxis-layout.json` neben die EXE;
diese externe Datei wird beim Start geladen und vom Baumodus gespeichert.

Details zum Schema stehen in
[Konfiguration/Praxislayout/README.md](./Konfiguration/Praxislayout/README.md).

## Personal und Raumkapazitaet

[personal.json](./Konfiguration/personal.json) und
[besetzung.json](./Konfiguration/besetzung.json) bleiben eigenstaendig.
Arbeitsplaetze im Layout beschreiben nur Position und Qualifikation. Die Zahl
der Personen kommt weiterhin aus SimSharp beziehungsweise dem Personalfenster.
Deshalb kann es mehr Arbeitsplaetze als aktive Personen geben.

Die Anzahl der Arzt- und Schwesternraeume sowie deren Flaechen werden vor dem
Offline-Lauf an die bestehende SimSharp-Konfiguration uebergeben. Dabei werden
keine Personalzahlen ueberschrieben.

## Architektur

| Bereich | Datei |
| --- | --- |
| Laden, Speichern, Validieren, Baumodus-Daten | [PraxisLayout.gd](./PraxisLayout.gd) |
| Gemeinsamer Konfigurationszugang | [KonfigurationLader.gd](./Konfiguration/KonfigurationLader.gd) |
| 3D-Aufbau | [Praxis.gd](./Raum3D/Praxis.gd), [Raum.gd](./Raum3D/Raum.gd) |
| ID- und Referenzpruefung | [RaumLayout.gd](./Raum3D/RaumLayout.gd) |
| Deklarative Moebeltypen | [Ausstattung.gd](./Raum3D/Ausstattung/Ausstattung.gd) |
| Patientenpositionen | [PatientenTimeline.gd](./Patienten/PatientenTimeline.gd) |
| Personalplanung | [PersonalVerwaltung.gd](./Personal/PersonalVerwaltung.gd) |
| SimSharp-Anbindung | [Anbindung/](./Anbindung/) |
| Automatisierte Pruefungen | [tests/](./tests/) |

Die Behandlungspositionen werden bereits ueber Arbeitsplatz-IDs aufgeloest.
Die vorhandene Weggeometrie in `RaumWege.gd` bleibt fuer Kompatibilitaet noch
bestehen und kann schrittweise durch eine vollstaendig ID-basierte Navigation
ersetzt werden.
