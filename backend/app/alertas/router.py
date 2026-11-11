from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.alertas import servicio
from app.alertas.esquemas import AlertaConGuia, AlertaEdicion, AlertaSalida
from app.alertas.modelos import Alerta
from app.db import get_db
from app.guias.servicio import obtener_guia
from app.seguridad import requiere_clave
from app.utiles import ahora

router = APIRouter(prefix="/alerts", tags=["alertas"])

VIGENCIA_HORAS = 12


def _buscar(db: Session, alerta_id: int) -> Alerta:
    alerta = db.get(Alerta, alerta_id)
    if not alerta:
        raise HTTPException(404, "Alerta no encontrada")
    return alerta


@router.get("", response_model=list[AlertaSalida], summary="Bandeja de alertas del panel")
def listar(estado: str | None = "propuesta", db: Session = Depends(get_db)):
    consulta = select(Alerta).order_by(Alerta.creada_en.desc()).limit(200)
    if estado:
        consulta = consulta.where(Alerta.estado == estado)
    return db.scalars(consulta).all()


@router.get(
    "/active",
    response_model=list[AlertaConGuia],
    summary="Alertas aprobadas vigentes (respaldo si falla el push)",
)
def activas(colonia_id: int | None = None, db: Session = Depends(get_db)):
    consulta = select(Alerta).where(
        Alerta.estado == "aprobada", Alerta.aprobada_en > ahora() - timedelta(hours=VIGENCIA_HORAS)
    )
    if colonia_id:
        consulta = consulta.where(Alerta.colonia_id == colonia_id)
    return [
        AlertaConGuia(**AlertaSalida.model_validate(a).model_dump(), guia=obtener_guia(a.tipo))
        for a in db.scalars(consulta.order_by(Alerta.aprobada_en.desc()))
    ]


@router.patch(
    "/{alerta_id}",
    response_model=AlertaSalida,
    dependencies=[Depends(requiere_clave)],
    summary="Editar el texto de una alerta propuesta",
)
def editar(alerta_id: int, datos: AlertaEdicion, db: Session = Depends(get_db)):
    alerta = _buscar(db, alerta_id)
    if alerta.estado != "propuesta":
        raise HTTPException(409, "Solo se pueden editar alertas propuestas")
    alerta.texto = datos.texto
    db.commit()
    return alerta


@router.post(
    "/{alerta_id}/approve",
    response_model=AlertaSalida,
    dependencies=[Depends(requiere_clave)],
    summary="Aprobar y enviar (requiere clave)",
)
def aprobar(alerta_id: int, db: Session = Depends(get_db)):
    alerta = _buscar(db, alerta_id)
    if alerta.estado != "propuesta":
        raise HTTPException(409, f"La alerta ya está {alerta.estado}")
    return servicio.aprobar(db, alerta)


@router.post(
    "/{alerta_id}/discard",
    response_model=AlertaSalida,
    dependencies=[Depends(requiere_clave)],
    summary="Descartar una alerta propuesta (requiere clave)",
)
def descartar(alerta_id: int, db: Session = Depends(get_db)):
    alerta = _buscar(db, alerta_id)
    if alerta.estado != "propuesta":
        raise HTTPException(409, f"La alerta ya está {alerta.estado}")
    return servicio.descartar(db, alerta)
