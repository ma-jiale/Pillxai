import os
from concurrent.futures import ThreadPoolExecutor
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, inspect

from pillxai_api.app import create_app
from pillxai_api.config import Settings
from pillxai_api.identity.models import CreateAccount, Role
from pillxai_api.identity.service import create_account

PASSWORD = "only-fixture-password-42"


@pytest.fixture
def world():
    url = os.environ.get("PILLXAI_TEST_DATABASE_URL")
    if not url:
        pytest.skip("Requires migrated PostgreSQL test database")
    assert url.rsplit("/", 1)[-1].endswith("_test")
    engine = create_engine(url)
    usernames = {
        key: f"{key}-{uuid4().hex[:15]}" for key in ("admin", "staff", "other")
    }
    with engine.begin() as connection:
        for key, role in (
            ("admin", Role.admin),
            ("staff", Role.staff),
            ("other", Role.admin),
        ):
            create_account(
                connection,
                CreateAccount(
                    username=usernames[key],
                    display_name=key,
                    password=PASSWORD,
                    role=role,
                ),
            )
    engine.dispose()
    settings = Settings(url)
    with TestClient(create_app(settings)) as client:
        tokens, actors = {}, {}
        for key, username in usernames.items():
            response = client.post("/auth/login", json=dict(username=username, password=PASSWORD))
            assert response.status_code == 200, response.text
            tokens[key] = {"Authorization": f"Bearer {response.json()['access_token']}"}
            actors[key] = response.json()["account"]
        yield client, tokens, actors, settings


def resident(client, token, *, bed="", resident_id=None, revision=0, name="测试长者"):
    return client.put(
        f"/residents/{resident_id or uuid4()}",
        headers=token,
        json=dict(expected_revision=revision, data=dict(name=name, bed=bed)),
    )


def prescription():
    return dict(
        medicine_name="虚构药物",
        strength="10 mg",
        unit="tablet",
        feed_form="half",
        doses=dict(morning="0.5", noon="0", evening="0.5", night="0"),
        meal_relation="after",
        start_date="2026-10-04",
        end_date="2026-10-06",
        stopped=False,
    )


def test_permissions_and_session_revocation(world):
    client, tokens, actors, _ = world
    assert client.get("/residents").status_code == 401
    assert client.get("/accounts", headers=tokens["staff"]).status_code == 403
    assert client.get("/residents", headers=tokens["staff"]).status_code == 200
    assert resident(client, tokens["staff"]).status_code == 403
    data = dict(
        username=f"new-{uuid4().hex[:12]}", display_name="员工", password=PASSWORD, role="staff"
    )
    assert (
        client.post("/accounts", headers=tokens["staff"], json=data).status_code
        == 403
    )
    assert (
        client.post(
            "/accounts",
            headers=tokens["admin"],
            json=data | {"role": "admin"},
        ).status_code
        == 200
    )
    assert (
        client.put(
            f"/accounts/{actors['admin']['id']}", headers=tokens["admin"],
            json=dict(expected_revision=1, display_name="本人", active=False, can_maintain=False),
        ).status_code == 403
    )
    target = f"/accounts/{actors['staff']['id']}"
    change = dict(expected_revision=1, display_name="员工", active=True, can_maintain=True)
    assert client.put(target, headers=tokens["admin"], json=change).status_code == 200
    assert resident(client, tokens["staff"]).status_code == 200
    assert client.put(target, headers=tokens["admin"], json=change).status_code == 409
    assert (
        client.put(
            target, headers=tokens["admin"], json=change | {"expected_revision": 2, "active": False}
        ).status_code
        == 200
    )
    assert client.get("/auth/me", headers=tokens["staff"]).status_code == 401
    assert (
        client.put(
            target, headers=tokens["admin"], json=change | {"expected_revision": 3}
        ).status_code
        == 200
    )
    # Reactivation never resurrects the old session.
    assert client.get("/auth/me", headers=tokens["staff"]).status_code == 401
    assert client.post("/auth/logout", headers=tokens["admin"]).status_code == 200
    assert client.get("/auth/me", headers=tokens["admin"]).status_code == 401


def test_bed_uniqueness_history_and_reopen(world):
    client, tokens, _, settings = world
    bed = f"A楼-{uuid4().hex[:10]}"
    saved = resident(client, tokens["admin"], bed=f"  {bed}  ").json()
    rid = saved["id"]
    assert saved["data"]["bed"] == bed
    assert resident(client, tokens["admin"], bed=bed).status_code == 409
    assert resident(client, tokens["other"], bed=bed).status_code == 409
    for _ in range(2):
        assert resident(client, tokens["admin"]).status_code == 200
    assert client.get(f"/residents/{rid}", headers=tokens["other"]).status_code == 200
    path = f"/residents/{uuid4()}"
    for suffix in ("", "/versions", "/prescriptions"):
        assert client.get(path + suffix, headers=tokens["other"]).status_code == 404
    assert (
        resident(
            client, tokens["admin"], resident_id=rid, revision=1, name="新姓名", bed=""
        ).status_code
        == 200
    )
    with TestClient(create_app(settings)) as reopened:
        versions = reopened.get(
            f"/residents/{rid}/versions", headers=tokens["admin"]
        ).json()
    assert [row["revision"] for row in versions] == [2, 1]
    assert versions[1]["data"] == dict(name="测试长者", bed=bed, barcode="")
    first = client.get("/residents?limit=1", headers=tokens["admin"]).json()
    second = client.get(
        f"/residents?limit=1&after={first['next_after']}", headers=tokens["admin"]
    ).json()
    assert first["items"][0]["id"] != second["items"][0]["id"]


