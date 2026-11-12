import logging
from datetime import datetime, timezone

import httpx

from app import eventos
from app.config import settings
from app.meteorologia import estado
from app.utiles import ahora

log = logging.getLogger(__name__)

URL = "https://api.open-meteo.com/v1/forecast"


def resumir_punto(
    horas: list[str],
    precipitacion: list[float | None],
    momento: datetime,
    probabilidad: list[float | None] | None = None,
) -> dict[str, float]:
    """Suma la lluvia de la última 1 h, 3 h y 24 h, más el pronóstico de las próximas 3 h.

    Si viene `probabilidad` (precipitation_probability de Open-Meteo, en %), agrega
    prob_3h y prob_6h: la probabilidad máxima de lluvia en las próximas 3 y 6 horas.
    """
    actual = momento.replace(minute=0, second=0, microsecond=0, tzinfo=None)
    pasadas, futuras, probs_futuras = [], [], []
    probs = probabilidad if probabilidad is not None else [None] * len(horas)
    for hora, mm, prob in zip(horas, precipitacion, probs):
        instante = datetime.fromisoformat(hora)
        if instante <= actual:
            pasadas.append(mm or 0.0)
        else:
            futuras.append(mm or 0.0)
            probs_futuras.append(prob)
    resumen = {
        "mm_1h": round(sum(pasadas[-1:]), 2),
        "mm_3h": round(sum(pasadas[-3:]), 2),
        "mm_24h": round(sum(pasadas[-24:]), 2),
        "pronostico_3h": round(sum(futuras[:3]), 2),
    }
    for clave, horas_ventana in (("prob_3h", 3), ("prob_6h", 6)):
        valores = [p for p in probs_futuras[:horas_ventana] if p is not None]
        if valores:
            resumen[clave] = float(max(valores))
    return resumen


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
                "hourly": "precipitation,precipitation_probability",
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
            resumenes += [
                resumir_punto(
                    p["hourly"]["time"],
                    p["hourly"]["precipitation"],
                    momento,
                    p["hourly"].get("precipitation_probability"),
                )
                for p in datos
            ]
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


def consultar_por_celda(
    centros: dict[int, tuple[float, float]], momento: datetime
) -> tuple[dict[int, tuple[float, float]], dict[tuple[float, float], dict[str, float]]] | None:
    """(celda de cada colonia, lluvia de cada celda). Las colonias de una misma celda comparten consulta."""
    celdas = {cid: _celda(*c) for cid, c in centros.items()}
    unicas = sorted(set(celdas.values()))
    resumenes = consultar_puntos(unicas, momento)
    if resumenes is None:
        return None
    return celdas, dict(zip(unicas, resumenes))


def consultar_por_colonia(
    centros: dict[int, tuple[float, float]], momento: datetime
) -> dict[int, dict[str, float]] | None:
    """Lluvia por colonia; las colonias que caen en la misma celda de ~0.05 grados comparten consulta."""
    resultado = consultar_por_celda(centros, momento)
    if resultado is None:
        return None
    celdas, por_celda = resultado
    return {cid: dict(por_celda[c]) for cid, c in celdas.items()}


def guardar_historial(por_celda: dict[tuple[float, float], dict[str, float]], momento: datetime) -> None:
    """Guarda una fila por celda. Un fallo aquí no debe interrumpir el cálculo de riesgo."""
    from app.db import SessionLocal
    from app.historial.modelos import LecturaLluvia

    try:
        with SessionLocal() as db:
            db.add_all(
                LecturaLluvia(
                    momento=momento,
                    celda_lat=lat,
                    celda_lon=lon,
                    mm_1h=r.get("mm_1h"),
                    mm_3h=r.get("mm_3h"),
                    mm_24h=r.get("mm_24h"),
                    pronostico_3h=r.get("pronostico_3h"),
                    prob_3h=r.get("prob_3h"),
                    prob_6h=r.get("prob_6h"),
                )
                for (lat, lon), r in por_celda.items()
            )
            db.commit()
    except Exception:
        log.warning("No se pudo guardar el historial de lluvia", exc_info=True)


def ejecutar() -> None:
    """Tarea programada: actualizar lluvia y avisar para recalcular riesgo."""
    centros = centroides()
    if centros:
        momento = datetime.now(timezone.utc)
        resultado = consultar_por_celda(centros, momento)
        if resultado is None:
            return  # error de red: se conserva la última lectura
        celdas, por_celda = resultado
        estado.guardar_por_colonia({cid: dict(por_celda[c]) for cid, c in celdas.items()}, ahora())
        guardar_historial(por_celda, momento)
    else:
        lluvia = consultar()
        if lluvia is None:
            return
        estado.guardar(lluvia, ahora())
    eventos.publicar("weather.updated", estado.resumen())
