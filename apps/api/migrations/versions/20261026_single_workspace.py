"""Remove tenant scopes while retaining business identities and revision history.

The preceding migration is retained only to upgrade existing development databases.
This migration refuses ambiguous merges; it never chooses an institution or renames beds.
"""

import sqlalchemy as sa
from alembic import op

revision = "20261026_single_workspace"
down_revision = "20261026_business"
branch_labels = None
depends_on = None


def upgrade():
    connection = op.get_bind()
    rows = connection.execute(sa.text("SELECT timezone, bedtime_enabled FROM institutions")).all()
    if len(rows) > 1:
        raise RuntimeError("Multiple data scopes exist; export and separate them before upgrading.")
    timezone, bedtime = rows[0] if rows else ("Asia/Shanghai", False)
    op.create_table(
        "app_settings",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("timezone", sa.String(64), nullable=False),
        sa.Column("bedtime_enabled", sa.Boolean(), nullable=False),
        sa.CheckConstraint("id = 1"),
    )
    connection.execute(
        sa.text("INSERT INTO app_settings VALUES (1, :timezone, :bedtime)"),
        dict(timezone=timezone, bedtime=bedtime),
    )
    # Discover the original unnamed constraints rather than assume server-generated names.
    for check in sa.inspect(connection).get_check_constraints("accounts"):
        if "role" in check["sqltext"]:
            op.drop_constraint(check["name"], "accounts", type_="check")
    connection.execute(sa.text("UPDATE accounts SET role = 'admin' WHERE role <> 'staff'"))
    op.create_check_constraint("accounts_role_check", "accounts", "role IN ('admin', 'staff')")
    # Existing tokens are invalid after changing the authorization model.
    connection.execute(sa.text("DELETE FROM account_sessions"))
    op.drop_index("residents_bed_unique", table_name="residents")
    op.drop_index("residents_institution_id", table_name="residents")
    for table in ("accounts", "residents", "medicines"):
        op.drop_column(table, "institution_id")
    op.drop_table("institutions")
    op.create_index(
        "residents_bed_unique", "residents", ["bed"], unique=True,
        postgresql_where=sa.text("bed <> ''"),
    )


def downgrade():
    raise RuntimeError("Restore a database backup to return to the removed authorization model.")