def test_prescription_revision_conflict_stop_restore_and_independent_identity(world):
    client, tokens, _, settings = world
    rid = resident(client, tokens["admin"]).json()["id"]
    pid = str(uuid4())
    base = f"/residents/{rid}/prescriptions"
    path = f"{base}/{pid}"
    data = prescription()
    saved = client.put(
        path, headers=tokens["admin"], json=dict(expected_revision=0, data=data)
    ).json()
    assert saved["revision"] == 1
    twin = client.put(
        f"{base}/{uuid4()}", headers=tokens["admin"], json=dict(expected_revision=0, data=data)
    ).json()
    assert twin["id"] != pid
    assert twin["medicine_id"] != saved["medicine_id"]
    assert (
        client.get(
            f"/residents/{uuid4()}/prescriptions/{pid}/versions",
            headers=tokens["other"],
        ).status_code
        == 404
    )

    def save_once(stopped):
        with TestClient(create_app(settings)) as concurrent:
            return concurrent.put(
                path,
                headers=tokens["admin"],
                json=dict(expected_revision=1, data=data | {"stopped": stopped}),
            ).status_code

    with ThreadPoolExecutor(max_workers=2) as pool:
        assert sorted(pool.map(save_once, [True, False])) == [200, 409]
    for revision, stopped in ((2, True), (3, False)):
        result = client.put(
            path,
            headers=tokens["admin"],
            json=dict(expected_revision=revision, data=data | {"stopped": stopped}),
        )
        assert result.status_code == 200
        assert result.json()["medicine_id"] == saved["medicine_id"]
    with TestClient(create_app(settings)) as reopened:
        versions = reopened.get(path + "/versions", headers=tokens["admin"]).json()
        assert len(versions) == 4
        assert versions[0]["data"]["stopped"] is False
        assert versions[1]["data"]["stopped"] is True
        assert versions[-1]["data"] == data
        assert len(reopened.get(base, headers=tokens["admin"]).json()) == 2


def test_dose_date_and_password_validation(world):
    client, tokens, _, _ = world
    rid = resident(client, tokens["admin"]).json()["id"]
    path = f"/residents/{rid}/prescriptions/{uuid4()}"
    original = prescription()
    for patch in (
        dict(end_date="2026-10-03"),
        dict(feed_form="whole"),
        dict(unit="capsule"),
        dict(doses=dict(morning="1", noon="0", evening="0", night="0")),
        dict(doses=dict(morning=0.5, noon="0", evening="0", night="0")),
        dict(doses=dict(morning="0", noon="0", evening="0", night="0.5")),
    ):
        result = client.put(
            path, headers=tokens["admin"], json=dict(expected_revision=0, data=original | patch)
        )
        assert result.status_code == 422, result.text
    response = client.post("/auth/login", json=dict(username="absent", password="do-not-echo"))
    assert response.status_code == 401 and "do-not-echo" not in response.text
    assert (
        client.post(
            "/auth/password",
            headers=tokens["admin"],
            json=dict(
                current_password="wrong",
                password="updated-password-42",
            ),
        ).status_code
        == 400
    )
    assert (
        client.post(
            "/auth/password",
            headers=tokens["admin"],
            json=dict(
                current_password=PASSWORD,
                password="updated-password-42",
            ),
        ).status_code
        == 200
    )
    assert client.get("/auth/me", headers=tokens["admin"]).status_code == 401


def test_single_workspace_contract_and_schema(world):
    client, tokens, _, settings = world
    assert client.get("/settings").status_code == 401
    configuration = client.get("/settings", headers=tokens["staff"]).json()
    assert configuration["timezone"] == "Asia/Shanghai"
    assert configuration["revision"] >= 1
    schema = client.get("/openapi.json").json()
    assert schema["components"]["schemas"]["Role"]["enum"] == ["admin", "staff"]
    assert not any("institution" in path for path in schema["paths"])
    assert client.get("/institutions", headers=tokens["admin"]).status_code == 404
    engine = create_engine(settings.database_url)
    try:
        inspector = inspect(engine)
        assert "institutions" not in inspector.get_table_names()
        for table in ("accounts", "residents", "medicines"):
            columns = {column["name"] for column in inspector.get_columns(table)}
            assert "institution_id" not in columns
    finally:
        engine.dispose()
