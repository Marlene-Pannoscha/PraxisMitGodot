# Arztpraxis: Originalsimulation + separate Godot-Visualisierung

> **Aktueller Laufzeitmodus:** SimSharp und Godot sind über WebSocket vollständig
> entkoppelt. Die verbindliche Start- und Architekturbeschreibung steht in
> [`WEBSOCKET_START.md`](./WEBSOCKET_START.md). Die weiter unten beschriebene direkte
> Kernanbindung bleibt nur als historische Prüf- und Vergleichsbeschreibung erhalten
> und wird vom Godot-Projekt nicht mehr kompiliert.

Godot - Marlene

.\Start-Visualisierung.ps1 -GodotPfad "C:\Tools\Godot_v4.7.2-stable_mono_win64.exe"

WebSocket

dotnet run --project .\simSharpSimulation\PraxisSimulation.Server\PraxisSimulation.Server.csproj --urls http://localhost:5080

## Was wurde übernommen? 

Der gesamte Ordner `simSharpSimulation/` entspricht inhaltlich **1:1 dem hochgeladenen Original**. Keine vorhandene C#-, JSON-, Projekt-, Server-, WPF- oder Auswertungsdatei wurde geändert. Auch die bestehende Solution bleibt erhalten.

`Praxis.Visualisierung/` zeigt die Originalsimulation jetzt in der **3D-Praxis aus `arztpraxis.zip`**. Der enthaltene Raumgenerator wurde unverändert nach `Praxis.Visualisierung/Raum3D/Praxis.gd` übernommen: Wartezimmer, zwei Arztzimmer, Rezeption, Schwesternzimmer, Flur, Türen und Möbel.

Die Patienten laufen in derselben 3D-Welt durch die Türöffnungen. Arzt-ID 1 und 2 werden ihren getrennten Zimmern zugeordnet; die Schwester-IDs bestimmen den sichtbaren Behandlungsplatz. Rückkehr zur Rezeption und Abbrüche folgen weiterhin den Originalereignissen. Die vorherige 2D-Hintergrundszene wird nicht mehr geladen.

Die vereinfachte Simulationslogik der Demo wird **nicht** verwendet. Es gibt keine zweite Behandlungssimulation in GDScript.

## Abhängigkeit

`Praxis.Visualisierung` → `simSharpSimulation/PraxisSimulation.Core`

Nur die Visualisierung hat einen `ProjectReference` auf den bestehenden Kern. Der Simulationskern enthält keinerlei Verweis auf Godot oder auf das neue Projekt.

Der vorhandene Kern bindet die Prozess- und Ressourcendateien des ursprünglichen Projekts bereits selbst ein. Diesen vorhandenen Aufbau verwendet die Visualisierung unverändert.

## Voraussetzungen

- **Godot 4.7.2 .NET**, passend zur mitgelieferten Demo und den enthaltenen Godot-Paketen.
- **.NET SDK 10**; geprüft mit SDK 10.0.203.
- Das Archiv vollständig entpacken. Die Ordnerstruktur muss erhalten bleiben.

Die notwendigen NuGet-Pakete aus der Demo liegen in `packages/`. Die enthaltene `NuGet.Config` verwendet diesen lokalen Paketordner. Godot und das .NET SDK selbst sind nicht Bestandteil des Archivs.

## Schnellstart unter Windows

1. Im entpackten Hauptordner ein Terminal öffnen.
2. Bauen:

   ```powershell
   dotnet build .\PraxisMitGodot.slnx -m:1
   ```
3. Godot **.NET** starten und `Praxis.Visualisierung/project.godot` importieren.
4. Den Asset-Import abwarten. Mit **F5** starten.
5. In der Anwendung **Start** drücken.

Alternativ das mitgelieferte Skript mit dem Pfad zur eigenen Godot-.NET-Datei ausführen:

```powershell
.\Start-Visualisierung.ps1 -GodotPfad "C:\Tools\Godot\Godot_v4.7.2-stable_mono_win64.exe"
```

