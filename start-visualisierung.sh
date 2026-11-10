#!/usr/bin/env bash
set -euo pipefail
praxis_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
praxis_godot="${1:-godot}"
cd "$praxis_root"
dotnet build "$praxis_root/Praxis.Visualisierung/Praxis.Visualisierung.csproj" -m:1
"$praxis_godot" --headless --editor --path "$praxis_root/Praxis.Visualisierung" --import
exec "$praxis_godot" --path "$praxis_root/Praxis.Visualisierung"
