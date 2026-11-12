"""Integración de fuentes en un perfil uniforme por polígono, diagnóstico y ficha legible."""
from . import config

TIPO_UNIDAD = "zona_codigo_postal"
DESCRIPCION_UNIDAD = (
    "Zona de código postal (SEPOMEX). No es colonia, AGEB ni manzana: suele agrupar varias colonias."
)

MOTIVO_SOCIAL = (
    "Sin datos: INEGI (Censo 2020 por AGEB/manzana) y CONAPO (marginación urbana 2020) no estaban en el "
    "repositorio y sus sitios no eran accesibles desde el entorno de procesamiento. Al integrarlos se requiere "
    "interpolación areal o por manzanas de AGEB a zona postal (ver metodologia.md)."
)
NOTA_ANTECEDENTES = (
    "Registros de prensa, avisos y notas del Atlas de Riesgo municipal (data/antecedentes/eventos_inundacion.json), "
    "asignados de colonia a código postal con el catálogo SEPOMEX. Inventario incompleto: la ausencia de registros no "
    "implica que no haya habido inundaciones, y el conteo no es una frecuencia. No se infieren antecedentes por cercanía a ríos."
)
MOTIVO_ZONA_OFICIAL = (
    "Sin capa oficial de zonas inundables en formato geográfico (el Atlas de Riesgos estatal 2023 está en PDF y el "
    "municipal es de 2006); no se puede calcular superficie expuesta."
)


