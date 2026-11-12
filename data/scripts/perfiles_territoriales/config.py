"""Rutas, fuentes y criterios. Los umbrales son CRITERIOS DE DISEÑO, no valores validados."""
from datetime import datetime, timezone
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[3]
DATA = RAIZ / "data"
FUENTES = DATA / "fuentes"          # ignorada por Git: datos crudos
SALIDA = DATA / "perfiles"

POLIGONOS = DATA / "colonias_veracruz.geojson"
CONAGUA = FUENTES / "conagua"
DEM_DIR = FUENTES / "dem"
NATURAL_EARTH = FUENTES / "natural_earth"

FECHA_PROCESO = datetime.now(timezone.utc).replace(microsecond=0)

# Proyección métrica para áreas, distancias y pendientes: UTM zona 14N (cubre Veracruz)
CRS_GEO = "EPSG:4326"
CRS_METRICO = "EPSG:32614"

# Ventana de análisis del DEM alrededor de los polígonos (grados). Se amplía para que
# la acumulación de flujo y la elevación del entorno no se corten en el borde.
MARGEN_DEM_GRADOS = 0.15
RESOLUCION_M = 30

# Criterios de diseño (documentados en metodologia.md; pendientes de calibración)
ANILLO_ENTORNO_M = 1000            # entorno para la elevación relativa
UMBRAL_CAUCE_KM2 = 1.0             # área de drenaje mínima para considerar una celda "cauce modelado"
UMBRAL_CAUCE_MAYOR_KM2 = 25.0      # cauce modelado "mayor" (probable río)
CERCA_AGUA_M = 500                 # "cerca" de un cuerpo de agua
MIN_CELDAS_DEM = 10                # menos celdas = estadísticas poco confiables

# Asociación estación–polígono (distancia al borde del polígono)
COBERTURA_ADECUADA_KM = 5.0
COBERTURA_LIMITADA_KM = 15.0
MAX_ESTACIONES_REPORTADAS = 3
# Precipitación por intervalo fuera de este rango se marca inválida (no se borra)
PRECIP_MAX_INTERVALO_MM = 100.0
# Antigüedad a partir de la cual una medición se considera desactualizada
DESACTUALIZADO_DIAS = 2

FUENTES_DOC = {
    "poligonos": {
        "nombre": "Zonas por código postal del proyecto (data/colonias_veracruz.geojson)",
        "origen": "SEPOMEX vía open-mexico/mexico-geojson (MIT); municipios con INEGI vía PhantomInsights/mexico-geojson (MIT). Ver data/scripts/generar_colonias.py",
        "url": "https://github.com/open-mexico/mexico-geojson",
    },
    "dem": {
        "nombre": "Copernicus DEM GLO-30 (modelo digital de SUPERFICIE, 30 m)",
        "origen": "ESA / Copernicus, distribuido en AWS Open Data",
        "url": "https://copernicus-dem-30m.s3.amazonaws.com",
        "limitaciones": "Es un DSM: incluye edificios y vegetación. Error vertical típico de metros; en zona urbana sobreestima el terreno. El mar está aplanado a ~0 m.",
    },
    "natural_earth": {
        "nombre": "Natural Earth 10m (coastline, rivers_lake_centerlines, lakes)",
        "origen": "Natural Earth (dominio público) vía GitHub nvkelso/natural-earth-vector",
        "url": "https://github.com/nvkelso/natural-earth-vector",
        "limitaciones": "Escala 1:10 000 000: no incluye ríos ni lagunas locales cerca de Veracruz; solo se usa para contrastar la costa.",
    },
    "conagua_catalogo": {
        "nombre": "CATALOGO_SIH.csv (CONAGUA, Sistema de Información Hidrológica)",
        "origen": "Archivo proporcionado por el equipo; no se sube al repositorio",
        "limitaciones": "Sin tipo de estación ni metadatos de unidades. 1 765 estaciones con coordenadas (0, 0).",
    },
    "conagua_precipitacion": {
        "nombre": "PRECIPITACION_HORA.csv (CONAGUA SIH)",
        "origen": "Archivo proporcionado por el equipo; no se sube al repositorio",
        "limitaciones": "Un solo día (2023-04-12). Pese al nombre, los registros son cada 3–20 min. Sin metadatos de unidad: se asume mm por intervalo.",
    },
    "conagua_nivel": {
        "nombre": "NIVEL_RIOS_DIA.csv (CONAGUA SIH)",
        "origen": "Archivo proporcionado por el equipo; no se sube al repositorio",
        "limitaciones": "Un solo registro por estación (2023-04-12). Sin metadatos de unidad ni de referencia: unas estaciones parecen reportar elevación (msnm) y otras lectura de escala local; no son comparables entre sí.",
    },
}
