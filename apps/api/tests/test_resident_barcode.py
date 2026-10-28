# ruff: noqa: F811
from concurrent.futures import ThreadPoolExecutor
from uuid import uuid4

from sqlalchemy import String, create_engine, select, text, update
from test_business import resident, world  # noqa: F401

from pillxai_api.residents.tables import residents


def test_auto_barcode_is_immutable_and_leading_zeros_survive(world):
    client, tokens, _, _ = world
    first = resident(client, tokens["admin"]).json()
    code = first["data"]["barcode"]
    assert len(code) == 6 and code.isascii() and code.isdigit()
    path = f"/residents/{first['id']}"
    for changed in ("", "999999"):
        response = client.put(
            path,
            headers=tokens["admin"],
            json=dict(expected_revision=1, data=first["data"] | {"barcode": changed}),
        )
        assert response.status_code == 422
        assert response.json()["code"] == "barcode_read_only"
    for revision, extra in ((1, {}), (2, {"barcode": None}), (3, {"barcode": code})):
        result = client.put(
            path,
            headers=tokens["admin"],
            json=dict(expected_revision=revision, data=dict(name="新名字", bed="", **extra)),
        )
        assert result.status_code == 200, result.text
        assert result.json()["data"]["barcode"] == code
    assert (
        client.get(path + "/versions", headers=tokens["admin"]).json()[-1]["data"]["barcode"]
        == code
    )
    matched = client.get("/residents", headers=tokens["staff"], params={"barcode": code}).json()
    assert [r["id"] for r in matched["items"]] == [first["id"]]
    invalid = client.put(
        f"/residents/{uuid4()}",
        headers=tokens["admin"],
        json=dict(expected_revision=0, data=dict(name="不允许指定", barcode="000001")),
    )
    assert invalid.status_code == 422


def test_parallel_creates_allocate_unique_numbers(world):
    client, tokens, _, _ = world
    with ThreadPoolExecutor(max_workers=8) as pool:
        responses = list(pool.map(lambda _: resident(client, tokens["admin"]), range(12)))
    assert all(r.status_code == 200 for r in responses)
    codes = [r.json()["data"]["barcode"] for r in responses]
    assert len(set(codes)) == 12
    assert all(len(code) == 6 and code.isdigit() for code in codes)


def test_sequence_starts_at_one_and_skips_existing_codes(world):
    from pillxai_api.residents.service import next_barcode

    _, _, _, settings = world
    engine = create_engine(settings.database_url)
    with engine.connect() as c:
        transaction = c.begin()
        c.execute(text("LOCK TABLE residents IN ACCESS EXCLUSIVE MODE"))
        previous = c.execute(
            text("SELECT last_value, is_called FROM resident_barcode_number")
        ).one()
        try:
            c.execute(text("SELECT setval('resident_barcode_number', 1, false)"))
            c.execute(update(residents).values(barcode="fixture-" + residents.c.id.cast(String)))
            first_id = c.scalar(select(residents.c.id).limit(1))
            assert first_id
            c.execute(update(residents).where(residents.c.id == first_id).values(barcode="000010"))
            assert [next_barcode(c) for _ in range(10)] == [f"{n:06d}" for n in range(1, 10)] + [
                "000011"
            ]
            assert (
                c.scalar(select(residents.c.barcode).where(residents.c.id == first_id)) == "000010"
            )
        finally:
            transaction.rollback()
            c.execute(
                text("SELECT setval('resident_barcode_number', :value, :called)"),
                {"value": previous.last_value, "called": previous.is_called},
            )
            c.commit()
    engine.dispose()
