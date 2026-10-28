from sqlalchemy import CheckConstraint, Column, DateTime, ForeignKey, Index, Integer, String, Table
from sqlalchemy.dialects.postgresql import JSONB, UUID

from ..database import metadata

medicines = Table(
    "medicines",
    metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("name", String(120), nullable=False),
    Column("strength", String(120), nullable=False),
    Column("unit", String(16), nullable=False),
)
prescriptions = Table(
    "prescriptions",
    metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("resident_id", UUID(as_uuid=True), ForeignKey("residents.id"), nullable=False),
    Column("medicine_id", UUID(as_uuid=True), ForeignKey("medicines.id"), nullable=False),
    Column("revision", Integer, nullable=False),
    Column("data", JSONB, nullable=False),
    Column("updated_at", DateTime(timezone=True), nullable=False),
    Column("updated_by", UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False),
    CheckConstraint("revision > 0"),
    Index("prescriptions_resident_id", "resident_id"),
)
prescription_versions = Table(
    "prescription_versions",
    metadata,
    Column("prescription_id", UUID(as_uuid=True), ForeignKey("prescriptions.id"), primary_key=True),
    Column("revision", Integer, primary_key=True),
    Column("medicine_id", UUID(as_uuid=True), ForeignKey("medicines.id"), nullable=False),
    Column("data", JSONB, nullable=False),
    Column("at", DateTime(timezone=True), nullable=False),
    Column("actor_id", UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False),
)
