"""Procesamiento geoespacial: identificación, elevación, pendiente, hidrología modelada y distancias.

Todo se calcula en UTM 14N (EPSG:32614) a 30 m. Los cuerpos de agua y cauces se DERIVAN del DEM:
no son cartografía oficial y así se reportan.
"""
import math

import geopandas as gpd
import numpy as np
import rasterio
from rasterio.features import geometry_mask
from rasterio.merge import merge
from rasterio.warp import Resampling, calculate_default_transform, reproject
from scipy import ndimage

from . import config
from .calidad import Bitacora

CELDA_KM2 = (config.RESOLUCION_M ** 2) / 1e6


def identificacion(g: gpd.GeoDataFrame) -> dict[str, dict]:
    metrico = gpd.GeoSeries(g["geom_calculo"], crs=g.crs).to_crs(config.CRS_METRICO)
    centroides = metrico.centroid.to_crs(config.CRS_GEO)
    puntos_interiores = gpd.GeoSeries(g["geom_calculo"], crs=g.crs).representative_point()
    salida = {}
    for i, r in g.iterrows():
        c = centroides.iloc[i]
        salida[r.id_poligono] = {
            "area_km2": round(metrico.iloc[i].area / 1e6, 4),
            "centroide": {"lon": round(c.x, 6), "lat": round(c.y, 6)},
            # El centroide puede caer fuera de un polígono irregular; este punto siempre cae dentro
            "punto_interior": {"lon": round(puntos_interiores.iloc[i].x, 6), "lat": round(puntos_interiores.iloc[i].y, 6)},
            "centroide_dentro_del_poligono": bool(r.geom_calculo.contains(c)),
            "bbox": [round(v, 6) for v in r.geom_calculo.bounds],
            "crs": config.CRS_GEO,
            "crs_calculo": config.CRS_METRICO,
        }
    return salida


