"""V2-only Docker deployment and recovery. Host Python standard library only."""

import argparse
import getpass
import hashlib
import json
import os
import re
import secrets
import shutil
import socket
import subprocess
import sys
import urllib.request
from contextlib import contextmanager
from datetime import UTC, datetime
from pathlib import Path
from uuid import uuid4

PROJECT = "pillxai-v2"
DEFAULT_ROOT = Path.home() / "projects/pillxa-dispenser/v2"
FILES = ("compose.yaml", "init-db.sh", "backup-loop.sh", "manage.py", "preflight.py")


def run(args, **kwargs):
    # Never echo commands: stdin/env can include credentials.
    return subprocess.run(args, check=True, **kwargs)


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write_json(path, data):
    path = Path(path)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def root_path(value):
    path = Path(value).expanduser().resolve()
    if path.name != "v2" or path.parent.name != "pillxa-dispenser":
        raise ValueError("Deployment root must end with pillxa-dispenser/v2")
    return path


@contextmanager
def lock(root):
    import fcntl

    with (root / ".deploy.lock").open("a") as stream:
        fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield


def initialize(root):
    root.mkdir(parents=True, exist_ok=True)
    with lock(root):
        shared = root / "shared"
        if shared.exists():
            raise ValueError("shared already exists; refusing to overwrite configuration")
        shared.mkdir(mode=0o700)
        for directory in (root / "releases", root / "backups"):
            directory.mkdir(mode=0o700)
        # PostgreSQL 18 chowns PGDATA (18/docker), not its bind-mounted parent.
        # The postgres user must traverse this parent after the entrypoint drops root.
        # shared stays 0700 on the host; PostgreSQL keeps actual PGDATA at 0700.
        (shared / "postgres").mkdir(mode=0o755)
        (shared / "postgres").chmod(0o755)
        password = secrets.token_hex(32)
        values = {
            "app-password": password,
            "postgres-password": secrets.token_hex(32),
            "database-url": f"postgresql+psycopg://pillxai_v2:{password}@db:5432/pillxai_v2",
        }
        for name, value in values.items():
            path = shared / name
            path.write_text(value + "\n", encoding="utf-8")
            # Parent is 0700. Container users can read only explicitly mounted files.
            path.chmod(0o444)
        (shared / "server.env").write_text(
            "V2_PORT=8068\nV2_ROOT_PATH=/dispenser-v2\nV2_FORWARDED_ALLOW_IPS=127.0.0.1\n",
            encoding="utf-8",
        )
        (shared / "server.env").chmod(0o600)
        shutil.copyfile(Path(__file__).with_name("init-db.sh"), shared / "init-db.sh")
        (shared / "init-db.sh").chmod(0o444)
        write_json(
            shared / "initial-admin.json",
            {
                "username": "admin",
                "password": secrets.token_urlsafe(32),
            },
        )
        (shared / "initial-admin.json").chmod(0o600)
        (shared / "DEPLOYMENT_READY").touch(mode=0o600)
    print(f"Initialized V2 configuration at {root}; no credentials printed.")


def configuration(root):
    shared = root / "shared"
    if shared.is_symlink():
        raise ValueError("Shared directory must not redirect to another deployment")
    if not (shared / "DEPLOYMENT_READY").is_file():
        raise ValueError("Run init on the deployment host first")
    result = {}
    for line in (shared / "server.env").read_text().splitlines():
        if line.strip() and not line.lstrip().startswith("#"):
            key, value = line.split("=", 1)
            if key not in {"V2_PORT", "V2_ROOT_PATH", "V2_FORWARDED_ALLOW_IPS"}:
                raise ValueError("Unknown server setting")
            result[key] = value
    port = int(result.get("V2_PORT", "8068"))
    if port < 1024 or port > 65535 or port in {5068, 5432}:
        raise ValueError("Unsafe V2 port")
    prefix = result.get("V2_ROOT_PATH", "/dispenser-v2")
    if prefix != "/dispenser-v2":
        raise ValueError("This deployment requires the independent /dispenser-v2 prefix")
    for name in ("app-password", "postgres-password", "database-url"):
        if not (shared / name).is_file() or (shared / name).is_symlink():
            raise ValueError("Missing or redirected credential file")
    if (shared / "postgres").is_symlink():
        raise ValueError("Database directory must not be a symlink")
    return result


