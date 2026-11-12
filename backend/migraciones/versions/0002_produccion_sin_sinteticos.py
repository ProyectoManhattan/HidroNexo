"""Prepara el esquema para registros reales y elimina datos sintéticos conocidos.

Revision ID: 0002
Revises: 0001
Create Date: 2026-11-12
"""
import sqlalchemy as sa
from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None

CATEGORIAS = "'inundacion', 'encharcamiento', 'alcantarilla', 'fuga', 'sin_agua'"


def upgrade() -> None:
    # Esta limpieza conserva las colonias: son el catálogo geográfico requerido
    # para asignar cada reporte ciudadano y calcular su riesgo.
    op.execute("DELETE FROM alertas WHERE simulada IS TRUE")
    op.execute("DELETE FROM reportes WHERE origen = 'seed'")
    op.execute("DELETE FROM riesgo_colonias")

    op.alter_column("colonias", "geom", nullable=False)
    op.alter_column("reportes", "ubicacion", nullable=False)

    op.create_check_constraint("ck_colonias_vulnerabilidad", "colonias", "vulnerabilidad BETWEEN 0 AND 1")
    op.create_check_constraint("ck_reportes_categoria", "reportes", f"categoria IN ({CATEGORIAS})")
    op.create_check_constraint("ck_reportes_severidad", "reportes", "severidad BETWEEN 1 AND 3")
    op.create_check_constraint("ck_reportes_lat", "reportes", "lat BETWEEN -90 AND 90")
    op.create_check_constraint("ck_reportes_lon", "reportes", "lon BETWEEN -180 AND 180")
    # `seed` permanece en el contrato para demos explícitas, pero no se genera
    # automáticamente y las filas existentes se eliminan arriba.
    op.create_check_constraint("ck_reportes_origen", "reportes", "origen IN ('app', 'panel', 'seed')")
    op.create_check_constraint("ck_reportes_estado", "reportes", "estado IN ('activo', 'resuelto')")
    op.create_check_constraint(
        "ck_reportes_descripcion_longitud", "reportes", "descripcion IS NULL OR length(descripcion) <= 500"
    )
    op.create_check_constraint("ck_alertas_tipo", "alertas", f"tipo IN ({CATEGORIAS})")
    op.create_check_constraint("ck_alertas_nivel", "alertas", "nivel IN ('bajo', 'medio', 'alto', 'critico')")
    op.create_check_constraint("ck_alertas_estado", "alertas", "estado IN ('propuesta', 'aprobada', 'descartada')")
    op.create_check_constraint(
        "ck_alertas_redactada_por", "alertas", "redactada_por IN ('plantilla', 'llm', 'manual')"
    )
    op.create_check_constraint("ck_alertas_texto_longitud", "alertas", "length(texto) BETWEEN 10 AND 1000")
    op.create_check_constraint("ck_dispositivos_plataforma", "dispositivos", "plataforma IN ('android', 'ios', 'web')")
    op.create_index("ix_reportes_activos_recientes", "reportes", ["estado", "expira_en", "creado_en"])


def downgrade() -> None:
    op.drop_index("ix_reportes_activos_recientes", table_name="reportes")
    for tabla, nombre in (
        ("dispositivos", "ck_dispositivos_plataforma"),
        ("alertas", "ck_alertas_texto_longitud"),
        ("alertas", "ck_alertas_redactada_por"),
        ("alertas", "ck_alertas_estado"),
        ("alertas", "ck_alertas_nivel"),
        ("alertas", "ck_alertas_tipo"),
        ("reportes", "ck_reportes_descripcion_longitud"),
        ("reportes", "ck_reportes_estado"),
        ("reportes", "ck_reportes_origen"),
        ("reportes", "ck_reportes_lon"),
        ("reportes", "ck_reportes_lat"),
        ("reportes", "ck_reportes_severidad"),
        ("reportes", "ck_reportes_categoria"),
        ("colonias", "ck_colonias_vulnerabilidad"),
    ):
        op.drop_constraint(nombre, tabla, type_="check")
    op.alter_column("reportes", "ubicacion", nullable=True)
    op.alter_column("colonias", "geom", nullable=True)
