"""Read-only application releases. Publishing is an explicit maintenance operation."""

from pathlib import Path

from fastapi import APIRouter, HTTPException, Request, Response
from fastapi.responses import FileResponse
from pydantic import BaseModel, ConfigDict, Field, model_validator

from .contracts import ApiError

API_COMPATIBILITY = 1
MAX_APK_BYTES = 512 * 1024 * 1024
router = APIRouter(
    prefix="/releases/android", tags=["releases"], responses={422: {"model": ApiError}}
)


class AndroidRelease(BaseModel):
    model_config = ConfigDict(extra="forbid")

    version_code: int = Field(ge=1, le=2100000000)
    version_name: str = Field(min_length=1, max_length=80)
    package_name: str = Field(pattern=r"^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$")
    sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    size_bytes: int = Field(ge=1, le=MAX_APK_BYTES)
    min_android_sdk: int = Field(ge=23, le=100)
    abis: list[str] = Field(min_length=1, max_length=4)
    min_api: int = Field(ge=1)
    max_api: int = Field(ge=1)
    notes: str = Field(max_length=8000)

    @model_validator(mode="after")
    def compatible_range(self):
        if self.min_api > self.max_api:
            raise ValueError("Invalid API compatibility range")
        if not set(self.abis) <= {"arm64-v8a", "armeabi-v7a", "x86_64"}:
            raise ValueError("Unsupported ABI")
        return self


class AndroidUpdateInfo(BaseModel):
    api_compatibility: int
    release: AndroidRelease | None


def release_directory(request: Request) -> Path | None:
    return request.app.state.client_releases_directory


def load_release(directory: Path | None) -> AndroidRelease | None:
    if directory is None:
        return None
    try:
        if not directory.is_dir():
            raise ValueError("Missing release directory")
        manifest = directory / "current.json"
        try:
            manifest_size = manifest.stat().st_size
        except FileNotFoundError:
            # An accessible directory without a manifest has no published release.
            return None
        if manifest_size > 65536:
            raise ValueError("Oversized manifest")
        release = AndroidRelease.model_validate_json(manifest.read_bytes())
        artifact = directory / f"{release.sha256}.apk"
        if not artifact.is_file() or artifact.stat().st_size != release.size_bytes:
            raise ValueError("Missing or incomplete APK")
        return release
    except (OSError, ValueError) as error:
        raise HTTPException(503, "应用发布信息暂不可用。") from error


@router.get("", operation_id="get_android_update", response_model=AndroidUpdateInfo)
def get_android_update(request: Request, response: Response):
    response.headers["Cache-Control"] = "no-store"
    return AndroidUpdateInfo(
        api_compatibility=API_COMPATIBILITY,
        release=load_release(release_directory(request)),
    )


@router.get(
    "/packages/{digest}",
    operation_id="download_android_release",
    response_class=FileResponse,
    responses={
        200: {
            "content": {
                "application/vnd.android.package-archive": {
                    "schema": {"type": "string", "format": "binary"}
                }
            }
        }
    },
)
def download_android_release(digest: str, request: Request):
    # Only the currently published, validated artifact is advertised or served.
    directory = release_directory(request)
    release = load_release(directory)
    if release is None or digest != release.sha256 or directory is None:
        raise HTTPException(404, "安装包未发布或已撤回，请重新检查更新。")
    return FileResponse(
        directory / f"{release.sha256}.apk",
        media_type="application/vnd.android.package-archive",
        filename=f"pillxai-{release.version_code}.apk",
        headers={"Cache-Control": "no-store"},
    )
