"""Bus de eventos en memoria.

Solo funciona con UN proceso/worker (plan, sección 3). Eventos:
    report.created, report.updated, weather.updated, zone.risk_updated,
    zone.threshold_crossed, alert.drafted, alert.approved, official_alerts.updated

Los suscriptores se registran en app/suscripciones.py.
Publicar siempre DESPUÉS de hacer commit en la base de datos.
"""
import logging
from collections import defaultdict
from typing import Any, Callable

log = logging.getLogger(__name__)

_suscriptores: dict[str, list[Callable[[Any], None]]] = defaultdict(list)


def suscribir(evento: str, funcion: Callable[[Any], None]) -> None:
    _suscriptores[evento].append(funcion)


def publicar(evento: str, datos: Any = None) -> None:
    for funcion in list(_suscriptores[evento]):
        try:
            funcion(datos)
        except Exception:
            # Un suscriptor que falla no debe tumbar la petición que publicó
            log.exception("Error en suscriptor de %s", evento)


def limpiar() -> None:
    """Útil en pruebas."""
    _suscriptores.clear()
