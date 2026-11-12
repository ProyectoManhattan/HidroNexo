from fastapi import APIRouter

from app.meteorologia import estado

router = APIRouter(tags=["meteorología"])


@router.get("/weather", summary="Lluvia actual usada en el cálculo de riesgo")
def clima():
    """Lectura pública y no modificable para el mapa ciudadano."""
    return estado.resumen()