Das Skript baut das neue Projekt, importiert die Grafiken und startet die Visualisierung. Der Beispielpfad ist durch den tatsächlichen Installationspfad zu ersetzen.

## Steuerung

| Funktion                  | Verhalten                                                                 |
| ------------------------- | ------------------------------------------------------------------------- |
| Start / Weiter            | Schaltet die originale SimSharp-Umgebung schrittweise weiter.             |
| Pause                     | Hält Simulationsuhr, Ereignisverarbeitung und Figurenanimation an.       |
| Reset                     | Erzeugt einen frischen Originallauf mit demselben Seed.                   |
| Rechte Maustaste + Ziehen | Dreht und neigt die 3D-Kamera.                                            |
| Mausrad über der Praxis  | Zoomt die 3D-Ansicht.                                                     |
| Ansicht zurücksetzen     | Stellt ausschließlich die Kamera zurück.                                |
| Geschwindigkeit           | 0,25 bis 5; verändert den Zeittakt, keine Behandlungs- oder Wartezeiten. |

Wie in der Demo entspricht 1x einer Darstellung von acht Simulationsminuten je realer Sekunde. Die Anzeige zeigt die seit Tagesbeginn verstrichene Simulationszeit.

Die Visualisierung zeigt **einen Arbeitstag**. Die Standardzahl der Arbeitstage im ursprünglichen Konsolen-/WPF-Projekt bleibt unverändert. Auch die ursprünglichen Konfigurationen und deren Ladeverhalten bleiben bestehen. Der vom Originalkern vorgegebene Nachlaufpuffer wird berücksichtigt; bei der vorhandenen Konfiguration endet die Modelluhr deshalb nach 660 Minuten. In diesem Nachlauf können bereits alle Personen ausgetreten sein.

## Wichtige neue Dateien

| Datei                                                            | Aufgabe                                                                              |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `Praxis.Visualisierung/SimulationBridge.cs`                    | Übergibt Daten und Steuerbefehle zwischen C# und GDScript.                          |
| `Praxis.Visualisierung/Anbindung/OriginalSimulation.cs`        | Kapselt den Zugriff auf die vorhandenen internen Einstiegspunkte.                    |
| `Praxis.Visualisierung/Anbindung/VisualisierungsController.cs` | Steuert die Original-SimSharp-Uhr; vergleicht Ereignisse mit dem Vorlauf.            |
| `Praxis.Visualisierung/PatientenTimeline.gd`                   | Ordnet Originalereignissen räumliche Positionen und Wege zu.                        |
| `Praxis.Visualisierung/Main.gd`                                | Oberfläche, Kamera, 3D-Welt und Figurenverwaltung.                                  |
| `Praxis.Visualisierung/Patient.gd`                             | Aufrechte FBX-Figuren und Gehen-/Warten-Animationen.                                 |
| `Praxis.Visualisierung/Raum3D/Praxis.gd`                       | Unveränderter Raum- und Möbelgenerator aus `arztpraxis.zip`.                     |
| `Praxis.Visualisierung/tests/raum3d_test.gd`                   | Prüft 3D-Szene, Türen, Wege, Kamera, Figurenposition und aufrechte Körperhaltung. |
| `Praxis.Visualisierung.Pruefung/`                              | Prüft Modellgleichheit und Steuerung unabhängig vom Godot-Editor.                  |

## Weshalb verwendet die Anbindung Reflection?

`PatientenProzess`, `FuehreAusAsync` und der Konfigurationslader sind im hochgeladenen Kern `internal`. Ein fremdes Projekt kann sie deshalb nicht direkt aufrufen. Um **keine einzige Originaldatei zu ändern**, ist dieser Zugriff in `OriginalSimulation.cs` gekapselt. Der Adapter ruft ausschließlich vorhandene Einstiegspunkte auf. Er enthält keine nachgebaute Patienten-, Prognose- oder Ressourcenlogik.

