from sqlalchemy import (
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Table,
    Text,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID

from ..database import metadata

residents = Table(
    "residents",
    metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("revision", Integer, nullable=False),
    Column("name", String(30), nullable=False),
    Column("bed", String(40), nullable=False),
    Column("barcode", String(128), nullable=False, server_default=""),
    Column("avatar", Text(), nullable=False, server_default=""),
    Column("updated_at", DateTime(timezone=True), nullable=False),
    Column("updated_by", UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False),
    CheckConstraint("revision > 0"),
    Index(
        "residents_barcode_unique", "barcode", unique=True, postgresql_where=text("barcode <> ''")
    ),
    Index(
        "residents_bed_unique",
        "bed",
        unique=True,
        postgresql_where=text("bed <> ''"),
    ),
)
resident_versions = Table(
    "resident_versions",
    metadata,
    Column("resident_id", UUID(as_uuid=True), ForeignKey("residents.id"), primary_key=True),
    Column("revision", Integer, primary_key=True),
    Column("data", JSONB, nullable=False),
    Column("at", DateTime(timezone=True), nullable=False),
    Column("actor_id", UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False),
)
