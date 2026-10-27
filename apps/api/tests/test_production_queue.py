# ruff: noqa: F811
from datetime import date, timedelta

from test_business import world  # noqa: F401
from test_tasks import claim, event, setup, start, upload


def test_preparation_queue_uses_real_coverage_and_keeps_invalid_demand(world):
    client, tokens, _, _ = world
    token = tokens["admin"]
    f = setup(client, token, mode="hardware", days=7)

    def row():
        response = client.get("/preparation", headers=token)
        assert response.status_code == 200, response.text
        return next(item for item in response.json() if item["resident_id"] == f["rid"])

    assert row()["early"] is False
    assert row()["medicine_count"] == 1
    task = claim(client, token, f).json()
    task = start(client, token, f, task).json()
    total = task["batches"][0]["total"]
    result = upload(
        client,
        token,
        f,
        task,
        [
            event(1, "count", {"count": total}),
            event(2, "batch_finished", {"feedback": "machine_state:FINISH"}),
            event(3, "collection_ready", {"absent": "test:absent", "ready": "test:ready"}),
        ],
    )
    assert result.status_code == 200, result.text
    item = row()
    assert item["early"] is True
    assert (
        item["dates"][0]
        == (date.fromisoformat(f["plan"]["dates"][-1]) + timedelta(days=1)).isoformat()
    )
    prescription = client.get(f"/residents/{f['rid']}/prescriptions", headers=token).json()[0]

    def bedtime(enabled):
        settings = client.get("/settings", headers=token).json()
        revision = settings.pop("revision")
        settings.pop("timezone")
        assert (
            client.put(
                "/settings",
                headers=token,
                json=settings | {"expected_revision": revision, "bedtime_enabled": enabled},
            ).status_code
            == 200
        )

    bedtime(True)
    prescription["data"]["doses"]["night"] = "0.5"
    assert (
        client.put(
            f"/residents/{f['rid']}/prescriptions/{f['pid']}",
            headers=token,
            json={"expected_revision": prescription["revision"], "data": prescription["data"]},
        ).status_code
        == 200
    )
    bedtime(False)
    assert "睡前" in row()["issue"]


def test_barcode_collection_requires_ordered_close_evidence(world):
    client, tokens, _, _ = world
    token = tokens["admin"]
    f = setup(client, token)
    profile = client.get(f"/residents/{f['rid']}", headers=token).json()
    code = f["rid"].replace("-", "")
    assert (
        client.put(
            f"/residents/{f['rid']}",
            headers=token,
            json={
                "expected_revision": profile["revision"],
                "data": profile["data"] | {"barcode": code},
            },
        ).status_code
        == 200
    )
    assert (
        client.put(
            f"/devices/{f['device']}",
            headers=token,
            json={
                "expected_revision": 1,
                "configuration": f["config"]
                | {"barcode_removal_closes": True, "feedback_verified": False},
            },
        ).status_code
        == 200
    )
    f["plan"] = client.post(
        f"/residents/{f['rid']}/plans/preview", headers=token, json={"days": 2}
    ).json()["snapshot"]
    task = claim(client, token, f).json()
    task = start(client, token, f, task).json()
    detail = {"source": "barcode", "absent": "DISAPPEARED," + code, "ready": "ACK,DONE"}
    assert (
        upload(
            client,
            token,
            f,
            task,
            [
                event(1, "count", {"count": task["batches"][0]["total"]}),
                event(2, "batch_finished", {"feedback": "machine_state:FINISH"}),
            ],
        ).status_code
        == 200
    )
    assert upload(client, token, f, task, [event(3, "collection_ready", detail)]).status_code == 409
    evidence = [
        event(3, "command_done", {"command": "open"}),
        event(4, "feedback", {"kind": "barcodeDisappeared", "raw": detail["absent"]}),
        event(5, "written", {"command": "close"}),
    ]
    assert upload(client, token, f, task, evidence).status_code == 200
    assert upload(client, token, f, task, [event(6, "collection_ready", detail)]).status_code == 409
    evidence = [
        event(6, "ack", {"command": "close"}),
        event(7, "command_done", {"command": "close"}),
        event(8, "collection_ready", detail),
    ]
    result = upload(client, token, f, task, evidence)
    assert result.status_code == 200, result.text
    assert result.json()["state"] == "completed"
    assert upload(client, token, f, task, evidence).status_code == 200
