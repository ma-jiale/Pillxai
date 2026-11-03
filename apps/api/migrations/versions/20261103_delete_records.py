"""Retain deleted profiles and prescriptions for historical task references."""
import sqlalchemy as sa
from alembic import op

revision = "20261103_delete_records"
down_revision = "20261103_box_slot_order"
branch_labels = None
depends_on = None


def upgrade():
    for name in ("residents", "prescriptions"):
        op.add_column(name, sa.Column("deleted_at", sa.DateTime(timezone=True)))
    op.drop_index("residents_bed_unique", table_name="residents")
    op.create_index("residents_bed_unique", "residents", ["bed"], unique=True,
                    postgresql_where=sa.text("bed <> '' AND deleted_at IS NULL"))


def downgrade():
    op.drop_index("residents_bed_unique", table_name="residents")
    op.create_index("residents_bed_unique", "residents", ["bed"], unique=True,
                    postgresql_where=sa.text("bed <> ''"))
    for name in ("prescriptions", "residents"):
        op.drop_column(name, "deleted_at")
