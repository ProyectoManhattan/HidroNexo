from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class Dispositivo(Base):
    __tablename__ = "dispositivos"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    # Token de notificaciones push (FCM en Flutter)
    token: Mapped[str] = mapped_column(String(500), unique=True)
    colonia_id: Mapped[int | None] = mapped_column(ForeignKey("colonias.id", ondelete="SET NULL"), index=True)
    plataforma: Mapped[str] = mapped_column(String(20), default="android")
    actualizado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True))
