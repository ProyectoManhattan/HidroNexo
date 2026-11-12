from pydantic import BaseModel, Field, model_validator


class DispositivoEntrada(BaseModel):
    token: str = Field(min_length=10, max_length=500)
    colonia_id: int | None = None
    lat: float | None = Field(default=None, ge=-90, le=90)
    lon: float | None = Field(default=None, ge=-180, le=180)
    plataforma: str = Field(default="android", pattern="^(android|ios|web)$")

    @model_validator(mode="after")
    def _zona_requerida(self):
        if (self.lat is None) != (self.lon is None):
            raise ValueError("lat y lon deben venir juntas")
        if self.colonia_id is None and self.lat is None:
            raise ValueError("Se requiere colonia_id o lat y lon")
        return self


class DispositivoSalida(BaseModel):
    id: int
    colonia_id: int | None
    plataforma: str

    model_config = {"from_attributes": True}
