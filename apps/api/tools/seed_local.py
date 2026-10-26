"""Explicit local development bootstrap. No seed runs on service startup."""

import json
import secrets
from pathlib import Path

from sqlalchemy import create_engine, select

from pillxai_api.config import Settings
from pillxai_api.identity.models import CreateAccount, Role
from pillxai_api.identity.service import create_account
from pillxai_api.identity.tables import accounts


def main():
    root = Path(__file__).resolve().parents[3]
    credentials = root / ".var/local-login.json"
    engine = create_engine(Settings.from_environment().database_url)
    with engine.begin() as connection:
        if connection.execute(select(accounts.c.id).limit(1)).first():
            print("Accounts already exist; no credentials or business data changed.")
            return
        password = secrets.token_urlsafe(24)
        create_account(
            connection,
            CreateAccount(
                username="local-admin", display_name="开发管理员",
                password=password, role=Role.admin,
            ),
        )
        entries = [dict(username="local-admin", password=password, role=Role.admin.value)]
        credentials.parent.mkdir(exist_ok=True)
        # Store before commit so a disk-write failure cannot leave inaccessible accounts.
        with credentials.open("x", encoding="utf-8") as output:
            json.dump(dict(accounts=entries), output, indent=2)
    engine.dispose()
    print(
        "Created development administrator. Credentials: .var/local-login.json (not committed)."
    )


if __name__ == "__main__":
    main()
