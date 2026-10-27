from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Table,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID

from ..database import metadata

devices = Table(
    "devices",
    metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("identity", String(120), nullable=False, unique=True),
    Column("revision", Integer, nullable=False),
    Column("configuration", JSONB, nullable=False),
)
labels = Table(
    "resident_labels",
    metadata,
    Column("uid", String(64), primary_key=True),
    Column("resident_id", UUID(as_uuid=True), ForeignKey("residents.id"), nullable=False),
    Column("actor_id", UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False),
    Column("at", DateTime(timezone=True), nullable=False),
)
parameters = Table(
    "prescription_parameters",
    metadata,
    Column("prescription_id", UUID(as_uuid=True), ForeignKey("prescriptions.id"), primary_key=True),
    Column("revision", Integer, primary_key=True),
    Column("medicine_id", UUID(as_uuid=True), nullable=False),
    Column("turntable", Float, nullable=False),
    Column("gate", Float, nullable=False),
    Column("simulation_only", Boolean, nullable=False),
    Column("actor_id", UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False),
    Column("at", DateTime(timezone=True), nullable=False),
)
tasks = Table(
    "dispensing_tasks",
    metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("plan_id", UUID(as_uuid=True), nullable=False, unique=True),
    Column("resident_id", UUID(as_uuid=True), ForeignKey("residents.id"), nullable=False),
    Column("device_id", UUID(as_uuid=True), ForeignKey("devices.id"), nullable=False),
    Column("terminal_id", UUID(as_uuid=True), nullable=False),
    Column("owner_id", UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False),
    Column("active", Boolean, nullable=False),
    Column("state", String(30), nullable=False),
    Column("snapshot", JSONB, nullable=False),
    Column("updated_at", DateTime(timezone=True), nullable=False),
)
Index("one_active_device", tasks.c.device_id, unique=True, postgresql_where=text("active"))
Index("one_active_resident", tasks.c.resident_id, unique=True, postgresql_where=text("active"))
events = Table(
    "execution_events",
    metadata,
    Column(
        "task_id",
        UUID(as_uuid=True),
        ForeignKey("dispensing_tasks.id", ondelete="CASCADE"),
        primary_key=True,
    ),
    Column("sequence", Integer, primary_key=True),
    Column("data", JSONB, nullable=False),
    Column("received_at", DateTime(timezone=True), nullable=False),
)
tombstones = Table(
    "deleted_tasks",
    metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
)
