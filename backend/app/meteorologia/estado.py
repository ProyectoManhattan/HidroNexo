"""Última lectura de lluvia, en memoria (un solo worker).

Open-Meteo tiene poca resolución espacial: la lluvia es casi igual en toda la
ciudad. El contraste entre colonias viene de reportes y vulnerabilidad (plan, sección 8).
"""
from datetime import datetime

_lluvia: dict[str, float] = {}
_actualizado_en: datetime | None = None
_simulacion: dict[str, float] | None = None


def guardar(lluvia: dict[str, float], momento: datetime) -> None:
    global _lluvia, _actualizado_en
    _lluvia = lluvia
    _actualizado_en = momento


def simular(lluvia: dict[str, float] | None) -> None:
    """Activa (o quita con None) la tormenta simulada; tiene prioridad sobre Open-Meteo."""
    global _simulacion
    _simulacion = lluvia


def en_simulacion() -> bool:
    return _simulacion is not None


def lluvia_actual() -> dict[str, float]:
    return dict(_simulacion) if _simulacion is not None else dict(_lluvia)


def resumen() -> dict:
    return {
        "lluvia": lluvia_actual(),
        "simulacion": en_simulacion(),
        "actualizado_en": _actualizado_en.isoformat() if _actualizado_en else None,
    }
