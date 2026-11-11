import logging

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.dispositivos.modelos import Dispositivo

log = logging.getLogger(__name__)


def enviar(token: str, titulo: str, cuerpo: str, datos: dict) -> bool:
    """TODO (Persona A con Persona C): enviar con Firebase Cloud Messaging (FCM).

    Probar un envío real ANTES de la hora 15 (plan, fase 3).
    Mientras tanto solo se registra en el log; la app tiene el respaldo
    GET /alerts/active?colonia_id=...
    """
    log.info("PUSH (simulado) a %s…: %s", token[:12], titulo)
    return True


def enviar_a_colonia(db: Session, alerta) -> int:
    tokens = db.scalars(select(Dispositivo.token).where(Dispositivo.colonia_id == alerta.colonia_id)).all()
    titulo = f"Alerta {alerta.nivel}" + (" (SIMULACIÓN)" if alerta.simulada else "")
    datos = {"alerta_id": str(alerta.id), "tipo": alerta.tipo}
    return sum(enviar(t, titulo, alerta.texto, datos) for t in tokens)
