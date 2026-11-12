"""Selección de dispositivos destino de una alerta.

Punto de integración: el módulo de notificaciones solo debe llamar a
`dispositivos_destino`; cómo se decide la zona vive aquí.
"""
import json
from datetime import timedelta

from sqlalchemy import and_, func, or_, select
from sqlalchemy.orm import Session

from app.colonias.modelos import Colonia
from app.colonias.servicio import punto
from app.dispositivos.modelos import Dispositivo
from app.utiles import ahora

# Una ubicación más vieja que esto se ignora y se usa la colonia declarada
VIGENCIA_UBICACION = timedelta(hours=24)


def _ubicacion_vigente():
    return and_(
        Dispositivo.ubicacion.is_not(None),
        Dispositivo.ubicacion_actualizada_en >= ahora() - VIGENCIA_UBICACION,
    )


def _en_geometria(geom):
    return func.ST_Contains(geom, Dispositivo.ubicacion)


def dispositivos_destino(db: Session, alerta) -> list[Dispositivo]:
    """Dispositivos que deben recibir la alerta.

    Con ubicación vigente manda la ubicación (debe caer en la colonia de la alerta);
    sin ella (ausente o vencida) se usa la colonia declarada.
    """
    geom = select(Colonia.geom).where(Colonia.id == alerta.colonia_id).scalar_subquery()
    condicion = or_(
        and_(_ubicacion_vigente(), _en_geometria(geom)),
        and_(~_ubicacion_vigente(), Dispositivo.colonia_id == alerta.colonia_id),
    )
    return list(db.scalars(select(Dispositivo).where(condicion)))


def dispositivos_en_geometria(db: Session, geojson: dict | str) -> list[Dispositivo]:
    """Dispositivos con ubicación vigente dentro de un polígono (GeoJSON dict/str o WKT)."""
    if isinstance(geojson, dict):
        geojson = json.dumps(geojson)
    if geojson.lstrip().startswith("{"):
        geom = func.ST_SetSRID(func.ST_GeomFromGeoJSON(geojson), 4326)
    else:
        geom = func.ST_GeomFromText(geojson, 4326)
    return list(db.scalars(select(Dispositivo).where(_ubicacion_vigente(), _en_geometria(geom))))


def dispositivos_en_radio(db: Session, lat: float, lon: float, metros: float) -> list[Dispositivo]:
    """Dispositivos con ubicación vigente a `metros` o menos del punto."""
    cond = func.ST_DWithin(
        func.cast(Dispositivo.ubicacion, _geography()), func.cast(punto(lat, lon), _geography()), metros
    )
    return list(db.scalars(select(Dispositivo).where(_ubicacion_vigente(), cond)))


def _geography():
    from geoalchemy2 import Geography

    return Geography()
