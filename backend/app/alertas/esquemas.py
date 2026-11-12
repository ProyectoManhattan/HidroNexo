from datetime import datetime

from typing import Literal

from pydantic import BaseModel, Field, field_validator

from app.catalogos import CATEGORIAS


class AlertaSalida(BaseModel):
    id: int
    colonia_id: int
    tipo: str
    nivel: str
    motivo: str | None
    texto: str
    estado: str
    redactada_por: str
    simulada: bool
    creada_en: datetime
    aprobada_en: datetime | None

    model_config = {"from_attributes": True}


class AlertaEdicion(BaseModel):
    texto: str = Field(min_length=10, max_length=1000)


class AlertaConGuia(AlertaSalida):
    guia: dict | None = None


class AlertaManual(BaseModel):
    """Alerta redactada por Protección Civil: se envía de inmediato, sin pasar por la bandeja."""

    colonia_ids: list[int] = Field(min_length=1, max_length=500, examples=[[1, 2]])
    tipo: str = Field(default="inundacion", examples=["inundacion"])
    nivel: Literal["medio", "alto", "critico"] = "alto"
    texto: str = Field(min_length=10, max_length=1000)

    @field_validator("tipo")
    @classmethod
    def tipo_valido(cls, valor: str) -> str:
        if valor not in CATEGORIAS:
            raise ValueError(f"Tipo inválido. Opciones: {', '.join(CATEGORIAS)}")
        return valor
