from fastapi import APIRouter, Depends, File, HTTPException, Query, Request, Response, UploadFile
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app import almacenamiento
from app.catalogos import CATEGORIAS, SEVERIDADES
from app.db import get_db
from app.reportes import servicio
from app.reportes.esquemas import ReporteEntrada, ReporteSalida
from app.reportes.modelos import Reporte
from app.seguridad import requiere_clave

router = APIRouter(prefix="/reports", tags=["reportes"])


@router.get("/categories", summary="Categorías y severidades válidas")
def categorias():
    return {"categorias": CATEGORIAS, "severidades": SEVERIDADES}


@router.post("", response_model=ReporteSalida, status_code=201, summary="Crear reporte desde la app (idempotente con cliente_id)")
def crear(datos: ReporteEntrada, response: Response, db: Session = Depends(get_db)):
    """Con `cliente_id`, un reintento devuelve el mismo reporte con 200 en vez de crear otro."""
    if datos.cliente_id:
        existente = servicio.buscar_por_cliente_id(db, datos.cliente_id)
        if existente:
            response.status_code = 200
            return existente
    try:
        return servicio.crear(db, datos, origen="app")
    except IntegrityError:
        # Dos reintentos simultáneos con el mismo cliente_id: gana uno, el otro recibe el existente
        db.rollback()
        existente = datos.cliente_id and servicio.buscar_por_cliente_id(db, datos.cliente_id)
        if not existente:
            raise
        response.status_code = 200
        return existente


@router.post("/photo", status_code=201, summary="Subir foto de un reporte (público)")
async def subir_foto(request: Request, foto: UploadFile = File(...)):
    """Devuelve `foto_url`; el cliente la envía después en `POST /reports`."""
    try:
        url = await almacenamiento.guardar_foto(foto, str(request.base_url))
    except almacenamiento.TipoNoPermitido:
        raise HTTPException(415, "Tipo de archivo no permitido. Solo image/jpeg, image/png o image/webp")
    except almacenamiento.ArchivoDemasiadoGrande:
        raise HTTPException(413, "La foto supera el máximo de 5 MB")
    except almacenamiento.AlmacenamientoError:
        raise HTTPException(503, "No se pudo guardar la foto; intenta más tarde")
    return {"foto_url": url}


@router.post(
    "/manual",
    response_model=ReporteSalida,
    status_code=201,
    dependencies=[Depends(requiere_clave)],
    summary="Reporte manual desde el panel (requiere clave)",
)
def crear_manual(datos: ReporteEntrada, db: Session = Depends(get_db)):
    return servicio.crear(db, datos, origen="panel")


@router.get("", response_model=list[ReporteSalida], summary="Listar reportes con filtros")
def listar(
    categoria: str | None = None,
    colonia_id: int | None = None,
    activos: bool = True,
    bbox: str | None = Query(default=None, description="min_lon,min_lat,max_lon,max_lat"),
    db: Session = Depends(get_db),
):
    caja = None
    if bbox:
        try:
            caja = tuple(float(x) for x in bbox.split(","))
            assert len(caja) == 4
        except (ValueError, AssertionError):
            raise HTTPException(422, "bbox debe ser min_lon,min_lat,max_lon,max_lat")
    return servicio.listar(db, categoria, colonia_id, activos, caja)


@router.post(
    "/{reporte_id}/resolve",
    response_model=ReporteSalida,
    dependencies=[Depends(requiere_clave)],
    summary="Marcar reporte como resuelto (requiere clave)",
)
def resolver(reporte_id: int, db: Session = Depends(get_db)):
    reporte = db.get(Reporte, reporte_id)
    if not reporte:
        raise HTTPException(404, "Reporte no encontrado")
    return servicio.resolver(db, reporte)