def construir(r, ident, geo, costa_ne, hid, norm, indices, bitacora, ant, clim) -> dict:
    pid = r.id_poligono
    dist = geo.get("distancias_m", {})
    geografia = {
        "elevacion_minima_m": geo.get("elevacion_minima_m"),
        "elevacion_maxima_m": geo.get("elevacion_maxima_m"),
        "elevacion_media_m": geo.get("elevacion_media_m"),
        "elevacion_mediana_m": geo.get("elevacion_mediana_m"),
        "elevacion_entorno_mediana_m": geo.get("elevacion_entorno_mediana_m"),
        "elevacion_relativa_m": geo.get("elevacion_relativa_m"),
        "percentil_en_entorno": geo.get("percentil_en_entorno"),
        "pendiente_media_grados": geo.get("pendiente_media_grados"),
        "pendiente_maxima_grados": geo.get("pendiente_maxima_grados"),
        "hand_mediana_m": geo.get("hand_mediana_m"),
        "hand_media_m": geo.get("hand_media_m"),
        "distancia_cuerpo_agua_m": geo.get("distancia_cuerpo_agua_m"),
        "tipo_cuerpo_agua": geo.get("tipo_cuerpo_agua"),
        "distancias_m": dist,
        "cuerpos_agua_dentro_o_cerca": geo.get("cuerpos_agua_cercanos", []),
        "distancia_costa_natural_earth_m": costa_ne,
        "acumulacion_flujo": {
            "max_km2": geo.get("acumulacion_flujo_max_km2"),
            "pct_celdas_cauce_modelado": geo.get("pct_celdas_cauce_modelado"),
        },
        "n_celdas_dem": geo.get("n_celdas_dem"),
        "pct_celdas_mar_o_bajo_cero": geo.get("pct_celdas_mar_o_bajo_cero"),
        "nota": "Cuerpos de agua y cauces derivados del DEM (no oficiales). 'cauce_mayor_modelado' ≥ "
                f"{config.UMBRAL_CAUCE_MAYOR_KM2} km² de drenaje; 'cauce_menor_modelado' ≥ {config.UMBRAL_CAUCE_KM2} km².",
    }
    sub = {k: (None if v != v else v) for k, v in norm.items()}  # NaN -> None
    ind_s = indices["susceptibilidad"]
    indicadores = {
        "advertencia": "Hipótesis de diseño sin calibrar ni validar. Escala relativa a los 101 polígonos. No es probabilidad de inundación.",
        "subindicadores_0_100": sub,
        "susceptibilidad": {"indice_preliminar": ind_s["indice"], "categoria_relativa": ind_s["categoria_relativa"],
                            "n_variables": ind_s["n_variables"]},
        "amenaza": {"indice_preliminar": None, "motivo": "Sin precipitación ni niveles representativos del polígono"},
        "exposicion_vulnerabilidad": {"indice_preliminar": None, "motivo": "Sin datos de INEGI ni CONAPO"},
    }

    disponibles, faltantes = [], []
    for k, v in {**{f"geografia.{k}": v for k, v in geografia.items() if not isinstance(v, (dict, list, str))},
                 "geografia.acumulacion_flujo.max_km2": geografia["acumulacion_flujo"]["max_km2"],
                 "hidromet.precipitacion_1h_mm": hid["precipitacion_1h_mm"],
                 "hidromet.precipitacion_24h_mm": hid["precipitacion_24h_mm"],
                 "hidromet.nivel_rio": hid["nivel_rio"],
                 "hidromet.tendencia_nivel_rio": hid["tendencia_nivel_rio"],
                 "antecedentes.eventos_registrados": ant["eventos_registrados"], "antecedentes.zona_inundable_oficial": None,
                 "vulnerabilidad.poblacion": None, "vulnerabilidad.viviendas": None,
                 "vulnerabilidad.indice_marginacion": None, "vulnerabilidad.cobertura_agua": None,
                 "vulnerabilidad.cobertura_drenaje": None}.items():
        (faltantes if v is None else disponibles).append(k)

    perfil = {
        "id_poligono": pid,
        "nombre": r.get("nombre"),
        "tipo_unidad": TIPO_UNIDAD,
        "descripcion_unidad": DESCRIPCION_UNIDAD,
        "municipio": r.get("municipio"),
        "atributos_originales": {k: r[k] for k in ("nombre", "codigo_postal", "municipio", "vulnerabilidad", "vulnerabilidad_fuente")},
        "identificacion": ident,
        "caracteristicas_geograficas": geografia,
        "antecedentes_inundacion": {
            "eventos_registrados": ant["eventos_registrados"],
            "eventos_posibles_por_nombre_ambiguo": ant["eventos_posibles_por_nombre_ambiguo"],
            "alertas_preventivas": ant["alertas_preventivas"],
            "identificado_en_riesgo": ant["identificado_en_riesgo"],
            "zona_inundable_oficial": None, "superficie_expuesta_km2": None, "porcentaje_superficie_expuesta": None,
            "motivo_zona_oficial_null": MOTIVO_ZONA_OFICIAL,
            "registros": ant["registros"],
            "fuentes": ant["fuentes"],
            "nota": NOTA_ANTECEDENTES,
            "motivo_null": None if ant["registros"] else "Sin registros encontrados en la búsqueda; no implica que no haya ocurrido.",
        },
        "vulnerabilidad_social": {
            "poblacion": None, "viviendas": None, "indice_marginacion": None,
            "cobertura_agua": None, "cobertura_drenaje": None, "motivo_null": MOTIVO_SOCIAL,
        },
        "condiciones_hidrometeorologicas": hid,
        "climatologia_precipitacion": clim,
        "indicadores": indicadores,
        "calidad_informacion": {
            "cobertura_geografica": "DEM y geometría: completa; estaciones: " + hid["cobertura_meteorologica"],
            "cobertura_temporal": hid["aviso"] or "vigente",
            "variables_disponibles": sorted(disponibles),
            "variables_faltantes": sorted(faltantes),
            "observaciones": bitacora.por_poligono.get(pid, []),
        },
    }
    perfil["diagnostico"] = diagnostico(perfil)
    return perfil


