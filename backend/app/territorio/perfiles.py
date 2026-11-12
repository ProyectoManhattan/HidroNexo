"""Lectura ligera de los perfiles territoriales generados en ``data/perfiles``.

Los archivos son suficientes para el MVP; no se duplican en PostgreSQL hasta que
exista un flujo de actualización o edición que justifique nuevas tablas.
"""
import csv
import re
from functools import lru_cache
from pathlib import Path

from app.config import settings

CAMPOS_NUMERICOS = (
    "elevacion_mediana_m",
    "elevacion_relativa_m",
    "pendiente_media_grados",
    "hand_mediana_m",
    "distancia_cuerpo_agua_m",
    "distancia_cauce_mayor_m",
    "acumulacion_flujo_max_km2",
    "eventos_inundacion_registrados",
    "lluvia_anual_media_mm",
    "lluvia_24h_retorno_2a_mm",
    "lluvia_24h_retorno_10a_mm",
    "lluvia_24h_retorno_100a_mm",
    "indice_susceptibilidad_preliminar",
    "n_variables_faltantes",
)


def _numero(valor: str | None) -> float | None:
    if valor in (None, ""):
        return None
    try:
        return float(valor)
    except ValueError:
        return None


@lru_cache(maxsize=4)
def _cargar(archivo: str) -> dict[str, dict]:
    ruta = Path(archivo)
    if not ruta.exists():
        return {}
    with ruta.open(encoding="utf-8-sig", newline="") as entrada:
        filas = {}
        for fila in csv.DictReader(entrada):
            perfil = {campo: _numero(fila.get(campo)) for campo in CAMPOS_NUMERICOS}
            perfil.update(
                {
                    "codigo_postal": fila["id_poligono"],
                    "categoria_relativa": fila.get("categoria_relativa") or None,
                    "tipo_cuerpo_agua": fila.get("tipo_cuerpo_agua") or None,
                    "cobertura_meteorologica": fila.get("cobertura_meteorologica") or None,
                    "fuente": "perfil_territorial_preliminar",
                    "advertencia": "Índice relativo no validado; no es probabilidad de inundación.",
                }
            )
            filas[fila["id_poligono"]] = perfil
        return filas


def todos() -> dict[str, dict]:
    return _cargar(str(settings.data_dir / "perfiles" / "resumen_territorial.csv"))


def codigo_postal(nombre: str) -> str | None:
    coincidencia = re.search(r"\b\d{5}\b", nombre)
    return coincidencia.group(0) if coincidencia else None


def perfil_para(nombre_o_cp: str) -> dict | None:
    cp = nombre_o_cp if nombre_o_cp.isdigit() else codigo_postal(nombre_o_cp)
    return todos().get(cp) if cp else None


def susceptibilidad(perfil: dict | None, respaldo: float) -> float:
    indice = perfil.get("indice_susceptibilidad_preliminar") if perfil else None
    return max(0.0, min(1.0, indice / 100)) if indice is not None else respaldo
