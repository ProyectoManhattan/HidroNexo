from alembic import context
from sqlalchemy import create_engine, pool

import app.modelos  # noqa: F401  (registra todos los modelos)
from app.config import settings
from app.db import Base

target_metadata = Base.metadata

# Tablas internas de PostGIS que autogenerate debe ignorar
IGNORAR = {"spatial_ref_sys"}


def incluir(objeto, nombre, tipo, reflejado, comparado):
    return not (tipo == "table" and nombre in IGNORAR)


def run_migrations_offline() -> None:
    context.configure(url=settings.database_url, target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    motor = create_engine(settings.database_url, poolclass=pool.NullPool)
    with motor.connect() as conexion:
        context.configure(connection=conexion, target_metadata=target_metadata, include_object=incluir)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
