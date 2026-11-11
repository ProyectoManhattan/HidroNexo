from datetime import datetime

from sqlalchemy import JSON, DateTime, Float, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class RiesgoColonia(Base):
    """Riesgo actual de cada colonia (una fila por colonia)."""

    __tablename__ = "riesgo_colonias"

    colonia_id: Mapped[int] = mapped_column(ForeignKey("colonias.id", ondelete="CASCADE"), primary_key=True)
    valor: Mapped[float] = mapped_column(Float, default=0.0)
    nivel: Mapped[str] = mapped_column(String(20), default="bajo")
    motivo: Mapped[str | None] = mapped_column(String(40))
    componentes: Mapped[dict] = mapped_column(JSON, default=dict)
    actualizado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    # Para el enfriamiento: no repetir alertas de la misma colonia
    ultima_alerta_en: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
