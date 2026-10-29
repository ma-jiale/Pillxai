"""Validate an Android APK and atomically publish it to a local release directory.

Uses the API's release model as the single metadata contract. No network/deployment actions.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "apps/api/src"))
from pillxai_api.releases import AndroidRelease  # noqa: E402


def inspect_apk(apk: Path, aapt: str, apksigner: str, expected_certificate_sha256: str) -> dict:
    signature = subprocess.run(
        [apksigner, "verify", "--verbose", "--print-certs", str(apk)],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    if "CN=Android Debug" in signature:
        raise ValueError("Refusing to publish an Android debug certificate")
    fingerprints = re.findall(
        r"^Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F]{64})$", signature, re.M
    )
    if (
        not re.fullmatch(r"[0-9a-fA-F]{64}", expected_certificate_sha256)
        or len(fingerprints) != 1
        or fingerprints[0].lower() != expected_certificate_sha256.lower()
    ):
        raise ValueError("APK signing certificate does not match the production fingerprint")
    badging = subprocess.run(
        [aapt, "dump", "badging", str(apk)], check=True, capture_output=True, text=True
    ).stdout
    package = re.search(
        r"^package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", badging, re.M
    )
    sdk = re.search(r"^sdkVersion:'(\d+)'", badging, re.M)
    native = re.search(r"^native-code: (.+)$", badging, re.M)
    if not package or not sdk or not native:
        raise ValueError("APK must declare package, build version, SDK and native ABIs")
    if re.search(r"^application-debuggable", badging, re.M):
        raise ValueError("Refusing a debuggable production APK")
    if package[1] != "com.pillxai.pillxai_client":
        raise ValueError("Only the production package may be published")
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", package[3]):
        raise ValueError("Only stable version names may be published")
    return dict(
        package_name=package[1],
        version_code=int(package[2]),
        version_name=package[3],
        min_android_sdk=int(sdk[1]),
        abis=re.findall(r"'([^']+)'", native[1]),
    )


def publish(apk: Path, output: Path, metadata: dict, notes: str, min_api: int, max_api: int):
    output.mkdir(parents=True, exist_ok=True)
    lock = output / ".publish-lock"
    # Fail rather than race another publisher; inspect a stale lock before removing it.
    lock.mkdir()
    temporary = output / "package.pending"
    try:
        shutil.copyfile(apk, temporary)
        with temporary.open("rb") as source:
            digest = hashlib.file_digest(source, "sha256").hexdigest()
        release = AndroidRelease(
            **metadata,
            sha256=digest,
            size_bytes=temporary.stat().st_size,
            min_api=min_api,
            max_api=max_api,
            notes=notes,
        )
        temporary.chmod(0o644)  # APKs are public; the container reads as a different UID.
        current = output / "current.json"
        if current.exists():
            previous = AndroidRelease.model_validate_json(current.read_bytes())
            if (
                previous.package_name != release.package_name
                or previous.version_code >= release.version_code
            ):
                raise ValueError("Publish a strictly newer build of the same application")
        artifact = output / f"{digest}.apk"
        if artifact.exists():
            with artifact.open("rb") as source:
                if hashlib.file_digest(source, "sha256").hexdigest() != digest:
                    raise ValueError("Existing immutable artifact is corrupt")
            temporary.unlink()
        else:
            os.replace(temporary, artifact)
        data = json.dumps(release.model_dump(), ensure_ascii=False, indent=2) + "\n"
        manifest = output / "current.pending"
        with manifest.open("w", encoding="utf-8") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        manifest.chmod(0o644)
        os.replace(manifest, current)
        print(f"Published {release.version_name} ({release.version_code}), SHA-256 {digest}")
    finally:
        temporary.unlink(missing_ok=True)
        lock.rmdir()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--aapt", required=True)
    parser.add_argument("--apksigner", required=True)
    parser.add_argument("--expected-certificate-sha256", required=True)
    parser.add_argument("--notes", type=Path, required=True)
    parser.add_argument("--min-api", type=int, default=1)
    parser.add_argument("--max-api", type=int, default=1)
    args = parser.parse_args()
    metadata = inspect_apk(args.apk, args.aapt, args.apksigner, args.expected_certificate_sha256)
    publish(
        args.apk,
        args.output,
        metadata,
        args.notes.read_text(encoding="utf-8"),
        args.min_api,
        args.max_api,
    )


if __name__ == "__main__":
    main()
