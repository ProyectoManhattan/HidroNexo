"""Catálogo de trazabilidad: fuente, unidad, método, resolución, cobertura y confianza por variable."""

DEM = "Copernicus DEM GLO-30 (DSM)"
CONAGUA_P = "CONAGUA SIH · PRECIPITACION_HORA.csv"
CONAGUA_N = "CONAGUA SIH · NIVEL_RIOS_DIA.csv"
CONAGUA_C = "CONAGUA SIH · CATALOGO_SIH.csv"
POL = "Polígonos del proyecto (SEPOMEX)"


def _v(seccion, unidad, fuente, metodo, resolucion, cobertura, confianza, fecha_observacion="no aplica"):
    return {"seccion": seccion, "unidad": unidad, "fuente": fuente, "metodo": metodo,
            "resolucion_espacial": resolucion, "cobertura_geografica": cobertura,
            "fecha_observacion": fecha_observacion, "confianza": confianza}


VARIABLES = {
    "area_km2": _v("identificacion", "km²", POL, "Área del polígono (geometría corregida con make_valid) en UTM 14N", "vectorial", "101 polígonos", "alta"),
    "centroide": _v("identificacion", "grados (EPSG:4326)", POL, "Centroide calculado en UTM 14N y reproyectado", "vectorial", "101 polígonos", "alta"),
    "elevacion_minima_m": _v("geografia", "m (EGM2008)", DEM, "Mínimo de celdas de tierra cuyo centro cae en el polígono", "30 m", "toda el área", "media; DSM (incluye edificios y vegetación)", "adquisición TanDEM-X 2011–2015"),
    "elevacion_maxima_m": _v("geografia", "m (EGM2008)", DEM, "Máximo de celdas de tierra del polígono", "30 m", "toda el área", "baja en zona urbana: refleja techos y árboles", "2011–2015"),
    "elevacion_media_m": _v("geografia", "m (EGM2008)", DEM, "Media de celdas de tierra del polígono", "30 m", "toda el área", "media", "2011–2015"),
    "elevacion_mediana_m": _v("geografia", "m (EGM2008)", DEM, "Mediana de celdas de tierra del polígono", "30 m", "toda el área", "media", "2011–2015"),
    "pendiente_media_grados": _v("geografia", "grados", DEM, "Gradiente por diferencias finitas sobre el DEM en UTM 14N; media del polígono", "30 m", "toda el área", "media-baja: los bordes de edificios generan pendientes falsas", "2011–2015"),
    "pendiente_maxima_grados": _v("geografia", "grados", DEM, "Máximo del gradiente en el polígono", "30 m", "toda el área", "baja: dominada por bordes de edificios", "2011–2015"),
    "elevacion_relativa_m": _v("geografia", "m", DEM, "Mediana del polígono menos mediana de la tierra en un anillo de 1 000 m alrededor", "30 m", "toda el área", "media", "2011–2015"),
    "percentil_en_entorno": _v("geografia", "%", DEM, "Porcentaje de celdas del anillo de 1 000 m más bajas que la mediana del polígono", "30 m", "toda el área", "media", "2011–2015"),
    "hand_mediana_m": _v("geografia", "m", DEM, "Height Above Nearest Drainage: altura sobre el cauce modelado (≥1 km²) al que drena cada celda (pysheds D8)", "30 m", "ventana de análisis", "baja-media: cauces modelados, no oficiales", "2011–2015"),
    "acumulacion_flujo_max_km2": _v("geografia", "km²", DEM, "Área de drenaje D8 máxima dentro del polígono, tras llenar depresiones; limitada a la ventana de análisis", "30 m", "ventana ±0.15°", "baja: subestima cuencas grandes y no considera drenaje pluvial", "2011–2015"),
    "distancia_cuerpo_agua_m": _v("geografia", "m", DEM, "Distancia euclidiana mínima del polígono a mar, cauce modelado o cuerpo interior inferido", "30 m", "ventana de análisis", "baja-media: cuerpos de agua derivados del DEM, no cartografía oficial", "2011–2015"),
    "distancia_costa_natural_earth_m": _v("geografia", "m", "Natural Earth 10m coastline", "Distancia vectorial del polígono a la línea de costa", "1:10 000 000", "global", "baja: error posible de cientos de metros"),
    "precipitacion_1h_mm": _v("hidromet", "mm (supuesto)", CONAGUA_P, "Suma de incrementos válidos en la hora previa a la última observación de la estación más cercana", "puntual", "estaciones con datos", "baja si la estación está lejos; ver cobertura", "2023-04-12"),
    "precipitacion_3h_mm": _v("hidromet", "mm (supuesto)", CONAGUA_P, "Ídem, ventana de 3 h", "puntual", "estaciones con datos", "baja", "2023-04-12"),
    "precipitacion_24h_mm": _v("hidromet", "mm (supuesto)", CONAGUA_P, "Ídem, ventana de 24 h; incompleta si la serie inicia después", "puntual", "estaciones con datos", "baja: la serie cubre menos de 24 h", "2023-04-12"),
    "distancia_estacion_km": _v("hidromet", "km", CONAGUA_C, "Distancia de la estación al borde del polígono (0 si está dentro), UTM 14N", "puntual", "catálogo con coordenadas válidas", "alta para la distancia; no implica representatividad"),
    "nivel_rio": _v("hidromet", "desconocida (probablemente m)", CONAGUA_N, "Último registro de la estación hidrométrica más cercana", "puntual", "estaciones con datos", "baja: referencia y unidad no documentadas", "2023-04-12"),
    "eventos_registrados": _v("antecedentes", "número de eventos", "Prensa y avisos (data/antecedentes/eventos_inundacion.json) + SEPOMEX", "Eventos observados distintos cuya colonia mencionada corresponde sin ambigüedad al CP del polígono", "colonia → código postal", "Veracruz, Boca del Río, Medellín", "baja-media: inventario incompleto, sesgado a cobertura de prensa; no es frecuencia", "2010–2026 según el evento"),
    "poblacion": _v("vulnerabilidad", "personas", "INEGI Censo 2020 (no disponible)", "Pendiente: interpolación areal de AGEB/manzana a zona postal", "AGEB/manzana", "sin datos", "no calculado"),
    "indice_marginacion": _v("vulnerabilidad", "índice", "CONAPO 2020 por AGEB (no disponible)", "Pendiente: promedio ponderado por población de las AGEB que intersectan", "AGEB", "sin datos", "no calculado"),
    "indice_susceptibilidad_preliminar": _v("indicadores", "0–100 (relativo)", "derivado", "Promedio simple de subindicadores normalizados por percentil entre los 101 polígonos. HIPÓTESIS DE DISEÑO sin calibrar ni validar", "zona postal", "101 polígonos", "no validado: no es probabilidad de inundación"),
}
