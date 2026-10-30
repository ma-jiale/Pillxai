import hashlib
import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from pillxai_api.app import create_app
from pillxai_api.config import Settings


@pytest.fixture
def releases(tmp_path):
    app = create_app(
        Settings("postgresql+psycopg://unused@localhost/unused", client_releases_directory=tmp_path)
    )
    with TestClient(app, raise_server_exceptions=False) as client:
        yield client, tmp_path


def publish(directory):
    # Deliberately not an APK: this test covers serving, not Android signature verification.
    payload = b"fixture package"
    digest = hashlib.sha256(payload).hexdigest()
    data = dict(
        version_code=2,
        version_name="0.1.1",
        package_name="com.pillxai.pillxai_client",
        sha256=digest,
        size_bytes=len(payload),
        min_android_sdk=24,
        abis=["arm64-v8a"],
        min_api=1,
        max_api=1,
        notes="test",
    )
    (directory / f"{digest}.apk").write_bytes(payload)
    (directory / "current.json").write_text(json.dumps(data))
    return data, payload


def test_unpublished_is_explicit(releases):
    client, _ = releases
    response = client.get("/releases/android")
    assert response.json() == {"api_compatibility": 1, "release": None}
    assert response.headers["cache-control"] == "no-store"


@pytest.mark.parametrize("endpoint", ["/releases/android", "/releases/android/packages/unknown"])
def test_unreadable_release_directory_reports_unavailable(releases, monkeypatch, endpoint):
    client, directory = releases
    original = Path.stat

    def denied(path, *args, **kwargs):
        if path == directory / "current.json":
            raise PermissionError("Container cannot traverse the release directory")
        return original(path, *args, **kwargs)

    monkeypatch.setattr(Path, "stat", denied)
    response = client.get(endpoint)
    assert response.status_code == 503
    assert response.json() == {"detail": "应用发布信息暂不可用。"}


def test_missing_configured_directory_is_not_an_unpublished_release(releases):
    client, directory = releases
    directory.rmdir()
    assert client.get("/releases/android").status_code == 503


def test_release_and_package_match_without_database(releases):
    client, directory = releases
    data, payload = publish(directory)
    assert client.get("/releases/android").json()["release"] == data
    response = client.get(f"/releases/android/packages/{data['sha256']}")
    assert response.content == payload
    assert response.headers["content-type"] == "application/vnd.android.package-archive"
    assert client.get("/releases/android/packages/unknown").status_code == 404
    (directory / "current.json").unlink()
    assert client.get(f"/releases/android/packages/{data['sha256']}").status_code == 404


@pytest.mark.parametrize("invalid", ["corrupt", "missing", "wrong_size", "bad_range", "bad_abi"])
def test_invalid_publication_never_reports_latest(releases, invalid):
    client, directory = releases
    data, _ = publish(directory)
    if invalid == "missing":
        (directory / f"{data['sha256']}.apk").unlink()
    if invalid == "wrong_size":
        data["size_bytes"] += 1
    if invalid == "bad_range":
        data["min_api"] = 2
    if invalid == "bad_abi":
        data["abis"] = ["unknown"]
    (directory / "current.json").write_text("broken" if invalid == "corrupt" else json.dumps(data))
    assert client.get("/releases/android").status_code == 503
