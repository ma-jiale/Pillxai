from uuid import UUID

from fastapi import APIRouter, Query
from sqlalchemy import select

from ..contracts import ApiError
from ..identity.service import AccountDep, ConnectionDep
from .models import ResidentPage, ResidentView, SaveResident
from .service import resident_row, save, view
from .tables import resident_versions, residents

router = APIRouter(
    prefix="/residents",
    tags=["residents"],
    responses={code: {"model": ApiError} for code in (401, 403, 404, 409, 422)},
)


@router.get("", operation_id="list_residents", response_model=ResidentPage)
def list_residents(
    account: AccountDep,
    connection: ConnectionDep,
    after: UUID | None = None,
    limit: int = Query(200, ge=1, le=500),
    query: str = Query("", max_length=80),
    barcode: str | None = Query(None, min_length=1, max_length=128),
):
    statement = select(residents)
    if barcode is not None:
        statement = statement.where(residents.c.barcode == barcode)
    if after:
        statement = statement.where(residents.c.id > after)
    if query.strip():
        statement = statement.where(
            residents.c.name.contains(query.strip(), autoescape=True)
            | residents.c.bed.contains(query.strip(), autoescape=True),
        )
    rows = connection.execute(statement.order_by(residents.c.id).limit(limit + 1)).mappings().all()
    return dict(
        items=[view(row) for row in rows[:limit]],
        next_after=rows[limit - 1]["id"] if len(rows) > limit else None,
    )


@router.get("/{resident_id}", operation_id="get_resident", response_model=ResidentView)
def get(resident_id: UUID, account: AccountDep, connection: ConnectionDep):
    return view(resident_row(connection, resident_id))


@router.put("/{resident_id}", operation_id="save_resident", response_model=ResidentView)
def put(resident_id: UUID, data: SaveResident, account: AccountDep, connection: ConnectionDep):
    return save(connection, account, resident_id, data)


@router.get(
    "/{resident_id}/versions",
    operation_id="list_resident_versions",
    response_model=list[ResidentView],
)
def versions(resident_id: UUID, account: AccountDep, connection: ConnectionDep):
    resident_row(connection, resident_id)
    rows = connection.execute(
        select(resident_versions)
        .where(
            resident_versions.c.resident_id == resident_id,
        )
        .order_by(resident_versions.c.revision.desc())
    ).mappings()
    return [
        dict(
            id=resident_id,
            revision=row["revision"],
            data=row["data"],
            updated_at=row["at"],
            updated_by=row["actor_id"],
        )
        for row in rows
    ]
