"""Auditoría de entregas push de alertas.

Revision ID: 0004
Revises: 0003
Create Date: 2026-11-12
"""
import sqlalchemy as sa
from alembic import op

revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "entregas_alerta",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("alerta_id", sa.Integer, sa.ForeignKey("alertas.id", ondelete="CASCADE"), nullable=False),
        sa.Column("dispositivo_id", sa.Integer, sa.ForeignKey("dispositivos.id", ondelete="SET NULL")),
        sa.Column("estado", sa.String(20), nullable=False),
        sa.Column("error", sa.Text),
        sa.Column("enviada_en", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_entregas_alerta_alerta_id", "entregas_alerta", ["alerta_id"])


def downgrade() -> None:
    op.drop_table("entregas_alerta")
