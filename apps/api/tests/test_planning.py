from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, date, datetime
from uuid import uuid4
from zoneinfo import ZoneInfo

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from test_business import prescription, resident, world  # noqa: F401

from pillxai_api.app import create_app
from pillxai_api.app_settings import AppSettings, versions
from pillxai_api.database import BusinessError
from pillxai_api.planning.engine import calculate
from pillxai_api.prescriptions.models import PrescriptionView


def configuration(**changes):
    return AppSettings(
        timezone="Asia/Shanghai",
        bedtime_enabled=False,
        preparation_days=7,
        split_meals=True,
        start_tomorrow=False,
        revision=1,
    ).model_copy(update=changes)


def source(**changes):
    data = prescription() | dict(start_date="2026-10-26", end_date=None) | changes
    return PrescriptionView(
        id=uuid4(),
        resident_id=uuid4(),
        medicine_id=uuid4(),
        revision=1,
        data=data,
        updated_at=datetime.now(UTC),
        updated_by=uuid4(),
    )


def test_half_particles_meal_trays_and_original_units():
    half = source(
        meal_relation="before", doses=dict(morning="0.5", noon="0.5", evening="0.5", night="0")
    )
    whole = source(feed_form="whole", doses=dict(morning="2", noon="0", evening="0", night="0"))
    dates, trays = calculate([half, whole], configuration(), date(2026, 10, 26), 7, True)
    assert len(dates) == 7 and [tray.purpose for tray in trays] == [
        "饭前",
        "饭后、随餐及无餐食限制",
    ]
    assert trays[0].medicines[0].particles == [[1, 1, 1, 0]] * 7
    assert trays[0].medicines[0].total_particles == 21
    assert trays[0].medicines[0].original_units == "10.5"
    assert trays[1].medicines[0].total_particles == 14
    _, combined = calculate([half, whole], configuration(), dates[0], 7, False)
    assert len(combined) == 1 and len(combined[0].medicines) == 2


def test_future_finite_dates_gaps_stopped_and_tomorrow():
    a = source(start_date="2026-10-29", end_date="2026-10-29")
    b = source(start_date="2026-10-31", end_date="2026-10-31")
    dates, trays = calculate(
        [a, b, source(stopped=True)], configuration(), date(2026, 10, 26), 7, False
    )
    assert dates == [date(2026, 10, 29), date(2026, 10, 30), date(2026, 10, 31)]
    assert all(m.particles[1] == [0, 0, 0, 0] for m in trays[0].medicines)
    dates, _ = calculate(
        [source()], configuration(start_tomorrow=True), date(2026, 10, 26), 1, False
    )
    assert dates == [date(2026, 10, 27)]
    with pytest.raises(BusinessError, match="当前没有"):
        calculate([source(stopped=True)], configuration(), date(2026, 10, 26), 7, True)


def test_night_demand_is_not_silently_dropped():
    night = source(doses=dict(morning="0", noon="0", evening="0", night="0.5"))
    with pytest.raises(BusinessError):
        calculate([night], configuration(), date(2026, 10, 26), 3, False)
    _, trays = calculate([night], configuration(bedtime_enabled=True), date(2026, 10, 26), 3, False)
    assert trays[0].medicines[0].particles == [[0, 0, 0, 1]] * 3


@pytest.fixture
def workspace(world):  # noqa: F811 - imported pytest fixture
    client, tokens, actors, settings = world
    before = client.get("/settings", headers=tokens["admin"]).json()
    yield world
    latest = client.get("/settings", headers=tokens["admin"]).json()
    assert (
        client.put(
            "/settings", headers=tokens["admin"], json=save_payload(before, latest["revision"])
        ).status_code
        == 200
    )


def save_payload(value, revision=None):
    return {
        key: value[key]
        for key in ("preparation_days", "split_meals", "bedtime_enabled", "start_tomorrow")
    } | {"expected_revision": revision if revision is not None else value["revision"]}


