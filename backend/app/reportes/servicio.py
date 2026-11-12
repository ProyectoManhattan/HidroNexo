from datetime import timedelta

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app import eventos
from app.colonias.servicio import colonia_de_punto, punto
from app.config import settings
from app.reportes.esquemas import ReporteEntrada, ReporteSalida
from app.reportes.modelos import Reporte
from app.utiles import ahora


def filtro_activos():
    return (Reporte.estado == "activo") & (Reporte.expira_en > ahora())


def crear(db: Session, datos: ReporteEntrada, origen: str = "app", horas_vigencia: int | None = None) -> Reporte:
    momento = ahora()
    reporte = Reporte(
        **datos.model_dump(),
        ubicacion=punto(datos.lat, datos.lon),
        colonia_id=colonia_de_punto(db, datos.lat, datos.lon),
        origen=origen,
        creado_en=momento,
        expira_en=momento + timedelta(hours=horas_vigencia or settings.reporte_horas_expiracion),
    )
    db.add(reporte)
    db.commit()
    db.refresh(reporte)
    eventos.publicar("report.created", ReporteSalida.model_validate(reporte).model_dump(mode="json"))
    # TODO: límite de solicitudes por dispositivo y confirmaciones de otros dispositivos
    return reporte


def listar(
    db: Session,
    categoria: str | None = None,
    colonia_id: int | None = None,
    solo_activos: bool = True,
    bbox: tuple[float, float, float, float] | None = None,
) -> list[Reporte]:
    consulta = select(Reporte).order_by(Reporte.creado_en.desc())
    if solo_activos:
        consulta = consulta.where(filtro_activos())
    if categoria:
        consulta = consulta.where(Reporte.categoria == categoria)
    if colonia_id:
        consulta = consulta.where(Reporte.colonia_id == colonia_id)
    if bbox:
        consulta = consulta.where(
            func.ST_Intersects(Reporte.ubicacion, func.ST_MakeEnvelope(*bbox, 4326))
        )
    return list(db.scalars(consulta.limit(1000)))


def resolver(db: Session, reporte: Reporte) -> Reporte:
    reporte.estado = "resuelto"
    db.commit()
    eventos.publicar("report.updated", ReporteSalida.model_validate(reporte).model_dump(mode="json"))
    return reporte
