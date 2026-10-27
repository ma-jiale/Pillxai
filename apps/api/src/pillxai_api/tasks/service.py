from datetime import UTC, datetime

from sqlalchemy import delete, insert, select, update
from sqlalchemy.exc import IntegrityError

from ..database import BusinessError, conflict, not_found
from ..identity.service import require_maintain
from ..planning.routes import get_preview, previews
from ..prescriptions.service import prescription_row
from ..residents.service import resident_row
from ..residents.tables import residents
from .learning import evaluate_batch, select_parameters
from .models import BatchPlan, DeviceMode, DeviceView, ParameterView, TaskState, TaskView
from .tables import devices, events, labels, parameters, tasks, tombstones


def reject(message, code="task_conflict"):
    raise BusinessError(409, code, message)


def device_view(row):
    return DeviceView.model_validate(row)


def save_device(connection, account, device_id, request):
    require_maintain(account)
    row = (
        connection.execute(select(devices).where(devices.c.id == device_id).with_for_update())
        .mappings()
        .first()
    )
    if (row["revision"] if row else 0) != request.expected_revision:
        conflict()
    if connection.execute(
        select(tasks.c.id).where(tasks.c.device_id == device_id, tasks.c.active)
    ).first():
        reject("设备仍有未结束任务，不能修改配置。")
    values = dict(
        identity=request.configuration.identity,
        revision=request.expected_revision + 1,
        configuration=request.configuration.model_dump(mode="json"),
    )
    try:
        if row:
            connection.execute(update(devices).where(devices.c.id == device_id).values(**values))
        else:
            connection.execute(insert(devices).values(id=device_id, **values))
    except IntegrityError as error:
        raise BusinessError(409, "device_identity", "该设备身份已登记，请选择原设备。") from error
    return DeviceView(id=device_id, **values)


def save_parameters(connection, account, resident_id, prescription_id, request):
    require_maintain(account)
    resident_row(connection, resident_id, lock=True)
    source = prescription_row(connection, resident_id, prescription_id)
    if source["medicine_id"] != request.medicine_id:
        reject("药物或投料形态已变化，请重新核对参数。")
    previous = latest_parameters(connection, prescription_id)
    if (previous.revision if previous else 0) != request.expected_revision:
        conflict()
    result = ParameterView(
        prescription_id=prescription_id,
        medicine_id=request.medicine_id,
        revision=request.expected_revision + 1,
        turntable=request.turntable,
        gate=request.gate,
        simulation_only=request.simulation_only,
        learning_enabled=request.learning_enabled,
        has_values=request.has_values,
        feed_form=source["data"]["feed_form"],
    )
    connection.execute(
        insert(parameters).values(**result.model_dump(), actor_id=account.id, at=datetime.now(UTC))
    )
    return result


def latest_parameters(connection, prescription_id):
    row = (
        connection.execute(
            select(parameters)
            .where(parameters.c.prescription_id == prescription_id)
            .order_by(parameters.c.revision.desc())
            .limit(1)
        )
        .mappings()
        .first()
    )
    return ParameterView.model_validate(row) if row else None


def bind_label(connection, account, resident_id, uid):
    require_maintain(account)
    resident_row(connection, resident_id, lock=True)
    existing = connection.execute(select(labels).where(labels.c.uid == uid)).mappings().first()
    if existing:
        if existing["resident_id"] != resident_id:
            reject("该标签已绑定其他长者，不能覆盖原归属。", "label_conflict")
        return existing
    try:
        connection.execute(
            insert(labels).values(
                uid=uid, resident_id=resident_id, actor_id=account.id, at=datetime.now(UTC)
            )
        )
    except IntegrityError as error:
        raise BusinessError(409, "label_conflict", "标签绑定已变化，请重新读取。") from error
    return dict(uid=uid, resident_id=resident_id)


def task_row(connection, task_id, lock=False):
    query = select(tasks).where(tasks.c.id == task_id)
    if lock:
        query = query.with_for_update()
    row = connection.execute(query).mappings().first()
    if row is None:
        not_found()
    return row


def owned_task(connection, account, task_id, terminal_id, lock=True):
    if lock:
        initial = task_row(connection, task_id)
        resident_row(connection, initial["resident_id"], lock=True)
    row = task_row(connection, task_id, lock)
    if row["terminal_id"] != terminal_id or row["owner_id"] != account.id:
        raise BusinessError(403, "task_owner", "请在领取任务的原终端、原账号操作。")
    return TaskView.model_validate(row["snapshot"])


def persist_task(connection, task):
    task.revision += 1
    task.updated_at = datetime.now(UTC)
    connection.execute(
        update(tasks)
        .where(tasks.c.id == task.id)
        .values(
            state=task.state.value,
            active=task.state not in (TaskState.completed, TaskState.cancelled),
            snapshot=task.model_dump(mode="json"),
            updated_at=task.updated_at,
        )
    )
    return task