def test_settings_permissions_cas_reopen_and_audit(workspace):
    client, tokens, actors, settings = workspace
    before = client.get("/settings", headers=tokens["admin"]).json()
    payload = save_payload(before) | dict(
        preparation_days=3, split_meals=False, bedtime_enabled=True, start_tomorrow=True
    )
    assert client.put("/settings", headers=tokens["staff"], json=payload).status_code == 403
    for days in (0, 8, True, 1.5):
        assert (
            client.put(
                "/settings", headers=tokens["admin"], json=payload | dict(preparation_days=days)
            ).status_code
            == 422
        )

    def save_once(_):
        with TestClient(create_app(settings)) as other:
            return other.put("/settings", headers=tokens["admin"], json=payload).status_code

    with ThreadPoolExecutor(max_workers=2) as pool:
        assert sorted(pool.map(save_once, range(2))) == [200, 409]
    with TestClient(create_app(settings)) as reopened:
        saved = reopened.get("/settings", headers=tokens["admin"]).json()
    assert saved["preparation_days"] == 3 and saved["revision"] == before["revision"] + 1
    engine = create_engine(settings.database_url)
    with engine.connect() as connection:
        history = (
            connection.execute(select(versions).where(versions.c.revision == saved["revision"]))
            .mappings()
            .one()
        )
        assert str(history["actor_id"]) == actors["admin"]["id"]
        assert history["data"] == saved
    engine.dispose()


def test_preview_snapshot_reopen_overrides_and_invalidation(workspace):
    client, tokens, _, settings = workspace
    rid = resident(client, tokens["admin"]).json()["id"]
    current = client.get("/settings", headers=tokens["admin"]).json()
    assert (
        client.put(
            "/settings",
            headers=tokens["admin"],
            json=save_payload(current) | dict(start_tomorrow=False, bedtime_enabled=False),
        ).status_code
        == 200
    )
    pid = uuid4()
    path = f"/residents/{rid}/prescriptions/{pid}"
    data = prescription() | dict(
        start_date=str(datetime.now(ZoneInfo("Asia/Shanghai")).date()), end_date=None
    )
    assert (
        client.put(
            path, headers=tokens["admin"], json=dict(expected_revision=0, data=data)
        ).status_code
        == 200
    )
    preview_path = f"/residents/{rid}/plans/preview"
    assert client.post(preview_path, json={}).status_code == 401
    for change in (dict(days=0), dict(days=8), dict(days=True), dict(start_date="2030-01-01")):
        assert client.post(preview_path, headers=tokens["staff"], json=change).status_code == 422
    original = client.post(
        preview_path, headers=tokens["staff"], json=dict(days=3, split_meals=False)
    ).json()
    snapshot = original["snapshot"]
    assert original["current"] and len(snapshot["dates"]) == 3
    assert snapshot["trays"][0]["medicines"][0]["total_particles"] == 6
    assert (
        client.get("/settings", headers=tokens["admin"]).json()["preparation_days"]
        == current["preparation_days"]
    )
    with TestClient(create_app(settings)) as reopened:
        assert reopened.get(f"/plans/{snapshot['id']}", headers=tokens["staff"]).json() == original
    # Generating another preview neither claims a machine nor advances coverage.
    again = client.post(preview_path, headers=tokens["admin"], json=dict(days=3)).json()
    assert again["snapshot"]["dates"] == snapshot["dates"]
    settings_now = client.get("/settings", headers=tokens["admin"]).json()
    assert client.put(
        "/settings", headers=tokens["admin"],
        json=save_payload(settings_now) | dict(preparation_days=2),
    ).status_code == 200
    changed_settings = client.get(f"/plans/{snapshot['id']}", headers=tokens["staff"]).json()
    assert not changed_settings["current"] and changed_settings["snapshot"] == snapshot
    fresh = client.post(preview_path, headers=tokens["admin"], json={}).json()
    assert fresh["current"] and len(fresh["snapshot"]["dates"]) == 2
    assert (
        client.put(
            path,
            headers=tokens["admin"],
            json=dict(expected_revision=1, data=data | dict(stopped=True)),
        ).status_code
        == 200
    )
    stale = client.get(f"/plans/{snapshot['id']}", headers=tokens["staff"]).json()
    assert not stale["current"] and stale["snapshot"] == snapshot
    assert client.post(preview_path, headers=tokens["admin"], json={}).status_code == 422
    assert not client.get(f"/plans/{fresh['snapshot']['id']}", headers=tokens["admin"]).json()[
        "current"
    ]
