"""Genera data/colonias_veracruz.geojson con límites reales.

Fuentes (ambas MIT):
- Zonas por código postal: https://github.com/open-mexico/mexico-geojson, archivo 30-Ver.geojson.
  Sus polígonos vienen de SEPOMEX/Correos de México y son **por código postal**, no por colonia:
  cada zona agrupa varias colonias y no trae nombres ni municipio. Aquí se usa "C.P. NNNNN".
- Límites municipales: https://github.com/PhantomInsights/mexico-geojson (CONABIO, a partir del
  Marco Geoestadístico de INEGI), con la clave oficial CVEGEO.

Cada código postal se asigna al municipio que contiene un punto interior suyo, y se conservan los
de MUNICIPIOS. Un código postal no siempre respeta el límite municipal: si cruza uno, queda en el
municipio donde cae su punto interior.

La vulnerabilidad NO es real: todas las zonas llevan 0.5 con vulnerabilidad_fuente="ejemplo"
hasta tener el atlas de riesgos municipal o datos de Protección Civil.

Uso (desde la raíz del repositorio):
    python3 data/scripts/generar_colonias.py [ruta_30-Ver.geojson ruta_municipios_ver.json]
Sin argumentos descarga los archivos.
"""
import json
import sys
import urllib.request
from pathlib import Path

URL_CP = "https://raw.githubusercontent.com/open-mexico/mexico-geojson/master/30-Ver.geojson"
URL_MUNICIPIOS = (
    "https://raw.githubusercontent.com/PhantomInsights/mexico-geojson/main/2020/states/"
    "Veracruz%20de%20Ignacio%20de%20la%20Llave.json"
)
SALIDA = Path(__file__).resolve().parent.parent / "colonias_veracruz.geojson"

# Municipios incluidos (CVEGEO de INEGI -> nombre). Para ampliar la zona, añadir aquí.
MUNICIPIOS = {
    "30193": "Veracruz",
    "30028": "Boca del Río",
    "30105": "Medellín de Bravo",
}

VULNERABILIDAD_EJEMPLO = 0.5


def poligonos(geom: dict) -> list:
    return [geom["coordinates"]] if geom["type"] == "Polygon" else geom["coordinates"]


def en_anillo(x: float, y: float, anillo: list) -> bool:
    dentro = False
    for i in range(len(anillo)):
        x1, y1 = anillo[i]
        x2, y2 = anillo[(i + 1) % len(anillo)]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            dentro = not dentro
    return dentro


def en_geometria(x: float, y: float, geom: dict) -> bool:
    return any(
        en_anillo(x, y, poli[0]) and not any(en_anillo(x, y, hueco) for hueco in poli[1:])
        for poli in poligonos(geom)
    )


def punto_interior(geom: dict) -> tuple[float, float]:
    """Punto dentro del polígono: mitad del tramo interior más largo de una línea horizontal.

    (El centroide puede caer fuera en polígonos irregulares.)
    """
    mejor = None
    for poli in poligonos(geom):
        ys = [p[1] for p in poli[0]]
        alto = max(ys) - min(ys)
        for fraccion in (0.5, 0.4, 0.6, 0.3, 0.7):
            y = min(ys) + fraccion * alto
            cortes = []
            for anillo in poli:
                for i in range(len(anillo)):
                    x1, y1 = anillo[i]
                    x2, y2 = anillo[(i + 1) % len(anillo)]
                    if (y1 > y) != (y2 > y):
                        cortes.append((x2 - x1) * (y - y1) / (y2 - y1) + x1)
            cortes.sort()
            for a, b in zip(cortes[0::2], cortes[1::2]):
                if mejor is None or b - a > mejor[0]:
                    mejor = (b - a, (a + b) / 2, y)
            if mejor:
                break
    if mejor is None:
        raise ValueError("polígono sin área")
    return mejor[1], mejor[2]


def redondear(coords):
    if isinstance(coords[0], (int, float)):
        return [round(coords[0], 5), round(coords[1], 5)]
    return [redondear(c) for c in coords]


def cargar(origen: str | None, url: str) -> dict:
    if origen:
        return json.loads(Path(origen).read_text(encoding="utf-8"))
    with urllib.request.urlopen(url, timeout=180) as r:
        return json.load(r)


def main() -> None:
    cps = cargar(sys.argv[1] if len(sys.argv) > 2 else None, URL_CP)
    munis = cargar(sys.argv[2] if len(sys.argv) > 2 else None, URL_MUNICIPIOS)

    limites = {
        m["properties"]["CVEGEO"]: m["geometry"]
        for m in munis["features"]
        if m["properties"]["CVEGEO"] in MUNICIPIOS
    }
    faltan = set(MUNICIPIOS) - set(limites)
    if faltan:
        sys.exit(f"No se encontraron los municipios {sorted(faltan)} en el archivo de límites")

    features = []
    for f in cps["features"]:
        x, y = punto_interior(f["geometry"])
        clave = next((c for c, g in limites.items() if en_geometria(x, y, g)), None)
        if clave is None:
            continue
        cp = str(f["properties"]["d_codigo"]).zfill(5)
        geom = {"type": f["geometry"]["type"], "coordinates": redondear(f["geometry"]["coordinates"])}
        props = {
            "nombre": f"C.P. {cp}",
            "codigo_postal": cp,
            "municipio": MUNICIPIOS[clave],
            "vulnerabilidad": VULNERABILIDAD_EJEMPLO,
            "vulnerabilidad_fuente": "ejemplo",
        }
        features.append({"type": "Feature", "properties": props, "geometry": geom})

    features.sort(key=lambda f: f["properties"]["codigo_postal"])
    SALIDA.write_text(
        json.dumps({"type": "FeatureCollection", "features": features}, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    por_municipio = {n: sum(1 for f in features if f["properties"]["municipio"] == n) for n in MUNICIPIOS.values()}
    print(f"{len(features)} zonas -> {SALIDA} ({SALIDA.stat().st_size // 1024} KB) {por_municipio}")


if __name__ == "__main__":
    main()
