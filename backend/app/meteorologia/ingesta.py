import logging
from datetime import datetime, timezone

import httpx

from app import eventos
from app.config import settings
from app.meteorologia import estado
from app.utiles import ahora

log = logging.getLogger(__name__)

URL = "https://api.open-meteo.com/v1/forecast"


def resumir_punto(horas: list[str], precipitacion: list[float | None], momento: datetime) -> dict[str, float]:
    """Suma la lluvia de la última 1 h, 3 h y 24 h, más el pronóstico de las próximas 3 h."""
    actual = momento.replace(minute=0, second=0, microsecond=0, tzinfo=None)
    pasadas, futuras = [], []
    for hora, mm in zip(horas, precipitacion):
        instante = datetime.fromisoformat(hora)
        (pasadas if instante <= actual else futuras).append(mm or 0.0)
    return {
        "mm_1h": round(sum(pasadas[-1:]), 2),
        "mm_3h": round(sum(pasadas[-3:]), 2),
        "mm_24h": round(sum(pasadas[-24:]), 2),
        "pronostico_3h": round(sum(futuras[:3]), 2),
    }


def consultar() -> dict[str, float] | None:
    """Consulta todos los puntos y se queda con el peor valor de cada ventana."""
    lats = ",".join(str(p[0]) for p in settings.meteo_puntos)
    lons = ",".join(str(p[1]) for p in settings.meteo_puntos)
    try:
        respuesta = httpx.get(
            URL,
            params={
                "latitude": lats,
                "longitude": lons,
                "hourly": "precipitation",
                "past_days": 1,
                "forecast_days": 1,
                "timezone": "UTC",
            },
            timeout=10,
        )
        respuesta.raise_for_status()
    except httpx.HTTPError:
        log.warning("Open-Meteo no respondió; se conserva la última lectura")
        return None

    datos = respuesta.json()
    puntos = datos if isinstance(datos, list) else [datos]
    momento = datetime.now(timezone.utc)
    resumenes = [resumir_punto(p["hourly"]["time"], p["hourly"]["precipitation"], momento) for p in puntos]
    return {k: max(r[k] for r in resumenes) for k in resumenes[0]}


def ejecutar() -> None:
    """Tarea programada: actualizar lluvia y avisar para recalcular riesgo."""
    lluvia = consultar()
    if lluvia is None:
        return
    estado.guardar(lluvia, ahora())
    eventos.publicar("weather.updated", estado.resumen())
