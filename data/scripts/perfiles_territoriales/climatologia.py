"""Modelo climatológico de precipitación con series diarias del SMN (Base de Datos Climatológica Nacional).

Qué hace:
  1. Carga y controla la calidad de las series diarias (dia<estación>.txt).
  2. Climatología mensual: lluvia media del mes, probabilidad diaria de lluvia fuerte, percentiles.
  3. Extremos: máximos anuales de 24 h y 72 h ajustados a Gumbel y GEV -> periodos de retorno.
  4. evaluar(): ubica una lluvia (mm en 24 h o 72 h) frente al historial de la estación y el mes.
  5. Contraste con los antecedentes de inundación documentados.

Qué NO hace: no predice inundaciones ni la lluvia futura. Describe qué tan inusual es una lluvia
según el historial de una estación. Los umbrales de categoría son criterios de diseño.
"""
import io
import json
import math
import re

import numpy as np
import pandas as pd
from scipy import stats

from . import config

# Completitud mínima para usar un periodo (criterios de diseño)
MIN_DIAS_MES = 0.90          # mes con >= 90 % de días con dato
MIN_DIAS_ANIO = 0.80         # año con >= 80 % de días con dato
MIN_DIAS_TEMPORADA = 0.80    # y >= 80 % de días de junio a octubre (cuando ocurren los máximos)
MIN_ANIOS_EXTREMOS = 20
PERIODOS_RETORNO = [2, 5, 10, 25, 50, 100]
UMBRALES_MM = [1, 25, 50, 100]
NORMAL = (1991, 2020)

# Lluvia mensual NACIONAL normal 1991-2020 (mm), transcrita de la gráfica de la pág. 6 de
# "Información estadística para la Planeación Hídrica" (SEMARNAT-CONAGUA, 2026; fuente: CGSMN).
NACIONAL_NORMAL_1991_2020 = {1: 24.1, 2: 18.7, 3: 15.8, 4: 17.0, 5: 40.0, 6: 99.8,
                             7: 125.9, 8: 132.3, 9: 140.4, 10: 75.5, 11: 34.5, 12: 23.5}
MESES = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]


# ---------------------------------------------------------------- carga y calidad
def cargar(ruta) -> tuple[dict, pd.DataFrame]:
    texto = ruta.read_text(encoding="utf-8").splitlines()
    meta = {}
    for linea in texto:
        m = re.match(r"\s*([A-ZÁÉÍÓÚÑ\.\- ]+?)\s*:\s*(.*?)\s*°?\s*$", linea)
        if m and m.group(1).strip() in {"ESTACIÓN", "NOMBRE", "ESTADO", "MUNICIPIO", "SITUACIÓN", "LATITUD", "LONGITUD", "ALTITUD", "EMISIÓN", "U. ADMNVA.", "CVE-OMM"}:
            meta[m.group(1).strip()] = m.group(2).strip()
    inicio = next(i for i, l in enumerate(texto) if l.startswith("FECHA"))
    d = pd.read_csv(io.StringIO("\n".join(texto[inicio + 2:])), sep=r"\t+", engine="python", header=None,
                    names=["fecha", "precip", "evap", "tmax", "tmin"], na_values=["NULO"])
    d["fecha"] = pd.to_datetime(d["fecha"], errors="coerce")
    d = d.dropna(subset=["fecha"]).drop_duplicates("fecha").set_index("fecha").sort_index()
    for c in ("precip", "evap", "tmax", "tmin"):
        d[c] = pd.to_numeric(d[c], errors="coerce")
    info = {
        "estacion": meta.get("ESTACIÓN"), "nombre": meta.get("NOMBRE"), "municipio": meta.get("MUNICIPIO"),
        "situacion": meta.get("SITUACIÓN"), "latitud": float(meta["LATITUD"].replace("°", "").strip()),
        "longitud": float(meta["LONGITUD"].replace("°", "").strip()),
        "altitud_msnm": float(meta.get("ALTITUD", "nan").split()[0]), "emision_archivo": meta.get("EMISIÓN"),
        "fuente": "CONAGUA-SMN, Base de Datos Climatológica Nacional (registro diario histórico)",
        "unidad": "mm/día (precipitación diaria; según la convención del SMN corresponde al periodo de 24 h que termina a las 08:00, verificar)",
    }
    return info, d


