"""Escritura de entregables: GeoJSON, JSON, CSV, metodología y calidad de datos."""
import csv
import json
import math
from collections import Counter

import numpy as np

from . import config, indicadores, metadatos


def _limpio(x):
    if isinstance(x, dict):
        return {k: _limpio(v) for k, v in x.items()}
    if isinstance(x, (list, tuple)):
        return [_limpio(v) for v in x]
    if isinstance(x, np.generic):
        x = x.item()
    if isinstance(x, float) and (math.isnan(x) or math.isinf(x)):
        return None
    return x


def escribir(r) -> list:
    config.SALIDA.mkdir(parents=True, exist_ok=True)
    perfiles = [_limpio(p) for p in r["perfiles"]]
    por_id = {p["id_poligono"]: p for p in perfiles}
    meta = {
        "fecha_procesamiento": config.FECHA_PROCESO.isoformat(),
        "unidad_territorial": "zona de código postal (no colonia, AGEB ni manzana)",
        "n_poligonos": len(perfiles),
        "crs": config.CRS_GEO, "crs_calculo": config.CRS_METRICO,
        "advertencia": "Los índices son hipótesis de diseño, relativos a estos polígonos; no son probabilidades de inundación.",
        "fuentes": r["fuentes"],
        "variables": metadatos.VARIABLES,
        "criterios_de_diseno": {k: getattr(config, k) for k in (
            "ANILLO_ENTORNO_M", "UMBRAL_CAUCE_KM2", "UMBRAL_CAUCE_MAYOR_KM2", "CERCA_AGUA_M", "MIN_CELDAS_DEM",
            "COBERTURA_ADECUADA_KM", "COBERTURA_LIMITADA_KM", "PRECIP_MAX_INTERVALO_MM", "DESACTUALIZADO_DIAS")},
        "problemas_de_calidad": r["bitacora"].resumen(),
    }
    rutas = []

    # 1. GeoJSON: geometría y atributos ORIGINALES tal cual + perfil
    original = json.loads(config.POLIGONOS.read_text(encoding="utf-8"))
    features = []
    for f in original["features"]:
        pid = str(f["properties"]["codigo_postal"])
        features.append({"type": "Feature", "geometry": f["geometry"],
                         "properties": {**f["properties"], "perfil_territorial": por_id.get(pid)}})
    ruta = config.SALIDA / "perfiles_territoriales.geojson"
    ruta.write_text(json.dumps({"type": "FeatureCollection", "metadatos": meta, "features": features}, ensure_ascii=False), encoding="utf-8")
    rutas.append(ruta)

    # 2. JSON
    ruta = config.SALIDA / "perfiles_territoriales.json"
    ruta.write_text(json.dumps({"metadatos": meta, "perfiles": perfiles}, ensure_ascii=False, indent=1), encoding="utf-8")
    rutas.append(ruta)

    # 3. CSV plano
    ruta = config.SALIDA / "resumen_territorial.csv"
    columnas = ["id_poligono", "nombre", "tipo_unidad", "municipio", "area_km2", "centroide_lon", "centroide_lat",
                "elevacion_minima_m", "elevacion_media_m", "elevacion_mediana_m", "elevacion_maxima_m",
                "elevacion_relativa_m", "pendiente_media_grados", "hand_mediana_m",
                "distancia_cuerpo_agua_m", "tipo_cuerpo_agua", "distancia_mar_m", "distancia_cauce_mayor_m",
                "acumulacion_flujo_max_km2", "cobertura_meteorologica", "estacion_meteorologica_cercana",
                "distancia_estacion_km", "estacion_hidrometrica_cercana", "distancia_estacion_hidrometrica_km",
                "nivel_rio", "fecha_nivel_rio", "datos_hidromet_historicos",
                "indice_susceptibilidad_preliminar", "categoria_relativa", "n_variables_faltantes", "observaciones"]
    with ruta.open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(columnas)
        for p in perfiles:
            g, h, s = p["caracteristicas_geograficas"], p["condiciones_hidrometeorologicas"], p["indicadores"]["susceptibilidad"]
            w.writerow([p["id_poligono"], p["nombre"], p["tipo_unidad"], p["municipio"], p["identificacion"]["area_km2"],
                        p["identificacion"]["centroide"]["lon"], p["identificacion"]["centroide"]["lat"],
                        g["elevacion_minima_m"], g["elevacion_media_m"], g["elevacion_mediana_m"], g["elevacion_maxima_m"],
                        g["elevacion_relativa_m"], g["pendiente_media_grados"], g["hand_mediana_m"],
                        g["distancia_cuerpo_agua_m"], g["tipo_cuerpo_agua"], g["distancias_m"].get("mar"),
                        g["distancias_m"].get("cauce_mayor_modelado"), g["acumulacion_flujo"]["max_km2"],
                        h["cobertura_meteorologica"], h["estacion_meteorologica_cercana"], h["distancia_estacion_km"],
                        h["estacion_hidrometrica_cercana"], h["distancia_estacion_hidrometrica_km"], h["nivel_rio"],
                        h["fecha_nivel_rio"], h["datos_historicos"], s["indice_preliminar"], s["categoria_relativa"],
                        len(p["calidad_informacion"]["variables_faltantes"]), " | ".join(p["calidad_informacion"]["observaciones"])])
    rutas.append(ruta)

    ruta = config.SALIDA / "metodologia.md"
    ruta.write_text(_metodologia(r, perfiles), encoding="utf-8")
    rutas.append(ruta)
    ruta = config.SALIDA / "calidad_datos.md"
    ruta.write_text(_calidad(r, perfiles), encoding="utf-8")
    rutas.append(ruta)
    return rutas


