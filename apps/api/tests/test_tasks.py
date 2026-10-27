from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime, timedelta
from uuid import uuid4

from fastapi.testclient import TestClient
from test_business import prescription, resident, world  # noqa: F401

from pillxai_api.app import create_app


def setup(client, token, *, mode="simulator", with_parameters=True, days=2):
    rid = resident(client, token).json()["id"]
    pid, device, terminal = map(str, (uuid4(), uuid4(), uuid4()))
    source = client.put(
        f"/residents/{rid}/prescriptions/{pid}",
        headers=token,
        json=dict(
            expected_revision=0, data=prescription() | dict(start_date="2026-01-01", end_date=None)
        ),
    ).json()
    if with_parameters:
        save_initial_parameters(client, token, rid, pid, source)
    config = dict(
        name="测试设备",
        identity=str(uuid4()),
        terminal_id=terminal,
        mode=mode,
        rows=[2, 1, 0, 3],
        positions_verified=True,
        feedback_verified=True,
        tray_present_line="test:present",
        tray_absent_line="test:absent",
        ready_line="test:ready",
    )
    assert (
        client.put(
            f"/devices/{device}",
            headers=token,
            json=dict(expected_revision=0, configuration=config),
        ).status_code
        == 200
    )
    uid = uuid4().hex.upper()
    assert (
        client.post(f"/residents/{rid}/labels", headers=token, json=dict(uid=uid)).status_code
        == 200
    )
    preview = client.post(
        f"/residents/{rid}/plans/preview", headers=token, json=dict(days=days)
    ).json()
    return dict(
        rid=rid,
        pid=pid,
        device=device,
        terminal=terminal,
        config=config,
        uid=uid,
        plan=preview["snapshot"],
    )


def save_initial_parameters(client, token, rid, pid, source):
    assert (
        client.put(
            f"/residents/{rid}/prescriptions/{pid}/parameters",
            headers=token,
            json=dict(
                expected_revision=0, medicine_id=source["medicine_id"], turntable=1, gate=0.5
            ),
        ).status_code
        == 200
    )


def claim(client, token, fixture, task_id=None):
    return client.put(
        f"/tasks/{task_id or uuid4()}",
        headers=token,
        json=dict(
            plan_id=fixture["plan"]["id"],
            device_id=fixture["device"],
            terminal_id=fixture["terminal"],
        ),
    )


def start(client, token, fixture, task, **changes):
    return client.post(
        f"/tasks/{task['id']}/start",
        headers=token,
        json=dict(
            terminal_id=fixture["terminal"],
            expected_revision=task["revision"],
            uid=fixture["uid"],
            observed_at=datetime.now(UTC).isoformat(),
        )
        | changes,
    )


def event(sequence, kind, detail=None):
    return dict(
        sequence=sequence, kind=kind, batch=0, at=datetime.now(UTC).isoformat(), detail=detail or {}
    )


def upload(client, token, fixture, task, values):
    return client.post(
        f"/tasks/{task['id']}/events",
        headers=token,
        json=dict(terminal_id=fixture["terminal"], events=values),
    )


def test_hardware_parameters_and_stale_start(world):  # noqa: F811
    client, tokens, _, _ = world
    token = tokens["admin"]
    f = setup(client, token, mode="hardware")
    path = f"/residents/{f['rid']}/prescriptions/{f['pid']}/parameters"
    params = client.get(path, headers=token).json()
    body = dict(
        expected_revision=params["revision"],
        medicine_id=params["medicine_id"],
        turntable=1,
        gate=0.5,
        simulation_only=True,
    )
    assert client.put(path, headers=token, json=body).status_code == 200
    body.update(expected_revision=2, simulation_only=False)
    assert client.put(path, headers=token, json=body).status_code == 200
    task = claim(client, token, f).json()
    changed = client.put(
        f"/residents/{f['rid']}",
        headers=token,
        json=dict(expected_revision=1, data=dict(name="版本已变长者", bed="")),
    )
    assert changed.status_code == 200
    assert start(client, token, f, task).status_code == 409


def test_claim_concurrency_owner_recognition_and_immutable_plan(world):  # noqa: F811
    client, tokens, _, settings = world
    f = setup(client, tokens["admin"])

    def attempt(_):
        with TestClient(create_app(settings)) as other:
            return claim(other, tokens["admin"], f)

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(attempt, range(2)))
    assert sorted(r.status_code for r in results) == [200, 409]
    task = next(r.json() for r in results if r.status_code == 200)
    assert claim(client, tokens["admin"], f, task["id"]).json() == task
    assert task["batches"][0]["matrix"][2][:2] == [1, 1]
    assert task["batches"][0]["matrix"][0][:2] == [1, 1]
    assert start(client, tokens["other"], f, task).status_code == 403
    assert start(client, tokens["admin"], f, task, uid="0000").status_code == 409
    assert (
        start(
            client,
            tokens["admin"],
            f,
            task,
            observed_at=(datetime.now(UTC) - timedelta(seconds=45)).isoformat(),
        ).status_code
        == 409
    )
    assert (
        client.put(
            f"/devices/{f['device']}",
            headers=tokens["admin"],
            json=dict(expected_revision=1, configuration=f["config"]),
        ).status_code
        == 409
    )
    started = start(client, tokens["admin"], f, task)
    assert started.status_code == 200
    assert start(client, tokens["admin"], f, task).json() == started.json()
    resident(client, tokens["admin"], resident_id=f["rid"], revision=1, name="后来修改")
    assert (
        client.get(f"/tasks/{task['id']}", headers=tokens["staff"]).json()["plan"] == task["plan"]
    )


