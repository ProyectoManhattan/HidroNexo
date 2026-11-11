"""Carga de datos de ejemplo.

Formato esperado (lo prepara Persona B en data/):

data/colonias_veracruz.geojson
    FeatureCollection de Polygon o MultiPolygon (EPSG:4326) con propiedades:
    nombre (obligatorio), municipio, vulnerabilidad (0–1), vulnerabilidad_fuente ("real"/"ejemplo")

data/reportes_prueba.json
    Lista de objetos: {"categoria", "severidad", "lat", "lon", "descripcion"}
"""
import json

from sqlalchemy import delete, func
from sqlalchemy.orm import Session

from app.alertas.modelos import Alerta
from app.colonias.modelos import Colonia
from app.config import settings
from app.dispositivos.modelos import Dispositivo
from app.meteorologia import estado as meteo
from app.reportes import servicio as reportes
from app.reportes.esquemas import ReporteEntrada
from app.reportes.modelos import Reporte
from app.riesgo.modelos import RiesgoColonia
from app.riesgo.servicio import recalcular_todas


def cargar_colonias(db: Session) -> int:
    archivo = settings.data_dir / "colonias_veracruz.geojson"
    if not archivo.exists():
        return 0
    features = json.loads(archivo.read_text(encoding="utf-8"))["features"]
    for f in features:
        p = f["properties"]
        geom = func.ST_Multi(func.ST_SetSRID(func.ST_GeomFromGeoJSON(json.dumps(f["geometry"])), 4326))
        db.add(
            Colonia(
                nombre=p["nombre"],
                municipio=p.get("municipio", "Veracruz"),
                vulnerabilidad=float(p.get("vulnerabilidad", 0.0)),
                vulnerabilidad_fuente=p.get("vulnerabilidad_fuente", "ejemplo"),
                geom=geom,
            )
        )
    db.commit()
    return len(features)


def cargar_reportes(db: Session) -> int:
    archivo = settings.data_dir / "reportes_prueba.json"
    if not archivo.exists():
        return 0
    lista = json.loads(archivo.read_text(encoding="utf-8"))
    for r in lista:
        reportes.crear(db, ReporteEntrada(**r), origen="seed")
    return len(lista)


def borrar_todo(db: Session, incluir_colonias: bool) -> None:
    for modelo in (Alerta, Reporte, RiesgoColonia):
        db.execute(delete(modelo))
    if incluir_colonias:
        db.execute(delete(Dispositivo))
        db.execute(delete(Colonia))
    db.commit()
    meteo.simular(None)


def seed(db: Session) -> dict:
    borrar_todo(db, incluir_colonias=True)
    colonias = cargar_colonias(db)
    recalcular_todas(db)
    reportes_cargados = cargar_reportes(db)
    return {"colonias": colonias, "reportes": reportes_cargados}


def simular_tormenta(db: Session, intensidad: float) -> dict:
    """Lluvia simulada; `intensidad` 1.0 satura todas las ventanas de lluvia."""
    meteo.simular(
        {
            "mm_1h": 20.0 * intensidad,
            "mm_3h": 40.0 * intensidad,
            "mm_24h": 80.0 * intensidad,
            "pronostico_3h": 40.0 * intensidad,
        }
    )
    recalcular_todas(db)
    return meteo.resumen()


def terminar_tormenta(db: Session) -> dict:
    meteo.simular(None)
    recalcular_todas(db)
    return meteo.resumen()
