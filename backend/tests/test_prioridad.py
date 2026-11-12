from datetime import datetime, timedelta, timezone

import pytest

from app.reportes import servicio
from app.reportes.esquemas import ReporteSalida
from app.riesgo.calculo import AMPLIFICACION_LLUVIA_MAX, severidad_efectiva

SECO = {}
SATURADA = {"mm_1h": 20.0}
MEDIA = {"mm_1h": 10.0}


def test_sin_lluvia_no_cambia():
    assert severidad_efectiva(3, "inundacion", SECO) == 3.0


def test_categoria_lluvia_se_amplifica_hasta_el_tope():
    assert severidad_efectiva(2, "encharcamiento", MEDIA) == pytest.approx(2 * 1.25)
    assert severidad_efectiva(2, "alcantarilla", {"mm_24h": 500}) == pytest.approx(2 * (1 + AMPLIFICACION_LLUVIA_MAX))


@pytest.mark.parametrize("cat", ["fuga", "sin_agua", "otra_nueva"])
def test_categorias_no_dependientes_no_cambian(cat):
    assert severidad_efectiva(3, cat, SATURADA) == 3.0


def test_nunca_baja_de_la_severidad():
    for cat in ["inundacion", "fuga"]:
        assert severidad_efectiva(1, cat, SECO) >= 1.0


class _R:
    def __init__(self, id, cat, sev, minutos, colonia=1):
        self.id, self.categoria, self.severidad, self.colonia_id = id, cat, sev, colonia
        self.lat = self.lon = 0.0
        self.descripcion = self.foto_url = None
        self.origen, self.estado = "app", "activo"
        base = datetime(2026, 1, 1, tzinfo=timezone.utc)
        self.creado_en = base + timedelta(minutes=minutos)
        self.expira_en = self.creado_en + timedelta(hours=6)


def test_orden_por_prioridad_y_luego_fecha(monkeypatch):
    monkeypatch.setattr(servicio.meteo, "lluvia_de", lambda c: SATURADA, raising=False)
    rs = [_R(1, "fuga", 3, 0), _R(2, "inundacion", 3, 1), _R(3, "fuga", 3, 5), _R(4, "inundacion", 1, 9)]
    out = servicio.ordenar_por_prioridad(rs)
    # inundacion sev3 = 4.5; fugas sev3 = 3.0 (más reciente primero); inundacion sev1 = 1.5
    assert [r.id for r in out] == [2, 3, 1, 4]
    assert out[0].prioridad == pytest.approx(4.5)


def test_prioridad_es_aditiva_y_opcional():
    r = _R(1, "fuga", 1, 0)
    assert ReporteSalida.model_validate(r).prioridad is None
