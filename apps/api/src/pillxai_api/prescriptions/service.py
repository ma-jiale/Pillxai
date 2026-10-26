from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import insert, select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert

from ..app_settings import read_settings
from ..database import BusinessError, conflict, not_found
from ..identity.service import require_maintain
from ..residents.service import resident_row
from .tables import medicines, prescription_versions, prescriptions


def prescription_row(connection, resident_id, prescription_id):
    resident_row(connection, resident_id)
    row = (
        connection.execute(
            select(prescriptions).where(
                prescriptions.c.id == prescription_id,
                prescriptions.c.resident_id == resident_id,
            )
        )
        .mappings()
        .first()
    )
    if not row:
        not_found()
    return row


def save(connection, account, resident_id, prescription_id, request):
    require_maintain(account)
    resident_row(connection, resident_id)
    if not read_settings(connection)["bedtime_enabled"] and request.data.doses.night != "0":
        raise BusinessError(422, "bedtime_disabled", "请先启用睡前格。")
    previous = None
    if request.expected_revision:
        previous = prescription_row(connection, resident_id, prescription_id)
        if previous["revision"] != request.expected_revision:
            conflict()
    data = request.data.model_dump(mode="json")
    # A medicine identity is stable while its descriptors stay unchanged. Editing
    # descriptors creates a new identity; old versions retain the original one.
    same_medicine = previous and all(
        previous["data"][key] == data[key] for key in ("medicine_name", "strength", "unit")
    )
    medicine_id = previous["medicine_id"] if same_medicine else uuid4()
    if not same_medicine:
        connection.execute(
            insert(medicines).values(
                id=medicine_id,
                name=data["medicine_name"],
                strength=data["strength"],
                unit=data["unit"],
            )
        )
    values = dict(
        data=data,
        medicine_id=medicine_id,
        revision=request.expected_revision + 1,
        updated_at=datetime.now(UTC),
        updated_by=account.id,
    )
    if request.expected_revision == 0:
        statement = (
            pg_insert(prescriptions)
            .values(
                id=prescription_id,
                resident_id=resident_id,
                **values,
            )
            .on_conflict_do_nothing(index_elements=[prescriptions.c.id])
        )
    else:
        statement = (
            update(prescriptions)
            .where(
                prescriptions.c.id == prescription_id,
                prescriptions.c.resident_id == resident_id,
                prescriptions.c.revision == request.expected_revision,
            )
            .values(**values)
        )
    saved = connection.execute(statement.returning(prescriptions)).mappings().first()
    if not saved:
        conflict()
    connection.execute(
        insert(prescription_versions).values(
            prescription_id=prescription_id,
            revision=saved["revision"],
            medicine_id=medicine_id,
            data=data,
            at=saved["updated_at"],
            actor_id=account.id,
        )
    )
    return saved
