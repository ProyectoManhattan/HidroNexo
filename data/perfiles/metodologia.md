# Metodología · Perfiles territoriales de HIDRA

Generado el 2026-11-12T02:56:29+00:00 con `python3 -m data.scripts.perfiles_territoriales`.

## 1. Unidad territorial

Se procesaron los **101 polígonos existentes** de `data/colonias_veracruz.geojson`, sin crear ni reemplazar ninguno.
Son **zonas de código postal** (SEPOMEX), no colonias, AGEB ni manzanas: una zona suele agrupar varias colonias.
Se conservan el identificador original (`codigo_postal`) y todos los atributos originales.

- CRS de entrada: el archivo no declara CRS; se asume EPSG:4326 (estándar GeoJSON, RFC 7946).
- Cálculos métricos (área, distancias, pendiente): UTM zona 14N (EPSG:32614).
- 5 polígonos tienen autointersecciones. **La geometría original no se modifica**: se corrige una copia con
  `shapely.make_valid` solo para calcular. Los polígonos no se traslapan entre sí.

## 2. Fuentes

| Fuente | Uso | Fecha | Limitaciones |
|---|---|---|---|
| Zonas por código postal del proyecto (data/colonias_veracruz.geojson) | Geometrías | — | Unidad postal, no colonia |
| Copernicus DEM GLO-30 (modelo digital de SUPERFICIE, 30 m) ([enlace](https://copernicus-dem-30m.s3.amazonaws.com)) | Elevación, pendiente, hidrología modelada | Descarga 2026-11-12T02:48:28+00:00 | Es un DSM: incluye edificios y vegetación. Error vertical típico de metros; en zona urbana sobreestima el terreno. El mar está aplanado a ~0 m. |
| Natural Earth 10m (coastline, rivers_lake_centerlines, lakes) | Contraste de la costa | Descarga 2026-11-12T02:45:02+00:00 | Escala 1:10 000 000: no incluye ríos ni lagunas locales cerca de Veracruz; solo se usa para contrastar la costa. |
| CATALOGO_SIH.csv (CONAGUA, Sistema de Información Hidrológica) | Ubicación de estaciones | Recibido 2026-11-12T02:44:56+00:00 | Sin tipo de estación ni metadatos de unidades. 1 765 estaciones con coordenadas (0, 0). |
| PRECIPITACION_HORA.csv (CONAGUA SIH) | Precipitación | Datos 2023-04-12T00:00:00 → 2023-04-12T22:50:00 | Un solo día (2023-04-12). Pese al nombre, los registros son cada 3–20 min. Sin metadatos de unidad: se asume mm por intervalo. |
| NIVEL_RIOS_DIA.csv (CONAGUA SIH) | Nivel de ríos | Datos 2023-04-12T00:00:00 | Un solo registro por estación (2023-04-12). Sin metadatos de unidad ni de referencia: unas estaciones parecen reportar elevación (msnm) y otras lectura de escala local; no son comparables entre sí. |

Teselas del DEM: Copernicus_DSM_COG_10_N18_00_W096_00_DEM.tif, Copernicus_DSM_COG_10_N18_00_W097_00_DEM.tif, Copernicus_DSM_COG_10_N19_00_W096_00_DEM.tif, Copernicus_DSM_COG_10_N19_00_W097_00_DEM.tif.

**No disponibles** (no estaban en el repositorio y sus sitios no eran accesibles desde el entorno de procesamiento):
INEGI (Censo 2020 por AGEB/manzana, Marco Geoestadístico, red hidrográfica 1:50 000), CONAPO (marginación urbana 2020),
CONAGUA `PRECACUM_HORA.csv`, capas oficiales de zonas inundables (Atlas de Riesgos estatal 2023, publicado en PDF; atlas
municipal de 2006) y registros históricos de inundación. Las variables que dependen de ellas quedan en `null`.

Los archivos crudos se guardan en `data/fuentes/`, que **no se sube al repositorio** (`.gitignore`).

## 3. Características físicas

1. Se unen las teselas del DEM en una ventana de ±0.15° alrededor de los polígonos y se
   reproyectan a UTM 14N a 30 m (interpolación bilineal).
2. **Mar**: celdas ≤ 0 m conectadas al borde de la ventana (> 10 km²). **Cuerpo de agua interior inferido**: otras
   zonas conectadas ≤ 0 m de al menos 0.05 km² (posibles lagunas o cauces aplanados en el DEM; no verificado).
3. Estadísticas de elevación y pendiente: celdas de tierra cuyo centro cae dentro del polígono (si no hay ninguna, se
   usan las celdas que toca). Pendiente por diferencias finitas.
4. **Elevación relativa** = mediana del polígono − mediana de la tierra en un anillo de 1000 m alrededor.
   Una elevación absoluta baja **no** se interpreta por sí sola como inundable.
5. **Hidrología modelada** (pysheds, D8): relleno de fosas y depresiones, resolución de planos, dirección y acumulación de flujo.
   Cauce modelado ≥ 1.0 km² de drenaje; cauce mayor ≥ 25.0 km².
   **HAND** (altura sobre el cauce al que drena cada celda) con los cauces ≥ 1.0 km².
   La acumulación está limitada a la ventana (subestima cuencas grandes como la del Jamapa) y no representa el drenaje pluvial.
6. Distancias: mínima euclidiana desde el polígono a cada tipo de cuerpo de agua. La cercanía a un cauce **no** implica inundabilidad.

Rangos obtenidos (mín / mediana / máx): elevación mediana (0.91, 9.01, 49.98) m;
elevación relativa (-5.95, 0.06, 26.12) m;
HAND mediano (0.0, 2.51, 20.88) m.

## 4. Hidrometeorología

- Se asocian a cada polígono las 3 estaciones **con datos** más cercanas (distancia de la
  estación al borde del polígono; 0 si está dentro). Se excluyen estaciones con coordenadas (0, 0) o fuera de México.
- **Cobertura** según la estación con precipitación más cercana: adecuada ≤ 5.0 km,
  limitada ≤ 15.0 km, insuficiente después (criterio de diseño, no validado).
  Con cobertura insuficiente, la precipitación **del polígono** queda en `null`; los valores de la estación se conservan
  en `estaciones_meteorologicas` como dato de la estación, no del polígono.
- Acumulados de 1, 3 y 24 h: suma de incrementos válidos en la ventana que termina en la última observación de cada
  estación. La ventana de 24 h está incompleta porque la serie cubre menos de un día.
- **Unidades**: los archivos no traen metadatos. Se asume mm por intervalo (convención del SIH); verificar con CONAGUA.
  Pese al nombre `PRECIPITACION_HORA`, los registros son cada 3–20 min: se tratan como incrementos, no como intensidades horarias.
- Valores fuera de [0, 100.0] mm por intervalo se marcan inválidos y se excluyen de los
  acumulados, sin borrarlos (ver `calidad_datos.md`).
- **Niveles**: un solo registro por estación; la tendencia queda `null`. No se comparan niveles entre estaciones porque
  la referencia (escala local o msnm) no está documentada.
- Todos los datos son del 2023-04-12: son **históricos**, no tiempo real.

## 5. Vulnerabilidad social (pendiente)

Método propuesto al contar con INEGI y CONAPO: (a) distribuir la población de cada AGEB a la zona postal según la
fracción de sus **manzanas** (preferente) o de su área (respaldo) que cae en la zona; (b) para índices como la
marginación, promedio ponderado por población de las AGEB que intersectan, reportando cuántas AGEB intervienen y qué
fracción de la zona cubren. **No** se asigna una AGEB completa a una zona sin esta correspondencia.

## 6. Indicadores territoriales (hipótesis de diseño)

Cada variable se normaliza a 0–100 por **percentil entre los 101 polígonos**, invirtiendo la escala cuando un valor
menor implica mayor susceptibilidad, amenaza o vulnerabilidad. Por eso 100 significa "el más desfavorable de este
conjunto", no un umbral físico.

| Variable | Dimensión | Dirección | Justificación |
|---|---|---|---|
| `elevacion_relativa_m` | susceptibilidad | menor valor → mayor indicador | Zonas más bajas que su entorno tienden a recibir y retener escurrimiento |
| `hand_mediana_m` | susceptibilidad | menor valor → mayor indicador | Menor altura sobre el cauce al que drenan implica mayor exposición a desbordes |
| `pendiente_media_grados` | susceptibilidad | menor valor → mayor indicador | Terreno plano drena más lento (encharcamiento); en laderas el peligro es otro (escurrimiento rápido) |
| `distancia_cauce_mayor_m` | susceptibilidad | menor valor → mayor indicador | Proximidad a cauces modelados mayores (probables ríos). La cercanía sola no implica inundabilidad |
| `acumulacion_flujo_max_km2` | susceptibilidad | mayor valor → mayor indicador | Mayor área que drena a través del polígono |
| `distancia_mar_m` | susceptibilidad | menor valor → mayor indicador | Exposición costera (marea de tormenta, nortes); peligro distinto al pluvial |
| `eventos_inundacion_registrados` | susceptibilidad | mayor valor → mayor indicador | Antecedentes documentados (sin fuente disponible) |
| `precipitacion_1h_mm` | amenaza | mayor valor → mayor indicador | Intensidad reciente |
| `precipitacion_3h_mm` | amenaza | mayor valor → mayor indicador | Acumulado de corto plazo |
| `precipitacion_24h_mm` | amenaza | mayor valor → mayor indicador | Acumulado diario (saturación del suelo y del drenaje) |
| `tendencia_nivel_rio` | amenaza | mayor valor → mayor indicador | Nivel del río al alza (requiere serie temporal) |
| `poblacion` | exposicion | mayor valor → mayor indicador | Personas potencialmente expuestas |
| `viviendas` | exposicion | mayor valor → mayor indicador | Viviendas potencialmente expuestas |
| `indice_marginacion` | exposicion | mayor valor → mayor indicador | Menor capacidad de respuesta y recuperación |
| `cobertura_agua_pct` | exposicion | menor valor → mayor indicador | Menor cobertura de agua entubada |
| `cobertura_drenaje_pct` | exposicion | menor valor → mayor indicador | Menor cobertura de drenaje |

**Índice preliminar de susceptibilidad** = promedio simple de los subindicadores disponibles (mínimo
4), con pesos iguales por diseño. Categorías relativas: baja < 33.3 ≤ media < 66.7 ≤ elevada.

> Es una **hipótesis de diseño pendiente de calibración y validación con eventos históricos**. No es una probabilidad de
> inundación y HIDRA no predice inundaciones con él. Hay variables correlacionadas (elevación relativa y HAND), que el
> promedio simple sobrepondera. Amenaza y exposición no se calculan porque faltan datos representativos.

## 7. Trazabilidad por variable

| Variable | Unidad | Fuente | Método | Resolución | Fecha de observación | Confianza / limitaciones |
|---|---|---|---|---|---|---|
| `area_km2` | km² | Polígonos del proyecto (SEPOMEX) | Área del polígono (geometría corregida con make_valid) en UTM 14N | vectorial | no aplica | alta |
| `centroide` | grados (EPSG:4326) | Polígonos del proyecto (SEPOMEX) | Centroide calculado en UTM 14N y reproyectado | vectorial | no aplica | alta |
| `elevacion_minima_m` | m (EGM2008) | Copernicus DEM GLO-30 (DSM) | Mínimo de celdas de tierra cuyo centro cae en el polígono | 30 m | adquisición TanDEM-X 2011–2015 | media; DSM (incluye edificios y vegetación) |
| `elevacion_maxima_m` | m (EGM2008) | Copernicus DEM GLO-30 (DSM) | Máximo de celdas de tierra del polígono | 30 m | 2011–2015 | baja en zona urbana: refleja techos y árboles |
| `elevacion_media_m` | m (EGM2008) | Copernicus DEM GLO-30 (DSM) | Media de celdas de tierra del polígono | 30 m | 2011–2015 | media |
| `elevacion_mediana_m` | m (EGM2008) | Copernicus DEM GLO-30 (DSM) | Mediana de celdas de tierra del polígono | 30 m | 2011–2015 | media |
| `pendiente_media_grados` | grados | Copernicus DEM GLO-30 (DSM) | Gradiente por diferencias finitas sobre el DEM en UTM 14N; media del polígono | 30 m | 2011–2015 | media-baja: los bordes de edificios generan pendientes falsas |
| `pendiente_maxima_grados` | grados | Copernicus DEM GLO-30 (DSM) | Máximo del gradiente en el polígono | 30 m | 2011–2015 | baja: dominada por bordes de edificios |
| `elevacion_relativa_m` | m | Copernicus DEM GLO-30 (DSM) | Mediana del polígono menos mediana de la tierra en un anillo de 1 000 m alrededor | 30 m | 2011–2015 | media |
| `percentil_en_entorno` | % | Copernicus DEM GLO-30 (DSM) | Porcentaje de celdas del anillo de 1 000 m más bajas que la mediana del polígono | 30 m | 2011–2015 | media |
| `hand_mediana_m` | m | Copernicus DEM GLO-30 (DSM) | Height Above Nearest Drainage: altura sobre el cauce modelado (≥1 km²) al que drena cada celda (pysheds D8) | 30 m | 2011–2015 | baja-media: cauces modelados, no oficiales |
| `acumulacion_flujo_max_km2` | km² | Copernicus DEM GLO-30 (DSM) | Área de drenaje D8 máxima dentro del polígono, tras llenar depresiones; limitada a la ventana de análisis | 30 m | 2011–2015 | baja: subestima cuencas grandes y no considera drenaje pluvial |
| `distancia_cuerpo_agua_m` | m | Copernicus DEM GLO-30 (DSM) | Distancia euclidiana mínima del polígono a mar, cauce modelado o cuerpo interior inferido | 30 m | 2011–2015 | baja-media: cuerpos de agua derivados del DEM, no cartografía oficial |
| `distancia_costa_natural_earth_m` | m | Natural Earth 10m coastline | Distancia vectorial del polígono a la línea de costa | 1:10 000 000 | no aplica | baja: error posible de cientos de metros |
| `precipitacion_1h_mm` | mm (supuesto) | CONAGUA SIH · PRECIPITACION_HORA.csv | Suma de incrementos válidos en la hora previa a la última observación de la estación más cercana | puntual | 2023-04-12 | baja si la estación está lejos; ver cobertura |
| `precipitacion_3h_mm` | mm (supuesto) | CONAGUA SIH · PRECIPITACION_HORA.csv | Ídem, ventana de 3 h | puntual | 2023-04-12 | baja |
| `precipitacion_24h_mm` | mm (supuesto) | CONAGUA SIH · PRECIPITACION_HORA.csv | Ídem, ventana de 24 h; incompleta si la serie inicia después | puntual | 2023-04-12 | baja: la serie cubre menos de 24 h |
| `distancia_estacion_km` | km | CONAGUA SIH · CATALOGO_SIH.csv | Distancia de la estación al borde del polígono (0 si está dentro), UTM 14N | puntual | no aplica | alta para la distancia; no implica representatividad |
| `nivel_rio` | desconocida (probablemente m) | CONAGUA SIH · NIVEL_RIOS_DIA.csv | Último registro de la estación hidrométrica más cercana | puntual | 2023-04-12 | baja: referencia y unidad no documentadas |
| `poblacion` | personas | INEGI Censo 2020 (no disponible) | Pendiente: interpolación areal de AGEB/manzana a zona postal | AGEB/manzana | no aplica | no calculado |
| `indice_marginacion` | índice | CONAPO 2020 por AGEB (no disponible) | Pendiente: promedio ponderado por población de las AGEB que intersectan | AGEB | no aplica | no calculado |
| `indice_susceptibilidad_preliminar` | 0–100 (relativo) | derivado | Promedio simple de subindicadores normalizados por percentil entre los 101 polígonos. HIPÓTESIS DE DISEÑO sin calibrar ni validar | zona postal | no aplica | no validado: no es probabilidad de inundación |

## 8. PostgreSQL / PostGIS

El backend ya usa PostGIS (tabla `colonias`). **No se modificó el esquema.** Si los perfiles pasan a la API, se propone:

- `perfil_territorial` (1:1 con `colonias`): variables físicas estáticas + `fecha_procesamiento`.
- `indicador_territorial` (formato largo): `colonia_id`, `variable`, `valor`, `valor_normalizado`, `fuente_id`,
  `fecha_observacion`, `metodo`, `confianza`. Permite agregar variables sin migraciones.
- `fuente_datos`: catálogo de fuentes con URL, licencia y fecha de descarga.

Conviene hacerlo cuando haya un consumidor real (la API o el motor de riesgo); hoy los archivos bastan.

## 9. Reproducir

```bash
pip install -r data/scripts/perfiles_territoriales/requirements.txt
# Colocar en data/fuentes/: conagua/*.csv, dem/Copernicus_DSM_COG_10_*_DEM.tif, natural_earth/ne_10m_*.geojson
python3 -m data.scripts.perfiles_territoriales
python3 -m data.scripts.perfiles_territoriales ficha 91700
```
