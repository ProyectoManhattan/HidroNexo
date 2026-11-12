from datetime import datetime

from sqlalchemy import JSON, Boolean, DateTime, Float, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class LecturaLluvia(Base):
    """Lluvia observada y pronosticada en una celda de ~0.05° (una fila por celda y consulta)."""

    __tablename__ = "historial_lluvia"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    momento: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    celda_lat: Mapped[float] = mapped_column(Float)
    celda_lon: Mapped[float] = mapped_column(Float)
    mm_1h: Mapped[float | None] = mapped_column(Float)
    mm_3h: Mapped[float | None] = mapped_column(Float)
    mm_24h: Mapped[float | None] = mapped_column(Float)
    pronostico_3h: Mapped[float | None] = mapped_column(Float)
    prob_3h: Mapped[float | None] = mapped_column(Float)
    prob_6h: Mapped[float | None] = mapped_column(Float)


class CambioNivel(Base):
    """Una fila cada vez que una zona cambia de nivel de riesgo (o su primer cálculo)."""

    __tablename__ = "historial_riesgo"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    momento: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    zona: Mapped[str] = mapped_column(String(200), index=True)
    municipio: Mapped[str | None] = mapped_column(String(100))
    # None en el primer cálculo de la zona
    nivel_anterior: Mapped[str | None] = mapped_column(String(20))
    nivel: Mapped[str] = mapped_column(String(20))
    valor: Mapped[float] = mapped_column(Float)
    motivo: Mapped[str | None] = mapped_column(String(40))
    # lluvia, reportes y vulnerabilidad normalizados (0–1) en ese momento
    componentes: Mapped[dict] = mapped_column(JSON, default=dict)
    # True si se calculó con una tormenta simulada: excluir al calibrar con datos reales
    simulacion: Mapped[bool] = mapped_column(Boolean, default=False)
