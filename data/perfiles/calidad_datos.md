# Calidad de datos · Perfiles territoriales

Procesado el 2026-11-12T03:36:16+00:00. Nada se eliminó: los problemas se marcan y documentan.

## Resumen

- Polígonos procesados: **101** (zonas de código postal); todos con estadísticas del DEM.
- Cobertura meteorológica: {'insuficiente': 101}. Distancia a la estación con precipitación más cercana:
  29.02–57.73 km. **Con estos archivos no hay cobertura adecuada para ningún polígono**;
  la precipitación por polígono queda en `null`.
- Todos los datos hidrometeorológicos son del **2023-04-12**: históricos, no tiempo real.
- Estaciones del catálogo a ≤ 5.0 km de algún polígono **sin datos** en los archivos recibidos:
  27 (B28039, B28040, C30018, C30048, C30056, C30136, C30192, C30324, C30468, COPVC, CORVC, COTAXTLA, CPREVISIÓN, CPRVC, ELTEJAR, ETEVC, IFLAPOSTAMED, JAMAPA, LAPOSTAVC, MFAVC, PASOTORO, PDTVC, SJNVC, UGALVANESIME, VERACRUZob…). Conseguir sus series mejoraría mucho la cobertura.

## Antecedentes de inundación

- Menciones de colonias en las fuentes: 53. Asignadas sin ambigüedad: 41; ambiguas: 2; sin
  coincidencia en SEPOMEX: 10 (Colina de Los Pájaros, Cuenca I y II, Esperanza, Geo Villas del Puerto, Las Reservas, Mangal, Matacocuite, Muñiz, Paso Real, Vergara de Tarimoya).
- Polígonos con al menos un evento documentado: 13; con algún registro (evento, alerta o riesgo): 22 de 101.
- Las menciones sin coincidencia pueden ser asentamientos nuevos, nombres coloquiales o erratas de la fuente; requieren revisión manual.

## Series diarias del SMN

| Estación | Registro | Días con dato | Años completos | Años completos 1991-2020 | Años incompletos (% de días) | Años sospechosos excluidos | Apta para extremos |
|---|---|---|---|---|---|---|---|
| 30048 EL COPITAL | 1961-05-01 a 2017-12-31 | 93.5 % | 49 | 21 de 30 | 1961 (62 %), 1988 (67 %), 2000 (67 %), 2001 (75 %), 2005 (50 %), 2007 (58 %), 2010 (58 %), 2017 (74 %) | 2017 | sí |
| 30192 VERACRUZ (OBS) | 1951-01-01 a 2022-03-24 | 73.7 % | 51 | 21 de 30 | 1974 (0 %), 1975 (0 %), 1976 (0 %), 1977 (0 %), 1978 (0 %), 1979 (0 %), 1980 (0 %), 1986 (73 %), 1988 (58 %), 1989 (42 %), 1990 (25 %), 2006 (67 %), 2007 (8 %), 2008 (0 %), 2009 (0 %), 2010 (0 %), 2011 (0 %), 2012 (0 %), 2013 (0 %), 2018 (48 %) | 1981, 1982, 1983, 1984, 1985, 1986, 1987, 1988, 1989, 1990, 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006 | sí |
| 30389 SAN JOSÉ NOVILLERO | 2019-03-27 a 2023-07-06 | 73.1 % | 2 | 1 de 30 | 2019 (76 %), 2021 (55 %), 2023 (40 %) | — | no (serie corta) |

No hay valores negativos ni mayores a 300 mm/día. La estación 30389 (San José Novillero, Boca del Río) tiene ~4 años: sus estadísticas son ilustrativas y no se usan para periodos de retorno.

## Problemas generales de las fuentes

