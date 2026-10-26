"""Shared settings for this deployment, independent of accounts and UI sessions."""

from fastapi import APIRouter
from pydantic import BaseModel
from sqlalchemy import Boolean, CheckConstraint, Column, Integer, String, Table, select

from .contracts import ApiError
from .database import metadata
from .identity.service import AccountDep, ConnectionDep

settings = Table(
    "app_settings",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("timezone", String(64), nullable=False),
    Column("bedtime_enabled", Boolean, nullable=False),
    CheckConstraint("id = 1"),
)


class AppSettings(BaseModel):
    timezone: str
    bedtime_enabled: bool


def read_settings(connection):
    return connection.execute(select(settings).where(settings.c.id == 1)).mappings().one()


router = APIRouter(tags=["settings"], responses={401: {"model": ApiError}})


@router.get("/settings", operation_id="get_settings", response_model=AppSettings)
def get_settings(account: AccountDep, connection: ConnectionDep):
    return read_settings(connection)
