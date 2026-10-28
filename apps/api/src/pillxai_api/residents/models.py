from datetime import datetime
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, Field, StringConstraints, field_validator

from ..identity.models import Input
from .avatar import normalize_avatar


class ResidentData(Input):
    name: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=30)]
    bed: Annotated[str, StringConstraints(strip_whitespace=True, max_length=40)] = ""
    # Server-assigned, immutable. Omission/null preserves an existing code;
    # a returned value may be echoed unchanged, never cleared or replaced.
    barcode: (
        Annotated[str, StringConstraints(strict=True, strip_whitespace=True, max_length=128)] | None
    ) = None
    avatar: Annotated[str, StringConstraints(strict=True, max_length=360000)] | None = None

    @field_validator("avatar")
    @classmethod
    def valid_avatar(cls, value):
        return normalize_avatar(value)


class SaveResident(Input):
    expected_revision: Annotated[int, Field(strict=True, ge=0)]
    data: ResidentData


class ResidentView(BaseModel):
    id: UUID
    revision: int
    data: ResidentData
    updated_at: datetime
    updated_by: UUID


class ResidentPage(BaseModel):
    items: list[ResidentView]
    next_after: UUID | None