def make_batches(connection, task_id, plan, device):
    batches = []
    for tray_index, tray in enumerate(plan.trays):
        for medicine in tray.medicines:
            previous = latest_parameters(connection, medicine.prescription.id)
            parameter, had_history = select_parameters(
                previous,
                medicine.prescription.id,
                medicine.prescription.medicine_id,
                medicine.prescription.data.feed_form.value,
                simulation=device.configuration.mode == DeviceMode.simulator,
            )
            matrix = [[0] * 7 for _ in range(4)]
            for day, amounts in enumerate(medicine.particles):
                column = 6 - day if device.configuration.reverse_columns else day
                for slot, count in enumerate(amounts):
                    matrix[device.configuration.rows[slot]][column] = count
            batches.append(
                BatchPlan(
                    index=len(batches),
                    tray=tray_index,
                    prescription_id=medicine.prescription.id,
                    medicine_id=medicine.prescription.medicine_id,
                    name=medicine.prescription.data.medicine_name,
                    strength=medicine.prescription.data.strength,
                    feed_form=medicine.prescription.data.feed_form.value,
                    purpose=tray.purpose,
                    total=medicine.total_particles,
                    matrix=matrix,
                    parameters=parameter,
                    learning_enabled=parameter.learning_enabled,
                    had_valid_history=had_history,
                )
            )
    return batches


def claim(connection, account, task_id, request):
    if connection.execute(select(tombstones.c.id).where(tombstones.c.id == task_id)).first():
        reject("该任务已删除，不能通过迟到请求重建。", "task_deleted")
    old = connection.execute(select(tasks).where(tasks.c.id == task_id)).mappings().first()
    if old:
        result = owned_task(connection, account, task_id, request.terminal_id)
        if result.plan_id != request.plan_id or result.device_id != request.device_id:
            conflict()
        return result
    preview = get_preview(request.plan_id, account, connection)
    if not preview.current:
        reject(preview.message, "stale_plan")
    row = (
        connection.execute(
            select(devices).where(devices.c.id == request.device_id).with_for_update()
        )
        .mappings()
        .first()
    )
    if row is None:
        not_found()
    device = device_view(row)
    config = device.configuration
    if config.terminal_id != request.terminal_id:
        reject("设备已固定到其他终端。")
    if config.mode == DeviceMode.hardware and not config.positions_verified:
        reject("须先完成并确认实体位置映射，才能下发真实计划。")
    active = connection.execute(
        select(tasks.c.id).where(
            tasks.c.active,
            (tasks.c.device_id == device.id)
            | (tasks.c.resident_id == preview.snapshot.resident_id),
        )
    ).first()
    if active:
        reject("这位长者或设备已有未结束任务，请处理原任务。", "already_claimed")
    bound = list(
        connection.execute(
            select(labels.c.uid).where(labels.c.resident_id == preview.snapshot.resident_id)
        ).scalars()
    )
    barcode_rows = (
        connection.execute(
            select(residents.c.id, residents.c.barcode).where(residents.c.barcode != "")
        )
        .mappings()
        .all()
    )
    bindings = [
        dict(source="barcode", value=r["barcode"], resident_id=r["id"]) for r in barcode_rows
    ]
    bindings += [
        dict(source="rfid", value=r["uid"], resident_id=r["resident_id"])
        for r in connection.execute(select(labels)).mappings()
    ]
    if not bound and not any(r["id"] == preview.snapshot.resident_id for r in barcode_rows):
        reject("请先为这位长者绑定新系统的药盒标签。", "label_required")
    now = datetime.now(UTC)
    task = TaskView(
        id=task_id,
        plan_id=request.plan_id,
        device_id=device.id,
        terminal_id=request.terminal_id,
        owner_id=account.id,
        revision=1,
        state=TaskState.claimed,
        plan=preview.snapshot,
        device=device,
        labels=bound,
        recognition_bindings=bindings,
        batches=make_batches(connection, task_id, preview.snapshot, device),
        sequence=0,
        completed_batches=[],
        counts=[0] * sum(len(t.medicines) for t in preview.snapshot.trays),
        started_at=None,
        updated_at=now,
    )
    try:
        connection.execute(
            insert(tasks).values(
                id=task.id,
                plan_id=task.plan_id,
                resident_id=task.plan.resident_id,
                device_id=task.device_id,
                terminal_id=task.terminal_id,
                owner_id=task.owner_id,
                active=True,
                state=task.state.value,
                snapshot=task.model_dump(mode="json"),
                updated_at=now,
            )
        )
    except IntegrityError as error:
        raise BusinessError(
            409, "already_claimed", "计划、长者或设备已被领取，请读取原任务。"
        ) from error
    return task


