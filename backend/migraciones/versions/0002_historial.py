"""Historial de lluvia y de cambios de nivel de riesgo.

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


def upgrade() -> None:
    op.create_table(
        "historial_lluvia",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("momento", sa.DateTime(timezone=True), nullable=False),
        sa.Column("celda_lat", sa.Float, nullable=False),
        sa.Column("celda_lon", sa.Float, nullable=False),
        sa.Column("mm_1h", sa.Float),
        sa.Column("mm_3h", sa.Float),
        sa.Column("mm_24h", sa.Float),
        sa.Column("pronostico_3h", sa.Float),
        sa.Column("prob_3h", sa.Float),
        sa.Column("prob_6h", sa.Float),
    )
    op.create_index("ix_historial_lluvia_momento", "historial_lluvia", ["momento"])

    op.create_table(
        "historial_riesgo",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("momento", sa.DateTime(timezone=True), nullable=False),
        sa.Column("zona", sa.String(200), nullable=False),
        sa.Column("municipio", sa.String(100)),
        sa.Column("nivel_anterior", sa.String(20)),
        sa.Column("nivel", sa.String(20), nullable=False),
        sa.Column("valor", sa.Float, nullable=False),
        sa.Column("motivo", sa.String(40)),
        sa.Column("componentes", sa.JSON, nullable=False),
        sa.Column("simulacion", sa.Boolean, nullable=False, server_default=sa.false()),
    )
    op.create_index("ix_historial_riesgo_momento", "historial_riesgo", ["momento"])
    op.create_index("ix_historial_riesgo_zona", "historial_riesgo", ["zona"])


def downgrade() -> None:
    op.drop_table("historial_riesgo")
    op.drop_table("historial_lluvia")
