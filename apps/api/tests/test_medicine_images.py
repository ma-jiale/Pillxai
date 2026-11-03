import base64
from io import BytesIO

import pytest
from PIL import Image
from test_business import world  # noqa: F401
from test_tasks import claim, setup

from pillxai_api.prescriptions.image import normalize_medicine_image


def picture(size=(30, 20)):
    output = BytesIO()
    Image.new("RGB", size, "blue").save(output, format="PNG")
    return "data:image/png;base64," + base64.b64encode(output.getvalue()).decode()


@pytest.mark.parametrize(
    "value",
    [
        "file:///tmp/photo.png",
        "https://example.com/photo.png",
        "data:image/png;base64,broken",
        picture((513, 1)),
    ],
)
def test_reject_invalid_or_oversized_image(value):
    with pytest.raises(ValueError):
        normalize_medicine_image(value)


def test_photo_persists_with_prescription_and_task_snapshot(world):  # noqa: F811
    client, tokens, _, _ = world
    token = tokens["admin"]
    fixture = setup(client, token)
    path = f"/residents/{fixture['rid']}/prescriptions/{fixture['pid']}"
    current = client.get(f"/residents/{fixture['rid']}/prescriptions", headers=token).json()[0]
    photo = normalize_medicine_image(picture())
    body = dict(expected_revision=1, data=current["data"] | {"image": photo})
    assert client.put(path, headers=tokens["staff"], json=body).status_code == 403
    saved = client.put(path, headers=token, json=body)
    assert saved.status_code == 200, saved.text
    assert saved.json()["data"]["image"] == photo
    assert saved.json()["medicine_id"] == current["medicine_id"]
    fixture["plan"] = client.post(
        f"/residents/{fixture['rid']}/plans/preview", headers=token, json={"days": 2}
    ).json()["snapshot"]
    assert fixture["plan"]["sources"][0]["data"]["image"] == photo
    task = claim(client, token, fixture).json()
    assert task["batches"][0]["image"] == photo
    # An old client omitting image must not erase it.
    body["data"].pop("image")
    body["expected_revision"] = 2
    assert client.put(path, headers=token, json=body).json()["data"]["image"] == photo
    body["expected_revision"] = 3
    body["data"]["image"] = ""
    assert client.put(path, headers=token, json=body).json()["data"]["image"] == ""
    stored = client.get(f"/tasks/{task['id']}", headers=token).json()
    assert stored["batches"][0]["image"] == photo
