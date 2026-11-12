"""POST /reports con cliente_id: reintentar no duplica (requiere PostGIS)."""

BASE = {"categoria": "inundacion", "severidad": 2, "lat": 19.175, "lon": -96.135, "descripcion": "Calle inundada"}
UUID = "3f1c2b8e-5d7a-4c19-9a62-0b7e4d1f8a10"


def _activos(cliente):
    return cliente.get("/reports").json()


def test_reintento_con_el_mismo_cliente_id_no_duplica(cliente):
    antes = len(_activos(cliente))
    primero = cliente.post("/reports", json={**BASE, "cliente_id": UUID})
    segundo = cliente.post("/reports", json={**BASE, "cliente_id": UUID})
    assert primero.status_code == 201, primero.text
    assert segundo.status_code == 200, segundo.text
    assert segundo.json()["id"] == primero.json()["id"]
    assert len(_activos(cliente)) == antes + 1


def test_cliente_id_distinto_crea_otro_reporte(cliente):
    a = cliente.post("/reports", json={**BASE, "cliente_id": "aaaaaaaa-0000-4000-8000-000000000001"})
    b = cliente.post("/reports", json={**BASE, "cliente_id": "aaaaaaaa-0000-4000-8000-000000000002"})
    assert a.status_code == b.status_code == 201
    assert a.json()["id"] != b.json()["id"]


def test_sin_cliente_id_funciona_como_antes(cliente):
    a = cliente.post("/reports", json=BASE)
    b = cliente.post("/reports", json=BASE)
    assert a.status_code == b.status_code == 201
    assert a.json()["id"] != b.json()["id"]


def test_cliente_id_invalido_es_422(cliente):
    for malo in ["corto", "con espacios y simbolos!!", "x" * 65]:
        assert cliente.post("/reports", json={**BASE, "cliente_id": malo}).status_code == 422


def test_el_cliente_id_no_se_expone_en_la_respuesta(cliente):
    r = cliente.post("/reports", json={**BASE, "cliente_id": "bbbbbbbb-0000-4000-8000-000000000001"})
    assert "cliente_id" not in r.json()
