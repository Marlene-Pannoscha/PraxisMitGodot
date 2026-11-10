# Herkunft des 3D-Grundrisses

`Praxis.gd` wurde bytegleich aus `arztpraxis.zip`, Datei `arztpraxis/scripts/praxis.gd`, übernommen. Es erzeugt die Räume, Türen, Wände und Möbel. `Praxis.tscn` bindet diesen Generator in das größere Visualisierungsprojekt ein.

Kamera, Licht, Raumbeschriftung, Patienten und Bedienoberfläche werden von `Main.gd` ergänzt. Die räumlichen Wege und Behandlungspositionen liegen in `PatientenTimeline.gd`. Die vorhandene C#-Anbindung und der gesamte Ordner `simSharpSimulation/` wurden für den 3D-Umbau nicht verändert.
