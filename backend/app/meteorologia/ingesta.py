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


LOTE = 50
RESOLUCION = 0.05  # grados; resolución real de Open-Meteo


def _pedir(puntos: list[tuple[float, float]]) -> list[dict] | None:
    """Una petición a Open-Meteo con varias coordenadas. None si falla la red."""
    try:
        respuesta = httpx.get(
            URL,
            params={
                "latitude": ",".join(str(p[0]) for p in puntos),
                "longitude": ",".join(str(p[1]) for p in puntos),
                "hourly": "precipitation",
                "past_days": 1,
                "forecast_days": 1,
                "timezone": "UTC",
            },
            timeout=10,
        )
        respuesta.raise_for_status()
        datos = respuesta.json()
    except (httpx.HTTPError, ValueError):
        log.warning("Open-Meteo no respondió; se conserva la última lectura")
        return None
    return datos if isinstance(datos, list) else [datos]


def consultar_puntos(puntos: list[tuple[float, float]], momento: datetime) -> list[dict[str, float]] | None:
    """Resumen de lluvia por punto (mismo orden), en lotes de LOTE. None si algún lote falla."""
    resumenes: list[dict[str, float]] = []
    for i in range(0, len(puntos), LOTE):
        lote = puntos[i : i + LOTE]
        datos = _pedir(lote)
        if datos is None or len(datos) != len(lote):
            return None
        try:
            resumenes += [resumir_punto(p["hourly"]["time"], p["hourly"]["precipitation"], momento) for p in datos]
        except (KeyError, TypeError, ValueError):
            log.warning("Respuesta de Open-Meteo inesperada; se conserva la última lectura")
            return None
    return resumenes


def consultar() -> dict[str, float] | None:
    """Consulta los puntos fijos y se queda con el peor valor de cada ventana (fallback global)."""
    resumenes = consultar_puntos(list(settings.meteo_puntos), datetime.now(timezone.utc))
    if not resumenes:
        return None
    return {k: max(r[k] for r in resumenes) for k in resumenes[0]}


def _celda(lat: float, lon: float) -> tuple[float, float]:
    return (round(round(lat / RESOLUCION) * RESOLUCION, 2), round(round(lon / RESOLUCION) * RESOLUCION, 2))


def centroides() -> dict[int, tuple[float, float]]:
    """Centroide (lat, lon) de cada colonia. Vacío si la BD falla."""
    from sqlalchemy import func, select

    from app.colonias.modelos import Colonia
    from app.db import SessionLocal

    try:
        with SessionLocal() as db:
            filas = db.execute(
                select(
                    Colonia.id,
                    func.ST_Y(func.ST_Centroid(Colonia.geom)),
                    func.ST_X(func.ST_Centroid(Colonia.geom)),
                ).where(Colonia.geom.is_not(None))
            ).all()
    except Exception:
        log.warning("No se pudieron leer las colonias; se usa la lectura global", exc_info=True)
        return {}
    return {cid: (float(lat), float(lon)) for cid, lat, lon in filas if lat is not None and lon is not None}


def consultar_por_colonia(
    centros: dict[int, tuple[float, float]], momento: datetime
) -> dict[int, dict[str, float]] | None:
    """Lluvia por colonia; las colonias que caen en la misma celda de ~0.05 grados comparten consulta."""
    celdas = {cid: _celda(*c) for cid, c in centros.items()}
    unicas = sorted(set(celdas.values()))
    resumenes = consultar_puntos(unicas, momento)
    if resumenes is None:
        return None
    por_celda = dict(zip(unicas, resumenes))
    return {cid: dict(por_celda[c]) for cid, c in celdas.items()}


def ejecutar() -> None:
    """Tarea programada: actualizar lluvia y avisar para recalcular riesgo."""
    centros = centroides()
    if centros:
        lecturas = consultar_por_colonia(centros, datetime.now(timezone.utc))
        if lecturas is None:
            return  # error de red: se conserva la última lectura
        estado.guardar_por_colonia(lecturas, ahora())
    else:
        lluvia = consultar()
        if lluvia is None:
            return
        estado.guardar(lluvia, ahora())
    eventos.publicar("weather.updated", estado.resumen())
