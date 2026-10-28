"""Build, exercise and export immutable V2 images on a GitHub-hosted Linux runner."""

import argparse
import gzip
import json
import os
import re
import shutil
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path
from uuid import uuid4

from manage import FILES, digest, run, write_json

ROOT = Path(__file__).resolve().parents[2]


def inspect(image):
    return json.loads(
        run(["docker", "image", "inspect", image], capture_output=True, text=True).stdout
    )[0]


def pull_pinned(tag):
    run(["docker", "pull", "--platform", "linux/amd64", tag])
    return inspect(tag)["RepoDigests"][0]


def request(port, path, payload=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(
        f"http://127.0.0.1:{port}{path}",
        data=json.dumps(payload).encode() if payload is not None else None,
        headers=headers,
    )
    with urllib.request.urlopen(req, timeout=10) as response:
        return json.load(response)


def smoke(api_image, pg_image, revision):
    """Actual image + database + authenticated API + isolated pg_restore, no production data."""
    suffix = uuid4().hex[:12]
    network, db, api = (f"pillxai-v2-ci-{suffix}-{part}" for part in ("net", "db", "api"))
    password = uuid4().hex
    environment = os.environ.copy()
    environment["PILLXAI_DATABASE_URL"] = (
        f"postgresql+psycopg://postgres:{password}@{db}/pillxai_v2_test"
    )
    environment["POSTGRES_PASSWORD"] = password
    admin = {"username": "ci-admin", "password": uuid4().hex}
    schema = None
    run(["docker", "network", "create", "--internal", network], stdout=subprocess.DEVNULL)
    try:
        run(
            [
                "docker",
                "run",
                "-d",
                "--name",
                db,
                "--network",
                network,
                "-e",
                "POSTGRES_PASSWORD",
                "-e",
                "POSTGRES_DB=pillxai_v2_test",
                pg_image,
            ],
            env=environment,
            stdout=subprocess.DEVNULL,
        )
        for _ in range(60):
            ready = subprocess.run(
                ["docker", "exec", db, "pg_isready", "-U", "postgres"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            if ready.returncode == 0:
                break
            time.sleep(1)
        common = ["docker", "run", "--rm", "--network", network, "-e", "PILLXAI_DATABASE_URL"]
        run(
            [*common, api_image, "alembic", "-c", "/app/apps/api/alembic.ini", "upgrade", "head"],
            env=environment,
        )
        run(
            [*common, "-i", api_image, "python", "/app/operations/admin.py"],
            env=environment,
            input=json.dumps(admin),
            text=True,
        )
        schema = run(
            [
                "docker",
                "exec",
                db,
                "psql",
                "-U",
                "postgres",
                "-d",
                "pillxai_v2_test",
                "-Atc",
                "SELECT version_num FROM alembic_version",
            ],
            capture_output=True,
            text=True,
        ).stdout.strip()
        run(
            [
                "docker",
                "run",
                "-d",
                "--name",
                api,
                "--network",
                network,
                "-e",
                "PILLXAI_DATABASE_URL",
                "-e",
                "PILLXAI_ROOT_PATH=/dispenser-v2",
                "-e",
                "PILLXAI_LOGIN_LIMIT_PER_MINUTE=60",
                "-p",
                "127.0.0.1::8000",
                api_image,
            ],
            env=environment,
            stdout=subprocess.DEVNULL,
        )
        port = inspect_container_port(api)
        for attempt in range(60):
            try:
                health = request(port, "/health/ready")
                break
            except (OSError, urllib.error.URLError):
                if attempt == 59:
                    raise
                time.sleep(1)
        assert health == {"status": "ready", "service_version": "0.1.0+" + revision}
        session = request(port, "/auth/login", admin)
        account = request(port, "/auth/me", token=session["access_token"])
        assert account["username"] == "ci-admin"
        assert request(port, "/openapi.json")["servers"] == [{"url": "/dispenser-v2"}]
        try:
            request(port, "/dev/contract-samples", {})
            raise AssertionError("Development probe was exposed")
        except urllib.error.HTTPError as error:
            assert error.code == 404
        # Back up and actually restore into a second disposable database.
        with tempfile.TemporaryFile() as stream:
            run(
                ["docker", "exec", db, "pg_dump", "-U", "postgres", "-d", "pillxai_v2_test", "-Fc"],
                stdout=stream,
            )
            stream.seek(0)
            run(["docker", "exec", db, "createdb", "-U", "postgres", "v2_restore_test"])
            run(
                [
                    "docker",
                    "exec",
                    "-i",
                    db,
                    "pg_restore",
                    "-U",
                    "postgres",
                    "-d",
                    "v2_restore_test",
                    "--exit-on-error",
                ],
                stdin=stream,
            )
        count = run(
            [
                "docker",
                "exec",
                db,
                "psql",
                "-U",
                "postgres",
                "-d",
                "v2_restore_test",
                "-Atc",
                "SELECT count(*) FROM accounts",
            ],
            capture_output=True,
            text=True,
        ).stdout.strip()
        assert count == "1"
        run(["docker", "restart", api], stdout=subprocess.DEVNULL)
        for attempt in range(60):
            try:
                assert (
                    request(port, "/auth/me", token=session["access_token"])["id"] == account["id"]
                )
                break
            except (OSError, urllib.error.URLError):
                if attempt == 59:
                    raise
                time.sleep(1)
        return schema
    finally:
        # Only randomly named disposable CI resources; never the production project.
        for name in (api, db):
            subprocess.run(
                ["docker", "rm", "-f", "-v", name],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        subprocess.run(
            ["docker", "network", "rm", network],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


def inspect_container_port(name):
    data = json.loads(run(["docker", "inspect", name], capture_output=True, text=True).stdout)[0]
    return int(data["NetworkSettings"]["Ports"]["8000/tcp"][0]["HostPort"])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--revision", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.revision):
        raise ValueError("Expected full commit SHA")
    args.output.mkdir(parents=True, exist_ok=False)
    python_image = pull_pinned("python:3.12.15-slim-bookworm")
    postgres_source = pull_pinned("postgres:18.6-bookworm")
    pg_id = inspect(postgres_source)["Id"]
    pg_image = "pillxai-v2-postgres:" + pg_id.split(":")[1]
    run(["docker", "tag", postgres_source, pg_image])
    temporary_tag = "pillxai-v2-build:" + args.revision
    with tempfile.TemporaryDirectory(prefix="pillxai-v2-context-") as directory:
        context = Path(directory)
        # Allowlist context: no legacy, client, .git, .var, .env or local credentials.
        shutil.copytree(
            ROOT / "apps/api",
            context / "apps/api",
            ignore=shutil.ignore_patterns(
                "__pycache__",
                "*.pyc",
                ".venv*",
                "*.egg-info",
                ".pytest_cache",
                ".env*",
                "tests",
            ),
        )
        shutil.copytree(ROOT / "deploy/v2-server/container", context / "deploy/v2-server/container")
        shutil.copyfile(ROOT / "deploy/v2-server/Dockerfile", context / "Dockerfile")
        run(
            [
                "docker",
                "build",
                "--platform",
                "linux/amd64",
                "--build-arg",
                f"PYTHON_IMAGE={python_image}",
                "--build-arg",
                f"REVISION={args.revision}",
                "-t",
                temporary_tag,
                str(context),
            ]
        )
    api_id = inspect(temporary_tag)["Id"]
    api_image = "pillxai-v2-api:" + api_id.split(":")[1]
    run(["docker", "tag", temporary_tag, api_image])
    schema = smoke(api_image, pg_image, args.revision)
    # docker load supports compressed tar. Keep host deployment independent of registries.
    archive = args.output / "images.tar.gz"
    process = subprocess.Popen(["docker", "save", api_image, pg_image], stdout=subprocess.PIPE)
    with gzip.open(archive, "wb", compresslevel=1) as output:
        shutil.copyfileobj(process.stdout, output)
    if process.wait() != 0:
        raise RuntimeError("Docker image export failed")
    for name in FILES:
        shutil.copyfile(ROOT / "deploy/v2-server" / name, args.output / name)
    write_json(
        args.output / "manifest.json",
        {
            "revision": args.revision,
            "schema": schema,
            "api_image": api_image,
            "api_id": api_id,
            "postgres_image": pg_image,
            "postgres_id": pg_id,
            "python_base": python_image,
            "postgres_base": postgres_source,
            "files": {name: digest(args.output / name) for name in (*FILES, "images.tar.gz")},
        },
    )
    from check_compose import check

    check(args.output, args.revision)
    print("V2 images built, HTTP/Compose/restart/restore checks passed, artifact exported.")


if __name__ == "__main__":
    main()