def runtime_environment(root, release):
    manifest = read_json(release / "manifest.json")
    environment = os.environ.copy()
    # Do not allow calling-shell Compose settings to choose another project/daemon file.
    for key in list(environment):
        if key.startswith("COMPOSE_") or key.startswith("V2_"):
            environment.pop(key)
    environment.update(configuration(root))
    info = json.loads(
        run(
            ["docker", "info", "--format", "{{json .SecurityOptions}}"],
            capture_output=True,
            text=True,
        ).stdout
    )
    rootless = any("rootless" in item for item in info)
    environment.update(
        V2_IMAGE=manifest["api_image"],
        V2_POSTGRES_IMAGE=manifest["postgres_image"],
        V2_SHARED=str(root / "shared"),
        V2_BACKUPS=str(root / "backups"),
        V2_UID=str(0 if rootless else os.getuid()),
        V2_GID=str(0 if rootless else os.getgid()),
    )
    return environment


def compose(root, release, *arguments, **kwargs):
    environment = runtime_environment(root, release)
    # Public APKs only, separately mounted from credentials. Empty is a valid
    # unpublished state; an existing deployment gains this directory on upgrade.
    client_releases = root / "shared/client-releases"
    if client_releases.is_symlink():
        raise ValueError("Client releases must not redirect outside this deployment")
    client_releases.mkdir(mode=0o755, exist_ok=True)
    return run(
        [
            "docker",
            "compose",
            "--project-name",
            PROJECT,
            "--env-file",
            str(root / "shared/server.env"),
            "--file",
            str(release / "compose.yaml"),
            *arguments,
        ],
        env=environment,
        **kwargs,
    )


def sql(root, release, query):
    return compose(
        root,
        release,
        "exec",
        "-T",
        "db",
        "psql",
        "-X",
        "-U",
        "postgres",
        "-d",
        "pillxai_v2",
        "-v",
        "ON_ERROR_STOP=1",
        "-At",
        "-c",
        query,
        capture_output=True,
        text=True,
    ).stdout.strip()


def schema(root, release):
    exists = sql(root, release, "SELECT to_regclass('public.alembic_version') IS NOT NULL")
    return sql(root, release, "SELECT version_num FROM alembic_version") if exists == "t" else None


def assert_idle(root, release):
    exists = sql(root, release, "SELECT to_regclass('public.dispensing_tasks') IS NOT NULL")
    if (
        exists == "t"
        and sql(root, release, "SELECT count(*) FROM dispensing_tasks WHERE active") != "0"
    ):
        raise ValueError(
            "Active V2 tasks exist; finish collection and synchronization before deployment"
        )


def verify_artifact(artifact, revision):
    manifest = read_json(artifact / "manifest.json")
    if not re.fullmatch(r"[0-9a-f]{40}", revision) or manifest["revision"] != revision:
        raise ValueError("Artifact revision mismatch")
    expected = {*FILES, "images.tar.gz"}
    if set(manifest["files"]) != expected:
        raise ValueError("Unexpected artifact file inventory")
    for name, expected_digest in manifest["files"].items():
        if (artifact / name).is_symlink() or digest(artifact / name) != expected_digest:
            raise ValueError(f"Artifact checksum mismatch: {name}")
    for name in ("api_image", "postgres_image"):
        if not re.fullmatch(r"pillxai-v2-(api|postgres):[0-9a-f]{40,64}", manifest[name]):
            raise ValueError("Image must use an immutable V2-specific tag")
    return manifest


