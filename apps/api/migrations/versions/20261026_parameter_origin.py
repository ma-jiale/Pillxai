"""Keep simulator parameter values out of hardware tasks."""

import sqlalchemy as sa
from alembic import op

revision = "20261026_parameter_origin"
down_revision = "20261026_execution"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        "prescription_parameters",
        sa.Column("simulation_only", sa.Boolean(), nullable=False, server_default=sa.true()),
    )
    op.alter_column("prescription_parameters", "simulation_only", server_default=None)


def downgrade():
    op.drop_column("prescription_parameters", "simulation_only")
