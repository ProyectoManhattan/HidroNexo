"""Carga de datos y controles de calidad de entrada."""
import json

import geopandas as gpd
import pandas as pd
import shapely
from shapely.validation import explain_validity

from . import config
from .calidad import Bitacora


def poligonos(bitacora: Bitacora) -> gpd.GeoDataFrame:
    """Polígonos originales + columna `geom_calculo` (válida) para los cálculos.

    La geometría original NO se modifica; solo se corrige una copia para medir.
    """
    crudo = json.loads(config.POLIGONOS.read_text(encoding="utf-8"))
    if "crs" in crudo:
        bitacora.registrar("crs", f"El GeoJSON declara CRS {crudo['crs']}")
    else:
        bitacora.registrar("crs", "El GeoJSON no declara CRS; se asume EPSG:4326 (estándar RFC 7946)")
    g = gpd.read_file(config.POLIGONOS)
    if g.crs is None:
        g = g.set_crs(config.CRS_GEO)
    g["id_poligono"] = g["codigo_postal"].astype(str)

    for _, r in g[g["id_poligono"].duplicated(keep=False)].iterrows():
        bitacora.registrar("duplicado", "ID de polígono repetido", r.id_poligono)
    for _, r in g.iterrows():
        geom = r.geometry
        if geom is None or geom.is_empty:
            bitacora.registrar("geometria_vacia", "Geometría vacía", r.id_poligono)
            continue
        if not geom.is_valid:
            bitacora.registrar("geometria_invalida", explain_validity(geom) + " (corregida con make_valid solo para calcular)", r.id_poligono)
        minx, miny, maxx, maxy = geom.bounds
        if not (-118.5 <= minx <= maxx <= -86 and 14 <= miny <= maxy <= 33):
            bitacora.registrar("coordenada_invalida", "Coordenadas fuera de México", r.id_poligono)

    g["geom_calculo"] = shapely.make_valid(g.geometry.values)
    # make_valid puede devolver colecciones; nos quedamos con la parte poligonal
    g["geom_calculo"] = [
        shapely.union_all([p for p in getattr(x, "geoms", [x]) if p.geom_type in ("Polygon", "MultiPolygon")])
        for x in g["geom_calculo"]
    ]
    return g


def catalogo_estaciones(bitacora: Bitacora) -> pd.DataFrame:
    c = pd.read_csv(config.CONAGUA / "CATALOGO_SIH.csv", encoding="utf-8-sig", dtype={"estacion": str})
    dup = c["estacion"].duplicated().sum()
    if dup:
        bitacora.registrar("duplicado", f"{dup} IDs de estación repetidos en el catálogo")
    cero = (c["latitud"] == 0) & (c["longitud"] == 0)
    fuera = ~cero & ~(c["latitud"].between(14, 33) & c["longitud"].between(-118.5, -86))
    c["coordenada_valida"] = ~(cero | fuera)
    bitacora.registrar("coordenada_invalida", f"{int(cero.sum())} estaciones del catálogo con coordenadas (0, 0); se excluyen de la asociación")
    if fuera.sum():
        bitacora.registrar("coordenada_invalida", f"{int(fuera.sum())} estaciones del catálogo con coordenadas fuera de México; se excluyen", ejemplos=c.loc[fuera, "estacion"].head(10).tolist())
    return c


def precipitacion(bitacora: Bitacora) -> pd.DataFrame:
    p = pd.read_csv(config.CONAGUA / "PRECIPITACION_HORA.csv", encoding="utf-8-sig", dtype={"estacionID": str})
    p = p.rename(columns={"estacionID": "estacion", "precipitacio": "precipitacion_mm"})
    p["fecha"] = pd.to_datetime(p["fecha"], errors="coerce")
    if p["fecha"].isna().any():
        bitacora.registrar("fecha_faltante", f"{int(p['fecha'].isna().sum())} registros de precipitación sin fecha válida")
    dup = p.duplicated(["estacion", "fecha"]).sum()
    if dup:
        bitacora.registrar("duplicado", f"{dup} registros de precipitación repetidos (estación + fecha)")
    p["valido"] = p["precipitacion_mm"].between(0, config.PRECIP_MAX_INTERVALO_MM)
    malos = p[~p["valido"]]
    for est, grupo in malos.groupby("estacion"):
        bitacora.registrar(
            "valor_inconsistente",
            f"Estación {est}: {len(grupo)} registros de precipitación fuera de [0, {config.PRECIP_MAX_INTERVALO_MM}] mm "
            f"(mín {grupo.precipitacion_mm.min()}, máx {grupo.precipitacion_mm.max()}); se conservan pero se excluyen de los acumulados",
        )
    intervalos = p.sort_values(["estacion", "fecha"]).groupby("estacion")["fecha"].diff().dt.total_seconds().div(60)
    bitacora.registrar(
        "frecuencia",
        "Pese al nombre PRECIPITACION_HORA, los intervalos entre registros van de "
        f"{intervalos.min():.0f} a {intervalos.max():.0f} min (mediana {intervalos.median():.0f}); "
        "se tratan como incrementos por intervalo, no como intensidades horarias",
    )
    return p


def niveles(bitacora: Bitacora) -> pd.DataFrame:
    n = pd.read_csv(config.CONAGUA / "NIVEL_RIOS_DIA.csv", encoding="utf-8-sig", dtype={"estacionID": str}).dropna(how="all")
    n = n.rename(columns={"estacionID": "estacion"})
    n["fecha"] = pd.to_datetime(n["fecha"], errors="coerce")
    neg = n[n["nivel"] < 0]
    if len(neg):
        bitacora.registrar(
            "valor_revisar",
            f"{len(neg)} niveles negativos ({', '.join(neg.estacion)}); pueden ser válidos según la referencia de la escala, se conservan",
        )
    bitacora.registrar(
        "unidades",
        "NIVEL_RIOS_DIA mezcla magnitudes (de −1.1 a 2 561): probablemente elevación del agua (msnm) en unas estaciones y "
        "lectura de escala local en otras; sin metadatos no se comparan niveles entre estaciones",
    )
    return n
