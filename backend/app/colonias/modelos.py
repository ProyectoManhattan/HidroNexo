from geoalchemy2 import Geometry
from sqlalchemy import Float, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class Colonia(Base):
    __tablename__ = "colonias"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    nombre: Mapped[str] = mapped_column(String(200), index=True)
    municipio: Mapped[str] = mapped_column(String(100), default="Veracruz")
    geom = mapped_column(Geometry("MULTIPOLYGON", srid=4326))
    # Vulnerabilidad base entre 0 y 1
    vulnerabilidad: Mapped[float] = mapped_column(Float, default=0.0)
    # "real" (con fuente en data/FUENTES.md) o "ejemplo"
    vulnerabilidad_fuente: Mapped[str] = mapped_column(String(20), default="ejemplo")
