from datetime import UTC, datetime

from sqlalchemy import insert, select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.exc import IntegrityError

from ..database import BusinessError, conflict, not_found
from ..identity.service import require_maintain
from .tables import resident_versions, residents


def resident_row(connection, resident_id, *, lock=False):
    statement = select(residents).where(residents.c.id == resident_id)
    if lock:
        statement = statement.with_for_update()
    row = connection.execute(statement).mappings().first()
    if not row:
        not_found()
    return row


def view(row):
    return dict(
        id=row["id"],
        revision=row["revision"],
        data=dict(name=row["name"], bed=row["bed"], barcode=row["barcode"]),
        updated_at=row["updated_at"],
        updated_by=row["updated_by"],
    )


def save(connection, account, resident_id, request):
    require_maintain(account)
    values = dict(
        **request.data.model_dump(exclude_none=True),
        updated_at=datetime.now(UTC),
        updated_by=account.id,
        revision=request.expected_revision + 1,
    )
    try:
        if request.expected_revision == 0:
            statement = (
                pg_insert(residents)
                .values(
                    id=resident_id,
                    **values,
                )
                .on_conflict_do_nothing(index_elements=[residents.c.id])
            )
        else:
            resident_row(connection, resident_id)
            statement = (
                update(residents)
                .where(
                    residents.c.id == resident_id,
                    residents.c.revision == request.expected_revision,
                )
                .values(**values)
            )
        row = connection.execute(statement.returning(residents)).mappings().first()
    except IntegrityError as error:
        if getattr(error.orig.diag, "constraint_name", None) == "residents_barcode_unique":
            raise BusinessError(
                409, "barcode_conflict", "该条码已属于其他长者，请核对条码。"
            ) from error
        if getattr(error.orig.diag, "constraint_name", None) == "residents_bed_unique":
            raise BusinessError(
                409, "bed_conflict", "该床位已属于其他长者，请核对完整床位。"
            ) from error
        raise
    if not row:
        conflict()
    connection.execute(
        insert(resident_versions).values(
            resident_id=resident_id,
            revision=row["revision"],
            data=view(row)["data"],
            at=row["updated_at"],
            actor_id=account.id,
        )
    )
    return view(row)
