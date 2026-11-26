# Verbindung zwischen Simulationskonfiguration und Godot

Die Simulation bestimmt Ankunftszeiten, Behandlungen und Ressourcenbelegung.
Godot stellt die daraus entstehenden Patientenereignisse dar. Im Offline-Modus
uebernimmt Godot jetzt auch die geladenen Personalzahlen fuer Rezeption, Schwester
und Arzt. Raeume, Arbeitsplaetze und deren Positionen bleiben im Godot-Layout.
Im Offline-Personalfenster werden Personen nach Stammrolle eingestellt und ihre
Einsatzrollen fuer den gesamten naechsten Lauf manuell gewaehlt. Mehrere
Qualifikationen sind moeglich; eine Person wird immer nur einmal eingesetzt.
Die daraus berechneten Einsatzkapazitaeten werden ueber die vorhandene
C#-Anbindung gesetzt, ohne die Kernlogik oder Simulations-JSONs zu aendern.
Automatische Rollenwechsel waehrend des Tages sind nicht Bestandteil dieser Funktion.

## Welche Datei muss ändern?

Die Simulationsdateien liegen im [Ressourcenordner](../simSharpSimulation/simSharpSimulation/Ressourcen/).

| Gewuenschte Aenderung | Datei und JSON-Einstellung | Auswirkung in Godot |
| --- | --- | --- |
| Patientenankuenfte | [patienten-konfiguration.json](../simSharpSimulation/simSharpSimulation/Ressourcen/patienten-konfiguration.json): `ZwischenankunftErste2StundenMinuten`, `ZwischenankunftNaechste3StundenMinuten`, `ZwischenankunftLetzte3StundenMinuten` | Die daraus entstehenden Klinikeintritte werden automatisch als Patientenfiguren dargestellt. |
| Anzahl Rezeptionskraefte | [rezeption-konfiguration.json](../simSharpSimulation/simSharpSimulation/Ressourcen/rezeption-konfiguration.json): `AnzahlRezeptionisten` | Offline automatisch entsprechend viele Figuren; zwei passende Arbeitsplaetze sind vorbereitet. |
| Anzahl Aerzte | [arzt-konfiguration.json](../simSharpSimulation/simSharpSimulation/Ressourcen/arzt-konfiguration.json): `AnzahlAerzte` | Offline automatisch entsprechend viele Figuren, sofern genug passende Arbeitsplaetze existieren; derzeit zwei. |
| Anzahl Schwestern | [schwester-konfiguration.json](../simSharpSimulation/simSharpSimulation/Ressourcen/schwester-konfiguration.json): `AnzahlSchwestern` | Offline automatisch entsprechend viele Figuren, sofern genug passende Arbeitsplaetze existieren; derzeit zwei. |
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
Die Personalzahlen werden stattdessen ueber die C#-Anbindung uebergeben.

- [personal.json](../Praxis.Visualisierung/Konfiguration/personal.json) beschreibt
  die Personen mit Qualifikationen, Stammrolle, voreingestellter Einsatzrolle und
  Modell. Ein Vorlageneintrag stellt keine Person ein; die Personenzahlen werden
  im Godot-Fenster eingestellt. Erste Schwester: nur Schwester. Ab zweiter Schwester:
  Schwester und Rezeption. Weitere Personen uebernehmen Qualifikationen und Modell
  der letzten Vorlage ihrer Stammrolle und starten in der Stammrolle.
  Eine optionale `besetzung.json` bleibt ausschliesslich fuer die explizite
  Arbeitsplatzzuordnung im WebSocket-Modus vorgesehen.
- [layout.json](../Praxis.Visualisierung/Konfiguration/Praxislayout/layout.json)
  listet die sichtbaren Raeume auf. Die [Raumdateien](../Praxis.Visualisierung/Konfiguration/Praxislayout/Raeume/)
  enthalten unter anderem Geometrie, Arbeitsplaetze und Ausstattung.
  Beispielsweise liegen die Rezeptionsarbeitsplaetze in
  [rezeption.json](../Praxis.Visualisierung/Konfiguration/Praxislayout/Raeume/rezeption.json).
- [PersonalVerwaltung.gd](../Praxis.Visualisierung/Personal/PersonalVerwaltung.gd)
  prueft im Offline-Modus mit `personen_planen()` Qualifikationen, Mindestbesetzung
  und freie passende Arbeitsplaetze. `erstellen()` erzeugt Figuren mit eindeutiger
  Personal-ID und Arbeitsplatz-ID. Das Modell bleibt unabhaengig von der Einsatzrolle.