def test_result_deduplication_collection_and_coverage(world):  # noqa: F811
    client, tokens, _, _ = world
    f = setup(client, tokens["admin"], mode="hardware")
    task = claim(client, tokens["admin"], f).json()
    total = task["batches"][0]["total"]
    assert (
        upload(client, tokens["admin"], f, task, [event(1, "count", {"count": total})]).status_code
        == 409
    )
    assert start(client, tokens["admin"], f, task).status_code == 200
    assert (
        upload(client, tokens["admin"], f, task, [event(2, "count", {"count": total})]).status_code
        == 409
    )
    data = [
        event(1, "count", {"count": total}),
        event(2, "batch_finished", {"feedback": "machine_state:FINISH"}),
    ]
    result = upload(client, tokens["admin"], f, task, data)
    assert result.status_code == 200, result.text
    assert result.json()["state"] == "awaiting_collection"
    assert upload(client, tokens["admin"], f, task, data).json()["completed_batches"] == [0]
    assert claim(client, tokens["admin"], f).status_code == 409
    future = client.post(
        f"/residents/{f['rid']}/plans/preview", headers=tokens["admin"], json={}
    ).json()
    assert future["snapshot"]["dates"][0] > f["plan"]["dates"][-1]
    assert (
        upload(
            client,
            tokens["admin"],
            f,
            task,
            [event(3, "collection_ready", {"absent": "NO CARD", "ready": "DONE"})],
        ).status_code
        == 409
    )
    collected = upload(
        client,
        tokens["admin"],
        f,
        task,
        [event(3, "collection_ready", {"absent": "test:absent", "ready": "test:ready"})],
    )
    assert collected.json()["state"] == "completed"
    assert len(client.get(f"/tasks/{task['id']}/events", headers=tokens["admin"]).json()) == 3


def test_late_idle_connection_does_not_block_cancelled_task_sync(world):  # noqa: F811
    client, tokens, _, _ = world
    f = setup(client, tokens["admin"])
    task = claim(client, tokens["admin"], f).json()
    cancelled = event(1, "cancelled", {"physical_scene_safe": True})
    assert upload(client, tokens["admin"], f, task, [cancelled]).json()["state"] == "cancelled"
    connected = event(2, "connected")
    replay = upload(client, tokens["admin"], f, task, [cancelled, connected])
    assert replay.status_code == 200 and replay.json()["sequence"] == 2
    assert (
        upload(client, tokens["admin"], f, task, [event(3, "count", {"count": 1})]).status_code
        == 409
    )
    assert (
        upload(
            client, tokens["admin"], f, task, [event(3, "connected", {"data": "unexpected"})]
        ).status_code
        == 409
    )
    diagnostics = [
        event(3, "recovery", {"message": "设备连接已断开，请核对现场。"}),
        event(4, "recovered"),
    ]
    settled = upload(client, tokens["admin"], f, task, diagnostics)
    assert settled.status_code == 200
    assert settled.json()["state"] == "cancelled"
    assert settled.json()["sequence"] == 4
    assert upload(client, tokens["admin"], f, task, diagnostics).status_code == 200
    assert upload(
        client, tokens["admin"], f, task, [event(5, "write_intent", {"command": "open"})]
    ).status_code == 409


def test_simulator_discard_tombstone_and_parameter_identity(world):  # noqa: F811
    client, tokens, _, _ = world
    f = setup(client, tokens["admin"])
    task = claim(client, tokens["admin"], f).json()
    assert start(client, tokens["admin"], f, task).status_code == 200
    total = task["batches"][0]["total"]
    assert (
        upload(
            client,
            tokens["admin"],
            f,
            task,
            [
                event(1, "count", {"count": total}),
                event(2, "batch_finished", {"feedback": "machine_state:FINISH"}),
            ],
        ).status_code
        == 200
    )
    preview = client.post(
        f"/residents/{f['rid']}/plans/preview", headers=tokens["admin"], json={}
    ).json()
    assert preview["snapshot"]["dates"][0] == f["plan"]["dates"][0]
    assert (
        client.post(
            f"/tasks/{task['id']}/discard",
            headers=tokens["admin"],
            json=dict(terminal_id=f["terminal"], physical_scene_safe=True),
        ).status_code
        == 200
    )
    assert client.get(f"/tasks/{task['id']}", headers=tokens["admin"]).status_code == 404
    assert claim(client, tokens["admin"], f, task["id"]).status_code == 409
    assert (
        upload(client, tokens["admin"], f, task, [event(3, "count", {"count": 1})]).status_code
        == 404
    )
    other = resident(client, tokens["admin"]).json()["id"]
    assert (
        client.post(
            f"/residents/{other}/labels", headers=tokens["admin"], json=dict(uid=f["uid"])
        ).status_code
        == 409
    )
    changed = prescription() | dict(medicine_name="新形态", start_date="2026-01-01", end_date=None)
    assert (
        client.put(
            f"/residents/{f['rid']}/prescriptions/{f['pid']}",
            headers=tokens["admin"],
            json=dict(expected_revision=1, data=changed),
        ).status_code
        == 200
    )
    f["plan"] = client.post(
        f"/residents/{f['rid']}/plans/preview", headers=tokens["admin"], json={}
    ).json()["snapshot"]
    next_task = claim(client, tokens["admin"], f).json()
    assert next_task["batches"][0]["parameters"]["gate"] == 0.7
    assert not next_task["batches"][0]["had_valid_history"]
