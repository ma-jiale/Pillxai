"""Versioned application settings and immutable plan previews."""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql as pg

revision = "20261026_planning"
down_revision = "20261026_single_workspace"
branch_labels = None
depends_on = None


def upgrade():
    for name, kind, default in (
        ("preparation_days", sa.Integer(), "7"),
        ("split_meals", sa.Boolean(), "true"),
        ("start_tomorrow", sa.Boolean(), "false"),
        ("revision", sa.Integer(), "1"),
    ):
        op.add_column(
            "app_settings", sa.Column(name, kind, nullable=False, server_default=sa.text(default))
        )
        op.alter_column("app_settings", name, server_default=None)
    op.create_check_constraint("settings_days", "app_settings", "preparation_days BETWEEN 1 AND 7")
    op.create_check_constraint("settings_revision", "app_settings", "revision > 0")
    op.create_table(
        "settings_versions",
        sa.Column("revision", sa.Integer(), primary_key=True),
        sa.Column("data", pg.JSONB(), nullable=False),
        sa.Column("at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("actor_id", pg.UUID(), sa.ForeignKey("accounts.id")),
    )
    op.execute(
        "INSERT INTO settings_versions "
        "SELECT revision, to_jsonb(s) - 'id', now(), NULL FROM app_settings s"
    )
    op.create_table(
        "plan_previews",
        sa.Column("id", pg.UUID(), primary_key=True),
        sa.Column("resident_id", pg.UUID(), sa.ForeignKey("residents.id"), nullable=False),
        sa.Column("snapshot", pg.JSONB(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_by", pg.UUID(), sa.ForeignKey("accounts.id"), nullable=False),
    )


def downgrade():
    op.drop_table("plan_previews")
    op.drop_table("settings_versions")
    op.drop_constraint("settings_days", "app_settings")
    op.drop_constraint("settings_revision", "app_settings")
    for name in ("revision", "start_tomorrow", "split_meals", "preparation_days"):
        op.drop_column("app_settings", name)
