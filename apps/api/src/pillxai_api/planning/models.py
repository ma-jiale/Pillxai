from datetime import date, datetime
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, Field

from ..app_settings import AppSettings
from ..identity.models import Input
from ..prescriptions.models import PrescriptionView


class PreviewRequest(Input):
    days: Annotated[int, Field(strict=True, ge=1, le=7)] | None = None
    split_meals: Annotated[bool, Field(strict=True)] | None = None


class PlanMedicine(BaseModel):
    prescription: PrescriptionView
    # One row per date, columns morning/noon/evening/night; quantities are particles.
    particles: list[list[int]]
    total_particles: int
    original_units: str


class PlanTray(BaseModel):
    purpose: str
    medicines: list[PlanMedicine]


class PlanSnapshot(BaseModel):
    id: UUID
    resident_id: UUID
    resident_revision: int
    resident_name: str
    bed: str
    business_date: date
    created_at: datetime
    settings: AppSettings
    requested_days: int
    split_meals: bool
    dates: list[date]
    slots: list[str]
    sources: list[PrescriptionView]
    trays: list[PlanTray]
    coverage_through: date | None = None


class PlanPreview(BaseModel):
    snapshot: PlanSnapshot
    current: bool
    message: str
