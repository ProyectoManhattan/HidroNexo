from pydantic import BaseModel, Field


class DispositivoEntrada(BaseModel):
    token: str = Field(min_length=10, max_length=500)
    colonia_id: int
    plataforma: str = Field(default="android", pattern="^(android|ios|web)$")


class DispositivoSalida(BaseModel):
    id: int
    colonia_id: int | None
    plataforma: str

    model_config = {"from_attributes": True}
