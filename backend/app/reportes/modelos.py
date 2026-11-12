from datetime import datetime

from geoalchemy2 import Geometry
from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class Reporte(Base):
    __tablename__ = "reportes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    categoria: Mapped[str] = mapped_column(String(40), index=True)
    severidad: Mapped[int] = mapped_column(Integer)
    descripcion: Mapped[str | None] = mapped_column(Text)
    lat: Mapped[float] = mapped_column(Float)
    lon: Mapped[float] = mapped_column(Float)
    ubicacion = mapped_column(Geometry("POINT", srid=4326))
    colonia_id: Mapped[int | None] = mapped_column(ForeignKey("colonias.id"), index=True)
    foto_url: Mapped[str | None] = mapped_column(String(500))
    dispositivo_id: Mapped[str | None] = mapped_column(String(200))
    # Llave de idempotencia generada por la app: reintentar con la misma no duplica el reporte
    cliente_id: Mapped[str | None] = mapped_column(String(64), unique=True)
    # "app" o "panel" (reporte manual desde la web)
    origen: Mapped[str] = mapped_column(String(20), default="app")
    # "activo" o "resuelto"
    estado: Mapped[str] = mapped_column(String(20), default="activo", index=True)
    creado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    expira_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
