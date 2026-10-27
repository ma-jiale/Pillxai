"""Independent resident barcode identity, preserving internal UUID references."""

import sqlalchemy as sa
from alembic import op

revision = "20261027_resident_barcode"
down_revision = "20261027_parameter_learning"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        "residents", sa.Column("barcode", sa.String(128), nullable=False, server_default="")
    )
    op.create_index(
        "residents_barcode_unique",
        "residents",
        ["barcode"],
        unique=True,
        postgresql_where=sa.text("barcode <> ''"),
    )


def downgrade():
    op.drop_index("residents_barcode_unique", table_name="residents")
    op.drop_column("residents", "barcode")
