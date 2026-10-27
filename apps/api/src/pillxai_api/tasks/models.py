from datetime import datetime
from enum import StrEnum
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, Field, StringConstraints, model_validator

from ..identity.models import Input
from ..planning.models import PlanSnapshot

Name = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)]
Uid = Annotated[str, StringConstraints(pattern=r"^[0-9A-F]{1,64}$")]


class DeviceMode(StrEnum):
    simulator = "simulator"
    hardware = "hardware"


class DeviceConfiguration(Input):
    name: Name
    identity: Name
    terminal_id: UUID
    mode: DeviceMode
    # Business morning/noon/evening/night -> protocol row. No implicit mapping.
    rows: list[Annotated[int, Field(strict=True, ge=0, le=3)]] = Field(min_length=4, max_length=4)
    reverse_columns: bool = False
    positions_verified: bool = False
    # Exact, explicitly verified complete lines; an RFID absence is not tray absence.
    tray_present_line: str = Field(default="", max_length=120)
    tray_absent_line: str = Field(default="", max_length=120)
    ready_line: str = Field(default="", max_length=120)
    feedback_verified: bool = False

    @model_validator(mode="after")
    def distinct_mapping(self):
        if sorted(self.rows) != [0, 1, 2, 3]:
            raise ValueError("时段映射不能重复。")
        lines = [self.tray_present_line, self.tray_absent_line, self.ready_line]
        if self.feedback_verified and (not all(lines) or len(set(lines)) != 3):
            raise ValueError("须填写独立、已确认的在轨、离轨和就绪反馈。")
        reserved = {"ACK", "DONE", "NO CARD", "machine init", "machine_state:FINISH"}
        if any(line in reserved or "\n" in line or "\r" in line for line in lines):
            raise ValueError("通用应答或无卡不能用作轨道位置反馈。")
        return self


class SaveDevice(Input):
    expected_revision: Annotated[int, Field(strict=True, ge=0)]
    configuration: DeviceConfiguration


class DeviceView(BaseModel):
    id: UUID
    revision: int
    configuration: DeviceConfiguration


class BindLabel(Input):
    uid: Uid


class LabelView(BaseModel):
    uid: str
    resident_id: UUID


class MedicationParameters(Input):
    expected_revision: Annotated[int, Field(strict=True, ge=0)]
    medicine_id: UUID
    turntable: Annotated[float, Field(ge=0, allow_inf_nan=False)]
    gate: Annotated[float, Field(ge=0, le=1, allow_inf_nan=False)]
    simulation_only: bool = False


class ParameterView(BaseModel):
    prescription_id: UUID
    medicine_id: UUID
    revision: int
    turntable: float
    gate: float
    simulation_only: bool = False


class BatchPlan(BaseModel):
    index: int
    tray: int
    prescription_id: UUID
    medicine_id: UUID
    name: str
    strength: str
    feed_form: str
    purpose: str
    total: int
    matrix: list[list[int]]
    parameters: ParameterView


class ClaimTask(Input):
    plan_id: UUID
    device_id: UUID
    terminal_id: UUID


class TaskState(StrEnum):
    claimed = "claimed"
    started = "started"
    awaiting_collection = "awaiting_collection"
    completed = "completed"
    cancelled = "cancelled"


class TaskView(BaseModel):
    id: UUID
    plan_id: UUID
    device_id: UUID
    terminal_id: UUID
    owner_id: UUID
    revision: int
    state: TaskState
    plan: PlanSnapshot
    device: DeviceView
    labels: list[str]
    batches: list[BatchPlan]
    sequence: int
    completed_batches: list[int]
    counts: list[int]
    started_at: datetime | None
    updated_at: datetime


class TaskOwner(Input):
    terminal_id: UUID


class StartTask(TaskOwner):
    expected_revision: Annotated[int, Field(strict=True, ge=1)]
    uid: Uid
    observed_at: datetime


class ExecutionEvent(Input):
    sequence: Annotated[int, Field(strict=True, ge=1)]
    kind: Annotated[str, StringConstraints(min_length=1, max_length=60)]
    batch: Annotated[int, Field(strict=True, ge=0)]
    at: datetime
    # Opaque evidence is retained but cannot directly mutate task state.
    detail: dict = Field(default_factory=dict)


class SyncEvents(TaskOwner):
    events: list[ExecutionEvent] = Field(min_length=1, max_length=200)


class StoredEvent(ExecutionEvent):
    received_at: datetime


class DiscardTask(TaskOwner):
    physical_scene_safe: bool


class TaskReceipt(BaseModel):
    task_id: UUID
    deleted: bool
