"""Configuración de pruebas.

Las pruebas de flujo usan una base PostgreSQL + PostGIS SEPARADA (se borra en cada corrida):
TEST_DATABASE_URL, o la de DATABASE_URL con el nombre cambiado a "<base>_test".
Se crea sola si no existe. Si no hay servidor de base de datos, esas pruebas se saltan.
"""
import os
from pathlib import Path

_principal = os.environ.get("DATABASE_URL", "postgresql+psycopg://agua:agua@localhost:5432/agua_lluvia")
_servidor, _nombre = _principal.rsplit("/", 1)
URL_PRUEBAS = os.environ.get("TEST_DATABASE_URL", f"{_servidor}/{_nombre}_test")
# Nunca correr pruebas contra la base principal
os.environ["DATABASE_URL"] = URL_PRUEBAS
os.environ["DATA_DIR"] = str(Path(__file__).parent / "datos")
os.environ["METEO_ACTIVA"] = "false"
os.environ["CLAVE_UNICA"] = "clave-de-prueba"

import pytest  # noqa: E402
from sqlalchemy import text  # noqa: E402

CLAVE = {"X-Clave": "clave-de-prueba"}


@pytest.fixture(scope="session")
def base_de_datos():
    from sqlalchemy import create_engine

    from app import modelos  # noqa: F401
    from app.db import Base, engine

    servidor, nombre = URL_PRUEBAS.rsplit("/", 1)
    try:
        admin = create_engine(f"{servidor}/postgres", isolation_level="AUTOCOMMIT")
        with admin.connect() as conexion:
            existe = conexion.scalar(text("SELECT 1 FROM pg_database WHERE datname = :n"), {"n": nombre})
            if not existe:
                conexion.execute(text(f'CREATE DATABASE "{nombre}"'))
        admin.dispose()
        with engine.begin() as conexion:
            conexion.execute(text("CREATE EXTENSION IF NOT EXISTS postgis"))
    except Exception as error:
        pytest.skip(f"No hay base de datos de prueba: {error.__class__.__name__}")
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    yield engine
    Base.metadata.drop_all(engine)


@pytest.fixture
def cliente(base_de_datos):
    from fastapi.testclient import TestClient

    from app.main import app

    with TestClient(app) as c:
        respuesta = c.post("/admin/seed", headers=CLAVE)
        assert respuesta.status_code == 200, respuesta.text
        yield c
