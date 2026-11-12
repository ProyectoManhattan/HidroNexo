from app.avisos_oficiales.ingesta import _es_relevante, _normalizar


PUBLICACION = {
    "idPublicacion": "abc123",
    "titulo": "Boletín de Alerta Hidrometeorológica General",
    "descripcion": "Lluvias fuertes en el oriente del país.",
    "siglasTipoPublicacion": "BAHG",
    "siglasInstitucion": "DGPC",
    "fecha": "11 Noviembre 2026, 07:00",
    "fechaExpiracion": "12 Noviembre 2026, 07:00",
    "nivelAlerta": "Estatal",
    "fenomenos": [{"fenomeno": "Lluvias"}, {"fenomeno": "Fuertes Vientos"}],
    "estados": [{"idEstado": "30", "estado": "Veracruz", "municipios": []}],
    "documentos": [{"enlace": "https://preparados.gob.mx/boletin.pdf"}],
}


def test_filtra_alertamientos_hidrometeorologicos():
    assert _es_relevante(PUBLICACION)
    assert not _es_relevante({"titulo": "Aviso administrativo", "fenomenos": []})


def test_excluye_alertamientos_de_incendios_aunque_mencionen_lluvias():
    assert not _es_relevante(
        {
            "titulo": "Sistema de Alerta Temprana por Incendios Forestales",
            "siglasTipoPublicacion": "SIAT-IF",
            "fenomenos": [{"fenomeno": "Lluvias"}],
        }
    )


def test_normaliza_sin_inventar_color_siat():
    alerta = _normalizar(PUBLICACION)
    assert alerta["alcance"] == "Estatal"
    assert "nivel_siat" not in alerta
    assert alerta["fenomenos"] == ["Lluvias", "Fuertes Vientos"]
    assert alerta["oficial"] is True
