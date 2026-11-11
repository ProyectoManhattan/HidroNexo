"""Estado de un navegador abierto (cada pestaña tiene el suyo)."""
from dataclasses import dataclass, field

from componentes.estilos import categoria


@dataclass
class Estado:
    clave: str | None = None
    filtro: str = "todo"  # "todo", "lluvia" o "agua"
    riesgo: dict = field(default_factory=lambda: {"features": []})
    reportes: list = field(default_factory=list)
    alertas: list = field(default_factory=list)
    clima: dict | None = None
    error: str | None = None
    version_vista: int = -1
    evento_visto: int = 0
    eligiendo_punto: bool = False

    @property
    def operador(self) -> bool:
        return self.clave is not None

    @property
    def colonias(self) -> list[dict]:
        return [f["properties"] for f in self.riesgo.get("features", [])]

    def nombre_colonia(self, colonia_id: int | None) -> str:
        for c in self.colonias:
            if c["id"] == colonia_id:
                return c["nombre"]
        return "fuera de colonias registradas"

    def reportes_visibles(self) -> list[dict]:
        if self.filtro == "todo":
            return self.reportes
        return [r for r in self.reportes if categoria(r["categoria"])["grupo"] == self.filtro]

    def en_alto_o_critico(self) -> int:
        return sum(1 for c in self.colonias if c["nivel"] in ("alto", "critico"))
