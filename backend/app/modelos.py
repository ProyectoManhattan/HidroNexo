"""Importa todos los modelos para que Alembic y SQLAlchemy los conozcan."""
from app.alertas.modelos import Alerta  # noqa: F401
from app.colonias.modelos import Colonia  # noqa: F401
from app.dispositivos.modelos import Dispositivo  # noqa: F401
from app.reportes.modelos import Reporte  # noqa: F401
from app.riesgo.modelos import RiesgoColonia  # noqa: F401
