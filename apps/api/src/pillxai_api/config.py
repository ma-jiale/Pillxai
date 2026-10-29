from dataclasses import dataclass
from os import environ
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    database_url: str
    enable_contract_probe: bool = False
    service_version: str = "0.1.0"
    root_path: str = ""
    login_limit_per_minute: int = 0
    client_releases_directory: Path | None = None

    @classmethod
    def from_environment(cls) -> "Settings":
        database_url = environ.get("PILLXAI_DATABASE_URL", "")
        if filename := environ.get("PILLXAI_DATABASE_URL_FILE"):
            database_url = Path(filename).read_text(encoding="utf-8").strip()
        if not database_url.startswith("postgresql+psycopg://"):
            raise ValueError("PILLXAI_DATABASE_URL must use postgresql+psycopg://")
        return cls(
            database_url=database_url,
            enable_contract_probe=environ.get("PILLXAI_ENABLE_CONTRACT_PROBE") == "true",
            service_version=environ.get("PILLXAI_SERVICE_VERSION", "0.1.0"),
            root_path=environ.get("PILLXAI_ROOT_PATH", ""),
            login_limit_per_minute=int(environ.get("PILLXAI_LOGIN_LIMIT_PER_MINUTE", "0")),
            client_releases_directory=(
                Path(environ["PILLXAI_CLIENT_RELEASES_DIRECTORY"])
                if environ.get("PILLXAI_CLIENT_RELEASES_DIRECTORY")
                else None
            ),
        )
