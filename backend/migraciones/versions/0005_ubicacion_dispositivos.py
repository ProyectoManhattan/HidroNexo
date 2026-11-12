"""Ubicación de los dispositivos para enviar alertas por zona.

Revision ID: 0005
Revises: 0004
Create Date: 2026-11-12
"""
import geoalchemy2
import sqlalchemy as sa
from alembic import op

revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "dispositivos",
        sa.Column("ubicacion", geoalchemy2.Geometry("POINT", srid=4326, spatial_index=False)),
    )
    op.add_column("dispositivos", sa.Column("ubicacion_actualizada_en", sa.DateTime(timezone=True)))
    op.create_index("idx_dispositivos_ubicacion", "dispositivos", ["ubicacion"], postgresql_using="gist")


def downgrade() -> None:
    op.drop_index("idx_dispositivos_ubicacion", table_name="dispositivos")
    op.drop_column("dispositivos", "ubicacion_actualizada_en")
    op.drop_column("dispositivos", "ubicacion")
