"""Paneles conectados por WebSocket.

Los eventos se publican desde hilos (peticiones síncronas y la tarea de Open-Meteo),
así que el envío se agenda en el loop principal con run_coroutine_threadsafe.
"""
import asyncio
import logging

from fastapi import WebSocket

log = logging.getLogger(__name__)

_conexiones: set[WebSocket] = set()
_loop: asyncio.AbstractEventLoop | None = None


def fijar_loop(loop: asyncio.AbstractEventLoop) -> None:
    global _loop
    _loop = loop


def agregar(ws: WebSocket) -> None:
    _conexiones.add(ws)


def quitar(ws: WebSocket) -> None:
    _conexiones.discard(ws)


async def _difundir(mensaje: dict) -> None:
    for ws in list(_conexiones):
        try:
            await ws.send_json(mensaje)
        except Exception:
            quitar(ws)


def difundir(tipo: str, datos) -> None:
    """Envía {"tipo": ..., "datos": ...} a todos los paneles. Seguro desde cualquier hilo."""
    if _loop is None or not _conexiones:
        return
    asyncio.run_coroutine_threadsafe(_difundir({"tipo": tipo, "datos": datos}), _loop)
