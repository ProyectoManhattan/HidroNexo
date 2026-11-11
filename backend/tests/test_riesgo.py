from app.riesgo.calculo import (
    calcular,
    componente_lluvia,
    componente_reportes,
    nivel_para,
    sube_a_alerta,
)


def test_sin_lluvia_ni_reportes_es_bajo():
    assert calcular(0, 0, 0.3).nivel == "bajo"


def test_todo_al_maximo_es_critico():
    assert calcular(1, 1, 1).nivel == "critico"


def test_valores_fuera_de_rango_se_limitan():
    assert calcular(5, -1, 0).valor == 0.4


def test_motivo_es_el_mayor_aporte():
    assert calcular(0.9, 0.1, 0.1).motivo == "lluvia"


def test_histeresis_evita_bajar_por_poco():
    assert nivel_para(0.73, nivel_anterior="critico") == "critico"
    assert nivel_para(0.65, nivel_anterior="critico") == "alto"


def test_subir_siempre_es_inmediato():
    assert nivel_para(0.76, nivel_anterior="bajo") == "critico"


def test_lluvia_toma_la_ventana_mas_grave():
    assert componente_lluvia({"mm_1h": 10, "mm_24h": 8}) == 0.5
    assert componente_lluvia({}) == 0.0


def test_reportes_se_saturan():
    assert componente_reportes(30) == 1.0


def test_alerta_solo_al_subir_a_alto_o_critico():
    assert sube_a_alerta("medio", "alto")
    assert sube_a_alerta(None, "critico")
    assert not sube_a_alerta("alto", "alto")
    assert not sube_a_alerta("critico", "alto")
    assert not sube_a_alerta("bajo", "medio")
