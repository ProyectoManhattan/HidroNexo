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
    # "plantilla" o "llm": honestidad sobre qué redactó la IA
    redactada_por: Mapped[str] = mapped_column(String(20), default="plantilla")
    simulada: Mapped[bool] = mapped_column(Boolean, default=False)
    creada_en: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    aprobada_en: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
