"""Run the actual V2 deploy/backup/recovery path on a disposable CI host."""

import json
import os
import socket
import tempfile
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
    try:
        # The surrounding workflow already checked out the exact CI commit.
        # No production command has this bypass; only this disposable integration test.
        with patch.object(manage, "verify_branch"):
            manage.deploy(root, artifact, revision, "ci/fixture", "NT")
        release = manage.current_release(root)
        assert manage.sql(root, release, "SELECT count(*) FROM accounts") == "1"
        assert (
            manage.sql(root, release, "SELECT rolsuper FROM pg_roles WHERE rolname='pillxai_v2'")
            == "f"
        )
        backup = manage.backup(root, release)
        manage.restore_check(root, release, backup)
        # A second update must preserve credentials/data and validate PostgreSQL ownership.
        before = (root / "shared/initial-admin.json").read_bytes()
        with patch.object(manage, "verify_branch"):
            manage.deploy(root, artifact, revision, "ci/fixture", "NT")
        assert (root / "shared/initial-admin.json").read_bytes() == before
        release = manage.current_release(root)
        assert manage.sql(root, release, "SELECT count(*) FROM accounts") == "1"
        assert (root / "previous.json").is_file()
        print("Actual Compose initialization, second deployment, backup and restore passed.")
    finally:
        record = root / "current.json"
        if not record.exists():
            record = root / "pending.json"
        if record.exists():
            release = root / "releases" / json.loads(record.read_text())["release"]
            manage.compose(root, release, "down", "--timeout", "35")