def _rango_calendario(serie: pd.Series) -> pd.DatetimeIndex:
    """Del 1 de enero del primer año al 31 de diciembre del último: un año parcial NO cuenta como completo."""
    return pd.date_range(f"{serie.index.min().year}-01-01", f"{serie.index.max().year}-12-31")


def diagnostico(serie: pd.Series) -> dict:
    """Completitud y anomalías de una serie diaria de precipitación (nada se elimina)."""
    rango = _rango_calendario(serie)
    completa = serie.reindex(rango)
    por_anio = completa.notna().groupby(rango.year).mean()
    return {
        "inicio": serie.index.min().date().isoformat(), "fin": serie.index.max().date().isoformat(),
        "dias_periodo": int(len(rango)), "dias_con_dato": int(completa.notna().sum()),
        "pct_dias_con_dato": round(100 * completa.notna().mean(), 1),
        "anios_completos": int((por_anio >= MIN_DIAS_ANIO).sum()),
        "anios_incompletos": {int(a): round(100 * v) for a, v in por_anio[por_anio < MIN_DIAS_ANIO].items()},
        "anios_completos_normal_1991_2020": int((por_anio.loc[NORMAL[0]:NORMAL[1]] >= MIN_DIAS_ANIO).sum()),
        "valores_negativos": int((serie < 0).sum()),
        "valores_mayores_300mm": int((serie > 300).sum()),
        "maximo_diario_mm": float(serie.max()), "fecha_maximo": serie.idxmax().date().isoformat(),
    }


def _anios_validos(serie: pd.Series) -> list[int]:
    rango = _rango_calendario(serie)
    c = serie.reindex(rango)
    anio = c.notna().groupby(rango.year).mean()
    temporada = c[(rango.month >= 6) & (rango.month <= 10)]
    temp = temporada.notna().groupby(temporada.index.year).mean()
    return [int(a) for a in anio.index if anio[a] >= MIN_DIAS_ANIO and temp.get(a, 0) >= MIN_DIAS_TEMPORADA]


# ---------------------------------------------------------------- homogeneidad
RAZON_MIN_DIAS_COMUNES = 150
RAZON_BAJA = 0.8    # estación A registra < 80 % de lo que registra B en los mismos días
RAZON_ALTA = 2.0    # o B registra < 50 % de lo que registra A


def homogeneidad(a: pd.Series, b: pd.Series) -> pd.DataFrame:
    """Razón anual A/B sobre los días en que ambas tienen dato. Sirve para detectar subregistros.

    Criterio (Veracruz 30192 vs El Copital 30048): en los años de solapamiento sin indicios de problema
    (1961-1973, 2014-2016) la razón fue 0.96-1.52; por debajo de 0.8 o por encima de 2.0 no es variabilidad
    climática plausible entre estaciones a ~22 km y se marca el año como sospechoso en la estación baja.
    """
    df = pd.concat({"a": a, "b": b}, axis=1, sort=True).dropna()
    g = df.groupby(df.index.year)
    t = pd.DataFrame({"dias_comunes": g.size(), "suma_a_mm": g["a"].sum(), "suma_b_mm": g["b"].sum()})
    t["razon_a_b"] = (t["suma_a_mm"] / t["suma_b_mm"]).round(3)
    t["evaluable"] = t["dias_comunes"] >= RAZON_MIN_DIAS_COMUNES
    t["sospechoso_a"] = t["evaluable"] & (t["razon_a_b"] < RAZON_BAJA)
    t["sospechoso_b"] = t["evaluable"] & (t["razon_a_b"] > RAZON_ALTA)
    return t


def depurar(serie: pd.Series, anios: list[int]) -> pd.Series:
    """Copia de la serie con los años sospechosos como faltantes (el original no se toca)."""
    s = serie.copy()
    s[s.index.year.isin(anios)] = np.nan
    return s


