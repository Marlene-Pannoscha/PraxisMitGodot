param([string]$GodotPfad = "godot")
$ErrorActionPreference = "Stop"
$Projekt = Join-Path $PSScriptRoot "Praxis.Visualisierung"
$ServerProjekt = Join-Path $PSScriptRoot "simSharpSimulation\PraxisSimulation.Server\PraxisSimulation.Server.csproj"
$ServerAdresse = "http://localhost:5080"
$ServerProzess = $null
$ServerSelbstGestartet = $false
Push-Location $PSScriptRoot
try {
    & dotnet build (Join-Path $Projekt "Praxis.Visualisierung.csproj") -m:1
    if ($LASTEXITCODE -ne 0) { throw "Der .NET-Build ist fehlgeschlagen." }
    try {
        Invoke-RestMethod "$ServerAdresse/health" -TimeoutSec 1 | Out-Null
    }
    catch {
        $ServerProzess = Start-Process -FilePath "dotnet" -ArgumentList @(
            "run", "--project", $ServerProjekt, "--urls", $ServerAdresse
        ) -PassThru -WindowStyle Hidden
        $ServerSelbstGestartet = $true
        $Bereit = $false
        for ($Versuch = 0; $Versuch -lt 60; $Versuch++) {
            if ($ServerProzess.HasExited) { throw "Der SimSharp-WebSocket-Server wurde unerwartet beendet." }
            try {
                Invoke-RestMethod "$ServerAdresse/health" -TimeoutSec 1 | Out-Null
                $Bereit = $true
                break
            }
            catch { Start-Sleep -Milliseconds 250 }
        }
        if (-not $Bereit) { throw "Der SimSharp-WebSocket-Server ist nicht rechtzeitig bereit geworden." }
    }
    & $GodotPfad --headless --editor --path $Projekt --import
    if ($LASTEXITCODE -ne 0) { throw "Der Godot-Import ist fehlgeschlagen." }
    & $GodotPfad --editor --path $Projekt
    if ($LASTEXITCODE -ne 0) { throw "Der Godot-Editor konnte nicht gestartet werden." }
}
finally {
    if ($ServerSelbstGestartet -and $null -ne $ServerProzess -and -not $ServerProzess.HasExited) {
        Stop-Process -Id $ServerProzess.Id
    }
    Pop-Location
}
