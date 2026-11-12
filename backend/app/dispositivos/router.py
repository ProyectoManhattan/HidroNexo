from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.colonias.modelos import Colonia
from app.colonias.servicio import colonia_de_punto, punto
from app.db import get_db
from app.dispositivos.esquemas import DispositivoEntrada, DispositivoSalida
from app.dispositivos.modelos import Dispositivo
from app.utiles import ahora

router = APIRouter(prefix="/devices", tags=["dispositivos"])


@router.post("", response_model=DispositivoSalida, summary="Registrar o actualizar dispositivo, su colonia y ubicación")
def registrar(datos: DispositivoEntrada, db: Session = Depends(get_db)):
    colonia_id = datos.colonia_id
    if colonia_id is not None and not db.get(Colonia, colonia_id):
        raise HTTPException(404, "Colonia no encontrada")
    con_ubicacion = datos.lat is not None and datos.lon is not None
    if colonia_id is None:
        colonia_id = colonia_de_punto(db, datos.lat, datos.lon)
        if colonia_id is None:
            raise HTTPException(404, "La ubicación no está dentro de ninguna colonia cubierta")
    dispositivo = db.scalar(select(Dispositivo).where(Dispositivo.token == datos.token))
    if dispositivo is None:
        dispositivo = Dispositivo(token=datos.token)
        db.add(dispositivo)
    dispositivo.colonia_id = colonia_id
    dispositivo.plataforma = datos.plataforma
    dispositivo.actualizado_en = ahora()
    if con_ubicacion:
        dispositivo.ubicacion = punto(datos.lat, datos.lon)
        dispositivo.ubicacion_actualizada_en = ahora()
    db.commit()
    db.refresh(dispositivo)
    return dispositivo
