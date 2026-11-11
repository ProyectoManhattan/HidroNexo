from fastapi import APIRouter, HTTPException

from app.guias.servicio import listar_guias, obtener_guia

router = APIRouter(prefix="/guides", tags=["guías"])


@router.get("", summary="Todas las guías (la app las guarda en caché)")
def listar():
    return listar_guias()


@router.get("/{tipo}", summary="Guía de un tipo de problema")
def obtener(tipo: str):
    guia = obtener_guia(tipo)
    if guia is None:
        raise HTTPException(404, "Guía no encontrada")
    return guia
