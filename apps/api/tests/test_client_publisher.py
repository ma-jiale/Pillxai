import importlib.util
import json
from pathlib import Path
from unittest.mock import Mock, patch

import pytest

script = Path(__file__).resolve().parents[3] / "scripts/publish-client-release.py"
spec = importlib.util.spec_from_file_location("client_publisher", script)
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)


def test_publisher_is_atomic_and_rejects_same_or_older_build(tmp_path):
    apk = tmp_path / "fixture.apk"
    apk.write_bytes(b"test publication bytes, not an actual APK")
    output = tmp_path / "releases"
    metadata = dict(
        package_name="com.pillxai.test",
        version_code=2,
        version_name="0.2.0",
        min_android_sdk=24,
        abis=["x86_64"],
    )
    publisher.publish(apk, output, metadata, "Test", 1, 1)
    original = (output / "current.json").read_bytes()
    manifest = json.loads(original)
    assert (output / f"{manifest['sha256']}.apk").read_bytes() == apk.read_bytes()
    with pytest.raises(ValueError, match="strictly newer"):
        publisher.publish(apk, output, metadata, "Replace", 1, 1)
    assert (output / "current.json").read_bytes() == original
    assert not (output / ".publish-lock").exists()
    assert not (output / "package.pending").exists()


def test_publisher_does_not_race_another_publisher(tmp_path):
    output = tmp_path / "releases"
    output.mkdir()
    (output / ".publish-lock").mkdir()
    with pytest.raises(FileExistsError):
        publisher.publish(tmp_path / "missing.apk", output, {}, "Test", 1, 1)


def test_debug_certificate_cannot_be_published():
    with patch.object(publisher.subprocess, "run", return_value=Mock(stdout="CN=Android Debug")):
        with pytest.raises(ValueError, match="debug certificate"):
            publisher.inspect_apk(Path("fixture.apk"), "aapt", "apksigner", "a" * 64)


@pytest.mark.parametrize(
    ("package", "version", "debuggable", "error"),
    [
        ("com.pillxai.pillxai_client.development", "0.2.0", False, "production package"),
        ("com.pillxai.pillxai_client.runtimecheck", "0.2.0", False, "production package"),
        ("com.pillxai.pillxai_client", "0.2.0-beta.1", False, "stable version"),
        ("com.pillxai.pillxai_client", "0.2.0", True, "debuggable"),
        ("com.pillxai.pillxai_client", "0.2.0", False, None),
    ],
)
def test_only_stable_production_apks_can_be_published(package, version, debuggable, error):
    badging = (
        f"package: name='{package}' versionCode='2' versionName='{version}'\n"
        "sdkVersion:'24'\nnative-code: 'arm64-v8a' 'x86_64'\n"
        + ("application-debuggable\n" if debuggable else "")
    )
    with patch.object(
        publisher.subprocess,
        "run",
        side_effect=[
            Mock(stdout=f"CN=Release\nSigner #1 certificate SHA-256 digest: {'a' * 64}\n"),
            Mock(stdout=badging),
        ],
    ):
        if error:
            with pytest.raises(ValueError, match=error):
                publisher.inspect_apk(Path("fixture.apk"), "aapt", "apksigner", "a" * 64)
        else:
            metadata = publisher.inspect_apk(Path("fixture.apk"), "aapt", "apksigner", "a" * 64)
            assert metadata["version_code"] == 2


@pytest.mark.parametrize("expected", ["b" * 64, "", "invalid"])
def test_publisher_rejects_unknown_signing_certificate(expected):
    with patch.object(
        publisher.subprocess,
        "run",
        return_value=Mock(stdout=f"Signer #1 certificate SHA-256 digest: {'a' * 64}\n"),
    ):
        with pytest.raises(ValueError, match="production fingerprint"):
            publisher.inspect_apk(Path("fixture.apk"), "aapt", "apksigner", expected)
