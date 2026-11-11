from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.admin import servicio
from app.db import get_db
from app.meteorologia import estado as meteo
from app.seguridad import requiere_clave

router = APIRouter(prefix="/admin", tags=["admin (demo)"], dependencies=[Depends(requiere_clave)])


class Tormenta(BaseModel):
    intensidad: float = Field(default=1.0, ge=0.0, le=2.0)


@router.post("/seed", summary="Borra todo y carga colonias y reportes de data/")
def seed(db: Session = Depends(get_db)):
    return servicio.seed(db)


@router.post("/reset", summary="Borra reportes, alertas y riesgo; conserva colonias")
def reset(db: Session = Depends(get_db)):
    servicio.borrar_todo(db, incluir_colonias=False)
    servicio.terminar_tormenta(db)
    return {"ok": True}


@router.post("/simulate-storm", summary="SIMULACIÓN: activa lluvia intensa")
def simular(datos: Tormenta, db: Session = Depends(get_db)):
    return servicio.simular_tormenta(db, datos.intensidad)


@router.delete("/simulate-storm", summary="Termina la simulación")
def terminar(db: Session = Depends(get_db)):
    return servicio.terminar_tormenta(db)


@router.get("/weather", summary="Lluvia actual usada en el cálculo")
def clima():
    return meteo.resumen()
