from copy import deepcopy
from datetime import timedelta
from threading import Lock

from app.utiles import ahora

_lock = Lock()
_datos = {"alertas": [], "actualizado_en": None, "ultima_consulta_en": None, "error": None}


def guardar(alertas: list[dict]) -> None:
    momento = ahora()
    with _lock:
        _datos.update(alertas=alertas, actualizado_en=momento, ultima_consulta_en=momento, error=None)


def guardar_error(mensaje: str) -> None:
    with _lock:
        _datos.update(ultima_consulta_en=ahora(), error=mensaje)


def resumen() -> dict:
    with _lock:
        datos = deepcopy(_datos)
    actualizado = datos["actualizado_en"]
    datos["desactualizado"] = actualizado is None or ahora() - actualizado > timedelta(minutes=30)
    datos["fuente"] = "Coordinación Nacional de Protección Civil (México Preparado)"
    datos["fuente_url"] = "https://preparados.gob.mx/apps/alertamientosSSPC/"
    datos["estado"] = "error" if datos["error"] and actualizado is None else "ok"
    for clave in ("actualizado_en", "ultima_consulta_en"):
        if datos[clave] is not None:
            datos[clave] = datos[clave].isoformat()
    return datos
