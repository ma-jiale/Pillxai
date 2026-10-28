from uuid import uuid4

import pytest
from test_business import world  # noqa: F401
from test_tasks import claim, event, setup, start, upload

from pillxai_api.tasks.learning import evaluate_batch, next_values, select_parameters
from pillxai_api.tasks.models import BatchPlan, ParameterView


def batch(history=False, enabled=True):
    pid, mid = uuid4(), uuid4()
    return BatchPlan(
        index=0,
        tray=0,
        prescription_id=pid,
        medicine_id=mid,
        name="测试",
        strength="测试",
        feed_form="whole",
        purpose="测试",
        total=30,
        matrix=[[0] * 7 for _ in range(4)],
        learning_enabled=enabled,
        had_valid_history=history,
        parameters=ParameterView(
            prescription_id=pid, medicine_id=mid, revision=0, turntable=0.2, gate=0.7
        ),
    )


def facts(widths, *, manual=None, initial=0.7, fault=None):
    result = [event(1, "batch_started", dict(gate=initial, turntable=0.2))]
    for number, width in enumerate(widths, 1):
        result.append(
            event(len(result) + 1, "feedback", dict(kind="count", count=number, width=str(width)))
        )
    if manual is not None:
        result.append(event(len(result) + 1, "manual_gate_written", dict(gate=manual)))
    if fault:
        result.append(event(len(result) + 1, fault))
    result.append(event(len(result) + 1, "batch_finished", dict(feedback="machine_state:FINISH")))
    return result


@pytest.mark.parametrize(
    "pulse,history,manual,speed,gate",
    [
        (20, False, None, 0.30, 0.305),
        (20, True, None, 0.30, 0.70),
        (13, False, 0.50, 0.23, 0.5985),
        (20, True, 0.75, 0.30, 0.5815),
        (3, False, None, 0.15, 0.89),
        (200, False, None, 0.36, 0.08),
        (13, True, 0.69, 0.23, 0.697),  # Equality uses the 70/30 branch.
        (13, True, 0.70, 0.23, 0.697),
    ],
)
def test_rule_examples(pulse, history, manual, speed, gate):
    assert next_values(pulse, 0.7, history, manual) == pytest.approx((speed, gate))


def test_selection_pair_policy_shape_and_unclamped_history():
    pid, mid = uuid4(), uuid4()
    previous = ParameterView(
        prescription_id=pid,
        medicine_id=mid,
        revision=3,
        turntable=0.8,
        gate=0.99,
        feed_form="whole",
    )

    def selected(value=previous, shape="whole"):
        return select_parameters(value, pid, mid, shape, simulation=False)

    actual, valid = selected()
    assert valid and (actual.turntable, actual.gate) == (0.8, 0.99)
    for value in (
        None,
        previous.model_copy(update={"gate": 0}),
        previous.model_copy(update={"turntable": 0}),
        previous.model_copy(update={"has_values": False}),
        previous.model_copy(update={"simulation_only": True}),
        previous.model_copy(update={"learning_enabled": False}),
    ):
        actual, valid = selected(value)
        assert not valid and (actual.turntable, actual.gate) == (0.2, 0.7)
    assert selected(shape="half")[0].gate == 0.7
    assert next_values(20, 0.99, True)[1] == 0.99


def test_filtering_even_median_and_last_successful_manual_value():
    rows = facts([3, 200, 10, 12, 14, 16, 18, 20, 2, 201])
    rows.insert(0, event(0, "feedback", dict(kind="count", count=200, width="20")))
    rows.insert(4, event(4, "feedback", dict(kind="count", count=1, width="100")))
    rows.insert(-1, event(20, "manual_gate_written", dict(gate=0.1)))
    rows.insert(-1, event(21, "manual_gate_written", dict(gate=0.5)))
    rows.insert(-1, event(22, "write_intent", dict(command="manual_gate", gate=0.01)))
    rows.append(event(24, "manual_gate_written", dict(gate=0.01)))
    result = evaluate_batch(batch(), rows)
    assert result.status == "calculated"
    assert result.median == 15
    assert result.evidence.valid_samples == 8
    assert result.evidence.manual_gate == 0.5
    assert [r.reason for r in result.evidence.samples].count("accepted") == 8
    assert result.evidence.samples[0].reason == "outside_batch"
    assert result.gate == pytest.approx(next_values(15, 0.7, False, 0.5)[1])


