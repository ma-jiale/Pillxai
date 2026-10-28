# ruff: noqa: F811
import base64
from io import BytesIO

from fastapi.testclient import TestClient
from PIL import Image
from test_business import resident, world  # noqa: F401

from pillxai_api.app import create_app


def image_data(size=(100, 80)):
    output = BytesIO()
    Image.new("RGB", size, "navy").save(output, format="PNG")
    return "data:image/png;base64," + base64.b64encode(output.getvalue()).decode()


def test_avatar_preset_upload_clear_versions_and_reopen(world):
    client, tokens, _, settings = world
    first = resident(client, tokens["admin"]).json()
    path = f"/residents/{first['id']}"
    code = first["data"]["barcode"]

    def save(revision, avatar, headers=None):
        return client.put(
            path,
            headers=headers or tokens["admin"],
            json=dict(
                expected_revision=revision, data=dict(name="头像测试", bed="", avatar=avatar)
            ),
        )

    preset = "assets/images/avatars/chen.png"
    assert save(1, preset, tokens["staff"]).status_code == 403
    assert save(1, preset).json()["data"]["avatar"] == preset
    assert save(2, None).json()["data"]["avatar"] == preset
    uploaded = save(3, image_data())
    assert uploaded.status_code == 200, uploaded.text
    data = uploaded.json()["data"]
    assert data["barcode"] == code
    assert data["avatar"].startswith("data:image/png;base64,")
    with TestClient(create_app(settings)) as reopened:
        assert (
            reopened.get(path, headers=tokens["admin"]).json()["data"]["avatar"] == data["avatar"]
        )
    assert save(4, "").json()["data"]["avatar"] == ""
    versions = client.get(path + "/versions", headers=tokens["admin"]).json()
    assert versions[1]["data"]["avatar"] == data["avatar"]
    assert versions[-1]["data"]["avatar"] == ""


def test_invalid_or_oversized_avatar_does_not_mutate_resident(world):
    client, tokens, _, _ = world
    first = resident(client, tokens["admin"]).json()
    path = f"/residents/{first['id']}"
    for invalid in [
        "https://example.com/photo.png",
        "data:image/png;base64,broken",
        "data:image/svg+xml;base64,PHN2Zy8+",
        image_data((257, 20)),
        "x" * 360001,
    ]:
        response = client.put(
            path,
            headers=tokens["admin"],
            json=dict(expected_revision=1, data=dict(name="头像测试", avatar=invalid)),
        )
        assert response.status_code == 422
    assert client.get(path, headers=tokens["admin"]).json() == first
