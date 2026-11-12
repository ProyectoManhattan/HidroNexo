"""Almacenamiento de fotos de reportes.

Producción: Supabase Storage (API REST con httpx, bucket público).
Desarrollo/tests sin credenciales: directorio local servido en /media (NO usar en
Railway: el disco es efímero).
"""
import logging
import re
import uuid
from contextlib import asynccontextmanager

import httpx
from fastapi import UploadFile

from app.config import settings

log = logging.getLogger(__name__)

MAX_BYTES = 5 * 1024 * 1024
_CHUNK = 64 * 1024
_EXTENSIONES = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}
_NOMBRE = r"[0-9a-f]{32}\.(?:jpg|png|webp)"


class AlmacenamientoError(Exception):
    """Falla del almacenamiento (se traduce a 503)."""


class TipoNoPermitido(Exception):
    pass


class ArchivoDemasiadoGrande(Exception):
    pass


def detectar_tipo(datos: bytes) -> str | None:
    """Tipo MIME por magic bytes; ignora lo que declare el cliente."""
    if datos.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if datos.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if datos[:4] == b"RIFF" and datos[8:12] == b"WEBP":
        return "image/webp"
    return None


def usa_supabase() -> bool:
    return bool(settings.supabase_url and settings.supabase_service_key)


def _prefijo_publico() -> str:
    return f"{settings.supabase_url.rstrip('/')}/storage/v1/object/public/{settings.supabase_bucket}/"


def url_foto_valida(url: str) -> bool:
    """Solo URLs generadas por nosotros: prefijo público de Supabase o /media/<id>.<ext> en modo local."""
    if usa_supabase():
        prefijo = _prefijo_publico()
        return url.startswith(prefijo) and re.fullmatch(_NOMBRE, url[len(prefijo):]) is not None
    return re.fullmatch(rf"(?:https?://[^/?#\s]+)?/media/{_NOMBRE}", url) is not None


@asynccontextmanager
async def _cliente_http():
    # Punto de sustitución en tests.
    async with httpx.AsyncClient(timeout=15.0) as cliente:
        yield cliente


async def _subir_supabase(contenido: bytes, mime: str, nombre: str) -> str:
    url = f"{settings.supabase_url.rstrip('/')}/storage/v1/object/{settings.supabase_bucket}/{nombre}"
    cabeceras = {
        "Authorization": f"Bearer {settings.supabase_service_key}",
        "apikey": settings.supabase_service_key,
        "Content-Type": mime,
        "x-upsert": "false",
    }
    try:
        async with _cliente_http() as cliente:
            respuesta = await cliente.post(url, content=contenido, headers=cabeceras)
    except httpx.HTTPError as error:
        # No registrar la excepción completa: nunca exponer cabeceras/credenciales.
        log.error("Supabase Storage inalcanzable: %s", error.__class__.__name__)
        raise AlmacenamientoError from None
    if respuesta.status_code >= 300:
        log.error("Supabase Storage respondió %s", respuesta.status_code)
        raise AlmacenamientoError
    return f"{_prefijo_publico()}{nombre}"


def _guardar_local(contenido: bytes, nombre: str, base_url: str) -> str:
    try:
        settings.media_dir.mkdir(parents=True, exist_ok=True)
        (settings.media_dir / nombre).write_bytes(contenido)
    except OSError as error:
        log.error("No se pudo escribir la foto local: %s", error.__class__.__name__)
        raise AlmacenamientoError from None
    ruta = f"/media/{nombre}"
    return f"{base_url.rstrip('/')}{ruta}" if base_url else ruta


async def guardar_foto(archivo: UploadFile, base_url: str = "") -> str:
    """Valida (magic bytes, 5 MB) y guarda. Devuelve la URL pública."""
    partes: list[bytes] = []
    total = 0
    mime: str | None = None
    while True:
        trozo = await archivo.read(_CHUNK)
        if not trozo:
            break
        partes.append(trozo)
        total += len(trozo)
        if mime is None:
            mime = detectar_tipo(b"".join(partes))
            if mime is None and total >= 12:
                raise TipoNoPermitido
        if total > MAX_BYTES:
            raise ArchivoDemasiadoGrande
    contenido = b"".join(partes)
    mime = mime or detectar_tipo(contenido)
    if mime is None:
        raise TipoNoPermitido
    nombre = f"{uuid.uuid4().hex}.{_EXTENSIONES[mime]}"
    if usa_supabase():
        return await _subir_supabase(contenido, mime, nombre)
    return _guardar_local(contenido, nombre, base_url)
