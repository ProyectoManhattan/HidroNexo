"""Caminos críticos de punta a punta (requieren PostgreSQL + PostGIS)."""
from tests.conftest import CLAVE

BAJA = {"lat": 19.175, "lon": -96.135}  # dentro de "Colonia Prueba Baja"


def _colonias(cliente):
    return {c["nombre"]: c["id"] for c in cliente.get("/zones").json()}


def test_health(cliente):
    assert cliente.get("/health").json() == {"status": "ok"}


def test_seed_carga_colonias_y_reportes(cliente):
    assert len(_colonias(cliente)) == 2
    assert len(cliente.get("/reports").json()) == 1


def test_reporte_se_asigna_a_su_colonia(cliente):
    r = cliente.post("/reports", json={"categoria": "inundacion", "severidad": 3, **BAJA})
    assert r.status_code == 201
    assert r.json()["colonia_id"] == _colonias(cliente)["Colonia Prueba Baja"]


def test_reporte_fuera_de_colonias_queda_sin_colonia(cliente):
    r = cliente.post("/reports", json={"categoria": "fuga", "severidad": 1, "lat": 0, "lon": 0})
    assert r.status_code == 201
    assert r.json()["colonia_id"] is None


def test_filtros_de_reportes(cliente):
    cliente.post("/reports", json={"categoria": "fuga", "severidad": 2, **BAJA})
    assert all(r["categoria"] == "fuga" for r in cliente.get("/reports?categoria=fuga").json())
    caja = "-96.14,19.17,-96.13,19.18"
    assert len(cliente.get(f"/reports?bbox={caja}").json()) == 1
    assert cliente.get("/reports?bbox=1,2").status_code == 422


def test_resolver_reporte_lo_quita_de_activos(cliente):
    rid = cliente.post("/reports", json={"categoria": "fuga", "severidad": 2, **BAJA}).json()["id"]
    assert cliente.post(f"/reports/{rid}/resolve").status_code == 401
    assert cliente.post(f"/reports/{rid}/resolve", headers=CLAVE).json()["estado"] == "resuelto"
    assert rid not in [r["id"] for r in cliente.get("/reports").json()]


def test_geojson_de_riesgo(cliente):
    datos = cliente.get("/zones/risk").json()
    assert datos["type"] == "FeatureCollection"
    assert len(datos["features"]) == 2
    assert datos["features"][0]["geometry"]["type"] == "MultiPolygon"


def test_admin_requiere_clave(cliente):
    assert cliente.post("/admin/simulate-storm", json={}).status_code == 401
    assert cliente.post("/admin/reset").status_code == 401


def test_tormenta_propone_alerta_y_se_aprueba(cliente):
    ids = _colonias(cliente)
    cliente.post(
        "/devices",
        json={"token": "token-de-prueba-123", "colonia_id": ids["Colonia Prueba Baja"]},
    )

    with cliente.websocket_connect("/ws") as ws:
        r = cliente.post("/admin/simulate-storm", json={"intensidad": 1.0}, headers=CLAVE)
        assert r.json()["simulacion"] is True
        tipos = {ws.receive_json()["tipo"] for _ in range(3)}
        assert "zone.risk_updated" in tipos

    # Solo la colonia vulnerable cruza a "alto": una sola alerta, rotulada como simulación
    propuestas = cliente.get("/alerts").json()
    assert [a["colonia_id"] for a in propuestas] == [ids["Colonia Prueba Baja"]]
    alerta = propuestas[0]
    assert alerta["simulada"] is True and alerta["redactada_por"] == "plantilla"

    # Repetir la tormenta no duplica la alerta
    cliente.post("/admin/simulate-storm", json={"intensidad": 1.0}, headers=CLAVE)
    assert len(cliente.get("/alerts").json()) == 1

    # Editar y aprobar requieren clave
    assert cliente.post(f"/alerts/{alerta['id']}/approve").status_code == 401
    editada = cliente.patch(f"/alerts/{alerta['id']}", json={"texto": "Texto revisado por PC"}, headers=CLAVE)
    assert editada.json()["texto"] == "Texto revisado por PC"
    assert cliente.post(f"/alerts/{alerta['id']}/approve", headers=CLAVE).json()["estado"] == "aprobada"
    assert cliente.post(f"/alerts/{alerta['id']}/approve", headers=CLAVE).status_code == 409

    # La app la ve con su guía
    activas = cliente.get(f"/alerts/active?colonia_id={ids['Colonia Prueba Baja']}").json()
    assert activas[0]["guia"]["titulo"] == "Guía de prueba"


def test_reset_borra_reportes_y_termina_simulacion(cliente):
    cliente.post("/admin/simulate-storm", json={}, headers=CLAVE)
    assert cliente.post("/admin/reset", headers=CLAVE).status_code == 200
    assert cliente.get("/reports").json() == []
    assert cliente.get("/admin/weather", headers=CLAVE).json()["simulacion"] is False
    assert len(_colonias(cliente)) == 2


def test_guias(cliente):
    assert "inundacion" in cliente.get("/guides").json()
    assert cliente.get("/guides/no-existe").status_code == 404


def test_alerta_manual_se_envia_de_inmediato(cliente):
    ids = _colonias(cliente)
    cuerpo = {"colonia_ids": list(ids.values()), "tipo": "fuga", "nivel": "medio", "texto": "Aviso manual de prueba"}
    assert cliente.post("/alerts", json=cuerpo).status_code == 401

    r = cliente.post("/alerts", json=cuerpo, headers=CLAVE)
    assert r.status_code == 201
    alertas = r.json()
    assert len(alertas) == len(ids)
    assert all(a["estado"] == "aprobada" and a["redactada_por"] == "manual" for a in alertas)
    assert all(a["motivo"] == "manual" and a["tipo"] == "fuga" for a in alertas)

    # No pasa por la bandeja de propuestas y la app la ve como activa
    assert cliente.get("/alerts").json() == []
    assert len(cliente.get("/alerts/active").json()) == len(ids)


def test_alerta_manual_valida_datos(cliente):
    ok = {"colonia_ids": [1], "tipo": "inundacion", "nivel": "alto", "texto": "Texto suficientemente largo"}
    inexistente = cliente.post("/alerts", json={**ok, "colonia_ids": [999999]}, headers=CLAVE)
    assert inexistente.status_code == 404
    assert cliente.post("/alerts", json={**ok, "colonia_ids": []}, headers=CLAVE).status_code == 422
    assert cliente.post("/alerts", json={**ok, "nivel": "bajo"}, headers=CLAVE).status_code == 422
    assert cliente.post("/alerts", json={**ok, "tipo": "otra"}, headers=CLAVE).status_code == 422
    assert cliente.post("/alerts", json={**ok, "texto": "corto"}, headers=CLAVE).status_code == 422


def test_reportes_de_ejemplo_uno_por_colonia(cliente):
    from app.admin import servicio
    from app.db import SessionLocal

    cliente.post("/admin/reset", headers=CLAVE)
    with SessionLocal() as db:
        assert servicio.cargar_reportes_demo(db) == len(_colonias(cliente))
    reportes = cliente.get("/reports").json()
    assert len(reportes) == len(_colonias(cliente))
    assert sorted(r["colonia_id"] for r in reportes) == sorted(_colonias(cliente).values())
    assert all(r["origen"] == "seed" for r in reportes)
