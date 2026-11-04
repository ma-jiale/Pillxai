"""Store the date direction with the shared pillbox layout."""

import sqlalchemy as sa
from alembic import op

revision = "20261104_box_direction"
down_revision = "20261103_delete_records"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("app_settings", sa.Column(
        "box_reverse_columns", sa.Boolean(), nullable=False, server_default=sa.false(),
    ))


def downgrade():
    op.drop_column("app_settings", "box_reverse_columns")
