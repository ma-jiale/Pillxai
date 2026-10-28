from fastapi.testclient import TestClient

from pillxai_api.app import create_app
from pillxai_api.config import Settings
from pillxai_api.database import transaction


def test_production_health_prefix_and_probe():
    app = create_app(Settings(
        "postgresql+psycopg://unused@localhost/unused",
        service_version="0.1.0+test-build", root_path="/dispenser-v2",
    ))
    with TestClient(app, root_path="/dispenser-v2") as client:
        assert client.get("/health/live").json()["service_version"] == "0.1.0+test-build"
        assert client.post("/dev/contract-samples", json={}).status_code == 404
        assert client.get("/openapi.json").json()["servers"] == [{"url": "/dispenser-v2"}]


def test_login_budget_does_not_block_health():
    app = create_app(Settings(
        "postgresql+psycopg://unused@localhost/unused", login_limit_per_minute=2,
    ))
    # This test covers the ASGI request budget independently of PostgreSQL.
    app.dependency_overrides[transaction] = lambda: None
    with TestClient(app) as client:
        for _ in range(2):
            assert client.post("/auth/login", json={}).status_code == 422
        response = client.post("/auth/login", json={})
        assert response.status_code == 429
        assert response.headers["Retry-After"] == "60"
        assert client.get("/health/live").status_code == 200


def test_database_secret_file(monkeypatch, tmp_path):
    secret = tmp_path / "database-url"
    secret.write_text("postgresql+psycopg://user:secret@db/pillxai_v2\n")
    monkeypatch.setenv("PILLXAI_DATABASE_URL_FILE", str(secret))
    assert Settings.from_environment().database_url.endswith("@db/pillxai_v2")
