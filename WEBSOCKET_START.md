# Live-Simulation mit Godot und WebSocket

Die SimSharp-Simulation und die Godot-Visualisierung laufen in getrennten Prozessen:

1. `PraxisSimulation.Server` erzeugt die Patienten und führt SimSharp aus.
2. Der Server veröffentlicht Uhr- und Trace-Ereignisse live über
   `ws://localhost:5080/ws/simulation`.
3. Godot sendet nur `start`, `stop` und `setSpeed` und zeichnet ausschließlich
   bereits empfangene Ereignisse. Es gibt keinen vorberechneten Tagesplan und keine
   nachgebildete Patientenlogik in Godot.

## Gemeinsamer Start

Im Repository-Hauptordner:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Start-Visualisierung.ps1 -GodotPfad "C:\Tools\Godot_v4.7.2-stable_mono_win64.exe"
```

Das Skript baut Godot, startet den Server auf Port 5080, wartet auf dessen
Health-Endpunkt und öffnet anschließend den Godot-Editor. Falls bereits ein Server
auf Port 5080 läuft und `/health` antwortet, wird dieser weiterverwendet.

Im Godot-Editor das Projekt mit F6/F5 ausführen und in der Visualisierung **Start**
drücken. **Stop** beendet den serverseitigen Lauf. Ein weiterer Start erzeugt eine
neue, unabhängige Server-Sitzung.

## Getrennter manueller Start

Serverterminal:

```powershell
dotnet run --project .\simSharpSimulation\PraxisSimulation.Server\PraxisSimulation.Server.csproj --urls http://localhost:5080
```

Danach Godot öffnen:

```powershell
& "C:\Tools\Godot_v4.7.2-stable_mono_win64.exe" --editor --path .\Praxis.Visualisierung
```

Der Server muss laufen, bevor die Godot-Szene gestartet wird. Der Health-Check ist
unter `http://localhost:5080/health` erreichbar.
