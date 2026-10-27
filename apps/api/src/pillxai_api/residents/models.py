from datetime import datetime
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, Field, StringConstraints

from ..identity.models import Input


class ResidentData(Input):
    name: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=30)]
    bed: Annotated[str, StringConstraints(strip_whitespace=True, max_length=40)] = ""
    # Omitted/null preserves an existing code for clients predating barcode support.
    # An empty string explicitly clears it; codes remain strings, including leading zeros.
    barcode: (
        Annotated[str, StringConstraints(strict=True, strip_whitespace=True, max_length=128)] | None
    ) = None


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