# ---------------------------------------------------------------- climatología
def climatologia_mensual(serie: pd.Series) -> dict:
    rango = _rango_calendario(serie)
    c = serie.reindex(rango)
    normal = c.loc[f"{NORMAL[0]}-01-01":f"{NORMAL[1]}-12-31"]
    usar = normal if normal.notna().groupby(normal.index.year).mean().ge(MIN_DIAS_ANIO).sum() >= 15 else c
    periodo = f"{NORMAL[0]}-{NORMAL[1]}" if usar is normal else f"{rango.year.min()}-{rango.year.max()} (años válidos del registro; la normal 1991-2020 tiene < 15 años válidos)"
    meses = {}
    for m in range(1, 13):
        dm = usar[usar.index.month == m]
        grupos = dm.groupby(dm.index.year)
        totales = grupos.sum(min_count=1)[grupos.apply(lambda s: s.notna().mean()) >= MIN_DIAS_MES]
        dias = dm.dropna()
        humedos = dias[dias >= 1]
        meses[MESES[m - 1]] = {
            "mes": m,
            "lluvia_media_mm": round(float(totales.mean()), 1) if len(totales) else None,
            "lluvia_mediana_mm": round(float(totales.median()), 1) if len(totales) else None,
            "anios_usados": int(len(totales)),
            **{f"prob_diaria_ge_{u}mm": round(float((dias >= u).mean()), 4) for u in UMBRALES_MM},
            "dias_ge_50mm_por_mes": round(float((dias >= 50).mean() * dm.index.days_in_month[0]), 2) if len(dias) else None,
            "p90_dia_humedo_mm": round(float(humedos.quantile(0.90)), 1) if len(humedos) else None,
            "p99_dia_humedo_mm": round(float(humedos.quantile(0.99)), 1) if len(humedos) else None,
            "max_diario_mm": round(float(dias.max()), 1) if len(dias) else None,
            "nacional_normal_1991_2020_mm": NACIONAL_NORMAL_1991_2020[m],
        }
    anual = sum(v["lluvia_media_mm"] or 0 for v in meses.values())
    for v in meses.values():
        v["pct_lluvia_anual"] = round(100 * (v["lluvia_media_mm"] or 0) / anual, 1) if anual else None
    orden = sorted(meses, key=lambda k: meses[k]["lluvia_media_mm"] or 0, reverse=True)
    return {"periodo": periodo, "lluvia_anual_media_mm": round(anual, 1), "meses_mas_lluviosos": orden[:4],
            "mes_pico": orden[0], "meses": meses}


def _ajuste(maximos: np.ndarray, semilla: int = 7) -> dict:
    gl, gs = stats.gumbel_r.fit(maximos)
    c, loc, esc = stats.genextreme.fit(maximos)
    rng = np.random.default_rng(semilla)
    boot = []
    for _ in range(300):
        m = rng.choice(maximos, size=len(maximos), replace=True)
        bl, bs = stats.gumbel_r.fit(m)
        boot.append([stats.gumbel_r.ppf(1 - 1 / t, bl, bs) for t in PERIODOS_RETORNO])
    boot = np.array(boot)
    niveles = {}
    for i, t in enumerate(PERIODOS_RETORNO):
        niveles[str(t)] = {
            "gumbel_mm": round(float(stats.gumbel_r.ppf(1 - 1 / t, gl, gs)), 1),
            "gumbel_ic90_mm": [round(float(np.percentile(boot[:, i], 5)), 1), round(float(np.percentile(boot[:, i], 95)), 1)],
            "gev_mm": round(float(stats.genextreme.ppf(1 - 1 / t, c, loc, esc)), 1),
        }
    ks = stats.kstest(maximos, "gumbel_r", args=(gl, gs))
    return {"parametros_gumbel": {"loc": round(gl, 3), "escala": round(gs, 3)},
            "parametros_gev": {"forma_c_scipy": round(c, 4), "loc": round(loc, 3), "escala": round(esc, 3)},
            "ks_gumbel_pvalor": round(float(ks.pvalue), 3), "niveles_retorno": niveles}


