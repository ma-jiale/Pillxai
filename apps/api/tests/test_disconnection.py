from uuid import uuid4

from test_business import world  # noqa: F401
from test_tasks import claim, setup, start


def test_disconnect_cleanup_releases_claim_without_claiming_physical_safety(world):  # noqa: F811
    client, tokens, _, _ = world
    f = setup(client, tokens["admin"])
    task = claim(client, tokens["admin"], f).json()
    assert start(client, tokens["admin"], f, task).status_code == 200
    path = f"/tasks/{task['id']}/discard"
    body = dict(terminal_id=f["terminal"], physical_scene_safe=False)
    assert client.post(path, headers=tokens["admin"], json=body).status_code == 409
    body["reason"] = "device_disconnected"
    assert client.post(path, headers=tokens["staff"], json=body).status_code == 403
    assert client.post(
        path, headers=tokens["admin"], json=body | dict(terminal_id=str(uuid4()))
    ).status_code == 403
    for _ in range(2):
        assert client.post(path, headers=tokens["admin"], json=body).status_code == 200
    assert client.get(f"/tasks/{task['id']}", headers=tokens["admin"]).status_code == 404
    assert claim(client, tokens["admin"], f, task["id"]).status_code == 409
    f["plan"] = client.post(
        f"/residents/{f['rid']}/plans/preview", headers=tokens["admin"], json={}
    ).json()["snapshot"]
    assert claim(client, tokens["admin"], f).status_code == 200
