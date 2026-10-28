from datetime import date, datetime
from decimal import Decimal
from enum import StrEnum
from typing import Annotated, Self
from uuid import UUID

from pydantic import BaseModel, Field, StringConstraints, model_validator

from ..contracts import FeedForm
from ..identity.models import Input

Dose = Annotated[str, StringConstraints(pattern=r"^(0|[1-9][0-9]{0,2})(\.5)?$")]
Description = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)]


class DoseAmounts(Input):
    morning: Dose
    noon: Dose
    evening: Dose
    night: Dose


class DoseUnit(StrEnum):
    tablet = "tablet"
    capsule = "capsule"


class MealRelation(StrEnum):
    before = "before"
    after = "after"
    with_meal = "with_meal"
    unrestricted = "unrestricted"


class PrescriptionData(Input):
    medicine_name: Description
    strength: Description
    unit: DoseUnit
    feed_form: FeedForm
    doses: DoseAmounts
    meal_relation: MealRelation
    start_date: date
    end_date: date | None
    stopped: bool = False

    @model_validator(mode="after")
    def validate_doses_and_dates(self) -> Self:
        doses = [Decimal(value) for value in self.doses.model_dump().values()]
        if not any(dose > 0 for dose in doses):
            raise ValueError("至少填写一个时段的正用量。")
        if self.feed_form == FeedForm.HALF:
            if self.unit != DoseUnit.tablet or any(
                dose not in (0, Decimal("0.5")) for dose in doses
            ):
                raise ValueError("半片仅支持每次 0.5 片，由人工预切。")
        elif any(dose != int(dose) or dose > 255 for dose in doses):
            raise ValueError("整片或整粒每次须为 0–255 的整数。")
        if self.end_date and self.end_date < self.start_date:
            raise ValueError("结束日期不能早于开始日期。")
        return self


class SavePrescription(Input):
    expected_revision: Annotated[int, Field(strict=True, ge=0)]
    data: PrescriptionData


class PrescriptionView(BaseModel):
    id: UUID
    resident_id: UUID
    medicine_id: UUID
    revision: int
    data: PrescriptionData
    updated_at: datetime
    updated_by: UUID


