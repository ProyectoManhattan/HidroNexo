from datetime import datetime, timezone

import httpx

from app.meteorologia import estado, ingesta

MOMENTO = datetime(2026, 11, 11, 12, 30, tzinfo=timezone.utc)
HORAS = [f"2026-11-11T{h:02d}:00" for h in range(24)] + [f"2026-11-12T{h:02d}:00" for h in range(24)]


def _punto(mm_ahora: float) -> dict:
    # lluvia solo en la hora actual (12:00) y 13:00
    lluvia = [0.0] * len(HORAS)
    lluvia[12] = mm_ahora
    lluvia[13] = 1.0
    return {"hourly": {"time": HORAS, "precipitation": lluvia}}


def _falso_get(llamadas):
    def get(url, params=None, timeout=None):
        llamadas.append(params)
        n = len(params["latitude"].split(","))
        # la lluvia es la latitud del punto * 0 + índice + 1 para distinguirlos
        cuerpo = [_punto(float(i + 1)) for i in range(n)]
        return httpx.Response(200, json=cuerpo if n > 1 else cuerpo[0], request=httpx.Request("GET", url))

    return get


def setup_function():
    estado.simular(None)
    estado.guardar({}, MOMENTO)
    estado.guardar_por_colonia({}, MOMENTO)


def test_prioridad_de_lluvia_de():
    a = {"mm_1h": 1.0, "mm_3h": 1.0, "mm_24h": 1.0, "pronostico_3h": 0.0}
    b = {"mm_1h": 5.0, "mm_3h": 5.0, "mm_24h": 5.0, "pronostico_3h": 2.0}
    estado.guardar_por_colonia({1: a, 2: b}, MOMENTO)
    assert estado.lluvia_de(1) == a
    assert estado.lluvia_de(2) == b
    assert estado.lluvia_de(99) == b  # fallback global = peor valor
    assert estado.lluvia_actual() == b
    tormenta = {"mm_1h": 20.0, "mm_3h": 40.0, "mm_24h": 80.0, "pronostico_3h": 40.0}
    estado.simular(tormenta)
    assert estado.lluvia_de(1) == tormenta
    assert estado.resumen()["simulacion"] is True
    assert estado.resumen()["colonias_con_lectura"] == 2


def test_deduplica_celdas_y_reparte(monkeypatch):
    llamadas = []
    monkeypatch.setattr(ingesta.httpx, "get", _falso_get(llamadas))
    centros = {1: (19.171, -96.131), 2: (19.174, -96.134), 3: (19.30, -96.20)}
    lecturas = ingesta.consultar_por_colonia(centros, MOMENTO)
    assert len(llamadas) == 1
    assert len(llamadas[0]["latitude"].split(",")) == 2  # 3 colonias, 2 celdas
    assert lecturas[1] == lecturas[2]
    assert lecturas[1] != lecturas[3]
    assert lecturas[1]["mm_1h"] == 1.0 and lecturas[3]["mm_1h"] == 2.0


def test_lotes_de_50(monkeypatch):
    llamadas = []
    monkeypatch.setattr(ingesta.httpx, "get", _falso_get(llamadas))
    centros = {i: (19.0 + i * 0.1, -96.0) for i in range(120)}
    lecturas = ingesta.consultar_por_colonia(centros, MOMENTO)
    assert [len(c["latitude"].split(",")) for c in llamadas] == [50, 50, 20]
    assert len(lecturas) == 120


def test_error_de_red_devuelve_none(monkeypatch):
    def falla(*a, **k):
        raise httpx.ConnectError("sin red")

    monkeypatch.setattr(ingesta.httpx, "get", falla)
    assert ingesta.consultar_por_colonia({1: (19.17, -96.13)}, MOMENTO) is None


def test_ejecutar_conserva_ultima_lectura_si_falla(monkeypatch):
    previo = {"mm_1h": 3.0, "mm_3h": 3.0, "mm_24h": 3.0, "pronostico_3h": 0.0}
    estado.guardar_por_colonia({1: previo}, MOMENTO)
    monkeypatch.setattr(ingesta, "centroides", lambda: {1: (19.17, -96.13)})
    monkeypatch.setattr(ingesta, "consultar_por_colonia", lambda c, m: None)
    publicados = []
    monkeypatch.setattr(ingesta.eventos, "publicar", lambda *a: publicados.append(a))
    ingesta.ejecutar()
    assert estado.lluvia_de(1) == previo
    assert publicados == []


def test_ejecutar_por_colonia_y_fallback_sin_bd(monkeypatch):
    publicados = []
    monkeypatch.setattr(ingesta.eventos, "publicar", lambda *a: publicados.append(a))
    l1 = {"mm_1h": 1.0, "mm_3h": 1.0, "mm_24h": 1.0, "pronostico_3h": 0.0}
    monkeypatch.setattr(ingesta, "centroides", lambda: {1: (19.17, -96.13)})
    monkeypatch.setattr(ingesta, "consultar_por_colonia", lambda c, m: {1: l1})
    ingesta.ejecutar()
    assert estado.lluvia_de(1) == l1 and publicados[0][0] == "weather.updated"

    estado.guardar_por_colonia({}, MOMENTO)
    g = {"mm_1h": 9.0, "mm_3h": 9.0, "mm_24h": 9.0, "pronostico_3h": 1.0}
    monkeypatch.setattr(ingesta, "centroides", lambda: {})
    monkeypatch.setattr(ingesta, "consultar", lambda: g)
    ingesta.ejecutar()
    assert estado.lluvia_de(1) == g