| Categoría | Detalle |
|---|---|
| crs | El GeoJSON no declara CRS; se asume EPSG:4326 (estándar RFC 7946) |
| coordenada_invalida | 1765 estaciones del catálogo con coordenadas (0, 0); se excluyen de la asociación |
| coordenada_invalida | 8 estaciones del catálogo con coordenadas fuera de México; se excluyen |
| valor_inconsistente | Estación TOPOCHICO: 12 registros de precipitación fuera de [0, 100.0] mm (mín -10448.4, máx 10525.7); se conservan pero se excluyen de los acumulados |
| frecuencia | Pese al nombre PRECIPITACION_HORA, los intervalos entre registros van de 1 a 730 min (mediana 10); se tratan como incrementos por intervalo, no como intensidades horarias |
| valor_revisar | 3 niveles negativos (CLLCM, BCSJL, SVTSL); pueden ser válidos según la referencia de la escala, se conservan |
| unidades | NIVEL_RIOS_DIA mezcla magnitudes (de −1.1 a 2 561): probablemente elevación del agua (msnm) en unas estaciones y lectura de escala local en otras; sin metadatos no se comparan niveles entre estaciones |
| estacion_sin_catalogo | Estaciones con datos pero sin coordenadas en el catálogo: LOSHERRERA |
| coordenada_invalida | 1 estaciones con datos tienen coordenadas inválidas en el catálogo y no se pueden asociar |
| antecedente_sin_ubicar | 'Las Reservas' (dt_90l_2014) no aparece en SEPOMEX para el municipio indicado |
| antecedente_sin_ubicar | 'Vergara de Tarimoya' (dt_90l_2014) no aparece en SEPOMEX para el municipio indicado |
| antecedente_sin_ubicar | 'Esperanza' (katia_2017_alerta) no aparece en SEPOMEX para el municipio indicado |
| antecedente_sin_ubicar | 'Cuenca I y II' (katia_2017_alerta) no aparece en SEPOMEX para el municipio indicado |
| antecedente_sin_ubicar | 'Mangal' (katia_2017_alerta) no aparece en SEPOMEX para el municipio indicado |
| antecedente_sin_ubicar | 'Paso Real' (katia_2017_alerta) no aparece en SEPOMEX para el municipio indicado |
| antecedente_ambiguo | 'Río Medio' (recurrencia_azteca_veracruz) puede ser los CP 91808, 91809 |
| antecedente_sin_ubicar | 'Muñiz' (onda_tropical_20_2025) no aparece en SEPOMEX para el municipio indicado |
| antecedente_sin_ubicar | 'Colina de Los Pájaros' (tormenta_2026_10_02) no aparece en SEPOMEX para el municipio indicado |
| antecedente_sin_ubicar | 'Matacocuite' (tormenta_2026_10_02) no aparece en SEPOMEX para el municipio indicado |
| antecedente_sin_ubicar | 'Geo Villas del Puerto' (tormenta_2026_10_02) no aparece en SEPOMEX para el municipio indicado |
| antecedente_ambiguo | 'La Carranza' (tormenta_2026_10_02) puede ser los CP 91759, 94297 |
| inhomogeneidad | Estación SMN 30048 (EL COPITAL): años [2017] con posible subregistro frente a la estación vecina; excluidos de las estadísticas |
| inhomogeneidad | Estación SMN 30192 (VERACRUZ (OBS)): años [1981, 1982, 1983, 1984, 1985, 1986, 1987, 1988, 1989, 1990, 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006] con posible subregistro frente a la estación vecina; excluidos de las estadísticas |
| serie_corta | Estación SMN 30389 (SAN JOSÉ NOVILLERO): 2 años válidos; no apta para periodos de retorno |

## Problemas por polígono

| Categoría | Polígonos |
|---|---|
| estacion_lejana | 101 |
| geometria_invalida | 5 |

- `91810` · geometria_invalida: Self-intersection[-96.1695 19.21604] (corregida con make_valid solo para calcular)
- `91870` · geometria_invalida: Self-intersection[-96.1695 19.21604] (corregida con make_valid solo para calcular)
- `91936` · geometria_invalida: Ring Self-intersection[-96.12978 19.15096] (corregida con make_valid solo para calcular)
- `94294` · geometria_invalida: Ring Self-intersection[-96.10913 19.15974] (corregida con make_valid solo para calcular)
- `94299` · geometria_invalida: Self-intersection[-96.10913 19.15974] (corregida con make_valid solo para calcular)

## Variables faltantes

| Variable | Polígonos sin dato |
|---|---|
| `antecedentes.zona_inundable_oficial` | 101 de 101 |
| `hidromet.precipitacion_1h_mm` | 101 de 101 |
| `hidromet.precipitacion_24h_mm` | 101 de 101 |
| `hidromet.tendencia_nivel_rio` | 101 de 101 |
| `vulnerabilidad.cobertura_agua` | 101 de 101 |
| `vulnerabilidad.cobertura_drenaje` | 101 de 101 |
| `vulnerabilidad.indice_marginacion` | 101 de 101 |
| `vulnerabilidad.poblacion` | 101 de 101 |
| `vulnerabilidad.viviendas` | 101 de 101 |
| `antecedentes.eventos_registrados` | 88 de 101 |

## Limitaciones conocidas

1. **DEM de superficie (DSM)**: Copernicus GLO-30 incluye edificios y vegetación. En zona urbana la elevación y la
   pendiente reflejan techos; la pendiente máxima suele ser un borde de edificio. Error vertical de varios metros.
2. **Hidrología modelada**: cauces y cuerpos de agua derivados del DEM, no cartografía oficial. No incluye drenaje
   pluvial ni obras hidráulicas. La acumulación está truncada a la ventana de análisis.
3. **Cuerpos de agua interiores inferidos**: celdas ≤ 0 m no conectadas al mar; pueden ser lagunas, cauces aplanados o
   artefactos. Sin la red hidrográfica del INEGI no se pueden nombrar ni clasificar.
4. **Precipitación**: un solo día, intervalos irregulares, unidad supuesta (mm). La estación TOPOCHICO (Nuevo León,
   fuera del área) tiene saltos de miles de mm, compatibles con un error del sensor o un reinicio de contador.
5. **Niveles de ríos**: un registro por estación y referencias heterogéneas; sin tendencia.
6. **Unidad postal**: los resultados describen la zona completa; una zona grande puede mezclar áreas muy distintas.
7. **Índices**: relativos a estos 101 polígonos y no validados.
