"""Colores y textos compartidos (los mismos del boceto en docs/diseno/)."""
from datetime import datetime, timezone

AZUL = "#1E5AA8"
NARANJA_SIM = "#F28C28"

NIVELES = {
    "bajo": {"color": "#2E9E5B", "suave": "#DFF3E7", "texto": "Bajo"},
    "medio": {"color": "#E0A800", "suave": "#FFF5D6", "texto": "Medio"},
    "alto": {"color": "#F07C1E", "suave": "#FFE9D6", "texto": "Alto"},
    "critico": {"color": "#D63B3B", "suave": "#FBE1E1", "texto": "Crítico"},
}

CATEGORIAS = {
    "inundacion": {"color": "#1E5AA8", "letra": "I", "texto": "Inundación", "grupo": "lluvia"},
    "encharcamiento": {"color": "#3A8DDE", "letra": "E", "texto": "Encharcamiento", "grupo": "lluvia"},
    "alcantarilla": {"color": "#6B4FA0", "letra": "A", "texto": "Alcantarilla tapada", "grupo": "lluvia"},
    "fuga": {"color": "#0FA3A3", "letra": "F", "texto": "Fuga de agua", "grupo": "agua"},
    "sin_agua": {"color": "#8A5A2B", "letra": "T", "texto": "Sin agua / tandeo", "grupo": "agua"},
}

MOTIVOS = {"lluvia": "lluvia", "reportes": "reportes ciudadanos", "vulnerabilidad": "vulnerabilidad"}

SEVERIDADES = {1: "baja", 2: "media", 3: "alta"}


def nivel(n: str | None) -> dict:
    return NIVELES.get(n or "bajo", NIVELES["bajo"])


def categoria(c: str) -> dict:
    return CATEGORIAS.get(c, {"color": "#5B6675", "letra": "?", "texto": c, "grupo": "otro"})


def hace(iso: str | None) -> str:
    if not iso:
        return ""
    momento = datetime.fromisoformat(iso.replace("Z", "+00:00"))
    segundos = int((datetime.now(timezone.utc) - momento).total_seconds())
    if segundos < 60:
        return f"hace {max(segundos, 1)} s"
    if segundos < 3600:
        return f"hace {segundos // 60} min"
    return f"hace {segundos // 3600} h"


def segundos_desde(iso: str) -> float:
    momento = datetime.fromisoformat(iso.replace("Z", "+00:00"))
    return (datetime.now(timezone.utc) - momento).total_seconds()
