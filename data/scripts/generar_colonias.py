"""Genera data/colonias_veracruz.geojson con límites reales.

Fuente: https://github.com/open-mexico/mexico-geojson (licencia MIT), archivo 30-Ver.geojson.
Sus polígonos vienen de SEPOMEX/Correos de México y son **por código postal**, no por colonia:
cada zona agrupa varias colonias y no trae nombres. Aquí se usa "C.P. NNNNN" como nombre.

La vulnerabilidad NO es real: todas las zonas llevan 0.5 con vulnerabilidad_fuente="ejemplo"
hasta tener el atlas de riesgos municipal o datos de Protección Civil.

Uso (desde la raíz del repositorio):
    python3 data/scripts/generar_colonias.py [ruta_local_a_30-Ver.geojson]
Sin argumento descarga el archivo.
"""
import json
import sys
import urllib.request
from pathlib import Path

URL = "https://raw.githubusercontent.com/open-mexico/mexico-geojson/master/30-Ver.geojson"
SALIDA = Path(__file__).resolve().parent.parent / "colonias_veracruz.geojson"

# Zona urbana de Veracruz y Boca del Río (centroide del polígono dentro de este recuadro)
LON_MIN, LON_MAX = -96.25, -96.07
LAT_MIN, LAT_MAX = 19.09, 19.24

VULNERABILIDAD_EJEMPLO = 0.5


def centroide(geom: dict) -> tuple[float, float]:
    polis = [geom["coordinates"]] if geom["type"] == "Polygon" else geom["coordinates"]
    pts = [p for poli in polis for p in poli[0]]
    return sum(x for x, _ in pts) / len(pts), sum(y for _, y in pts) / len(pts)


def redondear(coords):
    if isinstance(coords[0], (int, float)):
        return [round(coords[0], 5), round(coords[1], 5)]
    return [redondear(c) for c in coords]


def main() -> None:
    if len(sys.argv) > 1:
        datos = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    else:
        with urllib.request.urlopen(URL, timeout=120) as r:
            datos = json.load(r)

    features = []
    for f in datos["features"]:
        x, y = centroide(f["geometry"])
        if not (LON_MIN <= x <= LON_MAX and LAT_MIN <= y <= LAT_MAX):
            continue
        cp = str(f["properties"]["d_codigo"]).zfill(5)
        geom = {"type": f["geometry"]["type"], "coordinates": redondear(f["geometry"]["coordinates"])}
        props = {
            "nombre": f"C.P. {cp}",
            "codigo_postal": cp,
            "vulnerabilidad": VULNERABILIDAD_EJEMPLO,
            "vulnerabilidad_fuente": "ejemplo",
        }
        if cp[:3] in ("916", "917", "918", "919"):
            props["municipio"] = "Veracruz"
        features.append({"type": "Feature", "properties": props, "geometry": geom})

    features.sort(key=lambda f: f["properties"]["codigo_postal"])
    SALIDA.write_text(
        json.dumps({"type": "FeatureCollection", "features": features}, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"{len(features)} zonas -> {SALIDA} ({SALIDA.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
