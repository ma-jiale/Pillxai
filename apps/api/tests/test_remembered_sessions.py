from datetime import UTC, datetime, timedelta

from sqlalchemy import create_engine, select, update
from test_business import world  # noqa: F401

from pillxai_api.identity.security import token_hash
from pillxai_api.identity.tables import sessions


def test_restored_session_renews_thirty_days_but_expired_session_cannot(world):  # noqa: F811
    client, tokens, _, settings = world
    digest = token_hash(tokens["admin"]["Authorization"].split(" ")[1])
    engine = create_engine(settings.database_url)
    try:
        with engine.begin() as connection:
            initial = connection.scalar(
                select(sessions.c.expires_at).where(sessions.c.token_hash == digest)
            )
            assert initial > datetime.now(UTC) + timedelta(days=29)
            connection.execute(
                update(sessions)
                .where(sessions.c.token_hash == digest)
                .values(expires_at=datetime.now(UTC) + timedelta(minutes=1))
            )
        assert client.get("/auth/me", headers=tokens["admin"]).status_code == 200
        with engine.begin() as connection:
            renewed = connection.scalar(
                select(sessions.c.expires_at).where(sessions.c.token_hash == digest)
            )
            assert renewed > datetime.now(UTC) + timedelta(days=29)
            expired = datetime.now(UTC) - timedelta(seconds=1)
            connection.execute(
                update(sessions).where(sessions.c.token_hash == digest).values(expires_at=expired)
            )
        assert client.get("/auth/me", headers=tokens["admin"]).status_code == 401
        with engine.begin() as connection:
            assert (
                connection.scalar(
                    select(sessions.c.expires_at).where(sessions.c.token_hash == digest)
                )
                == expired
            )
    finally:
        engine.dispose()
