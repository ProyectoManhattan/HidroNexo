"""Llave de idempotencia de reportes enviados desde la app (reintentos sin duplicar).

Revision ID: 0006
Revises: 0005
Create Date: 2026-11-12
"""
import sqlalchemy as sa
from alembic import op

revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("reportes", sa.Column("cliente_id", sa.String(64)))
    op.create_unique_constraint("uq_reportes_cliente_id", "reportes", ["cliente_id"])


def downgrade() -> None:
    op.drop_constraint("uq_reportes_cliente_id", "reportes", type_="unique")
    op.drop_column("reportes", "cliente_id")