def start(connection, account, task_id, request):
    # Same lock order as claim: settings -> resident -> task. Never task -> resident.
    original = task_row(connection, task_id)
    preview = get_preview(original["plan_id"], account, connection)
    task = owned_task(connection, account, task_id, request.terminal_id)
    if task.state == TaskState.started:
        return task  # Lost response: no second permit or physical write.
    if task.state != TaskState.claimed or task.revision != request.expected_revision:
        conflict()
    if not preview.current:
        reject(preview.message, "stale_plan")
    observed = request.observed_at
    checked = request.checked_at or observed
    if (
        observed.tzinfo is None
        or checked.tzinfo is None
        or not -5 <= (datetime.now(UTC) - checked).total_seconds() <= 30
        or observed > checked
        or observed < task.plan.created_at
    ):
        reject("药盒识别已过期，请等待本次新反馈。", "stale_recognition")
    if request.barcode is not None:
        bound = connection.execute(
            select(residents.c.id).where(residents.c.barcode == request.barcode)
        ).scalar()
        in_snapshot = any(
            b.source == "barcode"
            and b.value == request.barcode
            and b.resident_id == task.plan.resident_id
            for b in task.recognition_bindings
        )
    else:
        bound = connection.execute(
            select(labels.c.resident_id).where(labels.c.uid == request.uid)
        ).scalar()
        in_snapshot = request.uid in task.labels
    if bound != task.plan.resident_id or not in_snapshot:
        reject("当前药盒不属于这位长者。", "wrong_resident")
    task.state = TaskState.started
    task.started_at = datetime.now(UTC)
    return persist_task(connection, task)


def sync(connection, account, task_id, request):
    task = owned_task(connection, account, task_id, request.terminal_id)
    for event in request.events:
        encoded = event.model_dump(mode="json")
        old = connection.execute(
            select(events.c.data).where(
                events.c.task_id == task.id, events.c.sequence == event.sequence
            )
        ).scalar()
        if old is not None:
            if old != encoded:
                conflict()
            continue
        if event.sequence != task.sequence + 1:
            reject("事件序号不连续，请先补传前面的记录。", "event_gap")
        if event.batch >= len(task.batches) or event.at.tzinfo is None:
            reject("批次或事件时间无效。")
        # Older Android builds could reconnect or enter recovery after cancellation.
        # Retain these diagnostics without reopening the task or accepting controls.
        late_idle_connection = event.kind == "connected" and event.detail == {}
        late_cancel_diagnostic = task.state == TaskState.cancelled and (
            (event.kind == "recovered" and event.detail == {})
            or (
                event.kind == "recovery"
                and set(event.detail) == {"message"}
                and isinstance(event.detail["message"], str)
            )
        )
        if task.state in (TaskState.completed, TaskState.cancelled) and not (
            late_idle_connection or late_cancel_diagnostic
        ):
            reject("任务已结束，不接受新的执行事件。")
        if (
            event.kind in ("count", "batch_finished", "collection_ready")
            and task.started_at is None
        ):
            reject("尚未取得中央启动许可。")
        if event.kind == "count":
            count = event.detail.get("count")
            if (
                type(count) is not int
                or not task.counts[event.batch] <= count <= task.batches[event.batch].total
            ):
                reject("计数倒退或超过目标，请核对原始反馈。")
            task.counts[event.batch] = count
        if event.kind == "batch_finished":
            if (
                event.batch != len(task.completed_batches)
                or task.counts[event.batch] != task.batches[event.batch].total
            ):
                reject("批次完成必须有顺序一致的计数及完成反馈。")
            if event.detail.get("feedback") != "machine_state:FINISH":
                reject("缺少当前批次完成反馈。")
            task.completed_batches.append(event.batch)
            if len(task.completed_batches) == len(task.batches):
                task.state = TaskState.awaiting_collection
        if event.kind == "collection_ready":
            config = task.device.configuration
            if task.state != TaskState.awaiting_collection:
                reject("取盒与就绪依据不完整，不能释放任务。")
            if config.barcode_removal_closes:
                if not barcode_collection_confirmed(connection, task, event.detail):
                    reject("缺少当前条码消失及收仓 ACK/DONE，不能释放任务。")
            elif not config.feedback_verified or (
                event.detail.get("absent") != task.device.configuration.tray_absent_line
                or event.detail.get("ready") != task.device.configuration.ready_line
            ):
                reject("取盒与就绪反馈不匹配。")
            task.state = TaskState.completed
        if event.kind == "cancelled":
            if event.detail.get("physical_scene_safe") is not True:
                reject("请先确认机器安全停稳并处理药盒和药物。")
            task.state = TaskState.cancelled
        connection.execute(
            insert(events).values(
                task_id=task.id,
                sequence=event.sequence,
                data=encoded,
                received_at=datetime.now(UTC),
            )
        )
        if event.kind in ("batch_finished", "cancelled"):
            finish_learning(connection, account, task, event.batch)
        task.sequence = event.sequence
    return persist_task(connection, task)


