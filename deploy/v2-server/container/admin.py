"""Create the first administrator; accepts credentials on stdin, never argv/logs."""

import json
import sys

from sqlalchemy import create_engine, select, text

from pillxai_api.config import Settings
from pillxai_api.identity.models import CreateAccount, Role
from pillxai_api.identity.service import create_account
from pillxai_api.identity.tables import accounts


def main():
    credentials = json.load(sys.stdin)
    engine = create_engine(Settings.from_environment().database_url)
    with engine.begin() as connection:
        connection.execute(text("LOCK TABLE accounts IN EXCLUSIVE MODE"))
        if connection.execute(select(accounts.c.id).limit(1)).first():
            print("Accounts already exist; left unchanged.")
            return
        create_account(
            connection,
            CreateAccount(
                username=credentials["username"],
                password=credentials["password"],
                display_name="管理员",
                role=Role.admin,
            ),
        )
    engine.dispose()
    print("Administrator initialized.")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Pydantic/SQL errors may contain submitted credentials.
        raise SystemExit(
            "Administrator initialization failed; credentials were not logged."
        ) from None
