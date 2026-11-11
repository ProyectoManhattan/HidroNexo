from pydantic import BaseModel


class ColoniaSalida(BaseModel):
    id: int
    nombre: str
    municipio: str
    vulnerabilidad: float
    vulnerabilidad_fuente: str

    model_config = {"from_attributes": True}
