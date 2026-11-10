# Projekt ausführen

Diese Anleitung beschreibt den Start der Godot-Visualisierung mit SimSharp.
Standardmäßig läuft SimSharp **offline direkt in Godot**: kein Server und keine
JSON-/Trace-Datei nötig. WebSocket bleibt als zweiter Modus verfügbar.

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

## 3. Godot starten (Offline-Standard)

Für den Offline-Modus **keinen Server starten**. Godot 4.7.2 .NET öffnen:

```powershell
& "C:\Tools\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe" `
  --editor `
  --path "C:\home\PraxisMitGodot\Praxis.Visualisierung"
```

Im Editor **F5** drücken und in der Anwendung auf **Start** klicken. Oben rechts
ist **Offline (direkt in Godot)** vorausgewählt. Die Patienten kommen aus dem
SimSharp-Kern im selben Prozess. Für die Laufanimation werden künftige
Ankunftszeiten einmal im Arbeitsspeicher ermittelt; es wird keine Datei erzeugt.

## Optional: WebSocket-Server starten

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

## Godot im WebSocket-Modus starten

Godot 4.7.2 .NET befindet sich auf diesem Computer unter:

```text
C:\Tools\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe
```

Den Editor kannst du direkt aus PowerShell mit dem Projekt öffnen:

```powershell
& "C:\Tools\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe" `
  --editor `
  --path "C:\home\PraxisMitGodot\Praxis.Visualisierung"
```

Alternativ Godot über das Startmenü öffnen und das Projekt importieren:

```text
C:\home\PraxisMitGodot\Praxis.Visualisierung\project.godot
```

Danach:

1. Asset-Import abwarten.
2. Zum Bearbeiten eine Szene oder ein Script im Datei-Explorer anklicken.
3. **F6** startet die aktuell geöffnete Szene.
4. **F5** startet das gesamte Projekt.
5. Oben rechts **WebSocket (Server)** auswählen und in der Anwendung auf **Start** klicken.

Wenn Godot nach dem Start fragt, welche Szene verwendet werden soll, die
Hauptszene `Main.tscn` auswählen.

## Alternativer gemeinsamer Start

Wenn der Godot-Pfad bekannt ist, kann das Offline-Projekt mit dem Startskript
gebaut und geöffnet werden:

```powershell
cd C:\home\PraxisMitGodot
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Start-Visualisierung.ps1 -GodotPfad "C:\Tools\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe"
```

Für WebSocket zusätzlich `-Modus WebSocket` angeben und in Godot oben rechts
**WebSocket (Server)** wählen. Das Skript startet den Server nur in diesem Modus.
Auf anderen Computern den Godot-Pfad entsprechend ersetzen.

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

Im Offline-Modus wird kein Server benötigt. Im WebSocket-Modus zuerst den Server
starten, danach den Modus in Godot auswählen und auf **Start** klicken.

