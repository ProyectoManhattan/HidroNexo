"""Asigna la vulnerabilidad base de cada zona a partir de los perfiles territoriales.

    python3 data/scripts/asignar_vulnerabilidad.py

Lee data/perfiles/perfiles_territoriales.json y escribe en data/colonias_veracruz.geojson:
    vulnerabilidad        = susceptibilidad física preliminar / 100   (0–1)
    vulnerabilidad_fuente = "modelada"

La susceptibilidad es el índice relativo (elevación relativa, HAND, pendiente, distancia al
cauce y al mar, acumulación de flujo) ya calculado en los perfiles. Es una hipótesis de diseño,
relativa a estas 101 zonas: mide exposición física, NO vulnerabilidad social (faltan INEGI/CONAPO).
Una zona sin índice conserva 0.5 y fuente "ejemplo". Es idempotente.
"""
import json
import sys
from pathlib import Path

DATA = Path(__file__).resolve().parents[1]
PERFILES = DATA / "perfiles" / "perfiles_territoriales.json"
ZONAS = DATA / "colonias_veracruz.geojson"
NEUTRO = 0.5


def main() -> None:
    perfiles = {
        p["id_poligono"]: p["indicadores"]["susceptibilidad"]["indice_preliminar"]
        for p in json.loads(PERFILES.read_text(encoding="utf-8"))["perfiles"]
    }
    geo = json.loads(ZONAS.read_text(encoding="utf-8"))
    modeladas = 0
    for f in geo["features"]:
        p = f["properties"]
        indice = perfiles.get(p["codigo_postal"])
        if indice is None:
            p["vulnerabilidad"], p["vulnerabilidad_fuente"] = NEUTRO, "ejemplo"
            continue
        p["vulnerabilidad"] = round(min(max(indice / 100, 0.0), 1.0), 3)
        p["vulnerabilidad_fuente"] = "modelada"
        modeladas += 1
    ZONAS.write_text(json.dumps(geo, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{modeladas}/{len(geo['features'])} zonas con vulnerabilidad modelada", file=sys.stderr)


if __name__ == "__main__":
    main()