### Schritt 1: Personalzahlen automatisch uebernehmen

1. [OriginalSimulation.cs](../Praxis.Visualisierung/Anbindung/OriginalSimulation.cs)
   liest mit `PersonalzahlenLesen()` die Werte der bereits geladenen
   `RezeptionKonfiguration`, `SchwesterKonfiguration` und `ArztKonfiguration`.
   Die Visualisierung liest keine zweite Kopie der Quell-JSONs ein.
2. [OfflineSimulationBridge.cs](../Praxis.Visualisierung/Anbindung/OfflineSimulationBridge.cs)
   speichert diese Zahlen beim Laden als Momentaufnahme und gibt sie ueber
   `PersonalzahlenLesen()` als Godot-Dictionary zurueck.
3. [Main.gd](../Praxis.Visualisierung/Main.gd) baut das Personal erst nach
   erfolgreichem Laden der Simulation auf. Die ersten passenden Arbeitsplaetze
   in Layout-Reihenfolge werden belegt; ueberzaehlige Plaetze bleiben leer.
   Beim Moduswechsel werden alte Figuren entfernt. Reset behaelt dieselbe Besetzung.

Beispiel: Fuer zwei Rezeptionskraefte `"AnzahlRezeptionisten": 2` in der
[Rezeptionskonfiguration](../simSharpSimulation/simSharpSimulation/Ressourcen/rezeption-konfiguration.json)
setzen, neu bauen und die Anwendung im Offline-Modus neu starten. Die beiden
Arbeitsplaetze `rezeption_1` und `rezeption_2` sind in
[rezeption.json](../Praxis.Visualisierung/Konfiguration/Praxislayout/Raeume/rezeption.json)
vorbereitet. Ein zweiter Eintrag in den Godot-Personaldateien ist nicht notwendig.
Die Simulationskonfiguration selbst wurde fuer diese Erweiterung nicht veraendert.

Fehlen passende Arbeitsplaetze, wird der Start mit einer konkreten Meldung
gesperrt, beispielsweise: `Rezeption: 3 Personen aus der Simulation, aber nur 2
passende Arbeitsplaetze im Godot-Layout.` Es werden keine Figuren gestapelt und
keine unvollstaendige Besetzung erzeugt. Weitere Standorte muessen bewusst im
Layout angelegt werden. Das Erstellen eines Arbeitsplatzes erhoeht umgekehrt
nicht die Simulationskapazitaet.

**WebSocket:** Das bestehende Serverprotokoll uebertraegt noch keine Personalzahlen.
Dieser Modus verwendet deshalb weiterhin die feste Besetzung aus den Godot-Dateien.
Lokale Offline-Werte werden nicht als Serverkonfiguration ausgegeben.

### Personal im Godot-Fenster einstellen (Offline)

1. Im Offline-Modus oben **Personal einstellen** oeffnen.
2. Fuer Rezeption, Schwestern und Aerzte die Zahlen fuer den **neuen Lauf**
   einstellen. Die Spalten **Aktiver Lauf** und **Arbeitsplaetze** zeigen die
   bisherige Besetzung und die im Layout vorhandenen Plaetze.
3. **Uebernehmen & neu starten** waehlen. Der bisherige Lauf wird verworfen,
   die Figuren werden neu aufgebaut und ein neuer Lauf beginnt bei 08:00 Uhr.

Die Eingaben sind bis zur Uebernahme nur ein Entwurf, auch wenn waehrenddessen
eine Behandlung laeuft. **Abbrechen** verwirft die Eingaben. **Standardwerte**
laedt die beim Start aus den JSON-Dateien gelesenen Zahlen in die Eingabefelder;
erst Uebernehmen macht sie wieder aktiv. **Reset** verwendet dagegen die zuletzt
uebernommenen Zahlen und startet diese Besetzung erneut, zunaechst pausiert.

Der aktuelle Kern benoetigt mindestens eine Person je Rolle. Das Fenster bietet
deshalb ganzzahlige Werte ab 1. Das Layout hat aktuell zwei Rezeptionsplaetze,
zwei Schwesterplaetze und zwei Arztplaetze. Bei zu vielen Personen erscheint
eine Platzmeldung und Uebernehmen ist gesperrt. Der bisherige Lauf bleibt erhalten.
Ein dritter Arzt benoetigt zunaechst einen weiteren passenden Darstellungsplatz;
das Fenster erstellt keine Raeume oder Moebel.

