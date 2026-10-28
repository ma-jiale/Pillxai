from sqlalchemy import select

from ..planning.models import PlanSnapshot
from .tables import tasks


def completed_until(connection, resident_id):
    """Only complete real cycles contribute coverage; cancellation revokes it."""
    rows = connection.execute(
        select(tasks.c.snapshot).where(
            tasks.c.resident_id == resident_id,
            tasks.c.state.in_(["awaiting_collection", "completed"]),
        )
    ).scalars()
    dates = [
        PlanSnapshot.model_validate(row["plan"]).dates[-1]
        for row in rows
        if row["device"]["configuration"]["mode"] == "hardware"
    ]
    return max(dates) if dates else None