# ---------------------------------------------------------------- documentos
def _rango(perfiles, f):
    v = [x for x in (f(p) for p in perfiles) if x is not None]
    return (min(v), float(np.median(v)), max(v)) if v else (None, None, None)


def _metodologia(r, perfiles) -> str:
    F = r["fuentes"]
    tabla_ind = "\n".join(f"| `{c}` | {d} | {'mayor valor → mayor indicador' if s == 'mayor' else 'menor valor → mayor indicador'} | {j} |"
                          for c, d, s, j in indicadores.VARIABLES)
    tabla_var = "\n".join(f"| `{k}` | {v['unidad']} | {v['fuente']} | {v['metodo']} | {v['resolucion_espacial']} | {v['fecha_observacion']} | {v['confianza']} |"
                          for k, v in metadatos.VARIABLES.items())
    return f"""# Metodología · Perfiles territoriales de HIDRA

Generado el {config.FECHA_PROCESO.isoformat()} con `python3 -m data.scripts.perfiles_territoriales`.

## 1. Unidad territorial

Se procesaron los **{len(perfiles)} polígonos existentes** de `data/colonias_veracruz.geojson`, sin crear ni reemplazar ninguno.
Son **zonas de código postal** (SEPOMEX), no colonias, AGEB ni manzanas: una zona suele agrupar varias colonias.
Se conservan el identificador original (`codigo_postal`) y todos los atributos originales.

- CRS de entrada: el archivo no declara CRS; se asume EPSG:4326 (estándar GeoJSON, RFC 7946).
- Cálculos métricos (área, distancias, pendiente): UTM zona 14N (EPSG:32614).
- 5 polígonos tienen autointersecciones. **La geometría original no se modifica**: se corrige una copia con
  `shapely.make_valid` solo para calcular. Los polígonos no se traslapan entre sí.

## 2. Fuentes

| Fuente | Uso | Fecha | Limitaciones |
|---|---|---|---|
| {F['poligonos']['nombre']} | Geometrías | — | Unidad postal, no colonia |
| {F['dem']['nombre']} ([enlace]({F['dem']['url']})) | Elevación, pendiente, hidrología modelada | Descarga {F['dem']['fecha_descarga']} | {F['dem']['limitaciones']} |
| {F['natural_earth']['nombre']} | Contraste de la costa | Descarga {F['natural_earth']['fecha_descarga']} | {F['natural_earth']['limitaciones']} |
| {F['conagua_catalogo']['nombre']} | Ubicación de estaciones | Recibido {F['conagua_catalogo']['fecha_recepcion']} | {F['conagua_catalogo']['limitaciones']} |
| {F['conagua_precipitacion']['nombre']} | Precipitación | Datos {F['conagua_precipitacion']['periodo'][0]} → {F['conagua_precipitacion']['periodo'][1]} | {F['conagua_precipitacion']['limitaciones']} |
| {F['conagua_nivel']['nombre']} | Nivel de ríos | Datos {F['conagua_nivel']['periodo'][0]} | {F['conagua_nivel']['limitaciones']} |

Teselas del DEM: {', '.join(F['dem']['teselas'])}.

**No disponibles** (no estaban en el repositorio y sus sitios no eran accesibles desde el entorno de procesamiento):
INEGI (Censo 2020 por AGEB/manzana, Marco Geoestadístico, red hidrográfica 1:50 000), CONAPO (marginación urbana 2020),
CONAGUA `PRECACUM_HORA.csv`, capas oficiales de zonas inundables (Atlas de Riesgos estatal 2023, publicado en PDF; atlas
municipal de 2006) y registros históricos de inundación. Las variables que dependen de ellas quedan en `null`.

Los archivos crudos se guardan en `data/fuentes/`, que **no se sube al repositorio** (`.gitignore`).

## 3. Características físicas

1. Se unen las teselas del DEM en una ventana de ±{config.MARGEN_DEM_GRADOS}° alrededor de los polígonos y se
   reproyectan a UTM 14N a {config.RESOLUCION_M} m (interpolación bilineal).
2. **Mar**: celdas ≤ 0 m conectadas al borde de la ventana (> 10 km²). **Cuerpo de agua interior inferido**: otras
   zonas conectadas ≤ 0 m de al menos 0.05 km² (posibles lagunas o cauces aplanados en el DEM; no verificado).
3. Estadísticas de elevación y pendiente: celdas de tierra cuyo centro cae dentro del polígono (si no hay ninguna, se
   usan las celdas que toca). Pendiente por diferencias finitas.
4. **Elevación relativa** = mediana del polígono − mediana de la tierra en un anillo de {config.ANILLO_ENTORNO_M} m alrededor.
   Una elevación absoluta baja **no** se interpreta por sí sola como inundable.
5. **Hidrología modelada** (pysheds, D8): relleno de fosas y depresiones, resolución de planos, dirección y acumulación de flujo.
   Cauce modelado ≥ {config.UMBRAL_CAUCE_KM2} km² de drenaje; cauce mayor ≥ {config.UMBRAL_CAUCE_MAYOR_KM2} km².
   **HAND** (altura sobre el cauce al que drena cada celda) con los cauces ≥ {config.UMBRAL_CAUCE_KM2} km².
   La acumulación está limitada a la ventana (subestima cuencas grandes como la del Jamapa) y no representa el drenaje pluvial.
6. Distancias: mínima euclidiana desde el polígono a cada tipo de cuerpo de agua. La cercanía a un cauce **no** implica inundabilidad.

Rangos obtenidos (mín / mediana / máx): elevación mediana {_rango(perfiles, lambda p: p['caracteristicas_geograficas']['elevacion_mediana_m'])} m;
elevación relativa {_rango(perfiles, lambda p: p['caracteristicas_geograficas']['elevacion_relativa_m'])} m;
HAND mediano {_rango(perfiles, lambda p: p['caracteristicas_geograficas']['hand_mediana_m'])} m.

## 4. Hidrometeorología

- Se asocian a cada polígono las {config.MAX_ESTACIONES_REPORTADAS} estaciones **con datos** más cercanas (distancia de la
  estación al borde del polígono; 0 si está dentro). Se excluyen estaciones con coordenadas (0, 0) o fuera de México.
- **Cobertura** según la estación con precipitación más cercana: adecuada ≤ {config.COBERTURA_ADECUADA_KM} km,
  limitada ≤ {config.COBERTURA_LIMITADA_KM} km, insuficiente después (criterio de diseño, no validado).
  Con cobertura insuficiente, la precipitación **del polígono** queda en `null`; los valores de la estación se conservan
  en `estaciones_meteorologicas` como dato de la estación, no del polígono.
- Acumulados de 1, 3 y 24 h: suma de incrementos válidos en la ventana que termina en la última observación de cada
  estación. La ventana de 24 h está incompleta porque la serie cubre menos de un día.
- **Unidades**: los archivos no traen metadatos. Se asume mm por intervalo (convención del SIH); verificar con CONAGUA.
  Pese al nombre `PRECIPITACION_HORA`, los registros son cada 3–20 min: se tratan como incrementos, no como intensidades horarias.
- Valores fuera de [0, {config.PRECIP_MAX_INTERVALO_MM}] mm por intervalo se marcan inválidos y se excluyen de los
  acumulados, sin borrarlos (ver `calidad_datos.md`).
- **Niveles**: un solo registro por estación; la tendencia queda `null`. No se comparan niveles entre estaciones porque
  la referencia (escala local o msnm) no está documentada.
- Todos los datos son del {F['conagua_precipitacion']['periodo'][0][:10]}: son **históricos**, no tiempo real.

## 5. Vulnerabilidad social (pendiente)

Método propuesto al contar con INEGI y CONAPO: (a) distribuir la población de cada AGEB a la zona postal según la
fracción de sus **manzanas** (preferente) o de su área (respaldo) que cae en la zona; (b) para índices como la
marginación, promedio ponderado por población de las AGEB que intersectan, reportando cuántas AGEB intervienen y qué
fracción de la zona cubren. **No** se asigna una AGEB completa a una zona sin esta correspondencia.

## 6. Indicadores territoriales (hipótesis de diseño)

Cada variable se normaliza a 0–100 por **percentil entre los {len(perfiles)} polígonos**, invirtiendo la escala cuando un valor
menor implica mayor susceptibilidad, amenaza o vulnerabilidad. Por eso 100 significa "el más desfavorable de este
conjunto", no un umbral físico.

| Variable | Dimensión | Dirección | Justificación |
|---|---|---|---|
{tabla_ind}

**Índice preliminar de susceptibilidad** = promedio simple de los subindicadores disponibles (mínimo
{indicadores.MIN_VARIABLES_INDICE}), con pesos iguales por diseño. Categorías relativas: baja < 33.3 ≤ media < 66.7 ≤ elevada.

> Es una **hipótesis de diseño pendiente de calibración y validación con eventos históricos**. No es una probabilidad de
> inundación y HIDRA no predice inundaciones con él. Hay variables correlacionadas (elevación relativa y HAND), que el
> promedio simple sobrepondera. Amenaza y exposición no se calculan porque faltan datos representativos.

## 7. Trazabilidad por variable

| Variable | Unidad | Fuente | Método | Resolución | Fecha de observación | Confianza / limitaciones |
|---|---|---|---|---|---|---|
{tabla_var}

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
"""


