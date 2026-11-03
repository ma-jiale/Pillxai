from uuid import uuid4

from test_business import resident, world  # noqa: F401
from test_tasks import claim, event, setup, upload


def test_delete_records_permissions_tasks_history_and_retries(world):  # noqa: F811
    client, tokens, _, _ = world
    admin = tokens["admin"]
    fixture = setup(client, admin)
    path = f"/residents/{fixture['rid']}"
    rx = f"{path}/prescriptions/{fixture['pid']}"
    task = claim(client, admin, fixture).json()
    for url in (path, rx):
        assert client.delete(url, headers=tokens["staff"], params={"expected_revision": 1}
                             ).status_code == 403
        assert client.delete(url, headers=admin, params={"expected_revision": 1}).status_code == 409
    assert upload(client, admin, fixture, task, [
        event(1, "cancelled", {"physical_scene_safe": True})
    ]).status_code == 200
    for attempt in range(2):
        assert client.delete(rx, headers=admin, params={"expected_revision": 1}).status_code == 204
    assert client.get(path + "/prescriptions", headers=admin).json() == []
    assert client.get(rx + "/versions", headers=admin).json()[0]["revision"] == 1
    assert client.get(path, headers=admin).status_code == 200
    bed = str(uuid4())[:12]
    assert client.put(path, headers=admin, json={
        "expected_revision": 1, "data": {"name": "删除测试", "bed": bed}
    }).status_code == 200
    assert client.delete(path, headers=admin, params={"expected_revision": 1}).status_code == 409
    for attempt in range(2):
        result = client.delete(path, headers=admin, params={"expected_revision": 2})
        assert result.status_code == 204
    assert client.get(path, headers=admin).status_code == 404
    assert client.get(path + "/prescriptions", headers=admin).status_code == 404
    assert client.get(path + "/versions", headers=admin).status_code == 200
    assert client.get(f"/tasks/{task['id']}", headers=admin).json()["batches"] == task["batches"]
    assert resident(client, admin, bed=bed).status_code == 200
