"""Tablas iniciales: colonias, reportes, riesgo, alertas y dispositivos.

Revision ID: 0001
Revises:
Create Date: 2026-11-11
"""
import geoalchemy2
import sqlalchemy as sa
from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS postgis")

    op.create_table(
        "colonias",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("nombre", sa.String(200), nullable=False),
        sa.Column("municipio", sa.String(100), nullable=False),
        sa.Column("geom", geoalchemy2.Geometry("MULTIPOLYGON", srid=4326, spatial_index=False)),
        sa.Column("vulnerabilidad", sa.Float, nullable=False),
        sa.Column("vulnerabilidad_fuente", sa.String(20), nullable=False),
    )
    op.create_index("ix_colonias_nombre", "colonias", ["nombre"])
    op.create_index("idx_colonias_geom", "colonias", ["geom"], postgresql_using="gist")

    op.create_table(
        "reportes",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("categoria", sa.String(40), nullable=False),
        sa.Column("severidad", sa.Integer, nullable=False),
        sa.Column("descripcion", sa.Text),
        sa.Column("lat", sa.Float, nullable=False),
        sa.Column("lon", sa.Float, nullable=False),
        sa.Column("ubicacion", geoalchemy2.Geometry("POINT", srid=4326, spatial_index=False)),
        sa.Column("colonia_id", sa.Integer, sa.ForeignKey("colonias.id")),
        sa.Column("foto_url", sa.String(500)),
        sa.Column("dispositivo_id", sa.String(200)),
        sa.Column("origen", sa.String(20), nullable=False),
        sa.Column("estado", sa.String(20), nullable=False),
        sa.Column("creado_en", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expira_en", sa.DateTime(timezone=True), nullable=False),
    )
    for columna in ("categoria", "colonia_id", "estado", "expira_en"):
        op.create_index(f"ix_reportes_{columna}", "reportes", [columna])
    op.create_index("idx_reportes_ubicacion", "reportes", ["ubicacion"], postgresql_using="gist")

    op.create_table(
        "riesgo_colonias",
        sa.Column("colonia_id", sa.Integer, sa.ForeignKey("colonias.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("valor", sa.Float, nullable=False),
        sa.Column("nivel", sa.String(20), nullable=False),
        sa.Column("motivo", sa.String(40)),
        sa.Column("componentes", sa.JSON, nullable=False),
        sa.Column("actualizado_en", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ultima_alerta_en", sa.DateTime(timezone=True)),
    )

    op.create_table(
        "alertas",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("colonia_id", sa.Integer, sa.ForeignKey("colonias.id", ondelete="CASCADE"), nullable=False),
        sa.Column("tipo", sa.String(40), nullable=False),
        sa.Column("nivel", sa.String(20), nullable=False),
        sa.Column("motivo", sa.String(40)),
        sa.Column("texto", sa.Text, nullable=False),
        sa.Column("estado", sa.String(20), nullable=False),
        sa.Column("redactada_por", sa.String(20), nullable=False),
        sa.Column("simulada", sa.Boolean, nullable=False),
        sa.Column("creada_en", sa.DateTime(timezone=True), nullable=False),
        sa.Column("aprobada_en", sa.DateTime(timezone=True)),
    )
    op.create_index("ix_alertas_colonia_id", "alertas", ["colonia_id"])
    op.create_index("ix_alertas_estado", "alertas", ["estado"])

    op.create_table(
        "dispositivos",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("token", sa.String(500), nullable=False, unique=True),
        sa.Column("colonia_id", sa.Integer, sa.ForeignKey("colonias.id", ondelete="SET NULL")),
        sa.Column("plataforma", sa.String(20), nullable=False),
        sa.Column("actualizado_en", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_dispositivos_colonia_id", "dispositivos", ["colonia_id"])


def downgrade() -> None:
    for tabla in ("dispositivos", "alertas", "riesgo_colonias", "reportes", "colonias"):
        op.drop_table(tabla)
