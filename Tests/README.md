# Tests und Pruefungen

Die vorhandenen Pruefungen sind von der laufenden Visualisierung getrennt.
Inhalt und Pruefablauf bleiben erhalten; nur Pfade und Ordner wurden angepasst.

```text
Tests/
├── DotNet/
│   ├── Praxis.Visualisierung.Pruefung.csproj
│   ├── Program.cs
│   └── Referenz/VisualisierungsController.cs
├── Originaldateien/
│   ├── Original_pruefen.py
│   └── Originaldateien.sha256.json
└── Nachweise/
    ├── PRUEFBERICHT.md
    ├── Vorschau.png
    ├── bisherige Protokolle
    └── 3D/

Praxis.Visualisierung/tests/
├── konfiguration_test.gd
├── timeline_test.gd
├── personal_test.gd
├── patient_sitzen_test.gd
├── raum3d_test.gd
├── offline_test.gd
├── integration_test.gd
├── zimmerleuchten_test.gd
├── gruppenblasen_test.gd
└── vorschau_3d.gd
```

Die [Godot-Tests](../Praxis.Visualisierung/tests/) bleiben innerhalb des
Godot-Projekts. Dadurch bleiben `res://`-Pfade und direkte Zugriffe auf Szenen
und Figuren erhalten. Alle anderen Pruefungen und gespeicherten Nachweise liegen
hier. Die Tests des eingebundenen Originalprojekts unter `simSharpSimulation/`
werden nicht verschoben.

## Ausfuehren

Alle folgenden Befehle gelten im Repository-Hauptordner.

```powershell
dotnet build .\PraxisMitGodot.slnx -m:1
dotnet run --project .\Tests\DotNet\Praxis.Visualisierung.Pruefung.csproj --no-build
```

Godot-Beispiel; den Pfad gegebenenfalls an die eigene Installation anpassen:

```powershell
& "C:\Tools\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe" --headless --path .\Praxis.Visualisierung --script res://tests/konfiguration_test.gd
```

Die uebrigen Godot-Tests verwenden denselben Aufruf mit dem jeweiligen
Skriptnamen. Der Integrationstest benoetigt einen laufenden WebSocket-Server;
die Vorschau benoetigt eine grafische Ausgabe und speichert nach
[Nachweise/Vorschau.png](./Nachweise/Vorschau.png).

Die [Originaldateipruefung](./Originaldateien/Original_pruefen.py) vergleicht den
vollstaendigen Originalordner einschliesslich generierter Dateien gegen den
historischen Auslieferungszustand:

```powershell
python .\Tests\Originaldateien\Original_pruefen.py
```

Nach eigenen Builds sind Abweichungen in generierten Dateien erwartbar. Der
[Pruefbericht](./Nachweise/PRUEFBERICHT.md) und die bisherigen Protokolle sind
historische Nachweise, keine Ergebnisse eines neu ausgefuehrten Gesamttests.

## Ergebnis der Referenzpruefung auf ungenutzte Dateien

Geprueft wurden Hauptszene, Skriptverweise, Projektdateien, Konfigurationen und
die Testaufrufe. Fehlende aktive Verweise bedeuten hier, dass die Ressourcen
derzeit nicht von der laufenden 3D-Visualisierung geladen werden.

| Ressource | Aktueller Status |
| --- | --- |
| [ClinicBackground.tscn](../Praxis.Visualisierung/ClinicBackground.tscn) | Fruehere 2D-Szene; wird von der Hauptszene nicht geladen |
| [assets/clinic/](../Praxis.Visualisierung/assets/clinic/) | Grafikpaket der alten 2D-Szene; keine Verwendung im aktuellen 3D-Aufbau gefunden |
| [WardOrderly.glb](../Praxis.Visualisierung/Personal/Modelle/WardOrderly.glb) und zugehoerige Textur/Importe | Ersatzmodell; wird von der aktuellen Modellauswahl nicht geladen |
| [PersonalMatrix.gd](../Praxis.Visualisierung/UI/PersonalMatrix.gd) | Reservierter Platzhalter ohne Aufruf oder Bedienfunktion |
| [VisualisierungsController.cs](./DotNet/Referenz/VisualisierungsController.cs) | Wird fuer die C#-Referenzpruefung benoetigt; deshalb hierher verschoben |
| [packages/](../packages/) | Wird von [NuGet.Config](../NuGet.Config) fuer den Build verwendet; behalten |

Die ungenutzten Grafikressourcen und der Platzhalter wurden erhalten. Ihre
Entfernung ist fuer die Umstrukturierung nicht erforderlich. Die Assetherkunft
bleibt in den jeweiligen Herkunftsdateien dokumentiert.

Godots `.godot/` sowie .NETs `bin/` und `obj/` sind generierte Cache- und
Buildordner. Sie werden automatisch erzeugt und sind keine weiteren Testquellen.
