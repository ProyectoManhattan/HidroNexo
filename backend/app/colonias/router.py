from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.colonias import servicio
from app.colonias.esquemas import ColoniaSalida
from app.colonias.modelos import Colonia
from app.db import get_db

router = APIRouter(prefix="/zones", tags=["colonias"])


@router.get("", response_model=list[ColoniaSalida], summary="Lista de colonias (para elegir en la app)")
def listar(db: Session = Depends(get_db)):
    return db.scalars(select(Colonia).order_by(Colonia.nombre)).all()


@router.get("/risk", summary="Colonias con su riesgo (GeoJSON)")
def riesgo(db: Session = Depends(get_db)):
    return servicio.geojson_riesgo(db)
