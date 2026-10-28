"""Optional resident profile avatar; existing records keep their placeholder."""

import sqlalchemy as sa
from alembic import op

revision = "20261027_resident_avatar"
down_revision = "20261027_barcode_sequence"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("residents", sa.Column("avatar", sa.Text(), nullable=False, server_default=""))


def downgrade():
    op.drop_column("residents", "avatar")
