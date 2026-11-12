from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

RAIZ_REPO = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+psycopg://agua:agua@localhost:5432/agua_lluvia"
    clave_unica: str = "cambiar-esta-clave"
    llm_api_key: str = ""
    data_dir: Path = RAIZ_REPO / "data"

    # Producción: las colonias son datos geográficos de referencia; los reportes
    # ciudadanos llegan exclusivamente desde los clientes.
    auto_load_reference_data: bool = True
    # Solo para demostraciones locales. Nunca debe activarse en producción.
    auto_seed: bool = False

    # Reportes
    reporte_horas_expiracion: int = 6

    # Alertas: tiempo mínimo entre dos alertas de la misma colonia
    alerta_enfriamiento_min: int = 60

    # Meteorología (Open-Meteo)
    meteo_activa: bool = True
    meteo_intervalo_min: int = 15
    avisos_oficiales_activos: bool = True
    avisos_oficiales_intervalo_min: int = 10
    # Puntos de consulta de respaldo (lat, lon); la ingesta normal usa el centroide de cada colonia
    meteo_puntos: list[tuple[float, float]] = [
        (19.1738, -96.1342),  # Centro
        (19.1950, -96.1530),  # Norte
        (19.1450, -96.1050),  # Boca del Río
        (19.1200, -96.1400),  # Sur
    ]


settings = Settings()
