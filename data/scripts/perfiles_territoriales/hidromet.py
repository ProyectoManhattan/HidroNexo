"""Asociación de estaciones CONAGUA a polígonos y resumen de observaciones.

Una estación NO representa las condiciones de un polígono: solo se reporta la más cercana con su
distancia, y los valores a nivel polígono quedan en null si la cobertura es insuficiente.
"""
import geopandas as gpd
import pandas as pd

from . import config
from .calidad import Bitacora


def _cobertura(dist_km: float | None) -> str:
    if dist_km is None:
        return "sin_estaciones"
    if dist_km <= config.COBERTURA_ADECUADA_KM:
        return "adecuada"
    if dist_km <= config.COBERTURA_LIMITADA_KM:
        return "limitada"
    return "insuficiente"


def _acumulados(serie: pd.DataFrame) -> dict:
    """Suma de incrementos válidos en ventanas que terminan en la última observación."""
    serie = serie.sort_values("fecha")
    fin = serie["fecha"].max()
    inicio_datos = serie["fecha"].min()
    validos = serie[serie["valido"]]
    r = {"ultima_observacion": fin.isoformat(), "primera_observacion": inicio_datos.isoformat(),
         "registros": int(len(serie)), "registros_invalidos": int((~serie["valido"]).sum())}
    for horas in (1, 3, 24):
        desde = fin - pd.Timedelta(hours=horas)
        ventana = validos[(validos["fecha"] > desde) & (validos["fecha"] <= fin)]
        r[f"precipitacion_{horas}h_mm"] = round(float(ventana["precipitacion_mm"].sum()), 2)
        # La ventana está completa si hay datos desde su inicio (con 30 min de tolerancia)
        r[f"ventana_{horas}h_completa"] = bool(inicio_datos <= desde + pd.Timedelta(minutes=30))
    return r