class Terreno:
    """Ventana del DEM reproyectada a UTM con derivados hidrológicos."""

    def __init__(self, g: gpd.GeoDataFrame, bitacora: Bitacora):
        self.bitacora = bitacora
        minx, miny, maxx, maxy = g.total_bounds
        m = config.MARGEN_DEM_GRADOS
        tiles = sorted(config.DEM_DIR.glob("Copernicus_DSM_COG_10_*_DEM.tif"))
        if not tiles:
            raise FileNotFoundError(f"No hay teselas del DEM en {config.DEM_DIR}")
        self.tiles = [t.name for t in tiles]
        fuentes = [rasterio.open(t) for t in tiles]
        mosaico, transform_geo = merge(fuentes, bounds=(minx - m, miny - m, maxx + m, maxy + m))
        src_crs = fuentes[0].crs
        alto, ancho = mosaico.shape[1:]
        dst_t, w, h = calculate_default_transform(
            src_crs, config.CRS_METRICO, ancho, alto,
            *rasterio.transform.array_bounds(alto, ancho, transform_geo), resolution=config.RESOLUCION_M,
        )
        dem = np.full((h, w), np.nan, dtype="float32")
        reproject(mosaico[0], dem, src_transform=transform_geo, src_crs=src_crs,
                  dst_transform=dst_t, dst_crs=config.CRS_METRICO, resampling=Resampling.bilinear, dst_nodata=np.nan)
        for f in fuentes:
            f.close()
        self.dem, self.transform, self.forma = dem, dst_t, dem.shape

        self._agua()
        self._pendiente()
        self._hidrologia()

    # ------------------------------------------------------------------ agua derivada del DEM
    def _agua(self):
        bajo = np.nan_to_num(self.dem, nan=0.0) <= 0.0
        etiquetas, n = ndimage.label(bajo)
        borde = np.unique(np.concatenate([etiquetas[0], etiquetas[-1], etiquetas[:, 0], etiquetas[:, -1]]))
        tamanos = ndimage.sum(bajo, etiquetas, index=np.arange(1, n + 1))
        mar_ids = [i for i in borde if i and tamanos[i - 1] * CELDA_KM2 > 10]
        self.mar = np.isin(etiquetas, mar_ids)
        interiores = [i for i in range(1, n + 1) if i not in mar_ids and tamanos[i - 1] * CELDA_KM2 >= 0.05]
        self.agua_interior = np.isin(etiquetas, interiores)
        self.tierra = ~self.mar & ~np.isnan(self.dem)

    def _pendiente(self):
        z = np.where(self.tierra, self.dem, np.nan)
        gy, gx = np.gradient(z, config.RESOLUCION_M)
        self.pendiente = np.degrees(np.arctan(np.hypot(gx, gy)))

    def _hidrologia(self):
        """D8 con pysheds: llenado de depresiones, dirección y acumulación de flujo, y HAND."""
        try:
            from pysheds.grid import Grid
            from pysheds.sview import Raster, ViewFinder
        except Exception as e:  # pragma: no cover
            self.bitacora.registrar("dependencia", f"pysheds no disponible ({e}); acumulación de flujo = null")
            self.acum_km2 = self.hand = None
            return
        nodata = -9999.0
        z = np.where(self.tierra, self.dem, nodata).astype("float64")
        vista = ViewFinder(affine=self.transform, shape=self.forma, crs=config.CRS_METRICO, nodata=nodata)
        raster = Raster(z, viewfinder=vista)
        grid = Grid.from_raster(raster)
        relleno = grid.resolve_flats(grid.fill_depressions(grid.fill_pits(raster)))
        fdir = grid.flowdir(relleno)
        acum = grid.accumulation(fdir)
        self.acum_km2 = np.where(self.tierra, np.asarray(acum) * CELDA_KM2, np.nan)
        cauces = np.nan_to_num(self.acum_km2) >= config.UMBRAL_CAUCE_KM2
        self.cauce = cauces
        self.cauce_mayor = np.nan_to_num(self.acum_km2) >= config.UMBRAL_CAUCE_MAYOR_KM2
        try:
            hand = grid.compute_hand(fdir, relleno, Raster(cauces, viewfinder=fdir.viewfinder))
            self.hand = np.where(self.tierra, np.asarray(hand, dtype="float64"), np.nan)
            self.hand[self.hand < -1e6] = np.nan
        except Exception as e:  # pragma: no cover
            self.bitacora.registrar("calculo", f"No se pudo calcular HAND ({e}); queda null")
            self.hand = None
        # Distancias (m) desde cada celda al elemento más cercano
        self.dist = {
            "mar": ndimage.distance_transform_edt(~self.mar) * config.RESOLUCION_M,
            "cauce_mayor_modelado": ndimage.distance_transform_edt(~self.cauce_mayor) * config.RESOLUCION_M,
            "cauce_menor_modelado": ndimage.distance_transform_edt(~self.cauce) * config.RESOLUCION_M,
            "cuerpo_agua_interior_inferido": (
                ndimage.distance_transform_edt(~self.agua_interior) * config.RESOLUCION_M if self.agua_interior.any() else None
            ),
        }

    # ------------------------------------------------------------------ estadísticas por polígono
    def _mascara(self, geom) -> np.ndarray:
        m = ~geometry_mask([geom], out_shape=self.forma, transform=self.transform, all_touched=False)
        if m.sum() == 0:
            m = ~geometry_mask([geom], out_shape=self.forma, transform=self.transform, all_touched=True)
        return m

    def estadisticas(self, id_poligono: str, geom_metrica) -> dict:
        dentro = self._mascara(geom_metrica)
        n_total = int(dentro.sum())
        tierra = dentro & self.tierra
        n = int(tierra.sum())
        r = {"n_celdas_dem": n_total, "n_celdas_tierra": n, "pct_celdas_mar_o_bajo_cero": None}
        if n_total:
            r["pct_celdas_mar_o_bajo_cero"] = round(100 * float((dentro & (self.mar | self.agua_interior)).sum()) / n_total, 2)
        if n < config.MIN_CELDAS_DEM:
            self.bitacora.registrar("baja_resolucion", f"Solo {n} celdas de 30 m con terreno; estadísticas de elevación poco confiables", id_poligono)
        if n == 0:
            return r
        z = self.dem[tierra]
        p = self.pendiente[tierra]
        r.update({
            "elevacion_minima_m": round(float(np.nanmin(z)), 2),
            "elevacion_maxima_m": round(float(np.nanmax(z)), 2),
            "elevacion_media_m": round(float(np.nanmean(z)), 2),
            "elevacion_mediana_m": round(float(np.nanmedian(z)), 2),
            "pendiente_media_grados": round(float(np.nanmean(p)), 2),
            "pendiente_maxima_grados": round(float(np.nanmax(p)), 2),
        })
        # Elevación relativa: mediana del polígono menos mediana del anillo de entorno (solo tierra)
        anillo = self._mascara(geom_metrica.buffer(config.ANILLO_ENTORNO_M)) & ~dentro & self.tierra
        if anillo.sum() >= config.MIN_CELDAS_DEM:
            entorno = self.dem[anillo]
            r["elevacion_entorno_mediana_m"] = round(float(np.nanmedian(entorno)), 2)
            r["elevacion_relativa_m"] = round(r["elevacion_mediana_m"] - r["elevacion_entorno_mediana_m"], 2)
            r["percentil_en_entorno"] = round(float((entorno < r["elevacion_mediana_m"]).mean() * 100), 1)
        else:
            r["elevacion_entorno_mediana_m"] = r["elevacion_relativa_m"] = r["percentil_en_entorno"] = None
        if self.acum_km2 is not None:
            a = self.acum_km2[tierra]
            r["acumulacion_flujo_max_km2"] = round(float(np.nanmax(a)), 3)
            r["pct_celdas_cauce_modelado"] = round(100 * float(self.cauce[tierra].mean()), 2)
        if self.hand is not None:
            h = self.hand[tierra]
            h = h[~np.isnan(h)]
            r["hand_mediana_m"] = round(float(np.median(h)), 2) if len(h) else None
            r["hand_media_m"] = round(float(np.mean(h)), 2) if len(h) else None
        # Distancias mínimas desde el polígono a cada tipo de cuerpo de agua derivado del DEM
        dist = {}
        for tipo, d in self.dist.items():
            dist[tipo] = None if d is None else round(float(d[dentro].min()), 0)
        r["distancias_m"] = dist
        disponibles = {k: v for k, v in dist.items() if v is not None}
        if disponibles:
            tipo = min(disponibles, key=disponibles.get)
            r["distancia_cuerpo_agua_m"] = disponibles[tipo]
            r["tipo_cuerpo_agua"] = tipo
        r["cuerpos_agua_cercanos"] = sorted(k for k, v in disponibles.items() if v <= config.CERCA_AGUA_M)
        return r


def distancia_costa_natural_earth(g: gpd.GeoDataFrame) -> dict[str, float | None]:
    """Contraste con la costa de Natural Earth (1:10 M; precisión de cientos de metros a km)."""
    ruta = config.NATURAL_EARTH / "ne_10m_coastline.geojson"
    if not ruta.exists():
        return {}
    metrico = gpd.GeoSeries(g["geom_calculo"], crs=g.crs).to_crs(config.CRS_METRICO)
    zona = metrico.union_all().buffer(50_000)
    costa = gpd.read_file(ruta).to_crs(config.CRS_METRICO)
    costa = costa[costa.intersects(zona)].union_all()
    return {r.id_poligono: round(float(metrico.iloc[i].distance(costa)), 0) for i, r in g.iterrows()}
