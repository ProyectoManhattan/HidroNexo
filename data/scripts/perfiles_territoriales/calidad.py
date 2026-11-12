"""Registro de problemas de calidad. Nada se elimina: se marca y se documenta."""
from collections import defaultdict


class Bitacora:
    def __init__(self):
        self.problemas: list[dict] = []
        self.por_poligono: dict[str, list[str]] = defaultdict(list)

    def registrar(self, categoria: str, detalle: str, poligono: str | None = None, **extra):
        self.problemas.append({"categoria": categoria, "detalle": detalle, "poligono": poligono, **extra})
        if poligono:
            self.por_poligono[poligono].append(f"{categoria}: {detalle}")

    def resumen(self) -> dict[str, int]:
        conteo: dict[str, int] = defaultdict(int)
        for p in self.problemas:
            conteo[p["categoria"]] += 1
        return dict(conteo)
