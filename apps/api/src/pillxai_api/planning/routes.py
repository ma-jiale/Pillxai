from datetime import UTC, datetime
from uuid import UUID as Uuid
from uuid import uuid4
from zoneinfo import ZoneInfo

from fastapi import APIRouter
from sqlalchemy import Column, DateTime, ForeignKey, Table, insert, select
from sqlalchemy.dialects.postgresql import JSONB, UUID

from ..app_settings import AppSettings, read_settings
from ..contracts import ApiError
from ..database import BusinessError, metadata, not_found
from ..identity.service import AccountDep, ConnectionDep
from ..prescriptions.service import current_prescriptions
from ..residents.service import resident_row
from ..residents.tables import residents
from ..tasks.coverage import completed_until
from .engine import calculate
from .models import PlanPreview, PlanSnapshot, PreparationItem, PreviewRequest

previews = Table(
    "plan_previews",
    metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("resident_id", UUID(as_uuid=True), ForeignKey("residents.id"), nullable=False),
    Column("snapshot", JSONB, nullable=False),
    Column("created_at", DateTime(timezone=True), nullable=False),
    Column("created_by", UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False),
)
router = APIRouter(
    tags=["planning"], responses={code: {"model": ApiError} for code in (401, 404, 422)}
)


@router.get("/preparation", operation_id="list_preparation", response_model=list[PreparationItem])
def list_preparation(account: AccountDep, connection: ConnectionDep):
    configuration = AppSettings.model_validate(read_settings(connection))
    today = datetime.now(ZoneInfo(configuration.timezone)).date()
    result = []
    for resident in connection.execute(select(residents).order_by(residents.c.name)).mappings():
        sources = current_prescriptions(connection, resident["id"])
        coverage = completed_until(connection, resident["id"])
        issue = None
        try:
            dates, trays = calculate(
                sources,
                configuration,
                today,
                configuration.preparation_days,
                configuration.split_meals,
                coverage,
            )
            count = sum(len(tray.medicines) for tray in trays)
        except BusinessError as error:
            if error.code == "no_demand":
                continue
            dates, count, issue = [], len(sources), error.message
        result.append(
            PreparationItem(
                resident_id=resident["id"],
                name=resident["name"],
                bed=resident["bed"],
                early=coverage is not None and (coverage - today).days + 1 > 2,
                medicine_count=count,
                dates=dates,
                coverage_through=coverage,
                issue=issue,
            )
        )
    return result


@router.post(
    "/residents/{resident_id}/plans/preview",
    operation_id="create_plan_preview",
    response_model=PlanPreview,
)
def create_preview(
    resident_id: Uuid, data: PreviewRequest, account: AccountDep, connection: ConnectionDep
):
    configuration = AppSettings.model_validate(read_settings(connection, lock=True))
    resident = resident_row(connection, resident_id, lock=True)
    sources = current_prescriptions(connection, resident_id)
    now = datetime.now(UTC)
    today = now.astimezone(ZoneInfo(configuration.timezone)).date()
    days = data.days if data.days is not None else configuration.preparation_days
    split = data.split_meals if data.split_meals is not None else configuration.split_meals
    coverage = completed_until(connection, resident_id)
    dates, trays = calculate(sources, configuration, today, days, split, coverage)
    snapshot = PlanSnapshot(
        id=uuid4(),
        resident_id=resident_id,
        resident_revision=resident["revision"],
        resident_name=resident["name"],
        bed=resident["bed"],
        business_date=today,
        created_at=now,
        settings=configuration,
        requested_days=days,
        split_meals=split,
        dates=dates,
        slots=["早", "午", "晚"] + (["睡前"] if configuration.bedtime_enabled else []),
        sources=sources,
        trays=trays,
        coverage_through=coverage,
    )
    connection.execute(
        insert(previews).values(
            id=snapshot.id,
            resident_id=resident_id,
            snapshot=snapshot.model_dump(mode="json"),
            created_at=now,
            created_by=account.id,
        )
    )
    return PlanPreview(snapshot=snapshot, current=True, message="预览未执行，不产生已摆药覆盖。")


@router.get("/plans/{plan_id}", operation_id="get_plan_preview", response_model=PlanPreview)
def get_preview(plan_id: Uuid, account: AccountDep, connection: ConnectionDep):
    stored = connection.execute(
        select(previews.c.snapshot).where(previews.c.id == plan_id)
    ).scalar()
    if stored is None:
        not_found()
    snapshot = PlanSnapshot.model_validate(stored)
    configuration = AppSettings.model_validate(read_settings(connection, lock=True))
    resident = resident_row(connection, snapshot.resident_id, lock=True)
    sources = current_prescriptions(connection, snapshot.resident_id)

    def versions(rows):
        return {(str(row.id), row.revision) for row in rows}

    current = (
        configuration.revision == snapshot.settings.revision
        and resident["revision"] == snapshot.resident_revision
        and versions(sources) == versions(snapshot.sources)
        and datetime.now(ZoneInfo(configuration.timezone)).date() == snapshot.business_date
        and completed_until(connection, snapshot.resident_id) == snapshot.coverage_through
    )
    return PlanPreview(
        snapshot=snapshot,
        current=current,
        message="预览未执行，不产生已摆药覆盖。"
        if current
        else "资料、设置或业务日期已变化，请重新生成计划。",
    )
