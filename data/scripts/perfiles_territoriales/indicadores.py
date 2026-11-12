"""Preparación de variables para un futuro motor de riesgo.

La normalización por percentil es RELATIVA a los polígonos procesados: 100 = el polígono con el
valor más desfavorable de este conjunto, no un umbral físico. Los pesos son iguales por diseño,
como hipótesis pendiente de calibrar con eventos históricos. Nada de esto es una probabilidad.
"""
import pandas as pd

# (clave, dimensión, dirección, justificación). dirección: "mayor" = valor mayor => indicador mayor
VARIABLES = [
    ("elevacion_relativa_m", "susceptibilidad", "menor", "Zonas más bajas que su entorno tienden a recibir y retener escurrimiento"),
    ("hand_mediana_m", "susceptibilidad", "menor", "Menor altura sobre el cauce al que drenan implica mayor exposición a desbordes"),
    ("pendiente_media_grados", "susceptibilidad", "menor", "Terreno plano drena más lento (encharcamiento); en laderas el peligro es otro (escurrimiento rápido)"),
    ("distancia_cauce_mayor_m", "susceptibilidad", "menor", "Proximidad a cauces modelados mayores (probables ríos). La cercanía sola no implica inundabilidad"),
    ("acumulacion_flujo_max_km2", "susceptibilidad", "mayor", "Mayor área que drena a través del polígono"),
    ("distancia_mar_m", "susceptibilidad", "menor", "Exposición costera (marea de tormenta, nortes); peligro distinto al pluvial"),
    ("eventos_inundacion_registrados", "susceptibilidad", "mayor", "Antecedentes documentados (sin fuente disponible)"),
    ("precipitacion_1h_mm", "amenaza", "mayor", "Intensidad reciente"),
    ("precipitacion_3h_mm", "amenaza", "mayor", "Acumulado de corto plazo"),
    ("precipitacion_24h_mm", "amenaza", "mayor", "Acumulado diario (saturación del suelo y del drenaje)"),
    ("tendencia_nivel_rio", "amenaza", "mayor", "Nivel del río al alza (requiere serie temporal)"),
    ("poblacion", "exposicion", "mayor", "Personas potencialmente expuestas"),
    ("viviendas", "exposicion", "mayor", "Viviendas potencialmente expuestas"),
    ("indice_marginacion", "exposicion", "mayor", "Menor capacidad de respuesta y recuperación"),
    ("cobertura_agua_pct", "exposicion", "menor", "Menor cobertura de agua entubada"),
    ("cobertura_drenaje_pct", "exposicion", "menor", "Menor cobertura de drenaje"),
]

MIN_VARIABLES_INDICE = 4


def normalizar(tabla: pd.DataFrame) -> pd.DataFrame:
    """Percentil (0–100) ajustado por dirección; null si la variable no tiene al menos 2 valores."""
    salida = pd.DataFrame(index=tabla.index)
    for clave, _, direccion, _ in VARIABLES:
        col = tabla.get(clave)
        if col is None or col.notna().sum() < 2:
            salida[clave] = None
            continue
        rango = col.rank(pct=True, method="average", ascending=(direccion == "mayor"))
        # rank(pct) va de 1/n a 1; se reescala a 0–100
        n = col.notna().sum()
        salida[clave] = ((rango * n - 1) / (n - 1) * 100).round(1)
    return salida


def indice_preliminar(normalizado: pd.DataFrame, dimension: str) -> pd.DataFrame:
    claves = [c for c, d, _, _ in VARIABLES if d == dimension]
    sub = normalizado[claves].astype("float64")
    n = sub.notna().sum(axis=1)
    indice = sub.mean(axis=1).round(1).where(n >= MIN_VARIABLES_INDICE)
    categoria = pd.cut(indice, bins=[-0.1, 33.3, 66.7, 100], labels=["baja", "media", "elevada"]).astype("object")
    return pd.DataFrame({"indice": indice, "categoria_relativa": categoria.where(indice.notna()), "n_variables": n})
