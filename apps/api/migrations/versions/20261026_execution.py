"""Devices, labels, independent parameters, owned tasks and execution facts."""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision = "20261026_execution"
down_revision = "20261026_planning"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "devices",
        sa.Column("id", UUID(), primary_key=True),
        sa.Column("identity", sa.String(120), nullable=False, unique=True),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("configuration", JSONB(), nullable=False),
    )
    op.create_table(
        "resident_labels",
        sa.Column("uid", sa.String(64), primary_key=True),
        sa.Column("resident_id", UUID(), sa.ForeignKey("residents.id"), nullable=False),
        sa.Column("actor_id", UUID(), sa.ForeignKey("accounts.id"), nullable=False),
        sa.Column("at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_table(
        "prescription_parameters",
        sa.Column("prescription_id", UUID(), sa.ForeignKey("prescriptions.id"), primary_key=True),
        sa.Column("revision", sa.Integer(), primary_key=True),
        sa.Column("medicine_id", UUID(), nullable=False),
        sa.Column("turntable", sa.Float(), nullable=False),
        sa.Column("gate", sa.Float(), nullable=False),
        sa.Column("actor_id", UUID(), sa.ForeignKey("accounts.id"), nullable=False),
        sa.Column("at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_table(
        "dispensing_tasks",
        sa.Column("id", UUID(), primary_key=True),
        sa.Column("plan_id", UUID(), nullable=False, unique=True),
        sa.Column("resident_id", UUID(), sa.ForeignKey("residents.id"), nullable=False),
        sa.Column("device_id", UUID(), sa.ForeignKey("devices.id"), nullable=False),
        sa.Column("terminal_id", UUID(), nullable=False),
        sa.Column("owner_id", UUID(), sa.ForeignKey("accounts.id"), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.Column("state", sa.String(30), nullable=False),
        sa.Column("snapshot", JSONB(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    for name, column in (
        ("one_active_device", "device_id"),
        ("one_active_resident", "resident_id"),
    ):
        op.create_index(
            name, "dispensing_tasks", [column], unique=True, postgresql_where=sa.text("active")
        )
    op.create_table(
        "execution_events",
        sa.Column(
            "task_id",
            UUID(),
            sa.ForeignKey("dispensing_tasks.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("sequence", sa.Integer(), primary_key=True),
        sa.Column("data", JSONB(), nullable=False),
        sa.Column("received_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_table("deleted_tasks", sa.Column("id", UUID(), primary_key=True))


def downgrade():
    for table in (
        "deleted_tasks",
        "execution_events",
        "dispensing_tasks",
        "prescription_parameters",
        "resident_labels",
        "devices",
    ):
        op.drop_table(table)
