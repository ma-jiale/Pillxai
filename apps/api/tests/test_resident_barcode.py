# ruff: noqa: F811
from uuid import uuid4

from test_business import resident, world  # noqa: F401


def test_barcode_identity_and_older_client_preservation(world):
    client, tokens, _, _ = world
    first = resident(client, tokens["admin"]).json()
    code = "000010" + uuid4().hex
    path = f"/residents/{first['id']}"
    payload = dict(expected_revision=1, data=first["data"] | {"barcode": code})
    assert client.put(path, headers=tokens["staff"], json=payload).status_code == 403
    saved = client.put(path, headers=tokens["admin"], json=payload)
    assert saved.status_code == 200, saved.text
    assert saved.json()["data"]["barcode"] == code
    assert saved.json()["id"] == first["id"]
    assert client.put(path, headers=tokens["admin"], json=payload).status_code == 409
    for revision, extra in ((2, {}), (3, {"barcode": None})):
        updated = client.put(
            path,
            headers=tokens["admin"],
            json=dict(
                expected_revision=revision,
                data=dict(name="新名字", bed="", **extra),
            ),
        )
        assert updated.status_code == 200, updated.text
        assert updated.json()["data"]["barcode"] == code
    matched = client.get("/residents", headers=tokens["staff"], params={"barcode": code})
    assert [r["id"] for r in matched.json()["items"]] == [first["id"]]
    assert (
        client.get("/residents", headers=tokens["staff"], params={"barcode": code[1:]}).json()[
            "items"
        ]
        == []
    )
    duplicate = client.put(
        f"/residents/{uuid4()}",
        headers=tokens["admin"],
        json=dict(
            expected_revision=0,
            data=dict(name="另一个长者", barcode=code),
        ),
    )
    assert duplicate.status_code == 409
    assert duplicate.json()["code"] == "barcode_conflict"
    invalid = client.put(
        path,
        headers=tokens["admin"],
        json=dict(
            expected_revision=4,
            data=dict(name="新名字", barcode=10),
        ),
    )
    assert invalid.status_code == 422
    cleared = client.put(
        path,
        headers=tokens["admin"],
        json=dict(
            expected_revision=4,
            data=dict(name="新名字", barcode=""),
        ),
    )
    assert cleared.status_code == 200
    versions = client.get(path + "/versions", headers=tokens["admin"]).json()
    assert versions[0]["data"]["barcode"] == ""
    assert versions[1]["data"]["barcode"] == code
