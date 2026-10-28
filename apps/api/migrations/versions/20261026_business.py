"""Institutions, accounts, residents and immutable prescription revisions.

Revision ID: 20261026_business
Revises: 20261026_foundation
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql as pg

revision = "20261026_business"
down_revision = "20261026_foundation"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "institutions",
        sa.Column("id", pg.UUID(), primary_key=True),
        sa.Column("name", sa.String(80), nullable=False),
        sa.Column("timezone", sa.String(64), nullable=False),
        sa.Column("bedtime_enabled", sa.Boolean(), nullable=False),
    )
    op.create_table(
        "accounts",
        sa.Column("id", pg.UUID(), primary_key=True),
        sa.Column("username", sa.String(64), nullable=False, unique=True),
        sa.Column("display_name", sa.String(80), nullable=False),
        sa.Column("password_hash", sa.String(256), nullable=False),
        sa.Column("role", sa.String(32), nullable=False),
        sa.Column("institution_id", pg.UUID(), sa.ForeignKey("institutions.id")),
        sa.Column("can_maintain", sa.Boolean(), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.CheckConstraint("revision > 0"),
        sa.CheckConstraint("role IN ('platform_admin', 'institution_admin', 'staff')"),
        sa.CheckConstraint("(role = 'platform_admin') = (institution_id IS NULL)"),
    )
    op.create_table(
        "account_sessions",
        sa.Column("token_hash", sa.String(64), primary_key=True),
        sa.Column("account_id", pg.UUID(), sa.ForeignKey("accounts.id"), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_table(
        "account_audit",
        sa.Column("id", pg.UUID(), primary_key=True),
        sa.Column("account_id", pg.UUID(), sa.ForeignKey("accounts.id"), nullable=False),
        sa.Column("actor_id", pg.UUID(), sa.ForeignKey("accounts.id"), nullable=False),
        sa.Column("action", sa.String(32), nullable=False),
        sa.Column("at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
    )
    op.create_table(
        "residents",
        sa.Column("id", pg.UUID(), primary_key=True),
        sa.Column("institution_id", pg.UUID(), sa.ForeignKey("institutions.id"), nullable=False),
        sa.Column("name", sa.String(30), nullable=False),
        sa.Column("bed", sa.String(40), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_by", pg.UUID(), sa.ForeignKey("accounts.id"), nullable=False),
        sa.CheckConstraint("revision > 0"),
    )
    op.create_index(
        "residents_bed_unique",
        "residents",
        ["institution_id", "bed"],
        unique=True,
        postgresql_where=sa.text("bed <> ''"),
    )
    op.create_index("residents_institution_id", "residents", ["institution_id", "id"])
    op.create_table(
        "resident_versions",
        sa.Column("resident_id", pg.UUID(), sa.ForeignKey("residents.id"), primary_key=True),
        sa.Column("revision", sa.Integer(), primary_key=True),
        sa.Column("data", pg.JSONB(), nullable=False),
        sa.Column("at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("actor_id", pg.UUID(), sa.ForeignKey("accounts.id"), nullable=False),
    )
    op.create_table(
        "medicines",
        sa.Column("id", pg.UUID(), primary_key=True),
        sa.Column("institution_id", pg.UUID(), sa.ForeignKey("institutions.id"), nullable=False),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("strength", sa.String(120), nullable=False),
        sa.Column("unit", sa.String(16), nullable=False),
    )
    op.create_table(
        "prescriptions",
        sa.Column("id", pg.UUID(), primary_key=True),
        sa.Column("resident_id", pg.UUID(), sa.ForeignKey("residents.id"), nullable=False),
        sa.Column("medicine_id", pg.UUID(), sa.ForeignKey("medicines.id"), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("data", pg.JSONB(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_by", pg.UUID(), sa.ForeignKey("accounts.id"), nullable=False),
        sa.CheckConstraint("revision > 0"),
    )
    op.create_index("prescriptions_resident_id", "prescriptions", ["resident_id"])
    op.create_table(
        "prescription_versions",
        sa.Column(
            "prescription_id", pg.UUID(), sa.ForeignKey("prescriptions.id"), primary_key=True
        ),
        sa.Column("revision", sa.Integer(), primary_key=True),
        sa.Column("medicine_id", pg.UUID(), sa.ForeignKey("medicines.id"), nullable=False),
        sa.Column("data", pg.JSONB(), nullable=False),
        sa.Column("at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("actor_id", pg.UUID(), sa.ForeignKey("accounts.id"), nullable=False),
    )


def downgrade():
    for table in (
        "prescription_versions",
        "prescriptions",
        "medicines",
        "resident_versions",
        "residents",
        "account_audit",
        "account_sessions",
        "accounts",
        "institutions",
    ):
        op.drop_table(table)
