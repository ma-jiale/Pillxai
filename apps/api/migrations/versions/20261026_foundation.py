"""Foundation only: development contract persistence, no business table shortcuts."""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "20261026_foundation"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "contract_samples",
        sa.Column("sample_id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("payload", postgresql.JSONB(), nullable=False),
        sa.CheckConstraint("revision > 0", name="contract_sample_revision_positive"),
    )


def downgrade():
    op.drop_table("contract_samples")