def barcode_collection_confirmed(connection, task, detail):
    codes = {
        b.value
        for b in task.recognition_bindings
        if b.source == "barcode" and b.resident_id == task.plan.resident_id
    }
    if len(codes) != 1:
        return False
    absent = "DISAPPEARED," + next(iter(codes))
    if detail != dict(source="barcode", absent=absent, ready="ACK,DONE"):
        return False
    stage = 0
    for record in connection.execute(
        select(events.c.data).where(events.c.task_id == task.id).order_by(events.c.sequence)
    ).scalars():
        kind, data = record["kind"], record["detail"]
        if kind in ("cancel_intent", "recovery", "recovered"):
            stage = 0
        elif kind == "batch_finished" and record["batch"] == len(task.batches) - 1:
            stage = 1
        elif stage == 1 and kind == "command_done" and data.get("command") == "open":
            stage = 2
        elif stage >= 3 and kind == "feedback" and data.get("kind") == "barcodeAppeared":
            stage = 0
        elif stage == 2 and kind == "feedback" and data.get("raw") == absent:
            stage = 3
        elif stage == 3 and kind == "written" and data.get("command") == "close":
            stage = 4
        elif stage == 4 and kind == "ack" and data.get("command") == "close":
            stage = 5
        elif stage == 5 and kind == "command_done" and data.get("command") == "close":
            stage = 6
    return stage == 6


def finish_learning(connection, account, task, batch_index):
    if any(result.batch == batch_index for result in task.learning_results):
        return
    batch = task.batches[batch_index]
    records = connection.execute(
        select(events.c.data).where(events.c.task_id == task.id).order_by(events.c.sequence)
    ).scalars()
    result = evaluate_batch(batch, records)
    if result.status == "calculated" and task.device.configuration.mode == DeviceMode.simulator:
        result.status = "simulated"
        result.message = "模拟学习结果已记录，不更新实机参数。"
    if result.status == "calculated":
        # owned_task holds the resident lock, also used by manual parameter/shape updates.
        source = prescription_row(connection, task.plan.resident_id, batch.prescription_id)
        latest = latest_parameters(connection, batch.prescription_id)
        current_revision = latest.revision if latest else 0
        if (
            current_revision != batch.parameters.revision
            or source["medicine_id"] != batch.medicine_id
            or source["data"]["feed_form"] != batch.feed_form
        ):
            result.status = "conflict"
            result.message = "参数已变化，请刷新后重新调整；本批计算保留为历史，未覆盖当前参数。"
        else:
            learned = ParameterView(
                prescription_id=batch.prescription_id,
                medicine_id=batch.medicine_id,
                revision=current_revision + 1,
                turntable=result.turntable,
                gate=result.gate,
                simulation_only=task.device.configuration.mode == DeviceMode.simulator,
                learning_enabled=True,
                has_values=True,
                source_task_id=task.id,
                source_batch=batch.index,
                feed_form=batch.feed_form,
            )
            connection.execute(
                insert(parameters).values(
                    **learned.model_dump(), actor_id=account.id, at=datetime.now(UTC)
                )
            )
            result.applied_revision = learned.revision
            result.status = "saved"
            result.message = "已保存本条目下次参数。"
    task.learning_results.append(result)


def cancel_unstarted(connection, account, task_id, request):
    task = owned_task(connection, account, task_id, request.terminal_id)
    if task.state == TaskState.cancelled:
        return task
    if task.state != TaskState.claimed:
        reject("已取得启动许可的任务必须从原终端受控结束。")
    if not request.physical_scene_safe:
        reject("取消前请确认机器、药盒和药物已安全处理。")
    task.state = TaskState.cancelled
    return persist_task(connection, task)


def discard(connection, account, task_id, request):
    if connection.execute(select(tombstones.c.id).where(tombstones.c.id == task_id)).first():
        return
    task = owned_task(connection, account, task_id, request.terminal_id)
    if task.state in (TaskState.completed, TaskState.cancelled) or not request.physical_scene_safe:
        reject("仅允许在现场已安全处理后删除当前未结束任务。")
    connection.execute(insert(tombstones).values(id=task_id))
    connection.execute(delete(parameters).where(parameters.c.source_task_id == task_id))
    connection.execute(delete(tasks).where(tasks.c.id == task_id))
    connection.execute(delete(previews).where(previews.c.id == task.plan_id))
