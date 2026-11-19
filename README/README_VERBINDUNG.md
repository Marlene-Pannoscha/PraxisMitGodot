# Verbindung zwischen Simulationskonfiguration und Godot

Die Simulation bestimmt Ankunftszeiten, Behandlungen und Ressourcenbelegung.
Godot stellt die daraus entstehenden Patientenereignisse dar. Sichtbare
Personalfiguren, Raeume und Arbeitsplaetze werden derzeit separat konfiguriert.
Eine automatische Uebernahme der Personal- und Raumanzahl in die Darstellung
ist noch nicht implementiert.

## Welche Datei muss ändern?

Die Simulationsdateien liegen im [Ressourcenordner](../simSharpSimulation/simSharpSimulation/Ressourcen/).

| Gewuenschte Aenderung | Datei und JSON-Einstellung | Auswirkung in Godot |
| --- | --- | --- |
| Patientenankuenfte | [patienten-konfiguration.json](../simSharpSimulation/simSharpSimulation/Ressourcen/patienten-konfiguration.json): `ZwischenankunftErste2StundenMinuten`, `ZwischenankunftNaechste3StundenMinuten`, `ZwischenankunftLetzte3StundenMinuten` | Die daraus entstehenden Klinikeintritte werden automatisch als Patientenfiguren dargestellt. |
| Anzahl Rezeptionskraefte | [rezeption-konfiguration.json](../simSharpSimulation/simSharpSimulation/Ressourcen/rezeption-konfiguration.json): `AnzahlRezeptionisten` | Aendert die Simulationskapazitaet. Sichtbare Figuren und Arbeitsplaetze separat anpassen. |
| Anzahl Aerzte | [arzt-konfiguration.json](../simSharpSimulation/simSharpSimulation/Ressourcen/arzt-konfiguration.json): `AnzahlAerzte` | Aendert den Arztpool der Simulation. Sichtbare Figuren und Arbeitsplaetze separat anpassen. |
| Anzahl Schwestern | [schwester-konfiguration.json](../simSharpSimulation/simSharpSimulation/Ressourcen/schwester-konfiguration.json): `AnzahlSchwestern` | Aendert den Schwesterpool der Simulation. Sichtbare Figuren und Arbeitsplaetze separat anpassen. |
| Simulierte Behandlungsraeume | [finanz-konfiguration.json](../simSharpSimulation/simSharpSimulation/Ressourcen/finanz-konfiguration.json): unter `Fixkosten` die Werte `AnzahlBehandlungsraeumeArzt` und `AnzahlBehandlungsraeumeSchwester` | Begrenzt auch in der Patientensimulation die gleichzeitig nutzbaren Behandlungsraeume; erzeugt keine sichtbaren Raeume. |
| Simulationsdauer und Bewegungszeiten | [simulation-konfiguration.json](../simSharpSimulation/simSharpSimulation/Ressourcen/simulation-konfiguration.json) | Die Ereigniszeitpunkte und Bewegungsdauern steuern die Darstellung. |

Beispiel: In der Patientenkonfiguration bedeutet
`"ZwischenankunftErste2StundenMinuten": 3.0`, dass in den ersten zwei Stunden
im Mittel alle drei Simulationsminuten eine Ankunft erzeugt wird. Die einzelnen
Abstaende sind zufaellig und muessen groesser als null konfiguriert sein.
Aufnahmestopp und Aufnahmeprognose koennen Patienten abweisen; nicht jede
generierte Ankunft fuehrt deshalb zu einer sichtbaren Figur innerhalb der Praxis.

## Wo ist die Verbindung im Code?

Fuer den standardmaessigen Offline-Modus gilt diese Kette:

1. [OfflineSimulationBridge.cs](../Praxis.Visualisierung/Anbindung/OfflineSimulationBridge.cs)
   ruft beim `Laden()` ueber [OriginalSimulation.cs](../Praxis.Visualisierung/Anbindung/OriginalSimulation.cs)
   die Methode `KonfigurationJsonExport.LadeAlle()` des Originalkerns auf.
2. [KonfigurationJsonExport.cs](../simSharpSimulation/simSharpSimulation/Ressourcen/KonfigurationJsonExport.cs)
   liest die JSON-Dateien und setzt unter anderem die Werte der
   [PatientenKonfiguration.cs](../simSharpSimulation/simSharpSimulation/Ressourcen/PatientenKonfiguration.cs).
3. [PatientenGenerator.cs](../simSharpSimulation/simSharpSimulation/Prozess/PatientenGenerator.cs)
   berechnet aus den Ankunftsabstaenden zufaellige Ankunftszeiten fuer drei
   Tagesphasen und startet die zugelassenen Patientenprozesse.
4. [PatientenProzess.PatientenAblauf.cs](../simSharpSimulation/simSharpSimulation/Prozess/PatientenProzess/PatientenProzess.PatientenAblauf.cs)
   meldet den Eintritt mit `daten.LogEvent(..., "betritt_klinik", patientId)`.
   [SimulationsDaten.cs](../simSharpSimulation/simSharpSimulation/SimulationsDaten.cs)
   veroeffentlicht diese und weitere Meldungen ueber `LiveEventOccurred`.