def extremos(serie: pd.Series) -> dict:
    anios = _anios_validos(serie)
    c = serie.reindex(_rango_calendario(serie))
    r = {"anios_validos": len(anios), "criterio": f">= {int(MIN_DIAS_ANIO*100)} % de días en el año y en jun-oct"}
    if len(anios) < MIN_ANIOS_EXTREMOS:
        r["motivo_null"] = f"Solo {len(anios)} años válidos (mínimo {MIN_ANIOS_EXTREMOS})"
        return r
    for nombre, s in (("24h", c), ("72h", c.rolling(3, min_periods=3).sum())):
        maximos = s[s.index.year.isin(anios)].groupby(s[s.index.year.isin(anios)].index.year).max().dropna()
        r[nombre] = {"maximos_anuales": {int(a): round(float(v), 1) for a, v in maximos.items()},
                     "mediana_maximo_anual_mm": round(float(maximos.median()), 1), **_ajuste(maximos.values)}
    r["nota"] = ("Gumbel es el ajuste principal (2 parámetros, más estable con ~50 años); GEV se reporta como contraste. "
                 "Los niveles de 50 y 100 años extrapolan más allá del registro: usar su intervalo de confianza.")
    return r


# ---------------------------------------------------------------- evaluación de una lluvia
def periodo_retorno(mm: float, ext: dict, ventana: str = "24h") -> float | None:
    if ventana not in ext:
        return None
    p = ext[ventana]["parametros_gumbel"]
    f = stats.gumbel_r.cdf(mm, p["loc"], p["escala"])
    return None if f >= 0.9999 else round(float(1 / (1 - f)), 1)


def evaluar(mm: float, mes: int, serie: pd.Series, ext: dict, ventana: str = "24h") -> dict:
    """Qué tan inusual es `mm` (en 24 h o 72 h) para ese mes según el historial de la estación.

    Categorías (criterio de diseño): habitual < P90 del mes; alta P90–P99; muy alta >= P99;
    extraordinaria si además su periodo de retorno anual es >= 10 años.
    """
    s = serie if ventana == "24h" else serie.rolling(3, min_periods=3).sum()
    del_mes = s[s.index.month == mes].dropna()
    pct = round(float((del_mes < mm).mean() * 100), 2) if len(del_mes) else None
    t = periodo_retorno(mm, ext, ventana)
    if pct is None:
        cat = None
    elif t is not None and t >= 10:
        cat = "extraordinaria"
    elif pct >= 99:
        cat = "muy alta"
    elif pct >= 90:
        cat = "alta"
    else:
        cat = "habitual"
    return {"mm": mm, "ventana": ventana, "mes": mes, "percentil_en_el_mes": pct,
            "periodo_retorno_anual_anios": t, "categoria": cat}


# ---------------------------------------------------------------- contraste con antecedentes
def contrastar_eventos(series: dict[str, pd.Series], extremos_: dict[str, dict]) -> list[dict]:
    datos = json.loads(config.ANTECEDENTES.read_text(encoding="utf-8"))
    filas = []
    for ev in datos["eventos"]:
        f = ev.get("fecha")
        if not f:
            continue
        if len(f) == 7:
            ini = pd.Timestamp(f + "-01"); fin = ini + pd.offsets.MonthEnd(0)
        else:
            ini = pd.Timestamp(f) - pd.Timedelta(days=2); fin = pd.Timestamp(f) + pd.Timedelta(days=2)
        for est, s in series.items():
            v = s.loc[ini:fin]
            fila = {"evento": ev["id"], "nombre": ev["nombre"], "tipo": ev["tipo"], "fecha": f, "estacion": est,
                    "ventana": f"{ini.date()} a {fin.date()}", "dias_con_dato": int(v.notna().sum()),
                    "dias_ventana": int((fin - ini).days + 1),
                    "advertencia": ("Fecha del evento con precisión de mes: el máximo del mes puede corresponder a otro día "
                                    "y no al evento") if len(f) == 7 else None}
            if v.notna().sum() < 0.8 * fila["dias_ventana"]:
                fila["resultado"] = "sin datos suficientes en la estación"
                filas.append(fila)
                continue
            s3 = s.rolling(3, min_periods=3).sum().loc[ini:fin]
            fila.update({
                "max_24h_mm": float(v.max()), "fecha_max_24h": v.idxmax().date().isoformat(),
                "max_72h_mm": float(s3.max()) if s3.notna().any() else None,
                **{f"24h_{k}": x for k, x in evaluar(float(v.max()), v.idxmax().month, s, extremos_[est]).items()
                   if k in ("percentil_en_el_mes", "periodo_retorno_anual_anios", "categoria")},
            })
            if fila["max_72h_mm"] is not None:
                e3 = evaluar(fila["max_72h_mm"], s3.idxmax().month, s, extremos_[est], "72h")
                fila["72h_periodo_retorno_anual_anios"] = e3["periodo_retorno_anual_anios"]
                fila["72h_categoria"] = e3["categoria"]
            filas.append(fila)
    return filas