@pytest.mark.parametrize(
    "fault", ["recovery", "recovered", "cancel_intent", "skipped", "manual_completion"]
)
def test_abnormal_batch_never_learns(fault):
    assert evaluate_batch(batch(), facts([20] * 7, fault=fault)).status == "abnormal"


@pytest.mark.parametrize(
    "position,expected", [(0, "calculated"), (2, "abnormal"), (-1, "calculated")]
)
def test_opening_stall_is_diagnostic_only_outside_running_batch(position, expected):
    rows = facts([20] * 7)
    observation = event(0, "feedback", dict(
        kind="stalled", raw="stalled:3", count=3, ignored_reason="opening_phase"
    ))
    if position == -1:
        rows.append(observation)
    else:
        rows.insert(position, observation)
    assert evaluate_batch(batch(), rows).status == expected
    observation["detail"].pop("ignored_reason")
    assert evaluate_batch(batch(), rows).status == "abnormal"


def test_sample_threshold_disabled_prestart_and_cross_batch():
    assert evaluate_batch(batch(), facts([20] * 6)).status == "insufficient"
    assert evaluate_batch(batch(enabled=False), facts([20] * 7)).status == "disabled"
    rows = facts([20] * 7, initial=0.6)
    rows.insert(0, event(0, "manual_gate_written", dict(gate=0.6)))
    result = evaluate_batch(batch(history=True), rows)
    assert result.gate == 0.6 and result.evidence.manual_gate is None
    for row in rows[1:5]:
        row["batch"] = 1
    assert evaluate_batch(batch(), rows).status != "calculated"


def complete_events(task, widths=None):
    rows = facts(widths or [20] * 7)
    rows[0]["detail"]["turntable"] = task["batches"][0]["parameters"]["turntable"]
    rows[0]["detail"]["gate"] = task["batches"][0]["parameters"]["gate"]
    rows.insert(-1, event(0, "count", dict(count=task["batches"][0]["total"])))
    for i, row in enumerate(rows, 1):
        row["sequence"] = i
    return rows


def test_first_batch_paged_upload_idempotency_and_next_profile(world):  # noqa: F811
    client, tokens, _, _ = world
    token = tokens["admin"]
    f = setup(client, token, mode="hardware", with_parameters=False, days=7)
    task = claim(client, token, f).json()
    assert task["batches"][0]["parameters"]["gate"] == 0.7
    assert task["batches"][0]["parameters"]["revision"] == 0
    assert task["batches"][0]["learning_enabled"]
    assert start(client, token, f, task).status_code == 200
    values = complete_events(task)
    values.insert(0, event(0, "feedback", dict(
        kind="stalled", raw="stalled:3", count=3, ignored_reason="opening_phase"
    )))
    for sequence, value in enumerate(values, 1):
        value["sequence"] = sequence
    assert upload(client, token, f, task, values[:5]).status_code == 200
    path = f"/residents/{f['rid']}/prescriptions/{f['pid']}/parameters"
    assert client.get(path, headers=token).json() is None
    response = upload(client, token, f, task, values[5:])
    assert response.status_code == 200, response.text
    assert response.json()["learning_results"][0]["status"] == "saved"
    saved = client.get(path, headers=token).json()
    assert (saved["turntable"], saved["gate"]) == pytest.approx((0.30, 0.305))
    assert saved["source_task_id"] == task["id"] and saved["source_batch"] == 0
    assert upload(client, token, f, task, values).status_code == 200
    assert client.get(path, headers=token).json()["revision"] == 1
    effective, valid = select_parameters(
        ParameterView.model_validate(saved),
        task_batch_id(task, "prescription_id"),
        task_batch_id(task, "medicine_id"),
        "half",
        simulation=False,
    )
    assert valid and effective.gate == pytest.approx(0.305)