def verify_branch(repository, branch, revision):
    from urllib.parse import quote

    if not re.fullmatch(r"[\w.-]+/[\w.-]+", repository):
        raise ValueError("Invalid repository")
    if branch != "main":
        raise ValueError("Untrusted deployment branch")
    headers = {"Accept": "application/vnd.github+json"}
    if token := os.environ.get("GH_TOKEN"):
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(
        f"https://api.github.com/repos/{repository}/git/ref/heads/{quote(branch, safe='')}",
        headers=headers,
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        if json.load(response)["object"]["sha"] != revision:
            raise ValueError("Deployment branch has advanced; refusing stale artifact")


def verify_images(manifest):
    for key in ("api", "postgres"):
        inspected = json.loads(
            run(
                ["docker", "image", "inspect", manifest[f"{key}_image"]],
                capture_output=True,
                text=True,
            ).stdout
        )[0]
        if inspected["Id"] != manifest[f"{key}_id"] or inspected["Architecture"] != "amd64":
            raise ValueError("Loaded image identity/architecture mismatch")
        if (
            key == "api"
            and inspected["Config"]["Labels"].get("org.opencontainers.image.revision")
            != manifest["revision"]
        ):
            raise ValueError("API image revision mismatch")


def health(root, manifest):
    port = configuration(root).get("V2_PORT", "8068")
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open(f"http://127.0.0.1:{port}/health/ready", timeout=10) as response:
        payload = json.load(response)
    if payload != {"status": "ready", "service_version": "0.1.0+" + manifest["revision"]}:
        raise ValueError("API readiness/version mismatch")


def backup(root, release):
    target = (
        root
        / "backups"
        / (datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid4().hex[:8] + ".dump")
    )
    temporary = target.with_suffix(".partial")
    with temporary.open("xb") as stream:
        compose(
            root,
            release,
            "exec",
            "-T",
            "db",
            "pg_dump",
            "-U",
            "postgres",
            "-d",
            "pillxai_v2",
            "-Fc",
            "--no-owner",
            stdout=stream,
        )
    with temporary.open("rb") as stream:
        compose(
            root,
            release,
            "exec",
            "-T",
            "db",
            "pg_restore",
            "--list",
            stdin=stream,
            stdout=subprocess.DEVNULL,
        )
    temporary.replace(target)
    write_json(
        target.with_suffix(".json"),
        {
            "sha256": digest(target),
            "schema": schema(root, release),
            "revision": read_json(release / "manifest.json")["revision"],
        },
    )
    print(f"Backup saved: {target.name}")
    return target


def current_release(root):
    record = root / "current.json"
    if not record.exists():
        raise ValueError("No successful V2 deployment")
    release = (root / "releases" / read_json(record)["release"]).resolve()
    if release.parent != (root / "releases").resolve():
        raise ValueError("Invalid release path")
    return release


def deploy(root, artifact, revision, repository, branch):
    manifest = verify_artifact(artifact, revision)
    verify_branch(repository, branch, revision)
    configuration(root)
    if (root / "pending.json").exists():
        raise ValueError("Unfinished deployment exists; inspect pending.json and use recover first")
    previous = current_release(root) if (root / "current.json").exists() else None
    # Neither importing images nor initializing V2 can overwrite V1 containers/data.
    if previous:
        old_manifest = read_json(previous / "manifest.json")
        if manifest["postgres_id"] != old_manifest["postgres_id"]:
            raise ValueError("Database image changes require a separate reviewed upgrade")
        # PostgreSQL owns its 0700 directory; the host account cannot traverse it.
        run(
            [
                "docker",
                "run",
                "--rm",
                "--network",
                "none",
                "--entrypoint",
                "sh",
                "--mount",
                f"type=bind,src={root / 'shared/postgres'},dst=/data,readonly",
                old_manifest["postgres_image"],
                "-c",
                "test -f /data/18/docker/PG_VERSION",
            ]
        )
    elif any((root / "shared/postgres").iterdir()):
        raise ValueError("Unowned database contents; recover the first deployment before retrying")
    else:
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", int(configuration(root).get("V2_PORT", "8068"))))
    if shutil.disk_usage(root).free < max(
        3 * (artifact / "images.tar.gz").stat().st_size, 2 * 1024**3
    ):
        raise ValueError("Insufficient free deployment disk space")
    run(["docker", "load", "--input", str(artifact / "images.tar.gz")], stdout=subprocess.DEVNULL)
    verify_images(manifest)
    release = root / "releases" / (revision[:12] + "-" + uuid4().hex[:8])
    release.mkdir()
    for name in (*FILES, "manifest.json"):
        shutil.copyfile(artifact / name, release / name)
    verify_branch(repository, branch, revision)
    if previous:
        assert_idle(root, previous)
    pending = {"release": release.name, "previous": previous.name if previous else None}
    write_json(root / "pending.json", pending)
    try:
        if previous:
            database_size = int(sql(root, release, "SELECT pg_database_size('pillxai_v2')"))
            if shutil.disk_usage(root).free < database_size * 2 + 1024**3:
                raise ValueError("Insufficient disk space for database backup")
            compose(root, previous, "stop", "--timeout", "35", "api")
        compose(root, release, "up", "-d", "--wait", "--wait-timeout", "120", "db")
        # Recheck after all API writes are quiescent, closing the preflight race.
        assert_idle(root, release)
        pending["before_schema"] = schema(root, release)
        write_json(root / "pending.json", pending)
        if previous:
            pending["backup"] = backup(root, previous).name
            write_json(root / "pending.json", pending)
        compose(root, release, "run", "--rm", "--no-deps", "migrate")
        initialize_admin(root, release)
        if schema(root, release) != manifest["schema"]:
            raise ValueError("Migration did not reach the expected revision")
        compose(root, release, "up", "-d", "--no-deps", "--wait", "--wait-timeout", "120", "api")
        health(root, manifest)
        compose(root, release, "up", "-d", "--no-deps", "backup")
        if previous:
            write_json(root / "previous.json", {"release": previous.name})
        write_json(root / "current.json", {"release": release.name, "revision": revision})
        (root / "pending.json").unlink()
        print(f"V2 deployed and ready: {revision}; V1 was not modified.")
    except Exception:
        compose(root, release, "stop", "--timeout", "35", "api")
        if previous and schema(root, release) == read_json(previous / "manifest.json")["schema"]:
            compose(
                root, previous, "up", "-d", "--no-deps", "--wait", "--wait-timeout", "120", "api"
            )
            health(root, read_json(previous / "manifest.json"))
            (root / "pending.json").unlink()
            print("Previous V2 API restored; database was not overwritten.")
        raise


def recover(root):
    pending = read_json(root / "pending.json")
    # Explicit recovery preserves data: resume candidate only at its exact schema.
    release = (root / "releases" / pending["release"]).resolve()
    if release.parent != (root / "releases").resolve():
        raise ValueError("Invalid pending release")
    manifest = read_json(release / "manifest.json")
    verify_images(manifest)
    compose(root, release, "up", "-d", "--wait", "--wait-timeout", "120", "db")
    assert_idle(root, release)
    compose(root, release, "run", "--rm", "--no-deps", "migrate")
    initialize_admin(root, release)
    if schema(root, release) != manifest["schema"]:
        raise ValueError("Candidate schema mismatch; recovery left database intact")
    compose(root, release, "up", "-d", "--no-deps", "--wait", "--wait-timeout", "120", "api")
    health(root, manifest)
    compose(root, release, "up", "-d", "--no-deps", "backup")
    if pending["previous"]:
        write_json(root / "previous.json", {"release": pending["previous"]})
    write_json(root / "current.json", {"release": release.name, "revision": manifest["revision"]})
    (root / "pending.json").unlink()
    print("Pending V2 release recovered without restoring or deleting data.")


def initialize_admin(root, release):
    credentials = root / "shared/initial-admin.json"
    if credentials.is_file():
        with credentials.open("rb") as stream:
            compose(
                root,
                release,
                "run",
                "--rm",
                "--no-deps",
                "-T",
                "migrate",
                "python",
                "/app/operations/admin.py",
                stdin=stream,
            )


def restore_check(root, release, source):
    source = source.resolve()
    if source.parent != (root / "backups").resolve():
        raise ValueError("Restore check input must be a V2 backup")
    if source.with_suffix(".json").exists():
        expected = read_json(source.with_suffix(".json"))["sha256"]
    else:
        expected = Path(str(source) + ".sha256").read_text().split()[0]
    if digest(source) != expected:
        raise ValueError("Backup checksum mismatch")
    name = "v2_restore_" + uuid4().hex
    compose(root, release, "exec", "-T", "db", "createdb", "-U", "postgres", name)
    try:
        with source.open("rb") as stream:
            compose(
                root,
                release,
                "exec",
                "-T",
                "db",
                "pg_restore",
                "-U",
                "postgres",
                "--exit-on-error",
                "--no-owner",
                "-d",
                name,
                stdin=stream,
            )
        result = compose(
            root,
            release,
            "exec",
            "-T",
            "db",
            "psql",
            "-X",
            "-U",
            "postgres",
            "-d",
            name,
            "-At",
            "-v",
            "ON_ERROR_STOP=1",
            "-c",
            "SELECT version_num FROM alembic_version; SELECT count(*) FROM accounts;",
            capture_output=True,
            text=True,
        ).stdout
        print(
            "Isolated restore passed; schema/account count: " + result.strip().replace("\n", ", ")
        )
    finally:
        compose(root, release, "exec", "-T", "db", "dropdb", "-U", "postgres", name)


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "action",
        choices=["init", "deploy", "status", "backup", "restore-check", "admin", "recover"],
    )
    parser.add_argument("--root", type=root_path, default=DEFAULT_ROOT)
    parser.add_argument("--artifact", type=Path)
    parser.add_argument("--revision")
    parser.add_argument("--repository")
    parser.add_argument("--branch")
    parser.add_argument("--backup", type=Path)
    args = parser.parse_args()
    if sys.platform != "linux" or os.getuid() == 0:
        raise ValueError("Use the authorized non-root Linux deployment account")
    if args.action == "init":
        initialize(args.root)
        return
    configuration(args.root)
    with lock(args.root):
        if args.action == "deploy":
            if not all((args.artifact, args.revision, args.repository, args.branch)):
                parser.error("deploy requires artifact, revision, repository and branch")
            deploy(args.root, args.artifact.resolve(), args.revision, args.repository, args.branch)
        elif args.action == "recover":
            recover(args.root)
        else:
            release = current_release(args.root)
            if args.action == "status":
                compose(args.root, release, "ps")
                health(args.root, read_json(release / "manifest.json"))
            elif args.action == "backup":
                backup(args.root, release)
            elif args.action == "restore-check":
                if not args.backup:
                    parser.error("restore-check requires --backup")
                restore_check(args.root, release, args.backup)
            elif args.action == "admin":
                username = input("Administrator username: ").strip()
                password = getpass.getpass("Administrator password (12–128 characters): ")
                if password != getpass.getpass("Repeat password: "):
                    raise ValueError("Passwords differ")
                compose(
                    args.root,
                    release,
                    "run",
                    "--rm",
                    "--no-deps",
                    "-T",
                    "migrate",
                    "python",
                    "/app/operations/admin.py",
                    input=json.dumps({"username": username, "password": password}),
                    text=True,
                )


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"V2 operation failed: {error}", file=sys.stderr)
        raise SystemExit(1) from None
