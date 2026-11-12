"""Conecta los módulos a través del bus de eventos.

report.created ──► recalcular riesgo de la colonia
weather.updated ─► recalcular riesgo de todas las colonias
zone.threshold_crossed ─► la IA propone una alerta
(todo lo relevante) ─► WebSocket al panel
"""
from app import eventos
from app.alertas import servicio as alertas
from app.db import SessionLocal
from app.riesgo import servicio as riesgo
from app.tiempo_real import conexiones

AL_PANEL = [
    "report.created",
    "report.updated",
    "weather.updated",
    "zone.risk_updated",
    "alert.drafted",
    "alert.approved",
    "official_alerts.updated",
]


def _al_crear_reporte(datos: dict) -> None:
    if datos.get("colonia_id"):
        with SessionLocal() as db:
            riesgo.recalcular(db, datos["colonia_id"])


def _al_actualizar_clima(_datos) -> None:
    with SessionLocal() as db:
        riesgo.recalcular_todas(db)


def _al_cruzar_umbral(datos: dict) -> None:
    with SessionLocal() as db:
        alertas.proponer(db, datos["colonia_id"], datos["nivel"], datos["motivo"])


def registrar() -> None:
    eventos.limpiar()
    eventos.suscribir("report.created", _al_crear_reporte)
    eventos.suscribir("report.updated", _al_crear_reporte)
    eventos.suscribir("weather.updated", _al_actualizar_clima)
    eventos.suscribir("zone.threshold_crossed", _al_cruzar_umbral)
    for evento in AL_PANEL:
        eventos.suscribir(evento, lambda datos, e=evento: conexiones.difundir(e, datos))
