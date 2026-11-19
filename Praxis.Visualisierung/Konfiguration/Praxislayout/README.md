# Vorhandenes Praxislayout

Die Dateien teilen nur vorhandene Angaben auf. Sie fuegen keine neuen Raeume
oder Funktionen hinzu.

| Gesuchte Information | Datei |
| --- | --- |
| Raum-ID, Position und Groesse | jeweilige Datei unter [Raeume/](./Raeume/) |
| Arbeits- und Warteplaetze | jeweilige Raumdatei |
| Moebel und Raumbeschriftung | jeweilige Raumdatei |
| Tuerposition und verbundene Raeume | [tueren.json](./tueren.json) |
| Wandanfang, Wandende und Oeffnungen | [waende.json](./waende.json) |
| Bisherige Stationspositionen | [navigation.json](./navigation.json) |
| Gesamtboden, Wandmasse und Raumdateiliste | [layout.json](./layout.json) |

Zum Lesen beispielsweise mit [arzt1.json](./Raeume/arzt1.json) beginnen:
`arbeitsplaetze` und `warteplaetze` stehen direkt bei ihrem Raum.
`tueren` enthaelt IDs, die auf die zentrale Tuerdatei verweisen.
Eine Tuer hat zwei Seiten; deshalb wird sie nur einmal zentral beschrieben.

Alle Koordinaten sind weiterhin absolut. `[x, z]` ist eine Position im Grundriss;
`[x, y, z]` enthaelt zusaetzlich die Hoehe. Bei `groesse` steht der zweite Wert
fuer die Bodendicke, nicht fuer die Raumhoehe.

Die bestehenden Wege bleiben in [RaumWege.gd](../../Raum3D/RaumWege.gd).
Automatische Wege durch zusaetzliche Raeume werden erst spaeter entwickelt.
