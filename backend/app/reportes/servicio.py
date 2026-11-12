from datetime import timedelta

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app import eventos
from app.colonias.servicio import colonia_de_punto, punto
from app.config import settings
from app.meteorologia import estado as meteo
from app.reportes.esquemas import ReporteEntrada, ReporteSalida
from app.reportes.modelos import Reporte
from app.riesgo.calculo import severidad_efectiva
from app.utiles import ahora


def filtro_activos():
    return (Reporte.estado == "activo") & (Reporte.expira_en > ahora())


def buscar_por_cliente_id(db: Session, cliente_id: str) -> Reporte | None:
    return db.scalar(select(Reporte).where(Reporte.cliente_id == cliente_id))


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
    eventos.publicar("report.created", con_prioridad(reporte).model_dump(mode="json"))
    # TODO: límite de solicitudes por dispositivo y confirmaciones de otros dispositivos
    return reporte


def listar(
    db: Session,
    categoria: str | None = None,
    colonia_id: int | None = None,
    solo_activos: bool = True,
    bbox: tuple[float, float, float, float] | None = None,
) -> list[ReporteSalida]:
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
    return ordenar_por_prioridad(db.scalars(consulta.limit(1000)))


def _lluvia_de_reporte(reporte: Reporte) -> dict[str, float]:
    if reporte.colonia_id is not None:
        return meteo.lluvia_de(reporte.colonia_id)
    return meteo.lluvia_actual()


def con_prioridad(reporte: Reporte, lluvia: dict[str, float] | None = None) -> ReporteSalida:
    """ReporteSalida con `prioridad` = severidad ajustada por la lluvia local de su colonia."""
    item = ReporteSalida.model_validate(reporte)
    item.prioridad = round(
        severidad_efectiva(reporte.severidad, reporte.categoria, lluvia or _lluvia_de_reporte(reporte)), 4
    )
    return item


def ordenar_por_prioridad(reportes) -> list[ReporteSalida]:
    """Calcula `prioridad` con la lluvia de la colonia de cada reporte y ordena
    por prioridad desc, luego creado_en desc."""
    lluvias: dict[int | None, dict[str, float]] = {}
    salida = []
    for r in reportes:
        if r.colonia_id not in lluvias:
            lluvias[r.colonia_id] = _lluvia_de_reporte(r)
        salida.append(con_prioridad(r, lluvias[r.colonia_id]))
    salida.sort(key=lambda x: (x.prioridad, x.creado_en), reverse=True)
    return salida


def resolver(db: Session, reporte: Reporte) -> Reporte:
    reporte.estado = "resuelto"
    db.commit()
    eventos.publicar("report.updated", con_prioridad(reporte).model_dump(mode="json"))
    return reporte
