import json

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.colonias.modelos import Colonia
from app.meteorologia import estado as meteo
from app.riesgo.calculo import resumen_pronostico
from app.riesgo.modelos import RiesgoColonia
from app.territorio.perfiles import perfil_para, susceptibilidad


def punto(lat: float, lon: float):
    return func.ST_SetSRID(func.ST_MakePoint(lon, lat), 4326)


def colonia_de_punto(db: Session, lat: float, lon: float) -> int | None:
    """Devuelve el id de la colonia que contiene el punto, o None."""
    return db.scalar(
        select(Colonia.id).where(func.ST_Contains(Colonia.geom, punto(lat, lon))).limit(1)
    )
    # TODO: si cae fuera de todas (borde, mar), usar la colonia más cercana a < 300 m


def geojson_riesgo(db: Session) -> dict:
    """FeatureCollection con cada colonia y su riesgo actual."""
    filas = db.execute(
        select(Colonia, func.ST_AsGeoJSON(Colonia.geom), RiesgoColonia).outerjoin(
            RiesgoColonia, RiesgoColonia.colonia_id == Colonia.id
        )
    ).all()
    features = []
    for colonia, geometria, riesgo in filas:
        perfil = perfil_para(colonia.nombre)
        features.append(
            {
                "type": "Feature",
                "id": colonia.id,
                "geometry": json.loads(geometria) if geometria else None,
                "properties": {
                    "id": colonia.id,
                    "nombre": colonia.nombre,
                    "municipio": colonia.municipio,
                    "vulnerabilidad": susceptibilidad(perfil, colonia.vulnerabilidad),
                    "vulnerabilidad_fuente": "perfil_territorial" if perfil else colonia.vulnerabilidad_fuente,
                    "riesgo": riesgo.valor if riesgo else 0.0,
                    "nivel": riesgo.nivel if riesgo else "bajo",
                    "motivo": riesgo.motivo if riesgo else None,
                    "componentes": riesgo.componentes if riesgo else {},
                    "actualizado_en": riesgo.actualizado_en.isoformat() if riesgo else None,
                    "pronostico": resumen_pronostico(meteo.lluvia_de(colonia.id)),
                    "perfil_territorial": perfil,
                },
            }
        )
    return {"type": "FeatureCollection", "features": features}
