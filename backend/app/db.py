from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.config import settings


class Base(DeclarativeBase):
    pass


opciones_motor = {"pool_pre_ping": True}
if settings.database_url.startswith("postgresql"):
    # Supabase instala PostGIS en `extensions`; Docker lo instala en `public`.
    # Incluir ambos esquemas hace que el mismo código funcione en los dos.
    opciones_motor["connect_args"] = {"options": "-csearch_path=public,extensions"}

engine = create_engine(settings.database_url, **opciones_motor)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def get_db():
    """Dependencia de FastAPI: una sesión por petición."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
