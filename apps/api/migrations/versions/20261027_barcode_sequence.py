"""Server-assigned six-digit barcodes; existing resident codes stay unchanged."""

import sqlalchemy as sa
from alembic import op

revision = "20261027_barcode_sequence"
down_revision = "20261027_resident_barcode"
branch_labels = None
depends_on = None


def upgrade():
    sa.Sequence("resident_barcode_number", start=1, maxvalue=999999, cycle=False).create(
        op.get_bind()
    )


def downgrade():
    sa.Sequence("resident_barcode_number").drop(op.get_bind())
