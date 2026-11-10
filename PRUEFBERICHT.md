# Prüfbericht – 3D-Umbau, 10.11.2026

Geprüft mit Godot 4.7.2 .NET und .NET SDK 10.0.203 unter Linux.

## Ergebnis

| Prüfung | Ergebnis |
|---|---|
| Build der Solution | Bestanden, 0 Warnungen, 0 Fehler |
| Originalsimulation: direkter Lauf, Vorlauf und schrittweise Ausführung | Alle 2.221 Ereignisse identisch, einschließlich Zeitstempeln, Reihenfolge und Mitarbeiter-IDs |
| Patienten im Originaltag | 71 Patienten, 71 Hit, 0 Miss |
| Start, Pause, Geschwindigkeit, Reset | Bestanden; erneuter Lauf reproduziert sämtliche Originalereignisse |
| Godot-Integration über den vollständigen Tag | Bestanden; alle Ereignisse verarbeitet, am Ende keine Patienten mehr sichtbar |
| 3D-Grundriss und Möbel | Generator aus arztpraxis.zip bytegleich übernommen und in gemeinsamer 3D-Welt geladen |
| 2D-Hintergrund | Aus der Hauptszene entfernt; die frühere Ressource bleibt ungenutzt erhalten |
| Tür- und Wandprüfung | 381 Originalwege mit jeweils 101 Abtastpositionen gegen sämtliche Wände plus 0,15 m Sicherheitsabstand geprüft; keine Wanddurchquerung |
| 3D-Raumprüfung insgesamt | 692.673 Prüfungen, 0 Fehler |
| Arztzuordnung | Arzt 1 und 2 erhalten getrennte Arztzimmer |
| Figuren | Gehen und Warten geladen; Positionen in 3D-Koordinaten, aufrechte Körperhaltung und eingefrorene Animation bei Pause geprüft |
| Kamera | Mausrad-Zoom, Drehen mit rechter Maustaste und Zurücksetzen geprüft |
| Räumliche Ereignisfolge | Schwester, Arzt, Ressourcen-IDs, Rezeptionsrückkehr, Stillstand während Behandlung und zeitgebundene Wege bestanden |
| Abbruchdarstellung | Synthetische Originalereignisfolge geprüft |
| Grafische Kontrolle | Echte OpenGL-Darstellung mit Software-Rendering geprüft; Vorschau.png zeigt den Originaltag nach 180 Simulationsminuten |
| Simulationsteil im ausgelieferten ZIP | Alle 1.077 Dateien aus simSharpSimulation/ bytegleich zum hochgeladenen PraxisMitGodot.zip; keine Datei ergänzt oder entfernt |
| C#-Anbindung der Visualisierung | SimulationBridge.cs, Anbindung/*.cs und Projektverweise unverändert |

## Grenzen

Die vorhandene Standardkonfiguration erzeugt keine Miss-Fälle. Der räumliche Abbruchpfad wird daher mit einer gezielten Ereignisfolge geprüft. Die Prognose-, Ressourcen- und Behandlungslogik verbleibt vollständig im Originalkern.

Die räumliche Prüfung tastet die dargestellten Wege gegen die Wände ab. Sie ist keine physikalische Kollisionssimulation zwischen Personen. Die Bewegungen werden innerhalb der unveränderten Originalwegezeiten interpoliert. Das gemeinsame Wartezimmer und zusätzliche Plätze im Flur sind ausschließlich grafische Zuordnungen.

Die drei sichtbaren Arbeitsplätze im Schwesternzimmer gehören zum gelieferten 3D-Raumplan. Der Raumgenerator baut den Grundriss nicht anhand beliebiger späterer Konfigurationsänderungen neu auf. Zwei Ärzte werden je einem Zimmer zugewiesen; zusätzliche Ärzte teilen sich die vorhandenen Räume.

Beim ersten FBX-Import meldet Godot die bereits im Ausgangsprojekt fehlende PSD-Textur. Zur Laufzeit erhalten die Figuren ihr eigenes blaues Material. Die Figuren und Animationen wurden erfolgreich ausgeführt und grafisch geprüft.

Die Windows-Startdatei bleibt erhalten. Ausgeführt wurde unter Linux; das ursprüngliche WPF-Fenster und der vorhandene Server wurden nicht verändert und nicht neu funktional geprüft.

## Nachweise

Die aktuellen Laufprotokolle liegen unter Pruefnachweise/3D/. Ältere Protokolle im übergeordneten Ordner gehören zum vorherigen 2D-Stand. Originaldateien.sha256.json und Original_pruefen.py prüfen den vollständigen Originalordner vor einem eigenen Build.

Der Simulationsordner wird beim Verpacken direkt aus dem unangetasteten Upload übernommen. Dadurch bleiben auch die ursprünglich enthaltenen generierten Dateien unverändert. Ein eigener Build verändert anschließend wie üblich generierte Dateien unter bin/ und obj/.
