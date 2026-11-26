# Projekt ausführen

Diese Befehle gelten für Windows PowerShell und das Projekt unter
`C:\home\PraxisMitGodot`. Die Visualisierung benötigt **Godot 4.7.2 .NET/Mono**,
weil sie C#-Skripte für die SimSharp-Anbindung lädt. Die normale Godot-Version
ohne `.NET` bzw. `mono` im Dateinamen kann dieses Projekt nicht ausführen.

## Schritt 1: Voraussetzungen prüfen

Benötigt werden das .NET SDK 10 und diese Godot-Datei:

```powershell
dotnet --version
Test-Path "C:\Tools\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe"
```

`Test-Path` muss `True` ausgeben. Auf einem anderen Computer den Godot-Pfad in
den folgenden Befehlen anpassen. Die lokale Solution
`PraxisMitGodot.slnx` enthält `PraxisSimulation.Core`,
`Praxis.Visualisierung` und `Praxis.Visualisierung.Pruefung`. Der optionale
WebSocket-Server ist ein eigenes Projekt unter
`simSharpSimulation\PraxisSimulation.Server`.

Der Ordner `simSharpSimulation` ist hier ein Junction-Link. Falls er fehlt,
siehe [README_JUNCTION.md](./README_JUNCTION.md).

## Schritt 2: Projekt bauen

PowerShell öffnen und in den Projektordner wechseln:

```powershell
cd C:\home\PraxisMitGodot
dotnet build .\PraxisMitGodot.slnx -m:1
```

Warten, bis `Der Buildvorgang wurde erfolgreich ausgeführt` und `0 Fehler`
angezeigt werden.

## Schritt 3: Godot-.NET-Editor öffnen und offline spielen

Für den Offline-Modus **keinen Server starten**. Zuerst alle Fenster der
normalen Godot-Version schließen. Danach im selben PowerShell-Fenster den
.NET-Editor öffnen:

```powershell
& "C:\Tools\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe" --editor --path "C:\home\PraxisMitGodot\Praxis.Visualisierung"
```

1. Warten, bis Godot die 3D-Modelle importiert hat.
2. Im Editor **F5** drücken. Dadurch startet die Hauptszene `Main.tscn`.
3. Im Anwendungsfenster oben rechts **Offline (direkt in Godot)** auswählen.
4. Im Anwendungsfenster **Start** klicken.

## Schritt 4: Alternativ direkt spielen, ohne Editor

Nach Schritt 2 kann die Anwendung auch ohne Editor gestartet werden:

```powershell
& "C:\Tools\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe" --path "C:\home\PraxisMitGodot\Praxis.Visualisierung"
```

Danach im Anwendungsfenster **Start** klicken. Die VS-Code-Aufgabe **Terminal →
Aufgabe ausführen → Godot-Visualisierung offline starten** führt nur diesen
Startbefehl aus. Nach Codeänderungen zuerst Schritt 2 wiederholen.

## Schritt 5: Optional im WebSocket-Modus starten

Der Server und Godot laufen in getrennten Prozessen. Zuerst den Build oben
ausführen, dann in **PowerShell-Fenster 1** den Server starten:

```powershell
cd C:\home\PraxisMitGodot
dotnet run --project .\simSharpSimulation\PraxisSimulation.Server\PraxisSimulation.Server.csproj --urls http://localhost:5080
```

Dieses Fenster geöffnet lassen. Der Server kann mit
`Invoke-RestMethod http://localhost:5080/health` geprüft werden.

In **PowerShell-Fenster 2** den .NET-Editor öffnen:

```powershell
& "C:\Tools\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe" --editor --path "C:\home\PraxisMitGodot\Praxis.Visualisierung"
```

Im Editor **F5** drücken, im Anwendungsfenster oben rechts **WebSocket
(Server)** auswählen und **Start** klicken. Für den Offline-Modus ist dieser
Server nicht nötig.

## Schritt 6: Alternativ das gemeinsame Startskript verwenden

Das Skript baut das Godot-Projekt, importiert Assets und öffnet den
.NET-Editor. Standardmäßig verwendet es den Offline-Modus:

```powershell
cd C:\home\PraxisMitGodot
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Start-Visualisierung.ps1 -GodotPfad "C:\Tools\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe"
```

Für WebSocket denselben Aufruf mit `-Modus WebSocket` ergänzen. Das Skript
startet dann den Server, falls er noch nicht läuft, und beendet seinen selbst
gestarteten Server beim Schließen des Editors. In Godot anschließend den
passenden Modus auswählen und mit **F5** starten.

## Schritt 7: Tests ausführen

Die C#-Pruefung, Originaldateipruefung und gespeicherten Nachweise liegen unter
[Tests/](../Tests/README.md). Die Godot-Skripte bleiben im eigenen
[Godot-Testordner](../Praxis.Visualisierung/tests/).

Zuerst die Solution bauen. Der folgende Raumtest benötigt Godot **.NET/Mono**;
die normale Godot-Version kann `SimulationBridge.cs` nicht laden:

```powershell
cd C:\home\PraxisMitGodot
dotnet build .\PraxisMitGodot.slnx -m:1
& "C:\Tools\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe" --headless --path "C:\home\PraxisMitGodot\Praxis.Visualisierung" --script res://tests/raum3d_test.gd
```

Die fokussierten Tests für Timeline, Sitzpose und Personal verwenden denselben
Konsolenbefehl mit `res://tests/timeline_test.gd`,
`res://tests/patient_sitzen_test.gd` bzw. `res://tests/personal_test.gd` nach
`--script`.


## Zentrale Offline-Simulationsuhr

Im Offline-Modus ist `OfflineSimulationBridge` die einzige Zeitquelle. Pro Godot-Frame
wird aus realer Zeit, Basisrate (8 Simulationsminuten pro Sekunde) und Reglerwert
(0,5x bis 5x) ein Zielzeitpunkt berechnet. SimSharp verarbeitet anschließend alle bis
zu diesem Zielzeitpunkt fälligen Ereignisse in Originalreihenfolge. Dieselbe erreichte
Zeit steuert Positionen und Animationsfortschritt der Patienten.

Pause verändert die Simulationszeit nicht; Fortsetzen beginnt deshalb ohne
Positionssprung am identischen Zeitpunkt. Reset setzt SimSharp, Uhr, Timeline und
Darstellung gemeinsam auf Minute 0. Die Oberfläche zeigt sowohl die verstrichene
Simulationszeit als auch die daraus berechnete Praxisuhr ab 08:00 Uhr.

Die Timeline nimmt neue Ereignisse inkrementell auf. Ein vollständiger Neuaufbau bei
jedem Ereignis ist nicht mehr erforderlich. Der WebSocket-Modus behält seine eigene
serverseitige Uhr und sein bisheriges Protokoll unverändert bei.

## Steuerung und Fehlerbehebung

- **Start / Weiter**: Simulation starten oder fortsetzen
- **Pause**: Simulation anhalten
- **Reset**: neuen Simulationslauf starten
- **Personal einstellen** (Offline): Personen nach Stammrolle einstellen, Einsatzrollen waehlen, vorhandene Plaetze pruefen
  und mit **Uebernehmen & neu starten** einen neuen Lauf beginnen. **Standardwerte**
  laedt die JSON-Startwerte in die Eingabefelder, **Abbrechen** verwirft den Entwurf.
  Die JSON-Dateien bleiben unveraendert. Details: [README_VERBINDUNG.md](./README_VERBINDUNG.md).
- **Rechte Maustaste ziehen**: Kamera drehen
- **Mausrad**: Ansicht zoomen

## Manuelle Einsatzrolle: Schwester an der Rezeption

Die [Personalkonfiguration](../Praxis.Visualisierung/Konfiguration/personal.json)
enthaelt fuer `schwester_1` ausschliesslich die Qualifikation und den Einsatz
**Schwester**. Ab `schwester_2` sind beide Einsaetze moeglich. Die Vorlage der
zweiten Schwester sieht so aus:

```json
{
  "id": "schwester_2",
  "qualifikationen": ["Schwester", "Rezeption"],
  "stammrolle": "Schwester",
  "einsatzrolle": "Rezeption",
  "modell": "Schwester"
}
```