def dias_extremos_sin_antecedente(series: dict[str, pd.Series], filas_eventos: list[dict], n: int = 10) -> list[dict]:
    """Días más lluviosos del registro que no caen en ninguna ventana de antecedentes: candidatos a investigar."""
    ventanas = [(pd.Timestamp(f["ventana"][:10]), pd.Timestamp(f["ventana"][-10:])) for f in filas_eventos]
    salida = []
    for est, s in series.items():
        for fecha, mm in s.nlargest(40).items():
            if any(a <= fecha <= b for a, b in ventanas):
                continue
            salida.append({"estacion": est, "fecha": fecha.date().isoformat(), "mm_24h": float(mm)})
    return sorted(salida, key=lambda x: -x["mm_24h"])[:n]


def modelo() -> dict | None:
    """Construye el modelo con las series disponibles en data/fuentes/smn/."""
    rutas = sorted((config.FUENTES / "smn").glob("dia*.txt"))
    if not rutas:
        return None
    crudas, infos = {}, {}
    for r in rutas:
        info, d = cargar(r)
        crudas[info["estacion"]] = d["precip"]
        infos[info["estacion"]] = info
    # Homogeneidad entre las dos series largas (si están ambas)
    sospechosos = {k: [] for k in crudas}
    tabla_homog = None
    if {"30192", "30048"} <= set(crudas):
        tabla_homog = homogeneidad(crudas["30192"], crudas["30048"])
        sospechosos["30192"] = [int(a) for a in tabla_homog.index[tabla_homog["sospechoso_a"]]]
        sospechosos["30048"] = [int(a) for a in tabla_homog.index[tabla_homog["sospechoso_b"]]]
        # Bloque continuo: si los años sospechosos de 30192 forman un tramo, se marca el tramo completo
        if sospechosos["30192"]:
            a0, a1 = min(sospechosos["30192"]), max(sospechosos["30192"])
            tramo = [int(a) for a in tabla_homog.index if a0 <= a <= a1]
            sospechosos["30192"] = sorted(set(sospechosos["30192"]) | set(tramo))
    estaciones, series, ext = {}, {}, {}
    for est, s0 in crudas.items():
        s = depurar(s0, sospechosos[est])
        e = extremos(s)
        estaciones[est] = {**infos[est], "calidad": {**diagnostico(s0), "anios_sospechosos_excluidos": sospechosos[est]},
                           "climatologia": climatologia_mensual(s), "extremos": e, "apta_para_extremos": "24h" in e}
        series[est] = s
        ext[est] = e
    contraste = contrastar_eventos({k: v for k, v in series.items() if estaciones[k]["apta_para_extremos"]}, ext)
    return {
        "descripcion": ("Modelo climatológico de precipitación por estación (SMN). Describe qué tan inusual es una lluvia "
                        "respecto al historial; no es un pronóstico ni una probabilidad de inundación."),
        "criterios": {"min_dias_mes": MIN_DIAS_MES, "min_dias_anio": MIN_DIAS_ANIO, "min_dias_temporada_jun_oct": MIN_DIAS_TEMPORADA,
                      "min_anios_extremos": MIN_ANIOS_EXTREMOS, "periodo_normal": f"{NORMAL[0]}-{NORMAL[1]}",
                      "categorias": "habitual < P90 del mes; alta P90-P99; muy alta >= P99; extraordinaria si T >= 10 años (criterio de diseño)"},
        "referencia_nacional": {"fuente": "SEMARNAT-CONAGUA (2026), Información estadística para la Planeación Hídrica, pág. 6 (CGSMN)",
                                "lluvia_mensual_normal_1991_2020_mm": NACIONAL_NORMAL_1991_2020,
                                "lluvia_anual_normal_mm": 747.6},
        "homogeneidad_30192_vs_30048": None if tabla_homog is None else {
            "metodo": ("Razón anual de lluvia 30192/30048 en los días en que ambas tienen dato. Años con >= "
                       f"{RAZON_MIN_DIAS_COMUNES} días comunes y razón < {RAZON_BAJA} se marcan sospechosos en 30192 "
                       f"(y, por continuidad, todo el tramo); razón > {RAZON_ALTA}, en 30048. Se excluyen de las estadísticas "
                       "pero se conservan en los archivos originales."),
            "por_anio": {int(a): {k: (round(float(v), 1) if isinstance(v, float) else (bool(v) if isinstance(v, (bool, np.bool_)) else int(v)))
                                  for k, v in fila.items()} for a, fila in tabla_homog.iterrows()},
        },
        "estaciones": estaciones,
        "contraste_antecedentes": contraste,
        "dias_extremos_sin_antecedente": dias_extremos_sin_antecedente(
            {k: v for k, v in series.items() if estaciones[k]["apta_para_extremos"]}, contraste),
        "_series": series,  # uso interno (no se serializa)
    }