[PersonalMatrix.gd](../Praxis.Visualisierung/UI/PersonalMatrix.gd) baut das Fenster
auf und prueft die Eingaben mit der bestehenden Personalplanung. Nach erfolgreicher
Platzpruefung ruft [Main.gd](../Praxis.Visualisierung/Main.gd) die Methode
`PersonalzahlenAnwenden()` der [OfflineSimulationBridge.cs](../Praxis.Visualisierung/Anbindung/OfflineSimulationBridge.cs)
auf. [OriginalSimulation.cs](../Praxis.Visualisierung/Anbindung/OriginalSimulation.cs)
setzt die Personalzahlen im Arbeitsspeicher des eingebundenen Kerns, wie das
bestehende WPF-Fenster. Die Bridge berechnet vor der Uebernahme einen neuen
Darstellungsplan fuer diese Besetzung. Erst nach erfolgreicher Vorbereitung
werden Uhr, Patientenverlauf und Personalfiguren gemeinsam ersetzt. Bei einem
Vorbereitungsfehler werden die bisherigen Kernwerte wiederhergestellt.

Das Personalfenster schreibt seine Eingaben nicht in JSON-Dateien. Ein Neustart der
Anwendung oder erneutes Laden des Offline-Modus liest wieder die Startkonfiguration.
Hat der Baumodus eine Besetzung im Godot-Layout gespeichert, wird diese inklusive
Personen-IDs und Einsatzrollen wiederhergestellt.
Weder Quellcode noch Konfigurationsdateien des per Junction eingebundenen
Simulationsprojekts muessen fuer dieses Fenster geaendert werden.
Im WebSocket-Modus ist **Personal einstellen** deaktiviert.

### Gewuenschte Besetzung: 1 Rezeptionskraft, 2 Schwestern, 2 Aerzte

Im Personalfenster fuer den neuen Lauf **Rezeption = 1**, **Schwestern = 2**
und **Aerzte = 2** einstellen und uebernehmen. In
[schwester.json](../Praxis.Visualisierung/Konfiguration/Praxislayout/Raeume/schwester.json)
sind zwei Arbeitsplaetze an den bestehenden Tischen vorbereitet.
Die JSON-Standardwerte der Hauptsimulation werden dadurch nicht geaendert.

Diese Zahlen beziehen sich jetzt auf Stammrollen. In der aktuellen
Personalkonfiguration bleibt `schwester_1` fest als Schwester eingesetzt.
Ab `schwester_2` sind die Personen zusaetzlich fuer die Rezeption qualifiziert.
Die zweite Schwester wird ausschliesslich
im Godot-Zahlenfeld eingestellt. Daraus ergeben sich fuer den Kern zwei Personen
an der Rezeption und eine Schwester. Fuer zwei Personen im Schwesternbereich
bei einer Rezeptionskraft muss die Einsatzrolle von `schwester_2` auf **Schwester**
gestellt werden. Der Rollenwechsel wird erst mit **Uebernehmen & neu starten** wirksam.
Die Bedienung ist in [README_AUSFUEHRUNG.md](./README_AUSFUEHRUNG.md#manuelle-einsatzrolle-schwester-an-der-rezeption)
beschrieben. Die Kern-Logikdateien werden fuer diese manuelle Verteilung nicht geaendert.

Die Patientenpositionierung in [PatientenTimeline.gd](../Praxis.Visualisierung/Patienten/PatientenTimeline.gd)
und die Wege in [RaumWege.gd](../Praxis.Visualisierung/Raum3D/RaumWege.gd)
enthalten weiterhin feste Regeln. Schritt 1 synchronisiert die Personalfiguren,
noch keine Zuordnung jedes Patienten zu einer konkreten Rezeptionskraft.
Bei neuen Raeumen oder Arbeitsplaetzen muessen
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

Es gibt kein automatisches Nachladen geaenderter JSON-Dateien waehrend des
laufenden Offline-Modus. Aenderungen ueber das Personalfenster benoetigen
dagegen keinen Build, sondern werden beim dortigen Neustart im Arbeitsspeicher
uebernommen. Auch **Reset** startet mit den zuletzt uebernommenen Werten. Aenderungen an den
Godot-Darstellungsdateien werden fuer einen verlaesslichen Neuaufbau ebenfalls
durch Neustart der Anwendung uebernommen.
