"""Prüft den unveränderten Auslieferungszustand des vollständigen Originalordners."""
from pathlib import Path
import hashlib
import json
import sys

root = Path(__file__).resolve().parent
original = root / "simSharpSimulation"
soll = json.loads((root / "Originaldateien.sha256.json").read_text(encoding="utf-8"))
ist = {p.relative_to(original).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
       for p in original.rglob("*") if p.is_file()}
abweichungen = sorted(name for name in set(soll) | set(ist) if soll.get(name) != ist.get(name))
if abweichungen:
    print("Abweichungen vom Auslieferungszustand:")
    print("\n".join(abweichungen))
    sys.exit(1)
print(f"BESTANDEN: Alle {len(soll)} Originaldateien sind bytegleich; keine Dateien ergänzt oder entfernt.")
