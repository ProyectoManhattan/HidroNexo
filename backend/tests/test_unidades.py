from datetime import datetime, timedelta, timezone

import pytest
from pydantic import ValidationError

from app import eventos
from app.ia.clasificador import clasificar_por_reglas
from app.ia.redactor_alertas import redactar_alerta
from app.meteorologia.ingesta import resumir_punto
from app.reportes.esquemas import ReporteEntrada


def test_plantilla_sin_llm():
    texto, origen = redactar_alerta("Centro", "alto", "lluvia", "inundacion")
    assert "Centro" in texto and "911" in texto
    assert origen == "plantilla"


def test_tipo_sin_plantilla_usa_la_general():
    texto, _ = redactar_alerta("Centro", "medio", "reportes", "fuga")
    assert "Centro" in texto


def test_clasificador_por_reglas():
    assert clasificar_por_reglas("Hay una FUGA enorme en la esquina") == "fuga"
    assert clasificar_por_reglas("todo bien") is None


def test_categoria_invalida():
    with pytest.raises(ValidationError):
        ReporteEntrada(categoria="tornado", severidad=2, lat=19.1, lon=-96.1)


def test_severidad_fuera_de_rango():
    with pytest.raises(ValidationError):
        ReporteEntrada(categoria="fuga", severidad=5, lat=19.1, lon=-96.1)


def test_resumen_de_lluvia_por_ventanas():
    ahora = datetime(2026, 11, 11, 12, 30, tzinfo=timezone.utc)
    inicio = datetime(2026, 11, 11, 0, 0)
    horas = [(inicio + timedelta(hours=h)).isoformat(timespec="minutes") for h in range(24)]
    lluvia = [0.0] * 24
    lluvia[12], lluvia[11], lluvia[13] = 5.0, 3.0, 7.0  # 12:00 es la hora actual
    r = resumir_punto(horas, lluvia, ahora)
    assert r["mm_1h"] == 5.0
    assert r["mm_3h"] == 8.0
    assert r["pronostico_3h"] == 7.0


def test_suscriptor_con_error_no_rompe_el_bus():
    recibidos = []
    eventos.limpiar()
    eventos.suscribir("x", lambda d: 1 / 0)
    eventos.suscribir("x", recibidos.append)
    eventos.publicar("x", 42)
    assert recibidos == [42]
    eventos.limpiar()
