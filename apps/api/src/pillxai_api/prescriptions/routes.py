from uuid import UUID

from fastapi import APIRouter
from sqlalchemy import select

from ..contracts import ApiError
from ..identity.service import AccountDep, ConnectionDep
from ..residents.service import resident_row
from .models import PrescriptionView, SavePrescription
from .service import prescription_row, save
from .tables import prescription_versions, prescriptions

router = APIRouter(
    prefix="/residents/{resident_id}/prescriptions",
    tags=["prescriptions"],
    responses={code: {"model": ApiError} for code in (401, 403, 404, 409, 422)},
)


@router.get("", operation_id="list_prescriptions", response_model=list[PrescriptionView])
def list_prescriptions(resident_id: UUID, account: AccountDep, connection: ConnectionDep):
    resident_row(connection, resident_id)
    return (
        connection.execute(
            select(prescriptions)
            .where(
                prescriptions.c.resident_id == resident_id,
            )
            .order_by(prescriptions.c.id)
        )
        .mappings()
        .all()
    )


@router.put("/{prescription_id}", operation_id="save_prescription", response_model=PrescriptionView)
def put(
    resident_id: UUID,
    prescription_id: UUID,
    data: SavePrescription,
    account: AccountDep,
    connection: ConnectionDep,
):
    return save(connection, account, resident_id, prescription_id, data)


@router.get(
    "/{prescription_id}/versions",
    operation_id="list_prescription_versions",
    response_model=list[PrescriptionView],
)
def versions(
    resident_id: UUID, prescription_id: UUID, account: AccountDep, connection: ConnectionDep
):
    prescription_row(connection, resident_id, prescription_id)
    rows = connection.execute(
        select(prescription_versions)
        .where(
            prescription_versions.c.prescription_id == prescription_id,
        )
        .order_by(prescription_versions.c.revision.desc())
    ).mappings()
    return [
        dict(
            id=prescription_id,
            resident_id=resident_id,
            medicine_id=row["medicine_id"],
            revision=row["revision"],
            data=row["data"],
            updated_at=row["at"],
            updated_by=row["actor_id"],
        )
        for row in rows
    ]
