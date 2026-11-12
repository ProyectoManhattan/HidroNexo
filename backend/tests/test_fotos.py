"""Subida de fotos de reportes con el almacenamiento mockeado."""
from contextlib import asynccontextmanager

import httpx
import pytest

from app import almacenamiento
from app.config import settings

JPG = b"\xff\xd8\xff\xe0" + b"\x00" * 100
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 100
WEBP = b"RIFF\x00\x00\x00\x00WEBP" + b"\x00" * 100
REPORTE = {"categoria": "fuga", "severidad": 1, "lat": 0, "lon": 0}
SUPA = "https://proyecto.supabase.co"
CLAVE_SERVICIO = "service-key-secreta"


@pytest.fixture
def local(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "supabase_url", "")
    monkeypatch.setattr(settings, "supabase_service_key", "")
    monkeypatch.setattr(settings, "media_dir", tmp_path)
    # StaticFiles ya está montado con el directorio original: se prueba en test aparte.
    return tmp_path


@pytest.fixture
def supabase(monkeypatch):
    monkeypatch.setattr(settings, "supabase_url", SUPA)
    monkeypatch.setattr(settings, "supabase_service_key", CLAVE_SERVICIO)
    monkeypatch.setattr(settings, "supabase_bucket", "reportes-fotos")
    llamadas = []
    estado = {"codigo": 200}

    def manejador(peticion: httpx.Request):
        llamadas.append(peticion)
        return httpx.Response(estado["codigo"], json={"Key": "x"})

    @asynccontextmanager
    async def cliente_falso():
        async with httpx.AsyncClient(transport=httpx.MockTransport(manejador)) as c:
            yield c

    monkeypatch.setattr(almacenamiento, "_cliente_http", cliente_falso)
    return llamadas, estado


def _subir(cliente, contenido, nombre="a.jpg", tipo="image/jpeg"):
    return cliente.post("/reports/photo", files={"foto": (nombre, contenido, tipo)})


def test_subida_ok_supabase(cliente, supabase):
    llamadas, _ = supabase
    r = _subir(cliente, JPG)
    assert r.status_code == 201
    url = r.json()["foto_url"]
    assert url.startswith(f"{SUPA}/storage/v1/object/public/reportes-fotos/") and url.endswith(".jpg")
    assert CLAVE_SERVICIO not in r.text
    p = llamadas[0]
    assert p.method == "POST" and str(p.url).startswith(f"{SUPA}/storage/v1/object/reportes-fotos/")
    assert p.headers["authorization"] == f"Bearer {CLAVE_SERVICIO}"
    assert "a.jpg" not in str(p.url)  # nombre aleatorio, no el del cliente


@pytest.mark.parametrize("contenido,ext", [(PNG, ".png"), (WEBP, ".webp")])
def test_extension_por_tipo_detectado(cliente, supabase, contenido, ext):
    r = _subir(cliente, contenido, "x.jpg", "image/jpeg")
    assert r.status_code == 201 and r.json()["foto_url"].endswith(ext)


def test_ejecutable_renombrado_jpg_415(cliente, supabase):
    r = _subir(cliente, b"MZ\x90\x00" + b"\x00" * 100, "virus.jpg", "image/jpeg")
    assert r.status_code == 415
    assert supabase[0] == []


def test_mas_de_5mb_413(cliente, supabase):
    r = _subir(cliente, JPG + b"\x00" * (5 * 1024 * 1024))
    assert r.status_code == 413
    assert supabase[0] == []


def test_exactamente_5mb_ok(cliente, supabase):
    assert _subir(cliente, JPG + b"\x00" * (5 * 1024 * 1024 - len(JPG))).status_code == 201


def test_fallo_de_storage_503(cliente, supabase):
    supabase[1]["codigo"] = 500
    r = _subir(cliente, JPG)
    assert r.status_code == 503 and "detail" in r.json()
    assert CLAVE_SERVICIO not in r.text


def test_storage_inalcanzable_503(cliente, supabase, monkeypatch):
    @asynccontextmanager
    async def roto():
        def m(_):
            raise httpx.ConnectError("sin red")

        async with httpx.AsyncClient(transport=httpx.MockTransport(m)) as c:
            yield c

    monkeypatch.setattr(almacenamiento, "_cliente_http", roto)
    assert _subir(cliente, JPG).status_code == 503


def test_sin_campo_foto_422(cliente, supabase):
    assert cliente.post("/reports/photo", files={"otro": ("a.jpg", JPG, "image/jpeg")}).status_code == 422


def test_reporte_con_foto_url_valida(cliente, supabase):
    url = _subir(cliente, JPG).json()["foto_url"]
    r = cliente.post("/reports", json={**REPORTE, "foto_url": url})
    assert r.status_code == 201 and r.json()["foto_url"] == url


def test_reporte_sin_foto_ok(cliente, supabase):
    assert cliente.post("/reports", json=REPORTE).status_code == 201


@pytest.mark.parametrize(
    "url",
    [
        "https://evil.example/x.jpg",
        f"{SUPA}/storage/v1/object/public/otro-bucket/{'a' * 32}.jpg",
        f"{SUPA}/storage/v1/object/public/reportes-fotos/../secreto.jpg",
        f"{SUPA}.evil.com/storage/v1/object/public/reportes-fotos/{'a' * 32}.jpg",
        f"/media/{'a' * 32}.jpg",  # ruta local no vale con Supabase activo
    ],
)
def test_foto_url_externa_422(cliente, supabase, url):
    assert cliente.post("/reports", json={**REPORTE, "foto_url": url}).status_code == 422


def test_foto_url_externa_422_modo_local(cliente, local):
    for url in ("https://evil.example/x.jpg", "/media/../etc/passwd", "/media/x.jpg"):
        assert cliente.post("/reports", json={**REPORTE, "foto_url": url}).status_code == 422


def test_modo_local_guarda_y_sirve(cliente, local, monkeypatch):
    # El mount de /media se creó con el media_dir original: se apunta a un directorio temporal.
    from app.main import app

    montaje = next(r for r in app.routes if getattr(r, "path", "") == "/media")
    monkeypatch.setattr(montaje.app, "directory", str(local))
    monkeypatch.setattr(montaje.app, "all_directories", [str(local)])
    r = _subir(cliente, PNG)
    assert r.status_code == 201
    url = r.json()["foto_url"]
    assert url.startswith("http://testserver/media/") and url.endswith(".png")
    archivo = local / url.rsplit("/", 1)[1]
    assert archivo.read_bytes() == PNG
    servido = cliente.get(url.removeprefix("http://testserver"))
    assert servido.status_code == 200 and servido.content == PNG
    assert cliente.post("/reports", json={**REPORTE, "foto_url": url}).status_code == 201
