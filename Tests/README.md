# Tests und Pruefungen

Die vorhandenen Pruefungen sind von der laufenden Visualisierung getrennt.
Inhalt und Pruefablauf bleiben erhalten; nur Pfade und Ordner wurden angepasst.

```text
Tests/
├── DotNet/
│   ├── Praxis.Visualisierung.Pruefung.csproj
│   ├── Program.cs
│   ├── RollenwechselPruefung.cs
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
├── personalfenster_test.gd
├── rollenwechsel_test.gd
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

Die automatische Personalanzahl im Offline-Modus wird auf drei Ebenen geprueft:
Die C#-Pruefung vergleicht die geladenen Kernwerte mit den Simulations-JSONs.
[personal_test.gd](../Praxis.Visualisierung/tests/personal_test.gd) prueft unter
anderem eine Rezeptionsfigur, zwei Schwesterfiguren, zwei Arztfiguren,
eindeutige IDs, reduzierte Zahlen und Platzmangel.
[offline_test.gd](../Praxis.Visualisierung/tests/offline_test.gd) vergleicht die
tatsaechlichen Figuren der Hauptszene mit den Zahlen der Bridge und prueft Reset.
Mit `-- --erwarte-platzmangel` hinter dem Skriptnamen erwartet dieser Test drei
geladene Rezeptionskraefte bei nur zwei Layout-Plaetzen und prueft die Startsperre.
Dieser Sonderfall braucht eine entsprechende Testkonfiguration im Build-Ausgabeordner;
die Quellkonfigurationen der verknuepften Simulation bleiben unveraendert.

[personalfenster_test.gd](../Praxis.Visualisierung/tests/personalfenster_test.gd)
prueft die echte Offline-Oberflaeche: Entwuerfe beeinflussen den aktiven Lauf nicht,
Platzmangel und ungueltige Zahlen werden abgewiesen, Abbrechen verwirft den Entwurf,
Uebernehmen startet Uhr und Figuren neu. Der Test fuehrt einen Lauf mit geaenderten
Personalzahlen bis zum Ende aus und prueft anschliessend Reset und Standardwerte.
Hashes der drei Personal-Quelldateien bestaetigen, dass die Simulations-JSONs
unveraendert bleiben.

[baumodus_personal_test.gd](../Praxis.Visualisierung/tests/baumodus_personal_test.gd)
prüft zusätzlich die automatische Besetzung neuer Arzt- und Schwesternräume,
den Erhalt bestehender Zuordnungen und manuell geänderter Personalzahlen,
Vorschau/Abbrechen, Platzmangel und Entfernen eines Raums. Eine isolierte
Layoutdatei im Godot-Benutzerordner prüft Speichern und Neustart der echten
Hauptszene einschließlich SimSharp-Personalzahlen, Figuren und Patientenwegen.
Das Nutzerlayout und die Personal-Quelldateien werden nicht verändert.

[kleiner_raum_test.gd](../Praxis.Visualisierung/tests/kleiner_raum_test.gd) prüft
kleine neue Räume mit vorher gewählter Breite und Tiefe, die Mausvorschau,
Rechteck und L-Form, ungültige Randpositionen und die zusätzliche Schwester.

[raum_ziehen_test.gd](../Praxis.Visualisierung/tests/raum_ziehen_test.gd) sendet
Mausereignisse an Seiten- und Eckgriffe und prüft Breite, Tiefe, feste Gegenkanten,
Flurtüren, relative Rasterschritte und abgewiesene Kollisionen ohne Speicherung.

[RollenwechselPruefung.cs](./DotNet/RollenwechselPruefung.cs) wird von der
C#-Pruefung mit ausgefuehrt. Sie prueft Schwellen, Rueckkehr, Leerlaufhilfe,
Prioritaet, Wegzeit, ununterbrochene Bearbeitung, Stornierung und Raumbelegung.
Ein vollstaendiger Simulationslauf mit 1 Rezeptionskraft, 2 Schwestern und 2 Aerzten
prueft ausserdem Wiederholbarkeit sowie fehlende Doppelbelegung von Personen
und Arbeitsplaetzen. Der bisherige Referenzlauf ohne Rollenwechsel bleibt erhalten.

[rollenwechsel_test.gd](../Praxis.Visualisierung/tests/rollenwechsel_test.gd)
aktiviert die Option ueber das echte Personalfenster und prueft Platzmangel,
fuenf Figuren, zwei Qualifikationen derselben Schwester, Bewegung ueber die
Raumwege, Pause, Ankunft am zweiten Rezeptionsplatz und einen vollstaendigen Lauf.
Reset, erneutes Oeffnen und Abschalten der Option werden ebenfalls geprueft.
Diese beiden Pruefungen benoetigen keinen WebSocket-Server.

Die [Originaldateipruefung](./Originaldateien/Original_pruefen.py) vergleicht den
vollstaendigen Originalordner einschliesslich generierter Dateien gegen den
historischen Auslieferungszustand:

```powershell
python .\Tests\Originaldateien\Original_pruefen.py
```

Nach eigenen Builds sind Abweichungen in generierten Dateien erwartbar. Auch
die bewusst erweiterten Kerndateien fuer den Rollenwechsel unterscheiden sich
jetzt vom historischen Originalzustand. Der
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
| [PersonalMatrix.gd](../Praxis.Visualisierung/UI/PersonalMatrix.gd) | Inzwischen aktiv: Offline-Personalfenster, durch den neuen Oberflaechentest geprueft |
| [VisualisierungsController.cs](./DotNet/Referenz/VisualisierungsController.cs) | Wird fuer die C#-Referenzpruefung benoetigt; deshalb hierher verschoben |
| [packages/](../packages/) | Wird von [NuGet.Config](../NuGet.Config) fuer den Build verwendet; behalten |

Die ungenutzten Grafikressourcen wurden erhalten. Ihre
Entfernung ist fuer die Umstrukturierung nicht erforderlich. Die Assetherkunft
bleibt in den jeweiligen Herkunftsdateien dokumentiert.

Godots `.godot/` sowie .NETs `bin/` und `obj/` sind generierte Cache- und
Buildordner. Sie werden automatisch erzeugt und sind keine weiteren Testquellen.
