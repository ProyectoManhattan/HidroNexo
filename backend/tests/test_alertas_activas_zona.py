"""GET /alerts/active filtrado por la ubicación de quien consulta (requiere PostGIS)."""
from tests.conftest import CLAVE

BAJA = {"lat": 19.175, "lon": -96.135}  # dentro de "Colonia Prueba Baja"
ALTA = {"lat": 19.175, "lon": -96.125}  # dentro de "Colonia Prueba Alta"
FUERA = {"lat": 0.0, "lon": 0.0}


def _alerta_manual(cliente, colonia_id):
    r = cliente.post(
        "/alerts",
        headers=CLAVE,
        json={"colonia_ids": [colonia_id], "tipo": "inundacion", "nivel": "alto", "texto": "Alerta de prueba de zona"},
    )
    assert r.status_code == 201, r.text
    return r.json()[0]["id"]


def _ids(cliente):
    return {c["nombre"]: c["id"] for c in cliente.get("/zones").json()}


def test_con_ubicacion_solo_devuelve_la_zona_del_punto(cliente):
    ids = _ids(cliente)
    id_baja = _alerta_manual(cliente, ids["Colonia Prueba Baja"])
    en_baja = [a["id"] for a in cliente.get("/alerts/active", params=BAJA).json()]
    en_alta = [a["id"] for a in cliente.get("/alerts/active", params=ALTA).json()]
    assert id_baja in en_baja
    assert id_baja not in en_alta


def test_ubicacion_manda_sobre_colonia_id(cliente):
    ids = _ids(cliente)
    id_baja = _alerta_manual(cliente, ids["Colonia Prueba Baja"])
    r = cliente.get("/alerts/active", params={**ALTA, "colonia_id": ids["Colonia Prueba Baja"]})
    assert id_baja not in [a["id"] for a in r.json()]


def test_punto_fuera_de_toda_colonia_devuelve_lista_vacia(cliente):
    ids = _ids(cliente)
    _alerta_manual(cliente, ids["Colonia Prueba Baja"])
    r = cliente.get("/alerts/active", params=FUERA)
    assert r.status_code == 200 and r.json() == []


def test_lat_sin_lon_es_422(cliente):
    assert cliente.get("/alerts/active", params={"lat": 19.1}).status_code == 422
    assert cliente.get("/alerts/active", params={"lon": -96.1}).status_code == 422


def test_sin_ubicacion_sigue_filtrando_por_colonia_id(cliente):
    ids = _ids(cliente)
    id_baja = _alerta_manual(cliente, ids["Colonia Prueba Baja"])
    r = cliente.get("/alerts/active", params={"colonia_id": ids["Colonia Prueba Baja"]})
    assert id_baja in [a["id"] for a in r.json()]
    r = cliente.get("/alerts/active", params={"colonia_id": ids["Colonia Prueba Alta"]})
    assert id_baja not in [a["id"] for a in r.json()]
