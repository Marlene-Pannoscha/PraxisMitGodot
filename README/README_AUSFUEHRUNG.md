# Projekt ausführen

Diese Anleitung beschreibt den aktuellen Startablauf für die Godot-Visualisierung
mit dem SimSharp-WebSocket-Server.

## Voraussetzungen

- Windows PowerShell
- .NET SDK 10
- Godot 4.7.2 .NET/Mono
- Das Projekt liegt unter `C:\home\PraxisMitGodot`

## 1. Projektstruktur prüfen

Die Solution erwartet diese Projekte:

```text
C:\home\PraxisMitGodot\PraxisMitGodot.slnx
C:\home\PraxisMitGodot\Praxis.Visualisierung\Praxis.Visualisierung.csproj
C:\home\PraxisMitGodot\simSharpSimulation\PraxisSimulation.Core\PraxisSimulation.Core.csproj
C:\home\PraxisMitGodot\simSharpSimulation\PraxisSimulation.Server\PraxisSimulation.Server.csproj
```

Der Ordner `simSharpSimulation` ist in dieser lokalen Installation ein
Junction-Link. Details stehen in [README_JUNCTION.md](./README_JUNCTION.md).

## 2. Projekt bauen

PowerShell im Hauptordner öffnen:

```powershell
cd C:\home\PraxisMitGodot
dotnet build .\PraxisMitGodot.slnx -m:1
```

Der Build muss mit `0 Fehler` erfolgreich sein.

## 3. SimSharp-Server starten

In einem eigenen PowerShell-Fenster ausführen:

```powershell
cd C:\home\PraxisMitGodot
dotnet run --project .\simSharpSimulation\PraxisSimulation.Server\PraxisSimulation.Server.csproj --urls http://localhost:5080
```

Das Fenster geöffnet lassen. Der Server stellt die Simulation über WebSocket
bereit. Der Health-Endpunkt ist:

```text
http://localhost:5080/health
```

## 4. Godot starten

Godot 4.7.2 .NET öffnen und das Projekt importieren:

```text
C:\home\PraxisMitGodot\Praxis.Visualisierung\project.godot
```

Danach:

1. Asset-Import abwarten.
2. `F6` oder `F5` drücken.
3. In der Anwendung auf **Start** klicken.

## Alternativer gemeinsamer Start

Wenn der Godot-Pfad bekannt ist, kann der Server und der Godot-Editor gemeinsam
gestartet werden:

```powershell
cd C:\home\PraxisMitGodot
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Start-Visualisierung.ps1 -GodotPfad "C:\Tools\Godot_v4.7.2-stable_mono_win64.exe"
```

Den Beispielpfad durch den tatsächlichen Pfad zur Godot-.NET-Datei ersetzen.

## Steuerung

- **Start / Weiter**: Simulation starten oder fortsetzen
- **Pause**: Simulation anhalten
- **Reset**: neuen Simulationslauf starten
- Rechte Maustaste ziehen: Kamera drehen
- Mausrad: Ansicht zoomen

## Fehlerbehebung

### `PraxisSimulation.Server.csproj` nicht gefunden

Prüfen:

```powershell
Get-ChildItem .\simSharpSimulation -Recurse -Filter *.csproj
```

Wenn keine Core- und Server-Projekte angezeigt werden, ist der Junction-Link
nicht vorhanden oder das Zielverzeichnis fehlt. Siehe
[README_JUNCTION.md](./README_JUNCTION.md).

### Server läuft nicht

Prüfen, ob Port 5080 erreichbar ist:

```powershell
Invoke-RestMethod http://localhost:5080/health
```

### Godot zeigt keine Simulation

Zuerst den Server starten, danach Godot öffnen und erst dann in der Anwendung
auf **Start** klicken.

