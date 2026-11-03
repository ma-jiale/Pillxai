"""Shared physical pillbox slot order, independent of machine calibration."""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

revision = "20261103_box_slot_order"
down_revision = "20261027_resident_avatar"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("app_settings", sa.Column(
        "box_slot_order", JSONB, nullable=False, server_default="[0,1,2,3]",
    ))


def downgrade():
    op.drop_column("app_settings", "box_slot_order")
