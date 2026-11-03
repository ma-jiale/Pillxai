from types import SimpleNamespace
from unittest.mock import Mock
from uuid import UUID, uuid4

import pytest
from sqlalchemy import create_engine
from test_business import world  # noqa: F401
from test_tasks import claim, collection_events, event, setup, start, upload

from pillxai_api.tasks.coverage import completed_until
from pillxai_api.tasks.service import barcode_collection_confirmed
from pillxai_api.tasks.skipping import confirmed_skip


def skip_events(manual=False, all_remaining=False):
    detail = dict(manual=manual, all_remaining=all_remaining)
    return [
        event(1, "count", {"count": 1}),
        event(2, "skip_requested", detail),
        event(3, "written", {"command": "stop_skip"}),
        event(4, "ack", {"command": "stop_skip"}),
        event(5, "command_done", {"command": "stop_skip"}),
        event(6, "written", {"command": "exit"}),
        event(7, "ack", {"command": "exit"}),
        event(8, "command_done", {"command": "exit"}),
        event(9, "skip_completed", detail),
    ]


@pytest.mark.parametrize("manual,all_remaining", [(False, False), (True, False), (False, True)])
def test_skip_sync_keeps_counts_and_only_manual_confirms_coverage(
    world, manual, all_remaining  # noqa: F811
):
    client, tokens, _, settings = world
    token = tokens["admin"]
    fixture = setup(client, token, mode="hardware")
    task = claim(client, token, fixture).json()
    assert task["skip_protocol"] == 1
    assert start(client, token, fixture, task).status_code == 200
    values = skip_events(manual, all_remaining)
    # Chunks split across requests still require persisted exit evidence.
    assert upload(client, token, fixture, task, values[:7]).status_code == 200
    rejected = upload(
        client, token, fixture, task, [event(8, "skip_completed", values[-1]["detail"])]
    )
    assert rejected.status_code == 409
    result = upload(client, token, fixture, task, values[7:])
    assert result.status_code == 200, result.text
    saved = result.json()
    assert saved["counts"] == [1]
    assert saved["completed_batches"] == []
    assert saved["manual_batches"] == ([0] if manual else [])
    assert saved["skipped_batches"] == ([] if manual else [0])
    assert saved["state"] == "awaiting_collection"
    assert saved["learning_results"] == []
    collected = collection_events(task, 10)
    result = upload(client, token, fixture, task, collected)
    assert result.status_code == 200, result.text
    assert result.json()["state"] == "completed"
    assert upload(client, token, fixture, task, values + collected).status_code == 200
    engine = create_engine(settings.database_url)
    with engine.connect() as connection:
        assert (completed_until(connection, UUID(fixture["rid"])) is not None) == manual
    engine.dispose()


def test_skip_evidence_rejects_missing_ack_recovery_and_invalid_confirmation():
    records = skip_events()
    detail = records[-1]["detail"]
    assert confirmed_skip(records[:-1], 0, detail)
    assert not confirmed_skip(records[:6] + records[7:-1], 0, detail)
    assert not confirmed_skip(records[:-1] + [event(9, "recovered")], 0, detail)
    assert not confirmed_skip(records[:-1], 0, dict(manual=True, all_remaining=True))


def test_retry_writes_never_replace_ack_or_duplicate_skip_completion():
    records = skip_events()
    retries = [
        event(1, "retry_write_intent", {"command": "exit", "attempt": 2}),
        event(1, "retry_written", {"command": "exit", "attempt": 2}),
    ]
    detail = records[-1]["detail"]
    assert confirmed_skip(records[:6] + retries + records[6:-1], 0, detail)
    assert not confirmed_skip(records[:6] + retries + records[7:-1], 0, detail)


