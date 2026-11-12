from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from app import almacenamiento
from app.catalogos import CATEGORIAS


class ReporteEntrada(BaseModel):
    categoria: str = Field(examples=["inundacion"])
    severidad: int = Field(ge=1, le=3)
    lat: float = Field(ge=-90, le=90)
    lon: float = Field(ge=-180, le=180)
    descripcion: str | None = Field(default=None, max_length=500)
    foto_url: str | None = None
    dispositivo_id: str | None = None

    @field_validator("foto_url")
    @classmethod
    def foto_url_propia(cls, valor: str | None) -> str | None:
        if valor is not None and not almacenamiento.url_foto_valida(valor):
            raise ValueError("foto_url debe ser una URL devuelta por POST /reports/photo")
        return valor

    @field_validator("categoria")
    @classmethod
    def categoria_valida(cls, valor: str) -> str:
        if valor not in CATEGORIAS:
            raise ValueError(f"Categoría inválida. Opciones: {', '.join(CATEGORIAS)}")
        return valor


class ReporteSalida(BaseModel):
    id: int
    categoria: str
    severidad: int
    lat: float
    lon: float
    descripcion: str | None
    foto_url: str | None
    colonia_id: int | None
    origen: str
    estado: str
    creado_en: datetime
    expira_en: datetime
    # Aditivo: severidad efectiva (ajustada por lluvia local). La llenan GET /reports y los eventos;
    # puede ser null en otras respuestas (p. ej. POST /reports).
    prioridad: float | None = None

    model_config = {"from_attributes": True}