def resumen_para_poligono(mod: dict, geom_metrica) -> dict:
    """Estación climatológica de referencia (serie larga más cercana) y sus datos clave para el polígono."""
    import geopandas as gpd
    aptas = {k: v for k, v in mod["estaciones"].items() if v["apta_para_extremos"]}
    if not aptas:
        return {"estacion_referencia": None, "motivo_null": "Sin series largas disponibles"}
    pts = gpd.GeoSeries(gpd.points_from_xy([v["longitud"] for v in aptas.values()], [v["latitud"] for v in aptas.values()]),
                        crs=config.CRS_GEO).to_crs(config.CRS_METRICO)
    dist = {k: round(float(p.distance(geom_metrica)) / 1000, 2) for k, p in zip(aptas, pts)}
    est = min(dist, key=dist.get)
    e = aptas[est]
    cl, ex = e["climatologia"], e["extremos"]
    pico = cl["meses"][cl["mes_pico"]]
    return {
        "estacion_referencia": est, "nombre_estacion": e["nombre"], "distancia_km": dist[est],
        "distancias_otras_estaciones_km": {k: v for k, v in dist.items() if k != est},
        "periodo_registro": f"{e['calidad']['inicio']} a {e['calidad']['fin']}",
        "periodo_climatologia": cl["periodo"], "anios_validos_extremos": ex["anios_validos"],
        "lluvia_anual_media_mm": cl["lluvia_anual_media_mm"], "meses_mas_lluviosos": cl["meses_mas_lluviosos"],
        "mes_pico": cl["mes_pico"], "lluvia_media_mes_pico_mm": pico["lluvia_media_mm"],
        "prob_diaria_ge_50mm_mes_pico": pico["prob_diaria_ge_50mm"],
        "lluvia_24h_retorno_mm": {t: v["gumbel_mm"] for t, v in ex["24h"]["niveles_retorno"].items()},
        "lluvia_72h_retorno_mm": {t: v["gumbel_mm"] for t, v in ex["72h"]["niveles_retorno"].items()},
        "metodo_asociacion": ("Serie larga más cercana (distancia al borde del polígono). La climatología varía poco a esta "
                              "escala, por eso se acepta una estación a decenas de km; NO sirve para lluvia en tiempo real."),
    }