class Hidromet:
    def __init__(self, catalogo: pd.DataFrame, precip: pd.DataFrame, niveles: pd.DataFrame, bitacora: Bitacora):
        self.bitacora = bitacora
        validas = catalogo[catalogo["coordenada_valida"]]
        self.estaciones = gpd.GeoDataFrame(
            validas, geometry=gpd.points_from_xy(validas["longitud"], validas["latitud"]), crs=config.CRS_GEO
        ).to_crs(config.CRS_METRICO)
        self.precip = precip
        self.niveles = niveles
        con_precip = set(precip["estacion"])
        con_nivel = set(niveles["estacion"])
        sin_catalogo = sorted((con_precip | con_nivel) - set(catalogo["estacion"]))
        if sin_catalogo:
            bitacora.registrar("estacion_sin_catalogo", f"Estaciones con datos pero sin coordenadas en el catálogo: {', '.join(sin_catalogo)}")
        sin_coord = sorted((con_precip | con_nivel) & set(catalogo.loc[~catalogo["coordenada_valida"], "estacion"]))
        if sin_coord:
            bitacora.registrar("coordenada_invalida", f"{len(sin_coord)} estaciones con datos tienen coordenadas inválidas en el catálogo y no se pueden asociar")
        self.est_precip = self.estaciones[self.estaciones["estacion"].isin(con_precip)]
        self.est_nivel = self.estaciones[self.estaciones["estacion"].isin(con_nivel)]
        self.resumen_precip = {e: _acumulados(s) for e, s in precip.groupby("estacion")}
        self.fecha_datos = max(precip["fecha"].max(), niveles["fecha"].max())

    def _cercanas(self, geom_metrica, estaciones: gpd.GeoDataFrame) -> pd.DataFrame:
        d = estaciones.distance(geom_metrica) / 1000
        return estaciones.assign(dist_km=d.round(2)).nsmallest(config.MAX_ESTACIONES_REPORTADAS, "dist_km")

    def para_poligono(self, id_poligono: str, geom_metrica) -> dict:
        antiguedad = (pd.Timestamp(config.FECHA_PROCESO).tz_localize(None) - self.fecha_datos).days
        desactualizado = antiguedad > config.DESACTUALIZADO_DIAS

        meteo = []
        for _, e in self._cercanas(geom_metrica, self.est_precip).iterrows():
            meteo.append({
                "estacion": e.estacion, "nombre": e.nombre,
                "latitud": e.latitud, "longitud": e.longitud,
                "distancia_km": float(e.dist_km),
                "metodo_distancia": "distancia mínima de la estación al borde del polígono (UTM 14N)",
                **self.resumen_precip.get(e.estacion, {}),
            })
        hidro = []
        for _, e in self._cercanas(geom_metrica, self.est_nivel).iterrows():
            fila = self.niveles[self.niveles["estacion"] == e.estacion].sort_values("fecha")
            hidro.append({
                "estacion": e.estacion, "nombre": e.nombre,
                "latitud": e.latitud, "longitud": e.longitud,
                "distancia_km": float(e.dist_km),
                "nivel": float(fila["nivel"].iloc[-1]),
                "unidad_nivel": "desconocida (sin metadatos; probablemente m)",
                "fecha_nivel": fila["fecha"].iloc[-1].isoformat(),
                "registros": int(len(fila)),
                "tendencia": None,
                "motivo_tendencia_null": "solo hay un registro por estación" if len(fila) < 2 else None,
            })
        # Estaciones del catálogo cercanas que NO tienen datos en los archivos disponibles
        cat_cerca = self.estaciones[self.estaciones.distance(geom_metrica) <= config.COBERTURA_ADECUADA_KM * 1000]
        sin_datos = cat_cerca[~cat_cerca["estacion"].isin(set(self.precip["estacion"]) | set(self.niveles["estacion"]))]

        dist_meteo = meteo[0]["distancia_km"] if meteo else None
        cobertura = _cobertura(dist_meteo)
        if cobertura == "insuficiente":
            self.bitacora.registrar("estacion_lejana", f"La estación con precipitación más cercana está a {dist_meteo} km", id_poligono)
        cercana = meteo[0] if meteo else None
        usar = cercana is not None and cobertura in ("adecuada", "limitada")
        hidro0 = hidro[0] if hidro else None
        return {
            "cobertura_meteorologica": cobertura,
            "estacion_meteorologica_cercana": cercana["estacion"] if cercana else None,
            "nombre_estacion_meteorologica": cercana["nombre"] if cercana else None,
            "distancia_estacion_km": dist_meteo,
            "ultima_observacion": cercana["ultima_observacion"] if cercana else None,
            # Valores a nivel polígono: solo con cobertura adecuada o limitada
            "precipitacion_1h_mm": cercana["precipitacion_1h_mm"] if usar else None,
            "precipitacion_3h_mm": cercana["precipitacion_3h_mm"] if usar else None,
            "precipitacion_24h_mm": cercana["precipitacion_24h_mm"] if usar else None,
            "precipitacion_acumulada_mm": None,
            "motivo_precipitacion_null": None if usar else (
                f"cobertura {cobertura}: la estación más cercana está a {dist_meteo} km" if cercana else "sin estaciones con datos"
            ),
            "estacion_hidrometrica_cercana": hidro0["estacion"] if hidro0 else None,
            "nombre_estacion_hidrometrica": hidro0["nombre"] if hidro0 else None,
            "distancia_estacion_hidrometrica_km": hidro0["distancia_km"] if hidro0 else None,
            "nivel_rio": hidro0["nivel"] if hidro0 else None,
            "fecha_nivel_rio": hidro0["fecha_nivel"] if hidro0 else None,
            "tendencia_nivel_rio": None,
            "datos_historicos": desactualizado,
            "antiguedad_dias": int(antiguedad),
            "aviso": (f"Datos históricos del {self.fecha_datos.date()} ({antiguedad} días antes del procesamiento); "
                      "no representan condiciones actuales") if desactualizado else None,
            "estaciones_meteorologicas": meteo,
            "estaciones_hidrometricas": hidro,
            "estaciones_catalogo_cercanas_sin_datos": sin_datos["estacion"].tolist(),
        }
