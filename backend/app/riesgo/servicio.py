from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app import eventos
from app.colonias.modelos import Colonia
from app.config import settings
from app.meteorologia import estado as meteo
from app.reportes.modelos import Reporte
from app.reportes.servicio import filtro_activos
from app.riesgo import calculo
from app.riesgo.modelos import RiesgoColonia
from app.utiles import ahora


def _suma_severidades(db: Session, colonia_id: int) -> float:
    # TODO: ponderar por confirmaciones y por antigüedad del reporte
    filas = db.execute(
        select(Reporte.severidad, Reporte.categoria).where(Reporte.colonia_id == colonia_id, filtro_activos())
    ).all()
    if not filas:
        return 0.0
    lluvia = meteo.lluvia_de(colonia_id)
    return float(sum(calculo.severidad_efectiva(sev, cat, lluvia) for sev, cat in filas))


def recalcular(db: Session, colonia_id: int) -> RiesgoColonia | None:
    colonia = db.get(Colonia, colonia_id)
    if not colonia:
        return None
    actual = db.get(RiesgoColonia, colonia_id)
    nivel_anterior = actual.nivel if actual else None

    resultado = calculo.calcular(
        lluvia=calculo.componente_lluvia(meteo.lluvia_de(colonia_id)),
        reportes=calculo.componente_reportes(_suma_severidades(db, colonia_id)),
        vulnerabilidad=colonia.vulnerabilidad,
        nivel_anterior=nivel_anterior,
    )

    if actual is None:
        actual = RiesgoColonia(colonia_id=colonia_id)
        db.add(actual)
    actual.valor = resultado.valor
    actual.nivel = resultado.nivel
    actual.motivo = resultado.motivo
    actual.componentes = resultado.componentes
    actual.actualizado_en = ahora()

    cruza = calculo.sube_a_alerta(nivel_anterior, resultado.nivel)
    enfriada = actual.ultima_alerta_en is None or ahora() - actual.ultima_alerta_en > timedelta(
        minutes=settings.alerta_enfriamiento_min
    )
    if cruza and enfriada:
        actual.ultima_alerta_en = ahora()
    db.commit()

    datos = {
        "colonia_id": colonia_id,
        "nombre": colonia.nombre,
        "valor": resultado.valor,
        "nivel": resultado.nivel,
        "motivo": resultado.motivo,
        "componentes": resultado.componentes,
    }
    if nivel_anterior != resultado.nivel:
        eventos.publicar("zone.risk_updated", datos)
    if cruza and enfriada:
        eventos.publicar("zone.threshold_crossed", datos)
    return actual


def recalcular_todas(db: Session) -> None:
    for colonia_id in db.scalars(select(Colonia.id)).all():
        recalcular(db, colonia_id)
