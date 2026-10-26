"""Pure preview computation. A preview never creates execution or completed coverage."""

from datetime import timedelta
from decimal import Decimal

from ..contracts import FeedForm
from ..database import BusinessError
from .models import PlanMedicine, PlanTray


def calculate(sources, settings, today, days, split_meals):
    start = today + timedelta(days=int(settings.start_tomorrow))
    active = [
        row
        for row in sources
        if not row.data.stopped and (row.data.end_date is None or row.data.end_date >= start)
    ]
    if not active:
        raise BusinessError(422, "no_demand", "当前没有需要准备的用药。")
    if all(row.data.start_date > start for row in active):
        start = min(row.data.start_date for row in active)
    dates = [start + timedelta(days=day) for day in range(days)]
    planned = []
    for source in active:
        data = source.data
        valid = [
            data.start_date <= day and (data.end_date is None or day <= data.end_date)
            for day in dates
        ]
        if not any(valid):
            continue
        if not settings.bedtime_enabled and Decimal(data.doses.night) > 0:
            raise BusinessError(
                422,
                "bedtime_disabled",
                f"{data.medicine_name}有睡前用量，请启用睡前时段后重新生成。",
            )
        doses = [Decimal(value) for value in data.doses.model_dump().values()]
        factor = 2 if data.feed_form == FeedForm.HALF else 1
        matrix = [[int(dose * factor) if valid_day else 0 for dose in doses] for valid_day in valid]
        total = sum(sum(row) for row in matrix)
        planned.append(
            PlanMedicine(
                prescription=source,
                particles=matrix,
                total_particles=total,
                original_units=format(Decimal(total) / factor, "f"),
            )
        )
    used = [index for index in range(days) if any(sum(m.particles[index]) for m in planned)]
    if not used:
        raise BusinessError(422, "no_demand", "本次日期范围没有需要准备的用药。")
    length = max(used) + 1
    dates = dates[:length]
    for medicine in planned:
        medicine.particles = medicine.particles[:length]
    groups = [("全部用药", planned)]
    if split_meals:
        groups = [
            ("饭前", [m for m in planned if m.prescription.data.meal_relation == "before"]),
            (
                "饭后、随餐及无餐食限制",
                [m for m in planned if m.prescription.data.meal_relation != "before"],
            ),
        ]
    return dates, [
        PlanTray(purpose=purpose, medicines=medicines) for purpose, medicines in groups if medicines
    ]
