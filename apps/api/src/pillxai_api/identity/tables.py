from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Table,
)
from sqlalchemy.dialects.postgresql import UUID

from ..database import metadata

accounts = Table(
    "accounts",
    metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("username", String(64), nullable=False, unique=True),
    Column("display_name", String(80), nullable=False),
    Column("password_hash", String(256), nullable=False),
    Column("role", String(32), nullable=False),
    Column("can_maintain", Boolean, nullable=False),
    Column("active", Boolean, nullable=False),
    Column("revision", Integer, nullable=False),
    CheckConstraint("revision > 0"),
    CheckConstraint("role IN ('admin', 'staff')"),
)
sessions = Table(
    "account_sessions",
    metadata,
    Column("token_hash", String(64), primary_key=True),
    Column("account_id", UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False),
    Column("expires_at", DateTime(timezone=True), nullable=False),
)
account_audit = Table(
    "account_audit",
    metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("account_id", UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False),
    Column("actor_id", UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False),
    Column("action", String(32), nullable=False),
    Column("at", DateTime(timezone=True), nullable=False),
    Column("revision", Integer, nullable=False),
)