def _calidad(r, perfiles) -> str:
    bit = r["bitacora"]
    cob = Counter(p["condiciones_hidrometeorologicas"]["cobertura_meteorologica"] for p in perfiles)
    falt = Counter(v for p in perfiles for v in p["calidad_informacion"]["variables_faltantes"])
    dist = sorted(p["condiciones_hidrometeorologicas"]["distancia_estacion_km"] for p in perfiles
                  if p["condiciones_hidrometeorologicas"]["distancia_estacion_km"] is not None)
    sin_datos = sorted({e for p in perfiles for e in p["condiciones_hidrometeorologicas"]["estaciones_catalogo_cercanas_sin_datos"]})
    generales = [p for p in bit.problemas if not p["poligono"]]
    por_pol = [p for p in bit.problemas if p["poligono"]]
    cat_pol = Counter(p["categoria"] for p in por_pol)
    filas_gen = "\n".join(f"| {p['categoria']} | {p['detalle']} |" for p in generales)
    filas_pol = "\n".join(f"| {k} | {v} |" for k, v in sorted(cat_pol.items()))
    detalle_pol = "\n".join(f"- `{p['poligono']}` · {p['categoria']}: {p['detalle']}" for p in por_pol if p["categoria"] != "estacion_lejana")
    filas_falt = "\n".join(f"| `{k}` | {v} de {len(perfiles)} |" for k, v in sorted(falt.items(), key=lambda x: -x[1]))
    g = perfiles
    return f"""# Calidad de datos · Perfiles territoriales

Procesado el {config.FECHA_PROCESO.isoformat()}. Nada se eliminó: los problemas se marcan y documentan.

## Resumen

- Polígonos procesados: **{len(g)}** (zonas de código postal); todos con estadísticas del DEM.
- Cobertura meteorológica: {dict(cob)}. Distancia a la estación con precipitación más cercana:
  {dist[0] if dist else '—'}–{dist[-1] if dist else '—'} km. **Con estos archivos no hay cobertura adecuada para ningún polígono**;
  la precipitación por polígono queda en `null`.
- Todos los datos hidrometeorológicos son del **2023-04-12**: históricos, no tiempo real.
- Estaciones del catálogo a ≤ {config.COBERTURA_ADECUADA_KM} km de algún polígono **sin datos** en los archivos recibidos:
  {len(sin_datos)} ({', '.join(sin_datos[:25])}{'…' if len(sin_datos) > 25 else ''}). Conseguir sus series mejoraría mucho la cobertura.

## Problemas generales de las fuentes

| Categoría | Detalle |
|---|---|
{filas_gen}

## Problemas por polígono

| Categoría | Polígonos |
|---|---|
{filas_pol}

{detalle_pol}

## Variables faltantes

| Variable | Polígonos sin dato |
|---|---|
{filas_falt}

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
7. **Índices**: relativos a estos {len(g)} polígonos y no validados.
"""
