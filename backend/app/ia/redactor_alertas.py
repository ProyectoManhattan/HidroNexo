import logging
from pathlib import Path

from app.config import settings

log = logging.getLogger(__name__)

AQUI = Path(__file__).parent
PLANTILLAS = AQUI / "plantillas"
PROMPTS = AQUI / "prompts"


def desde_plantilla(colonia: str, nivel: str, motivo: str, tipo: str) -> str:
    archivo = PLANTILLAS / f"{tipo}.txt"
    if not archivo.exists():
        archivo = PLANTILLAS / "general.txt"
    return archivo.read_text(encoding="utf-8").strip().format(colonia=colonia, nivel=nivel, motivo=motivo)


def desde_llm(colonia: str, nivel: str, motivo: str, tipo: str) -> str:
    """TODO (Persona C): llamar al LLM con prompts/borrador_alerta.txt.

    Debe devolver un texto corto. Si algo falla, lanzar excepción: se usa la plantilla.
    """
    raise NotImplementedError


def redactar_alerta(colonia: str, nivel: str, motivo: str, tipo: str = "inundacion") -> tuple[str, str]:
    if settings.llm_api_key:
        try:
            return desde_llm(colonia, nivel, motivo, tipo), "llm"
        except NotImplementedError:
            pass
        except Exception:
            log.exception("Falló el LLM; se usa plantilla")
    return desde_plantilla(colonia, nivel, motivo, tipo), "plantilla"
