"""Dispositivos: ubicación, derivación de colonia y selección de destinos (requieren PostGIS)."""
from datetime import timedelta
from types import SimpleNamespace

from sqlalchemy import select

BAJA = {"lat": 19.175, "lon": -96.135}  # dentro de "Colonia Prueba Baja"
ALTA = {"lat": 19.175, "lon": -96.125}  # dentro de "Colonia Prueba Alta"


def _ids(cliente):
    return {c["nombre"]: c["id"] for c in cliente.get("/zones").json()}


def _destino(colonia_id):
    from app.db import SessionLocal
    from app.dispositivos.servicio import dispositivos_destino

    with SessionLocal() as db:
        return {d.token for d in dispositivos_destino(db, SimpleNamespace(colonia_id=colonia_id))}


def _envejecer(token, horas):
    from app.db import SessionLocal
    from app.dispositivos.modelos import Dispositivo

    with SessionLocal() as db:
        d = db.scalar(select(Dispositivo).where(Dispositivo.token == token))
        d.ubicacion_actualizada_en = d.ubicacion_actualizada_en - timedelta(hours=horas)
        db.commit()


def test_registro_con_lat_lon_deriva_colonia(cliente):
    ids = _ids(cliente)
    r = cliente.post("/devices", json={"token": "tok-deriva-0001", **BAJA})
    assert r.status_code == 200, r.text
    assert r.json()["colonia_id"] == ids["Colonia Prueba Baja"]


def test_registro_con_ambos_guarda_ambos(cliente):
    ids = _ids(cliente)
    r = cliente.post("/devices", json={"token": "tok-ambos-0001", "colonia_id": ids["Colonia Prueba Baja"], **ALTA})
    assert r.json()["colonia_id"] == ids["Colonia Prueba Baja"]
    assert _destino(ids["Colonia Prueba Alta"]) == {"tok-ambos-0001"}
    assert "tok-ambos-0001" not in _destino(ids["Colonia Prueba Baja"])


def test_validaciones_del_registro(cliente):
    base = {"token": "tok-valida-001"}
    assert cliente.post("/devices", json=base).status_code == 422
    assert cliente.post("/devices", json={**base, "lat": 19.1}).status_code == 422
    assert cliente.post("/devices", json={**base, "lat": 91, "lon": 0}).status_code == 422
    assert cliente.post("/devices", json={**base, "lat": 0, "lon": 181}).status_code == 422
    assert cliente.post("/devices", json={**base, "colonia_id": 999999}).status_code == 404
    assert cliente.post("/devices", json={**base, "lat": 0, "lon": 0}).status_code == 404


def test_solo_colonia_sigue_funcionando(cliente):
    ids = _ids(cliente)
    cliente.post("/devices", json={"token": "tok-colonia-001", "colonia_id": ids["Colonia Prueba Baja"]})
    assert _destino(ids["Colonia Prueba Baja"]) == {"tok-colonia-001"}
    assert _destino(ids["Colonia Prueba Alta"]) == set()


def test_ubicacion_manda_sobre_colonia_declarada(cliente):
    ids = _ids(cliente)
    cliente.post("/devices", json={"token": "tok-viaje-0001", "colonia_id": ids["Colonia Prueba Baja"]})
    cliente.post("/devices", json={"token": "tok-viaje-0001", "colonia_id": ids["Colonia Prueba Baja"], **ALTA})
    assert _destino(ids["Colonia Prueba Baja"]) == set()
    assert _destino(ids["Colonia Prueba Alta"]) == {"tok-viaje-0001"}


def test_ubicacion_vencida_cae_a_colonia_declarada(cliente):
    ids = _ids(cliente)
    cliente.post("/devices", json={"token": "tok-viejo-0001", "colonia_id": ids["Colonia Prueba Baja"], **ALTA})
    _envejecer("tok-viejo-0001", 25)
    assert _destino(ids["Colonia Prueba Alta"]) == set()
    assert _destino(ids["Colonia Prueba Baja"]) == {"tok-viejo-0001"}


def test_funciones_por_geometria_y_radio(cliente):
    from app.db import SessionLocal
    from app.dispositivos.servicio import dispositivos_en_geometria, dispositivos_en_radio

    cliente.post("/devices", json={"token": "tok-geom-00001", **BAJA})
    cliente.post("/devices", json={"token": "tok-geom-00002", **ALTA})
    poligono = {
        "type": "Polygon",
        "coordinates": [[[-96.14, 19.17], [-96.13, 19.17], [-96.13, 19.18], [-96.14, 19.18], [-96.14, 19.17]]],
    }
    wkt = "POLYGON((-96.13 19.17,-96.12 19.17,-96.12 19.18,-96.13 19.18,-96.13 19.17))"
    with SessionLocal() as db:
        assert {d.token for d in dispositivos_en_geometria(db, poligono)} == {"tok-geom-00001"}
        assert {d.token for d in dispositivos_en_geometria(db, wkt)} == {"tok-geom-00002"}
        assert {d.token for d in dispositivos_en_radio(db, BAJA["lat"], BAJA["lon"], 100)} == {"tok-geom-00001"}
        assert len(dispositivos_en_radio(db, BAJA["lat"], BAJA["lon"], 5000)) == 2
