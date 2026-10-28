"""Shared settings for this deployment, independent of accounts and UI sessions."""

from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter
from pydantic import BaseModel, Field
from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Table,
    insert,
    select,
    update,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID

from .contracts import ApiError
from .database import conflict, metadata
from .identity.models import Input
from .identity.service import AccountDep, ConnectionDep, require_admin

settings = Table(
    "app_settings",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("timezone", String(64), nullable=False),
    Column("bedtime_enabled", Boolean, nullable=False),
    Column("preparation_days", Integer, nullable=False),
    Column("split_meals", Boolean, nullable=False),
    Column("start_tomorrow", Boolean, nullable=False),
    Column("revision", Integer, nullable=False),
    CheckConstraint("id = 1"),
    CheckConstraint("preparation_days BETWEEN 1 AND 7"),
    CheckConstraint("revision > 0"),
)
versions = Table(
    "settings_versions",
    metadata,
    Column("revision", Integer, primary_key=True),
    Column("data", JSONB, nullable=False),
    Column("at", DateTime(timezone=True), nullable=False),
    Column("actor_id", UUID(as_uuid=True), ForeignKey("accounts.id")),
)


class AppSettings(BaseModel):
    timezone: str
    bedtime_enabled: bool
    preparation_days: int
    split_meals: bool
    start_tomorrow: bool
    revision: int


class SaveSettings(Input):
    expected_revision: Annotated[int, Field(strict=True, ge=1)]
    preparation_days: Annotated[int, Field(strict=True, ge=1, le=7)]
    split_meals: Annotated[bool, Field(strict=True)]
    bedtime_enabled: Annotated[bool, Field(strict=True)]
    start_tomorrow: Annotated[bool, Field(strict=True)]


def read_settings(connection, *, lock=False):
    statement = select(settings).where(settings.c.id == 1)
    if lock:
        statement = statement.with_for_update(read=True)
    return connection.execute(statement).mappings().one()


router = APIRouter(
    tags=["settings"], responses={code: {"model": ApiError} for code in (401, 403, 409, 422)}
)


@router.get("/settings", operation_id="get_settings", response_model=AppSettings)
def get_settings(account: AccountDep, connection: ConnectionDep):
    return read_settings(connection)


@router.put("/settings", operation_id="save_settings", response_model=AppSettings)
def save_settings(data: SaveSettings, account: AccountDep, connection: ConnectionDep):
    require_admin(account)
    row = (
        connection.execute(
            update(settings)
            .where(settings.c.id == 1, settings.c.revision == data.expected_revision)
            .values(
                **data.model_dump(exclude={"expected_revision"}),
                revision=data.expected_revision + 1,
            )
            .returning(settings)
        )
        .mappings()
        .first()
    )
    if not row:
        conflict()
    result = AppSettings.model_validate(row)
    connection.execute(
        insert(versions).values(
            revision=result.revision,
            data=result.model_dump(mode="json"),
            at=datetime.now(UTC),
            actor_id=account.id,
        )
    )
    return result
