"""Orquesta el procesamiento: carga → geoespacial → hidromet → indicadores → perfiles."""
from datetime import datetime, timezone

import geopandas as gpd
import pandas as pd

from . import carga, config, geoespacial, hidromet, indicadores, perfiles
from .calidad import Bitacora


def _fecha_archivo(ruta):
    return datetime.fromtimestamp(ruta.stat().st_mtime, timezone.utc).replace(microsecond=0).isoformat()


def ejecutar() -> dict:
    bit = Bitacora()
    g = carga.poligonos(bit)
    cat = carga.catalogo_estaciones(bit)
    prec = carga.precipitacion(bit)
    niv = carga.niveles(bit)

    ident = geoespacial.identificacion(g)
    terreno = geoespacial.Terreno(g, bit)
    metrico = gpd.GeoSeries(g["geom_calculo"], crs=g.crs).to_crs(config.CRS_METRICO)
    geo = {r.id_poligono: terreno.estadisticas(r.id_poligono, metrico.iloc[i]) for i, r in g.iterrows()}
    costa = geoespacial.distancia_costa_natural_earth(g)
    hm = hidromet.Hidromet(cat, prec, niv, bit)
    hid = {r.id_poligono: hm.para_poligono(r.id_poligono, metrico.iloc[i]) for i, r in g.iterrows()}

    # Controles de consistencia física (se marcan, no se eliminan)
    for pid, d in geo.items():
        if (d.get("elevacion_maxima_m") or 0) > 300:
            bit.registrar("valor_revisar", f"Elevación máxima {d['elevacion_maxima_m']} m, inusual para la zona", pid)
        if (d.get("pendiente_maxima_grados") or 0) > 45:
            bit.registrar("valor_revisar", f"Pendiente máxima {d['pendiente_maxima_grados']}°: probable borde de edificio o talud en el DSM", pid)

    tabla = pd.DataFrame({
        pid: {
            "elevacion_relativa_m": d.get("elevacion_relativa_m"),
            "hand_mediana_m": d.get("hand_mediana_m"),
            "pendiente_media_grados": d.get("pendiente_media_grados"),
            "distancia_cauce_mayor_m": d.get("distancias_m", {}).get("cauce_mayor_modelado"),
            "acumulacion_flujo_max_km2": d.get("acumulacion_flujo_max_km2"),
            "distancia_mar_m": d.get("distancias_m", {}).get("mar"),
            "precipitacion_1h_mm": hid[pid]["precipitacion_1h_mm"],
            "precipitacion_3h_mm": hid[pid]["precipitacion_3h_mm"],
            "precipitacion_24h_mm": hid[pid]["precipitacion_24h_mm"],
        } for pid, d in geo.items()
    }).T.apply(pd.to_numeric, errors="coerce")
    norm = indicadores.normalizar(tabla)
    ind = {dim: indicadores.indice_preliminar(norm, dim) for dim in ("susceptibilidad",)}

    lista = []
    for _, r in g.iterrows():
        pid = r.id_poligono
        indices = {dim: {k: (None if pd.isna(v) else (int(v) if k == "n_variables" else v)) for k, v in t.loc[pid].items()}
                   for dim, t in ind.items()}
        lista.append(perfiles.construir(r, ident[pid], geo[pid], costa.get(pid), hid[pid], norm.loc[pid].to_dict(), indices, bit))

    fuentes = {k: dict(v) for k, v in config.FUENTES_DOC.items()}
    fuentes["dem"]["teselas"] = terreno.tiles
    fuentes["dem"]["fecha_descarga"] = _fecha_archivo(config.DEM_DIR / terreno.tiles[0])
    fuentes["natural_earth"]["fecha_descarga"] = _fecha_archivo(config.NATURAL_EARTH / "ne_10m_coastline.geojson")
    for clave, archivo in (("conagua_catalogo", "CATALOGO_SIH.csv"), ("conagua_precipitacion", "PRECIPITACION_HORA.csv"), ("conagua_nivel", "NIVEL_RIOS_DIA.csv")):
        fuentes[clave]["fecha_recepcion"] = _fecha_archivo(config.CONAGUA / archivo)
    fuentes["conagua_precipitacion"]["periodo"] = [prec["fecha"].min().isoformat(), prec["fecha"].max().isoformat()]
    fuentes["conagua_nivel"]["periodo"] = [niv["fecha"].min().isoformat(), niv["fecha"].max().isoformat()]

    return {"g": g, "perfiles": lista, "bitacora": bit, "fuentes": fuentes, "tabla": tabla, "normalizado": norm,
            "hidromet": hm, "terreno": terreno, "precip": prec, "niveles": niv, "catalogo": cat}
