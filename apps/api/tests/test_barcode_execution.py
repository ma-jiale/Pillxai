# ruff: noqa: F811
from datetime import UTC, datetime, timedelta

from sqlalchemy import create_engine, delete
from test_business import world  # noqa: F401
from test_tasks import claim, setup, start

from pillxai_api.tasks.tables import labels


def test_barcode_only_claim_and_start_snapshot(world):
    client, tokens, _, settings = world
    token = tokens["admin"]
    f = setup(client, token)
    profile = client.get(f"/residents/{f['rid']}", headers=token).json()
    code = profile["data"]["barcode"]
    response = client.put(
        f"/residents/{f['rid']}",
        headers=token,
        json=dict(
            expected_revision=profile["revision"],
            data=profile["data"] | {"barcode": code},
        ),
    )
    assert response.status_code == 200
    engine = create_engine(settings.database_url)
    with engine.begin() as conn:
        conn.execute(delete(labels).where(labels.c.resident_id == f["rid"]))
    engine.dispose()
    f["plan"] = client.post(
        f"/residents/{f['rid']}/plans/preview", headers=token, json=dict(days=2)
    ).json()["snapshot"]
    task_response = claim(client, token, f)
    assert task_response.status_code == 200, task_response.text
    task = task_response.json()
    assert task["labels"] == []
    assert dict(source="barcode", value=code, resident_id=f["rid"]) in task["recognition_bindings"]
    assert start(client, token, f, task, uid=None, barcode=code[1:]).status_code == 409
    assert start(client, token, f, task, barcode=code).status_code == 422
    assert start(client, token, f, task, uid=code).status_code in (409, 422)
    observed = datetime.now(UTC)
    assert (
        start(
            client,
            token,
            f,
            task,
            uid=None,
            barcode=code,
            observed_at=observed.isoformat(),
            checked_at=(observed - timedelta(seconds=1)).isoformat(),
        ).status_code
        == 409
    )
    allowed = start(
        client,
        token,
        f,
        task,
        uid=None,
        barcode=code,
        observed_at=observed.isoformat(),
        checked_at=datetime.now(UTC).isoformat(),
    )
    assert allowed.status_code == 200, allowed.text
