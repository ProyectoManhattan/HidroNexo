"""Selección de dispositivos destino de una alerta.

Punto de integración: el módulo de notificaciones solo debe llamar a
`dispositivos_destino`; cómo se decide la zona vive aquí.
"""
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.dispositivos.modelos import Dispositivo


def dispositivos_destino(db: Session, alerta) -> list[Dispositivo]:
    """Dispositivos que deben recibir la alerta (hoy: por colonia declarada)."""
    return list(db.scalars(select(Dispositivo).where(Dispositivo.colonia_id == alerta.colonia_id)))
