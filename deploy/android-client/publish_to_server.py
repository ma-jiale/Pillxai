"""Install a main CI artifact already validated against the API model and APK certificate.

Only Python's standard library is needed on the existing production Runner.
The build job supplies the manifest digest separately through its job output.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import tempfile
import urllib.request
from pathlib import Path


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def reject_symlinks(path: Path):
    if any(part.is_symlink() for part in (path, *path.parents)):
        raise ValueError(f"Symlinks are not allowed: {path}")


def publish(source: Path, output: Path, manifest_sha256: str, revision: str,
            version_name: str, version_code: int) -> dict:
    reject_symlinks(source)
    reject_symlinks(output)
    manifest = source / "current.json"
    provenance = source / "source-revision.txt"
    reject_symlinks(manifest)
    reject_symlinks(provenance)
    if digest(manifest) != manifest_sha256:
        raise ValueError("Manifest differs from the verified build job output")
    if provenance.read_text().strip() != revision:
        raise ValueError("Artifact source revision does not match this workflow")
    release = json.loads(manifest.read_bytes())
    if (release["package_name"] != "com.pillxai.pillxai_client"
            or release["version_name"] != version_name
            or release["version_code"] != version_code
            or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version_name)
            or not re.fullmatch(r"[0-9a-f]{64}", release["sha256"])):
        raise ValueError("Artifact identity does not match the requested stable release")
    apk = source / f"{release['sha256']}.apk"
    reject_symlinks(apk)
    if apk.stat().st_size != release["size_bytes"] or digest(apk) != release["sha256"]:
        raise ValueError("Incomplete or corrupt APK")

    # The deployment root must already exist. Never change parent directory permissions.
    output.mkdir(exist_ok=True, mode=0o755)
    output.chmod(0o755)  # Defeat umask 077 and repair directories created by older deploys.
    lock = output / ".publish-lock"
    lock.mkdir()  # Shared with the local publisher; an existing lock requires investigation.
    try:
        current = output / "current.json"
        reject_symlinks(current)
        if current.exists():
            previous = json.loads(current.read_bytes())
            if (previous["package_name"] != release["package_name"]
                    or previous["version_code"] > version_code
                    or (previous["version_code"] == version_code and previous != release)):
                raise ValueError("Refusing downgrade or replacement of an existing build")
        target = output / apk.name
        reject_symlinks(target)
        if target.exists() and digest(target) != release["sha256"]:
            raise ValueError("Existing immutable APK is corrupt")
        # Stage inside the destination filesystem; publish the manifest only after the APK.
        with tempfile.TemporaryDirectory(prefix=".publish-", dir=output) as staging:
            staged_apk = Path(staging) / apk.name
            if not target.exists():
                shutil.copyfile(apk, staged_apk)
                if digest(staged_apk) != release["sha256"]:
                    raise ValueError("APK changed during copy")
                with staged_apk.open("rb") as stream:
                    os.fsync(stream.fileno())
                staged_apk.chmod(0o644)
                os.replace(staged_apk, target)
            target.chmod(0o644)
            staged_manifest = Path(staging) / "current.json"
            with staged_manifest.open("wb") as stream:
                stream.write(manifest.read_bytes())
                stream.flush()
                os.fsync(stream.fileno())
            if digest(staged_manifest) != manifest_sha256:
                raise ValueError("Manifest changed during copy")
            staged_manifest.chmod(0o644)
            os.replace(staged_manifest, current)
        directory_fd = os.open(output, os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        lock.rmdir()
    return release


def verify_online(api_url: str, release: dict):
    endpoint = api_url.rstrip("/") + "/releases/android"
    with urllib.request.urlopen(endpoint, timeout=60) as response:
        info = json.load(response)
    if info["release"] != release:
        raise ValueError("Public update endpoint does not advertise the published release")
    if not release["min_api"] <= info["api_compatibility"] <= release["max_api"]:
        raise ValueError("Published release is incompatible with the deployed API")
    downloaded = hashlib.sha256()
    size = 0
    with urllib.request.urlopen(endpoint + "/packages/" + release["sha256"],
                                timeout=60) as response:
        while chunk := response.read(1024 * 1024):
            size += len(chunk)
            downloaded.update(chunk)
    if size != release["size_bytes"] or downloaded.hexdigest() != release["sha256"]:
        raise ValueError("Public APK download failed integrity verification")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--manifest-sha256", required=True)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--version-name", required=True)
    parser.add_argument("--version-code", type=int, required=True)
    parser.add_argument("--api-url", required=True)
    args = parser.parse_args()
    release = publish(args.artifact, args.output, args.manifest_sha256, args.revision,
                      args.version_name, args.version_code)
    verify_online(args.api_url, release)
    print(f"Published and downloaded {release['version_name']} ({release['version_code']}), "
          f"SHA-256 {release['sha256']}")


if __name__ == "__main__":
    main()
