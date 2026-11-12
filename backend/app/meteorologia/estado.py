"""Última lectura de lluvia, en memoria (un solo worker).

Open-Meteo tiene poca resolución espacial: la lluvia es casi igual en toda la
ciudad. El contraste entre colonias viene de reportes y vulnerabilidad (plan, sección 8).
"""
from datetime import datetime

_lluvia: dict[str, float] = {}
_actualizado_en: datetime | None = None
_simulacion: dict[str, float] | None = None
_por_colonia: dict[int, dict[str, float]] = {}


def guardar(lluvia: dict[str, float], momento: datetime) -> None:
    global _lluvia, _actualizado_en
    _lluvia = lluvia
    _actualizado_en = momento


def guardar_por_colonia(lecturas: dict[int, dict[str, float]], momento: datetime) -> None:
    """Guarda la lluvia de cada colonia; el valor global (fallback) es el peor de todas."""
    global _por_colonia
    _por_colonia = {cid: dict(l) for cid, l in lecturas.items()}
    if lecturas:
        claves = {k for l in lecturas.values() for k in l}
        guardar({k: max(l[k] for l in lecturas.values() if k in l) for k in claves}, momento)
    else:
        guardar(_lluvia, momento)


def simular(lluvia: dict[str, float] | None) -> None:
    """Activa (o quita con None) la tormenta simulada; tiene prioridad sobre Open-Meteo."""
    global _simulacion
    _simulacion = lluvia


def en_simulacion() -> bool:
    return _simulacion is not None


def lluvia_actual() -> dict[str, float]:
    return dict(_simulacion) if _simulacion is not None else dict(_lluvia)


def lluvia_de(colonia_id: int) -> dict[str, float]:
    """Simulación activa > lectura de la colonia > lectura global (peor valor)."""
    if _simulacion is not None:
        return dict(_simulacion)
    return dict(_por_colonia.get(colonia_id) or _lluvia)


def resumen() -> dict:
    return {
        "lluvia": lluvia_actual(),
        "simulacion": en_simulacion(),
        "actualizado_en": _actualizado_en.isoformat() if _actualizado_en else None,
        "colonias_con_lectura": len(_por_colonia),
    }