5. [OriginalSimulation.cs](../Praxis.Visualisierung/Anbindung/OriginalSimulation.cs)
   verbindet das Ereignis mit `OfflineSimulationBridge.EreignisEmpfangen`.
   Die Bridge wandelt es in ein Godot-Dictionary um und sendet das Signal
   `EreignisAufgetreten` mit Patient-ID, Zeitpunkt, Ereignistyp und Bewegungsdauer.
6. [Main.gd](../Praxis.Visualisierung/Main.gd) verbindet das Signal mit
   `_simulation_ereignis()`. Der Handler uebergibt die Meldung an
   [PatientenTimeline.gd](../Praxis.Visualisierung/Patienten/PatientenTimeline.gd),
   die daraus den raeumlichen Verlauf des Patienten erstellt.
7. [Main.gd](../Praxis.Visualisierung/Main.gd) erzeugt in `_aktualisiere_patienten()` fuer jede sichtbare Patient-ID
   einen Node mit [Patient.gd](../Praxis.Visualisierung/Patienten/Patient.gd).
   Dieses Skript laedt das 3D-Modell und aktualisiert Position und Pose.
   Nach dem Austritt wird die Figur entfernt.

Der Offline-Modus fuehrt den Kern direkt im Godot-Prozess aus. Ein Vorlauf dient
der Bestimmung der Bewegungsdauern und dem Vergleich der Ereignisfolge; die
Darstellung erhaelt die Meldungen erst beim Fortschalten des eigentlichen Laufs.
Im optionalen WebSocket-Modus laeuft die Simulation im Serverprozess;
[SimulationBridge.cs](../Praxis.Visualisierung/Anbindung/SimulationBridge.cs)
empfaengt dessen Meldungen und gibt sie ebenfalls als Godot-Signale weiter.

## Welche Dateien steuern die sichtbaren Raeume und Personalfiguren?

[KonfigurationLader.gd](../Praxis.Visualisierung/Konfiguration/KonfigurationLader.gd)
liest ausschliesslich die [Godot-Konfiguration](../Praxis.Visualisierung/Konfiguration/).
Er liest die Simulations-JSONs nicht und aendert keine Simulationskapazitaeten.

- [personal.json](../Praxis.Visualisierung/Konfiguration/personal.json) definiert
  sichtbare Personen mit ID, Qualifikationen und Modell.
- [besetzung.json](../Praxis.Visualisierung/Konfiguration/besetzung.json) ordnet
  diese Personen den Arbeitsplaetzen zu.
- [layout.json](../Praxis.Visualisierung/Konfiguration/Praxislayout/layout.json)
  listet die sichtbaren Raeume auf. Die [Raumdateien](../Praxis.Visualisierung/Konfiguration/Praxislayout/Raeume/)
  enthalten unter anderem Geometrie, Arbeitsplaetze und Ausstattung.
  Beispielsweise liegen die Rezeptionsarbeitsplaetze in
  [rezeption.json](../Praxis.Visualisierung/Konfiguration/Praxislayout/Raeume/rezeption.json).
- [PersonalVerwaltung.gd](../Praxis.Visualisierung/Personal/PersonalVerwaltung.gd)
  erzeugt die Figuren aus den geprueften Zuordnungen des Laders.

Beispiel: `AnzahlRezeptionisten` von 1 auf 2 zu erhoehen erlaubt zwei gleichzeitige
Bearbeitungen in der Simulation. Fuer zwei sichtbare Rezeptionsfiguren muessen
zusaetzlich eine zweite Person, ein zweiter Arbeitsplatz und deren Zuordnung in
den genannten Godot-Dateien angelegt werden. Zusaetzliche sichtbare Figuren
allein erhoehen umgekehrt die Simulationskapazitaet nicht.

Die Patientenpositionierung in [PatientenTimeline.gd](../Praxis.Visualisierung/Patienten/PatientenTimeline.gd)
und die Wege in [RaumWege.gd](../Praxis.Visualisierung/Raum3D/RaumWege.gd)
enthalten weiterhin feste Regeln. Bei neuen Raeumen oder Arbeitsplaetzen muessen
diese Regeln ebenfalls angepasst werden; eine neue JSON-Zeile reicht fuer eine
vollstaendige raeumliche Erweiterung nicht aus.

## Wann werden Aenderungen wirksam?

Nach Aenderungen an den Simulations-JSONs die laufende Anwendung schliessen,
[Schritt 2 (Build)](./README_AUSFUEHRUNG.md#schritt-2-projekt-bauen) wiederholen und Godot neu starten. Fuer WebSocket zusaetzlich
den Server neu bauen und neu starten.
Das [Core-Projekt](../simSharpSimulation/PraxisSimulation.Core/PraxisSimulation.Core.csproj)
kopiert die Quell-JSONs beim Build in den Ausgabeordner. Der Konfigurationslader
des Kerns bevorzugt dort den Unterordner `Ressourcen`; die Dateien im Ausgabeordner
sollten deshalb nicht als zweite Konfigurationsquelle gepflegt werden.

Es gibt kein automatisches Nachladen waehrend des laufenden Offline-Modus.
Auch **Reset** startet mit den bereits geladenen Werten. Aenderungen an den
Godot-Darstellungsdateien werden fuer einen verlaesslichen Neuaufbau ebenfalls
durch Neustart der Anwendung uebernommen.
