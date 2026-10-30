import hashlib
import importlib.util
import io
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "publisher", Path(__file__).resolve().parents[1] / "publish_to_server.py"
)
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)


class PublishTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "artifact"
        self.source.mkdir()
        self.output = self.root / "releases"
        self.apk = b"verified CI APK bytes"
        self.release = dict(
            package_name="com.pillxai.pillxai_client", version_name="0.2.3", version_code=5,
            sha256=hashlib.sha256(self.apk).hexdigest(), size_bytes=len(self.apk),
            min_android_sdk=23, abis=["arm64-v8a"], min_api=1, max_api=1, notes="更新",
        )
        (self.source / f"{self.release['sha256']}.apk").write_bytes(self.apk)
        (self.source / "current.json").write_text(json.dumps(self.release), encoding="utf-8")
        (self.source / "source-revision.txt").write_text("a" * 40 + "\n")
        self.expected_hash = publisher.digest(self.source / "current.json")

    def publish(self, **overrides):
        args = dict(source=self.source, output=self.output, manifest_sha256=self.expected_hash,
                    revision="a" * 40, version_name="0.2.3", version_code=5)
        return publisher.publish(**(args | overrides))

    def test_first_publish_repairs_restrictive_umask_and_preserves_parent(self):
        self.root.chmod(0o700)
        old_umask = os.umask(0o077)
        try:
            self.publish()
        finally:
            os.umask(old_umask)
        self.assertEqual(self.root.stat().st_mode & 0o777, 0o700)
        self.assertEqual(self.output.stat().st_mode & 0o777, 0o755)
        for name in ("current.json", f"{self.release['sha256']}.apk"):
            self.assertEqual((self.output / name).stat().st_mode & 0o777, 0o644)

    def test_retry_repairs_existing_directory_and_keeps_same_release(self):
        self.publish()
        self.output.chmod(0o700)
        self.publish()
        self.assertEqual(self.output.stat().st_mode & 0o777, 0o755)
        self.assertEqual(json.loads((self.output / "current.json").read_bytes()), self.release)

    def test_corrupt_apk_cannot_replace_current_release(self):
        self.publish()
        (self.source / f"{self.release['sha256']}.apk").write_bytes(b"broken")
        with self.assertRaisesRegex(ValueError, "corrupt APK"):
            self.publish()
        self.assertEqual(json.loads((self.output / "current.json").read_bytes()), self.release)

    def test_manifest_and_provenance_must_match_build(self):
        for override in (dict(manifest_sha256="0" * 64), dict(revision="b" * 40),
                         dict(version_code=6), dict(version_name="0.2.4")):
            with self.subTest(override=override), self.assertRaises(ValueError):
                self.publish(**override)
        self.assertFalse(self.output.exists())

    def test_same_build_replacement_and_downgrade_rejected(self):
        self.publish()
        for previous in (self.release | {"version_code": 6},
                         self.release | {"sha256": "0" * 64}):
            with self.subTest(previous=previous):
                current = self.output / "current.json"
                current.write_text(json.dumps(previous))
                with self.assertRaisesRegex(ValueError, "Refusing downgrade"):
                    self.publish()
                self.assertEqual(json.loads(current.read_bytes()), previous)
                self.assertFalse((self.output / ".publish-lock").exists())

    def test_existing_lock_blocks_other_publisher(self):
        self.output.mkdir()
        (self.output / ".publish-lock").mkdir()
        with self.assertRaises(FileExistsError):
            self.publish()
        self.assertTrue((self.output / ".publish-lock").exists())
        self.assertFalse((self.output / "current.json").exists())

    def test_symlink_destination_rejected(self):
        real = self.root / "elsewhere"
        real.mkdir()
        self.output.symlink_to(real, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "Symlinks"):
            self.publish()
        self.assertEqual(list(real.iterdir()), [])

    def test_interrupted_manifest_switch_keeps_previous_and_retry_succeeds(self):
        self.output.mkdir()
        current = self.output / "current.json"
        previous = self.release | {"version_code": 4, "version_name": "0.2.2"}
        current.write_text(json.dumps(previous))
        replace = os.replace

        def fail_manifest(source, target):
            if target == current:
                raise OSError("simulated interrupted switch")
            replace(source, target)

        with patch.object(publisher.os, "replace", side_effect=fail_manifest):
            with self.assertRaises(OSError):
                self.publish()
        self.assertEqual(json.loads(current.read_bytes()), previous)
        self.publish()
        self.assertEqual(json.loads(current.read_bytes()), self.release)

    def test_public_download_is_fully_checked(self):
        info = json.dumps(dict(release=self.release, api_compatibility=1)).encode()
        for apk in (self.apk, b"broken"):
            with self.subTest(apk=apk), patch.object(
                publisher.urllib.request, "urlopen", side_effect=[io.BytesIO(info), io.BytesIO(apk)]
            ):
                if apk == self.apk:
                    publisher.verify_online("https://example.test/pillxai", self.release)
                else:
                    with self.assertRaisesRegex(ValueError, "integrity"):
                        publisher.verify_online("https://example.test/pillxai", self.release)


if __name__ == "__main__":
    unittest.main()