Beim Laden läuft ein echter Originaltag einmal vollständig vor. Seine unveränderten Ereignisse liefern die Zielzeitpunkte für die Weganimation. Beim Start wird eine neue originale SimSharp-Umgebung ausgeführt; jede dabei entstehende Meldung wird gegen den Vorlauf geprüft. Pause und Geschwindigkeit steuern diese neue Umgebung tatsächlich.

Reflection hängt von den vorhandenen Typ- und Methodennamen ab. Falls diese im Kern später geändert werden, muss nur die Anbindung angepasst werden. Ein fehlender Einstiegspunkt wird als Ladefehler angezeigt.

## Räumliche Darstellung

Die Positionen und Laufwege gehören ausschließlich zur Visualisierung. Die Darstellung setzt Bewegungen zwischen den im Original protokollierten Weg- und Ankunftsereignissen um. Während Behandlungen und Wartezeiten bleiben die Figuren stehen. Prognose- oder Terminmeldungen lösen keine Bewegung aus.

Arzt- und Schwester-IDs werden an die Darstellung weitergegeben. Die zwei Ärzte der mitgelieferten Konfiguration erhalten je ein eigenes Arztzimmer. Mehrere Schwestern werden an den drei Arbeitsplätzen im gemeinsamen Schwesternzimmer dargestellt. Dieser Raumplan ist eine Visualisierung, kein maßstabsgetreuer Raumplan der Finanzkonfiguration.

Die Warteschlangen von Arzt und Schwester nutzen grafisch das gemeinsame Wartezimmer. Bei starker Belegung werden zusätzliche Wartepositionen im Flur verwendet. Diese Positionen werden ausschließlich aus den vorhandenen Ereignissen abgeleitet und entscheiden nicht über die fachliche Reihenfolge. Die Laufwege werden zwischen den unveränderten Start- und Ankunftszeiten animiert; die 3D-Weglänge ändert keine Modellzeit.

Das FBX-Animationsskelett richtet sich beim Abspielen bereits auf die Y-Achse aus. Die bisherige zusätzliche Achsendrehung wurde ausschließlich im Figuren-Skript entfernt, damit die Patienten in der 3D-Praxis aufrecht stehen.

Die Original-FBX-Dateien der Demo verweisen auf eine nicht mitgelieferte PSD-Textur. Beim ersten Import kann Godot deshalb Texturmeldungen ausgeben. Wie in der Demo setzt `Patient.gd` zur Laufzeit ein eigenes blaues Material; Figuren und Animationen wurden damit erfolgreich geprüft.

## Prüfungen selbst ausführen

```powershell
dotnet build .\PraxisMitGodot.slnx -m:1
dotnet .\Praxis.Visualisierung.Pruefung\bin\Debug\net10.0\Praxis.Visualisierung.Pruefung.dll
```

Mit Godot .NET im Suchpfad:

```powershell
godot --headless --path .\Praxis.Visualisierung --script res://tests/timeline_test.gd
godot --headless --path .\Praxis.Visualisierung --script res://tests/integration_test.gd
godot --headless --path .\Praxis.Visualisierung --script res://tests/raum3d_test.gd
```

Die .NET-Prüfung vergleicht einen vollständigen direkten Originallauf mit Vorlauf, schrittweiser Ausführung und Reset. Die Godot-Prüfungen prüfen zusätzlich Steuerung, Figuren, Animationen, Bewegung nur auf protokollierten Wegen, Schwester-/Arzt-IDs, Rückkehr zur Rezeption und den Abbruchpfad.

Die Ergebnisse der durchgeführten Prüfung stehen in `PRUEFBERICHT.md`.

## Originaldateien kontrollieren

Vor dem ersten Build kann der gesamte Originalordner gegen `Originaldateien.sha256.json` geprüft werden:

```powershell
python .\Original_pruefen.py
```

Nach dem Bauen ändern sich erwartungsgemäß generierte Dateien unter `bin/` und `obj/`. Die Prüfliste dokumentiert den unveränderten Auslieferungszustand einschließlich der bereits im Originalarchiv vorhandenen Dateien.

## Technische Referenz

Godot-Dokumentation zum Zusammenspiel von .NET-Projekten und Godot C#: https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_basics.html