# ---------------------------------------------------------------- textos
def _elev_rel(v):
    if v is None:
        return "no determinada"
    if v <= -1:
        return f"baja respecto al entorno ({v:+.1f} m frente a la mediana del anillo de 1 km)"
    if v >= 1:
        return f"alta respecto al entorno ({v:+.1f} m)"
    return f"similar al entorno ({v:+.1f} m)"


def _cercania(geo):
    d = [x for x in (geo["distancias_m"].get("cauce_mayor_modelado"), geo["distancias_m"].get("mar")) if x is not None]
    if not d:
        return "no determinada"
    m = min(d)
    nivel = "alta" if m <= 500 else "media" if m <= 2000 else "baja"
    return f"{nivel} (a {m:,.0f} m de mar o de cauce mayor modelado)"


def _texto_antecedentes(a) -> str:
    partes = []
    obs = sorted({(r["nombre"], r["fecha"]) for r in a["registros"] if r["tipo"] == "evento_observado" and r["asignacion"] == "unica"},
                 key=lambda x: x[1] or "")
    if obs:
        partes.append(f"{len(obs)} evento(s) documentado(s): " + ", ".join(f"{n} ({f})" for n, f in obs))
    amb = sorted({(r["nombre"], r["fecha"]) for r in a["registros"] if r["tipo"] == "evento_observado" and r["asignacion"] == "ambigua"}
                 - set(obs), key=lambda x: x[1] or "")
    if amb:
        partes.append("posible(s) por nombre ambiguo: " + ", ".join(f"{n} ({f})" for n, f in amb))
    if a["alertas_preventivas"]:
        partes.append("incluida en alerta preventiva: " + ", ".join(sorted({r["nombre"] for r in a["registros"] if r["tipo"] == "alerta_preventiva"})))
    if a["identificado_en_riesgo"]:
        partes.append("identificada como propensa a inundarse: " + ", ".join(sorted({r["nombre"] for r in a["registros"] if r["tipo"] == "riesgo_identificado"})))
    cols = sorted({r["colonia_fuente"] for r in a["registros"]})
    return "; ".join(partes) + f" [colonias mencionadas: {', '.join(cols)}]"


def diagnostico(p) -> str:
    g, h = p["caracteristicas_geograficas"], p["condiciones_hidrometeorologicas"]
    ident = p["identificacion"]
    partes = [f"{p['nombre']} ({p['municipio']}, {ident['area_km2']} km²; unidad: zona de código postal)."]
    if g["elevacion_mediana_m"] is not None:
        partes.append(
            f"Elevación mediana {g['elevacion_mediana_m']} m, {_elev_rel(g['elevacion_relativa_m'])}; "
            f"pendiente media {g['pendiente_media_grados']}°."
        )
    if g["hand_mediana_m"] is not None:
        partes.append(f"Altura mediana sobre el cauce modelado al que drena: {g['hand_mediana_m']} m.")
    if g["tipo_cuerpo_agua"]:
        partes.append(f"Cuerpo de agua más cercano: {g['tipo_cuerpo_agua'].replace('_', ' ')} a {g['distancia_cuerpo_agua_m']:,.0f} m.")
    a = p["antecedentes_inundacion"]
    if a["registros"]:
        partes.append(f"Antecedentes: {_texto_antecedentes(a)}.")
    partes.append("Respaldado por: DEM Copernicus 30 m (modelo de superficie; incluye edificios), cauces modelados no oficiales"
                  + (" y registros de prensa/avisos asignados por nombre de colonia." if a["registros"] else "."))
    no = ["zona inundable oficial", "población, viviendas y marginación"]
    if not a["registros"]:
        no.insert(0, "antecedentes de inundación (sin registros en la búsqueda; no implica que no hayan ocurrido)")
    if h["precipitacion_1h_mm"] is None:
        no.append(f"precipitación representativa ({h['motivo_precipitacion_null']})")
    partes.append("No determinado: " + "; ".join(no) + ".")
    c = p.get("climatologia_precipitacion") or {}
    if c.get("estacion_referencia"):
        partes.append(
            f"Clima de lluvia (estación SMN {c['estacion_referencia']} {c['nombre_estacion']}, a {c['distancia_km']} km): "
            f"{c['lluvia_anual_media_mm']:.0f} mm/año, temporada {', '.join(c['meses_mas_lluviosos'])}; una lluvia de "
            f"{c['lluvia_24h_retorno_mm']['10']:.0f} mm en 24 h se espera en promedio una vez cada 10 años."
        )
    if h["aviso"]:
        partes.append(h["aviso"] + ".")
    return " ".join(partes)


