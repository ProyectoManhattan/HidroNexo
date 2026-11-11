import secrets

from fastapi import Header, HTTPException

from app.config import settings


def requiere_clave(x_clave: str = Header(default="", description="Clave única del panel")) -> None:
    """Dependencia para acciones que modifican: aprobar alertas, /admin/*, reporte manual."""
    if not secrets.compare_digest(x_clave.encode(), settings.clave_unica.encode()):
        raise HTTPException(status_code=401, detail="Clave inválida")