Die zweite Schwester wird **im Godot-Personalfenster eingestellt**, nicht als feste
Zahl im Code oder in den Kern-Konfigurationen. Der zusaetzliche Eintrag ist eine
Vorlage fuer Qualifikationen und Startrolle; er stellt noch keine weitere Person ein.
Die Startbesetzung mit einer Schwester ist gueltig, weil `schwester_1` fest im
Schwesternbereich bleibt. Spaeter hinzugefuegte Schwestern uebernehmen die beiden
Qualifikationen der letzten Schwesternvorlage und starten in der Stammrolle.

1. **Personal einstellen** oeffnen und bei **Stammrolle Schwestern** unter
   **Personen neu** die Anzahl auf **2** stellen.
2. `schwester_1` bleibt fest als **Schwester** eingesetzt. Fuer die neu eingestellte
   `schwester_2` kann **Rezeption** oder **Schwester** ausgewaehlt werden. Die aktuelle
   Vorlage stellt fuer `schwester_2` zunaechst **Rezeption** ein.
3. Die Anzeige **Neuer Lauf** pruefen: Bei einer Rezeptionskraft, zwei Schwestern
   und zwei Aerzten nach Stammrolle ergeben sich **2 Rezeption, 1 Schwester, 2 Aerzte**.
4. **Uebernehmen & neu starten** klicken. Der bisherige Tag wird verworfen; der neue
   Lauf beginnt ab 08:00 Uhr. Die Einsatzrollen gelten fuer den gesamten Lauf.

Die Auswahl bietet nur die Qualifikationen der jeweiligen Person an. Einsaetze ohne
freien passenden Arbeitsplatz oder mit einer unbesetzten Einsatzrolle sind gesperrt.
Personal-ID und Aussehen bleiben beim Rollenwechsel erhalten. Jede Person zaehlt
genau einmal; Patientenwege verwenden die Zuordnung der aktuellen Einsatzrolle.

**Abbrechen** verwirft den Entwurf. **Reset** behaelt die uebernommene Besetzung.
**Standardwerte** laedt die Kern-Startzahlen und die Einsatzrollen der
Personalkonfiguration in den Entwurf. Bei einer eingestellten Schwester bleibt nur
`schwester_1` aktiv; die zweite muss bei Bedarf erneut eingestellt werden. Die Personaleinstellungen gelten
fuer die Sitzung. Wird anschliessend ein Layout im Baumodus uebernommen, speichert
dieser die aktuelle Besetzung einschliesslich Einsatzrollen im Godot-Layout mit.

Alle Aenderungen liegen in der Godot-Visualisierung. Die vorhandene Schnittstelle
uebergibt dem Kern nur die aus den Einsatzrollen berechneten Zahlen. Die Logikdateien
und JSON-Quelldateien des Kern-Branches `unity` werden nicht veraendert. Ein
automatischer Rollenwechsel waehrend des Tages ist nicht Bestandteil dieser Funktion.
Beim manuellen Wechsel und Neustart steht dieselbe Person direkt am neu zugeordneten
Arbeitsplatz. Ein Laufweg zwischen Rezeption und Schwesternbereich wird dabei nicht abgespielt.

Der fokussierte Test prueft die echte Oberflaeche, Rollenwechsel beim Neustart,
Personen-IDs, Patientenwege, Abbrechen, Platzmangel, Tagesende und Layout-Neustart:

```powershell
& "C:\Tools\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe" --headless --path "C:\home\PraxisMitGodot\Praxis.Visualisierung" --script res://tests/rollen_einsatz_test.gd
```

Falls `PraxisSimulation.Server.csproj` fehlt, den Junction-Link prüfen:

```powershell
Get-ChildItem .\simSharpSimulation -Recurse -Filter *.csproj
```

Bei der Fehlermeldung `Preload file "res://Anbindung/SimulationBridge.cs" has no resource
loaders` läuft die normale Godot-Version. Sie schließen und den oben genannten
Editor mit `mono_win64` im Dateinamen starten. Für WebSocket-Verbindungsfehler
zuerst den Health-Check oben ausführen.
