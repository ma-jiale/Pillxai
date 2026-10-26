"""Public wire types; no SQLAlchemy types cross this boundary."""

from datetime import date
from decimal import Decimal
from enum import StrEnum
from typing import Annotated
from uuid import UUID

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, model_validator


class Health(BaseModel):
    status: str
    service_version: str


class ApiError(BaseModel):
    code: str
    message: str


class FeedForm(StrEnum):
    WHOLE = "whole"
    HALF = "half"


class ContractSample(BaseModel):
    """Development fixture, NOT a prescription or permission to operate a machine.

    Decimal strings survive Python/Dart round trips without float conversion.
    Dates represent business dates; observed_at must carry an offset.
    """

    model_config = ConfigDict(extra="forbid")
    sample_id: UUID
    prescription_version: Annotated[int, Field(strict=True, ge=1)]
    start_date: date
    end_date: date | None
    observed_at: AwareDatetime
    feed_form: FeedForm
    original_tablets: Annotated[str, Field(pattern=r"^(0|[1-9][0-9]*)(\.[0-9]+)?$")]
    particles: Annotated[int, Field(strict=True, ge=1, le=255)]
    note: str | None

    @model_validator(mode="after")
    def validate_quantity_and_dates(self) -> "ContractSample":
        unit = Decimal("0.5") if self.feed_form == FeedForm.HALF else Decimal("1")
        if Decimal(self.original_tablets) != unit * self.particles:
            raise ValueError("original_tablets must equal particles times the feed-form unit")
        if self.end_date is not None and self.end_date < self.start_date:
            raise ValueError("end_date cannot precede start_date")
        return self


class SaveContractSample(BaseModel):
    model_config = ConfigDict(extra="forbid")
    expected_revision: Annotated[int, Field(strict=True, ge=0)]
    sample: ContractSample


class SavedContractSample(BaseModel):
    revision: int
    sample: ContractSample
