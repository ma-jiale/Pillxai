"""Per-prescription learning policy and provenance; no old learning data import."""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision = "20261027_parameter_learning"
down_revision = "20261026_parameter_origin"
branch_labels = None
depends_on = None


def upgrade():
    for name in ("learning_enabled", "has_values"):
        op.add_column(
            "prescription_parameters",
            sa.Column(name, sa.Boolean(), nullable=False, server_default=sa.true()),
        )
    op.add_column("prescription_parameters", sa.Column("source_task_id", UUID(as_uuid=True)))
    op.add_column("prescription_parameters", sa.Column("source_batch", sa.Integer()))
    # Existing parameter rows have no attested shape: retain as history, not new defaults.
    op.add_column("prescription_parameters", sa.Column("feed_form", sa.String(20)))


def downgrade():
    for name in ("feed_form", "source_batch", "source_task_id", "has_values", "learning_enabled"):
        op.drop_column("prescription_parameters", name)
