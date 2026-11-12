import logging

from fastapi import BackgroundTasks
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app import eventos
from app.alertas.esquemas import AlertaManual, AlertaSalida
from app.alertas.modelos import Alerta, EntregaAlerta
from app.colonias.modelos import Colonia
from app.db import SessionLocal
from app.ia.redactor_alertas import redactar_alerta
from app.meteorologia import estado as meteo
from app.notificaciones import push
from app.utiles import ahora

log = logging.getLogger(__name__)

# Qué tipo de guía corresponde a cada motivo de riesgo
# TODO: si el motivo es "reportes", usar la categoría más reportada en la colonia
TIPO_POR_MOTIVO = {"lluvia": "inundacion", "reportes": "inundacion", "vulnerabilidad": "inundacion"}


def proponer(db: Session, colonia_id: int, nivel: str, motivo: str) -> Alerta | None:
    """Crea un borrador; si ya hay uno pendiente para la colonia, lo actualiza."""
    colonia = db.get(Colonia, colonia_id)
    if not colonia:
        return None
    tipo = TIPO_POR_MOTIVO.get(motivo, "inundacion")
    texto, redactada_por = redactar_alerta(colonia.nombre, nivel, motivo, tipo)

    pendiente = db.scalar(
        select(Alerta).where(Alerta.colonia_id == colonia_id, Alerta.estado == "propuesta")
    )
    alerta = pendiente or Alerta(colonia_id=colonia_id, creada_en=ahora())
    alerta.tipo, alerta.nivel, alerta.motivo = tipo, nivel, motivo
    alerta.texto, alerta.redactada_por = texto, redactada_por
    alerta.simulada = meteo.en_simulacion()
    if not pendiente:
        db.add(alerta)
    db.commit()
    db.refresh(alerta)
    eventos.publicar("alert.drafted", AlertaSalida.model_validate(alerta).model_dump(mode="json"))
    return alerta


def resumen_entregas(db: Session, alerta_id: int) -> dict:
    filas = dict(
        db.execute(
            select(EntregaAlerta.estado, func.count()).where(EntregaAlerta.alerta_id == alerta_id).group_by(EntregaAlerta.estado)
        ).all()
    )
    return {
        "total": sum(filas.values()),
        "enviados": filas.get("enviado", 0),
        "fallidos": filas.get("fallido", 0),
        "token_invalidos": filas.get("token_invalido", 0),
    }


def _enviar_y_publicar(alerta_id: int) -> None:
    """Envía el push con su propia sesión (corre fuera de la petición) y publica alert.approved."""
    with SessionLocal() as db:
        alerta = db.get(Alerta, alerta_id)
        if not alerta:
            return
        try:
            resumen = push.enviar_alerta(db, alerta)
        except Exception:
            log.exception("Error enviando la alerta %s", alerta_id)
            db.rollback()
            resumen = resumen_entregas(db, alerta_id)
        datos = AlertaSalida.model_validate(alerta).model_dump(mode="json")
        eventos.publicar(
            "alert.approved", {**datos, "dispositivos_notificados": resumen["enviados"], "entregas": resumen}
        )


def aprobar(db: Session, alerta: Alerta, tareas: BackgroundTasks | None = None) -> Alerta:
    """Aprueba y manda el push. Con `tareas` el envío ocurre tras responder; sin ellas, de forma síncrona."""
    alerta.estado = "aprobada"
    alerta.aprobada_en = ahora()
    db.commit()
    if tareas is not None:
        tareas.add_task(_enviar_y_publicar, alerta.id)
    else:
        _enviar_y_publicar(alerta.id)
    return alerta


def descartar(db: Session, alerta: Alerta) -> Alerta:
    alerta.estado = "descartada"
    db.commit()
    return alerta


def crear_manual(db: Session, datos: AlertaManual, tareas: BackgroundTasks | None = None) -> list[Alerta]:
    """Una alerta aprobada y enviada por cada colonia. Lanza LookupError si alguna no existe."""
    ids = list(dict.fromkeys(datos.colonia_ids))
    existentes = set(db.scalars(select(Colonia.id).where(Colonia.id.in_(ids))))
    faltan = [i for i in ids if i not in existentes]
    if faltan:
        raise LookupError(f"Colonias inexistentes: {faltan}")
    enviadas = []
    for colonia_id in ids:
        alerta = Alerta(
            colonia_id=colonia_id,
            tipo=datos.tipo,
            nivel=datos.nivel,
            motivo="manual",
            texto=datos.texto,
            redactada_por="manual",
            simulada=meteo.en_simulacion(),
            creada_en=ahora(),
        )
        db.add(alerta)
        db.commit()
        db.refresh(alerta)
        enviadas.append(aprobar(db, alerta, tareas))
    return enviadas
