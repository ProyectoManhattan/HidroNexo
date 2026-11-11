"""Escucha el WebSocket del backend (una sola conexión para todo el servidor web).

Cada evento incrementa `version`; cada navegador abierto revisa la versión con
un temporizador y, si cambió, vuelve a pedir los datos y muestra avisos.
"""
import asyncio
import json
import logging

import websockets

from config import WS_URL

log = logging.getLogger(__name__)

version = 0
conectado = False
ultimo_clima: dict | None = None
# Lista de (número, evento); se conservan los últimos 200
eventos: list[tuple[int, dict]] = []


def _registrar(evento: dict) -> None:
    global version, ultimo_clima
    version += 1
    eventos.append((version, evento))
    del eventos[:-200]
    if evento.get("tipo") == "weather.updated":
        ultimo_clima = evento.get("datos")


def eventos_desde(numero: int) -> list[dict]:
    return [e for n, e in eventos if n > numero]


async def escuchar() -> None:
    global conectado, version
    while True:
        try:
            async with websockets.connect(WS_URL, ping_interval=20) as ws:
                conectado = True
                version += 1  # Fuerza a recargar datos al reconectar
                async for mensaje in ws:
                    _registrar(json.loads(mensaje))
        except (OSError, websockets.WebSocketException):
            pass
        except Exception:
            log.exception("Error en el WebSocket del backend")
        if conectado:
            conectado = False
            version += 1
        await asyncio.sleep(3)
