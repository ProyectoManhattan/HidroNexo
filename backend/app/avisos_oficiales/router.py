from fastapi import APIRouter, Depends

from app.avisos_oficiales import estado, ingesta
from app.seguridad import requiere_clave

router = APIRouter(prefix="/official-alerts", tags=["alertamientos oficiales"])


@router.get("", summary="Alertamientos hidrometeorológicos oficiales vigentes para Veracruz")
def listar():
    return estado.resumen()


@router.post("/refresh", dependencies=[Depends(requiere_clave)], summary="Actualizar desde México Preparado")
def actualizar():
    ingesta.ejecutar()
    return estado.resumen()
