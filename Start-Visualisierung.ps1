param([string]$GodotPfad = "godot")
$ErrorActionPreference = "Stop"
$Projekt = Join-Path $PSScriptRoot "Praxis.Visualisierung"
Push-Location $PSScriptRoot
try {
    & dotnet build (Join-Path $Projekt "Praxis.Visualisierung.csproj") -m:1
    if ($LASTEXITCODE -ne 0) { throw "Der .NET-Build ist fehlgeschlagen." }
    & $GodotPfad --headless --editor --path $Projekt --import
    if ($LASTEXITCODE -ne 0) { throw "Der Godot-Import ist fehlgeschlagen." }
    & $GodotPfad --path $Projekt
    if ($LASTEXITCODE -ne 0) { throw "Godot konnte nicht gestartet werden." }
}
finally { Pop-Location }
