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
- **Rechte Maustaste ziehen**: Kamera drehen
- **Mausrad**: Ansicht zoomen

Falls `PraxisSimulation.Server.csproj` fehlt, den Junction-Link prüfen:

```powershell
Get-ChildItem .\simSharpSimulation -Recurse -Filter *.csproj
```

Bei der Fehlermeldung `Preload file "res://SimulationBridge.cs" has no resource
loaders` läuft die normale Godot-Version. Sie schließen und den oben genannten
Editor mit `mono_win64` im Dateinamen starten. Für WebSocket-Verbindungsfehler
zuerst den Health-Check oben ausführen.
