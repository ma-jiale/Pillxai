import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from pillxai_api.app import create_app
from pillxai_api.config import Settings
from pillxai_api.contracts import ContractSample

FIXTURE = Path(__file__).resolve().parents[3] / "tests/fixtures/contract-sample.json"


def sample():
    return json.loads(FIXTURE.read_text()) | {"sample_id": str(uuid4())}


@pytest.mark.parametrize(
    "change",
    [
        {"original_tablets": "0.6"},
        {"original_tablets": 0.5},
        {"particles": 1.0},
        {"end_date": "2026-10-25"},
        {"observed_at": "2026-10-26T09:00:00"},
        {"feed_form": "unknown"},
        {"prescription_version": 0},
    ],
)
def test_contract_rejects_lossy_or_invalid_values(change):
    with pytest.raises(ValidationError):
        ContractSample.model_validate(sample() | change)


def test_development_routes_disabled_by_default():
    app = create_app(Settings("postgresql+psycopg://unused@localhost/unused"))
    with TestClient(app) as client:
        assert client.get("/health/live").status_code == 200
        assert client.post("/dev/contract-samples", json={}).status_code == 404
        assert "/dev/contract-samples" not in app.openapi()["paths"]


@pytest.fixture
def settings():
    import os

    url = os.environ.get("PILLXAI_TEST_DATABASE_URL")
    if not url:
        pytest.skip("PostgreSQL integration requires PILLXAI_TEST_DATABASE_URL")
    if not url.rsplit("/", 1)[-1].endswith("_test"):
        pytest.fail("Integration database name must end in _test")
    return Settings(url, True)


def test_persistence_reopen_conflict_and_concurrent_save(settings):
    payload = sample()
    with TestClient(create_app(settings)) as client:
        assert client.get("/health/ready").status_code == 200
        saved = client.post(
            "/dev/contract-samples", json={"expected_revision": 0, "sample": payload}
        )
        assert saved.status_code == 200
        assert saved.json()["sample"] == payload
    # A new application/engine reads the committed database row.
    with TestClient(create_app(settings)) as client:
        saved = client.get(f"/dev/contract-samples/{payload['sample_id']}")
        assert saved.json()["revision"] == 1

    def update_once(note):
        with TestClient(create_app(settings)) as client:
            return client.post(
                "/dev/contract-samples",
                json={
                    "expected_revision": 1,
                    "sample": payload | {"note": note},
                },
            ).status_code

    with ThreadPoolExecutor(max_workers=2) as executor:
        assert sorted(executor.map(update_once, ["first", "second"])) == [200, 409]
    with TestClient(create_app(settings)) as client:
        assert client.get(f"/dev/contract-samples/{payload['sample_id']}").json()["revision"] == 2


def test_invalid_request_returns_public_error(settings):
    with TestClient(create_app(settings)) as client:
        response = client.post("/dev/contract-samples", json={"password": "never-echo"})
        assert response.status_code == 422
        assert response.json()["code"] == "invalid_request"
        assert "never-echo" not in response.text
