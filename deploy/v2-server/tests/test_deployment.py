import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

DEPLOY = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(DEPLOY))
import manage  # noqa: E402

REVISION = "a" * 40


def manifest():
    return {
        "revision": REVISION,
        "schema": "schema_new",
        "api_image": "pillxai-v2-api:" + "a" * 64,
        "api_id": "sha256:" + "a" * 64,
        "postgres_image": "pillxai-v2-postgres:" + "b" * 64,
        "postgres_id": "sha256:" + "b" * 64,
    }


class DeploymentBranchTests(unittest.TestCase):
    def test_development_branches_are_rejected_before_network_access(self):
        with patch.object(manage.urllib.request, "urlopen") as request:
            for branch in ("NT", "codex/v2-server-deployment", "feature/example"):
                with self.subTest(branch=branch), self.assertRaisesRegex(ValueError, "Untrusted"):
                    manage.verify_branch("ma-jiale/Pillxai", branch, REVISION)
        request.assert_not_called()

    def test_main_accepts_only_current_remote_revision(self):
        for remote, accepted in ((REVISION, True), ("b" * 40, False)):
            response = io.BytesIO(json.dumps({"object": {"sha": remote}}).encode())
            with (
                self.subTest(remote=remote),
                patch.object(manage.urllib.request, "urlopen", return_value=response) as request,
            ):
                if accepted:
                    manage.verify_branch("ma-jiale/Pillxai", "main", REVISION)
                else:
                    with self.assertRaisesRegex(ValueError, "advanced"):
                        manage.verify_branch("ma-jiale/Pillxai", "main", REVISION)
                self.assertEqual(
                    "https://api.github.com/repos/ma-jiale/Pillxai/git/ref/heads/main",
                    request.call_args.args[0].full_url,
                )


class DeploymentTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.base = Path(self.temporary.name)
        self.root = self.base / "pillxa-dispenser/v2"
        manage.initialize(self.root)
        self.artifact = self.base / "artifact"
        self.artifact.mkdir()
        for name in (*manage.FILES, "images.tar.gz"):
            (self.artifact / name).write_text(name)
        self.manifest = manifest()
        self.manifest["files"] = {
            name: manage.digest(self.artifact / name) for name in (*manage.FILES, "images.tar.gz")
        }
        manage.write_json(self.artifact / "manifest.json", self.manifest)

    def tearDown(self):
        self.temporary.cleanup()

    def previous(self):
        release = self.root / "releases/old"
        release.mkdir()
        data = manifest() | {"schema": "schema_old", "revision": "b" * 40}
        manage.write_json(release / "manifest.json", data)
        manage.write_json(self.root / "current.json", {"release": "old", "revision": "b" * 40})
        return release

    def test_initialization_is_independent_and_never_overwrites(self):
        v1 = self.root.parent / "v1"
        v1.mkdir()
        marker = v1 / "existing.db"
        marker.write_text("V1 business data")
        before = (self.root / "shared/app-password").read_text()
        with self.assertRaises(ValueError):
            manage.initialize(self.root)
        self.assertEqual(before, (self.root / "shared/app-password").read_text())
        self.assertEqual("V1 business data", marker.read_text())

    def test_root_and_port_reject_v1(self):
        with self.assertRaises(ValueError):
            manage.root_path(self.root.parent / "v1")
        (self.root / "shared/server.env").write_text("V2_PORT=5068\n")
        with self.assertRaises(ValueError):
            manage.configuration(self.root)

    def test_client_releases_directory_survives_repeated_compose_calls(self):
        directory = self.root / "shared/client-releases"
        with (
            patch.object(manage, "runtime_environment", return_value={}),
            patch.object(manage, "run"),
        ):
            manage.compose(self.root, self.artifact, "ps")
            (directory / "current.json").write_text("existing release")
            manage.compose(self.root, self.artifact, "ps")
        self.assertEqual((directory / "current.json").read_text(), "existing release")

    def test_artifact_rejects_changed_bytes_or_revision(self):
        manage.verify_artifact(self.artifact, REVISION)
        with self.assertRaises(ValueError):
            manage.verify_artifact(self.artifact, "c" * 40)
        (self.artifact / "compose.yaml").write_text("tampered")
        with self.assertRaises(ValueError):
            manage.verify_artifact(self.artifact, REVISION)

    def test_artifact_inventory_cannot_escape(self):
        data = self.manifest | {"files": {"../v1/server.env": "a" * 64}}
        manage.write_json(self.artifact / "manifest.json", data)
        with self.assertRaises(ValueError):
            manage.verify_artifact(self.artifact, REVISION)

    def test_active_task_refuses_deployment(self):
        self.previous()
        with (
            patch.object(manage, "verify_branch"),
            patch.object(manage, "run"),
            patch.object(manage, "verify_images"),
            patch.object(manage, "compose") as command,
            patch.object(manage, "assert_idle", side_effect=ValueError("active")),
        ):
            with self.assertRaisesRegex(ValueError, "active"):
                manage.deploy(self.root, self.artifact, REVISION, "owner/repo", "main")
        command.assert_not_called()
        self.assertEqual("old", manage.read_json(self.root / "current.json")["release"])

    def failure(self, migrated):
        previous = self.previous()

        def command(root, release, *args, **kwargs):
            if args[:3] == ("run", "--rm", "--no-deps"):
                raise subprocess.CalledProcessError(1, ["migration"])

        with (
            patch.object(manage, "verify_branch"),
            patch.object(manage, "run"),
            patch.object(manage, "verify_images"),
            patch.object(manage, "assert_idle"),
            patch.object(manage, "schema", side_effect=["schema_old", migrated]),
            patch.object(manage, "sql", return_value="100"),
            patch.object(manage, "backup", return_value=Path("safe.dump")),
            patch.object(manage, "health") as health,
            patch.object(manage, "compose", side_effect=command) as calls,
        ):
            with self.assertRaises(subprocess.CalledProcessError):
                manage.deploy(self.root, self.artifact, REVISION, "owner/repo", "main")
        return previous, calls, health

    def test_failure_restores_only_compatible_previous_api(self):
        previous, calls, health = self.failure("schema_old")
        self.assertFalse((self.root / "pending.json").exists())
        health.assert_called_once()
        self.assertTrue(
            any(c.args[1] == previous and c.args[2:4] == ("up", "-d") for c in calls.call_args_list)
        )

    def test_schema_change_blocks_automatic_rollback_and_preserves_evidence(self):
        previous, calls, health = self.failure("schema_new")
        self.assertTrue((self.root / "pending.json").exists())
        health.assert_not_called()
        self.assertFalse(
            any(c.args[1] == previous and c.args[2:4] == ("up", "-d") for c in calls.call_args_list)
        )
        self.assertEqual("old", manage.read_json(self.root / "current.json")["release"])

    def test_first_deploy_failure_keeps_pending_without_success_record(self):
        with (
            patch.object(manage, "verify_branch"),
            patch.object(manage, "run"),
            patch.object(manage, "verify_images"),
            patch.object(manage, "assert_idle"),
            patch.object(manage, "schema", return_value=None),
            patch.object(manage, "compose") as calls,
        ):

            def command(root, release, *args, **kwargs):
                if args[:3] == ("run", "--rm", "--no-deps"):
                    raise ValueError("migration failed")

            calls.side_effect = command
            with self.assertRaises(ValueError):
                manage.deploy(self.root, self.artifact, REVISION, "owner/repo", "main")
        self.assertFalse((self.root / "current.json").exists())
        self.assertTrue((self.root / "pending.json").exists())

    def test_database_image_upgrade_is_not_part_of_api_release(self):
        self.previous()
        self.manifest["postgres_id"] = "sha256:" + "d" * 64
        manage.write_json(self.artifact / "manifest.json", self.manifest)
        with patch.object(manage, "verify_branch"), patch.object(manage, "run") as run:
            with self.assertRaisesRegex(ValueError, "separate reviewed upgrade"):
                manage.deploy(self.root, self.artifact, REVISION, "owner/repo", "main")
        run.assert_not_called()

    def test_compose_cannot_use_a_v1_project(self):
        previous = self.previous()
        with (
            patch.object(manage, "runtime_environment", return_value={}),
            patch.object(manage, "run") as call,
        ):
            manage.compose(self.root, previous, "ps")
        args = call.call_args.args[0]
        self.assertEqual("pillxai-v2", args[args.index("--project-name") + 1])


if __name__ == "__main__":
    unittest.main()
