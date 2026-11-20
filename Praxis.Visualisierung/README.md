# Visualisierung: Projektstruktur

Das Projekt ist nach Aufgaben geordnet. Es wurden die vorhandenen Informationen
aufgeteilt. Im Offline-Modus werden die Personalzahlen jetzt automatisch aus
der geladenen Simulation uebernommen. Je zwei Rezeptions- und Schwesterarbeitsplaetze
sind im Layout vorbereitet; die Simulation bestimmt, wie viele davon besetzt werden.
Die bisherige Wegberechnung und Patientenplatzvergabe bleiben erhalten.

| Bereich | Einstieg und Aufgabe |
| --- | --- |
| Start | [Main.tscn](./Main.tscn), [Main.gd](./Main.gd): verbindet die Bereiche |
| Konfiguration | [KonfigurationLader.gd](./Konfiguration/KonfigurationLader.gd): setzt die aufgeteilten Dateien zusammen |
| Personal | [Personal.gd](./Personal/Personal.gd): einzelne Figur; [PersonalVerwaltung.gd](./Personal/PersonalVerwaltung.gd): Personalzahlen auf Layout-Arbeitsplaetze verteilen |
| Patienten | [Patient.gd](./Patienten/Patient.gd): Figur und Pose; [PatientenTimeline.gd](./Patienten/PatientenTimeline.gd): Verlauf der Originalereignisse |
| Raeume | [Praxis.gd](./Raum3D/Praxis.gd): vorhandener Boden und Waende; [Raum.gd](./Raum3D/Raum.gd): Raum mit ID, Position, Groesse und Platz-/Tuerverweisen |
| Raumdaten | [RaumLayout.gd](./Raum3D/RaumLayout.gd): ordnet vorhandene Daten nach IDs und prueft Verweise |
| Raumwege | [RaumWege.gd](./Raum3D/RaumWege.gd): bisherige Raumgrenzen und Wegberechnung |
| Ausstattung | [Ausstattung.gd](./Raum3D/Ausstattung/Ausstattung.gd): bestehende Moebeltypen; Standorte stehen in den Raumdateien |
| Bedienung | [Steuerung.gd](./UI/Steuerung.gd): Steuerung und Personalbutton; [PersonalMatrix.gd](./UI/PersonalMatrix.gd): Offline-Personalfenster mit Platzpruefung und Neustart |
| Simulation | [Anbindung/](./Anbindung/): bestehende C#-Anbindung |
| Modelle | [Personal/Modelle/](./Personal/Modelle/), [Patienten/Modelle/](./Patienten/Modelle/): Modelle, Texturen und Importe |
| Weitere Assets | [assets/](./assets/), [ClinicBackground.tscn](./ClinicBackground.tscn): vorhandene Grafikpakete und bisheriger Hintergrund |
| Pruefungen | [tests/](./tests/): Godot-Tests; [Tests/](../Tests/README.md): C#-Pruefung, Originaldateivergleich und Nachweise |

## Konfiguration lesen

```text
Konfiguration/
├── personal.json
├── besetzung.json
├── KonfigurationLader.gd
└── Praxislayout/
    ├── layout.json
    ├── tueren.json
    ├── waende.json
    ├── navigation.json
    └── Raeume/
        ├── wartezimmer.json
        ├── arzt1.json
        ├── arzt2.json
        ├── rezeption.json
        ├── schwester.json
        └── flur.json
```

- [personal.json](./Konfiguration/personal.json) und [besetzung.json](./Konfiguration/besetzung.json): bisherige feste Besetzung fuer den WebSocket-Modus. Offline kommen Anzahl und Rollen aus dem geladenen Simulationskern.
- [layout.json](./Konfiguration/Praxislayout/layout.json): Dateiliste, Gesamtboden und Wandmasse.
- [Raeume/](./Konfiguration/Praxislayout/Raeume/): eine Datei je vorhandenem Raum; enthaelt ID, Position, Groesse, Tuerverweise, eigene Arbeits- und Warteplaetze sowie vorhandene Ausstattung, Beschriftung und Statusleuchten.
- [tueren.json](./Konfiguration/Praxislayout/tueren.json): sechs vorhandene Oeffnungen mit Position, Breite und verbundenen Raum-IDs. `Draussen` ist die Aussenseite des Eingangs.
- [waende.json](./Konfiguration/Praxislayout/waende.json): vorhandene Wandabschnitte und deren Tueroeffnungen.
- [navigation.json](./Konfiguration/Praxislayout/navigation.json): bisherige Stationspositionen und die Eingangsbeschriftung; keine neue Navigation.

Die grosse bisherige Layoutdatei wurde durch diese Dateien ersetzt. Der Lader
fuehrt sie intern zur bisherigen Datenstruktur zusammen. Die Raumzuordnung eines
Arbeits- oder Warteplatzes ergibt sich aus seiner Raumdatei; sie muss dort nicht
zusaetzlich als `raum_id` wiederholt werden.

Koordinaten bleiben **absolut** und in Metern: `[x, z]` fuer Stationen und Plaetze,
`[x, y, z]` fuer Boden und Moebel. `groesse` bedeutet Breite, Bodendicke und Tiefe.
`winkel_grad` wird beim Laden in Radiant umgerechnet. Es sind dieselben Masse,
Farben und Modelle wie zuvor hinterlegt; je ein zweiter Rezeptions- und Schwesterplatz ist vorbereitet.

Die Verbindung zur Simulation und die automatische Figurenanzahl sind in
[README_VERBINDUNG.md](../README/README_VERBINDUNG.md) erklaert. Bei mehr Personal
als passenden Arbeitsplaetzen wird der Offline-Start mit einer Fehlermeldung gesperrt.
Ueber **Personal einstellen** lassen sich die Zahlen fuer neue Offline-Laeufe
im Arbeitsspeicher aendern. Der Dialog zeigt aktive Zahlen und vorhandene Plaetze;
die JSON-Dateien der verknuepften Simulation werden dabei nicht veraendert.

## Grenzen dieser Umstrukturierung

Die vorhandene Wegberechnung, Raumgrenzen und Behandlungsplatzvergabe bleiben im
Code. Es gibt keine automatische Navigation durch neue Raumverbindungen,
keinen dynamischen Rollenwechsel und keinen Raumeditor. Fuer mehr Raeume
werden diese Funktionen erst spaeter erweitert. Ein neuer Eintrag allein
erweitert auch nicht die Kapazitaet des originalen SimSharp-Kerns.

Der unbenutzte Ordner mit den alten Unarmed-FBX-Animationen wurde nach einer
Referenzpruefung entfernt. Die verwendeten Gobkit-Modelle bleiben erhalten.

## Ausfuehren und pruefen

Startbefehle: [README_AUSFUEHRUNG.md](../README/README_AUSFUEHRUNG.md).
Die Hauptszene bleibt am bisherigen Ort. Modelle und Skript-UIDs sind erhalten.
Die fokussierten Godot-Tests liegen im [Testordner](./tests/).
Die gemeinsame Uebersicht aller Pruefungen und der derzeit ungenutzten
Ressourcen steht in [Tests/README.md](../Tests/README.md).

Bereits vor dieser Aufteilung reproduzierbar: Der Raumtest meldet zwei
Abweichungen zur Patientenkoerperhoehe. Die Figurenskalierung wurde im Rahmen
der Strukturierung nicht veraendert.
