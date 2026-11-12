"""Probabilidad de lluvia del pronóstico (precipitation_probability de Open-Meteo)."""
from datetime import datetime, timedelta, timezone

import pytest

from app.meteorologia import estado
from app.meteorologia.ingesta import resumir_punto
from app.riesgo.calculo import componente_lluvia, pronostico_efectivo, resumen_pronostico
from tests.conftest import CLAVE

AHORA = datetime(2026, 11, 11, 12, 30, tzinfo=timezone.utc)
HORAS = [(datetime(2026, 11, 11) + timedelta(hours=h)).isoformat(timespec="minutes") for h in range(24)]


def test_resumen_incluye_probabilidad_maxima_de_las_proximas_horas():
    lluvia = [0.0] * 24
    prob = [0.0] * 24
    prob[10] = 99  # pasada: no cuenta
    prob[13], prob[15], prob[18] = 40, 70, 90  # 13–15 = próximas 3 h; 13–18 = próximas 6 h
    r = resumir_punto(HORAS, lluvia, AHORA, prob)
    assert r["prob_3h"] == 70
    assert r["prob_6h"] == 90


def test_sin_probabilidad_no_agrega_claves():
    r = resumir_punto(HORAS, [0.0] * 24, AHORA)
    assert "prob_3h" not in r and "prob_6h" not in r


def test_probabilidades_nulas_se_ignoran():
    r = resumir_punto(HORAS, [0.0] * 24, AHORA, [None] * 24)
    assert "prob_3h" not in r


def test_pronostico_se_pondera_por_probabilidad():
    assert pronostico_efectivo({"pronostico_3h": 20.0, "prob_3h": 30}) == pytest.approx(6.0)
    assert pronostico_efectivo({"pronostico_3h": 20.0}) == 20.0  # sin dato: como antes


def test_pronostico_poco_probable_casi_no_sube_el_riesgo():
    seguro = componente_lluvia({"pronostico_3h": 40.0, "prob_3h": 100})
    dudoso = componente_lluvia({"pronostico_3h": 40.0, "prob_3h": 10})
    assert seguro == 1.0
    assert dudoso == pytest.approx(0.1)


def test_lluvia_observada_no_depende_de_la_probabilidad():
    assert componente_lluvia({"mm_1h": 20.0, "pronostico_3h": 0.0, "prob_3h": 0}) == 1.0


def test_resumen_para_el_panel():
    r = resumen_pronostico({"pronostico_3h": 15.0, "prob_3h": 80, "prob_6h": 90})
    assert r == {"mm_3h": 15.0, "prob_3h": 80, "prob_6h": 90, "mm_3h_efectivos": 12.0}


def test_lecturas_mixtas_con_y_sin_probabilidad():
    con = {"mm_1h": 1.0, "mm_3h": 1.0, "mm_24h": 1.0, "pronostico_3h": 2.0, "prob_3h": 60.0}
    sin = {"mm_1h": 3.0, "mm_3h": 3.0, "mm_24h": 3.0, "pronostico_3h": 1.0}
    estado.simular(None)
    estado.guardar_por_colonia({1: con, 2: sin}, AHORA)
    try:
        assert estado.lluvia_actual()["mm_1h"] == 3.0
        assert estado.lluvia_actual()["prob_3h"] == 60.0
    finally:
        estado.guardar_por_colonia({}, AHORA)
        estado.guardar({}, AHORA)


def test_geojson_trae_pronostico(cliente):
    cliente.post("/admin/simulate-storm", json={"intensidad": 0.5, "probabilidad": 80}, headers=CLAVE)
    zona = cliente.get("/zones/risk").json()["features"][0]["properties"]
    assert zona["pronostico"]["prob_3h"] == 80
    assert zona["pronostico"]["mm_3h"] == 20.0
    assert zona["pronostico"]["mm_3h_efectivos"] == 16.0


def test_tormenta_que_viene_depende_de_la_probabilidad(cliente):
    """Sin lluvia caída, el riesgo por lluvia sale solo del pronóstico ponderado."""

    def zona(probabilidad):
        cliente.post("/admin/reset", headers=CLAVE)
        clima = cliente.post(
            "/admin/simulate-storm",
            json={"intensidad": 1.0, "probabilidad": probabilidad, "solo_pronostico": True},
            headers=CLAVE,
        ).json()
        assert clima["lluvia"]["mm_1h"] == 0.0 and clima["lluvia"]["prob_3h"] == probabilidad
        return cliente.get("/zones/risk").json()["features"][0]["properties"]

    poco_probable, muy_probable = zona(10), zona(90)
    assert poco_probable["componentes"]["lluvia"] == pytest.approx(0.1)
    assert muy_probable["componentes"]["lluvia"] == pytest.approx(0.9)
    assert muy_probable["riesgo"] > poco_probable["riesgo"]