@pytest.mark.parametrize("removed_before", [True, False])
def test_counter_review_upload(world, removed_before):  # noqa: F811
    client, tokens, _, _ = world
    token = tokens["admin"]
    fixture = setup(client, token, mode="hardware")
    task = claim(client, token, fixture).json()
    assert start(client, token, fixture, task).status_code == 200
    values = [
        event(1, "count", {"count": 1}),
        event(2, "feedback", {"raw": "machine_state:CNT_ERR"}),
        event(3, "counter_review_requested"),
    ]
    detail = dict(source="counter_review", manual=True, all_remaining=False)
    for command in ["stop_review", "exit", "open"]:
        for kind in ["written", "ack", "command_done"]:
            values.append(event(len(values) + 1, kind, {"command": command}))
    assert upload(client, token, fixture, task, values[:-1]).status_code == 200
    rejected = upload(client, token, fixture, task, [event(len(values), "skip_completed", detail)])
    assert rejected.status_code == 409
    if removed_before:
        for kind in ["written", "ack", "command_done"]:
            values.append(event(len(values) + 1, kind, {"command": "release_stall_3"}))
    tail = collection_events(task, len(values))[1:]
    tail.insert(1 if removed_before else 0, event(0, "skip_completed", detail))
    for i, item in enumerate(tail, len(values) + 1):
        item["sequence"] = i
    result = upload(client, token, fixture, task, values + tail)
    assert result.status_code == 200, result.text
    assert result.json()["manual_batches"] == [0]
    assert result.json()["counts"] == [1]
    assert result.json()["learning_results"] == []
    assert result.json()["state"] == "completed"
    assert upload(client, token, fixture, task, values + tail).status_code == 200


def test_barcode_collection_retry_keeps_result_but_requires_fresh_removal():
    task = SimpleNamespace(id=uuid4(), batches=[None] * 3,
        recognition_bindings=[SimpleNamespace(source="barcode", value="000010", resident_id="r")],
        plan=SimpleNamespace(resident_id="r"))
    evidence = dict(source="barcode", absent="DISAPPEARED,000010", ready="ACK,DONE")
    records = [event(1, "skip_completed", dict(all_remaining=True, manual=False)),
        event(2, "recovery")]
    connection = Mock()
    connection.execute.return_value.scalars.return_value = records
    assert not barcode_collection_confirmed(connection, task, evidence)
    records.extend([
        event(3, "command_done", {"command": "open"}),
        event(4, "feedback", {"raw": "DISAPPEARED,000010"}),
        event(5, "written", {"command": "close"}),
        event(6, "ack", {"command": "close"}),
        event(7, "command_done", {"command": "close"}),
    ])
    assert barcode_collection_confirmed(connection, task, evidence)


def test_machine_completion_after_skip_keeps_partial_result(world):  # noqa: F811
    from test_business import prescription

    client, tokens, _, _ = world
    token = tokens["admin"]
    fixture = setup(client, token, days=1)
    response = client.put(
        f"/residents/{fixture['rid']}/prescriptions/{uuid4()}", headers=token,
        json=dict(expected_revision=0, data=prescription() | dict(
            medicine_name="第二种药", start_date="2026-01-01", end_date=None,
        )),
    )
    assert response.status_code == 200
    fixture["plan"] = client.post(
        f"/residents/{fixture['rid']}/plans/preview", headers=token, json=dict(days=1)
    ).json()["snapshot"]
    task = claim(client, token, fixture).json()
    assert len(task["batches"]) == 2
    assert start(client, token, fixture, task).status_code == 200
    assert upload(client, token, fixture, task, skip_events()).status_code == 200
    values = [
        event(10, "count", {"count": task["batches"][1]["total"]}) | {"batch": 1},
        event(11, "batch_finished", {"feedback": "machine_state:FINISH"}) | {"batch": 1},
    ]
    response = upload(client, token, fixture, task, values)
    assert response.status_code == 200, response.text
    assert response.json()["completed_batches"] == [1]
    assert response.json()["skipped_batches"] == [0]
    assert response.json()["state"] == "awaiting_collection"