def task_batch_id(task, key):
    from uuid import UUID

    return UUID(task["batches"][0][key])


@pytest.mark.parametrize("change", ["parameters", "shape"])
def test_delayed_result_preserves_new_parameters_or_shape(world, change):  # noqa: F811
    client, tokens, _, _ = world
    token = tokens["admin"]
    f = setup(client, token, mode="hardware", with_parameters=False, days=7)
    task = claim(client, token, f).json()
    assert start(client, token, f, task).status_code == 200
    path = f"/residents/{f['rid']}/prescriptions/{f['pid']}"
    if change == "parameters":
        response = client.put(
            path + "/parameters",
            headers=token,
            json=dict(
                expected_revision=0,
                medicine_id=task["batches"][0]["medicine_id"],
                turntable=0.25,
                gate=0.8,
            ),
        )
    else:
        data = f["plan"]["sources"][0]["data"] | dict(
            feed_form="whole", doses=dict(morning="1", noon="0", evening="1", night="0")
        )
        response = client.put(path, headers=token, json=dict(expected_revision=1, data=data))
    assert response.status_code == 200, response.text
    result = upload(client, token, f, task, complete_events(task))
    assert result.status_code == 200, result.text
    learning = result.json()["learning_results"][0]
    assert learning["status"] == "conflict" and learning["gate"] == pytest.approx(0.305)
    saved = client.get(path + "/parameters", headers=token).json()
    assert saved is None if change == "shape" else saved["gate"] == 0.8


def test_simulator_calculation_does_not_create_real_parameters(world):  # noqa: F811
    client, tokens, _, _ = world
    token = tokens["admin"]
    f = setup(client, token, with_parameters=False, days=7)
    task = claim(client, token, f).json()
    assert start(client, token, f, task).status_code == 200
    result = upload(client, token, f, task, complete_events(task)).json()
    assert result["learning_results"][0]["status"] == "simulated"
    assert (
        client.get(
            f"/residents/{f['rid']}/prescriptions/{f['pid']}/parameters", headers=token
        ).json()
        is None
    )


def test_learning_disabled_keeps_history_and_uses_defaults(world):  # noqa: F811
    client, tokens, _, _ = world
    token = tokens["admin"]
    f = setup(client, token, mode="hardware", days=7)
    path = f"/residents/{f['rid']}/prescriptions/{f['pid']}/parameters"
    original = client.get(path, headers=token).json()
    saved = client.put(
        path,
        headers=token,
        json=dict(
            expected_revision=original["revision"],
            medicine_id=original["medicine_id"],
            turntable=original["turntable"],
            gate=original["gate"],
            learning_enabled=False,
        ),
    ).json()
    task = claim(client, token, f).json()
    assert task["batches"][0]["parameters"]["turntable"] == 0.2
    assert task["batches"][0]["parameters"]["gate"] == 0.7
    assert not task["batches"][0]["learning_enabled"]
    assert start(client, token, f, task).status_code == 200
    result = upload(client, token, f, task, complete_events(task)).json()
    assert result["learning_results"][0]["status"] == "disabled"
    assert client.get(path, headers=token).json() == saved


def test_discard_removes_learning_from_deleted_test_task(world):  # noqa: F811
    client, tokens, _, _ = world
    token = tokens["admin"]
    f = setup(client, token, mode="hardware", with_parameters=False, days=7)
    task = claim(client, token, f).json()
    assert start(client, token, f, task).status_code == 200
    result = upload(client, token, f, task, complete_events(task)).json()
    assert result["learning_results"][0]["status"] == "saved"
    path = f"/residents/{f['rid']}/prescriptions/{f['pid']}/parameters"
    assert client.get(path, headers=token).json()["source_task_id"] == task["id"]
    assert (
        client.post(
            f"/tasks/{task['id']}/discard",
            headers=token,
            json=dict(terminal_id=f["terminal"], physical_scene_safe=True),
        ).status_code
        == 200
    )
    assert client.get(path, headers=token).json() is None
