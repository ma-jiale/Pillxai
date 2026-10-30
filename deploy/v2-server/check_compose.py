"""Run the actual V2 deploy/backup/recovery path on a disposable CI host."""

import json
import os
import socket
import sys
import tempfile
import urllib.request
from pathlib import Path
from unittest.mock import patch

import manage


def check(artifact, revision):
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise ValueError("Compose integration is restricted to disposable GitHub CI hosts")
    # Owned by PostgreSQL after init; the disposable VM cleans up these files.
    root = Path(tempfile.mkdtemp(prefix="v2-compose-")) / "pillxa-dispenser/v2"
    manage.initialize(root)
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    (root / "shared/server.env").write_text(f"V2_PORT={port}\nV2_ROOT_PATH=/dispenser-v2\n")
    update_url = f"http://127.0.0.1:{port}/releases/android"
    try:
        # The surrounding workflow already checked out the exact CI commit.
        # No production command has this bypass; only this disposable integration test.
        previous_umask = os.umask(0o077)
        try:
            with patch.object(manage, "verify_branch"):
                manage.deploy(root, artifact, revision, "ci/fixture", "main")
        finally:
            os.umask(previous_umask)
        with urllib.request.urlopen(update_url, timeout=10) as response:
            assert json.load(response) == {"api_compatibility": 1, "release": None}
        release = manage.current_release(root)
        assert manage.sql(root, release, "SELECT count(*) FROM accounts") == "1"
        assert (
            manage.sql(root, release, "SELECT rolsuper FROM pg_roles WHERE rolname='pillxai_v2'")
            == "f"
        )
        backup = manage.backup(root, release)
        manage.restore_check(root, release, backup)
        database_container = manage.compose(
            root,
            release,
            "ps",
            "-q",
            "db",
            capture_output=True,
            text=True,
        ).stdout.strip()
        # A second update must preserve credentials/data and validate PostgreSQL ownership.
        before = (root / "shared/initial-admin.json").read_bytes()
        # Upgrade must also repair a directory created by the previous deployment script.
        (root / "shared/client-releases").chmod(0o700)
        with patch.object(manage, "verify_branch"):
            manage.deploy(root, artifact, revision, "ci/fixture", "main")
        with urllib.request.urlopen(update_url, timeout=10) as response:
            assert json.load(response) == {"api_compatibility": 1, "release": None}
        assert (root / "shared/initial-admin.json").read_bytes() == before
        release = manage.current_release(root)
        assert (
            manage.compose(
                root,
                release,
                "ps",
                "-q",
                "db",
                capture_output=True,
                text=True,
            ).stdout.strip()
            == database_container
        )
        assert manage.sql(root, release, "SELECT count(*) FROM accounts") == "1"
        assert (root / "previous.json").is_file()
        print("Actual Compose initialization, second deployment, backup and restore passed.")
    finally:
        record = root / "current.json"
        if not record.exists():
            record = root / "pending.json"
        if record.exists():
            release = root / "releases" / json.loads(record.read_text())["release"]
            if sys.exc_info()[0] is not None:
                logs = manage.compose(
                    root,
                    release,
                    "logs",
                    "--no-color",
                    "--tail",
                    "80",
                    capture_output=True,
                    text=True,
                )
                diagnostic = logs.stdout + logs.stderr
                for name in ("postgres-password", "app-password", "database-url"):
                    diagnostic = diagnostic.replace(
                        (root / "shared" / name).read_text().strip(), "[redacted]"
                    )
                admin = json.loads((root / "shared/initial-admin.json").read_text())
                print(diagnostic.replace(admin["password"], "[redacted]"))
            manage.compose(root, release, "down", "--timeout", "35")