def ficha(p) -> str:
    g, h, s = p["caracteristicas_geograficas"], p["condiciones_hidrometeorologicas"], p["indicadores"]["susceptibilidad"]
    est = h["estaciones_meteorologicas"]
    hid = h["estaciones_hidrometricas"]
    lineas = [
        f"PERFIL TERRITORIAL — {p['nombre']} ({p['municipio']})",
        f"Unidad: {p['descripcion_unidad']}",
        "",
        f"Susceptibilidad territorial (preliminar, relativa, sin validar): "
        f"{s['categoria_relativa'] or 'no determinada'}"
        + (f" — índice {s['indice_preliminar']}/100 con {s['n_variables']} variables" if s["indice_preliminar"] is not None else ""),
        "",
        f"- Elevación: {_elev_rel(g['elevacion_relativa_m'])}.",
        f"- Cercanía a cuerpos de agua: {_cercania(g)}.",
        f"- Altura sobre el cauce (HAND): {g['hand_mediana_m'] if g['hand_mediana_m'] is not None else 'no determinada'} m.",
        "- Antecedentes de inundación: " + (_texto_antecedentes(p["antecedentes_inundacion"]) if p["antecedentes_inundacion"]["registros"]
                                             else "sin registros encontrados (no implica que no hayan ocurrido)") + ".",
        "- Vulnerabilidad social: sin información disponible (INEGI/CONAPO pendientes).",
        "- Población potencialmente expuesta: sin información disponible.",
        "- Precipitación reciente: " + (
            f"{h['precipitacion_1h_mm']} mm en 1 h al {h['ultima_observacion']}" if h["precipitacion_1h_mm"] is not None
            else f"no asignada — {h['motivo_precipitacion_null']}"
        ) + ".",
        "- Clima de lluvia: " + (
            f"{p['climatologia_precipitacion']['lluvia_anual_media_mm']:.0f} mm/año; meses más lluviosos "
            f"{', '.join(p['climatologia_precipitacion']['meses_mas_lluviosos'])}; 24 h con retorno de 10 años ≈ "
            f"{p['climatologia_precipitacion']['lluvia_24h_retorno_mm']['10']:.0f} mm "
            f"(estación SMN {p['climatologia_precipitacion']['estacion_referencia']}, a {p['climatologia_precipitacion']['distancia_km']} km)"
            if p.get("climatologia_precipitacion", {}).get("estacion_referencia") else "sin serie histórica"
        ) + ".",
        "- Estaciones meteorológicas cercanas: " + (", ".join(f"{e['estacion']} ({e['distancia_km']} km)" for e in est) or "ninguna") + ".",
        "- Estaciones hidrométricas cercanas: " + (", ".join(f"{e['estacion']} ({e['distancia_km']} km)" for e in hid) or "ninguna") + ".",
        f"- Cobertura y calidad: meteorológica {h['cobertura_meteorologica']}; "
        f"{len(p['calidad_informacion']['variables_faltantes'])} variables sin dato. {h['aviso'] or ''}".rstrip(),
    ]
    if p["calidad_informacion"]["observaciones"]:
        lineas.append("- Observaciones: " + "; ".join(p["calidad_informacion"]["observaciones"]))
    lineas += ["", "Diagnóstico:", p["diagnostico"]]
    return "\n".join(lineas)
