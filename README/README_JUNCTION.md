# Junction-Link für simSharpSimulation

## Zweck

Die Datei [PraxisMitGodot.slnx](../PraxisMitGodot.slnx) verweist relativ auf:

```text
simSharpSimulation/PraxisSimulation.Core/PraxisSimulation.Core.csproj
```

Das eigentliche SimSharp-Repository liegt lokal unter:

```text
C:\home\simSharpSimulation
```

Damit beide Verzeichnisstrukturen zusammenpassen, verweist der lokale Ordner

```text
C:\home\PraxisMitGodot\simSharpSimulation
```

per Junction auf:

```text
C:\home\simSharpSimulation
```

## Link prüfen

```powershell
Get-Item C:\home\PraxisMitGodot\simSharpSimulation | Select-Object FullName,LinkType,Target
```

Erwartetes Ergebnis:

```text
LinkType : Junction
Target   : C:\home\simSharpSimulation
```

## Projekte prüfen

```powershell
Get-ChildItem C:\home\PraxisMitGodot\simSharpSimulation -Recurse -Filter *.csproj
```

Mindestens diese Dateien müssen erscheinen:

```text
C:\home\PraxisMitGodot\simSharpSimulation\PraxisSimulation.Core\PraxisSimulation.Core.csproj
C:\home\PraxisMitGodot\simSharpSimulation\PraxisSimulation.Server\PraxisSimulation.Server.csproj
```

## Wichtiger Hinweis

Ein Junction-Link ist eine lokale Windows-Verknüpfung. Er ist normalerweise
nicht in GitHub enthalten und funktioniert auf einem anderen Computer nicht
automatisch.

Das Zielverzeichnis `C:\home\simSharpSimulation` muss deshalb auf dem Computer
vorhanden sein. Beim Klonen des Hauptrepositories muss der Link gegebenenfalls
erneut eingerichtet werden.

## Junction neu einrichten

Nur ausführen, wenn der Zielordner `C:\home\PraxisMitGodot\simSharpSimulation`
leer ist oder entfernt werden darf:

```powershell
$link = 'C:\home\PraxisMitGodot\simSharpSimulation'
$target = 'C:\home\simSharpSimulation'
Remove-Item -LiteralPath $link -Force
New-Item -ItemType Junction -Path $link -Target $target
```

Danach die Projekte prüfen und den Build ausführen:

```powershell
cd C:\home\PraxisMitGodot
dotnet build .\PraxisMitGodot.slnx -m:1
```

