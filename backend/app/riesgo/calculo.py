"""Fórmula del riesgo. Funciones PURAS (sin base de datos): fáciles de probar.

riesgo = w1 · lluvia + w2 · reportes + w3 · vulnerabilidad

Cada componente llega normalizado entre 0 y 1.
TODO (fase 2): calibrar PESOS, UMBRALES y SATURACION_REPORTES con datos de ejemplo.
"""
from dataclasses import dataclass

from app.catalogos import NIVELES_RIESGO

PESOS = {"lluvia": 0.4, "reportes": 0.4, "vulnerabilidad": 0.2}

# Valor mínimo para entrar a cada nivel
UMBRALES = {"bajo": 0.0, "medio": 0.25, "alto": 0.5, "critico": 0.75}

# Para BAJAR de nivel, el riesgo debe quedar este margen por debajo del umbral
HISTERESIS = 0.05

# Suma de severidades de reportes activos que se considera "saturación" (componente = 1)
SATURACION_REPORTES = 10.0

# Lluvia (mm) que se considera saturación en cada ventana
SATURACION_LLUVIA = {"mm_1h": 20.0, "mm_3h": 40.0, "mm_24h": 80.0, "pronostico_3h": 40.0}

# Categorías cuya gravedad depende de la lluvia. Las demás (fuga, sin_agua, categorías
# nuevas) NO se amplifican ni se penalizan: factor 1.0, para no causar falsos negativos.
CATEGORIAS_LLUVIA = {"inundacion", "encharcamiento", "alcantarilla"}

# Amplificación máxima (+50 %) de la severidad de un reporte con lluvia local en saturación
AMPLIFICACION_LLUVIA_MAX = 0.5

# Niveles que generan borrador de alerta
NIVELES_ALERTA = {"alto", "critico"}


@dataclass
class Resultado:
    valor: float
    nivel: str
    motivo: str
    componentes: dict[str, float]


def limitar(x: float) -> float:
    return max(0.0, min(1.0, x))


def pronostico_efectivo(lluvia: dict[str, float]) -> float:
    """mm pronosticados en 3 h ponderados por su probabilidad: 20 mm al 30 % cuentan como 6 mm.

    Sin dato de probabilidad (prob_3h) se toma el pronóstico completo, como antes.
    """
    mm = lluvia.get("pronostico_3h", 0.0)
    prob = lluvia.get("prob_3h")
    if prob is None:
        return mm
    return mm * limitar(prob / 100)


def componente_lluvia(lluvia: dict[str, float], retorno_2a_24h_mm: float | None = None) -> float:
    """Toma la ventana más grave y, si existe, usa la climatología local para 24 h.

    El retorno de dos años sustituye el umbral genérico de 80 mm/24 h. No se
    interpreta como probabilidad: únicamente normaliza la amenaza en el clima local.
    """
    if not lluvia:
        return 0.0
    ventanas = {**lluvia, "pronostico_3h": pronostico_efectivo(lluvia)}
    topes = dict(SATURACION_LLUVIA)
    if retorno_2a_24h_mm is not None and retorno_2a_24h_mm > 0:
        topes["mm_24h"] = retorno_2a_24h_mm
    return limitar(max(ventanas.get(k, 0.0) / tope for k, tope in topes.items()))


def resumen_pronostico(lluvia: dict[str, float]) -> dict:
    """Lo que el panel y la app muestran del pronóstico de una zona."""
    return {
        "mm_3h": round(lluvia.get("pronostico_3h", 0.0), 2),
        "prob_3h": lluvia.get("prob_3h"),
        "prob_6h": lluvia.get("prob_6h"),
        "mm_3h_efectivos": round(pronostico_efectivo(lluvia), 2),
    }


def severidad_efectiva(severidad: int, categoria: str, lluvia: dict[str, float]) -> float:
    """Severidad ajustada por la lluvia local: severidad × (1 + 0.5 · componente_lluvia).

    Solo categorías de CATEGORIAS_LLUVIA se amplifican (factor entre 1.0 y 1.5);
    el resto conserva su severidad tal cual. Nunca baja de la severidad original.
    """
    if categoria not in CATEGORIAS_LLUVIA:
        return float(severidad)
    return severidad * (1.0 + AMPLIFICACION_LLUVIA_MAX * componente_lluvia(lluvia))


def componente_reportes(suma_severidades: float) -> float:
    return limitar(suma_severidades / SATURACION_REPORTES)


def nivel_para(valor: float, nivel_anterior: str | None = None) -> str:
    nuevo = max((n for n, minimo in UMBRALES.items() if valor >= minimo), key=NIVELES_RIESGO.index)
    if nivel_anterior is None or NIVELES_RIESGO.index(nuevo) >= NIVELES_RIESGO.index(nivel_anterior):
        return nuevo
    # Va a bajar: solo baja si quedó claramente por debajo del umbral del nivel anterior
    if valor >= UMBRALES[nivel_anterior] - HISTERESIS:
        return nivel_anterior
    return nuevo


def calcular(lluvia: float, reportes: float, vulnerabilidad: float, nivel_anterior: str | None = None) -> Resultado:
    componentes = {
        "lluvia": limitar(lluvia),
        "reportes": limitar(reportes),
        "vulnerabilidad": limitar(vulnerabilidad),
    }
    aportes = {k: PESOS[k] * v for k, v in componentes.items()}
    valor = round(sum(aportes.values()), 4)
    return Resultado(
        valor=valor,
        nivel=nivel_para(valor, nivel_anterior),
        motivo=max(aportes, key=aportes.get),
        componentes={k: round(v, 4) for k, v in componentes.items()},
    )


def sube_a_alerta(nivel_anterior: str | None, nivel_nuevo: str) -> bool:
    """True si la colonia acaba de cruzar hacia un nivel que amerita alerta."""
    if nivel_nuevo not in NIVELES_ALERTA:
        return False
    anterior = NIVELES_RIESGO.index(nivel_anterior) if nivel_anterior else 0
    return NIVELES_RIESGO.index(nivel_nuevo) > anterior
