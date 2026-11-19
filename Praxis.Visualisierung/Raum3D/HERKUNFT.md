# Herkunft des 3D-Grundrisses

[Praxis.gd](./Praxis.gd) wurde urspruenglich bytegleich aus `arztpraxis.zip`, Datei `arztpraxis/scripts/praxis.gd`, uebernommen. Bei der Strukturierung wurden die vorhandenen Raumdaten nach [Praxislayout/](../Konfiguration/Praxislayout/) und der Moebelcode nach [Ausstattung.gd](./Ausstattung/Ausstattung.gd) ausgelagert. Masse, Farben und Positionen bleiben erhalten. [Praxis.tscn](./Praxis.tscn) bindet den Generator weiterhin ein.

Kamera, Licht, Raumbeschriftung und Patienten werden weiterhin durch [Main.gd](../Main.gd) verbunden; der UI-Aufbau liegt in [Steuerung.gd](../UI/Steuerung.gd). Die bisherigen Raumwege liegen in [RaumWege.gd](./RaumWege.gd), die Ereignisauswertung und Behandlungspositionen in [PatientenTimeline.gd](../Patienten/PatientenTimeline.gd). Der Simulationskern wurde fuer die Umstrukturierung nicht geaendert.
