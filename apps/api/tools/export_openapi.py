"""Export the actual application schema; no live database or secrets required."""

import json
from pathlib import Path

from pillxai_api.app import create_app
from pillxai_api.config import Settings

root = Path(__file__).resolve().parents[3]
app = create_app(Settings("postgresql+psycopg://unused@localhost/unused", True))
schema = app.openapi()
target = root / "contracts/http/openapi.json"
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(json.dumps(schema, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
app.state.engine.dispose()
print(target)
