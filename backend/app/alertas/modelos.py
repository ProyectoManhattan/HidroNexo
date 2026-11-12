from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class Alerta(Base):
    __tablename__ = "alertas"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    colonia_id: Mapped[int] = mapped_column(ForeignKey("colonias.id", ondelete="CASCADE"), index=True)
    # Tipo de problema; define qué guía se adjunta (data/guias/<tipo>.json)
    tipo: Mapped[str] = mapped_column(String(40), default="inundacion")
    nivel: Mapped[str] = mapped_column(String(20))
    motivo: Mapped[str | None] = mapped_column(String(40))
    texto: Mapped[str] = mapped_column(Text)
    # "propuesta" → "aprobada" | "descartada"
    estado: Mapped[str] = mapped_column(String(20), default="propuesta", index=True)
    # "plantilla", "llm" o "manual": honestidad sobre quién redactó el texto
    redactada_por: Mapped[str] = mapped_column(String(20), default="plantilla")
    simulada: Mapped[bool] = mapped_column(Boolean, default=False)
    creada_en: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    aprobada_en: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class EntregaAlerta(Base):
    """Auditoría: un intento de entrega push de una alerta a un dispositivo."""

    __tablename__ = "entregas_alerta"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    alerta_id: Mapped[int] = mapped_column(ForeignKey("alertas.id", ondelete="CASCADE"), index=True)
    # Nulo si el dispositivo se eliminó (p. ej. token inválido)
    dispositivo_id: Mapped[int | None] = mapped_column(ForeignKey("dispositivos.id", ondelete="SET NULL"))
    # "enviado" | "fallido" | "token_invalido"
    estado: Mapped[str] = mapped_column(String(20))
    error: Mapped[str | None] = mapped_column(Text)
    enviada_en: Mapped[datetime] = mapped_column(DateTime(timezone=True))
