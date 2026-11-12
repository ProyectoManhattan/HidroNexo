"""Conector de solo lectura a los endpoints públicos usados por México Preparado."""
import json
import logging

import httpx

from app import eventos
from app.avisos_oficiales import estado

log = logging.getLogger(__name__)

BASE = "https://preparados.gob.mx/apps/alertamientosSSPC"
LISTA_URL = f"{BASE}/alertamientos_fns.php"
DETALLE_URL = f"{BASE}/publicacion_fns.php"
ESTADO_VERACRUZ = 30
FENOMENOS_RELEVANTES = {
    "lluvias",
    "inundaciones",
    "ciclón tropical",
    "ciclon tropical",
    "tormenta tropical",
    "fuertes vientos",
    "oleaje elevado",
    "marea de tormenta",
    "tormentas eléctricas",
    "tormentas electricas",
}


def _es_relevante(publicacion: dict) -> bool:
    textos = [
        publicacion.get("titulo", ""),
        publicacion.get("tipoPublicacion", ""),
        publicacion.get("siglasTipoPublicacion", ""),
    ]
    textos += [f.get("fenomeno", "") for f in publicacion.get("fenomenos", [])]
    unido = " ".join(textos).lower()
    # Un boletín forestal puede mencionar lluvia en el pronóstico general, pero no
    # representa una amenaza hidrometeorológica para este producto.
    if "siat-if" in unido or "incendio" in unido or "forestal" in unido:
        return False
    return "hidrometeor" in unido or "siat-ct" in unido or any(f in unido for f in FENOMENOS_RELEVANTES)


def _normalizar(publicacion: dict) -> dict:
    documentos = publicacion.get("documentos") or []
    estados = publicacion.get("estados") or []
    veracruz = next((e for e in estados if str(e.get("idEstado")) == str(ESTADO_VERACRUZ)), None)
    return {
        "id": publicacion["idPublicacion"],
        "titulo": publicacion.get("titulo"),
        "descripcion": publicacion.get("descripcion"),
        "tipo": publicacion.get("siglasTipoPublicacion") or publicacion.get("tipoPublicacion"),
        "institucion": publicacion.get("siglasInstitucion") or publicacion.get("institucion"),
        "emitida_en": publicacion.get("fecha"),
        "expira_en": publicacion.get("fechaExpiracion"),
        # El campo oficial describe alcance (estatal/municipal), no color SIAT-CT.
        "alcance": publicacion.get("nivelAlerta"),
        "fenomenos": [f.get("fenomeno") for f in publicacion.get("fenomenos", []) if f.get("fenomeno")],
        "municipios_veracruz": [m.get("municipio") for m in (veracruz or {}).get("municipios", [])],
        "documento_url": documentos[0].get("enlace") if documentos else None,
        "detalle_url": f"{BASE}/publicacion.php?pubId={publicacion['idPublicacion']}",
        "oficial": True,
    }


def consultar() -> list[dict]:
    opciones = json.dumps({"vigente": 1, "estados": [ESTADO_VERACRUZ]}, separators=(",", ":"))
    with httpx.Client(timeout=15, follow_redirects=True) as cliente:
        respuesta = cliente.get(
            LISTA_URL,
            params={"pubs": 1, "noResults": 50, "vigente": 1, "options": opciones},
        )
        respuesta.raise_for_status()
        listado = respuesta.json()
        if not listado.get("status", {}).get("ok"):
            raise ValueError("México Preparado respondió sin estado OK")

        alertas = []
        for item in listado.get("publicaciones", []):
            detalle = cliente.get(DETALLE_URL, params={"pubId": item["idPublicacion"]})
            detalle.raise_for_status()
            publicaciones = detalle.json().get("publicaciones") or []
            if publicaciones and _es_relevante(publicaciones[0]):
                alertas.append(_normalizar(publicaciones[0]))
        return alertas


def ejecutar() -> None:
    try:
        alertas = consultar()
        estado.guardar(alertas)
        eventos.publicar("official_alerts.updated", estado.resumen())
    except (httpx.HTTPError, ValueError, KeyError, TypeError) as error:
        log.warning("No se pudieron actualizar los alertamientos oficiales: %s", error)
        estado.guardar_error(str(error))
