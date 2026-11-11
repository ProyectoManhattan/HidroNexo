from datetime import datetime

from pydantic import BaseModel, Field


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
