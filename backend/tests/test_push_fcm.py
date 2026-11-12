"""Push FCM (mockeado) y auditoría de entregas. Usa SQLite en memoria: no necesita Postgres."""
from types import SimpleNamespace

import pytest
from firebase_admin import exceptions, messaging
from sqlalchemy import select
from sqlalchemy.orm import Session
from sqlalchemy.schema import CreateTable
from sqlalchemy.pool import StaticPool

from app.alertas import servicio
from app.alertas.modelos import Alerta, EntregaAlerta
from app.colonias.modelos import Colonia
from app.config import settings
from app.dispositivos.modelos import Dispositivo
from app.notificaciones import push
from app.utiles import ahora


@pytest.fixture
def db(base_de_datos):
    from sqlalchemy import text

    with Session(base_de_datos, expire_on_commit=False) as sesion:
        sesion.execute(text("TRUNCATE entregas_alerta, dispositivos, alertas, colonias RESTART IDENTITY CASCADE"))
        sesion.add(Colonia(id=1, nombre="Colonia de prueba"))
        sesion.commit()
        yield sesion


@pytest.fixture
def fcm(monkeypatch):
    monkeypatch.setattr(settings, "fcm_credenciales_json", '{"simulado": true}')
    monkeypatch.setattr(push, "ESPERA_REINTENTO_S", 0)
    llamadas = []
    return llamadas


def _alerta(db, n_dispositivos=3):
    alerta = Alerta(colonia_id=1, tipo="inundacion", nivel="alto", texto="Evita la zona", creada_en=ahora())
    db.add(alerta)
    db.add_all([Dispositivo(token=f"tok{i}", colonia_id=1, actualizado_en=ahora()) for i in range(n_dispositivos)])
    db.commit()
    return alerta


def _ok():
    return SimpleNamespace(success=True, exception=None)


def _fallo(excepcion):
    return SimpleNamespace(success=False, exception=excepcion)


def test_sin_credenciales_es_simulado(db, monkeypatch):
    monkeypatch.setattr(settings, "fcm_credenciales_json", "")
    alerta = _alerta(db)
    resumen = push.enviar_alerta(db, alerta)
    assert resumen == {"total": 3, "enviados": 3, "fallidos": 0, "token_invalidos": 0}


def test_envio_ok_con_payload(db, fcm, monkeypatch):
    def falso(tokens, titulo, cuerpo, datos):
        fcm.append((tokens, titulo, cuerpo, datos))
        return [_ok() for _ in tokens]

    monkeypatch.setattr(push, "_multicast", falso)
    alerta = _alerta(db)
    resumen = push.enviar_alerta(db, alerta)
    assert resumen["enviados"] == 3 and resumen["total"] == 3
    tokens, titulo, cuerpo, datos = fcm[0]
    assert sorted(tokens) == ["tok0", "tok1", "tok2"]
    assert titulo == "Alerta alto" and cuerpo == "Evita la zona"
    assert datos == {"alerta_id": str(alerta.id), "tipo": "inundacion", "nivel": "alto"}
    assert servicio.resumen_entregas(db, alerta.id)["enviados"] == 3


def test_token_invalido_se_borra(db, fcm, monkeypatch):
    def falso(tokens, *_):
        return [_fallo(messaging.UnregisteredError("x")) if t == "tok1" else _ok() for t in tokens]

    monkeypatch.setattr(push, "_multicast", falso)
    alerta = _alerta(db)
    resumen = push.enviar_alerta(db, alerta)
    assert resumen == {"total": 3, "enviados": 2, "fallidos": 0, "token_invalidos": 1}
    assert db.scalars(select(Dispositivo.token).order_by(Dispositivo.token)).all() == ["tok0", "tok2"]
    entrega = db.scalar(select(EntregaAlerta).where(EntregaAlerta.estado == "token_invalido"))
    assert entrega.dispositivo_id is None and "UnregisteredError" in entrega.error


def test_fallo_transitorio_se_reintenta(db, fcm, monkeypatch):
    intentos = {"n": 0}

    def falso(tokens, *_):
        intentos["n"] += 1
        if intentos["n"] == 1:
            return [_fallo(exceptions.UnavailableError("caído")) for _ in tokens]
        return [_ok() for _ in tokens]

    monkeypatch.setattr(push, "_multicast", falso)
    resumen = push.enviar_alerta(db, _alerta(db, 2))
    assert intentos["n"] == 2
    assert resumen["enviados"] == 2 and resumen["fallidos"] == 0


def test_fallo_persistente_queda_fallido(db, fcm, monkeypatch):
    monkeypatch.setattr(push, "_multicast", lambda tokens, *_: [_fallo(exceptions.UnavailableError("x")) for _ in tokens])
    resumen = push.enviar_alerta(db, _alerta(db, 2))
    assert resumen["fallidos"] == 2 and resumen["enviados"] == 0
    assert db.scalar(select(Dispositivo.id).limit(1)) is not None  # no se borran


def test_lotes_de_500(db, fcm, monkeypatch):
    tamanos = []

    def falso(tokens, *_):
        tamanos.append(len(tokens))
        return [_ok() for _ in tokens]

    monkeypatch.setattr(push, "_multicast", falso)
    resultados = push._enviar_tokens([f"t{i}" for i in range(1203)], "t", "c", {})
    assert tamanos == [500, 500, 203] and len(resultados) == 1203


def test_resumen_de_entregas_mezcla(db):
    alerta = _alerta(db, 0)
    for estado in ["enviado", "enviado", "fallido", "token_invalido"]:
        db.add(EntregaAlerta(alerta_id=alerta.id, estado=estado, enviada_en=ahora()))
    db.commit()
    assert servicio.resumen_entregas(db, alerta.id) == {"total": 4, "enviados": 2, "fallidos": 1, "token_invalidos": 1}


def test_endpoint_entregas_y_evento(cliente):
    from app import eventos

    recibidos = []
    eventos.suscribir("alert.approved", recibidos.append)
    assert cliente.get("/alerts/999999/deliveries").status_code == 404
    colonia = cliente.get("/colonias").json()[0]["id"] if cliente.get("/colonias").status_code == 200 else 1
    creada = cliente.post(
        "/alerts",
        headers={"X-Clave": "clave-de-prueba"},
        json={"colonia_ids": [colonia], "tipo": "inundacion", "nivel": "alto", "texto": "Texto de prueba largo"},
    )
    assert creada.status_code == 201, creada.text
    alerta_id = creada.json()[0]["id"]
    resumen = cliente.get(f"/alerts/{alerta_id}/deliveries").json()
    assert set(resumen) == {"total", "enviados", "fallidos", "token_invalidos"}
    evento = [e for e in recibidos if e["id"] == alerta_id][0]
    assert evento["dispositivos_notificados"] == resumen["enviados"] and evento["entregas"] == resumen
