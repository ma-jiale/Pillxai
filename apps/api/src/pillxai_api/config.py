from dataclasses import dataclass
from os import environ


@dataclass(frozen=True)
class Settings:
    database_url: str
    enable_contract_probe: bool = False

    @classmethod
    def from_environment(cls) -> "Settings":
        database_url = environ.get("PILLXAI_DATABASE_URL", "")
        if not database_url.startswith("postgresql+psycopg://"):
            raise ValueError("PILLXAI_DATABASE_URL must use postgresql+psycopg://")
        return cls(
            database_url=database_url,
            enable_contract_probe=environ.get("PILLXAI_ENABLE_CONTRACT_PROBE") == "true",
        )
