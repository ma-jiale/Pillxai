from uuid import UUID

from fastapi import APIRouter
from sqlalchemy import select

from ..contracts import ApiError
from ..identity.service import AccountDep, ConnectionDep
from . import service
from .models import (
    BindLabel,
    ClaimTask,
    DeviceView,
    DiscardTask,
    LabelView,
    MedicationParameters,
    ParameterView,
    SaveDevice,
    StartTask,
    StoredEvent,
    SyncEvents,
    TaskReceipt,
    TaskView,
)
from .tables import devices, events, labels, tasks

router = APIRouter(
    tags=["execution"], responses={code: {"model": ApiError} for code in (401, 403, 404, 409, 422)}
)


@router.get("/devices", operation_id="list_devices", response_model=list[DeviceView])
def list_devices(account: AccountDep, connection: ConnectionDep):
    return list(connection.execute(select(devices).order_by(devices.c.identity)).mappings())


@router.put("/devices/{device_id}", operation_id="save_device", response_model=DeviceView)
def save_device(device_id: UUID, data: SaveDevice, account: AccountDep, connection: ConnectionDep):
    return service.save_device(connection, account, device_id, data)


@router.get(
    "/residents/{resident_id}/labels", operation_id="list_labels", response_model=list[LabelView]
)
def list_labels(resident_id: UUID, account: AccountDep, connection: ConnectionDep):
    return list(
        connection.execute(select(labels).where(labels.c.resident_id == resident_id)).mappings()
    )


@router.post("/residents/{resident_id}/labels", operation_id="bind_label", response_model=LabelView)
def bind_label(resident_id: UUID, data: BindLabel, account: AccountDep, connection: ConnectionDep):
    return service.bind_label(connection, account, resident_id, data.uid)


@router.get(
    "/residents/{resident_id}/prescriptions/{prescription_id}/parameters",
    operation_id="get_parameters",
    response_model=ParameterView | None,
)
def get_parameters(
    resident_id: UUID, prescription_id: UUID, account: AccountDep, connection: ConnectionDep
):
    service.prescription_row(connection, resident_id, prescription_id)
    return service.latest_parameters(connection, prescription_id)


@router.put(
    "/residents/{resident_id}/prescriptions/{prescription_id}/parameters",
    operation_id="save_parameters",
    response_model=ParameterView,
)
def save_parameters(
    resident_id: UUID,
    prescription_id: UUID,
    data: MedicationParameters,
    account: AccountDep,
    connection: ConnectionDep,
):
    return service.save_parameters(connection, account, resident_id, prescription_id, data)


@router.get("/tasks", operation_id="list_tasks", response_model=list[TaskView])
def list_tasks(account: AccountDep, connection: ConnectionDep, active: bool = True):
    return list(
        connection.execute(
            select(tasks.c.snapshot)
            .where(tasks.c.active == active)
            .order_by(tasks.c.updated_at.desc())
            .limit(200)
        ).scalars()
    )


@router.get("/tasks/{task_id}", operation_id="get_task", response_model=TaskView)
def get_task(task_id: UUID, account: AccountDep, connection: ConnectionDep):
    return service.task_row(connection, task_id)["snapshot"]


@router.put("/tasks/{task_id}", operation_id="claim_task", response_model=TaskView)
def claim_task(task_id: UUID, data: ClaimTask, account: AccountDep, connection: ConnectionDep):
    return service.claim(connection, account, task_id, data)


@router.post("/tasks/{task_id}/start", operation_id="start_task", response_model=TaskView)
def start_task(task_id: UUID, data: StartTask, account: AccountDep, connection: ConnectionDep):
    return service.start(connection, account, task_id, data)


@router.post("/tasks/{task_id}/events", operation_id="sync_events", response_model=TaskView)
def sync_events(task_id: UUID, data: SyncEvents, account: AccountDep, connection: ConnectionDep):
    return service.sync(connection, account, task_id, data)


@router.get(
    "/tasks/{task_id}/events", operation_id="list_task_events", response_model=list[StoredEvent]
)
def list_events(task_id: UUID, account: AccountDep, connection: ConnectionDep, after: int = 0):
    service.task_row(connection, task_id)
    rows = connection.execute(
        select(events)
        .where(events.c.task_id == task_id, events.c.sequence > after)
        .order_by(events.c.sequence)
        .limit(200)
    ).mappings()
    return [row["data"] | dict(received_at=row["received_at"]) for row in rows]


@router.post("/tasks/{task_id}/cancel", operation_id="cancel_task", response_model=TaskView)
def cancel_task(task_id: UUID, data: DiscardTask, account: AccountDep, connection: ConnectionDep):
    return service.cancel_unstarted(connection, account, task_id, data)


@router.post("/tasks/{task_id}/discard", operation_id="discard_task", response_model=TaskReceipt)
def discard_task(task_id: UUID, data: DiscardTask, account: AccountDep, connection: ConnectionDep):
    service.discard(connection, account, task_id, data)
    return TaskReceipt(task_id=task_id, deleted=True)
