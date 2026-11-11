import json

from app.config import settings


def carpeta():
    return settings.data_dir / "guias"


def listar_guias() -> dict[str, dict]:
    if not carpeta().exists():
        return {}
    return {a.stem: json.loads(a.read_text(encoding="utf-8")) for a in sorted(carpeta().glob("*.json"))}


def obtener_guia(tipo: str) -> dict | None:
    archivo = carpeta() / f"{tipo}.json"
    if not archivo.exists():
        return None
    return json.loads(archivo.read_text(encoding="utf-8"))
