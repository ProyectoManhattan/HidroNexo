from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.colonias.modelos import Colonia
from app.db import get_db
from app.dispositivos.esquemas import DispositivoEntrada, DispositivoSalida
from app.dispositivos.modelos import Dispositivo
from app.utiles import ahora

router = APIRouter(prefix="/devices", tags=["dispositivos"])


@router.post("", response_model=DispositivoSalida, summary="Registrar o actualizar dispositivo y su colonia")
def registrar(datos: DispositivoEntrada, db: Session = Depends(get_db)):
    if not db.get(Colonia, datos.colonia_id):
        raise HTTPException(404, "Colonia no encontrada")
    dispositivo = db.scalar(select(Dispositivo).where(Dispositivo.token == datos.token))
    if dispositivo is None:
        dispositivo = Dispositivo(token=datos.token)
        db.add(dispositivo)
    dispositivo.colonia_id = datos.colonia_id
    dispositivo.plataforma = datos.plataforma
    dispositivo.actualizado_en = ahora()
    db.commit()
    db.refresh(dispositivo)
    return dispositivo
